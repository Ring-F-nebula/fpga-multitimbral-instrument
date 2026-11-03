`timescale 1ns/1ps
module tb_competition_top;
 GSR GSR(1'b1);
reg clk=0;always #5 clk=~clk;reg reset_n=0,tick=0,frame=0;reg [4:0] contacts=0;reg [59:0] px=0,py=0;
dualmode_top dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),.enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'h7f),.soft_touch(1'b1),.bend_touch(1'b1),.timbre_touch(1'b1),.fx_touch(1'b1));
initial begin force dut.clk=clk;force dut.reset_n=reset_n;force dut.sample_tick=tick;force dut.touch_frame=frame;force dut.contacts=contacts;force dut.points_x=px;force dut.points_y=py;end
task report;begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(16)@(negedge clk);end endtask
task up;begin contacts=0;report();end endtask
task down(input integer x,y);begin up();contacts=1;px=x;py=y;report();end endtask
task tap(input integer x,y);begin down(x,y);up();end endtask
task sample;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(575)@(negedge clk);end endtask
task write(input [7:0] a,b);begin @(negedge clk);force dut.ui_id=a;force dut.ui_value=b;force dut.ui_commit=1'b1;@(negedge clk);release dut.ui_id;release dut.ui_value;release dut.ui_commit;repeat(5)@(negedge clk);end endtask
`include "surface_test_points.vh"
integer i,n,heard;reg [31:0] old_keys;
initial begin repeat(4)@(negedge clk);reset_n=1;wait(dut.fx_ready);repeat(60)sample();if(dut.live_keys!=0||dut.pcm!=0)$fatal(1,"disabled sensors not silent");
 down(160,540);heard=0;repeat(200)begin sample();if(dut.pcm!=0)heard++;end
 if(dut.live_keys!==1||heard<130||dut.overrun)$fatal(1,"real touch audio");
 for(i=0;i<3;i++)begin contacts=1;report();contacts=3;px[23:12]=456+i*84;py[23:12]=198;report();repeat(5)sample();if(dut.plot_mode!=i||dut.live_keys!==1)$fatal(1,"three view switch interrupted note");end
 contacts=7;px[23:12]=800;py[23:12]=276;px[35:24]=960;py[35:24]=276;report();repeat(5)sample();
 if(dut.bend!=0||dut.gain!=126||dut.vibrato!=49||dut.live_keys!=1)$fatal(1,"independent touch expression decode");
 px[23:12]=863;report();if(dut.bend!=200||dut.gain!=126||dut.vibrato!=49)$fatal(1,"horizontal pitch independence");
 py[23:12]=212;report();if(dut.bend!=200||dut.gain!=256||dut.vibrato!=49)$fatal(1,"vertical loudness independence");
 py[35:24]=339;report();if(dut.bend!=200||dut.gain!=256||dut.vibrato!=0)$fatal(1,"vibrato independence");
 up();write('h53,1);write('h2b,1);wait(dut.fx_ready);
 // Real UI taps accumulate 32 separate gates across the two note banks.
 tap(960,130);if(!dut.hold_mode)$fatal(1,"hold button");
 for(n=0;n<16;n++)tap(piano_test_x(dut.bank,n),piano_test_y(dut.bank,n));
 if(dut.live_keys!==32'h0000ffff)$fatal(1,"lower 16 held gates %h",dut.live_keys);
 tap(850,130);if(!dut.bank)$fatal(1,"bank switch");for(n=0;n<16;n++)tap(piano_test_x(dut.bank,n),piano_test_y(dut.bank,n));
 repeat(120)sample();if(dut.live_keys!==32'hffffffff||dut.active_count!=32)$fatal(1,"32 audible held voices");
 tap(944,46);repeat(129)sample();if(!dut.stopped||dut.pcm!==0)$fatal(1,"STOP");tap(808,46);wait(dut.fx_ready);repeat(4)sample();if(dut.live_keys!=0)$fatal(1,"held restart after STOP");
 tap(48,516);
 for(i=0;i<4;i++)begin tap(226+i*164,192);wait(dut.fx_ready);repeat(180)sample();n=4<<i;heard=0;repeat(32)begin sample();if(dut.pcm!=0)heard++;end if(dut.test_count!=n||dut.active_count!=n||dut.overrun||heard<24)$fatal(1,"test profile %d active=%d",n,dut.active_count);end
 tap(648,342);if(dut.selected!=31)$fatal(1,"previous proof voice wraps");tap(896,342);repeat(100)sample();if(dut.active_count!=31)$fatal(1,"single oscillator mute");tap(896,342);repeat(100)sample();if(dut.active_count!=32)$fatal(1,"single oscillator restore");
 // Capture exactly the PCM that the serial DAC consumes in test mode.
 write('h60,1);repeat(300)sample();write('h60,0);if(dut.audio_count!=300||dut.audio_recording)$fatal(1,"integrated actual PCM capture");
 tap(882,192);wait(dut.fx_ready);tap(808,46);write('h2a,0);down(160,540);heard=0;repeat(200)begin sample();if(dut.pcm!=0)heard++;end;if(heard<130)$fatal(1,"normal playing after acceptance mode");
 // Practice must never synthesize guide notes, and must let the user play.
 up();if(dut.bank)tap(850,130);write('h2e,1);wait(dut.fx_ready);repeat(200)begin sample();if(dut.pcm!==0||dut.practice_gate||dut.live_keys!=0)$fatal(1,"practice generated automatic audio");end
 if(!dut.practice_running||dut.practice_cue==0||dut.hold_mode)$fatal(1,"practice visual cue/hold reset");
 down(160,540);heard=0;repeat(200)begin sample();if(dut.pcm!=0)heard++;end
 if(dut.live_keys!==1||heard<130||dut.practice_hits!=1)$fatal(1,"practice user playing/scoring");
 write(4,0);up();repeat(120)sample();if(dut.pcm!==0||dut.live_keys!=0)$fatal(1,"practice kept sounding with no user gate");
 write('h2e,2);repeat(30)sample();if(!dut.practice_paused||dut.practice_gate)$fatal(1,"practice pause");
 write('h2e,3);repeat(30)sample();if(dut.practice_paused||dut.pcm!==0||dut.practice_gate)$fatal(1,"practice resume generated audio");
 write('h2e,0);repeat(10)sample();if(dut.practice_running||dut.pcm!==0)$fatal(1,"practice stop");
 $display("PASS practice_user_only: cue without auto sound; actual user touch-to-PCM and scoring; no hold injection, pause/resume silent");
 $display("PASS competition_top: real touch-to-PCM, 3 independent expression axes, view continuity, 32 UI-held voices/two banks, STOP, 4/8/16/32 proof mode, single-voice mute, actual output PCM capture and resume");$finish;
end
initial begin #100000000;$fatal(1,"competition top timeout");end
endmodule
config cfg_tb_competition_top;
 design work.tb_competition_top;default liblist work;
 instance tb_competition_top.dut.display use work.lcd_test_stub;
 instance tb_competition_top.dut.clock_gen use work.merged_clock_test_stub;
endconfig
