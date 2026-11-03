`timescale 1ns/1ps
module tb_fsr_gain_smooth;
 reg clk=0;always #5 clk=~clk;reg reset_n=0,toggle=0;
 reg [223:0] samples={16{14'd20}};wire [15:0] keys;wire [143:0] gains;
 fsr_keyboard #(.CALIBRATION_LOG2(1),.GAIN_SMOOTH_LOG2(7)) dut(.clk(clk),.reset_n(reset_n),.sample_tick(1'b1),
 .recalibrate(1'b0),.samples_async(samples),.peak_async(14'd0),.frame_toggle_async(toggle),.online_async(1'b1),.keys(keys),.gains(gains));
 task clocks(input integer n);repeat(n) @(negedge clk);endtask
 task publish;@(negedge clk);toggle=~toggle;clocks(30);endtask
 integer lo=256,hi=0;reg [8:0] tail;
 initial begin
 clocks(3);reset_n=1;clocks(5);repeat(5) publish();
 samples[0+:14]=36;publish();publish();if(keys!=1 || gains[0+:9]!=64) $fatal(1,"gain smoothing delayed onset");
 for(integer i=0;i<30;i=i+1) begin
 samples[0+:14]=i%2?39:33;publish();
 repeat(70) begin clocks(1);if(i>8) begin if(gains[0+:9]<lo)lo=gains[0+:9];if(gains[0+:9]>hi)hi=gains[0+:9];end end
 if(keys!=1) $fatal(1,"gain jitter released held key");
 end
 if(hi-lo>12) $fatal(1,"pressure modulation not reduced: %0d",hi-lo);
 samples[0+:14]=84;publish();clocks(256);if(gains[0+:9]<220 || gains[0+:9]>256) $fatal(1,"pressure response/saturation");
 samples[0+:14]=20;publish();tail=gains[0+:9];clocks(1000);if(keys || gains[0+:9]!=tail) $fatal(1,"release tail gain");
 $display("PASS pressure gain smoothing: immediate onset, held +/-3 raw-code jitter produces <=12 gain-code span instead of 24, pressure response and frozen release gain");$finish;
 end
endmodule
