`timescale 1ns/1ps
module tb_practice32;
reg clk=0;always #5 clk=~clk;reg reset_n=0,tick=0,cv=0;reg [1:0] command=0,song=0;reg [7:0] bpm=120;reg [31:0] keys=0;reg [255:0] notes;
wire running,paused,finished,gate;wire [31:0] cue;wire [7:0] progress,length;wire [23:0] step;wire [6:0] address;
reg [7:0] unote=31,udur=4;
practice32 #(.TEMPO_THRESHOLD(480)) dut(.clk(clk),.reset_n(reset_n),.tick(tick),.bpm(bpm),.song(song),.note_numbers(notes),.command_valid(cv),.command(command),.halt(1'b0),.keys(keys),.upload_ready(1'b1),.upload_length(8'd2),.uploaded_note(unote),.uploaded_duration(udur),.read_address(address),.running(running),.paused(paused),.finished(finished),.gate(gate),.step(step),.cue(cue),.progress(progress),.length(length));
task cmd(input [1:0] c);begin @(negedge clk);command=c;cv=1;@(negedge clk);cv=0;repeat(6)@(negedge clk);end endtask
task sample;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(6)@(negedge clk);end endtask
integer i,n;reg [7:0] old_progress;
initial begin for(i=0;i<32;i++)notes[i*8+:8]=60+i;repeat(3)@(negedge clk);reset_n=1;
 for(n=0;n<3;n++)begin song=n;cmd(1);if(!running||gate||cue==0)$fatal(1,"offline start");
  cmd(2);old_progress=progress;repeat(20)sample();if(progress!=old_progress||gate||!paused)$fatal(1,"pause timeline");cmd(3);
  for(i=0;i<500&&running;i++)begin keys=0;sample();keys=cue;sample();end
  if(!finished||progress!=length||running||gate)$fatal(1,"complete built-in song %d",n);
 end
 song=3;cmd(1);if(cue!==32'h80000000||gate||length!=2)$fatal(1,"uploaded upper voice");
 cmd(0);if(running||gate)$fatal(1,"stop");bpm=60;song=2;cmd(1);repeat(6)sample();if(progress!=0)$fatal(1,"tempo scaling too fast");repeat(4)sample();if(progress!=1)$fatal(1,"tempo scaling slow");
 $display("PASS practice32: silent visual cues for three melodies, fractional BPM, pause/resume, completion, uploaded upper note and stop");$finish;
end endmodule
