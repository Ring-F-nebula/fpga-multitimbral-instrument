`timescale 1ns/1ps
module tb_bluetooth;
    reg clk=0,rx=1;
    always #5 clk=~clk;
    wire [15:0] keys; wire mode_event,mode_auto; wire [7:0] params;
    integer mode_seen=0;
    uart_link #(.DEFAULT_BIT_CLOCKS(2734),.KEY_TIMEOUT(400000),.CONFIG_TIMEOUT(100000)) dut(
        .clk(clk),.rx(rx),.pressed(keys),.mode_event(mode_event),.mode_auto(mode_auto),.param_count(params));
    always @(posedge clk) if(mode_event) mode_seen<=mode_seen+1;
    task clocks(input integer n);repeat(n)@(negedge clk);endtask
    task byte_out(input [7:0] b);
        rx=0;clocks(2734);for(integer j=0;j<8;j=j+1)begin rx=b[j];clocks(2734);end
        rx=1;clocks(2740);
    endtask
    task mask(input [15:0] m,input corrupt);
        byte_out(8'hf6);byte_out(m[7:0]);byte_out(m[15:8]);byte_out(8'hf6^m[7:0]^m[15:8]^corrupt);clocks(5);
    endtask
    initial begin
        clocks(10);mask(16'h8011,0);if(keys!==16'h8011)$fatal(1,"9600 default / atomic chord");
        mask(16'hffff,1);if(keys!==16'h8011)$fatal(1,"bad checksum changed notes");
        mask(16'h8011,0);clocks(230000);mask(16'h8011,0);if(keys!==16'h8011)$fatal(1,"heartbeat hold");
        byte_out(8'hf5);byte_out(6);byte_out(1);byte_out(8'hf2);clocks(5);
        if(mode_seen!=1 || !mode_auto)$fatal(1,"remote auto command");
        mask(0,0);if(keys!==0)$fatal(1,"release chord");
        mask(16'h0080,0);byte_out(8'hf6);byte_out(8'hff);clocks(100005);
        if(keys!==16'h0080)$fatal(1,"partial packet mutated notes");
        byte_out(8'h55);clocks(310000);if(keys!==0)$fatal(1,"noise refreshed note watchdog");
        $display("PASS Bluetooth: factory 9600 UART, atomic masks, checksum rejection, heartbeat, mode, partial timeout, watchdog");$finish;
    end
    initial begin #40000000;$fatal(1,"timeout");end
endmodule
