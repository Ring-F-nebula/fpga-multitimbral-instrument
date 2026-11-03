`timescale 1ns/1ps
module tb_pressure_matrix_upload;
 reg clk=0;always #5 clk=~clk;reg reset_n=0,commit=0;reg [7:0] id=0,value=0;
 wire ready,compatible;
 competition_control dut(.clk(clk),.reset_n(reset_n),.tick(1'b0),.touch_keys(32'd0),.serial_keys(32'd0),.bluetooth_keys(32'd0),
  .commit(commit),.id(id),.value(value),.ui_stop(1'b0),.ui_live(1'b0),.axis_valid(3'd0),.axis_bend(9'sd0),.axis_gain(9'd256),.axis_vibrato(7'd0),
  .upload_ready(ready),.upload_matrix_ok(compatible),.song_read_address(7'd0));
 task write(input [7:0] a,b);begin @(negedge clk);id=a;value=b;commit=1;@(negedge clk);commit=0;repeat(3)@(negedge clk);end endtask
 task entry(input [7:0] index,note);begin write('h41,index);write('h42,note);write('h43,4);write('h44,1);end endtask
 initial begin
  repeat(4)@(negedge clk);reset_n=1;write('h40,2);entry(0,15);entry(1,255);write('h45,2^15^4^255^4);
  if(!ready||!compatible)$fatal(1,"16-key score with rest must be accepted");
  write('h40,1);if(ready||compatible)$fatal(1,"incomplete matrix score playable");entry(0,31);write('h45,1^31^4);
  if(!ready||compatible)$fatal(1,"upper-note score must remain valid for legacy practice but blocked for matrix");
  write('h40,1);entry(0,0);write('h45,0);if(ready||compatible)$fatal(1,"bad CRC matrix compatibility");write('h45,1^0^4);
  if(!ready||!compatible)$fatal(1,"new valid lower score did not recover");
  $display("PASS pressure_matrix_upload: lower16/rest accepted, upper32 legacy score preserved, partial/bad CRC blocked and compatibility reset/recovered");$finish;
 end
endmodule
