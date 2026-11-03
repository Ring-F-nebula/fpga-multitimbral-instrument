// V4/V5 compatibility plus checksummed V6 full performance/event telemetry.
module competition_status #(parameter integer PERIOD=2625000,ENABLE_WAX=0)(input clk,input [11:0] bit_clocks,input [335:0] payload,
 input [783:0] wax,input [127:0] fx,input [7:0] fx_revision,input [7:0] flags,
 input [15:0] rx_count,serial_keys,live_keys,active_envelopes,peak,phase0,frame_count,
 input [7:0] last_byte,envelope0,attack,decay,sustain,release_time,param_count,input [3:0] volume,
 input audio_request,input [8:0] audio_block,input [17:0] audio_count,input audio_recording,audio_available,
 input [15:0] audio_data,output reg [16:0] audio_address=0,output audio_busy,audio_waiting,
 output tx);
 reg [823:0] packet=0;reg [2:0] kind=0;reg [2:0] state=0;
 reg [9:0] index=0,length=40;reg audio_pending=0;reg [8:0] pending_block=0,dump_block=0;reg [8:0] dump_samples=0;reg [7:0] running_crc=0;reg [21:0] timer=0;reg start=0;reg [7:0] data=0;
 wire busy;uart_tx sender(clk,start,data,bit_clocks,tx,busy);
 always @(posedge clk)audio_address<={dump_block,8'd0}+((index>=8?index-8:0)>>1);
 assign audio_busy=(kind==3);assign audio_waiting=audio_pending;
 reg [7:0] dump_byte;
 always @*case(index)
  0:dump_byte=8'ha5;1:dump_byte=8'h5a;2:dump_byte=7;3:dump_byte=8'h66;
  4:dump_byte=dump_block[7:0];5:dump_byte={7'd0,dump_block[8]};6:dump_byte=dump_samples[7:0];7:dump_byte={7'd0,dump_samples[8]};
  default:dump_byte=index==length-1?running_crc:(index[0]?audio_data[15:8]:audio_data[7:0]);
 endcase
 integer i;reg [7:0] checksum;
 always @*begin checksum=0;for(i=2;i<102;i=i+1)if(i<length-1)checksum=checksum^packet[i*8+:8];end
 always @(posedge clk)begin
  start<=0;
  if(audio_request&&!audio_recording&&{1'b0,audio_block,8'd0}<audio_count)begin audio_pending<=1;pending_block<=audio_block;end
  case(state)
   0:if(audio_pending&&audio_available)begin
       audio_pending<=0;dump_block<=pending_block;kind<=3;timer<=0;state<=1;
       dump_samples<=audio_count-{pending_block,8'd0}>=256?9'd256:audio_count-{pending_block,8'd0};
      end else if(timer==PERIOD-1)begin timer<=0;packet<=0;state<=1;end else timer<=timer+1'b1;
   1:begin
    packet<=0;packet[7:0]<=8'ha5;packet[15:8]<=8'h5a;
    if(kind==0)begin
     length<=40;packet[23:16]<=4;packet[31:24]<=flags;packet[47:32]<=rx_count;packet[55:48]<=last_byte;
     packet[71:56]<=serial_keys;packet[87:72]<=live_keys;packet[103:88]<=live_keys;packet[127:120]<=volume;
     packet[143:128]<=bit_clocks;packet[175:160]<=peak;packet[183:176]<=128;
     packet[199:184]<=active_envelopes;packet[215:200]<=phase0;packet[223:216]<=envelope0;
     packet[239:224]<=frame_count;packet[247:240]<=8'h66;packet[255:248]<=attack;packet[263:256]<=decay;
     packet[271:264]<=sustain;packet[279:272]<=release_time;packet[311:304]<=param_count;
    end else if(kind==1)begin length<=22;packet[23:16]<=5;packet[31:24]<=8'h66;packet[39:32]<=fx_revision;packet[167:40]<=fx;end
    else if(kind==2)begin length<=48;packet[23:16]<=6;packet[31:24]<=8'h66;packet[367:32]<=payload;end
    else if(kind==4)begin length<=103;packet[23:16]<=8;packet[31:24]<=8'h66;packet[815:32]<=wax;end
    if(kind==3)begin length<=9+{dump_samples,1'b0};index<=0;running_crc<=0;state<=6;end else state<=2;
   end
   2:begin packet[(length-1)*8+:8]<=checksum;index<=0;state<=3;end
   3:if(!busy)begin
     data<=kind==3?dump_byte:packet[index*8+:8];start<=1;state<=4;
     if(kind==3&&index>=2&&index<length-1)running_crc<=running_crc^dump_byte;
    end
   4:if(busy)state<=5;
   5:if(!busy)begin
    if(index==length-1)begin if(kind==3)begin kind<=0;state<=1;end else if(kind==2&&ENABLE_WAX)begin kind<=4;state<=1;end else if(kind==2||kind==4)begin kind<=0;state<=0;end else begin kind<=kind+1'b1;state<=1;end end
    else begin index<=index+1'b1;state<=6;end
   end
   6:state<=7;
   7:state<=3;
  endcase
 end
endmodule
