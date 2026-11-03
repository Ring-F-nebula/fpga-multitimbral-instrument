`timescale 1ns/1ps
module tb_native_ui;
reg clk=0;always #5 clk=~clk;
reg reset_n=0,frame=0,key1=1;reg [4:0] contacts=0;reg [59:0] px=0,py=0;
wire [2:0] view;wire [15:0] keys;wire [1:0] instrument;wire [3:0] volume;wire [2:0] page,orientation;
wire live,stop,auto_play,start,game,commit,recalibrate;wire [7:0] id,value;wire [3:0] pad;
reg [3:0] a=0,d=5,r=5;reg [7:0] s=160;wire [127:0] fx;
reg bt_commit=0;reg [7:0] bt_id=0,bt_value=0;
fx_registers regs(.clk(clk),.reset_n(reset_n),.usb_commit(1'b0),.bt_commit(bt_commit),.usb_id(0),.usb_value(0),
 .bt_id(bt_id),.bt_value(bt_value),.ui_commit(commit),.ui_id(id),.ui_value(value),.stopped(1'b0),.snapshot(fx));
always @(posedge clk)if(commit)case(id)1:a<=value;2:d<=value;3:s<=value;4:r<=value;endcase
panel_ui #(.ORIENTATION_HOLD(12)) dut(.clk(clk),.reset_n(reset_n),.frame_valid(frame),.key1_n(key1),.contacts(contacts),.point_x(px),.point_y(py),
 .serial_volume(4'd8),.serial_volume_event(1'b0),.keys(keys),.instrument(instrument),.plot_mode(view),.volume(volume),.auto_press(auto_play),.live_press(live),.stop_press(stop),
 .orientation(orientation),.game_page(game),.game_start(start),.page(page),.selected_pad(pad),.recalibrate(recalibrate),
 .fx_params(fx),.attack_sel(a),.decay_sel(d),.release_sel(r),.sustain_level(s),.commit(commit),.param_id(id),.param_value(value));
integer stops=0,starts=0,lives=0,calibrations=0;
always @(posedge clk)begin if(stop)stops++;if(start)starts++;if(live)lives++;if(recalibrate)calibrations++;end
task report;begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(12)@(negedge clk);end endtask
task up;begin contacts=0;report();end endtask
task tap(input integer x,y);begin up();contacts=1;px=x;py=y;report();up();end endtask
integer n;
initial begin
 repeat(3)@(negedge clk);reset_n=1;
 // Every one of sixteen screen pads, held and released.
 for(n=0;n<16;n++)begin contacts=1;px=232+(n%4)*224;py=398+(n/4)*52;report();
 if(keys!==(16'b1<<n))$fatal(1,"pad %d mapping",n);report();if(keys!==(16'b1<<n))$fatal(1,"pad hold");up();if(keys!==0)$fatal(1,"release");end
 contacts=5'b11111;px={12'd232,12'd904,12'd680,12'd456,12'd232};py={12'd450,12'd398,12'd398,12'd398,12'd398};report();
 if(keys!==16'h001f)$fatal(1,"five-touch chord");up();
 // Switch all views while another contact holds a note. No key release.
 contacts=1;px=232;py=398;report();
 for(n=0;n<3;n++)begin
  contacts=1;report();contacts=3;px[23:12]=860;py[23:12]=233+n*38;report();
  if(view!=n || keys!==1)$fatal(1,"view switch released note or wrong mode");
 end
 up();
 tap(48,252);if(page!=1)$fatal(1,"sound navigation");tap(512,230);if(a!=1)$fatal(1,"ADSR register write");
 tap(952,192);if(!fx[3])$fatal(1,"glide enable");tap(960,240);if(fx[87:80]!=4)$fatal(1,"glide duration");
 tap(952,290);if(!fx[4])$fatal(1,"vibrato enable");tap(960,344);if(fx[95:88]!=51)$fatal(1,"vibrato Hz");
 tap(960,440);if(fx[119:112]!=105 || !fx[6])$fatal(1,"bend +10 cents and enable");
 tap(960,488);if(fx[111:104]!=0)$fatal(1,"automatic target advances to physical pad 01");
 tap(872,488);if(fx[111:104]!=16)$fatal(1,"target wraps back to automatic");
 tap(48,340);if(page!=2)$fatal(1,"effects navigation");
 tap(352,142);tap(648,142);tap(944,142);if(fx[2:0]!=7)$fatal(1,"effect toggles");
 tap(360,252);if(fx[15:8]!=19)$fatal(1,"delay time");
 // Repeated reports from a held toggle must not repeatedly flip it.
 contacts=1;px=250;py=552;report();repeat(5)report();if(!fx[5])$fatal(1,"held bypass button");up();
 // Remote parameter updates are the same state the native panel reads.
 @(negedge clk);bt_commit=1;bt_id='h13;bt_value=200;@(negedge clk);bt_commit=0;repeat(3)@(negedge clk);
 if(fx[31:24]!=200)$fatal(1,"BT/native readback");
 tap(880,552);repeat(20)@(negedge clk);if(fx[119:0]!=={8'd100,8'd16,8'd18,8'd50,8'd3,8'd64,8'd4,8'd45,8'd51,8'd30,8'd8,8'd64,8'd90,8'd18,8'd0})$fatal(1,"restore all parameters");
 tap(48,428);tap(900,150);if(!game || starts!=1 || instrument!=0)$fatal(1,"practice start");
 tap(48,164);if(game || lives==0 || page!=0)$fatal(1,"BACK returns to normal play");
 tap(680,130);tap(48,252);tap(512,230);if(a!=1)$fatal(1,"drum envelope should be disabled");
 tap(952,192);tap(952,290);if(fx[4:3]!=0)$fatal(1,"drum pitch controls should be disabled");
 tap(48,516);tap(370,360);if(pad!=10)$fatal(1,"FSR pad selection");tap(800,472);if(calibrations!=1)$fatal(1,"recalibration");
 tap(944,46);if(stops!=1)$fatal(1,"global stop");
 key1=0;repeat(18)@(negedge clk);if(orientation!=1)$fatal(1,"mirror-X combo");key1=1;repeat(5)@(negedge clk);
 tap(1023-808,46);if(page!=0)$fatal(1,"mirrored live button");
 contacts=1;px=1023-232;py=398;report();if(keys!==1)$fatal(1,"mirrored pad mapping");up();
 $display("PASS native_ui: all 16 pads/five-touch chords, waveform/FFT/XY switch holds notes, five pages, real ADSR/FX writes, held-button edges, remote readback, defaults, game/BACK, calibration and mirror");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
