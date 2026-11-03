`timescale 1ns/1ps
// Two-flop CDC, followed by consecutive-stability filtering. No derived clocks.
module input_filter #(parameter WIDTH=1, parameter STABLE_CYCLES=3125)(
 input wire clk, reset_n, input wire [WIDTH-1:0] async_in,
 output reg [WIDTH-1:0] stable_out
);
 reg [WIDTH-1:0] meta, sync;
 reg [15:0] count [0:WIDTH-1];
 integer i;
 always @(posedge clk or negedge reset_n) begin
  if(!reset_n) begin
   meta<=0; sync<=0; stable_out<=0;
   for(i=0;i<WIDTH;i=i+1) count[i]<=0;
  end else begin
   meta<=async_in; sync<=meta;
   for(i=0;i<WIDTH;i=i+1) begin
    if(sync[i]==stable_out[i]) count[i]<=0;
    else if(count[i]==STABLE_CYCLES-1) begin
     count[i]<=0; stable_out[i]<=sync[i];
    end else count[i]<=count[i]+1'b1;
   end
  end
 end
endmodule
