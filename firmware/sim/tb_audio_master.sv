`timescale 1ns/1ps
module tb_audio_master;
 reg clk=0;always #5 clk=~clk;
 reg reset_n=0,tick=0,mute=0;reg [3:0] volume=8;
 reg signed [15:0] source=24000;wire signed [15:0] result;
 audio_master dut(clk,reset_n,tick,mute,volume,source,result);
 task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
 integer v,i,previous,expected,scaled,mag;
 function integer reference_gain(input integer x,vol);
  integer n,m;
  begin
   n=$rtoi($floor(real'(x)*real'(vol)/8.0));m=n<0?-n:n;
   if(m>22528)m=22528+$rtoi($floor(real'(m-22528)/4.0));
   reference_gain=n<0?-m:m;
  end
 endfunction
 initial begin
  repeat(3)@(negedge clk);reset_n=1;
  for(v=0;v<16;v++)begin
   volume=v;source=24000;repeat(260)frame();
   if(result!=reference_gain(24000,v))$fatal(1,"positive master level %0d got %0d",v,result);
   source=-24000;frame();if(result!=reference_gain(-24000,v))$fatal(1,"negative master level");
   source=6000;frame();if(result!=750*v)$fatal(1,"low-level +6dB gain curve");
  end
  // All signed 16-bit PCM values at maximum gain: monotonic and no wrap.
  volume=15;source=0;repeat(260)frame();previous=-32768;
  for(i=-32768;i<=32767;i++)begin
   source=i;frame();expected=reference_gain(i,15);
   if(result!=expected||result<previous||result>32256||result< -32256)$fatal(1,"full-domain peak protection x=%0d got=%0d",i,result);
   previous=result;
  end
  source=24000;volume=15;repeat(260)frame();previous=result;volume=0;
  for(i=0;i<245;i++)begin frame();if(result>previous||previous-result>188)$fatal(1,"gain change discontinuity");previous=result;end
  if(result!=0)$fatal(1,"volume zero not exact silence");
  volume=15;repeat(260)frame();mute=1;previous=result;
  for(i=0;i<128;i++)begin frame();if(result>previous||previous-result>256)$fatal(1,"hard mute discontinuity");previous=result;end
  if(result!=0)$fatal(1,"mute residual");
  mute=0;previous=0;repeat(245)begin frame();if(result<previous||result-previous>188)$fatal(1,"unmute discontinuity");previous=result;end
  $display("PASS audio_master: +6.02dB low-level gain at all 16 settings, exhaustive signed 16-bit PCM monotonic peak protection, exact silence and bounded mute/unmute");$finish;
 end
endmodule
