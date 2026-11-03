`timescale 1ns/1ps
module tb_fx_protocol;
reg clk=0;always #5 clk=~clk;
reg rx=1;wire commit;wire [7:0] id,value,count;wire [127:0] p;wire [7:0] revision;
uart_link #(.DEFAULT_BIT_CLOCKS(40),.CONFIG_TIMEOUT(4000),.ALLOW_LEGACY_KEYS(0)) link(
 .clk(clk),.rx(rx),.config_commit(commit),.committed_id(id),.committed_value(value),.param_count(count));
fx_registers regs(.clk(clk),.reset_n(1'b1),.usb_commit(commit),.usb_id(id),.usb_value(value),
 .bt_commit(1'b0),.bt_id(8'd0),.bt_value(8'd0),.stopped(1'b0),.snapshot(p),.revision(revision));
task clocks(input integer n);repeat(n)@(negedge clk);endtask
task send(input [7:0] b);begin rx=0;clocks(40);for(integer i=0;i<8;i++)begin rx=b[i];clocks(40);end rx=1;clocks(80);end endtask
task configure(input [7:0] a,b);begin send(8'hf5);send(a);send(b);send(8'hf5^a^b);clocks(20);end endtask
wire tx;
uart_status #(.PERIOD(1000),.BUILD_ID(8'h65),.FX_STATUS(1)) status(.clk(clk),.flags(8'd0),.rx_count(16'd0),.last_byte(8'd0),
 .serial_keys(16'd0),.matrix_keys(16'd0),.live_keys(16'd0),.blocked_keys(16'd0),.volume(4'd8),.bit_clocks(12'd40),.edges(16'd0),
 .peak(16'd0),.gain(9'd256),.active_envelopes(16'd0),.phase0(16'd0),.envelope0(8'd0),.frame_count(16'd0),
 .attack_sel(4'd2),.decay_sel(4'd5),.release_sel(4'd5),.sustain_level(8'd160),.bend_target(4'd0),.bend_cents(9'd0),
 .param_count(count),.tx(tx),.fx_snapshot(p),.fx_revision(revision));
reg [7:0] received[0:61];integer j;reg [7:0] check;reg packet_ok=0;
initial begin
 for(j=0;j<62;j++)begin
  @(negedge tx);clocks(60);
  for(integer k=0;k<8;k++)begin received[j][k]=tx;clocks(40);end
  if(tx!==1)$fatal(1,"stop bit");
 end
 if(received[0]!=8'ha5 || received[2]!=4 || received[30]!=8'h65)$fatal(1,"legacy status broken");
 check=0;for(j=2;j<40;j++)check^=received[j];if(check!=0)$fatal(1,"legacy checksum");
 if(received[40]!=8'ha5 || received[41]!=8'h5a || received[42]!=5 || received[43]!=8'h65)$fatal(1,"FX header");
 check=0;for(j=42;j<62;j++)check^=received[j];if(check!=0)$fatal(1,"FX checksum");
 if(received[45]!=7 || received[46]!=25 || received[47]!=200)$fatal(1,"readback stale %d %d %d",received[45],received[46],received[47]);
 packet_ok=1;
end
initial begin
 clocks(10);configure(8'h10,7);configure(8'h11,25);configure(8'h12,200);
 if(p[23:0]!={8'd200,8'd25,8'd7} || revision!=3)$fatal(1,"valid commit");
 configure(8'h12,231);configure(8'h11,0);configure(8'h10,255);configure(8'h7f,1);
 send(8'hf5);send(8'h10);send(0);send(0);
 send(8'hf5);send(8'h10);clocks(4100);send(0);send(8'he5);
 if(p[23:0]!={8'd200,8'd25,8'd7} || revision!=3 || count!=3)$fatal(1,"invalid/partial frame committed");
 wait(packet_ok);
 $display("PASS fx_protocol: framed serial writes, bounds, checksum, timeout, V4 compatibility and V5 readback");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
