`timescale 1ns/1ps
module tb_competition_control;
reg clk=0;always #5 clk=~clk;reg reset_n=0,tick=0,commit=0,stop=0,live=0;reg [7:0] id=0,value=0;reg [31:0] touch=0,serial=0,bluetooth=0;
wire [31:0] keys;wire [255:0] notes;wire [287:0] gains;wire hold,stopped,ready;wire [5:0] tests;wire [7:0] received;reg [6:0] address=0;wire [7:0] note,duration;
wire signed [8:0] bend;wire [8:0] gain;wire [6:0] vibrato;
competition_control dut(.clk(clk),.reset_n(reset_n),.tick(tick),.touch_keys(touch),.serial_keys(serial),.bluetooth_keys(bluetooth),.commit(commit),.id(id),.value(value),.ui_stop(stop),.ui_live(live),
 .axis_valid(3'd0),.axis_bend(9'sd0),.axis_gain(9'd256),.axis_vibrato(7'd0),.performance_keys(keys),.note_numbers(notes),.voice_gains(gains),.hold_mode(hold),.stopped(stopped),.test_count(tests),
 .bend(bend),.gain(gain),.vibrato(vibrato),.upload_ready(ready),.upload_received(received),.song_read_address(address),.song_note(note),.song_duration(duration));
task write(input [7:0] a,b);begin @(negedge clk);id=a;value=b;commit=1;@(negedge clk);commit=0;repeat(4)@(negedge clk);end endtask
integer i,crc;
initial begin
 repeat(3)@(negedge clk);reset_n=1;repeat(3)@(negedge clk);
 for(i=0;i<32;i++)if(notes[i*8+:8]!=60+i)$fatal(1,"default mapping");
 touch=1;repeat(4)@(negedge clk);if(keys!=1)$fatal(1,"normal touch");write('h2a,1);touch=0;repeat(4)@(negedge clk);if(keys!=1)$fatal(1,"held touch");
 touch=1;repeat(4)@(negedge clk);touch=0;repeat(4)@(negedge clk);if(keys!=0)$fatal(1,"tap toggles held note off");
 serial=32'h80000000;repeat(4)@(negedge clk);serial=0;repeat(4)@(negedge clk);if(keys!==32'h80000000)$fatal(1,"held upper serial voice");write('h2a,0);
 write('h25,80);touch=16;repeat(5)@(negedge clk);if(gains[4*9+:9]!=80)$fatal(1,"onset independent gain");write('h25,200);if(gains[4*9+:9]!=200||gains[3*9+:9]!=256)$fatal(1,"independent selected gain");
 write('h24,200);write('h26,60);if(bend!=200||gain!=200||vibrato!=60)$fatal(1,"three independent expressions");touch=0;
 write('h27,32);if(keys!==32'hffffffff)$fatal(1,"32 test gates");write('h28,31);write('h29,1);if(keys!==32'h7fffffff)$fatal(1,"single proof voice mute");write('h29,0);write('h27,0);
 write('h30,31);write('h31,100);if(notes[31*8+:8]!=100||notes[30*8+:8]!=90)$fatal(1,"actual mapping edit");write('h32,1);if(notes[31*8+:8]!=91)$fatal(1,"mapping reset");
 write('h40,3);crc=3;
 for(i=0;i<3;i++)begin write('h41,i);write('h42,i==2?255:i==1?31:0);write('h43,i+1);write('h44,1);crc=crc^(i==2?255:i==1?31:0)^(i+1);end
 write('h45,crc^1);if(ready)$fatal(1,"bad score CRC");write('h45,crc);if(!ready||received!=3)$fatal(1,"score commit");address=1;repeat(3)@(negedge clk);if(note!=31||duration!=2)$fatal(1,"real score memory");
 write('h40,1);if(ready)$fatal(1,"partial score is playable");write('h41,3);write('h44,1);if(received!=0)$fatal(1,"out of order score accepted");
 serial=1;stop=1;@(negedge clk);stop=0;repeat(4)@(negedge clk);if(keys||!stopped)$fatal(1,"STOP");live=1;@(negedge clk);live=0;repeat(4)@(negedge clk);if(keys)$fatal(1,"held serial retrigger after STOP");bluetooth=1;repeat(4)@(negedge clk);if(keys!=1)$fatal(1,"fresh BT blocked by stale USB owner");bluetooth=0;repeat(4)@(negedge clk);if(keys)$fatal(1,"stale USB reappears after BT release");
 touch=1;repeat(4)@(negedge clk);if(keys!=1)$fatal(1,"fresh touch blocked by stale USB owner");touch=0;repeat(4)@(negedge clk);if(keys)$fatal(1,"independent touch release");
 serial=0;repeat(4)@(negedge clk);serial=1;repeat(4)@(negedge clk);if(keys!=1)$fatal(1,"fresh resume");
 $display("PASS competition_control: 32 mappings/gains, touch+serial hold, independent pitch/gain/vibrato, 32 gates, per-voice mute, CRC score transaction, STOP/resume");$finish;
end
endmodule
