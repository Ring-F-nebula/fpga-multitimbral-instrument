`timescale 1ns/1ps
// Actual production thresholds: low codes reported on the user's pad.
module tb_fsr_small_signal;
 reg clk=0;always #5 clk=~clk;
 reg reset_n=0,toggle=0,online=0,recalibrate=0;
 reg [223:0] samples={16{14'd20}};
 wire [15:0] keys,calibrated;wire [143:0] gains;
 wire ready,fault;wire [13:0] delta,threshold;reg [8:0] tail_gain;
 fsr_keyboard dut(.clk(clk),.reset_n(reset_n),.sample_tick(1'b1),.recalibrate(recalibrate),
 .samples_async(samples),.peak_async(14'd0),.frame_toggle_async(toggle),.online_async(online),
 .keys(keys),.gains(gains),.ready(ready),.fault(fault),.calibrated_mask(calibrated),
 .diagnostic_delta(delta),.diagnostic_threshold(threshold));
 task clocks(input integer n);repeat(n) @(negedge clk);endtask
 task publish;@(negedge clk);toggle=~toggle;clocks(30);endtask
 initial begin
 clocks(3);reset_n=1;online=1;clocks(5);repeat(34) publish();
 if(!ready || calibrated!=16'hffff || keys || fault) $fatal(1,"default calibration");
 // Idle +/- 3 codes, isolated spikes, and a subthreshold press remain silent.
 for(integer n=0;n<64;n=n+1) begin samples[0+:14]=17+n%7;publish();if(keys) $fatal(1,"small idle noise");end
 samples[0+:14]=100;publish();samples[0+:14]=20;publish();if(keys) $fatal(1,"isolated spike");
 samples[0+:14]=35;publish();publish();if(keys) $fatal(1,"below 16-code delta");
 samples[0+:14]=36;publish();if(keys) $fatal(1,"one scan is insufficient");publish();
 if(keys!=1 || gains[0+:9]!=64 || delta!=16 || threshold!=16) $fatal(1,"low-range pressure rejected");
 samples[4*14+:14]=52;publish();publish();clocks(300);
 if(keys!=3 || gains[0+:9]!=64 || gains[9+:9]!=128) $fatal(1,"independent small-signal gains");
 samples[0+:14]=84;publish();clocks(300);
 if(gains[0+:9]!=256 || gains[9+:9]!=128) $fatal(1,"independent full pressure");
 samples[0+:14]=29;publish();if(!keys[0]) $fatal(1,"hysteresis");
 samples[0+:14]=28;publish();if(keys!=2 || gains[0+:9]==0) $fatal(1,"release retains tail gain");
 tail_gain=gains[0+:9];clocks(100);if(gains[0+:9]!=tail_gain) $fatal(1,"tail gain changed after release");
 samples={16{14'd20}};publish();
 recalibrate=1;clocks(1);recalibrate=0;repeat(34) publish();
 if(keys || !ready || fault) $fatal(1,"recalibration");
 $display("PASS default small-signal FSR: raw 20->36 light onset, <100 raw full pressure, 16/8 hysteresis, noise/spike rejection, independent velocity and recalibration");$finish;
 end
endmodule
