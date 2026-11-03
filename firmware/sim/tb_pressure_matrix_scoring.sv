`timescale 1ns/1ps
module tb_pressure_matrix_scoring;
 reg clk=0;always #5 clk=~clk;reg reset_n=0,tick=0,cv=0,ready=1;
 reg [1:0] command=0;reg [31:0] keys=0;reg [255:0] notes;
 wire [15:0] score;wire [5:0] hits,misses;wire [2:0] feedback;wire [31:0] cue;wire gate;
 practice32 #(.ENABLE_PRESSURE_MODE(1)) dut(.clk(clk),.reset_n(reset_n),.tick(tick),.bpm(8'd60),.song(2'd0),
  .pressure_mode(1'b1),.pressure_ready(ready),.note_numbers(notes),.command_valid(cv),.command(command),.halt(1'b0),.keys(keys),
  .upload_ready(1'b0),.upload_length(8'd0),.uploaded_note(8'd255),.uploaded_duration(8'd4),
  .score(score),.hits(hits),.misses(misses),.feedback(feedback),.cue(cue),.gate(gate));
 task cmd(input [1:0] c);begin @(negedge clk);command=c;cv=1;@(negedge clk);cv=0;repeat(8)@(negedge clk);end endtask
 task sample;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(2)@(negedge clk);end endtask
 task key(input [31:0] mask);begin @(negedge clk);keys=mask;repeat(5)@(negedge clk);end endtask
 integer i;reg [31:0] saved;
 initial begin
  for(i=0;i<32;i++)notes[i*8+:8]=60+i;
  repeat(4)@(negedge clk);reset_n=1;cmd(1);
  if(cue!=1||gate)$fatal(1,"matrix cue must be visual only");
  key(2);if(feedback!=4||score||hits)$fatal(1,"wrong pressure cell");key(0);key(1);
  if(score!=100||hits!=1||feedback!=1)$fatal(1,"correct retry after wrong key");
  repeat(1000)sample();if(score!=100||hits!=1)$fatal(1,"held pressure duplicated score");
  key(0);cmd(1);key(3);if(score||hits||feedback!=4)$fatal(1,"target plus wrong held cell must not score");
  key(2);key(3);if(score||hits)$fatal(1,"new correct edge while wrong key remains held must not score");key(0);
  cmd(1);repeat(13673)sample();key(1);if(score!=50||feedback!=2)$fatal(1,"pressure 300ms/600ms GOOD window");
  key(0);cmd(1);repeat(27345)sample();key(1);if(score||hits||misses!=1||feedback!=3)$fatal(1,"pressure late MISS");
  repeat(19000)sample();if(misses!=1)$fatal(1,"late note counted twice at boundary");
  key(1);cmd(1);if(feedback!=5||score||hits)$fatal(1,"held-at-start must require release");key(0);key(1);if(score!=100||hits!=1)$fatal(1,"fresh edge after held guard");
  key(0);cmd(1);cmd(2);saved=dut.elapsed;key(1);repeat(500)sample();if(score||dut.elapsed!=saved||cue)$fatal(1,"pause must freeze timeline and scoring");
  cmd(3);if(score)$fatal(1,"held key scored on resume");key(0);key(1);if(score!=100)$fatal(1,"resume with fresh pressure edge");
  key(0);cmd(1);ready=0;saved=dut.elapsed;key(1);repeat(500)sample();if(score||cue||dut.elapsed!=saved)$fatal(1,"unready pressure must freeze/hide cue");
  ready=1;repeat(4)@(negedge clk);if(score)$fatal(1,"reconnect must not score stale held key");key(0);key(1);if(score!=100)$fatal(1,"fresh press after ready");
  $display("PASS pressure_matrix_scoring: real pressure edge matching, wrong/multiple/held guards, retry, 300ms PERFECT/600ms GOOD, late/timeout, pause and calibration freeze; guide audio always off");$finish;
 end
 initial begin #5000000;$fatal(1,"matrix scoring timeout");end
endmodule
