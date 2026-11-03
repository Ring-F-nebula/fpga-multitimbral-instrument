`timescale 1ns/1ps
module tb_spp_uart_profiles;
    reg clk=0,rx=1;
    always #5 clk=~clk;
    wire [15:0] keys;
    wire [11:0] bit_clocks;
    wire trained;
    integer period=2734,intergap=6;
    uart_link #(.DEFAULT_BIT_CLOCKS(2734),.ALLOW_LEGACY_KEYS(0),.KEY_TIMEOUT(600000),.CONFIG_TIMEOUT(100000)) dut(
        .clk(clk),.rx(rx),.pressed(keys),.bit_clocks(bit_clocks),.trained(trained));
    task clocks(input integer n);repeat(n)@(negedge clk);endtask
    task byte_out(input [7:0] b);
        rx=0;clocks(period);
        for(integer j=0;j<8;j=j+1)begin rx=b[j];clocks(period);end
        rx=1;clocks(period+intergap);
    endtask
    task mask(input [15:0] m,input corrupt);
        byte_out(8'hf6);byte_out(m[7:0]);byte_out(m[15:8]);byte_out(8'hf6^m[7:0]^m[15:8]^corrupt);clocks(5);
    endtask
    task train(input integer p);
        rx=1;clocks(bit_clocks*40);period=p;
        repeat(24)byte_out(8'h55);
        clocks(period*40);
        if(!trained || bit_clocks<p-1 || bit_clocks>p+1)$fatal(1,"autobaud mismatch: wanted %d got %d",p,bit_clocks);
        mask(16'h0241,0);if(keys!==16'h0241)$fatal(1,"trained SPP mask failed at bit period %d",p);
        byte_out(8'h90);byte_out(8'h80);byte_out(8'hf0);clocks(5);
        if(keys!==16'h0241)$fatal(1,"unframed wireless bytes changed keys");
        mask(16'hffff,1);if(keys!==16'h0241)$fatal(1,"bad F6 checksum accepted");
        mask(0,0);if(keys!==0)$fatal(1,"SPP all-off failed");
    endtask
    initial begin
        clocks(20);mask(16'h8001,0);if(keys!==16'h8001)$fatal(1,"factory 9600 did not work without AT setup");
        mask(0,0);
        train(2734); // 9600 at 26.25MHz
        intergap=2400;train(2734); // real byte pauses need not fit the bit-period range
        intergap=1500;
        train(684);  // 38400 data configuration, distinct from AT mode
        intergap=500;
        train(228);  // 115200, common modified UART setting
        intergap=6;
        train(2734); // reconnect to a different factory-configured serial module
        mask(1,0);clocks(600010);if(keys!==0)$fatal(1,"framed wireless watchdog failed");
        $display("PASS SPP UART: factory 9600, train/retrain 9600/38400/115200 with byte gaps, framed-only wireless keys, checksum/all-off/watchdog");
        $finish;
    end
    initial begin #80000000;$fatal(1,"SPP profile timeout");end
endmodule
