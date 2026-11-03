`timescale 1ns/1ps
module tb_event_recorder;
reg clk=0;always #5 clk=~clk;reg reset_n=0,tick=0,cv=0;reg [1:0] command=0;reg [31:0] keys=0;reg [8:0] query=0;
wire recording,playing,overflow;wire [9:0] count;wire [31:0] qtime,qkeys,played;
event_recorder dut(.clk(clk),.reset_n(reset_n),.tick(tick),.keys(keys),.command_valid(cv),.command(command),.halt(1'b0),.query_index(query),.query_time(qtime),.query_keys(qkeys),.recording(recording),.playing(playing),.overflow(overflow),.count(count),.playback_keys(played));
task cmd(input [1:0] c);begin @(negedge clk);command=c;cv=1;@(negedge clk);cv=0;repeat(3)@(negedge clk);end endtask
task sample;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(4)@(negedge clk);end endtask
integer i,heard1=0,heard3=0;
initial begin repeat(3)@(negedge clk);reset_n=1;repeat(4)@(negedge clk);if(qtime!==0||qkeys!==0)$fatal(1,"empty query exposes uninitialized memory");cmd(1);repeat(5)sample();keys=1;sample();repeat(9)sample();keys=3;sample();repeat(9)sample();keys=0;sample();cmd(0);sample();
 if(count!=4||recording)$fatal(1,"event count/final release");query=0;repeat(4)@(negedge clk);if(qtime!=5||qkeys!=1)$fatal(1,"first event data");query=1;repeat(4)@(negedge clk);if(qtime!=15||qkeys!=3)$fatal(1,"second event data");
 cmd(2);repeat(40)begin sample();if(played==1)heard1++;if(played==3)heard3++;end
 if(playing||played!=0||heard1<8||heard3<8)$fatal(1,"sample-timed replay");
 cmd(1);keys=0;for(i=0;i<513;i++)begin keys=~keys;sample();end
 if(!overflow||recording||count!=512)$fatal(1,"bounded event buffer");query=511;repeat(4)@(negedge clk);if(qkeys!=0)$fatal(1,"overflow final release");
 cmd(3);if(count||playing||recording)$fatal(1,"clear");$display("PASS event_recorder: actual note masks/sample timestamps, readback, replay, final release, 512-event overflow and clear");$finish;
end endmodule
