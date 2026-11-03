`timescale 1ns/1ps
module tb_knob5_top;
GSR GSR(1'b1);reg clk=0;always #5 clk=~clk;reg rst=0,tick=0;
reg [4:0] a=31,b=31,sw=31;reg [31:0] keys=0;
reg frame=0;reg [4:0] contacts=0;reg [59:0] px=0,py=0;
dualmode_top dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),.WAX_RX(1'b1),.enc_a_n(a),.enc_b_n(b),.enc_sw_n(sw[4]));
defparam dut.knobs.FILTER_CYCLES=2,dut.knobs.BUTTON_CYCLES=4;
initial begin force dut.clk=clk;force dut.reset_n=rst;force dut.sample_tick=tick;force dut.touch_keys=keys;force dut.axis_valid=3'd0;end
initial begin force dut.touch_frame=frame;force dut.contacts=contacts;force dut.points_x=px;force dut.points_y=py;end
task sample;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(575)@(negedge clk);end endtask
task waitc(input integer n);repeat(n)@(negedge clk);endtask
task turn(input integer n);begin b[n]=0;waitc(12);a[n]=0;waitc(12);b[n]=1;waitc(12);a[n]=1;waitc(30);end endtask
task push(input integer n);begin sw[n]=0;waitc(20);sw[n]=1;waitc(30);end endtask
task report;begin @(negedge clk);frame=1;@(negedge clk);frame=0;waitc(24);end endtask
task tap(input integer x,y);begin contacts=0;report();contacts=1;px=x;py=y;report();contacts=0;report();end endtask
task write(input [7:0] x,y);begin @(negedge clk);force dut.ui_id=x;force dut.ui_value=y;force dut.ui_commit=1'b1;@(negedge clk);release dut.ui_id;release dut.ui_value;release dut.ui_commit;waitc(8);end endtask
longint quiet,loud;integer j;
initial begin waitc(5);rst=1;wait(dut.fx_ready);repeat(10)sample();
 write(2,0);write(3,255);write(4,0);write(5,3);keys=3;repeat(80)sample();quiet=0;
 repeat(256)begin sample();quiet+=dut.pcm<0?-dut.pcm:dut.pcm;end
 repeat(8)turn(0);if(dut.volume!=11)$fatal(1,"top volume route");repeat(40)sample();loud=0;
 repeat(256)begin sample();loud+=dut.pcm<0?-dut.pcm:dut.pcm;end
 if(quiet==0||loud<=quiet*2)$fatal(1,"knob must change actual PCM amplitude");
 turn(1);if(dut.bend!=10||dut.bend_target!=1)$fatal(1,"top single voice target");
 turn(2);if(!dut.fx_params[3])$fatal(1,"top glide FX route");
 turn(3);if(!dut.fx_params[4]||dut.effective_vibrato!=5)$fatal(1,"top vibrato route");
 turn(4);if(dut.attack!=1)$fatal(1,"top ADSR");push(4);turn(4);if(dut.decay!=1)$fatal(1,"top D");
 tap(48,224);tap(204,498);
 if(dut.attack!=7||dut.decay!=8||dut.sustain!=192||dut.release_time!=9)$fatal(1,"touch soft preset with knobs");
 turn(4);if(dut.decay!=9||dut.attack!=7||dut.sustain!=192)$fatal(1,"knob must continue from real preset D");
 tap(340,498);turn(4);if(dut.attack!=0||dut.decay!=7||dut.sustain!=0||dut.release_time!=5)$fatal(1,"touch short preset and knob coherence");
 push(4);turn(4);if(dut.sustain!=8)$fatal(1,"S after screen preset");
 push(4);turn(4);if(dut.release_time!=6)$fatal(1,"R after screen preset");
 write('h1f,1);repeat(10)sample();if(dut.pcm!=0)$fatal(1,"STOP");turn(0);if(!dut.stopped)$fatal(1,"knob resumed STOP");
 $display("PASS knob5_top: physical inputs through production router, actual PCM loudness, newest single target, glide/vibrato, live screen presets plus all four ADSR knob fields, STOP preservation");$finish;
end
initial begin #30000000;$fatal(1,"timeout");end
endmodule
config cfg_tb_knob5_top;
 design work.tb_knob5_top;default liblist work;
 instance tb_knob5_top.dut.display use work.lcd_test_stub;
 instance tb_knob5_top.dut.clock_gen use work.merged_clock_test_stub;
endconfig
