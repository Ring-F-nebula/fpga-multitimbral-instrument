`timescale 1ns/1ps
module tb_audio_effects;
reg clk=0;always #5 clk=~clk;
reg reset_n=0,tick=0;reg signed [15:0] dry=0;wire signed [15:0] wet;wire valid,ready;
reg [127:0] p=0;
audio_effects dut(.clk(clk),.reset_n(reset_n),.sample_tick(tick),.enable(1'b0),.dry(dry),.params(p),.wet(wet),.valid(valid),.ready(ready));
integer i,cycles,seen,first,late,fd,peak;
longint energy_early,energy_late;
task sample(input integer x);
begin
 @(negedge clk);dry=x;tick=1;@(negedge clk);tick=0;cycles=0;
 while(!valid && cycles<32)begin @(negedge clk);cycles=cycles+1;end
 if(!valid || $isunknown(wet))$fatal(1,"invalid PCM or deadline missed");
 @(negedge clk);
end endtask
task reset;
begin
 @(negedge clk);reset_n=0;repeat(3)@(negedge clk);
 if(wet!==0)$fatal(1,"STOP did not mute");reset_n=1;
 wait(ready);@(negedge clk);
 for(integer n=0;n<300;n=n+1)sample(0);
end endtask
initial begin
 p[15:8]=1;p[23:16]=128;p[31:24]=128;
 p[39:32]=50;p[47:40]=100;p[55:48]=255;
 p[63:56]=45;p[71:64]=0;p[79:72]=200;
 reset();
 for(i=0;i<1000;i=i+1)begin sample((i*137)%60000-30000);if(wet!==dry)$fatal(1,"bypass not unity: %d %d",wet,dry);end
 p[7:0]=1;reset();
 for(i=0;i<1500;i=i+1)begin
  sample(i==0?16000:0);
  if(i==0 && wet!=8000)$fatal(1,"dry impulse gain %d",wet);
  if(i==456 && wet!=8000)$fatal(1,"first echo time/gain %d",wet);
  if(i==912 && wet!=4000)$fatal(1,"feedback echo %d",wet);
  if(i!=0 && i%456!=0 && wet!=0)$fatal(1,"unexpected echo at %d",i);
 end
 reset();for(i=0;i<1400;i=i+1)begin sample(0);if(wet!=0)$fatal(1,"tail survived STOP");end
 p[7:0]=2;reset();seen=0;first=99999;
 for(i=0;i<2200;i=i+1)begin sample(i==0?16000:0);if(i>0 && wet!=0)begin seen++;if(i<first)first=i;end end
 if(seen<2 || first<560 || first>980)$fatal(1,"chorus fractional taps absent %d %d",seen,first);
 p[7:0]=4;reset();energy_early=0;energy_late=0;seen=0;
 for(i=0;i<95000;i=i+1)begin
  sample(i==0?16000:0);
  if(i>1000 && wet!=0)seen++;
  if(i>1000 && i<15000)energy_early+=wet<0?-wet:wet;
  if(i>80000)energy_late+=wet<0?-wet:wet;
 end
 if(seen<100 || energy_early<1000 || energy_late!=0)$fatal(1,"reverb missing/unstable tail %d %d %d",seen,energy_early,energy_late);
 // Rapid bypass, parameter changes and full-scale excitation must stay known.
 p[7:0]=7;p[23:16]=230;p[71:64]=9;reset();
 for(i=0;i<4000;i=i+1)begin
   if(i==300)p[15:8]=100;
   if(i==900)p[7:0]=39;
   sample(i%2==0?32767:-32768);
   if(i>1200 && wet!==dry)$fatal(1,"dry A/B did not settle");
 end
 $display("PASS audio_effects: unity, 456/912-sample echoes, feedback, chorus taps, reverb decay, bypass and STOP");$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
