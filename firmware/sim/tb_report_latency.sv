`timescale 1ns/1ps
// Warm instrument, production 26.25 MHz and actual PT8211 serial words.
// Starts at a decoded touch report, excludes touch IC scan/analog/amplifier.
module tb_report_latency;
 GSR GSR(1'b1);
reg clk=0;always #19.047619048 clk=~clk;reg reset_n=0,frame=0;reg [4:0] contacts=0;
reg [59:0] px=160,py=540;
dualmode_top dut(.clk_50m(clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(1'b1),.enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'h7f),.soft_touch(1'b1),.bend_touch(1'b1),.timbre_touch(1'b1),.fx_touch(1'b1));
initial begin force dut.clk=clk;force dut.reset_n=reset_n;force dut.startup=12'd2048;force dut.touch_frame=frame;force dut.contacts=contacts;force dut.points_x=px;force dut.points_y=py;end
reg started=0,armed=0;reg [15:0] word=0;integer bit_count=0;realtime first=-1,t0,worst=0,delay_ns;
always @(posedge dut.HP_BCK)begin
 if(!started)started=1;else begin word={word[14:0],dut.HP_DIN};if(bit_count==15)begin bit_count=0;if(armed&&first<0&&($signed(word)>=32||$signed(word)<= -32))first=$realtime;end else bit_count=bit_count+1;end
end
task report;begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(20)@(negedge clk);end endtask
integer phase;
initial begin
 #2000;reset_n=1;wait(dut.fx_ready);repeat(8)@(negedge dut.sample_tick);
 for(phase=0;phase<8;phase++)begin
  @(negedge dut.sample_tick);#(phase*21942.8571429/8);contacts=1;t0=$realtime;first=-1;armed=1;report();wait(first>=t0);delay_ns=first-t0;armed=0;
  if(delay_ns>=2000000)$fatal(1,"decoded report digital latency %f ms",delay_ns/1e6);if(delay_ns>worst)worst=delay_ns;
  $display("REPORT_LATENCY phase=%d decoded_report_to_DAC_ms=%f",phase,delay_ns/1e6);
  contacts=0;report();force dut.ui_stop=1'b1;repeat(3)@(negedge clk);release dut.ui_stop;repeat(3)@(negedge clk);force dut.ui_live=1'b1;repeat(3)@(negedge clk);release dut.ui_live;
  wait(dut.fx_ready);repeat(8)@(negedge dut.sample_tick);
 end
 $display("PASS report_latency: production clocks, all 8 sample phases, first complete DAC word magnitude >=32; worst_ms=%f; touch IC and analog path excluded",worst/1e6);$finish;
end
initial begin #60000000;$fatal(1,"latency timeout");end
endmodule
config cfg_tb_report_latency;
 design work.tb_report_latency;default liblist work;
 instance tb_report_latency.dut.display use work.lcd_test_stub;
 instance tb_report_latency.dut.clock_gen use work.merged_clock_test_stub;
endconfig
