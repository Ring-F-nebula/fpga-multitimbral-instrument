`timescale 1ns/1ps
module tb_practice_exit;
 GSR GSR(1'b1);
 reg clk=0;always #5 clk=~clk;reg reset_n=0,frame=0;reg [4:0] contacts=0;reg [59:0] px=0,py=0;
 dualmode_top dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),.enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'h7f),.soft_touch(1'b1),.bend_touch(1'b1),.timbre_touch(1'b1),.fx_touch(1'b1));
 initial begin force dut.clk=clk;force dut.reset_n=reset_n;force dut.touch_frame=frame;force dut.contacts=contacts;force dut.points_x=px;force dut.points_y=py;end
 task report;begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(24)@(negedge clk);end endtask
 task tap(input integer x,y);begin contacts=0;report();contacts=1;px=x;py=y;report();contacts=0;report();end endtask
 initial begin
  repeat(4)@(negedge clk);reset_n=1;wait(dut.fx_ready);
  tap(48,516);tap(226,192);if(dut.test_count!=4)$fatal(1,"proof start");
  tap(48,224);if(dut.test_count!=0)$fatal(1,"hidden proof mode keeps playing and mapping reset disabled after sidebar exit");
  tap(48,376);tap(900,148);if(!dut.practice_running)$fatal(1,"practice start");
  tap(48,224);if(dut.practice_running)$fatal(1,"hidden practice keeps mapping controls disabled after leaving page");
  tap(892,554);if(!dut.mapping_reset_done||dut.selected!=0)$fatal(1,"mapping reset after practice exit");
  tap(48,376);tap(900,148);tap(48,452);if(dut.practice_running)$fatal(1,"practice -> record page did not stop practice");
  tap(48,376);tap(900,148);tap(456,46);if(dut.practice_running||!dut.recording)$fatal(1,"recording did not replace hidden practice");
  $display("PASS practice_exit: actual touch exits guide on timbre/record navigation; mapping reset enabled; recording replaces practice");$finish;
 end
 initial begin #3000000;$fatal(1,"practice exit timeout");end
endmodule
config cfg_tb_practice_exit;
 design work.tb_practice_exit;default liblist work;
 instance tb_practice_exit.dut.display use work.lcd_test_stub;
 instance tb_practice_exit.dut.clock_gen use work.merged_clock_test_stub;
endconfig
