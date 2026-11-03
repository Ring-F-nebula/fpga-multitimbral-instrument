function [7:0] instrument_note_at;
input [1:0] tone;input upper;input [2:0] chord;input analysis;input [10:0] px;input [9:0] py;
reg [7:0] note;begin instrument_note_at=0;note=255;
if(tone==0 && upper==1'd0 && px>=128 && px<225 && py>=404 && py<584)instrument_note_at=8'd128;
if(tone==0 && upper==1'd0 && px>=225 && px<323 && py>=404 && py<584)instrument_note_at=8'd130;
if(tone==0 && upper==1'd0 && px>=323 && px<421 && py>=404 && py<584)instrument_note_at=8'd132;
if(tone==0 && upper==1'd0 && px>=421 && px<519 && py>=404 && py<584)instrument_note_at=8'd133;
if(tone==0 && upper==1'd0 && px>=519 && px<616 && py>=404 && py<584)instrument_note_at=8'd135;
if(tone==0 && upper==1'd0 && px>=616 && px<714 && py>=404 && py<584)instrument_note_at=8'd137;
if(tone==0 && upper==1'd0 && px>=714 && px<812 && py>=404 && py<584)instrument_note_at=8'd139;
if(tone==0 && upper==1'd0 && px>=812 && px<910 && py>=404 && py<584)instrument_note_at=8'd140;
if(tone==0 && upper==1'd0 && px>=910 && px<1008 && py>=404 && py<584)instrument_note_at=8'd142;
if(tone==0 && upper==1'd0 && px>=193 && px<257 && py>=404 && py<516)instrument_note_at=8'd129;
if(tone==0 && upper==1'd0 && px>=291 && px<355 && py>=404 && py<516)instrument_note_at=8'd131;
if(tone==0 && upper==1'd0 && px>=487 && px<551 && py>=404 && py<516)instrument_note_at=8'd134;
if(tone==0 && upper==1'd0 && px>=584 && px<648 && py>=404 && py<516)instrument_note_at=8'd136;
if(tone==0 && upper==1'd0 && px>=682 && px<746 && py>=404 && py<516)instrument_note_at=8'd138;
if(tone==0 && upper==1'd0 && px>=878 && px<942 && py>=404 && py<516)instrument_note_at=8'd141;
if(tone==0 && upper==1'd0 && px>=976 && px<1008 && py>=404 && py<516)instrument_note_at=8'd143;
if(tone==0 && upper==1'd1 && px>=128 && px<216 && py>=404 && py<584)instrument_note_at=8'd128;
if(tone==0 && upper==1'd1 && px>=216 && px<304 && py>=404 && py<584)instrument_note_at=8'd129;
if(tone==0 && upper==1'd1 && px>=304 && px<392 && py>=404 && py<584)instrument_note_at=8'd131;
if(tone==0 && upper==1'd1 && px>=392 && px<480 && py>=404 && py<584)instrument_note_at=8'd133;
if(tone==0 && upper==1'd1 && px>=480 && px<568 && py>=404 && py<584)instrument_note_at=8'd135;
if(tone==0 && upper==1'd1 && px>=568 && px<656 && py>=404 && py<584)instrument_note_at=8'd136;
if(tone==0 && upper==1'd1 && px>=656 && px<744 && py>=404 && py<584)instrument_note_at=8'd138;
if(tone==0 && upper==1'd1 && px>=744 && px<832 && py>=404 && py<584)instrument_note_at=8'd140;
if(tone==0 && upper==1'd1 && px>=832 && px<920 && py>=404 && py<584)instrument_note_at=8'd141;
if(tone==0 && upper==1'd1 && px>=920 && px<1008 && py>=404 && py<584)instrument_note_at=8'd143;
if(tone==0 && upper==1'd1 && px>=272 && px<336 && py>=404 && py<516)instrument_note_at=8'd130;
if(tone==0 && upper==1'd1 && px>=360 && px<424 && py>=404 && py<516)instrument_note_at=8'd132;
if(tone==0 && upper==1'd1 && px>=448 && px<512 && py>=404 && py<516)instrument_note_at=8'd134;
if(tone==0 && upper==1'd1 && px>=624 && px<688 && py>=404 && py<516)instrument_note_at=8'd137;
if(tone==0 && upper==1'd1 && px>=712 && px<776 && py>=404 && py<516)instrument_note_at=8'd139;
if(tone==0 && upper==1'd1 && px>=888 && px<952 && py>=404 && py<516)instrument_note_at=8'd142;
if(tone==1 && px>=144 && px<992 && py>=428 && py<452)begin note=guitar_note(chord,3'd0);if(note!=255)instrument_note_at=8'd128+note-8'd40;end
if(tone==1 && px>=144 && px<992 && py>=452 && py<476)begin note=guitar_note(chord,3'd1);if(note!=255)instrument_note_at=8'd128+note-8'd40;end
if(tone==1 && px>=144 && px<992 && py>=476 && py<500)begin note=guitar_note(chord,3'd2);if(note!=255)instrument_note_at=8'd128+note-8'd40;end
if(tone==1 && px>=144 && px<992 && py>=500 && py<524)begin note=guitar_note(chord,3'd3);if(note!=255)instrument_note_at=8'd128+note-8'd40;end
if(tone==1 && px>=144 && px<992 && py>=524 && py<548)begin note=guitar_note(chord,3'd4);if(note!=255)instrument_note_at=8'd128+note-8'd40;end
if(tone==1 && px>=144 && px<992 && py>=548 && py<572)begin note=guitar_note(chord,3'd5);if(note!=255)instrument_note_at=8'd128+note-8'd40;end
if(tone==1 && px>=136 && px<252 && py>=376 && py<416)instrument_note_at=8'd43;
if(tone==1 && px>=260 && px<376 && py>=376 && py<416)instrument_note_at=8'd44;
if(tone==1 && px>=384 && px<500 && py>=376 && py<416)instrument_note_at=8'd45;
if(tone==1 && px>=508 && px<624 && py>=376 && py<416)instrument_note_at=8'd46;
if(tone==1 && px>=632 && px<748 && py>=376 && py<416)instrument_note_at=8'd47;
if(tone==1 && px>=756 && px<872 && py>=376 && py<416)instrument_note_at=8'd48;
if(tone==1 && px>=880 && px<996 && py>=376 && py<416)instrument_note_at=8'd49;
end endfunction
