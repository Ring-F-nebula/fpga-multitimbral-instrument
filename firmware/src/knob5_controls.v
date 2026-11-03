// Read-modify-write against authoritative registers. Queue every detent while
// touch/UART owns the command bus; never replace a live parameter with a shadow.
module knob5_controls #(parameter integer FILTER_CYCLES=13125,BUTTON_CYCLES=262500)(
 input clk,reset_n,input [4:0] a_n,b_n,sw_n,input grant,
 input [3:0] volume,attack,decay,release_time,input [7:0] sustain,
 input signed [8:0] bend,input [127:0] fx,
 output commit,output reg [7:0] id,value,output reg [1:0] envelope_selection=0);
 wire [4:0] cw,ccw,press;genvar g;
 generate for(g=0;g<5;g=g+1)begin:encoders
  ec11_decoder #(.FILTER_CYCLES(FILTER_CYCLES)) decoder(clk,a_n[g],b_n[g],cw[g],ccw[g]);
  button_press #(.DEBOUNCE_CYCLES(BUTTON_CYCLES)) button(clk,sw_n[g],press[g]);
 end endgenerate
 reg signed [8:0] pending[0:4];reg [4:0] pushed=0;
 reg [2:0] state=0,pick=0,owner=0,round_robin=0;
 reg signed [2:0] saved_direction=1;reg saved_press=0;
 reg found,chosen_press;reg signed [2:0] direction;
 reg [7:0] first_id=0,first_value=0,second_id=0,second_value=0;
 reg [1:0] length=0;reg flag_value=0;reg [2:0] flag_bit=0;
 integer i,j,k,next_count,current,next_value;
 always @*begin
  found=0;pick=0;
  for(j=0;j<5;j=j+1)begin k=round_robin+j;if(k>=5)k=k-5;
   if(!found&&(pending[k]!=0||pushed[k]))begin found=1;pick=k;end
  end
  chosen_press=pushed[pick];direction=pending[pick]>0?1:-1;
 end
 wire take=state==0&&found&&grant;
 // If a higher-priority writer arrives before the relative update commits,
 // put the detent back and reread the authoritative registers on retry.
 // State 2 has only committed the idempotent bend-target selection; state 3
 // has already applied the step and must never requeue it a second time.
 wire retry=(state==1||state==2)&&!grant;
 assign commit=grant&&state!=0;
 always @*begin
  id=first_id;value=first_value;
  if(state==2)begin id=second_id;value=second_value;end
  if(state==3)begin id=8'h10;value=(fx[7:0]&~(8'd1<<flag_bit))|({7'd0,flag_value}<<flag_bit);end
 end
 always @(posedge clk)begin
  if(!reset_n)begin
   state<=0;pushed<=0;round_robin<=0;envelope_selection<=0;
   for(i=0;i<5;i=i+1)pending[i]<=0;
  end else begin
   for(i=0;i<5;i=i+1)begin
    next_count=$signed(pending[i])+(cw[i]?1:0)-(ccw[i]?1:0);
    if(take&&pick==i&&!chosen_press)next_count=next_count-direction;
    if(retry&&owner==i&&!saved_press)next_count=next_count+$signed(saved_direction);
    pending[i]<=next_count>127?127:next_count< -127?-127:next_count;
    pushed[i]<=(pushed[i]&&!(take&&pick==i&&chosen_press))||press[i]||(retry&&owner==i&&saved_press);
   end
   if(retry)state<=0;
   else if(take)begin
    owner<=pick;round_robin<=pick==4?0:pick+1'b1;state<=1;length<=1;
    saved_direction<=direction;saved_press<=chosen_press;
    case(pick)
     0:begin first_id<=5;next_value=chosen_press?8:$signed({1'b0,volume})+$signed(direction);first_value<=next_value<0?0:next_value>15?15:next_value;end
     1:begin
      first_id<=8'h1d;first_value<=32;second_id<=8'h24;
      next_value=chosen_press?100:100+$signed(bend)/2+direction*5;
      second_value<=next_value<0?0:next_value>200?200:next_value;
      length<=3;flag_bit<=6;flag_value<=0;
     end
     2:begin
      current=fx[3]?fx[87:80]:0;next_value=chosen_press?0:current+direction;
      if(next_value<0)next_value=0;if(next_value>9)next_value=9;
      first_id<=8'h1a;first_value<=next_value;length<=2;flag_bit<=3;flag_value<=next_value!=0;
     end
     3:begin
      current=fx[4]?fx[103:96]:0;next_value=chosen_press?0:current+direction*5;
      if(next_value<0)next_value=0;if(next_value>100)next_value=100;
      first_id<=8'h1c;first_value<=next_value;length<=2;flag_bit<=4;flag_value<=next_value!=0;
     end
     4:if(chosen_press)begin envelope_selection<=envelope_selection+1'b1;state<=0;end
      else begin
       case(envelope_selection)
        0:begin first_id<=1;current=attack;end
        1:begin first_id<=2;current=decay;end
        2:begin first_id<=3;current=sustain;end
        3:begin first_id<=4;current=release_time;end
       endcase
       next_value=current+direction*(envelope_selection==2?8:1);
       if(next_value<0)next_value=0;
       if(next_value>(envelope_selection==2?255:9))next_value=envelope_selection==2?255:9;
       first_value<=next_value;
      end
    endcase
   end else if(commit)begin
    if(state==1&&length==3)state<=2;
    else if(state==1&&length==2||state==2)state<=3;
    else state<=0;
   end
  end
 end
endmodule
