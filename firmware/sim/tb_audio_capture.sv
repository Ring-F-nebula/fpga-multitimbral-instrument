`timescale 1ns/1ps
module tb_audio_capture;
reg clk=0;always #5 clk=~clk;reg reset_n=0,tick=0,cv=0;reg [1:0] command=0;reg signed [15:0] pcm=0;reg [16:0] address=0;
wire [15:0] data;wire recording,full,armed;wire [17:0] count;
audio_capture dut(.clk(clk),.reset_n(reset_n),.tick(tick),.pcm(pcm),.command_valid(cv),.command(command),.read_address(address),.read_data(data),.recording(recording),.armed(armed),.full(full),.count(count));
task cmd(input [1:0] c);begin @(negedge clk);command=c;cv=1;@(negedge clk);cv=0;end endtask
integer i;
initial begin repeat(3)@(negedge clk);reset_n=1;cmd(1);
 for(i=0;i<131076;i++)begin @(negedge clk);pcm=i*19;tick=1;@(negedge clk);tick=0;end
 if(count!=131072||!full||recording)$fatal(1,"PCM full bound");
 for(i=0;i<131072;i=i+257)begin address=i;repeat(2)@(negedge clk);if(data!==((i*19)&65535))$fatal(1,"captured PCM differs at %d",i);end
 address=131071;repeat(2)@(negedge clk);if(data!==((131071*19)&65535))$fatal(1,"last sample");
 cmd(2);if(count||recording||full)$fatal(1,"clear");cmd(1);repeat(17)begin @(negedge clk);tick=1;@(negedge clk);tick=0;end cmd(0);repeat(8)@(negedge clk);
 if(count!=17||recording)$fatal(1,"short capture stop");cmd(3);pcm=0;repeat(100)begin @(negedge clk);tick=1;@(negedge clk);tick=0;end
 if(!armed||recording||count!=0)$fatal(1,"armed capture consumed silence");pcm=-123;@(negedge clk);tick=1;@(negedge clk);tick=0;
 if(armed||!recording||count!=1)$fatal(1,"first audible sample did not trigger capture");address=0;repeat(3)@(negedge clk);if(data!==16'hff85)$fatal(1,"trigger sample lost");cmd(0);
 $display("PASS audio_capture: actual signed PCM data, 131072-sample boundary, no overwrite, synchronous readback, short capture, clear and first-sound auto-trigger");$finish;
end endmodule
