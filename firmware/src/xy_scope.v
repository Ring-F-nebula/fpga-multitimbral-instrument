// Double-buffered 256x112 XY plot. AUDIO mode plots actual mono PCM against
// the same signal delayed by 32 sample frames. Other modes are labelled sine
// references (1:1, 1:2, 2:3), not a fictitious stereo measurement.
module xy_scope(input clk,audio_clk,sample_tick,input signed [15:0] pcm,
    input [1:0] plot_mode,input frame_blank,
    input [14:0] read_address,output wire pixel,output reg display_valid=0);
    reg signed [15:0] audio_hold=0;
    reg audio_toggle=0;
    always @(posedge audio_clk) if(sample_tick) begin audio_hold<=pcm; audio_toggle<=~audio_toggle; end
    reg [2:0] toggle_sync=0;
    always @(posedge clk) toggle_sync<={toggle_sync[1:0],audio_toggle};
    wire new_sample=toggle_sync[2]^toggle_sync[1];
    reg signed [15:0] delay_line[0:31];
    reg [4:0] delay_index=0;
    reg [5:0] history_count=0;
    reg [15:0] peak=0;
    wire [15:0] absolute_pcm=audio_hold[15] ? -audio_hold:audio_hold;
    reg [23:0] reference_phase=0;
    reg [1:0] mode_meta=0,active_mode=0;
    always @(posedge clk) begin mode_meta<=plot_mode; active_mode<=mode_meta; end
    wire [23:0] twice_phase=reference_phase<<1;
    wire [23:0] thrice_phase=reference_phase+twice_phase;
    wire [7:0] x_phase=(active_mode==3)?twice_phase[23:16]:reference_phase[23:16];
    wire [7:0] y_phase=((active_mode==2)?twice_phase[23:16]:
                         (active_mode==3)?thrice_phase[23:16]:reference_phase[23:16])+
                         ((active_mode==2)?8'd0:8'd64);
    wire signed [7:0] sine_x,sine_y;
    instrument_wave_table ref_x(.phase(x_phase),.kind(2'd0),.value(sine_x));
    instrument_wave_table ref_y(.phase(y_phase),.kind(2'd0),.value(sine_y));
    function signed [8:0] normalize;
        input signed [15:0] value;
        input [15:0] level;
        reg signed [16:0] scaled;
        begin
            if(level<256) scaled=value>>>1;
            else if(level<512) scaled=value>>>2;
            else if(level<1024) scaled=value>>>3;
            else if(level<2048) scaled=value>>>4;
            else if(level<4096) scaled=value>>>5;
            else if(level<8192) scaled=value>>>6;
            else if(level<16384) scaled=value>>>7;
            else scaled=value>>>8;
            if(scaled>120) normalize=120;
            else if(scaled< -120) normalize=-120;
            else normalize=scaled[8:0];
        end
    endfunction
    wire signed [8:0] audio_x=normalize(audio_hold,peak);
    wire signed [8:0] audio_y=history_count<32?9'sd0:normalize(delay_line[delay_index],peak);
    reg signed [8:0] audio_x_q=0,audio_y_q=0;
    reg signed [7:0] sine_x_q=0,sine_y_q=0;
    always @(posedge clk) begin
        audio_x_q<=audio_x; audio_y_q<=audio_y;
        sine_x_q<=sine_x; sine_y_q<=sine_y;
    end
    reg signed [9:0] plot_y;
    reg [7:0] target_x;
    reg [6:0] target_y;
    reg [7:0] target_x_q=128;
    reg [6:0] target_y_q=56;
    reg signed [11:0] ref_y_scaled;
    always @* begin
        ref_y_scaled=$signed(sine_y_q)*12'sd7;
        plot_y=active_mode==0 ? (audio_y_q>>>1):(ref_y_scaled>>>4);
        if(plot_y>52) plot_y=52; else if(plot_y< -52) plot_y=-52;
        target_x=8'd128+((active_mode==0)?audio_x_q:$signed(sine_x_q));
        target_y=7'd56-plot_y;
    end
    always @(posedge clk) begin target_x_q<=target_x; target_y_q<=target_y; end
    always @(posedge clk) if(new_sample) begin
        delay_line[delay_index]<=audio_hold; delay_index<=delay_index+1'b1;
        if(history_count<32) history_count<=history_count+1'b1;
        if(absolute_pcm>peak) peak<=absolute_pcm;
        else if(peak>64) peak<=peak-(peak>>10)-1'b1;
        else peak<=0;
        reference_phase<=reference_phase+24'd96315;
    end
    (* ram_style="block" *) reg memory0[0:32767];
    (* ram_style="block" *) reg memory1[0:32767];
    reg bank=0,read_bank=0,q0=0,q1=0,valid_q=0;
    reg [1:0] state=0,mode_q=0;
    reg [14:0] clear_index=0;
    reg [9:0] point_count=0;
    reg [7:0] pen_x=128,end_x=128,last_x=128,dx=0;
    reg [6:0] pen_y=56,end_y=56,last_y=56,dy=0;
    reg first_point=1,step_right=0,step_down=0;
    reg signed [10:0] line_error=0,next_error;
    reg [7:0] next_x;
    reg [6:0] next_y;
    wire write_enable=(state==0 || state==2);
    wire [14:0] write_address=(state==0)?clear_index:{pen_y,pen_x};
    always @(posedge clk) begin
        if(write_enable && bank) memory0[write_address]<=(state==2);
        if(write_enable && !bank) memory1[write_address]<=(state==2);
        q0<=memory0[read_address]; q1<=memory1[read_address];
        read_bank<=bank; valid_q<=display_valid;
    end
    assign pixel=valid_q && (read_bank?q1:q0);
    always @* begin
        next_error=line_error; next_x=pen_x; next_y=pen_y;
        if((line_error<<<1)> -$signed({4'd0,dy})) begin
            next_error=next_error-$signed({4'd0,dy});
            next_x=step_right?pen_x+1'b1:pen_x-1'b1;
        end
        if((line_error<<<1)<$signed({3'd0,dx})) begin
            next_error=next_error+$signed({3'd0,dx});
            next_y=step_down?pen_y+1'b1:pen_y-1'b1;
        end
    end
    always @(posedge clk) begin
        mode_q<=active_mode;
        case(state)
            0: if(clear_index==32767) begin state<=1; point_count<=0; first_point<=1; end
               else clear_index<=clear_index+1'b1;
            1: if(new_sample) begin
                end_x<=target_x_q; end_y<=target_y_q;
                if(first_point) begin
                    pen_x<=target_x_q; pen_y<=target_y_q; dx<=0; dy<=0; line_error<=0;
                    first_point<=0;
                end else begin
                    pen_x<=last_x; pen_y<=last_y;
                    dx<=target_x_q>last_x?target_x_q-last_x:last_x-target_x_q;
                    dy<=target_y_q>last_y?target_y_q-last_y:last_y-target_y_q;
                    line_error<=$signed({3'd0,(target_x_q>last_x?target_x_q-last_x:last_x-target_x_q)})-
                                 $signed({4'd0,(target_y_q>last_y?target_y_q-last_y:last_y-target_y_q)});
                    step_right<=target_x_q>=last_x; step_down<=target_y_q>=last_y;
                end
                state<=2;
            end
            2: if(pen_x==end_x && pen_y==end_y) begin
                last_x<=end_x; last_y<=end_y;
                if(point_count==511) state<=3;
                else begin point_count<=point_count+1'b1; state<=1; end
            end else begin pen_x<=next_x; pen_y<=next_y; line_error<=next_error; end
            3: if(frame_blank) begin bank<=~bank; display_valid<=1; clear_index<=0; state<=0; end
        endcase
        if(mode_q!=active_mode) begin clear_index<=0; state<=0; point_count<=0; first_point<=1; end
    end
endmodule
