// Four fixed hardware lanes, eight independently stored voice states per lane.
// Expensive glide/pitch multipliers are shared; the caller keeps 32 physical NCOs.
module frequency_bank4(input clk,clear,frame_tick,input [31:0] keys,
 input [255:0] notes,input glide_enable,input [3:0] glide_time,
 input [16:0] coefficient,input [4:0] target_voice,input expression_enable,
 output [767:0] phase_steps,output reg done=0,overrun=0);
 wire [767:0] cached_steps;note_step_cache cache(.clk(clk),.notes(notes),.steps(cached_steps));
 reg [767:0] base_snapshot=0;reg [31:0] keys_snapshot=0,attacks=0,previous_keys=0;
 reg [16:0] coefficient_snapshot=65536;reg [4:0] target_snapshot=0,newest_snapshot=0;
 reg enable_snapshot=0,expression_snapshot=0,legato_snapshot=0;
 reg [23:0] last_step=96315,from_snapshot=96315;
 reg [15:0] duration_snapshot=456,reciprocal_snapshot=36792;
 reg [3:0] state=0;reg [2:0] slot=0;
 wire [31:0] new_keys=keys&~previous_keys;reg [4:0] newest;integer n;
 always @*begin newest=0;for(n=0;n<32;n=n+1)if(new_keys[n])newest=n;end
 function [15:0] duration;input [3:0] t;begin case(t)
  0:duration=456;1:duration=911;2:duration=1823;3:duration=3646;4:duration=5469;
  5:duration=9115;6:duration=13672;7:duration=22786;8:duration=34180;default:duration=45573;
 endcase end endfunction
 function [15:0] reciprocal;input [3:0] t;begin case(t)
  0:reciprocal=36792;1:reciprocal=18416;2:reciprocal=9203;3:reciprocal=4601;4:reciprocal=3067;
  5:reciprocal=1840;6:reciprocal=1227;7:reciprocal=736;8:reciprocal=490;default:reciprocal=368;
 endcase end endfunction
 wire [95:0] lane_bases;
 always @(posedge clk)begin
  done<=0;
  if(clear)begin state<=0;slot<=0;previous_keys<=0;overrun<=0;keys_snapshot<=0;attacks<=0;last_step<=96315;end
  else begin
   if(frame_tick&&state!=0)overrun<=1;
   case(state)
    0:if(frame_tick)begin
     base_snapshot<=cached_steps;keys_snapshot<=keys;attacks<=new_keys;previous_keys<=keys;
     coefficient_snapshot<=coefficient;target_snapshot<=target_voice;expression_snapshot<=expression_enable;
     enable_snapshot<=glide_enable;duration_snapshot<=duration(glide_time);reciprocal_snapshot<=reciprocal(glide_time);
     from_snapshot<=last_step;newest_snapshot<=newest;
     legato_snapshot<=new_keys!=0&&((new_keys&(new_keys-32'd1))==0)&&(|(keys&previous_keys));
     slot<=0;state<=1;
    end
    1:state<=2;2:state<=3;3:state<=4;4:state<=5;5:state<=6;
    6:begin
     if(attacks!=0&&newest_snapshot[4:2]==slot)last_step<=lane_bases[newest_snapshot[1:0]*24+:24];
     if(slot==7)state<=7;else begin slot<=slot+1'b1;state<=1;end
    end
    7:begin done<=1;state<=0;end
    default:state<=0;
   endcase
  end
 end
 genvar lane,k;
 generate for(lane=0;lane<4;lane=lane+1)begin: lanes
  wire [191:0] lane_steps;
  frequency_lane8 #(.LANE(lane)) pipe(.clk(clk),.clear(clear),.state(state),.slot(slot),
   .base_snapshot(base_snapshot),.keys_snapshot(keys_snapshot),.attacks(attacks),
   .enable(enable_snapshot),.legato(legato_snapshot),.from_step(from_snapshot),
   .duration(duration_snapshot),.reciprocal(reciprocal_snapshot),
   .coefficient(coefficient_snapshot),.target_voice(target_snapshot),.expression_enable(expression_snapshot),
   .steps(lane_steps),.base_value(lane_bases[lane*24+:24]));
  for(k=0;k<8;k=k+1)begin: outputs
   assign phase_steps[(k*4+lane)*24+:24]=lane_steps[k*24+:24];
  end
 end endgenerate
endmodule

module frequency_lane8 #(parameter integer LANE=0)(input clk,clear,input [3:0] state,input [2:0] slot,
 input [767:0] base_snapshot,input [31:0] keys_snapshot,attacks,input enable,legato,
 input [23:0] from_step,input [15:0] duration,reciprocal,input [16:0] coefficient,
 input [4:0] target_voice,input expression_enable,output [191:0] steps,output [23:0] base_value);
 // Local scheduling registers bound control fanout and avoid a Gowin 1.9.11.03
 // inference crash when four lanes share unregistered state/slot directly.
 // The last result is committed on the same edge as the parent's done pulse;
 // consumers use it on the following clock, before the next audio frame.
 reg [3:0] state_q /* synthesis syn_preserve=1 */ =0;
 reg [2:0] slot_q /* synthesis syn_preserve=1 */ =0;
 always @(posedge clk)begin state_q<=clear?0:state;slot_q<=slot;end
 // Eight small state rows per lane; registered logic avoids a global 32-way mux.
 wire [97:0] memory[0:7];
 localparam [97:0] EMPTY={32'd0,32'd0,16'd0,1'b0,17'd65536};
 reg [97:0] read_word=0,old_word=EMPTY,next_word=EMPTY;reg [7:0] valid=0;reg read_valid=0;
 reg [191:0] step_words=0;reg [23:0] base_q=0;reg attack_q=0,selected_q=0;
 localparam [1:0] LANE_ID=LANE;wire [4:0] voice_id={slot_q,LANE_ID};
 wire [31:0] old_value=old_word[97:66],old_rate=old_word[65:34];
 wire [15:0] old_remaining=old_word[33:18];wire old_rising=old_word[17];wire [16:0] old_smooth=old_word[16:0];
 wire [23:0] local_base[0:7];wire [7:0] local_attack;
 genvar j;generate for(j=0;j<8;j=j+1)begin: addresses
  assign local_base[j]=base_snapshot[(j*4+LANE)*24+:24];assign local_attack[j]=attacks[j*4+LANE];
  reg [97:0] row /* synthesis syn_preserve=1 */ =0;
  always @(posedge clk)if(!clear&&state_q==6&&slot_q==j)row<=next_word;
  assign memory[j]=row;
 end endgenerate
 reg [23:0] glide_step=0,distance=0;reg [16:0] target=65536,smooth_next=65536;
 reg [39:0] glide_product=0;reg [40:0] pitch_product=0;
 reg [31:0] value_next,rate_next;reg [15:0] remaining_next;reg rising_next;
 always @*begin
  value_next=old_value;rate_next=old_rate;remaining_next=old_remaining;rising_next=old_rising;
  if(!enable)begin value_next={base_q,8'd0};remaining_next=0;end
  else if(attack_q)begin
   if(legato)begin value_next={from_step,8'd0};rate_next={8'd0,glide_product[39:16]};remaining_next=duration;rising_next=base_q>=from_step;end
   else begin value_next={base_q,8'd0};remaining_next=0;end
  end else if(old_remaining!=0)begin
   remaining_next=old_remaining-1'b1;
   if(old_remaining==1)value_next={base_q,8'd0};else value_next=old_rising?old_value+old_rate:old_value-old_rate;
  end else value_next={base_q,8'd0};
 end
 always @(posedge clk)read_word<=memory[slot_q];
 always @(posedge clk)begin
  if(clear)begin valid<=0;step_words<=0;read_valid<=0;old_word<=EMPTY;next_word<=EMPTY;end
  else case(state_q)
   1:begin base_q<=local_base[slot_q];read_valid<=valid[slot_q];attack_q<=local_attack[slot_q];selected_q<=target_voice==voice_id;end
   2:old_word<=read_valid?read_word:EMPTY;
   3:begin
    glide_step<=enable&&old_remaining!=0?old_value[31:8]:base_q;
    distance<=base_q>from_step?base_q-from_step:from_step-base_q;
    target<=expression_enable&&selected_q?coefficient:17'd65536;
   end
   4:begin
    glide_product<=distance*reciprocal;pitch_product<=glide_step*old_smooth+41'd32768;
    if(target>old_smooth)smooth_next<=target-old_smooth>32?old_smooth+17'd32:target;
    else if(target<old_smooth)smooth_next<=old_smooth-target>32?old_smooth-17'd32:target;else smooth_next<=old_smooth;
   end
   5:next_word<={value_next,rate_next,remaining_next,rising_next,smooth_next};
   6:begin valid[slot_q]<=1;step_words[slot_q*24+:24]<=pitch_product[39:16];end
  endcase
 end
 assign steps=step_words;assign base_value=base_q;
endmodule
