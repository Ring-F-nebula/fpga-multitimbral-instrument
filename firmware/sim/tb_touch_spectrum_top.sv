`timescale 1ns/1ps
// Current hardware profile: touch/serial only; disconnected FSR/laser/encoder
// must never create notes or bend a held touchscreen note.
module tb_touch_spectrum_top;
reg clk=0;always #5 clk=~clk;
reg tick=0,frame=0;reg [4:0] contacts=0;reg [59:0] xx=0,yy=0;
reg [15:0] absent_fsr=16'hffff;
reg enc_a=0,enc_b=0,enc_sw=0;
dualmode_top dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),
 .enc_a_n(enc_a),.enc_b_n(enc_b),.enc_sw_n(enc_sw),.beam_broken(7'h7f),
 .soft_touch(1'b1),.bend_touch(1'b1),.timbre_touch(1'b1),.fx_touch(1'b1));
initial begin
 force dut.clk=clk;force dut.harp_reset_n=1'b1;force dut.sample_tick=tick;
 force dut.touch_frame=frame;force dut.touch_contacts=contacts;force dut.touch_x=xx;force dut.touch_y=yy;
 force dut.fsr_keys=absent_fsr;
end
task sample;
begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(127)@(negedge clk);end endtask
task report;
begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(12)@(negedge clk);end endtask
task up;begin contacts=0;report();end endtask
task down(input integer x,y);begin up();contacts=1;xx=x;yy=y;report();end endtask
task tap(input integer x,y);begin down(x,y);up();end endtask
integer heard,i;
initial begin
 wait(dut.fx_ready);repeat(100)sample();
 if(dut.live_keys!==0 || dut.matrix_keys!==0 || dut.game_keys!==0 || dut.pcm!==0)
  $fatal(1,"disabled sensors produced notes");
 down(232,398);heard=0;
 for(i=0;i<400;i++)begin
  enc_a=i[0];enc_b=i[1];enc_sw=i[2];sample();if(dut.pcm!=0)heard++;
 end
 if(dut.live_keys!==1 || heard<300 || dut.bend_cents!==0 || dut.press_reset!==0)
  $fatal(1,"touch audio or disabled encoder profile");
 // Three view buttons must not reset the synth or release a held note.
 for(i=0;i<3;i++)begin
  contacts=1;report();contacts=3;xx[23:12]=860;yy[23:12]=233+i*38;report();
  if(dut.plot_mode!=i || dut.live_keys!==1 || dut.clear)$fatal(1,"view switch interrupted live audio");
  heard=0;repeat(50)begin sample();if(dut.pcm!=0)heard++;end
  if(heard<35)$fatal(1,"view switch muted PCM");
 end
 // Five real screen contact reports drive five distinct synthesis voices.
 contacts=5'b11111;xx={12'd232,12'd904,12'd680,12'd456,12'd232};
 yy={12'd450,12'd398,12'd398,12'd398,12'd398};report();repeat(100)sample();
 if(dut.live_keys!==16'h001f || dut.active_envelopes!==16'h001f)$fatal(1,"five-voice touch chord");
 up();repeat(3000)sample();if(dut.pcm!==0)$fatal(1,"release silence");
 tap(48,252);tap(960,440);repeat(10)sample();
 if(!dut.fx_params[6] || dut.fx_params[119:112]!=105)$fatal(1,"screen pitch controls lost");
 tap(808,46);down(232,398);repeat(100)sample();
 tap(944,46);repeat(20)sample();if(dut.pcm!==0 || !dut.performance_stopped)$fatal(1,"STOP");
 down(456,398);repeat(100)sample();if(dut.pcm!==0)$fatal(1,"touch restarted latched STOP");
 up();tap(808,46);repeat(500)sample();wait(dut.fx_ready);
 down(456,398);heard=0;repeat(300)begin sample();if(dut.pcm!=0)heard++;end
 if(heard<200 || dut.live_keys!==2)$fatal(1,"touch resume");
 $display("PASS touch_spectrum_top: no FSR/laser/RC/encoder input, real touch-to-PCM, three views preserve PCM/held notes, five-voice chord, release, screen pitch, latched STOP/resume");$finish;
end
initial begin #40000000;$fatal(1,"touch profile timeout");end
endmodule
config cfg_tb_touch_spectrum_top;
 design work.tb_touch_spectrum_top;default liblist work;
 instance tb_touch_spectrum_top.dut.display use work.lcd_test_stub;
 instance tb_touch_spectrum_top.dut.clock_gen use work.merged_clock_test_stub;
 instance tb_touch_spectrum_top.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig
