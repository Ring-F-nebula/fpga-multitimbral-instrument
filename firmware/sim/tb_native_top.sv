`timescale 1ns/1ps
module tb_native_top;
reg clk=0;always #5 clk=~clk;reg tick=0,frame=0;reg [4:0] contacts=0;reg [59:0] xx=0,yy=0;
reg [15:0] fsr=0;reg [143:0] gains={16{9'd256}};
dualmode_top dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),
 .enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'd0),.soft_touch(1'b0),.bend_touch(1'b0),.timbre_touch(1'b0),.fx_touch(1'b0));
initial begin force dut.clk=clk;force dut.harp_reset_n=1'b1;force dut.sample_tick=tick;
 force dut.touch_frame=frame;force dut.touch_contacts=contacts;force dut.touch_x=xx;force dut.touch_y=yy;
 force dut.fsr_keys=fsr;force dut.fsr_gains=gains;
end
task sample;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(127)@(negedge clk);end endtask
task report;begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(12)@(negedge clk);end endtask
task up;begin contacts=0;report();end endtask
task down(input integer x,y);begin up();contacts=1;xx=x;yy=y;report();end endtask
task tap(input integer x,y);begin down(x,y);up();end endtask
integer heard;
initial begin
 wait(dut.fx_ready);repeat(100)sample();down(232,398);
 heard=0;repeat(400)begin sample();if(dut.pcm!=0)heard++;end
 if(dut.live_keys!==1 || heard<300)$fatal(1,"native pad does not drive actual audio");
 fsr=2;sample();tap(48,252);repeat(20)sample();
 if(dut.live_keys!==2 || dut.panel_page!=1)$fatal(1,"parameter page lost independent FSR source");
 tap(512,230);if(dut.attack_sel!=1)$fatal(1,"native ADSR not applied to synth");
 tap(960,440);repeat(20)sample();if(!dut.fx_params[6] || dut.fx_params[119:112]!=105)$fatal(1,"native bend not applied");
 force dut.press_reset=1'b1;@(negedge clk);@(negedge clk);release dut.press_reset;repeat(5)@(negedge clk);
 if(dut.fx_params[6])$fatal(1,"encoder reset must restore physical bend control");
 tap(48,340);tap(352,142);tap(648,142);tap(944,142);
 if(dut.fx_params[2:0]!=7)$fatal(1,"effects not enabled in FPGA");
 heard=0;repeat(1200)begin sample();if(dut.pcm!=0)heard++;end;if(heard<1000)$fatal(1,"effects or conditioner silence");
 tap(944,46);repeat(5)sample();if(!dut.performance_stopped || dut.pcm!==0)$fatal(1,"global STOP");
 fsr=16'hffff;repeat(100)sample();if(dut.pcm!==0)$fatal(1,"FSR restarted STOP");
 fsr=0;tap(808,46);wait(dut.fx_ready);repeat(500)begin sample();if(dut.pcm!==0)$fatal(1,"stale tail after LIVE");end
 fsr=4;heard=0;repeat(400)begin sample();if(dut.pcm!=0)heard++;end;if(heard<250)$fatal(1,"fresh FSR after LIVE");fsr=0;
 tap(48,428);tap(900,150);repeat(300)sample();if(!dut.game_running || !dut.game_page || dut.performance_stopped)$fatal(1,"practice entry");
 tap(48,164);repeat(400)sample();if(dut.game_page || dut.game_running || dut.performance_stopped)$fatal(1,"practice BACK");
 tap(48,428);tap(900,254);repeat(400)sample();if(!dut.auto_mode || dut.game_page)$fatal(1,"offline demonstration");
 tap(808,46);repeat(400)sample();if(dut.auto_mode)$fatal(1,"LIVE failed to exit demo");
 $display("PASS native_top: real pad-to-PCM, FSR preserved on parameter pages, ADSR/pitch/FX, encoder reset, latched STOP, quiet resume, practice/BACK and stored demonstration");$finish;
end
initial begin #40000000;$fatal(1,"timeout");end
endmodule
config cfg_tb_native_top;
design work.tb_native_top;default liblist work;
instance tb_native_top.dut.display use work.lcd_test_stub;
instance tb_native_top.dut.clock_gen use work.merged_clock_test_stub;
instance tb_native_top.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig
