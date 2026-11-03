`timescale 1ns/1ps
module tb_panel_regression;
 realtime adc_t;
 reg board_clk=0;always #10 board_clk=~board_clk;
 reg key1=1,knob=1,valid=0;reg [4:0] contacts=0;reg [59:0] xx=0,yy=0;
 dualmode_top #(.PANEL_UI(0)) dut(.clk_50m(board_clk),.key0_n(1'b1),.key1_n(key1),.UART_RX(1'b1),.BT_RX(1'b1),
 .enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(knob),.beam_broken(7'b0),.soft_touch(1'b0),
 .bend_touch(1'b0),.timbre_touch(1'b0),.fx_touch(1'b0));
 defparam dut.legacy_controls.ui.ORIENTATION_HOLD=12;
 initial begin force dut.touch_frame=valid;force dut.touch_contacts=contacts;force dut.touch_x=xx;force dut.touch_y=yy;end
 task clocks(input integer n);repeat(n) @(negedge dut.clk);endtask
 task frames(input integer n);repeat(n) @(negedge dut.sample_tick);@(negedge dut.clk);endtask
 task raw_touch(input integer x,input integer y,input bit down=1);
 @(negedge dut.clk);xx=x;yy=y;contacts=down?1:0;valid=1;
 @(negedge dut.clk);valid=0;clocks(8);endtask
 task touch(input integer x,input integer y,input bit down=1);raw_touch(x,y,down);endtask
 initial begin
 frames(2200);if(dut.PA_EN) $fatal(1,"performance amplifier must stay awake at idle");@(posedge dut.fsr_adc_clk);adc_t=$realtime;repeat(100) @(posedge dut.fsr_adc_clk);
 if($realtime-adc_t<39999 || $realtime-adc_t>40001) $fatal(1,"ADC clock not 2.5MHz");
 // User's panel sends high X on a physical left touch.
 raw_touch(50,550);frames(100);
 if(dut.touch_keys!=1 || dut.cursor_x!=50 || dut.cursor_y!=550 || dut.live_keys!=1) $fatal(1,"horizontal correction");
 raw_touch(950,550);frames(100);
 if(dut.touch_keys!=16'h1000 || dut.cursor_x!=950 || dut.cursor_y!=550) $fatal(1,"right-side correction");
 touch(0,0,0);key1=0;clocks(100);key1=1;clocks(20);
 if(dut.touch_orientation!=0) $fatal(1,"KEY1 alone changed touch direction");
 key1=0;knob=0;clocks(30);key1=1;knob=1;clocks(20);
 if(dut.touch_orientation!=1) $fatal(1,"horizontal toggle");
 raw_touch(973,550);if(dut.touch_keys!=1 || dut.cursor_x!=50) $fatal(1,"mirror mode");
 key1=0;knob=0;clocks(30);key1=1;knob=1;clocks(20);
 if(dut.touch_orientation!=0) $fatal(1,"toggle back without cycling axes");
 touch(920,24);touch(0,0,0);frames(250);if(!dut.game_page) $fatal(1,"GAME");
 touch(920,24);touch(0,0,0);frames(250);touch(50,550);frames(150);
 if(dut.game_page || dut.performance_stopped || dut.live_keys!=1) $fatal(1,"BACK left piano stopped");
 touch(690,70);touch(0,0,0);frames(250);touch(50,550);frames(100);
 if(!dut.performance_stopped || dut.live_keys) $fatal(1,"explicit STOP no longer latches");
 touch(0,0,0);touch(950,70);touch(0,0,0);frames(250);touch(50,550);frames(150);
 if(dut.performance_stopped || dut.live_keys!=1 || dut.pcm==0) $fatal(1,"LIVE did not restore screen audio");
 $display("PASS panel regression: actual default normal-X mapping, both screen edges, KEY1 isolation, GAME/BACK resume, persistent explicit STOP and LIVE-to-PCM");$finish;
 end
 initial begin #200000000;$fatal(1,"panel timeout");end
endmodule
config cfg_tb_panel_regression;
 design work.tb_panel_regression;default liblist work;
 instance tb_panel_regression.dut.display use work.lcd_test_stub;
 instance tb_panel_regression.dut.clock_gen use work.merged_clock_test_stub;
 instance tb_panel_regression.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig
