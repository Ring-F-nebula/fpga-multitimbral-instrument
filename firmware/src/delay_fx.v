`timescale 1ns/1ps
// 8192 samples = 179.755886 ms at the merged 45572.9167 Hz rate. Clear at startup at system-clock speed, then
// read/write only at sample_tick. A separate read port infers true block RAM.
module delay_fx #(parameter ADDRESS_BITS=13)(
 input wire clk, reset_n, sample_tick, enable,
 input wire signed [15:0] dry,
 output reg signed [15:0] wet, output wire ready
);
 reg signed [15:0] memory [0:(1<<ADDRESS_BITS)-1];
 reg [ADDRESS_BITS-1:0] pointer;
 reg clearing;
 reg signed [15:0] delayed;
 wire signed [16:0] feedback=$signed(dry)+($signed(delayed)>>>1);
 wire signed [16:0] combined=($signed(dry)>>>1)+($signed(delayed)>>>1);
 function [15:0] clip;
  input signed [16:0] x;
  begin if(x>32767) clip=16'h7fff;
   else if(x< -32768) clip=16'h8000;
   else clip=x[15:0]; end
 endfunction
 assign ready=~clearing;
 // No reset on RAM/read register: contents are explicitly cleared before use.
 always @(posedge clk) begin
  delayed<=memory[pointer];
  if(clearing) memory[pointer]<=0;
  else if(sample_tick) memory[pointer]<=enable ? clip(feedback) : dry;
 end
 always @(posedge clk or negedge reset_n) begin
  if(!reset_n) begin pointer<=0; clearing<=1; wet<=0; end
  else if(clearing) begin
   pointer<=pointer+1'b1; wet<=0;
   if(&pointer) clearing<=0;
  end else if(sample_tick) begin
   pointer<=pointer+1'b1;
   wet<=enable ? clip(combined) : dry;
  end
 end
endmodule
