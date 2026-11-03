// GW5AST-138B dedicated ADCV input: NEO Dock 31005 J11-2 (+), J11-1 (-).
// The dedicated analog pads are implicit ADCLRC hard-block connections, not
// digital top-level GPIOs. AO MUST be divided to <=1 V before the ADCV+ pin.
// Suggested divider: AO --47k--+-- ADCV+; node --10k-- GND, 1nF to GND.
module fsr_adc #(parameter integer STREAMING=1)(
    input wire clk,reset_n,
    output wire [3:0] select,output wire enable_n,
    output wire [13:0] peak,output wire frame_toggle,online,fault,
    output wire [15:0] update_mask,output wire [223:0] samples
);
    wire adc_ready,adc_request,adc_reset_n;
    wire [13:0] adc_value;
    ADCLRC #(
        .CLK_SEL(1'b1),.PIOCLK_SEL(1'b0),.DIV_CTL(2'd0),
        .VSEN_CTL(3'd0),.VSEN_CTL_SEL(1'b1),.ADC_MODE(1'b1),
        .SAMPLE_CNT_SEL(3'd1),.RATE_CHANGE_CTRL(3'd2) // 128 samples, CIC period 16; 128 > 7*16
    ) adc_i (
        .CLK(clk),.DRSTN(adc_reset_n),.ADCEN(reset_n),.ADCREQI(adc_request),
        .VSENCTL(3'd0),.FSCAL_VALUE(10'd653),.OFFSET_VALUE(12'd0),
        .ADCINBK2A(1'b0),.ADCINBK2B(1'b0),
        .ADCINBK3A(1'b0),.ADCINBK3B(1'b0),
        .ADCINBK4A(1'b0),.ADCINBK4B(1'b0),
        .ADCINBK5A(1'b0),.ADCINBK5B(1'b0),
        .ADCRDY(adc_ready),.ADCVALUE(adc_value)
    );
    fsr_scanner #(.STREAMING(STREAMING)) scan(.clk(clk),.reset_n(reset_n),.adc_ready(adc_ready),.adc_value(adc_value),
        .adc_request(adc_request),.adc_reset_n(adc_reset_n),.select(select),.enable_n(enable_n),
        .peak(peak),.samples(samples),.update_mask(update_mask),.frame_toggle(frame_toggle),.online(online),.fault(fault));
endmodule
