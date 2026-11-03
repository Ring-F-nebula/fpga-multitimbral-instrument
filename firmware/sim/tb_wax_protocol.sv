`timescale 1ns/1ps
module tb_wax_protocol;
reg clk=0;always #5 clk=~clk;reg rst=0,rx=1;
wire valid,err,frame,ack,ackok;wire [7:0] byte_data,model;wire [383:0] samples;wire [15:0] good,bad;
wax_uart_rx #(.BIT_CLOCKS(8)) u(clk,rst,rx,valid,byte_data,err);
wax_packet #(.GAP_CYCLES(300)) p(clk,rst,valid,err,byte_data,frame,samples,model,good,bad,ack,ackok);
integer frames=0,acks=0;always @(posedge clk)begin if(frame)frames++;if(ack)acks++;end
task octet(input [7:0] b);integer j;begin
 @(negedge clk);rx=0;repeat(8)@(negedge clk);
 for(j=0;j<8;j++)begin rx=b[j];repeat(8)@(negedge clk);end
 rx=1;repeat(8)@(negedge clk);
end endtask
task packet(input [7:0] kind,input integer corrupt,tail);integer j;reg [7:0] sum,b;begin
 octet('haa);octet('h55);octet(kind);octet(48);sum=0;
 for(j=0;j<48;j++)begin b=(j*37+170)&255;octet(b);sum=sum+b;end
 octet(sum^corrupt);octet(tail);repeat(10)@(negedge clk);
end endtask
integer i;reg [23:0] expect_code;
initial begin
 repeat(4)@(negedge clk);rst=1;repeat(4)@(negedge clk);
 // Payload deliberately contains AA / 55; must not resync inside good data.
 packet(1,0,13);if(frames!=1||good!=1||model!=1)$fatal(1,"valid 54-byte packet lost");
 for(i=0;i<16;i++)begin expect_code={8'((i*3*37+170)&255),8'(((i*3+1)*37+170)&255),8'(((i*3+2)*37+170)&255)};if(samples[i*24+:24]!==expect_code)$fatal(1,"BE24 order/channel %d",i);end
 packet(1,1,13);packet(1,0,12);packet(4,0,13);
 if(frames!=1||bad<3)$fatal(1,"bad checksum/tail/3x3 accepted");
 octet('haa);octet('h55);octet(0);octet(1);octet(13);repeat(8)@(negedge clk);if(acks!=1||!ackok)$fatal(1,"ACK parse");
 octet('haa);octet('h55);octet(1);octet(48);octet(0);repeat(400)@(negedge clk);
 packet(3,0,13);if(frames!=2||model!=3)$fatal(1,"truncation recovery");
 rx=0;repeat(100)@(negedge clk);rx=1;repeat(20)@(negedge clk);
 packet(8,0,13);if(frames!=3||model!=8)$fatal(1,"break recovery");
 $display("PASS wax_protocol: actual 8N1 wire, BE24 16 channels, checksum/tail/model rejection, ACK, byte-gap and break recovery");$finish;
end
initial begin #1000000;$fatal(1,"protocol timeout");end
endmodule
