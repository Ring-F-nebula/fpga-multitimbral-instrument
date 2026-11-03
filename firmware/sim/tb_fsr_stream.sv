`timescale 1ns/1ps
module tb_fsr_stream;
 reg clk=0;always #5 clk=~clk;reg reset_n=0,online=0,toggle=0;
 reg [223:0] samples={16{14'd20}};reg [15:0] mask=0;
 wire [15:0] keys,cal;wire ready,fault;wire [143:0] gains;
 fsr_keyboard #(.STREAMING(1),.CALIBRATION_LOG2(1)) dut(.clk(clk),.reset_n(reset_n),.sample_tick(1'b1),
 .recalibrate(1'b0),.samples_async(samples),.update_mask_async(mask),.peak_async(14'd0),
 .frame_toggle_async(toggle),.online_async(online),.keys(keys),.gains(gains),.ready(ready),.fault(fault),.calibrated_mask(cal));
 task publish(input integer ch);@(negedge clk);mask=16'b1<<ch;toggle=~toggle;repeat(30) @(negedge clk);endtask
 task sweep;for(integer c=0;c<16;c=c+1) publish(c);endtask
 initial begin
 repeat(3) @(negedge clk);reset_n=1;online=1;repeat(5) @(negedge clk);repeat(5) sweep();
 if(!ready || cal!=16'hffff || keys) $fatal(1,"stream calibration");
 samples[0+:14]=36;publish(0);if(keys) $fatal(1,"single observation");
 for(integer c=1;c<16;c=c+1) begin publish(c);if(keys) $fatal(1,"stale pad confirmed by another channel");end
 publish(0);if(keys!=1 || gains[0+:9]!=64) $fatal(1,"second fresh observation must publish immediately");
 samples[0+:14]=20;publish(0);if(keys) $fatal(1,"release should not wait for sweep end");
 samples[4*14+:14]=100;publish(4);samples[4*14+:14]=20;publish(4);if(keys) $fatal(1,"single spike");
 samples={16{14'd120}};
 for(integer c=0;c<16;c=c+1) begin publish(c);if(keys) $fatal(1,"coherent offset produced initial noise");end
 if(!fault) $fatal(1,"common-mode first-visit guard");
 samples={16{14'd20}};repeat(6) sweep();if(!ready || fault || keys) $fatal(1,"recover");
 for(integer c=0;c<6;c=c+1) publish(c);samples={16{14'd120}};
 for(integer c=6;c<16;c=c+1) begin publish(c);if(keys) $fatal(1,"wrapped coherent step");end
 for(integer c=0;c<6;c=c+1) begin publish(c);if(keys) $fatal(1,"wrapped coherent step before second visit");end
 if(!fault) $fatal(1,"wrapped common-mode guard");
 samples={16{14'd20}};repeat(6) sweep();samples[0+:14]=36;samples[4*14+:14]=52;repeat(2) sweep();
 if(keys!=3 || gains[0+:9]!=64 || gains[9+:9]!=128) $fatal(1,"independent pressure chord");
 online=0;repeat(8) @(negedge clk);if(keys || ready) $fatal(1,"source loss");
 $display("PASS streaming keys: fresh-channel-only two-observation onset, immediate release, isolated spikes, common-mode guard before first note including wrap, independent velocity and source loss");$finish;
 end
endmodule
