// CDC mailbox: the ADC peak is held stable until the next full scan. Two-stage
// toggle/online synchronization plus a settling cycle precedes bus capture.
// Gain is Q8, 0..256. Default 32-code dead zone, full gain at code 1056.
// These are relative ADC thresholds, not calibrated grams or newtons.
module fsr_volume #(
    parameter [13:0] ZERO_CODE=14'd32,
    parameter integer GAIN_SHIFT=2
)(
    input wire clk,reset_n,sample_tick,
    input wire [13:0] peak_async,
    input wire frame_toggle_async,online_async,
    input wire signed [15:0] pcm_in,
    output reg signed [15:0] pcm_out=0,
    output reg [8:0] gain=0,
    output reg [13:0] pressure=0
);
    reg [1:0] toggle_sync=0,online_sync=0;
    reg last_toggle=0,capture_pending=0,valid=0;
    wire [13:0] above_zero=pressure>ZERO_CODE ? pressure-ZERO_CODE:14'd0;
    wire [13:0] mapped=above_zero>>GAIN_SHIFT;
    wire [8:0] target=(!valid || !online_sync[1]) ? 9'd0 :
        (mapped>=256 ? 9'd256:mapped[8:0]);
    wire signed [25:0] product=$signed(pcm_in)*$signed({1'b0,gain});
    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            toggle_sync<=0; online_sync<=0; last_toggle<=0;
            capture_pending<=0; valid<=0; pressure<=0; gain<=0; pcm_out<=0;
        end else begin
            toggle_sync<={toggle_sync[0],frame_toggle_async};
            online_sync<={online_sync[0],online_async};
            if(toggle_sync[1]!=last_toggle) begin
                last_toggle<=toggle_sync[1]; capture_pending<=1;
            end
            if(capture_pending) begin
                pressure<=peak_async; valid<=1; capture_pending<=0;
            end
            // Do not resurrect stale pressure after reset/timeout. Recovery
            // must publish a NEW full frame before enabling the gain again.
            if(!online_sync[1]) begin valid<=0; pressure<=0; end
            if(sample_tick) begin
                if(gain<target) gain<=gain+1'b1;
                else if(gain>target) gain<=gain-1'b1;
            end
            pcm_out<=product>>>8;
        end
    end
endmodule
