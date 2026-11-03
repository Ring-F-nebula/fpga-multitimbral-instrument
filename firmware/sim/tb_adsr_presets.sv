`timescale 1ns/1ps
// Compare audible-time envelope differences using the real production ADSR.
// Samples, thresholds and checks are independent of the DUT's duration table.
module tb_adsr_presets;
 reg clk=0;always #5 clk=~clk;
 reg clear=1,gate=0;
 `include "adsr_presets.vh"
 wire [15:0] level[0:2];wire [2:0] state[0:2];
 genvar p;generate for(p=0;p<3;p=p+1)begin: preset
  wire [7:0] a=adsr_preset_value(p,0),d=adsr_preset_value(p,1),s=adsr_preset_value(p,2),r=adsr_preset_value(p,3);
  adsr_envelope dut(.clk(clk),.tick(1'b1),.clear(clear),.gate(gate),
   .attack_sel(a[3:0]),.decay_sel(d[3:0]),.sustain_level(s),.release_sel(r[3:0]),.level(level[p]),.state(state[p]));
 end endgenerate
 task step;begin @(posedge clk);#1;@(negedge clk);end endtask
 initial begin
  @(negedge clk);step();clear=0;gate=1;step();
  repeat(2300)step(); // About 50 ms: clearly different attack transients.
  if(level[1]<32000||level[1]>34000||level[0]<16000||level[0]>17000||level[2]<3200||level[2]>3400)$fatal(1,"50ms envelope separation");
  repeat(11700)step(); // About 307 ms: short note is silent while still held.
  if(level[1]!=0||level[0]<61000||level[0]>63000||level[2]<20000||level[2]>20500)$fatal(1,"307ms decay separation");
  repeat(22458)step(); // About 800 ms: soft has settled, swell is still rising.
  if(level[0]!=49344||state[0]!=3||level[1]!=0||level[2]<52200||level[2]>52600||state[2]!=1)$fatal(1,"800ms sustain/swell");
  repeat(36458)step(); // About 1.6s: full sustained pad vs 75% soft.
  if(level[0]!=49344||level[1]!=0||level[2]!=65535)$fatal(1,"held sustain contrast");
  gate=0;step();
  repeat(22786)step(); // About 500 ms into release, long tails remain.
  if(level[1]!=0||level[0]<24600||level[0]>24750||level[2]<32700||level[2]>32850)$fatal(1,"long release tails");
  repeat(22789)step();
  if(level[0]!=0||level[1]!=0||level[2]!=0)$fatal(1,"release stuck");
  $display("PASS adsr_presets: distinct 50/307/800/1600ms envelope shapes, zero-sustain short note, 75/100 percent holds, 1s tails and clean silence");$finish;
 end
 initial begin #5000000;$fatal(1,"ADSR preset timeout");end
endmodule
