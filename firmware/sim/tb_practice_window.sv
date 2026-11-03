`timescale 1ns/1ps
module tb_practice_window;
reg clk=0;always #5 clk=~clk;reg reset_n=0,tick=0,cv=0;reg [1:0] command=0;reg [31:0] keys=0;reg [255:0] notes;
wire [15:0] score;wire [5:0] hits,misses;wire [2:0] feedback;
practice32 dut(.clk(clk),.reset_n(reset_n),.tick(tick),.bpm(8'd120),.song(2'd0),.note_numbers(notes),.command_valid(cv),.command(command),.halt(1'b0),.keys(keys),.upload_ready(1'b0),.upload_length(8'd0),.uploaded_note(8'd255),.uploaded_duration(8'd4),.score(score),.hits(hits),.misses(misses),.feedback(feedback));
task cmd(input [1:0] c);begin @(negedge clk);command=c;cv=1;@(negedge clk);cv=0;repeat(6)@(negedge clk);end endtask
task sample;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(3)@(negedge clk);end endtask
integer i;
initial begin for(i=0;i<32;i++)notes[i*8+:8]=60+i;repeat(3)@(negedge clk);reset_n=1;
 cmd(1);repeat(1000)sample();keys=1;repeat(4)@(negedge clk);if(score!=100||hits!=1||feedback!=1)$fatal(1,"PERFECT timing window");
 keys=0;cmd(0);cmd(1);repeat(3000)sample();keys=1;repeat(4)@(negedge clk);if(score!=50||hits!=1||feedback!=2)$fatal(1,"GOOD timing window");
 keys=0;cmd(0);cmd(1);repeat(8000)sample();keys=1;repeat(4)@(negedge clk);if(score!=0||hits!=0||misses!=1||feedback!=3)$fatal(1,"late miss");
 repeat(15000)sample();if(misses!=1)$fatal(1,"late press double-counted miss");
 $display("PASS practice_window: production sample timing, 60ms PERFECT, 150ms GOOD, late MISS and no duplicate miss");$finish;
end endmodule
