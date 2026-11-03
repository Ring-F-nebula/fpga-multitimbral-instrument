`timescale 1ns/1ps
module tb_uart32;
reg clk=0;always #5 clk=~clk;reg rx=1;wire [15:0] lo,hi;wire commit;wire [7:0] id,value;integer commits=0;
uart_link #(.DEFAULT_BIT_CLOCKS(16),.ALLOW_LEGACY_KEYS(0),.CONFIG_TIMEOUT(4000),.KEY_TIMEOUT(10000)) dut(.clk(clk),.rx(rx),.pressed(lo),.upper_pressed(hi),.config_commit(commit),.committed_id(id),.committed_value(value));
always @(posedge clk)if(commit)commits++;
task byte_out(input [7:0] b);begin @(negedge clk);rx=0;repeat(16)@(negedge clk);for(integer k=0;k<8;k++)begin rx=b[k];repeat(16)@(negedge clk);end rx=1;repeat(16)@(negedge clk);end endtask
task mask(input [31:0] b,input corrupt);begin byte_out('hf7);byte_out(b[7:0]);byte_out(b[15:8]);byte_out(b[23:16]);byte_out(b[31:24]);byte_out('hf7^b[7:0]^b[15:8]^b[23:16]^b[31:24]^corrupt);repeat(12)@(negedge clk);end endtask
initial begin repeat(30)@(negedge clk);mask(32'h80010001,0);if({hi,lo}!==32'h80010001)$fatal(1,"atomic 32 mask");mask(32'hffffffff,1);if({hi,lo}!==32'h80010001)$fatal(1,"CRC altered keys");
 byte_out('hf7);byte_out(0);repeat(4100)@(negedge clk);mask(32'hffffffff,0);if({hi,lo}!==32'hffffffff)$fatal(1,"partial timeout recovery");
 byte_out('hf6);byte_out(3);byte_out(0);byte_out('hf6^3);repeat(12)@(negedge clk);if({hi,lo}!==3)$fatal(1,"legacy F6 releases upper keys");
 byte_out('hf5);byte_out('h27);byte_out(32);byte_out('hf5^'h27^32);repeat(12)@(negedge clk);if(commits!=1||id!='h27||value!=32)$fatal(1,"new valid command");
 byte_out('hf5);byte_out('h27);byte_out(31);byte_out('hf5^'h27^31);repeat(12)@(negedge clk);if(commits!=1)$fatal(1,"invalid command accepted");
 repeat(10010)@(negedge clk);if({hi,lo}!==0)$fatal(1,"full 32 watchdog release");
 $display("PASS uart32: actual 8N1 F7 atomic upper/lower notes, CRC, timeout, F6 compatibility, command validation, 32-note watchdog");$finish;
end endmodule
