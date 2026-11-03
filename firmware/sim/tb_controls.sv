`timescale 1ns/1ps
module tb_controls;
    reg clk=0; always #5 clk=~clk;
    reg [5:0] c=0; always @(posedge clk)c<=c+1'b1;
    wire tick=(c==0);
    reg b0=1,b1=1;
    wire p0,p1,mode,clear;
    wire [8:0] gain;
    button_press #(.DEBOUNCE_CYCLES(16)) db0(clk,b0,p0);
    button_press #(.DEBOUNCE_CYCLES(16)) db1(clk,b1,p1);
    mode_control modes(clk,tick,p0,p1,mode,clear,gain);
    integer clear_count=0;
    always @(posedge clear) clear_count=clear_count+1;
    always @(posedge clk) if(clear && gain!=0) $fatal(1,"not muted during change");
    reg uart=1;
    wire [15:0] pressed;
    pc_key_receiver rx(clk,uart,pressed);
    task clocks(input integer n); repeat(n) @(negedge clk); endtask
    task frames(input integer n); repeat(n) @(negedge tick); @(negedge clk); endtask
    task send_byte(input [7:0] b);
        @(negedge clk); uart=0; clocks(228);
        for(integer j=0;j<8;j=j+1) begin uart=b[j]; clocks(228); end
        uart=1; clocks(240);
    endtask
    initial begin
        frames(80); if(mode || gain!=256) $fatal(1,"default mode");
        b0=0; clocks(3); b0=1; clocks(30);
        frames(5); if(mode) $fatal(1,"bounce triggered");
        b0=0; frames(220); if(!mode || gain!=256 || clear_count!=1) $fatal(1,"KEY0 mode");
        frames(220); if(clear_count!=1) $fatal(1,"held button repeated");
        b0=1; clocks(30); b0=0; frames(220);
        if(!mode || clear_count!=2) $fatal(1,"KEY0 restart");
        b0=1; clocks(30); b1=0; frames(220);
        if(mode || gain!=256) $fatal(1,"KEY1 mode");
        b1=1; clocks(30); b0=0; b1=0; frames(220);
        if(mode) $fatal(1,"KEY1 priority");
        send_byte(8'h90); send_byte(8'h94); send_byte(8'h97);
        if(pressed!=16'h0091) $fatal(1,"UART chord");
        send_byte(8'h84); if(pressed!=16'h0081) $fatal(1,"UART off");
        send_byte(8'hf4); if(pressed!=16'h0081) $fatal(1,"keepalive");
        send_byte(8'hf0); if(pressed!=0) $fatal(1,"all off");
        send_byte(8'h9f); if(pressed!=16'h8000) $fatal(1,"last note");
        // Exercise real watchdog terminal branch without 26 million idle cycles.
        @(negedge clk); rx.silence_count=26249999; clocks(3);
        if(pressed!=0) $fatal(1,"watchdog");
        $display("PASS debounce, held-key, restart, KEY1 priority, mode mute, UART chords/all-off/watchdog");
        $finish;
    end
    initial begin #100000000; $fatal(1,"timeout"); end
endmodule
