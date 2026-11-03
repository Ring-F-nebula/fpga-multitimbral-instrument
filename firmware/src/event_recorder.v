// Note-event recording only: timestamped 32-bit note masks, not PCM recording.
module event_recorder(input clk,reset_n,tick,input [31:0] keys,input command_valid,input [1:0] command,
 input halt,auto_trigger,input [8:0] query_index,output reg [31:0] query_time=0,query_keys=0,output reg [8:0] query_index_valid=0,
 output reg recording=0,playing=0,overflow=0,has_notes=0,output reg [15:0] duration_seconds=0,
 output reg [9:0] count=0,output reg [31:0] playback_keys=0);
 reg armed=0;reg [15:0] second_samples=0;
 reg [63:0] events[0:511];reg [31:0] clock_samples=0,last_keys=0,play_time=0;
 reg [9:0] query_count=0;reg [8:0] query_tag=0;reg query_valid=0;reg [8:0] play_index=0;reg [63:0] read_q=0;wire [63:0] fetched=read_q;reg [1:0] state=0;reg stop_pending=0;
 // One physical write port lets synthesis infer synchronous block RAM.
 wire write_event=reset_n&&tick&&recording&&((stop_pending&&count<512)||(!stop_pending&&keys!=last_keys));
 wire [8:0] write_address=stop_pending?count[8:0]:count<511?count[8:0]:9'd511;
 wire [63:0] write_data={clock_samples,(stop_pending||count>=511)?32'd0:keys};
 always @(posedge clk)if(write_event)events[write_address]<=write_data;
 always @(posedge clk)begin read_q<=events[playing?play_index:query_index];query_valid<=!playing;if(!playing)begin query_tag<=query_index;query_count<=count;if(query_valid)begin query_time<={1'b0,query_tag}<query_count?read_q[63:32]:32'd0;query_keys<={1'b0,query_tag}<query_count?read_q[31:0]:32'd0;query_index_valid<=query_tag;end end end
 always @(posedge clk)begin
  if(!reset_n)begin recording<=0;playing<=0;overflow<=0;count<=0;playback_keys<=0;state<=0;stop_pending<=0;clock_samples<=0;armed<=0;has_notes<=0;duration_seconds<=0;second_samples<=0;end
  else begin
   if(halt)begin playing<=0;playback_keys<=0;if(recording)stop_pending<=1;end
   if(command_valid)case(command)
    0:begin if(recording)stop_pending<=1;playing<=0;playback_keys<=0;end
    1:begin recording<=1;playing<=0;count<=0;overflow<=0;clock_samples<=0;last_keys<=0;playback_keys<=0;stop_pending<=0;
      armed<=(auto_trigger===1'b1);has_notes<=0;duration_seconds<=0;second_samples<=0;end
    2:if(count!=0)begin recording<=0;playing<=1;play_index<=0;play_time<=0;playback_keys<=0;state<=1;end
    3:begin recording<=0;playing<=0;count<=0;overflow<=0;playback_keys<=0;stop_pending<=0;armed<=0;has_notes<=0;duration_seconds<=0;second_samples<=0;end
   endcase
   if(tick)begin
    if(recording)begin
     if(!armed||keys!=0)begin
      clock_samples<=clock_samples+1'b1;armed<=0;
      if(second_samples==45572)begin second_samples<=0;if(duration_seconds!=65535)duration_seconds<=duration_seconds+1'b1;end
      else second_samples<=second_samples+1'b1;
     end
     if(write_event&&write_data[31:0]!=0)has_notes<=1;
     if(stop_pending)begin
      if(count<512)begin count<=count+1'b1;end else overflow<=1;
      recording<=0;stop_pending<=0;last_keys<=0;armed<=0;
     end else if(keys!=last_keys)begin
      if(count<511)begin count<=count+1'b1;last_keys<=keys;end
      else begin count<=512;recording<=0;overflow<=1;end
     end
    end
    if(playing)begin
     play_time<=play_time+1'b1;
     if(state==2 && play_time>=fetched[63:32])begin
      playback_keys<=fetched[31:0];
      if({1'b0,play_index}+1>=count)begin playing<=0;playback_keys<=0;end
      else begin play_index<=play_index+1'b1;state<=1;end
     end
    end
   end
   if(playing&&state==1)state<=2;
  end
 end
endmodule
