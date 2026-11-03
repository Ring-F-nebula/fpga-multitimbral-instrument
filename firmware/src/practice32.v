// Sample-clock fractional tempo sequencer, local songs or validated event RAM.
// Visual cue/scoring only. gate/step ports remain for interface compatibility;
// gate is always low, so a practice timeline can never trigger audio.
module practice32 #(parameter integer TEMPO_THRESHOLD=2734375,ENABLE_PRESSURE_MODE=0,
 parameter integer PRESSURE_PERFECT_SAMPLES=13672,PRESSURE_GOOD_SAMPLES=27344)(input clk,reset_n,tick,input [7:0] bpm,input [1:0] song,
 input pressure_mode,pressure_ready,
 input [255:0] note_numbers,input command_valid,input [1:0] command,input halt,input [31:0] keys,
 input upload_ready,input [7:0] upload_length,input [7:0] uploaded_note,uploaded_duration,
 output [6:0] read_address,output reg running=0,paused=0,finished=0,
 output wire gate,output reg [23:0] step=0,output [31:0] cue,
 output reg [7:0] progress=0,output [7:0] length,output reg [15:0] score=0,
 output reg [5:0] combo=0,hits=0,misses=0,output reg [2:0] feedback=0,
 output [4:0] target_note,output [1:0] countdown,output signed [10:0] position);
 reg [1:0] selected_song=0;reg [7:0] index=0;reg [5:0] remaining=0;
 reg [23:0] tempo_acc=0;reg [31:0] previous_keys=0;reg judged=0;reg [1:0] state=0;
 reg [7:0] note_q=255,duration_q=4;reg [31:0] elapsed=0;
 assign gate=1'b0;
 wire [31:0] pressed=keys&~previous_keys;
 function [7:0] melody;
 input [1:0] which;input [7:0] n;
 begin
  if(which==0)case(n)
   0,1,13,28,29,41:melody=0;11,12,20,27,39,40:melody=2;9,10,18,19,25,26,37,38:melody=4;
   7,8,16,17,23,24,35,36:melody=5;2,3,6,14,15,21,22,30,31,34:melody=7;4,5,32,33:melody=9;default:melody=255;
  endcase
  else if(which==1)case(n)
   0,1,3,6,7,8,12,13:melody=4;2,5:melody=5;4:melody=7;9,10,14:melody=2;11:melody=0;default:melody=255;
  endcase
  else case(n)
   0,15:melody=0;1,14:melody=2;2,13:melody=4;3,12:melody=5;4,11:melody=7;5,10:melody=9;6,9:melody=11;7,8:melody=12;default:melody=255;
  endcase
 end endfunction
 function [7:0] duration;
 input [1:0] which;input [7:0] n;
 begin duration=4;if(which==0&&(n==6||n==13||n==20||n==27||n==34||n==41))duration=8;
 if(which==1&&n==14)duration=8;if(which==2&&n==15)duration=8;end endfunction
 wire [1:0] preview_song=running?selected_song:song;
 assign length=preview_song==0?42:preview_song==1?15:preview_song==2?16:upload_length;
 assign read_address=index[6:0];assign target_note=note_q[4:0];
 wire pressure_active=ENABLE_PRESSURE_MODE&&pressure_mode;
 wire source_ready=!pressure_active||pressure_ready;
 wire [31:0] perfect_limit=pressure_active?PRESSURE_PERFECT_SAMPLES:2734;
 wire [31:0] good_limit=pressure_active?PRESSURE_GOOD_SAMPLES:6836;
 assign cue=running&&!paused&&source_ready&&note_q<32?(32'h1<<note_q):32'd0;
 assign countdown=0;
 wire signed [31:0] moving=-$signed(elapsed>>7);
 assign position=moving< -64?-11'sd64:moving>600?11'sd600:moving[10:0];
 wire [23:0] note_step; midi_step_rom freq(.note(note_q<32?note_numbers[note_q*8+:8]:8'd0),.step(note_step));
 wire [24:0] next_tempo={1'b0,tempo_acc}+{15'd0,bpm,2'b00};
 always @(posedge clk)begin
  previous_keys<=keys;
  if(!reset_n)begin running<=0;paused<=0;finished<=0;state<=0;score<=0;progress<=0;tempo_acc<=0;end
  else begin
   if(halt||(selected_song==3&&!upload_ready))begin running<=0;paused<=0;end
   if(command_valid)case(command)
    0:begin running<=0;paused<=0;finished<=0;end
    1:if(song!=3||upload_ready)begin selected_song<=song;index<=0;progress<=0;score<=0;combo<=0;hits<=0;misses<=0;running<=1;paused<=0;finished<=0;tempo_acc<=0;state<=1;feedback<=0;judged<=0;end
    2:begin if(running)paused<=1;end
    3:if(running)begin paused<=0;end
   endcase
   if(running&&!paused&&!command_valid&&!halt&&source_ready)begin
    case(state)
     1:state<=2;
     2:begin note_q<=selected_song==3?uploaded_note:melody(selected_song,index);duration_q<=selected_song==3?uploaded_duration:duration(selected_song,index);state<=3;end
     3:begin step<=note_step;remaining<=duration_q[5:0];elapsed<=0;judged<=0;state<=0;
       feedback<=pressure_active?(note_q<16&&keys[note_q]?3'd5:3'd0):feedback;end
     0:begin
      if(pressed!=0&&!judged&&note_q<32)begin
       if(pressed==(32'h1<<note_q)&&(!pressure_active||keys==(32'h1<<note_q)))begin
        judged<=1;
        if(elapsed<=good_limit)begin score<=score+(elapsed<=perfect_limit?100:50);hits<=hits+1'b1;if(combo<63)combo<=combo+1'b1;feedback<=elapsed<=perfect_limit?1:2;end
        else begin misses<=misses+1'b1;combo<=0;feedback<=3;end
       end
       else begin combo<=0;feedback<=4;end
      end
      if(tick)begin
       elapsed<=elapsed+1'b1;
       if(next_tempo>=TEMPO_THRESHOLD)begin
        tempo_acc<=next_tempo-TEMPO_THRESHOLD;
        if(remaining<=1)begin
         
         if(!judged&&note_q<32)begin misses<=misses+1'b1;combo<=0;feedback<=3;end
         progress<=progress+1'b1;
         if(index+1>=length)begin running<=0;finished<=1;end
         else begin index<=index+1'b1;state<=1;end
        end else remaining<=remaining-1'b1;
       end else tempo_acc<=next_tempo;
      end
     end
    endcase
   end
  end
 end
endmodule
