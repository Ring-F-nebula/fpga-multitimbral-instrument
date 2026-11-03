`timescale 1ns/1ps
// Export actual RTL effects output; the dry excitation is a synthetic phrase.
// Not a hardware recording. Five 2.5 s sections: dry, delay, chorus, reverb, all.
module tb_audio_render;
reg clk=0;always #5 clk=~clk;
reg reset_n=0,tick=0;reg signed [15:0] dry=0;wire signed [15:0] wet;wire valid,ready;
reg [127:0] p=0;
audio_effects dut(.clk(clk),.reset_n(reset_n),.sample_tick(tick),.enable(1'b0),.dry(dry),.params(p),.wet(wet),.valid(valid),.ready(ready));
integer file,i,section,n,amp,nonzero;real fs=26250000.0/576.0,t,age,hz,x,pi=3.141592653589793;
task sample(input integer value);
begin @(negedge clk);dry=value;tick=1;@(negedge clk);tick=0;wait(valid);@(negedge clk);end endtask
initial begin
 file=$fopen("audio_fx_demo.raw","wb");if(!file)$fatal(1,"export file");
 p[15:8]=28;p[23:16]=140;p[31:24]=110;p[39:32]=9;p[47:40]=70;p[55:48]=128;
 p[63:56]=65;p[71:64]=4;p[79:72]=140;
 for(section=0;section<5;section++)begin
  case(section)0:p[7:0]=0;1:p[7:0]=1;2:p[7:0]=2;3:p[7:0]=4;4:p[7:0]=7;endcase
  reset_n=0;repeat(4)@(negedge clk);reset_n=1;wait(ready);repeat(300)sample(0);nonzero=0;
  for(i=0;i<113932;i++)begin
   t=i/fs;age=t-$floor(t/0.24)*0.24;n=$rtoi(t/0.24);
   case(n%4)0:hz=261.625565;1:hz=329.627557;2:hz=391.995436;3:hz=523.251131;endcase
   x=t<0.96?( $sin(2*pi*hz*age)+0.22*$sin(4*pi*hz*age)) * $exp(-age*16) * (age<0.003?age/0.003:1):0;
   amp=$rtoi(12500*x);sample(amp);
   if($isunknown(wet))$fatal(1,"unknown exported sample");if(wet!=0)nonzero++;
   $fwrite(file,"%c%c",wet[7:0],wet[15:8]);
  end
  if(nonzero<40000)$fatal(1,"missing audio section %d",section);
 end
 $fclose(file);$display("PASS audio_render: five RTL dry/effect sections exported, 569660 valid PCM samples");$finish;
end
endmodule
