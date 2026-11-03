// WAX official protocol: AA 55 model 30 [16 x unsigned BE24] sum(data) 0D.
// Full, verified packets only. ACK (AA5500xx0D), unsupported sensor models,
// truncated frames, bad checksum and framing errors cannot update pressure.
module wax_packet #(parameter integer GAP_CYCLES=131250)(
 input clk,reset_n,byte_valid,byte_error,input [7:0] byte_data,
 output reg frame_valid=0,output reg [383:0] pressures=0,
 output reg [7:0] model=0,output reg [15:0] good_frames=0,bad_frames=0,
 output reg ack_valid=0,ack_ok=0);
 reg [2:0] state=0;reg [5:0] index=0;
 reg [7:0] kind=0,sum=0;reg [383:0] work_data=0;
 reg [23:0] word_shift=0;reg [1:0] part=0;reg [3:0] channel=0;
 reg [$clog2(GAP_CYCLES+1)-1:0] gap=0;reg ack_bit=0;
 wire supported=kind==1||kind==2||kind==3||kind==7||kind==8;
 always @(posedge clk)begin
  frame_valid<=0;ack_valid<=0;
  if(!reset_n)begin state<=0;pressures<=0;model<=0;good_frames<=0;bad_frames<=0;gap<=0;end
  else if(byte_error)begin state<=0;gap<=0;bad_frames<=bad_frames+1'b1;end
  else if(byte_valid)begin
   gap<=0;
   case(state)
    0:if(byte_data==8'haa)state<=1;
    1:if(byte_data==8'h55)state<=2;else state<=byte_data==8'haa ?1:0;
    2:begin kind<=byte_data;state<=3;end
    3:if(kind==0)begin ack_bit<=byte_data==1;state<=7;end
      else if(byte_data==48&&supported)begin
       index<=0;channel<=0;part<=0;word_shift<=0;sum<=0;work_data<=0;state<=4;
      end else begin bad_frames<=bad_frames+1'b1;state<=byte_data==8'haa ?1:0;end
    4:begin
       sum<=sum+byte_data;word_shift<={word_shift[15:0],byte_data};
       if(part==2)begin work_data[channel*24+:24]<={word_shift[15:0],byte_data};channel<=channel+1'b1;part<=0;end
       else part<=part+1'b1;
       if(index==47)state<=5;else index<=index+1'b1;
      end
    5:if(byte_data==sum)state<=6;else begin bad_frames<=bad_frames+1'b1;state<=byte_data==8'haa ?1:0;end
    6:begin
       if(byte_data==13)begin pressures<=work_data;model<=kind;frame_valid<=1;good_frames<=good_frames+1'b1;end
       else bad_frames<=bad_frames+1'b1;
       state<=byte_data==8'haa ?1:0;
      end
    7:begin if(byte_data==13)begin ack_valid<=1;ack_ok<=ack_bit;end else bad_frames<=bad_frames+1'b1;state<=byte_data==8'haa ?1:0;end
    default:state<=0;
   endcase
  end else if(state!=0)begin
   if(gap==GAP_CYCLES-1)begin state<=0;gap<=0;bad_frames<=bad_frames+1'b1;end
   else gap<=gap+1'b1;
  end
 end
endmodule
