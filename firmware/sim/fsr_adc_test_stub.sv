`timescale 1ns/1ps
// Digital handshake surrogate ONLY. Gowin's ADCLRC simulation primitive has
// no analog conversion model. This does not validate the external analog path.
module fsr_adc_test_stub #(
    parameter CLK_SEL=1'b1,PIOCLK_SEL=1'b0,DIV_CTL=2'd0,
    parameter VSEN_CTL=3'd0,VSEN_CTL_SEL=1'b1,ADC_MODE=1'b1,
    parameter SAMPLE_CNT_SEL=3'd1,RATE_CHANGE_CTRL=3'd2,
    parameter integer CONVERSION_CYCLES=148
)(
    input CLK,DRSTN,ADCEN,ADCREQI,
    input [2:0] VSENCTL,input [9:0] FSCAL_VALUE,input [11:0] OFFSET_VALUE,
    input ADCINBK2A,ADCINBK2B,ADCINBK3A,ADCINBK3B,
    input ADCINBK4A,ADCINBK4B,ADCINBK5A,ADCINBK5B,
    output reg ADCRDY=0,output reg [13:0] ADCVALUE=0
);
    reg [13:0] sample_code=0,latched_code=0;
    reg fail_conversion=0;
    reg previous_request=0;
    integer remaining=0;
    initial begin
        if(CLK_SEL!=1 || ADC_MODE!=1 || VSENCTL!=0 ||
           SAMPLE_CNT_SEL!=1 || RATE_CHANGE_CTRL!=2)
            $fatal(1,"FSR ADC configuration changed");
    end
    always @(posedge CLK or negedge DRSTN) begin
        if(!DRSTN) begin
            remaining<=0; ADCRDY<=0; ADCVALUE<=0; previous_request<=0;
        end else begin
            previous_request<=ADCREQI;
            if(ADCEN && ADCREQI && !previous_request) begin
                ADCRDY<=0; remaining<=CONVERSION_CYCLES; latched_code<=sample_code;
            end else if(remaining>0 && !fail_conversion) begin
                remaining<=remaining-1;
                if(remaining==1) begin ADCVALUE<=latched_code; ADCRDY<=1; end
            end
        end
    end
endmodule
