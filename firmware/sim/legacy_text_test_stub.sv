// Test-only: instrument_screen.PANEL_UI=1 never selects the old text-cell bus.
// Replace only that inactive branch to stay below ModelSim ASE's design cap.
// The native panel renderer, its text ROM, PCM/FFT/XY paths remain production.
module legacy_text_test_stub #(parameter integer LENGTH=1,OX=0,OY=0,SCALE=0)(
 input clk,visible,input [10:0] x,input [9:0] y,input [319:0] text,output pixel);
 assign pixel=1'b0;
endmodule

module legacy_game_test_stub(input clk,frame_start,visible,input [10:0] raster_x,
 input [9:0] raster_y,input running,finished,input [15:0] score,keys,cue_keys,
 input [5:0] combo,max_combo,hits,misses,progress,input [9:0] wrong,
 input [2:0] feedback,input [1:0] countdown,input [3:0] target_note,next_note,volume,
 output [23:0] pixel_color);
 assign pixel_color=24'd0;
endmodule

module legacy_decimal_test_stub(input clk,input [15:0] value,output [31:0] text);
 assign text="0000";
endmodule
