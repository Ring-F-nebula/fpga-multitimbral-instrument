`timescale 1ns/1ps
module tb_laser_spi_main;
 GSR GSR(1'b1);
 reg clk50=0;always #10 clk50=~clk50;
 reg audio_clk=0;always #19.047619 audio_clk=~audio_clk;
 reg reset_n=0,disconnect=0,bad_first=0;
 reg [127:0] codes={8{16'd18000}};
 reg [31:0] touch=0,serial=0;
 wire [15:0] data;wire busy,first,rst,convst,cs,sclk,byte_sel;
 dualmode_top #(.LASER_ADC_RESET_CYCLES(10),.LASER_ADC_SETTLE_CYCLES(600)) dut(
 .clk_50m(clk50),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),.WAX_RX(1'b1),
 .enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'd0),
 .soft_touch(1'b1),.bend_touch(1'b1),.timbre_touch(1'b1),.fx_touch(1'b1),
 .AD7606_DOUTA(data[7]),.AD7606_BUSY(busy),.AD7606_FRSTDATA(first),
 .AD7606_RESET(rst),.AD7606_CONVST(convst),.AD7606_CS_N(cs),.AD7606_SCLK(sclk),.AD7606_BYTE_SEL(byte_sel));
 ad7606_spi_model chip(rst,convst,cs,sclk,codes,1'b0,1'b0,bad_first,disconnect,busy,first,data);
 initial begin force dut.clk=audio_clk;force dut.reset_n=reset_n;force dut.touch_keys=touch;force dut.usb_lo=serial[15:0];force dut.usb_hi=serial[31:16];end
 task clocks(input integer n);repeat(n)@(negedge audio_clk);endtask
 task frames(input integer n);repeat(n)begin @(posedge dut.laser_frame);clocks(8);end endtask
 task command(input [7:0] id,value);begin
  force dut.usb_commit=1;force dut.usb_id=id;force dut.usb_value=value;clocks(2);
  release dut.usb_commit;release dut.usb_id;release dut.usb_value;clocks(5);
 end endtask
 task audible;integer heard;begin
  heard=0;repeat(180)begin @(negedge dut.sample_tick);if(dut.pcm!=0)heard++;end
  if(heard<100||dut.overrun)$fatal(1,"main audio missing/overrun");
 end endtask
 integer ch;reg [31:0] masks[0:6];
 initial begin
  masks[0]=1;masks[1]=4;masks[2]=16;masks[3]=32;masks[4]=128;masks[5]=512;masks[6]=2048;
  clocks(12);reset_n=1;frames(14);wait(dut.fx_ready);
  if(byte_sel!==0||dut.laser_keys||dut.live_keys)$fatal(1,"mode/dark boot");
  command(4,0);codes={8{16'd1000}};frames(10);
  if(dut.laser_armed!==127)$fatal(1,"dual-clock arming");
  for(ch=0;ch<7;ch++)begin
   codes[ch*16+:16]=18000;frames(4);
   if(dut.live_keys!==masks[ch])$fatal(1,"channel mapping %0d",ch);
   audible();codes[ch*16+:16]=1000;frames(4);
   if(dut.live_keys)$fatal(1,"release");
  end
  codes={8{16'd18000}};frames(4);if(dut.live_keys!==32'hab5)$fatal(1,"chord");audible();
  codes={8{16'd1000}};frames(4);codes[15:0]=18000;frames(4);
  touch=1;clocks(8);codes[15:0]=1000;frames(4);if(dut.live_keys!==1)$fatal(1,"laser release silenced touch");
  codes[15:0]=18000;frames(4);touch=0;clocks(8);if(dut.live_keys!==1)$fatal(1,"touch release silenced laser");
  serial=2;clocks(8);if(dut.live_keys!==3)$fatal(1,"serial union");serial=0;
  command('h50,1);codes[15:0]=1000;frames(4);codes[15:0]=18000;frames(4);command('h50,0);
  if(!dut.record_has_notes||dut.record_count<2)$fatal(1,"laser event recording");
  command('h1f,1);clocks(300);if(dut.live_keys)$fatal(1,"STOP");
  command('h1f,0);frames(3);if(dut.live_keys)$fatal(1,"held laser after STOP");
  touch=1;clocks(8);if(dut.live_keys!==1)$fatal(1,"independent fresh touch blocked by held laser");touch=0;
  codes[15:0]=1000;frames(4);codes[15:0]=18000;frames(4);if(dut.live_keys!==1)$fatal(1,"STOP rearm");
  disconnect=1;wait(dut.laser_fault);clocks(40000);if(dut.laser_keys||dut.live_keys)$fatal(1,"ADC disconnect release");
  disconnect=0;frames(12);if(dut.laser_armed[0]||dut.live_keys)$fatal(1,"dark reconnect");
  codes={8{16'd1000}};frames(10);codes[15:0]=18000;frames(4);if(dut.live_keys!==1)$fatal(1,"reconnect rearm");
  force dut.page=3'd6;command('h2e,1);frames(5);
  if(dut.practice_hits||dut.practice_score||dut.matrix_scoring_keys)$fatal(1,"laser must not score pressure matrix");
  release dut.page;
  $display("PASS laser_spi_main: actual 50MHz/26.25MHz crossing, seven channels to main PCM, chord, independent touch/serial releases, recording, STOP, disconnect/rearm, pressure-only scoring");$finish;
 end
 initial begin #250000000;$fatal(1,"laser main timeout");end
endmodule
config cfg_tb_laser_spi_main;
 design work.tb_laser_spi_main;default liblist work;
 instance tb_laser_spi_main.dut.display use work.lcd_test_stub;
 instance tb_laser_spi_main.dut.clock_gen use work.merged_clock_test_stub;
endconfig
