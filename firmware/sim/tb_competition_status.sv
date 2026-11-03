`timescale 1ns/1ps
module tb_competition_status;
reg clk=0;always #5 clk=~clk;reg request=0;reg [8:0] block=2;wire tx,busy,waiting;wire [16:0] address;reg [15:0] data=0;
always @(posedge clk)data<=address[15:0]^16'h55aa^(address[16]?16'h1357:16'd0);
reg [17:0] audio_count=513;reg [335:0] payload=336'h123456789abcdef;
competition_status #(.PERIOD(16)) dut(.clk(clk),.bit_clocks(12'd8),.payload(payload),.fx(128'h1234),.fx_revision(8'd7),.flags(8'd8),.rx_count(16'd10),.serial_keys(16'h8001),.live_keys(16'h8001),.active_envelopes(16'h8001),.peak(16'd123),.phase0(16'd1),.frame_count(16'd2),.last_byte(8'h66),.envelope0(8'd255),.attack(8'd0),.decay(8'd5),.sustain(8'd160),.release_time(8'd5),.param_count(8'd3),.volume(4'd8),
 .audio_request(request),.audio_block(block),.audio_count(audio_count),.audio_recording(1'b0),.audio_available(1'b1),.audio_data(data),.audio_address(address),.audio_busy(busy),.audio_waiting(waiting),.tx(tx));
reg [7:0] bytes[0:600];reg [7:0] b,crc;integer n,i,kind,samples;reg [15:0] word;
task read_byte(output [7:0] out);
begin @(negedge tx);repeat(12)@(posedge clk);#1;out[0]=tx;for(integer k=1;k<8;k++)begin repeat(8)@(posedge clk);#1;out[k]=tx;end repeat(8)@(posedge clk);#1;if(tx!==1)$fatal(1,"UART stop bit");end endtask
task packet;
begin
 read_byte(bytes[0]);read_byte(bytes[1]);read_byte(bytes[2]);read_byte(bytes[3]);kind=bytes[2];
 if(bytes[0]!='ha5||bytes[1]!='h5a)$fatal(1,"packet header");
 if(kind==7)begin for(i=4;i<8;i++)read_byte(bytes[i]);samples={bytes[7],bytes[6]};n=9+samples*2;end
 else n=kind==4?40:kind==5?22:kind==6?48:0;
 if(n==0||n>521)$fatal(1,"packet length");
 for(i=kind==7?8:4;i<n;i++)read_byte(bytes[i]);crc=0;for(i=2;i<n-1;i++)crc=crc^bytes[i];if(crc!==bytes[n-1])$fatal(1,"packet CRC");
 if(kind==7)begin
  for(i=0;i<samples;i++)begin word={bytes[9+i*2],bytes[8+i*2]};if(word!==((({bytes[5],bytes[4]}*256+i)&65535)^16'h55aa^(bytes[5]?16'h1357:16'd0)))$fatal(1,"PCM export word %d",i);end
 end
end endtask
initial begin
 request=1;@(negedge clk);request=0;packet();if(kind!=7||samples!=1||bytes[4]!=2)$fatal(1,"short final PCM block");
 @(negedge clk);block=0;request=1;@(negedge clk);request=0;packet();if(kind!=4)$fatal(1,"V4 fairness during PCM export");packet();if(kind!=5)$fatal(1,"V5 fairness");packet();if(kind!=6)$fatal(1,"V6 fairness");packet();if(kind!=7||samples!=256)$fatal(1,"full PCM block kind=%d samples=%d",kind,samples);
 packet();if(kind!=4||bytes[30]!='h66||bytes[7]!=1||bytes[8]!='h80)$fatal(1,"V4 compatibility");
 packet();if(kind!=5||bytes[4]!=7)$fatal(1,"V5 compatibility");
 packet();if(kind!=6||{bytes[5],bytes[4]}!==payload[15:0])$fatal(1,"V6 telemetry");
 @(negedge clk);block=511;audio_count=131072;request=1;@(negedge clk);request=0;
 packet();while(kind!=7)packet();if(samples!=256||bytes[5]!=1||bytes[4]!=255)$fatal(1,"upper PCM bank export");
 $display("PASS competition_status: real UART V4/V5/V6 checksums and V7 PCM readback, partial/full blocks, signed bits and synchronous RAM alignment");$finish;
end
initial begin #10000000;$fatal(1,"status timeout");end endmodule
