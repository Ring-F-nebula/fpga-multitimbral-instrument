// High E to low E. FF means a muted string, not a zero-pitch playable note.
function [7:0] guitar_note;
 input [2:0] chord;input [2:0] string_id;
 reg [47:0] voicing;
 begin
  case(chord)
   1:voicing={8'hff,8'd48,8'd52,8'd55,8'd60,8'd64}; // C: x32010
   2:voicing={8'd43,8'd47,8'd50,8'd55,8'd59,8'd67}; // G: 320003
   3:voicing={8'hff,8'd45,8'd52,8'd57,8'd60,8'd64}; // Am: x02210
   4:voicing={8'd41,8'd48,8'd53,8'd57,8'd60,8'd65}; // F: 133211
   5:voicing={8'hff,8'hff,8'd50,8'd57,8'd62,8'd65}; // Dm: xx0231
   6:voicing={8'd40,8'd47,8'd52,8'd55,8'd59,8'd64}; // Em: 022000
   default:voicing={8'd40,8'd45,8'd50,8'd55,8'd59,8'd64}; // Open: 000000
  endcase
  case(string_id)
   0:guitar_note=voicing[7:0];1:guitar_note=voicing[15:8];
   2:guitar_note=voicing[23:16];3:guitar_note=voicing[31:24];
   4:guitar_note=voicing[39:32];5:guitar_note=voicing[47:40];
   default:guitar_note=8'hff;
  endcase
 end
endfunction
