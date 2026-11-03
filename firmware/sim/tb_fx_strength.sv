`timescale 1ns/1ps
// Compare the shipped default effect settings with the previous release using
// real production effect memories, interpolation, feedback and LFOs.
module tb_fx_strength;
 reg clk=0;always #5 clk=~clk;
 reg reset_n=0,tick=0,commit=0;reg [7:0] id=0,value=0;
 wire [127:0] params;wire signed [15:0] current,previous;
 reg signed [15:0] dry=0;wire ready_c,ready_p,valid_c,valid_p;
 reg [127:0] old_params={8'd0,8'd100,8'd32,8'd18,8'd50,8'd3,8'd64,8'd4,8'd45,8'd51,8'd30,8'd8,8'd64,8'd90,8'd18,8'd0};
 fx_registers registers(.clk(clk),.reset_n(reset_n),.usb_commit(1'b0),.bt_commit(1'b0),.usb_id(8'd0),.usb_value(8'd0),.bt_id(8'd0),.bt_value(8'd0),.ui_commit(commit),.ui_id(id),.ui_value(value),.stopped(1'b0),.snapshot(params));
 audio_effects current_fx(.clk(clk),.reset_n(reset_n),.sample_tick(tick),.enable(1'b0),.dry(dry),.params(params),.wet(current),.valid(valid_c),.ready(ready_c));
 audio_effects previous_fx(.clk(clk),.reset_n(reset_n),.sample_tick(tick),.enable(1'b0),.dry(dry),.params(old_params),.wet(previous),.valid(valid_p),.ready(ready_p));
 task sample(input integer x);integer cycles;begin
  @(negedge clk);dry=x;tick=1;@(negedge clk);tick=0;cycles=0;
  while(!(valid_c&&valid_p)&&cycles<32)begin @(negedge clk);cycles++;end
  if(!valid_c||!valid_p||$isunknown({current,previous}))$fatal(1,"effect deadline or unknown PCM");
  @(negedge clk);
 end endtask
 task write(input [7:0] a,b);begin @(negedge clk);id=a;value=b;commit=1;@(negedge clk);commit=0;end endtask
 task reset_effect(input [7:0] flags);begin
  reset_n=0;repeat(3)@(negedge clk);reset_n=1;
  write('h10,flags);old_params[7:0]=flags;
  wait(ready_c&&ready_p);repeat(300)sample(0);
 end endtask
 integer i,source,echo_c,echo_p;real old_diff,new_diff,old_tail,new_tail,delta;
 initial begin
  repeat(3)@(negedge clk);reset_n=1;repeat(3)@(negedge clk);
  if(params[119:0]!={8'd100,8'd32,8'd35,8'd55,8'd5,8'd115,8'd5,8'd70,8'd115,8'd70,8'd12,8'd102,8'd128,8'd24,8'd0})$fatal(1,"power-on strong defaults");
  reset_effect(1);echo_c=0;echo_p=0;
  for(i=0;i<22000;i++)begin
   sample(i==0?12000:0);
   if(i==8203)echo_p=previous;
   if(i==10938)echo_c=current;
  end
  if(echo_p!=3000||echo_c<4770||echo_c>4790)$fatal(1,"strong delay first echoes old=%0d new=%0d",echo_p,echo_c);
  reset_effect(2);old_diff=0;new_diff=0;
  for(i=0;i<60000;i++)begin
   source=$rtoi(6000.0*$sin(6.28318530718*440.0*i/45572.9166667)+3000.0*$sin(6.28318530718*659.255*i/45572.9166667));
   sample(source);
   if(i>8000)begin delta=previous-source;old_diff+=delta*delta;delta=current-source;new_diff+=delta*delta;end
  end
  if(new_diff<old_diff*2.0)$fatal(1,"chorus default contrast too small %f",new_diff/old_diff);
  reset_effect(4);old_tail=0;new_tail=0;
  for(i=0;i<70000;i++)begin
   sample(i==0?12000:0);
   if(i>20000)begin delta=previous;old_tail+=delta*delta;delta=current;new_tail+=delta*delta;end
  end
  if(old_tail<=0||new_tail<old_tail*2.0)$fatal(1,"reverb default tail contrast too small %f",new_tail/old_tail);
  write('h10,36);repeat(300)sample(0);sample(1234);if(current!=1234)$fatal(1,"global bypass lost unity");
  $display("PASS fx_strength: real power-on defaults, delay echo %0d -> %0d, chorus difference-energy ratio=%f, reverb late-energy ratio=%f, bypass unity",echo_p,echo_c,new_diff/old_diff,new_tail/old_tail);$finish;
 end
 initial begin #100000000;$fatal(1,"FX strength timeout");end
endmodule
