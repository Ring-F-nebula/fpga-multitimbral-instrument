`timescale 1ns/1ps
// Active-high comparator outputs: blocked beam=1, illuminated=0.
// The shared 16-key engine uses chromatic indices; the seven strings use C major.
module laser_inputs #(parameter STABLE_CYCLES=13125)(
 input wire clk,reset_n,input wire [6:0] beam_broken,
 output wire [6:0] notes,output wire [15:0] keys
);
 input_filter #(.WIDTH(7),.STABLE_CYCLES(STABLE_CYCLES)) filter(
  .clk(clk),.reset_n(reset_n),.async_in(beam_broken),.stable_out(notes));
 assign keys=(notes[0]?16'h0001:16'h0000) |
             (notes[1]?16'h0004:16'h0000) |
             (notes[2]?16'h0010:16'h0000) |
             (notes[3]?16'h0020:16'h0000) |
             (notes[4]?16'h0080:16'h0000) |
             (notes[5]?16'h0200:16'h0000) |
             (notes[6]?16'h0800:16'h0000);
endmodule
