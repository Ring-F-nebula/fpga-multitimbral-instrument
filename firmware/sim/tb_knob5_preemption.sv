`timescale 1ns/1ps
module tb_knob5_preemption;
reg clk=0;always #5 clk=~clk;reg reset_n=0,grant=1,remote=0;reg [7:0] remote_id=0,remote_value=0;
reg [4:0] a_n=31,b_n=31,sw_n=31;wire kc;wire [7:0] ki,kv;wire [1:0] selection;
wire commit=remote||kc;wire [7:0] id=remote?remote_id:ki,value=remote?remote_value:kv;
wire [3:0] volume,attack,decay,release_time;wire [7:0] sustain;wire signed [8:0] bend;wire [127:0] fx;wire [7:0] revision;
knob5_controls #(.FILTER_CYCLES(2),.BUTTON_CYCLES(4)) knobs(.envelope_selection(selection),.commit(kc),.id(ki),.value(kv),.*);
competition_control control(.clk(clk),.reset_n(reset_n),.tick(1'b0),.touch_keys(32'h3),.serial_keys(32'd0),.bluetooth_keys(32'd0),.pressure_keys(16'd0),.pressure_gains(144'd0),
 .commit(commit),.id(id),.value(value),.effect_flags(fx[7:0]),.ui_stop(1'b0),.ui_live(1'b0),.record_playing(1'b0),.axis_valid(3'd0),.axis_bend(9'sd0),.axis_gain(9'd256),.axis_vibrato(7'd0),
 .volume(volume),.attack(attack),.decay(decay),.sustain(sustain),.release_time(release_time),.bend(bend),.song_read_address(7'd0));
fx_registers effects(.clk(clk),.reset_n(reset_n),.usb_commit(remote),.usb_id(remote_id),.usb_value(remote_value),.bt_commit(1'b0),.bt_id(8'd0),.bt_value(8'd0),
 .ui_commit(kc),.ui_id(ki),.ui_value(kv),.stopped(1'b0),.snapshot(fx),.revision(revision));
task waitc(input integer n);repeat(n)@(negedge clk);endtask
task turn(input integer n,input bit reverse);begin
 if(!reverse)begin b_n[n]=0;waitc(12);a_n[n]=0;waitc(12);b_n[n]=1;waitc(12);a_n[n]=1;end
 else begin a_n[n]=0;waitc(12);b_n[n]=0;waitc(12);a_n[n]=1;waitc(12);b_n[n]=1;end
 waitc(30);end endtask
task push(input integer n);begin sw_n[n]=0;waitc(20);sw_n[n]=1;waitc(30);end endtask
task write(input [7:0] x,y);begin grant=0;remote_id=x;remote_value=y;remote=1;waitc(1);remote=0;grant=1;waitc(20);end endtask
initial begin waitc(5);reset_n=1;waitc(10);
 // A remote write wins after the knob has prepared, before its first commit.
 grant=0;turn(0,0);@(negedge clk);grant=1;
 @(posedge clk);#1;if(knobs.state!=1)$fatal(1,"prepare state");
 @(negedge clk);grant=0;remote_id=5;remote_value=12;remote=1;
 waitc(1);remote=0;grant=1;waitc(30);
 if(volume!=13)$fatal(1,"knob overwrote a newer remote value with stale data: %0d",volume);
 // The bend target write may have committed, but the relative bend has not.
 grant=0;turn(1,0);@(negedge clk);grant=1;
 wait(knobs.state==2);@(negedge clk);grant=0;remote_id='h24;remote_value=120;remote=1;
 waitc(1);remote=0;grant=1;waitc(40);
 if(bend!=50)$fatal(1,"bend preemption lost authoritative readback: %0d",bend);
 $display("PASS knob5_preemption: queued relative changes rebase after first/second-stage bus preemption, without stale overwrite or duplicate bend steps");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
