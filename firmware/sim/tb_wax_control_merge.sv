`timescale 1ns/1ps
module tb_wax_control_merge;
 reg clk=0;always #5 clk=~clk;
 reg reset_n=0,commit=0,stop=0,live=0,replaying=0;
 reg [7:0] id=0,value=0;reg [31:0] touch=0,serial=0,bluetooth=0;
 reg [15:0] pressure=0;reg [143:0] pressure_gains=0;
 wire [31:0] keys;wire [287:0] gains;wire [255:0] notes;
 competition_control #(.ENABLE_PRESSURE(1)) dut(.clk(clk),.reset_n(reset_n),.tick(1'b0),
  .touch_keys(touch),.serial_keys(serial),.bluetooth_keys(bluetooth),.pressure_keys(pressure),.pressure_gains(pressure_gains),
  .commit(commit),.id(id),.value(value),.effect_flags(8'd0),.ui_stop(stop),.ui_live(live),.record_playing(replaying),
  .axis_valid(3'd0),.axis_bend(9'sd0),.axis_gain(9'd256),.axis_vibrato(7'd0),
  .song_read_address(7'd0),.performance_keys(keys),.voice_gains(gains),.note_numbers(notes));
 task settle;repeat(5)@(negedge clk);endtask
 task write(input [7:0] a,b);begin @(negedge clk);id=a;value=b;commit=1;@(negedge clk);commit=0;settle();end endtask
 integer i;reg [8:0] saved;
 initial begin
  for(i=0;i<16;i++)pressure_gains[i*9+:9]=32+i*13;
  repeat(4)@(negedge clk);reset_n=1;settle();pressure=16'hffff;settle();
  if(keys!==32'h0000ffff)$fatal(1,"all 16 pressure gates must map to voices 0..15");
  for(i=0;i<16;i++)if(gains[i*9+:9]!=32+i*13||notes[i*8+:8]!=60+i)$fatal(1,"independent pressure voice %0d",i);
  pressure_gains[8:0]=200;settle();if(gains[8:0]!=200||gains[9+:9]!=45)$fatal(1,"aftertouch changed another voice");
  pressure[0]=0;settle();if(keys[0]||gains[8:0]!=200)$fatal(1,"release must retain tail gain");
  pressure[0]=1;settle();touch=1;settle();if(gains[8:0]!=256)$fatal(1,"new touch owner must take priority over existing pressure");
  write('h25,96);if(gains[8:0]!=96)$fatal(1,"touch expression lost priority");
  touch=0;settle();if(gains[8:0]!=200||!keys[0])$fatal(1,"remaining pressure owner must recover independently");
  serial=1;settle();if(gains[8:0]!=96)$fatal(1,"USB priority");serial=0;bluetooth=1;settle();if(gains[8:0]!=96)$fatal(1,"Bluetooth priority");bluetooth=0;
  stop=1;@(negedge clk);stop=0;settle();if(keys)$fatal(1,"STOP pressure gates");
  live=1;@(negedge clk);live=0;settle();if(keys)$fatal(1,"held pressure restarted after STOP");
  touch=1;settle();if(keys!=1)$fatal(1,"fresh touch must not be blocked by stale pressure owner");touch=0;settle();if(keys)$fatal(1,"blocked pressure returned after touch release");
  pressure=0;settle();pressure=1;settle();if(keys!=1)$fatal(1,"fresh pressure press after release");
  write('h2b,1);if(keys)$fatal(1,"all-notes-off must block held pressure");pressure=0;settle();
  write('h27,32);pressure=16'hffff;settle();saved=gains[8:0];pressure_gains[8:0]=33;settle();
  if(keys!==32'hffffffff||gains[8:0]!=saved)$fatal(1,"pressure disturbed proof profile gates/gain");
  write('h27,0);if(keys)$fatal(1,"held pressure leaked out of proof mode");pressure=0;settle();
  replaying=1;pressure=1;settle();saved=gains[8:0];pressure_gains[8:0]=220;settle();if(gains[8:0]!=saved)$fatal(1,"pressure aftertouch disturbed replay gain");
  replaying=0;pressure=0;settle();write('h23,1);pressure=1;settle();
  if(keys!=1||notes[7:0]!=40||!dut.guitar_analysis)$fatal(1,"guitar pitch map and permanent analyzer lost");
  write('h54,1);if(keys)$fatal(1,"chord switch must not revive held pressure");pressure=0;settle();pressure=1;settle();
  if(keys!=1||notes[7:0]!=40)$fatal(1,"pressure must preserve fixed guitar voice pitch across chord changes");
  $display("PASS wax_control_merge: 16 independent gains/tails, touch/USB/BT priority, STOP/fresh ownership, all-notes-off, proof/replay isolation and guitar mapping");$finish;
 end
 initial begin #1000000;$fatal(1,"pressure control merge timeout");end
endmodule
