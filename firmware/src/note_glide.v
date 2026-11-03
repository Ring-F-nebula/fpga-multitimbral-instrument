// Linear portamento. Start only on a legato attack selected by the caller.
module note_glide(input clk,tick,clear,enable,attack,legato,input [3:0] time_sel,
 input [23:0] base,from_step,output [23:0] step);
reg [31:0] value=0,rate=0;reg [15:0] remaining=0;reg rising=0;
reg [15:0] duration;reg [15:0] reciprocal;
always @* case(time_sel)
4'd0:begin duration=16'd456;reciprocal=16'd36792;end
4'd1:begin duration=16'd911;reciprocal=16'd18416;end
4'd2:begin duration=16'd1823;reciprocal=16'd9203;end
4'd3:begin duration=16'd3646;reciprocal=16'd4601;end
4'd4:begin duration=16'd5469;reciprocal=16'd3067;end
4'd5:begin duration=16'd9115;reciprocal=16'd1840;end
4'd6:begin duration=16'd13672;reciprocal=16'd1227;end
4'd7:begin duration=16'd22786;reciprocal=16'd736;end
4'd8:begin duration=16'd34180;reciprocal=16'd490;end
4'd9:begin duration=16'd45573;reciprocal=16'd368;end
default:begin duration=45573;reciprocal=368;end
endcase
wire [23:0] distance=base>from_step?base-from_step:from_step-base;
wire [39:0] product=distance*reciprocal;
assign step=(enable && remaining!=0)?value[31:8]:base;
always @(posedge clk) begin
 if(clear)begin value<=0;rate<=0;remaining<=0;rising<=0;end
 else if(tick)begin
  if(!enable)begin value<={base,8'd0};remaining<=0;end
  else if(attack)begin
   if(legato)begin value<={from_step,8'd0};rate<=product>>16;remaining<=duration;rising<=base>=from_step;end
   else begin value<={base,8'd0};remaining<=0;end
  end else if(remaining!=0)begin
   remaining<=remaining-1'b1;
   if(remaining==1)value<={base,8'd0};else if(rising)value<=value+rate;else value<=value-rate;
  end else value<={base,8'd0};
 end
end
endmodule
