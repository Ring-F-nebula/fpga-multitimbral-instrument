// Independent pressure keys with per-pad startup baseline/noise calibration.
// The external ADC mailbox is captured atomically; process ONE pad per fabric
// clock so diagnostics/guard reductions never form a 16-comparator timing chain.
module fsr_keyboard #(
    parameter integer STREAMING=0,
    parameter integer CALIBRATION_LOG2=5, // 32 complete idle scans (~0.84 s)
    parameter [13:0] ON_DELTA_MIN=14'd16, OFF_DELTA_MIN=14'd8,
    parameter [13:0] CAL_NOISE_LIMIT=14'd512, MAX_VALID_CODE=14'd2304,
    parameter integer GAIN_SHIFT=-2,GAIN_SMOOTH_LOG2=0,
    parameter integer COMMON_MODE_KEYS=12,
    parameter [13:0] COMMON_DELTA_SPREAD=14'd32,
    parameter integer STALE_CYCLES=2625000
)(
    input wire clk,reset_n,sample_tick,
    input wire recalibrate,
    input wire [223:0] samples_async,input wire [15:0] update_mask_async,
    input wire [13:0] peak_async,
    input wire frame_toggle_async,online_async,
    output reg [15:0] keys=0,
    output wire [143:0] gains,
    output reg [223:0] pressures=0,
    output reg [13:0] peak=0,
    output wire ready,calibrating,fault,
    input [3:0] selected_pad,
    output [13:0] selected_raw,selected_baseline,selected_threshold,output [8:0] selected_gain,
    output reg [13:0] diagnostic_delta=0,diagnostic_threshold=0,
    output reg [15:0] calibrated_mask=0
);
    localparam integer CAL_FRAMES=1<<CALIBRATION_LOG2;
    localparam integer SUM_WIDTH=15+CALIBRATION_LOG2;
    localparam [1:0] IDLE=0,PROCESS_PAD=1,PUBLISH=2;
    function [3:0] channel_for_pad;
        input integer p;
        begin case(p)
            0:channel_for_pad=0;1:channel_for_pad=4;2:channel_for_pad=11;3:channel_for_pad=15;
            4:channel_for_pad=1;5:channel_for_pad=5;6:channel_for_pad=10;7:channel_for_pad=14;
            8:channel_for_pad=2;9:channel_for_pad=6;10:channel_for_pad=9;11:channel_for_pad=13;
            12:channel_for_pad=3;13:channel_for_pad=7;14:channel_for_pad=8;15:channel_for_pad=12;
        endcase end
    endfunction
    function [8:0] pressure_gain;
        input [13:0] delta;
        reg [13:0] mapped;
        begin
            mapped=GAIN_SHIFT>=0 ? delta>>GAIN_SHIFT : delta<<(-GAIN_SHIFT);
            pressure_gain=mapped>=256 ? 9'd256 : mapped<32 ? 9'd32 : mapped[8:0];
        end
    endfunction
    (* async_reg="true" *) reg [1:0] toggle_sync=0,online_sync=0;
    reg last_toggle=0,capture_pending=0,valid=0,common_fault=0;
    reg [$clog2(STALE_CYCLES+1)-1:0] age=0;
    reg [1:0] state=IDLE;
    reg [3:0] pad=0;
    reg [223:0] snapshot=0;
    wire [223:0] mapped_source;wire [15:0] mapped_mask;
    reg [15:0] snapshot_mask=0;
    reg [4:0] pending_total=0;reg [13:0] pending_min=0,pending_max=0;
    reg stream_fault_pending=0;
    reg [13:0] peak_snapshot=0,frame_delta=0,frame_threshold=0;
    reg [15:0] next_keys=0,new_keys=0,press_pending=0;
    reg [143:0] next_targets=0;
    reg [4:0] new_count=0;
    reg [13:0] delta_min=14'h3fff,delta_max=0;
    reg [15:0] invalid_mask=0,noise_mask=0;
    reg [4:0] drift_clock=0;
    reg [1:0] warmup_frames=2;
    reg [8:0] gain[0:15],target[0:15];
    reg [16:0] gain_fraction[0:15];
    reg signed [17:0] smooth_next;
    reg [13:0] baseline[0:15],cal_min[0:15],cal_max[0:15],on_delta[0:15];
    reg [SUM_WIDTH-1:0] cal_sum[0:15];
    reg [CALIBRATION_LOG2:0] cal_count[0:15];
    wire fresh=toggle_sync[1]!=last_toggle;
    assign selected_raw=pressures[selected_pad*14+:14];
    assign selected_baseline=baseline[selected_pad];
    assign selected_threshold=on_delta[selected_pad];
    assign selected_gain=gain[selected_pad];
    assign fault=(|invalid_mask) || (|noise_mask) || common_fault;
    assign ready=valid && online_sync[1] && age<STALE_CYCLES && (|calibrated_mask) && !common_fault;
    assign calibrating=valid && online_sync[1] && !(|calibrated_mask) && !fault;
    genvar p;
    generate for(p=0;p<16;p=p+1) begin: outputs
        assign mapped_mask[p]=update_mask_async[channel_for_pad(p)];
        assign mapped_source[p*14 +: 14]=samples_async[channel_for_pad(p)*14 +: 14];
        assign gains[p*9 +: 9]=gain[p];
        initial begin
            gain_fraction[p]=0;gain[p]=0;target[p]=0;baseline[p]=0;cal_min[p]=14'h3fff;cal_max[p]=0;
            cal_sum[p]=0;cal_count[p]=0;on_delta[p]=ON_DELTA_MIN;
        end
    end endgenerate
    integer i;
    reg [13:0] code,delta,low_code,high_code,noise,threshold,off_threshold,effective_delta;
    reg [SUM_WIDTH-1:0] sum;
    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            pending_total<=0;pending_min<=0;pending_max<=0;snapshot_mask<=0;stream_fault_pending<=0;
            toggle_sync<=0;online_sync<=0;last_toggle<=0;capture_pending<=0;valid<=0;
            diagnostic_delta<=0;diagnostic_threshold<=0;frame_delta<=0;frame_threshold<=0;
            keys<=0;pressures<=0;peak<=0;age<=0;state<=IDLE;pad<=0;snapshot<=0;peak_snapshot<=0;
            next_keys<=0;new_keys<=0;press_pending<=0;next_targets<=0;new_count<=0;
            delta_min<=14'h3fff;delta_max<=0;calibrated_mask<=0;invalid_mask<=0;noise_mask<=0;
            common_fault<=0;drift_clock<=0;warmup_frames<=2;pending_total<=0;stream_fault_pending<=0;
            for(i=0;i<16;i=i+1) begin
                gain_fraction[i]<=0;gain[i]<=0;target[i]<=0;baseline[i]<=0;cal_min[i]<=14'h3fff;cal_max[i]<=0;
                cal_sum[i]<=0;cal_count[i]<=0;on_delta[i]<=ON_DELTA_MIN;
            end
        end else begin
            toggle_sync<={toggle_sync[0],frame_toggle_async};
            online_sync<={online_sync[0],online_async};
            if(age<STALE_CYCLES) age<=age+1'b1;
            if(fresh) begin
                last_toggle<=toggle_sync[1];capture_pending<=1;age<=0;
            end
            if(sample_tick && state!=PUBLISH) for(i=0;i<16;i=i+1) if(keys[i]) begin
                if(GAIN_SMOOTH_LOG2==0) begin
                    if(gain[i]<target[i]) gain[i]<=gain[i]+1'b1;
                    else if(gain[i]>target[i]) gain[i]<=gain[i]-1'b1;
                end else begin
                    smooth_next=$signed({1'b0,gain_fraction[i]})+(($signed({1'b0,target[i],8'd0})-$signed({1'b0,gain_fraction[i]}))>>>GAIN_SMOOTH_LOG2);
                    gain_fraction[i]<=smooth_next[16:0];gain[i]<=smooth_next[16:8];
                end
            end
            if(recalibrate) begin
                keys<=0;valid<=0;state<=IDLE;capture_pending<=0;age<=0;
                last_toggle<=toggle_sync[1];calibrated_mask<=0;press_pending<=0;
                invalid_mask<=0;noise_mask<=0;common_fault<=0;
                warmup_frames<=2;pending_total<=0;stream_fault_pending<=0;
                for(i=0;i<16;i=i+1) begin
                    cal_count[i]<=0;cal_sum[i]<=0;cal_min[i]<=14'h3fff;cal_max[i]<=0;
                    target[i]<=gain[i];
                end
            end else if(!online_sync[1] || (age==STALE_CYCLES && !fresh && !capture_pending)) begin
                // Source loss invalidates ALL baselines. Fresh stable scans
                // are mandatory before pressure keys can recover.
                keys<=0;valid<=0;state<=IDLE;capture_pending<=0;
                calibrated_mask<=0;press_pending<=0;invalid_mask<=0;noise_mask<=0;common_fault<=0;
                warmup_frames<=2;pending_total<=0;stream_fault_pending<=0;
                pressures<=0;peak<=0;
                for(i=0;i<16;i=i+1) begin
                    cal_count[i]<=0;cal_sum[i]<=0;cal_min[i]<=14'h3fff;cal_max[i]<=0;
                    target[i]<=gain[i];
                end
            end else if(fresh && state!=IDLE) begin
                // A mailbox overwrite cannot create partially updated keys.
                keys<=0;valid<=0;state<=IDLE;capture_pending<=0;
                calibrated_mask<=0;press_pending<=0;common_fault<=1;pending_total<=0;
                for(i=0;i<16;i=i+1) begin cal_count[i]<=0;cal_sum[i]<=0;end
            end else case(state)
                IDLE: if(capture_pending) begin
                    capture_pending<=0;
                    if(warmup_frames!=0) begin
                        // A sweep already in progress at KEY1 can contain
                        // pre-release pressure. Do not train its old channels
                        // into the new idle peak/threshold. Also covers ADC
                        // recovery and analog startup settling.
                        if(!STREAMING || update_mask_async[15]) warmup_frames<=warmup_frames-1'b1;
                    end else begin
                        snapshot<=mapped_source;snapshot_mask<=STREAMING ? mapped_mask:16'hffff;peak_snapshot<=peak_async;stream_fault_pending<=0;
                        pad<=0;state<=PROCESS_PAD;
                        next_keys<=keys;new_keys<=0;new_count<=0;if(!STREAMING || update_mask_async[0]) begin frame_delta<=0;frame_threshold<=ON_DELTA_MIN;end
                        delta_min<=14'h3fff;delta_max<=0;
                        for(i=0;i<16;i=i+1) next_targets[i*9 +: 9]<=target[i];
                    end
                end
                PROCESS_PAD: begin
                    if(snapshot_mask[pad]) begin
                    code=snapshot[pad*14 +: 14];
                    if(calibrated_mask[pad] && code<=MAX_VALID_CODE) begin
                        delta=code>baseline[pad] ? code-baseline[pad]:14'd0;
                        if(delta>=frame_delta) begin frame_delta<=delta;frame_threshold<=on_delta[pad];end
                    end
                    if(code>MAX_VALID_CODE) begin
                        // ADCV voltage range is nominally 0..2048 codes;
                        // generous margin excludes full-scale garbage/rails.
                        next_keys[pad]<=0;press_pending[pad]<=0;invalid_mask[pad]<=1;
                        if(STREAMING && press_pending[pad] && pending_total!=0) pending_total<=pending_total-1'b1;
                        calibrated_mask[pad]<=0;cal_count[pad]<=0;cal_sum[pad]<=0;
                        next_targets[pad*9 +: 9]<=gain[pad];
                    end else if(!calibrated_mask[pad]) begin
                        next_keys[pad]<=0;press_pending[pad]<=0;
                        if(cal_count[pad]==0) begin
                            cal_min[pad]<=code;cal_max[pad]<=code;cal_sum[pad]<=code;cal_count[pad]<=1;
                        end else begin
                            low_code=code<cal_min[pad] ? code:cal_min[pad];
                            high_code=code>cal_max[pad] ? code:cal_max[pad];
                            noise=high_code-low_code;sum=cal_sum[pad]+code;
                            if(noise>CAL_NOISE_LIMIT) begin
                                noise_mask[pad]<=1;cal_min[pad]<=code;cal_max[pad]<=code;
                                cal_sum[pad]<=code;cal_count[pad]<=1;
                            end else if(cal_count[pad]==CAL_FRAMES-1) begin
                                baseline[pad]<=sum>>CALIBRATION_LOG2;
                                // Observe a FULL idle window, including its
                                // excursions. A short accidentally quiet run
                                // must not give a noisy pad a tiny threshold.
                                // Only the upper excursion can mimic a press.
                                // Using the whole peak-to-peak span here would
                                // unnecessarily discard the useful pressure
                                // range above a roughly symmetric idle signal.
                                on_delta[pad]<=high_code-(sum>>CALIBRATION_LOG2)+ON_DELTA_MIN;
                                calibrated_mask[pad]<=1;invalid_mask[pad]<=0;noise_mask[pad]<=0;
                                cal_count[pad]<=0;
                            end else begin
                                cal_min[pad]<=low_code;cal_max[pad]<=high_code;
                                cal_sum[pad]<=sum;cal_count[pad]<=cal_count[pad]+1'b1;
                            end
                        end
                    end else begin
                        delta=code>baseline[pad] ? code-baseline[pad]:14'd0;
                        off_threshold=on_delta[pad]-ON_DELTA_MIN+OFF_DELTA_MIN;
                        // Remove the measured noise allowance from velocity;
                        // otherwise a noisy pad reaches full volume at onset.
                        effective_delta=delta>(on_delta[pad]-ON_DELTA_MIN) ?
                            delta-(on_delta[pad]-ON_DELTA_MIN):14'd0;
                        if(keys[pad]) begin
                            if(delta<=off_threshold) begin
                                next_keys[pad]<=0;next_targets[pad*9 +: 9]<=gain[pad];
                            end else next_targets[pad*9 +: 9]<=pressure_gain(effective_delta);
                        end else begin
                            if(delta>=on_delta[pad]) begin
                                // EVERY attack needs two consecutive scans.
                                // A single large ADC spike is not a strike.
                                if(press_pending[pad]) begin
                                    next_keys[pad]<=1;new_keys[pad]<=1;press_pending[pad]<=0;
                                    if(STREAMING && pending_total!=0) pending_total<=pending_total-1'b1;
                                    next_targets[pad*9 +: 9]<=pressure_gain(effective_delta);new_count<=new_count+1'b1;
                                    if(delta<delta_min) delta_min<=delta;
                                    if(delta>delta_max) delta_max<=delta;
                                end else begin
                                    press_pending[pad]<=1;
                                    if(STREAMING) begin
                                        pending_total<=pending_total+1'b1;
                                        if(pending_total==0) begin pending_min<=delta;pending_max<=delta;end
                                        else begin
                                            if(delta<pending_min) pending_min<=delta;
                                            if(delta>pending_max) pending_max<=delta;
                                        end
                                        if(COMMON_MODE_KEYS<=16 && pending_total+1>=COMMON_MODE_KEYS &&
                                          ((pending_total==0 ? delta : (delta>pending_max ? delta:pending_max))-
                                           (pending_total==0 ? delta : (delta<pending_min ? delta:pending_min)))<=COMMON_DELTA_SPREAD)
                                            stream_fault_pending<=1;
                                    end
                                end
                            end else begin
                                if(STREAMING && press_pending[pad] && pending_total!=0) pending_total<=pending_total-1'b1;
                                press_pending[pad]<=0;
                                // Keep the measured idle reference fixed.
                                // Following every low outlier downward made
                                // the next ordinary idle high look like a key.
                                // KEY1 restarts calibration with hands away.
                            end
                        end
                    end
                    end
                    if(pad==15) state<=PUBLISH;else pad<=pad+1'b1;
                end
                PUBLISH: begin
                    valid<=1;pressures<=snapshot;peak<=peak_snapshot;
                    if(!STREAMING || snapshot_mask[3]) begin diagnostic_delta<=frame_delta;diagnostic_threshold<=frame_threshold;end drift_clock<=drift_clock+1'b1;
                    state<=IDLE;
                    if((!STREAMING && COMMON_MODE_KEYS<=16 && new_count>=COMMON_MODE_KEYS && delta_max-delta_min<=COMMON_DELTA_SPREAD) || (STREAMING && stream_fault_pending)) begin
                        pending_total<=0;stream_fault_pending<=0;
                        // A correlated all-pad step is a wiring/ADC/offset
                        // event, not a chord. Recalibrate without sounding it.
                        keys<=0;calibrated_mask<=0;press_pending<=0;common_fault<=1;pending_total<=0;
                        for(i=0;i<16;i=i+1) begin
                            cal_count[i]<=0;cal_sum[i]<=0;target[i]<=gain[i];
                        end
                    end else begin
                        keys<=next_keys;
                        if(&calibrated_mask) common_fault<=0;
                        for(i=0;i<16;i=i+1) begin
                            target[i]<=next_targets[i*9 +: 9];
                            if(new_keys[i]) begin gain[i]<=next_targets[i*9 +: 9];gain_fraction[i]<={next_targets[i*9 +: 9],8'd0};end
                        end
                    end
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
