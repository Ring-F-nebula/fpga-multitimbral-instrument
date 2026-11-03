`timescale 1ns/1ps
module tb_guitar_rom;
 GSR GSR(1'b1);
 reg clk=0;always #5 clk=~clk;
 reg [23:0] phase=0,step=0;reg [7:0] brightness=0;
 wire signed [12:0] value;
 guitar_wave_table dut(.clk(clk),.enable(1'b1),.phase(phase),.step(step),.brightness(brightness),.value(value));
 reg signed [15:0] reference_words[0:8191];
 integer bank,p,b,body,attack,wanted;
 initial begin
  $readmemh("src/guitar_wave.hex",reference_words);
  for(bank=0;bank<3;bank=bank+1)begin
   step=bank==0?100000:bank==1?200000:400000;
   for(b=0;b<3;b=b+1)begin
    brightness=b==0?0:b==1?128:255;
    for(p=0;p<1024;p=p+1)begin
     @(negedge clk);phase=p<<14;repeat(5)@(negedge clk);
     body=reference_words[bank*1024+p];attack=reference_words[(bank+3)*1024+p];
     wanted=body+(((attack-body)*int'(brightness))>>>8);
     if(value!==wanted)$fatal(1,"guitar SP/phase/blend mismatch bank%0d phase%0d bright%0d got%0d expected%0d",bank,p,brightness,value,wanted);
     if(value>1900||value< -1900)$fatal(1,"guitar table peak bound");
    end
   end
  end
  $display("PASS guitar_rom: all 1024 phases, 3 harmonic banks, 3 spectral blend levels, initialized hardware SP contents and signed peak bound");$finish;
 end
 initial begin #2000000;$fatal(1,"guitar ROM timeout");end
endmodule
