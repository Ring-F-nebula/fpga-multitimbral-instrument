`timescale 1ns/1ps
// Real production clocks and scanner parameters, documented 128+20-cycle
// DIGITAL ADC timing surrogate. This measures RTL latency, not analog settling.
module tb_fsr_latency;
 reg adc_clk=0;always #200 adc_clk=~adc_clk;
 reg clk=0;always #19.047619048 clk=~clk;
 reg reset_n=0;reg [13:0] code0=20;
 wire [3:0] select;wire [13:0] peak;wire [223:0] samples;
 wire [15:0] update_mask;wire toggle,online,fault,ready;wire [15:0] keys;
 fsr_adc adc(.clk(adc_clk),.reset_n(reset_n),.select(select),.peak(peak),.samples(samples),.update_mask(update_mask),
 .frame_toggle(toggle),.online(online),.fault(fault));
 wire [13:0] analog_code=select==0 ? code0:14'd20;
 initial force adc.adc_value=analog_code;
 fsr_keyboard #(.CALIBRATION_LOG2(1),.STREAMING(1)) keyboard(.clk(clk),.reset_n(reset_n),.sample_tick(1'b0),
 .recalibrate(1'b0),.samples_async(samples),.update_mask_async(update_mask),.peak_async(peak),.frame_toggle_async(toggle),
 .online_async(online),.keys(keys),.ready(ready));
 realtime t0,t1,period_ns,attack_ns;
 initial begin
 #5000;reset_n=1;wait(ready);
 begin @(toggle);while(update_mask!=1) @(toggle);end t0=$realtime;begin @(toggle);while(update_mask!=1) @(toggle);end t1=$realtime;period_ns=t1-t0;
 if(period_ns<2200000 || period_ns>2300000) $fatal(1,"production sweep period %f",period_ns);
 // Sweep the input-change phase across the entire channel scan period.
 for(integer phase=0;phase<8;phase=phase+1) begin
 code0=20;wait(keys==0);begin @(toggle);while(update_mask!=1) @(toggle);end#(phase*period_ns/8);
 code0=36;t0=$realtime;wait(keys[0]);attack_ns=$realtime-t0;
 if(attack_ns>4600000 || attack_ns<period_ns*0.9) $fatal(1,"attack deadline phase=%0d delay=%f",phase,attack_ns);
 $display("LATENCY phase=%0d scan_ms=%f attack_ms=%f",phase,period_ns/1e6,attack_ns/1e6);
 end
 $display("PASS real-clock digital latency: 16-channel sweep <2.45ms, all eight phases of two-scan attack <7.35ms; physical analog settling not measured");$finish;
 end
 initial begin #400000000;$fatal(1,"latency timeout");end
endmodule
config cfg_tb_fsr_latency;
 design work.tb_fsr_latency;default liblist work;
 instance tb_fsr_latency.adc.adc_i use work.fsr_adc_test_stub;
endconfig
