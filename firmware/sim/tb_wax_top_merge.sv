`timescale 1ns/1ps
// Actual serial WAX frames -> unchanged frontend -> production control/synth/
// effects/master/DAC. Only LCD/PLL are stubbed. Watchdog shortened in this
// fixture only; production WAX constants and packet timing remain unchanged.
module tb_wax_top_merge;
 GSR GSR(1'b1);
 reg clk=0;always #5 clk=~clk;reg reset_n=0,wax_rx=1,host_rx=1;
 wire wax_tx;reg [383:0] samples=0;
 dualmode_top dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(host_rx),.BT_RX(1'b1),.WAX_RX(wax_rx),.WAX_TX(wax_tx),
  .enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'h7f),.soft_touch(1'b1),.bend_touch(1'b1),.timbre_touch(1'b1),.fx_touch(1'b1));
 defparam dut.wax_input.pressure.STALE_CYCLES=600000;
 initial begin force dut.clk=clk;force dut.reset_n=reset_n;end
 wire tx_valid,tx_error;wire [7:0] tx_data;integer tx_count=0;reg [7:0] setup_bytes[0:6];
 wax_uart_rx monitor(.clk(clk),.reset_n(reset_n),.rx(wax_tx),.valid(tx_valid),.error(tx_error),.data(tx_data));
 always @(posedge clk)if(tx_valid&&tx_count<7)begin setup_bytes[tx_count]=tx_data;tx_count=tx_count+1;end
 task clocks(input integer n);repeat(n)@(negedge clk);endtask
 task byte_out(input [7:0] b,input bit host);begin
  @(negedge clk);if(host)host_rx=0;else wax_rx=0;clocks(228);
  for(integer j=0;j<8;j++)begin if(host)host_rx=b[j];else wax_rx=b[j];clocks(228);end
  if(host)host_rx=1;else wax_rx=1;clocks(228);
 end endtask
 task command(input [7:0] a,b);begin byte_out('hf5,1);byte_out(a,1);byte_out(b,1);byte_out('hf5^a^b,1);clocks(32);end endtask
 task idle_values;begin for(integer j=0;j<16;j++)samples[j*24+:24]=100+j;end endtask
 task frame;reg [7:0] sum,b;begin
  sum=0;byte_out('haa,0);byte_out('h55,0);byte_out(3,0);byte_out(48,0);
  for(integer j=0;j<16;j++)for(integer k=2;k>=0;k--)begin b=samples[j*24+k*8+:8];sum=sum+b;byte_out(b,0);end
  byte_out(sum,0);byte_out(13,0);clocks(600);
 end endtask
 task audio_frames(input integer n);begin repeat(n)begin @(negedge dut.sample_tick);@(negedge clk);end end endtask
 integer i,heard;reg [8:0] tail_gain;
 initial begin
  clocks(8);reset_n=1;wait(dut.fx_ready);
  // Threshold writes intentionally invalidate calibration in the supplied
  // module. Exercise the host path before the unloaded calibration frames.
  command('h71,35);if(dut.wax_on!=35)$fatal(1,"real main UART pressure whitelist/config routing");command('h71,20);
  idle_values();repeat(10)frame();
  if(!dut.wax_ready||dut.wax_keys||dut.live_keys||dut.wax_model!=3||dut.wax_cal!=16'hffff)$fatal(1,"WAX real UART calibration/idle");
  if(tx_count!=7||setup_bytes[0]!=8'haa||setup_bytes[1]!=8'h55||setup_bytes[2]!=3||setup_bytes[3]!=1||setup_bytes[6]!=13)$fatal(1,"auto setup must retain detected model and 100 ms command");
  byte_out('haa,0);byte_out('h55,0);byte_out(0,0);byte_out(1,0);byte_out(13,0);clocks(100);if(!dut.wax_configured)$fatal(1,"WAX ACK propagation");
  command('h50,1);if(!dut.recording)$fatal(1,"host record start");samples[23:0]=600;samples[15*24+:24]=1115;frame();if(dut.wax_keys)$fatal(1,"single frame spike reached engine");frame();
  if(dut.live_keys!==32'h00008001||dut.voice_gains[8:0]!=128||dut.voice_gains[15*9+:9]!=256)$fatal(1,"real independent pressure onset and gain");
  heard=0;repeat(180)begin audio_frames(1);if(dut.pcm!=0)heard++;end
  if(heard<120||dut.active_count!=2||dut.overrun)$fatal(1,"pressure-to-real-audio");
  if(dut.wax_telemetry[63:48]!=16'h8001||dut.wax_telemetry[66*8+:16]!=128||dut.wax_telemetry[(66+15*2)*8+:16]!=256)$fatal(1,"actual pressure telemetry packing");
  tail_gain=dut.voice_gains[8:0];idle_values();frame();if(dut.live_keys||dut.voice_gains[8:0]!=tail_gain)$fatal(1,"pressure release gate/tail gain");
  command('h50,0);audio_frames(3);if(dut.recording||dut.record_count<2||!dut.record_has_notes)$fatal(1,"pressure recording/count/notes: %0d/%0d/%0d",dut.recording,dut.record_count,dut.record_has_notes);
  force dut.page=3'd6;command('h2e,1);wait(dut.fx_ready);audio_frames(80);
  if(!dut.practice_running||dut.practice_cue!=1||dut.practice_gate||dut.pcm!=0)$fatal(1,"practice must remain a silent visual guide");
  samples[23:0]=600;samples[1*24+:24]=601;frame();frame();audio_frames(16);
  if(dut.practice_hits||dut.practice_score||dut.practice_feedback!=4||dut.matrix_last_keys!=3)$fatal(1,"real serial simultaneous A0+A1 was mis-scored");
  idle_values();frame();samples[23:0]=600;frame();frame();audio_frames(120);
  if(dut.practice_hits!=1||dut.live_keys!=1||dut.pcm==0)$fatal(1,"pressure must drive actual practice score/audio");
  command('h1f,1);audio_frames(4);if(dut.live_keys||dut.pcm!=0)$fatal(1,"STOP pressure audio");
  command('h1f,0);frame();if(dut.live_keys)$fatal(1,"held pressure retriggered after STOP/resume");
  idle_values();frame();samples[23:0]=600;frame();frame();if(dut.live_keys!=1)$fatal(1,"fresh pressure after STOP release");
  clocks(610000);if(dut.wax_online||dut.wax_ready||dut.wax_keys||dut.live_keys)$fatal(1,"watchdog release did not reach engine");
  idle_values();repeat(10)frame();if(!dut.wax_ready||dut.live_keys)$fatal(1,"pressure reconnect/recalibration");
  command('h2e,0);release dut.page;for(i=0;i<16;i++)samples[i*24+:24]=1100+i;frame();frame();audio_frames(160);
  if(dut.live_keys!==32'h0000ffff||dut.active_count!=16||dut.overrun)$fatal(1,"16 physical pressure voices");
  for(i=0;i<16;i++)if(dut.voice_gains[i*9+:9]!=256)$fatal(1,"16 full-scale independent gains");
  command('h78,0);clocks(100);if(dut.wax_keys||dut.live_keys)$fatal(1,"host disable did not release pressure");
  $display("PASS wax_top_merge: serial frames, detected-model setup/ACK, real host threshold command, two-frame qualification, independent pressure-to-PCM, event recording, silent practice/scoring, STOP, timeout/reconnect and 16-voice concurrency");$finish;
 end
 initial begin #150000000;$fatal(1,"WAX top integration timeout");end
endmodule
config cfg_tb_wax_top_merge;
 design work.tb_wax_top_merge;default liblist work;
 instance tb_wax_top_merge.dut.display use work.lcd_test_stub;
 instance tb_wax_top_merge.dut.clock_gen use work.merged_clock_test_stub;
endconfig
