// Control-rate MIDI conversion. One ROM refreshes 32 independent step words.
// A changed MIDI slot reaches the cache within 33 fabric clocks.
module note_step_cache(input clk,input [255:0] notes,output [767:0] steps);
 reg [4:0] index=0,index_q=0;reg [7:0] note_q=0;
 wire [23:0] converted;
 midi_step_rom convert(.note(note_q),.step(converted));
 always @(posedge clk)begin
  note_q<=notes[index*8+:8];index_q<=index;index<=index+1'b1;
 end
 genvar voice;generate for(voice=0;voice<32;voice=voice+1)begin: cached_voice
  reg [23:0] word /* synthesis syn_preserve=1 */ =0;
  always @(posedge clk)if(index_q==voice)word<=converted;
  assign steps[voice*24+:24]=word;
 end endgenerate
endmodule
