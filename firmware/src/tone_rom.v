// One synchronous read port. The fixed mixer schedule reuses it four times
// per voice: two neighboring phases for each of body and attack waveforms.
module tone_rom(input clk,input [13:0] address,output reg signed [15:0] value=0);
 reg signed [15:0] words[0:16383] /* synthesis syn_romstyle="block_rom" */;
 initial $readmemh("src/tone_rom.hex",words);
 always @(posedge clk)value<=words[address];
endmodule
