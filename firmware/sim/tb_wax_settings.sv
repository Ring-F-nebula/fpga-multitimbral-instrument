`timescale 1ns/1ps
module tb_wax_settings;
reg clk=0;always #5 clk=~clk;reg rst=0,commit=0,frame=0,ack=0,ackok=0;reg [7:0] id=0,value=0,model=3;
wire recal,en,continuous,tx,configured;wire [15:0] onv,offv;wire [23:0] full;wire rv,re;wire [7:0] rd;
wax_settings dut(clk,rst,commit,id,value,frame,model,ack,ackok,recal,en,continuous,onv,offv,full,tx,configured);
wax_uart_rx #(.BIT_CLOCKS(228)) receiver(clk,rst,tx,rv,rd,re);
reg [7:0] received[0:31];integer n=0;always @(posedge clk)if(rv)begin received[n]=rd;n++;end
task write(input [7:0] a,b);begin @(negedge clk);id=a;value=b;commit=1;@(negedge clk);commit=0;repeat(4)@(negedge clk);end endtask
initial begin
 repeat(4)@(negedge clk);rst=1;@(negedge clk);frame=1;@(negedge clk);frame=0;
 wait(n==7);repeat(300)@(negedge clk);
 if(received[0]!='haa||received[1]!='h55||received[2]!=3||received[3]!=1||received[4]!=0||received[5]!=0||received[6]!=13||configured)$fatal(1,"range-preserving 100ms setup/ACK guard");
 ack=1;ackok=1;@(negedge clk);ack=0;repeat(3)@(negedge clk);if(!configured)$fatal(1,"ACK confirmation");
 frame=1;@(negedge clk);frame=0;repeat(20000)@(negedge clk);if(n!=7)$fatal(1,"reprogrammed every frame");
 write('h7a,2);wait(n==14);if(received[9]!=2)$fatal(1,"explicit sensor range setting");
 write('h75,8'h56);write('h76,8'h34);write('h77,8'h12);write('h71,30);write('h73,15);write('h79,0);
 if(full!='h123456||onv!=30||offv!=15||continuous)$fatal(1,"full 24bit sensitivity");
 write('h78,0);if(en)$fatal(1,"mute pressure input");
 $display("PASS wax_settings: real 115200 TX setup, 100ms interval, detected range retained, explicit range override, ACK gating, full-width thresholds/gain parameters");$finish;
end
initial begin #2000000;$fatal(1,"settings timeout");end
endmodule
