`timescale 1ns/1ps
// Full host F5 UART -> uart_link whitelist -> wax_settings -> WAX UART test.
// EXPECT_LEGACY_BLOCK reproduces the frozen baseline issue intentionally.
module tb_wax_host_config #(parameter EXPECT_LEGACY_BLOCK=0);
 reg clk=0; always #5 clk=~clk;
 reg reset_n=0,host_rx=1;
 wire commit,recalibrate,enabled,continuous,configured,wax_tx,rx_valid,rx_error;
 wire [7:0] id,value,rx_data;
 wire [15:0] on_delta,off_delta;
 wire [23:0] full_scale;
 integer commits=0,recals=0,n=0,before_count,before_recal;
 reg [7:0] captured[0:15];
 uart_link #(.DEFAULT_BIT_CLOCKS(8),.CONFIG_TIMEOUT(2048)) link(
  .clk(clk),.rx(host_rx),.config_commit(commit),.committed_id(id),.committed_value(value),
  .upper_pressed(),.pressed(),.rx_count(),.last_byte(),.edges(),.bit_clocks(),.trained(),
  .attack_sel(),.decay_sel(),.release_sel(),.volume(),.sustain_level(),.param_count(),
  .volume_event(),.mode_event(),.mode_auto());
 wax_settings settings(.clk(clk),.reset_n(reset_n),.commit(commit),.id(id),.value(value),
  .frame_valid(1'b0),.detected_model(8'd1),.ack_valid(1'b0),.ack_ok(1'b0),
  .recalibrate(recalibrate),.enabled(enabled),.continuous(continuous),
  .on_delta(on_delta),.off_delta(off_delta),.full_scale(full_scale),
  .tx(wax_tx),.configured(configured));
 wax_uart_rx #(.BIT_CLOCKS(228)) monitor(.clk(clk),.reset_n(reset_n),.rx(wax_tx),
  .valid(rx_valid),.data(rx_data),.error(rx_error));
 always @(posedge clk)begin
  if(commit)commits=commits+1;
  if(recalibrate)recals=recals+1;
  if(rx_valid)begin captured[n]=rx_data;n=n+1;end
 end
 task octet(input [7:0] x);integer i;begin
  @(negedge clk);host_rx=0;repeat(8)@(negedge clk);
  for(i=0;i<8;i=i+1)begin host_rx=x[i];repeat(8)@(negedge clk);end
  host_rx=1;repeat(8)@(negedge clk);
 end endtask
 task command(input [7:0] a,v,input corrupt);begin
  octet(8'hf5);octet(a);octet(v);octet(8'hf5^a^v^{7'd0,corrupt});
  repeat(20)@(negedge clk);
 end endtask
 initial begin
  repeat(8)@(negedge clk);reset_n=1;repeat(8)@(negedge clk);
  command(8'h71,8'd35,0);
  if(EXPECT_LEGACY_BLOCK)begin
   if(commits!=0||on_delta!=20)$fatal(1,"unexpected legacy filter behavior");
   $display("PASS legacy_filter_reproduced: frozen baseline blocks pressure F5 IDs; patch required for runtime parameters");
   $finish;
  end
  if(commits!=1||on_delta!=35)$fatal(1,"host pressure command blocked at whitelist");
  command(8'h73,8'd15,0);if(off_delta!=15)$fatal(1,"off threshold host write");
  command(8'h75,8'h34,0);command(8'h76,8'h12,0);command(8'h77,8'd0,0);
  if(full_scale!=24'h001234)$fatal(1,"24-bit host full scale");
  command(8'h79,8'd0,0);if(continuous)$fatal(1,"host continuous mode");
  command(8'h78,8'd0,0);if(enabled)$fatal(1,"host disable");
  command(8'h78,8'd1,0);if(!enabled)$fatal(1,"host enable");
  before_recal=recals;command(8'h70,8'd1,0);if(recals<=before_recal)$fatal(1,"host recalibration");
  before_count=commits;command(8'h79,8'd2,0);command(8'h7a,8'd4,0);command(8'h71,8'd99,1);
  if(commits!=before_count||on_delta!=35)$fatal(1,"invalid values or corrupt host checksum accepted");
  command(8'h7a,8'd3,0);wait(n==7);repeat(300)@(negedge clk);
  if(captured[0]!=8'haa||captured[1]!=8'h55||captured[2]!=3||captured[3]!=1||
     captured[4]!=0||captured[5]!=0||captured[6]!=13)$fatal(1,"host-to-module configuration bytes");
  $display("PASS wax_host_config: F5 UART whitelist patch, thresholds, enable, mode, recalibration, invalid-value/checksum rejection, real module setup TX");
  $finish;
 end
 initial begin #2000000;$fatal(1,"host configuration timeout");end
endmodule
