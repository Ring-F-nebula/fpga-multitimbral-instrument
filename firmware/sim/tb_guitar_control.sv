`timescale 1ns/1ps
module tb_guitar_control;
 GSR GSR(1'b1);
 reg clk=0;always #5 clk=~clk;
 reg reset_n=0,tick=0,frame=0;reg [4:0] contacts=0;reg [59:0] px=0,py=0;
 dualmode_top dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),.enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'h7f),.soft_touch(1'b1),.bend_touch(1'b1),.timbre_touch(1'b1),.fx_touch(1'b1));
 initial begin force dut.clk=clk;force dut.reset_n=reset_n;force dut.sample_tick=tick;force dut.touch_frame=frame;force dut.contacts=contacts;force dut.points_x=px;force dut.points_y=py;end
 task report;begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(24)@(negedge clk);end endtask
 task up;begin contacts=0;report();end endtask
 task down(input integer x,y);begin contacts=1;px=x;py=y;report();end endtask
 task tap(input integer x,y);begin up();down(x,y);up();end endtask
 task sample;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(575)@(negedge clk);end endtask
 task write(input [7:0] a,b);begin @(negedge clk);force dut.ui_id=a;force dut.ui_value=b;force dut.ui_commit=1'b1;@(negedge clk);release dut.ui_id;release dut.ui_value;release dut.ui_commit;repeat(8)@(negedge clk);end endtask
 integer i,j,n,saw_c,saw_g,heard;reg [8:0] soft_gain;
 initial begin
  repeat(4)@(negedge clk);reset_n=1;wait(dut.fx_ready);repeat(60)sample();
  write('h2a,1);tap(456,130);if(dut.instrument!=1||!dut.guitar_analysis||dut.hold_mode)$fatal(1,"guitar must open with analyzer and clear piano toggle-hold");
  for(i=0;i<32;i=i+1)if(dut.note_numbers[i*8+:8]!=40+i)$fatal(1,"fixed guitar pitch map %0d",i);
  tap(320,396);if(dut.guitar_chord!=1||dut.live_keys)$fatal(1,"C selection must be silent");
  down(920,560);if(dut.live_keys)$fatal(1,"C muted sixth string");up();
  down(400,464);soft_gain=dut.gain;if(dut.live_keys!==(32'd1<<20))$fatal(1,"C4 string gate");up();
  down(960,464);if(dut.gain<=soft_gain)$fatal(1,"independent pick-position expression");up();
  write('h50,1);down(920,464);repeat(100)sample();up();repeat(120)sample();
  tap(444,396);if(dut.guitar_chord!=2||dut.note_numbers[20*8+:8]!=60)$fatal(1,"chord selection retuned a ringing voice");
  down(920,440);if(dut.live_keys!==(32'd1<<27))$fatal(1,"G4 string gate");repeat(100)sample();up();repeat(120)sample();
  write('h50,0);repeat(3)sample();if(dut.recording||dut.record_count<4)$fatal(1,"guitar note-event recording");
  write('h50,2);saw_c=0;saw_g=0;heard=0;
  for(j=0;j<600;j=j+1)begin sample();if(dut.live_keys[20])saw_c=1;if(dut.live_keys[27])saw_g=1;if(dut.pcm!=0)heard=heard+1;end
  if(!saw_c||!saw_g||heard<100||dut.replaying)$fatal(1,"guitar chord-change replay lost pitch/gates/audio");
  tap(960,130);if(!dut.guitar_analysis||!dut.info[229]||dut.hold_mode)$fatal(1,"guitar status heading must not hide analyzer or enable hold");
  write('h55,0);if(!dut.guitar_analysis||!dut.info[229])$fatal(1,"legacy command must not hide analyzer");
  tap(456,198);if(dut.plot_mode!=0)$fatal(1,"guitar waveform selector");
  tap(540,198);if(dut.plot_mode!=1)$fatal(1,"guitar spectrum selector");
  tap(624,198);if(dut.plot_mode!=2)$fatal(1,"guitar Lissajous selector");
  down(736,339);if(dut.gain!=0||dut.bend!=-200)$fatal(1,"guitar XY lower-left endpoint");up();
  down(800,240);if(dut.gain!=198||dut.bend!=0)$fatal(1,"guitar XY expression");up();
  down(960,212);if(dut.vibrato!=100)$fatal(1,"guitar vibrato control");up();
  contacts=3;px={36'd0,12'd540,12'd920};py={36'd0,12'd198,12'd440};report();
  if(dut.plot_mode!=1||dut.live_keys!==(32'd1<<27))$fatal(1,"plot selection must preserve concurrent string contact");up();
  tap(232,130);if(dut.instrument!=0||dut.note_numbers[7:0]!=60)$fatal(1,"piano map was damaged");
  $display("PASS guitar_control: permanent analyzer on entry and legacy writes, three plot selectors, compact strings/chords, independent pick expression, real event record/replay audio, piano mapping restore");$finish;
 end
 initial begin #50000000;$fatal(1,"guitar control timeout");end
endmodule
config cfg_tb_guitar_control;
 design work.tb_guitar_control;default liblist work;
 instance tb_guitar_control.dut.display use work.lcd_test_stub;
 instance tb_guitar_control.dut.clock_gen use work.merged_clock_test_stub;
endconfig
