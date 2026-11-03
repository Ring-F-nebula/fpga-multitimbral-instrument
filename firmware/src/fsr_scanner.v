// Runs in the ADC clock domain. The external 16:1 analog module is active-low.
// Allow its output and the input RC divider to settle before EACH conversion.
// Only a complete 16-channel sweep publishes a peak. A stale high ADCRDY is
// never accepted: each request must first observe ADCRDY low, then high.
module fsr_scanner #(
    parameter integer STREAMING=0,
    parameter integer SETTLE_CYCLES=200, // 80 us at 2.5 MHz; >9.7 RC constants for 47k/10k + 1nF
    parameter integer REQUEST_CYCLES=32,
    parameter integer TIMEOUT_CYCLES=6563 // >=4 ms at 1.640625 MHz
)(
    input wire clk,reset_n,
    input wire adc_ready,input wire [13:0] adc_value,
    output reg adc_request=0,adc_reset_n=0,
    output reg [3:0] select=0,output reg enable_n=1,
    output reg [13:0] peak=0,output reg frame_toggle=0,
    output reg [223:0] samples=0,output reg [15:0] update_mask=0,
    output reg online=0,fault=0
);
    localparam RECOVER=3'd0,SETTLE=3'd1,REQUEST=3'd2,WAIT_RESULT=3'd3,BLANK=3'd4;
    localparam TIMER_WIDTH=$clog2(TIMEOUT_CYCLES+SETTLE_CYCLES+REQUEST_CYCLES+1);
    reg [2:0] state=RECOVER;
    reg [TIMER_WIDTH-1:0] timer=0;
    reg [13:0] running_peak=0;
    reg [223:0] working_samples=0;
    reg ready_went_low=0;
    wire [13:0] next_peak=adc_value>running_peak ? adc_value:running_peak;
    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            state<=RECOVER; timer<=0; select<=0; enable_n<=1;
            adc_request<=0; adc_reset_n<=0; running_peak<=0;
            peak<=0; samples<=0; working_samples<=0;
            frame_toggle<=0;update_mask<=0; online<=0; fault<=0; ready_went_low<=0;
        end else case(state)
            RECOVER: begin
                adc_request<=0; adc_reset_n<=0; enable_n<=1;
                if(timer==REQUEST_CYCLES-1) begin
                    timer<=0; select<=0; running_peak<=0; working_samples<=0; adc_reset_n<=1;
                    enable_n<=0; state<=SETTLE;
                end else timer<=timer+1'b1;
            end
            BLANK: begin enable_n<=0;timer<=0;state<=SETTLE;end
            SETTLE: begin
                if(timer==SETTLE_CYCLES-1) begin
                    timer<=0; adc_request<=1; ready_went_low<=0; state<=REQUEST;
                end else timer<=timer+1'b1;
            end
            REQUEST: begin
                if(!adc_ready) ready_went_low<=1;
                if(timer==REQUEST_CYCLES-1) begin
                    timer<=0; adc_request<=0; state<=WAIT_RESULT;
                end else timer<=timer+1'b1;
            end
            WAIT_RESULT: begin
                if(!adc_ready) ready_went_low<=1;
                if(ready_went_low && adc_ready) begin
                    timer<=0;
                    working_samples[select*14 +: 14]<=adc_value;
                    if(STREAMING) begin
                        samples<=working_samples;samples[select*14 +:14]<=adc_value;
                        update_mask<=16'b1<<select;frame_toggle<=~frame_toggle;
                    end
                    if(select==15) begin
                        // Include the current channel; its nonblocking write
                        // has not reached working_samples yet.
                        samples<={adc_value,working_samples[209:0]};
                        peak<=next_peak; if(!STREAMING) begin frame_toggle<=~frame_toggle;update_mask<=16'hffff;end
                        online<=1; fault<=0; running_peak<=0; select<=0;
                    end else begin running_peak<=next_peak; select<=select+1'b1; end
                    // Disconnect while changing mux address; reconnect and settle next cycle.
                    enable_n<=1;state<=BLANK;
                end else if(timer==TIMEOUT_CYCLES-1) begin
                    // Mute on a failed conversion and reset the ADC for retry.
                    peak<=0; samples<=0; online<=0; fault<=1; timer<=0; state<=RECOVER;
                    enable_n<=1; adc_request<=0; adc_reset_n<=0; running_peak<=0;
                end else timer<=timer+1'b1;
            end
            default: begin state<=RECOVER; timer<=0; online<=0; end
        endcase
    end
endmodule
