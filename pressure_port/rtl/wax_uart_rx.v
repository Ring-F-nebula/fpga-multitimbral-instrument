// Fixed-baud 115200 8N1, 26.25 MHz fabric clock. Center start/data/stop
// sampling. A framing error never publishes a byte; a break waits for idle.
module wax_uart_rx #(parameter integer BIT_CLOCKS=228)(
 input clk,reset_n,rx,output reg valid=0,output reg [7:0] data=0,
 output reg error=0);
 (* async_reg="true" *) reg [1:0] sync=3;
 reg [2:0] state=0,bit_index=0;reg [15:0] timer=0;reg [7:0] shift=0;
 always @(posedge clk)begin
  sync<={sync[0],rx};valid<=0;error<=0;
  if(!reset_n)begin sync<=3;state<=0;timer<=0;data<=0;shift<=0;end
  else case(state)
   0:if(!sync[1])begin timer<=BIT_CLOCKS/2-1;state<=1;end
   1:if(timer!=0)timer<=timer-1'b1;else if(sync[1])state<=0;
     else begin timer<=BIT_CLOCKS-1;bit_index<=0;state<=2;end
   2:if(timer!=0)timer<=timer-1'b1;else begin
     shift[bit_index]<=sync[1];timer<=BIT_CLOCKS-1;
     if(bit_index==7)state<=3;else bit_index<=bit_index+1'b1;
    end
   3:if(timer!=0)timer<=timer-1'b1;else if(sync[1])begin data<=shift;valid<=1;state<=0;end
     else begin error<=1;state<=4;end
   4:if(sync[1])state<=0;
   default:state<=0;
  endcase
 end
endmodule
