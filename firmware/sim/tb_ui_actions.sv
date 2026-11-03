`timescale 1ns/1ps
module tb_ui_actions;
 GSR GSR(1'b1);
reg clk=0;always #5 clk=~clk;reg reset_n=0,tick=0,frame=0;reg [4:0] contacts=0;reg [59:0] px=0,py=0;
dualmode_top dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),.enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'h7f),.soft_touch(1'b1),.bend_touch(1'b1),.timbre_touch(1'b1),.fx_touch(1'b1));
initial begin force dut.clk=clk;force dut.reset_n=reset_n;force dut.sample_tick=tick;force dut.touch_frame=frame;force dut.contacts=contacts;force dut.points_x=px;force dut.points_y=py;end
task report;begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(24)@(negedge clk);end endtask
task up;begin contacts=0;report();end endtask
task down(input integer x,y);begin up();contacts=1;px=x;py=y;report();end endtask
task tap(input integer x,y);begin down(x,y);up();end endtask
task sample;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(575)@(negedge clk);end endtask
task write(input [7:0] a,b);begin @(negedge clk);force dut.ui_id=a;force dut.ui_value=b;force dut.ui_commit=1'b1;@(negedge clk);release dut.ui_id;release dut.ui_value;release dut.ui_commit;repeat(8)@(negedge clk);end endtask
task pair(input integer xm,xp,y,offset,step);integer old;begin old=dut.fx_params[offset*8+:8];tap(xp,y);if(dut.fx_params[offset*8+:8]!=old+step)$fatal(1,"UI increment offset=%d",offset);tap(xm,y);if(dut.fx_params[offset*8+:8]!=old)$fatal(1,"UI decrement offset=%d",offset);end endtask
integer heard,i;reg [17:0] saved_samples;
initial begin
 repeat(4)@(negedge clk);reset_n=1;wait(dut.fx_ready);repeat(60)sample();
 tap(702,46);if(dut.volume!=9)$fatal(1,"MASTER VOLUME PLUS FAILED value=%0d",dut.volume);
 tap(550,46);if(dut.volume!=8)$fatal(1,"MASTER VOLUME MINUS FAILED value=%0d",dut.volume);
 tap(48,452);if(dut.page!=5)$fatal(1,"record page navigation");
 down(232,460);if(dut.page!=0||!dut.recording||!dut.audio_armed||dut.hold_mode)$fatal(1,"record start/arm/navigation");
 report();repeat(100)sample();if(dut.live_keys||dut.audio_count||dut.record_has_notes)$fatal(1,"navigation finger/silence consumed capture");
 up();down(160,540);heard=0;repeat(200)begin sample();if(dut.pcm!=0)heard++;end
 if(heard<120||!dut.record_has_notes||!dut.audio_recording||dut.audio_count==0)$fatal(1,"record actual playing");
 up();repeat(20)sample();tap(456,46);repeat(4)sample();saved_samples=dut.audio_count;
 if(dut.recording||dut.audio_recording||dut.audio_armed||dut.record_count<2||saved_samples==0)$fatal(1,"record stop/readback");
 tap(48,452);tap(320,530);wait(dut.fx_ready);heard=0;repeat(600)begin sample();if(dut.pcm!=0)heard++;end
 if(heard<120||dut.replaying||dut.audio_count!=saved_samples)$fatal(1,"note replay must sound without replaying/changing PCM");
 tap(776,530);repeat(3)sample();if(dut.record_count||dut.audio_count||dut.record_has_notes)$fatal(1,"record clear");
 // Local mapping/ADSR work through the real touch pipeline and registers.
 tap(48,224);tap(512,374);if(dut.sustain!=176)$fatal(1,"S increment");tap(440,374);if(dut.sustain!=160)$fatal(1,"S decrement");
 tap(512,230);if(dut.attack!=1)$fatal(1,"A increment");tap(440,230);if(dut.attack!=0)$fatal(1,"A decrement");
 tap(440,302);if(dut.decay!=4)$fatal(1,"D decrement");tap(512,302);if(dut.decay!=5)$fatal(1,"D increment");
 tap(512,446);if(dut.release_time!=6)$fatal(1,"R increment");tap(440,446);if(dut.release_time!=5)$fatal(1,"R decrement");
 tap(512,374);tap(496,138);if(dut.attack!=0||dut.decay!=5||dut.sustain!=160||dut.release_time!=5)$fatal(1,"envelope reset");
 // Presets use real touch frames and the same authoritative engine registers.
 down(204,498);if(dut.attack!=7||dut.decay!=8||dut.sustain!=192||dut.release_time!=9)$fatal(1,"soft preset");
 repeat(3)report();if(dut.ui_commit)$fatal(1,"held preset repeated writes");up();
 tap(340,498);if(dut.attack!=0||dut.decay!=6||dut.sustain!=0||dut.release_time!=5)$fatal(1,"short preset");
 tap(476,498);if(dut.attack!=9||dut.decay!=8||dut.sustain!=255||dut.release_time!=9)$fatal(1,"swell preset");
 tap(440,230);if(dut.attack!=8||dut.decay!=8||dut.sustain!=255||dut.release_time!=9)$fatal(1,"preset manual edit");
 tap(204,498);if(dut.attack!=7||dut.sustain!=192)$fatal(1,"preset reselect after edit");
 // Existing FX and master volume must survive a preset selection.
 if(dut.volume!=8||dut.fx_params[7:0]!=0||dut.fx_params[15:8]!=24)$fatal(1,"ADSR preset changed volume/FX");
 tap(496,138);if(dut.attack!=0||dut.decay!=5||dut.sustain!=160||dut.release_time!=5)$fatal(1,"reset after preset");
 tap(560,554);if(dut.note_numbers[7:0]!=61)$fatal(1,"local MIDI +");tap(504,554);if(dut.note_numbers[7:0]!=60)$fatal(1,"local MIDI -");
 tap(256,554);if(dut.selected!=31)$fatal(1,"previous voice wrap");tap(312,554);if(dut.selected!=0)$fatal(1,"next voice wrap");
 for(i=0;i<32;i++)begin write('h30,i);write('h31,24+i);end
 write('h28,23);if(dut.note_numbers[23*8+:8]!=47)$fatal(1,"mapping reset precondition");
 tap(892,554);if(dut.selected!=0||!dut.mapping_reset_done||dut.hold_mode)$fatal(1,"mapping reset completion feedback");
 for(i=0;i<32;i++)if(dut.note_numbers[i*8+:8]!=60+i)$fatal(1,"all 32 mappings must reset");
 tap(560,554);if(dut.mapping_reset_done)$fatal(1,"mapping reset acknowledgement did not clear on edit");tap(892,554);
 down(696,554);if(dut.touch_keys!=1)$fatal(1,"audition gate");up();if(dut.touch_keys!=0)$fatal(1,"audition release");
 write('h23,1);tap(204,498);if(dut.attack!=7||dut.decay!=8||dut.sustain!=192||dut.release_time!=9)$fatal(1,"guitar preset");tap(496,138);tap(512,374);if(dut.sustain!=176)$fatal(1,"guitar ADSR control");
 write('h23,2);tap(204,498);tap(340,498);tap(476,498);tap(496,138);
 if(dut.attack!=0||dut.decay!=5||dut.sustain!=176||dut.release_time!=5)$fatal(1,"disabled drum preset/reset changed");
 tap(512,230);if(dut.attack!=0)$fatal(1,"disabled drum ADSR changed");tap(560,554);if(dut.note_numbers[7:0]!=60)$fatal(1,"disabled drum MIDI changed");write('h23,0);
 // A touched vibrato strip must not permanently override the parameter page.
 write('h26,70);if(dut.effective_vibrato!=70)$fatal(1,"touch vibrato");tap(952,292);
 if(!dut.fx_params[4]||dut.vibrato_override||dut.effective_vibrato!=35)$fatal(1,"vibrato switch/readback");
 pair(872,960,344,11,1);pair(872,960,392,12,2);pair(872,960,440,14,5);
 tap(808,46);tap(932,194);if(dut.bend!=0||dut.gain!=256||dut.effective_vibrato!=0||dut.fx_params[6]||dut.fx_params[119:112]!=100)$fatal(1,"expression reset incomplete");
 tap(48,300);tap(360,254);if(dut.fx_params[15:8]!=24)$fatal(1,"disabled effect knob changed");tap(352,142);
 pair(176,360,254,1,1);pair(176,360,350,2,8);pair(176,360,446,3,8);
 tap(648,142);pair(472,656,254,4,1);pair(472,656,350,5,5);pair(472,656,446,6,8);
 tap(944,142);pair(768,952,254,7,5);pair(768,952,350,8,1);pair(768,952,446,9,8);
 tap(256,552);if(!dut.fx_params[5])$fatal(1,"global bypass");tap(352,142);if(dut.fx_params[5])$fatal(1,"effect switch did not leave bypass");
 tap(880,552);repeat(24)@(negedge clk);
 if(dut.fx_params[119:0]!={8'd100,8'd32,8'd35,8'd55,8'd5,8'd115,8'd5,8'd70,8'd115,8'd70,8'd12,8'd102,8'd128,8'd24,8'd0})$fatal(1,"all strong defaults must restore from real LCD reset");
 tap(48,376);write('h2d,3);tap(900,148);if(dut.practice_running)$fatal(1,"empty uploaded score start was not disabled");
 write('h2d,2);if(dut.practice_length!=16)$fatal(1,"song preview length stale");tap(900,148);if(!dut.practice_running||dut.practice_gate)$fatal(1,"visual practice start");
 tap(632,254);if(!dut.practice_paused)$fatal(1,"pause");tap(760,254);if(dut.practice_paused)$fatal(1,"resume");tap(908,254);if(dut.practice_running)$fatal(1,"end practice");
 tap(48,516);tap(226,192);tap(648,342);if(dut.selected!=3)$fatal(1,"proof voice range");tap(760,342);if(dut.selected!=0)$fatal(1,"proof next voice");tap(904,342);if(!dut.test_muted)$fatal(1,"proof mute");
 tap(808,46);if(dut.test_count||dut.stopped||dut.page!=0)$fatal(1,"return to performance did not leave proof mode");
 $display("PASS ui_actions: real touch record/arm/stop/replay/clear; all ADSR, pitch, FX pairs and resets; audition and mapping; disabled states; practice and proof navigation");$finish;
end
initial begin #140000000;$fatal(1,"UI action timeout");end
endmodule
config cfg_tb_ui_actions;
 design work.tb_ui_actions;default liblist work;
 instance tb_ui_actions.dut.display use work.lcd_test_stub;
 instance tb_ui_actions.dut.clock_gen use work.merged_clock_test_stub;
endconfig
