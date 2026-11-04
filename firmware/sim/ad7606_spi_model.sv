`timescale 1ns/1ps
// Independent behavioral slave: CS presents bit15, SCLK rising advances,
// FRST goes low after falling edge16. Non-DOUTA pins intentionally differ.
module ad7606_spi_model #(
 parameter integer FIRST_DELAY_NS=35,DATA_DELAY_NS=35
)(input reset,convst,cs_n,sclk,input [127:0] codes,
 input no_busy,stuck_busy,bad_first,disconnect,
 output wire busy,first,output wire [15:0] data);
 reg busy_i=0,first_i=0,sdo=0;
 reg [127:0] latched=0;
 integer falls=0,transactions=0,reset_epoch=0;
 assign busy=disconnect?1'b0:busy_i;
 assign first=disconnect?1'b0:(bad_first?1'b1:first_i);
 assign data[7]=cs_n||disconnect?1'bz:sdo;
 assign data[8]=cs_n||disconnect?1'bz:~sdo;
 assign data[6:0]=cs_n||disconnect?7'bz:7'h55;
 assign data[14:9]=cs_n||disconnect?6'bz:6'h2a;
 assign data[15]=1'bz;
 always @(posedge reset)begin
  reset_epoch=reset_epoch+1;busy_i=0;first_i=0;sdo=0;
 end
 always @(posedge convst)if(!reset&&!no_busy&&!disconnect)begin:conversion
  integer epoch;
  epoch=reset_epoch;
  #37;if(!reset&&epoch==reset_epoch)busy_i=1;
  #4000;
  if(!reset&&epoch==reset_epoch&&!stuck_busy)begin latched=codes;busy_i=0;end
 end
 always @(negedge cs_n)begin
  falls=0;
  if(busy_i||reset)$fatal(1,"SPI read while BUSY/reset");
  sdo<=#(DATA_DELAY_NS)latched[15];first_i<=#(FIRST_DELAY_NS)1;
 end
 always @(negedge sclk)if(!cs_n)begin
  falls=falls+1;
  if(falls>128)$fatal(1,"extra SPI falling clock");
  if(falls==16)first_i<=#(FIRST_DELAY_NS)0;
 end
 always @(posedge sclk)if(!cs_n)begin
  if(falls<1||falls>127)$fatal(1,"unexpected SPI rising edge");
  sdo<=#(DATA_DELAY_NS)latched[(falls/16)*16+15-(falls%16)];
 end
 always @(posedge cs_n)if(falls!=0)begin
  if(falls!=128&&!reset)$fatal(1,"incomplete SPI frame: %0d clocks",falls);
  if(falls==128)transactions=transactions+1;
  first_i<=#(FIRST_DELAY_NS)0;
 end
endmodule
