`timescale 1ns/1ps
module tb_audio_conditioner;
 reg clk=0;always #5 clk=~clk;reg reset_n=0,tick=0,active=1;
 reg signed [15:0] pcm=0;wire signed [15:0] out;wire idle;
 audio_conditioner dut(clk,reset_n,tick,active,pcm,out,idle);
 task frame(input integer value);@(negedge clk);pcm=value;tick=1;@(negedge clk);tick=0;endtask
 task reset;reset_n=0;repeat(3) @(negedge clk);reset_n=1;endtask
 real low_energy,high_energy;
 initial begin
 reset();low_energy=0;high_energy=0;
 for(integer i=0;i<5000;i=i+1) begin frame($rtoi(10000*$sin(6.28318530718*1000*i/45572.9167)));if(i>1000) low_energy=low_energy+$itor(out)*$itor(out);end
 reset();for(integer i=0;i<5000;i=i+1) begin frame($rtoi(10000*$sin(6.28318530718*12000*i/45572.9167)));if(i>1000) high_energy=high_energy+$itor(out)*$itor(out);end
 if(low_energy<1.4e11 || high_energy>low_energy*0.12) $fatal(1,"passband or high-frequency suppression");
 reset();repeat(8000) frame(8000);if(out>3 || out< -3) $fatal(1,"DC not rejected");
 reset();repeat(50) frame(32767);repeat(10) frame(-32768);if(out>=0) $fatal(1,"full-scale signed overflow");
 active=0;repeat(300) frame(0);if(!idle || out!==0) $fatal(1,"idle must be exact zero");
 repeat(1000) frame(0);if(out!==0) $fatal(1,"negative rounding limit cycle");
 active=1;frame(2000);if(idle || out==0) $fatal(1,"idle wakeup added holdoff");
 $display("PASS audio conditioner: 1kHz passband retained, 12kHz energy attenuated >9dB, DC rejected, full-scale sign safe, idle exact zero and immediate wakeup");$finish;
 end
endmodule
