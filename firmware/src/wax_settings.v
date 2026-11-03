// Additional F5 parameter IDs 70..7A; existing piano protocol is unchanged.
// Model 0 auto-detects the first supported model. Set interval=100 ms only;
// never guess which load range the user purchased. TX command is 7 bytes.
module wax_settings(input clk,reset_n,commit,input [7:0] id,value,
 input frame_valid,input [7:0] detected_model,input ack_valid,ack_ok,
 output reg recalibrate=0,output reg enabled=1,continuous=1,
 output reg [15:0] on_delta=20,off_delta=10,
 output reg [23:0] full_scale=1000,
 output tx,output reg configured=0);
 reg [7:0] requested_model=0,pending_model=0,configured_model=0;
 reg configure_pending=0,start=0,wait_ack=0;reg [7:0] data=0;
 reg [2:0] state=0,index=0;wire busy;
 uart_tx sender(clk,start,data,12'd228,tx,busy);
 always @(posedge clk)begin
  start<=0;recalibrate<=0;
  if(!reset_n)begin
   enabled<=1;continuous<=1;on_delta<=20;off_delta<=10;full_scale<=1000;
   requested_model<=0;configured_model<=0;configured<=0;state<=0;configure_pending<=0;wait_ack<=0;
  end else begin
   if(ack_valid&&wait_ack)begin configured<=ack_ok;wait_ack<=0;end
   if(frame_valid&&detected_model!=configured_model&&state==0)begin
    pending_model<=requested_model!=0?requested_model:detected_model;configure_pending<=1;
   end
   if(commit)case(id)
    8'h70:recalibrate<=value[0];
    8'h71:begin on_delta[7:0]<=value;recalibrate<=1;end
    8'h72:begin on_delta[15:8]<=value;recalibrate<=1;end
    8'h73:begin off_delta[7:0]<=value;recalibrate<=1;end
    8'h74:begin off_delta[15:8]<=value;recalibrate<=1;end
    8'h75:full_scale[7:0]<=value;
    8'h76:full_scale[15:8]<=value;
    8'h77:full_scale[23:16]<=value;
    8'h78:begin enabled<=value[0];recalibrate<=1;end
    8'h79:continuous<=value[0];
    8'h7a:if(value==1||value==2||value==3||value==7||value==8)begin
     requested_model<=value;pending_model<=value;configure_pending<=1;configured<=0;recalibrate<=1;
    end
   endcase
   case(state)
    0:if(configure_pending)begin configure_pending<=0;configured_model<=pending_model;index<=0;state<=1;end
    1:if(!busy)begin
      case(index)0:data<=8'haa;1:data<=8'h55;2:data<=configured_model;3:data<=1;4,5:data<=0;6:data<=13;endcase
      start<=1;state<=2;
     end
    2:if(busy)state<=3;
    3:if(!busy)begin if(index==6)begin state<=0;wait_ack<=1;end else begin index<=index+1'b1;state<=1;end end
    default:state<=0;
   endcase
  end
 end
endmodule
