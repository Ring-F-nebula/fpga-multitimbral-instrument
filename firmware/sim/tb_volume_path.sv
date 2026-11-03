`timescale 1ns/1ps
module tb_volume_path;
 GSR GSR(1'b1);
 reg clk=0;always #5 clk=~clk;reg reset_n=0,frame_valid=0;
 reg [4:0] contacts=0;reg [59:0] points_x=0,points_y=0;
 dualmode_top dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),.enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'h7f),.soft_touch(1'b1),.bend_touch(1'b1),.timbre_touch(1'b1),.fx_touch(1'b1));
 initial begin force dut.clk=clk;force dut.reset_n=reset_n;force dut.touch_frame=frame_valid;force dut.contacts=contacts;force dut.points_x=points_x;force dut.points_y=points_y;end
 // Decode the real serial DAC stream, including both channels.
 integer slot=0,words=0;reg started=0;reg [15:0] shift=0,expected=0;
 always @(posedge clk)if(dut.sample_tick)begin expected=dut.pcm;slot=0;started=1;end
 always @(posedge dut.HP_BCK)if(started)begin
  if(dut.HP_WS!==(slot>=16))$fatal(1,"DAC channel alignment");
  shift={shift[14:0],dut.HP_DIN};
  if(slot==15||slot==31)begin if(shift!==expected)$fatal(1,"DAC source/serial mismatch");words++;end
  slot++;
 end
 task report;begin @(negedge clk);frame_valid=1;@(negedge clk);frame_valid=0;repeat(24)@(negedge clk);end endtask
 task button(input integer x,y);begin contacts=1;report();contacts=3;points_x[23:12]=x;points_y[23:12]=y;report();contacts=1;report();end endtask
 task sample;begin @(posedge dut.sample_tick);@(negedge clk);end endtask
 task write(input [7:0] id,value);begin @(negedge clk);force dut.ui_id=id;force dut.ui_value=value;force dut.ui_commit=1'b1;@(negedge clk);release dut.ui_id;release dut.ui_value;release dut.ui_commit;repeat(8)@(negedge clk);end endtask
 task energy(output real power);integer j;begin power=0;for(j=0;j<512;j++)begin sample();power+=real'($signed(dut.pcm))*real'($signed(dut.pcm));end end endtask
 real e8,e4;integer i;reg pa;
 initial begin
  repeat(4)@(negedge clk);reset_n=1;wait(dut.fx_ready);repeat(2100)sample();pa=dut.PA_EN;if(pa!==0)$fatal(1,"amp startup");
  write(1,0);write(2,0);write(3,255);write(4,0);
  // 100% wet delay: volume must control buffered audio, not just dry input.
  write('h11,1);write('h13,255);write('h10,1);
  contacts=1;points_x=160;points_y=540;report();repeat(800)sample();energy(e8);
  for(i=0;i<4;i++)button(550,46);if(dut.volume!=4)$fatal(1,"touch master volume 8 -> 4");
  repeat(300)sample();energy(e4);
  if(e8<1000||e4/e8<0.20||e4/e8>0.30)$fatal(1,"post-effect volume ratio squared %f",e4/e8);
  for(i=0;i<4;i++)button(550,46);if(dut.volume!=0)$fatal(1,"touch master volume 4 -> 0");
  repeat(270)begin sample();if(!dut.fx_ready||dut.PA_EN!==pa)$fatal(1,"zero volume reset effects/amplifier");end
  repeat(40)begin sample();if(dut.pcm!==0)$fatal(1,"wet tail audible at volume zero");end
  for(i=0;i<8;i++)button(702,46);repeat(300)sample();energy(e8);if(dut.volume!=8||e8<1000)$fatal(1,"volume restore");
  if(words<6000)$fatal(1,"insufficient real DAC words checked");
  $display("PASS volume_path: actual touch 8/4/0/8 -> 100%% wet FX -> master -> real decoded stereo DAC; squared gain ratio=%f; stable amp/FX, zero silence",e4/e8);$finish;
 end
 initial begin #50000000;$fatal(1,"volume path timeout");end
endmodule
config cfg_tb_volume_path;
 design work.tb_volume_path;default liblist work;
 instance tb_volume_path.dut.display use work.lcd_test_stub;
 instance tb_volume_path.dut.clock_gen use work.merged_clock_test_stub;
endconfig
