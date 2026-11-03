`timescale 1ns/1ps
module tb_knob5;
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
 turn(0,0);if(volume!=9)$fatal(1,"volume up");turn(0,1);if(volume!=8)$fatal(1,"volume down");
 write(5,3);turn(0,0);if(volume!=4)$fatal(1,"stale shadow");push(0);if(volume!=8)$fatal(1,"volume reset");
 turn(1,0);if(bend!=10||fx[111:104]!=32||fx[6])$fatal(1,"single note bend");push(1);if(bend!=0)$fatal(1,"bend reset");
 turn(2,0);if(!fx[3]||fx[87:80]!=1)$fatal(1,"glide enable");turn(2,1);if(fx[3])$fatal(1,"glide off");
 turn(3,0);if(!fx[4]||fx[103:96]!=5)$fatal(1,"vibrato");push(3);if(fx[4]||fx[103:96])$fatal(1,"vibrato off");
 turn(4,0);if(attack!=1)$fatal(1,"A");push(4);turn(4,0);if(decay!=6||selection!=1)$fatal(1,"D");
 push(4);turn(4,1);if(sustain!=152||selection!=2)$fatal(1,"S");push(4);turn(4,0);if(release_time!=6||selection!=3)$fatal(1,"R");
 // Queue multiple mechanical steps during a remote transaction.
 grant=0;turn(0,0);turn(0,0);turn(1,1);if(volume!=8||bend!=0)$fatal(1,"grant bypass");grant=1;waitc(100);
 if(volume!=10||bend!=-10)$fatal(1,"queued events lost");
 write(5,15);turn(0,0);if(volume!=15)$fatal(1,"volume saturation");
 $display("PASS knob5: physical quadrature and push, authoritative readback, five controls, ADSR selection, queue under arbitration, bounds");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
