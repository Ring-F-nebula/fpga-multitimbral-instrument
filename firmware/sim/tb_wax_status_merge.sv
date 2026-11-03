`timescale 1ns/1ps
module tb_wax_status_merge;
 reg clk=0;always #5 clk=~clk;
 reg [783:0] wax=0;reg request=0;wire tx;wire [16:0] address;reg [15:0] pcm=0;
 always @(posedge clk)pcm<=address[15:0]^16'h56ab;
 competition_status #(.PERIOD(16),.ENABLE_WAX(1)) dut(.clk(clk),.bit_clocks(12'd8),.payload(336'h123456),
  .wax(wax),.fx(128'h789abc),.fx_revision(8'd3),.flags(8'd8),.rx_count(16'd10),.serial_keys(16'h8001),.live_keys(16'h8001),
  .active_envelopes(16'h8001),.peak(16'd123),.phase0(16'd1),.frame_count(16'd2),.last_byte(8'h66),.envelope0(8'd255),
  .attack(8'd0),.decay(8'd5),.sustain(8'd160),.release_time(8'd5),.param_count(8'd3),.volume(4'd8),
  .audio_request(request),.audio_block(9'd0),.audio_count(18'd256),.audio_recording(1'b0),.audio_available(1'b1),
  .audio_data(pcm),.audio_address(address),.tx(tx));
 reg [7:0] bytes[0:520],crc;integer kind,n,i;
 task read_byte(output [7:0] b);begin
  @(negedge tx);repeat(12)@(posedge clk);#1;b[0]=tx;
  for(integer j=1;j<8;j++)begin repeat(8)@(posedge clk);#1;b[j]=tx;end
  repeat(8)@(posedge clk);#1;if(tx!==1)$fatal(1,"status UART stop bit");
 end endtask
 task packet;begin
  for(i=0;i<4;i++)read_byte(bytes[i]);kind=bytes[2];
  if(bytes[0]!=8'ha5||bytes[1]!=8'h5a)$fatal(1,"status header");
  n=kind==4?40:kind==5?22:kind==6?48:kind==8?103:kind==7?521:0;
  if(n==0)$fatal(1,"unexpected status version %0d",kind);
  for(i=4;i<n;i++)read_byte(bytes[i]);crc=0;for(i=2;i<n-1;i++)crc=crc^bytes[i];
  if(crc!==bytes[n-1])$fatal(1,"status CRC version %0d",kind);
  if(kind==8)for(i=0;i<98;i++)if(bytes[i+4]!==wax[i*8+:8])$fatal(1,"V8 pressure field byte %0d",i);
  if(kind==7)for(i=0;i<256;i++)if({bytes[9+2*i],bytes[8+2*i]}!==(i^16'h56ab))$fatal(1,"V7 PCM alignment %0d",i);
 end endtask
 initial begin
  for(i=0;i<98;i++)wax[i*8+:8]=i*7+3;
  wax[79:64]=20;wax[95:80]=10;wax[119:96]=1000;wax[143:120]=24'habcd12;wax[543:528]=256;
  packet();if(kind!=4)$fatal(1,"V4 order");packet();if(kind!=5)$fatal(1,"V5 order");packet();if(kind!=6)$fatal(1,"V6 order");
  @(negedge clk);request=1;@(negedge clk);request=0;
  packet();if(kind!=8)$fatal(1,"V8 pressure status must follow V6");packet();if(kind!=7)$fatal(1,"V7 PCM request starved by pressure status");
  packet();if(kind!=4)$fatal(1,"V4 fairness after PCM");packet();if(kind!=5)$fatal(1,"V5 fairness after PCM");
  packet();if(kind!=6)$fatal(1,"V6 fairness after PCM");packet();if(kind!=8)$fatal(1,"V8 fairness after PCM");
  $display("PASS wax_status_merge: exact V8 payload/CRC, 24-bit raw and 9-bit gain preservation, V4/V5/V6 compatibility and V7 PCM fairness/alignment");$finish;
 end
 initial begin #10000000;$fatal(1,"WAX status timeout");end
endmodule
