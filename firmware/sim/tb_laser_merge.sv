`timescale 1ns/1ps
module tb_laser_merge;
 reg [6:0] beams=0;
 reg bt=1,usb=1,valid=0;
 reg [4:0] contacts=0;
 reg [59:0] xx=0,yy=0;
 reg [3:0] electrodes=0,press_pad=0;
 wire drive;
 tri1 scl,sda,irq;
 reg board_clk=0; always #10 board_clk=~board_clk;
 dualmode_top #(.PANEL_UI(0),.ENABLE_LASER_INPUTS(1),.ENABLE_RC_PADS(1)) dut(.clk_50m(board_clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(usb),.BT_RX(bt),
  .enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(beams),
  .soft_touch(electrodes[0]),.bend_touch(electrodes[1]),
  .timbre_touch(electrodes[2]),.fx_touch(electrodes[3]),.TOUCH_DRIVE(drive),
  .touch_scl(scl),.touch_sda(sda),.touch_int(irq));
 defparam dut.pads.CALIBRATION_FRAMES=4;
 initial begin
  force dut.display.h=0;force dut.display.v=0;force dut.display.scope.audio_toggle=0;
  force dut.touch_frame=valid;force dut.touch_contacts=contacts;
  force dut.touch_x=xx;force dut.touch_y=yy;force dut.touch_online=1;
 end
 // Four independent RC electrode models: 8 us idle / 40 us touched.
 genvar k;
 generate for(k=0;k<4;k=k+1) begin: rc
  always @(posedge drive) begin
   if(press_pad[k]) #40000; else #8000;
   electrodes[k]=1;
  end
  always @(negedge drive) electrodes[k]=0;
 end endgenerate
 task clocks(input integer n);repeat(n)@(negedge dut.clk);endtask
 task frames(input integer n);repeat(n)@(negedge dut.sample_tick);@(negedge dut.clk);endtask
 task send_bt(input [7:0] b);
  bt=0;clocks(2734);
  for(integer i=0;i<8;i=i+1)begin bt=b[i];clocks(2734);end
  bt=1;clocks(2740);
 endtask
 task mask(input [15:0] keys);
  send_bt(8'hf6);send_bt(keys[7:0]);send_bt(keys[15:8]);send_bt(8'hf6^keys[7:0]^keys[15:8]);clocks(8);
 endtask
 task write_param(input [7:0] id,input [7:0] value);
  send_bt(8'hf5);send_bt(id);send_bt(value);send_bt(8'hf5^id^value);clocks(8);
 endtask
 task screen(input integer x,input integer y,input bit down);
  @(negedge dut.clk);xx=x;yy=y;contacts=down?1:0;valid=1;
  @(negedge dut.clk);valid=0;clocks(8);
 endtask
 task audible;
  integer nonzero;
  nonzero=0;
  repeat(250)begin frames(1);if(dut.pcm!==16'bx && dut.pcm!=0)nonzero++;end
  if(nonzero<100)$fatal(1,"merged output silent");
 endtask
 reg [15:0] expected[0:6];
 initial begin
  expected[0]=1;expected[1]=4;expected[2]=16;expected[3]=32;
  expected[4]=128;expected[5]=512;expected[6]=2048;
  frames(2200);
  if(!dut.pads_ready || dut.pad_controls!==0)$fatal(1,"RC calibration / counter width");
  beams=1;clocks(1000);beams=0;clocks(15000);
  if(dut.live_keys!==0)$fatal(1,"short light glitch was not rejected");
  for(integer i=0;i<7;i++)begin
   beams=1<<i;clocks(13200);
   if(dut.live_keys!==expected[i])$fatal(1,"laser mapping channel %0d: %h",i,dut.live_keys);
   audible();beams=0;clocks(13200);
  end
  beams=127;clocks(13200);
  if(dut.live_keys!==16'h0ab5)$fatal(1,"seven-string chord");
  audible();beams=0;clocks(13200);
  // Same pitch held by two independent sources must survive either release.
  beams=1;clocks(13200);mask(3);
  screen(150,550,1); // Adds a touchscreen note; decoded mask is checked below.
  if(dut.live_keys!==(dut.touch_keys|16'h0003))$fatal(1,"laser/BT/touch union");
  beams=0;clocks(13200);
  if(dut.live_keys!==(dut.touch_keys|16'h0003))$fatal(1,"laser release silenced Bluetooth");
  beams=1;clocks(13200);mask(0);screen(0,0,0);
  if(dut.live_keys!==1)$fatal(1,"Bluetooth release silenced laser");
  write_param(5,12);press_pad[0]=1;clocks(55000);
  if(dut.effective_volume!==6)$fatal(1,"soft electrode / Bluetooth volume");
  press_pad[0]=0;clocks(55000);
  if(dut.effective_volume!==12)$fatal(1,"soft release");
  press_pad[1]=1;frames(350);
  if(dut.synth.voices[0].manual_voice.coeff_smooth!==17'd73562)$fatal(1,"smooth touch bend");
  press_pad[1]=0;frames(350);
  if(dut.synth.voices[0].manual_voice.coeff_smooth!==17'd65536)$fatal(1,"bend release");
  press_pad[3]=1;clocks(55000);
  if(!dut.fx.enable)$fatal(1,"delay electrode missing");audible();
  press_pad[3]=0;beams=0;clocks(55000);
  press_pad[2]=1;frames(400);
  if(dut.effective_instrument!==1)$fatal(1,"pluck electrode missing");
  beams=1;clocks(13200);audible();beams=0;clocks(13200);
  press_pad[2]=0;frames(400);
  if(dut.effective_instrument!==0)$fatal(1,"base instrument restore");
  beams=1;clocks(13200);write_param(6,0);frames(400);
  if(dut.live_keys!==0)$fatal(1,"STOP must block held laser");
  beams=0;clocks(13200);beams=1;clocks(13200);
  if(dut.live_keys!==1)$fatal(1,"laser must retrigger after release");
  write_param(6,1);frames(400);
  if(!dut.auto_mode || dut.live_keys!==0)$fatal(1,"AUTO ownership");
  write_param(6,0);frames(400);
  if(dut.live_keys!==0)$fatal(1,"held laser leaked through AUTO exit");
  beams=0;clocks(13200);
  force dut.game_page=1;beams=2;clocks(13200);
  if(dut.game_keys!==4 || dut.live_keys!==0)$fatal(1,"game laser input path");
  release dut.game_page;
  $display("PASS laser merge: seven notes/chord, glitch rejection, independent BT/touch releases, real RC pads, soft/bend/pluck/delay, STOP/AUTO, game input, nonzero PCM");
  $finish;
 end
 initial begin #1000000000;$fatal(1,"laser merge timeout");end
endmodule
