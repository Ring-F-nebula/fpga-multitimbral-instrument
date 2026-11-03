`timescale 1ns/1ps
// Production touch controls, scorer, audio engine and matrix-state routing.
// The already-verified WAX frontend outputs are injected at its boundary.
module tb_pressure_matrix_top;
 GSR GSR(1'b1);
 reg clk=0;always #5 clk=~clk;reg reset_n=0,tick=0,frame=0,pressure_ready=1,pressure_frame=0;
 reg [4:0] contacts=0;reg [59:0] px=0,py=0;reg [15:0] pressure=0,usb=0;
 dualmode_top dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),.WAX_RX(1'b1),
  .enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'h7f),.soft_touch(1'b1),.bend_touch(1'b1),.timbre_touch(1'b1),.fx_touch(1'b1));
 initial begin force dut.clk=clk;force dut.reset_n=reset_n;force dut.sample_tick=tick;force dut.touch_frame=frame;
  force dut.contacts=contacts;force dut.points_x=px;force dut.points_y=py;force dut.wax_keys=pressure;force dut.wax_ready=pressure_ready;
  force dut.wax_frame=pressure_frame;
  force dut.wax_gains={16{9'd192}};force dut.usb_lo=usb;end
 task report;begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(24)@(negedge clk);end endtask
 task tap(input integer x,y);begin contacts=0;report();contacts=1;px=x;py=y;report();contacts=0;report();end endtask
 task sample;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(575)@(negedge clk);end endtask
 task press(input [15:0] mask);begin @(negedge clk);pressure=mask;pressure_frame=1;@(negedge clk);pressure_frame=0;repeat(600)@(negedge clk);end endtask
 integer heard,i;reg [31:0] elapsed;
 initial begin
  repeat(4)@(negedge clk);reset_n=1;wait(dut.fx_ready);repeat(60)sample();
  tap(48,376);tap(800,464);if(dut.page!=6||dut.practice_running)$fatal(1,"matrix page entry must not auto-start");
  tap(134,162);tap(48,376);if(dut.page!=6||dut.touch_keys)$fatal(1,"matrix cells/sidebar remnants must not trigger audio or navigate");
  tap(664,48);if(!dut.practice_running||dut.practice_cue!=1||dut.practice_bpm!=80)$fatal(1,"matrix start/tempo cap");
  wait(dut.fx_ready);repeat(80)begin sample();if(dut.pcm!=0||dut.live_keys||dut.practice_gate)$fatal(1,"guide generated audio");end
  usb=1;repeat(16)@(negedge clk);repeat(20)sample();if(dut.practice_hits||dut.practice_score)$fatal(1,"USB note must not score matrix practice");usb=0;
  tap(134,162);if(dut.practice_hits||dut.touch_keys)$fatal(1,"screen cell impersonated pressure input");
  // A0 qualifies before A1 during one core scan: no partial-vector score.
  pressure_frame=1;@(negedge clk);pressure_frame=0;repeat(20)@(negedge clk);pressure=1;repeat(30)@(negedge clk);pressure=3;
  if(dut.practice_hits)$fatal(1,"partial WAX scan scored before complete frame");repeat(600)@(negedge clk);
  if(dut.practice_feedback!=4||dut.practice_hits||dut.matrix_last_keys!=3)$fatal(1,"completed multi-key pressure frame must be rejected");
  press(0);press(2);if(dut.practice_feedback!=4||dut.practice_hits||dut.matrix_last_keys!=2)$fatal(1,"wrong pressure input identification");press(0);press(1);
  if(dut.practice_hits!=1||dut.practice_score!=100||dut.matrix_last_keys!=1)$fatal(1,"correct pressure retry/scoring");
  heard=0;repeat(160)begin sample();if(dut.pcm!=0)heard++;end;if(heard<100)$fatal(1,"real pressure instrument audio missing");
  if(dut.practice_hits!=1)$fatal(1,"held pressure scored repeatedly");
  tap(792,48);if(!dut.practice_paused)$fatal(1,"matrix pause button");elapsed=dut.practice.elapsed;press(0);press(4);repeat(30)sample();
  if(dut.practice.elapsed!=elapsed||dut.practice_hits!=1||dut.practice_cue)$fatal(1,"pause freeze");
  tap(792,48);if(dut.practice_paused)$fatal(1,"matrix resume button");press(0);tap(664,48);if(dut.practice_score||dut.practice_hits)$fatal(1,"matrix restart");
  pressure_ready=0;repeat(8)@(negedge clk);elapsed=dut.practice.elapsed;repeat(30)sample();if(dut.practice.elapsed!=elapsed||dut.practice_cue)$fatal(1,"unready pressure timeline not frozen");
  tap(664,48);if(dut.practice.elapsed!=elapsed)$fatal(1,"start/restart must be disabled without ready pressure");
  pressure_ready=1;repeat(8)@(negedge clk);tap(664,48);press(1);if(dut.practice_hits!=1)$fatal(1,"ready matrix restart/press");press(0);
  tap(936,48);if(dut.page!=3||dut.practice_running||dut.matrix_mode)$fatal(1,"matrix return must stop hidden scoring");
  $display("PASS pressure_matrix_top: fullscreen navigation, read-only cells, pressure-only score, no automatic guide sound, actual PCM, wrong/held/retry/restart, pause/ready guards and exit");$finish;
 end
 initial begin #50000000;$fatal(1,"matrix top timeout");end
endmodule
config cfg_tb_pressure_matrix_top;
 design work.tb_pressure_matrix_top;default liblist work;
 instance tb_pressure_matrix_top.dut.display use work.lcd_test_stub;
 instance tb_pressure_matrix_top.dut.clock_gen use work.merged_clock_test_stub;
endconfig
