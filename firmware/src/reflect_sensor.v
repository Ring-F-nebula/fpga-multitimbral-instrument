// Digital comparator module input (AO unused). No modulated IR transmitter.
// Remove the hand before power-on or pressing KEY1: capture stable idle D0
// after 200 ms settling + 50 ms stable calibration. Supports either polarity.
// 5 ms stable transitions, one 8 ms gate per approach; release before repeat.
module reflect_sensor #(
    parameter integer CLK_HZ=26250000,
    parameter integer SETTLE_MS=200,
    parameter integer CALIBRATE_MS=50,
    parameter integer DEBOUNCE_MS=5,
    parameter integer GATE_MS=8
)(input clk,input enable,input d0,
    output wire gate,output reg calibrated=0,output reg active=0,
    output wire raw_level,output reg idle_level=1,
    output reg [15:0] trigger_count=0);
    localparam integer MS_CYCLES=CLK_HZ/1000;
    reg meta=1,sync=1;
    reg [31:0] divider=0;
    reg [15:0] settle=0,cal_count=0,debounce=0,hold_ms=0;
    reg candidate=1,stable=1;
    assign raw_level=sync;
    assign gate=enable && (hold_ms!=0);
    always @(posedge clk) begin
        meta<=d0; sync<=meta;
        if(!enable) begin
            divider<=0; settle<=0; cal_count<=0; debounce<=0; hold_ms<=0;
            candidate<=sync; stable<=sync; idle_level<=sync;
            calibrated<=0; active<=0;
            // Counter is cumulative since FPGA configuration, not mode entry.
        end else if(divider==MS_CYCLES-1) begin
            divider<=0;
            if(hold_ms!=0) hold_ms<=hold_ms-1'b1;
            if(settle<SETTLE_MS) begin
                settle<=settle+1'b1; candidate<=sync; cal_count<=0;
            end else if(!calibrated) begin
                if(sync!=candidate) begin candidate<=sync; cal_count<=1; end
                else if(cal_count==CALIBRATE_MS-1) begin
                    calibrated<=1; idle_level<=sync; stable<=sync;
                    active<=0; debounce<=0; cal_count<=0;
                end else cal_count<=cal_count+1'b1;
            end else begin
                if(sync==stable) debounce<=0;
                else if(debounce==DEBOUNCE_MS-1) begin
                    stable<=sync; debounce<=0;
                    active<=(sync!=idle_level);
                    if(sync!=idle_level) begin
                        hold_ms<=GATE_MS;
                        trigger_count<=trigger_count+1'b1;
                    end
                end else debounce<=debounce+1'b1;
            end
        end else divider<=divider+1'b1;
    end
endmodule
