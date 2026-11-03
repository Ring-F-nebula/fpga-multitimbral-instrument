`timescale 1ns/1ps
module tb_ec11;
    reg clk=0; always #5 clk=~clk;
    reg a=1,b=1,clear=0,reset_bend=0;
    reg [15:0] keys=0;
    wire cw,ccw;
    wire [3:0] target;
    wire signed [8:0] cents;
    ec11_decoder #(.FILTER_CYCLES(4)) decoder(clk,a,b,cw,ccw);
    single_note_bend bend(clk,clear,keys,cw,ccw,reset_bend,target,cents);
    integer forward=0,backward=0;
    always @(posedge clk) begin if(cw) forward=forward+1; if(ccw) backward=backward+1; end
    task clocks(input integer n); repeat(n) @(negedge clk); endtask
    task ab(input [1:0] value); {a,b}=value; clocks(12); endtask
    task right; ab(2'b10); ab(0); ab(1); ab(3); endtask
    task left; ab(1); ab(0); ab(2); ab(3); endtask
    initial begin
        clocks(20); right(); if(cents!=0 || forward!=1) $fatal(1,"idle bend");
        keys=1; clocks(3); right(); if(target!=0 || cents!=10) $fatal(1,"C4 bend");
        // Both filtered bounce and complete reversal must not make a detent.
        a=0; clocks(1); a=1; clocks(12);
        ab(2); ab(3); if(cents!=10) $fatal(1,"bounce");
        left(); if(cents!=0 || backward!=1) $fatal(1,"reverse");
        keys=16'h11; clocks(3); right();
        if(target!=4 || cents!=10) $fatal(1,"last note selection");
        repeat(30) right(); if(cents!=200) $fatal(1,"positive clamp");
        repeat(60) left(); if(cents!=-200) $fatal(1,"negative clamp");
        reset_bend=1; clocks(2); reset_bend=0; if(cents!=0) $fatal(1,"push reset");
        ab(0); ab(3); if(cents!=0) $fatal(1,"illegal two-bit jump");
        right(); if(cents!=10) $fatal(1,"illegal jump recovery");
        keys=1; clocks(3); right(); if(cents!=10) $fatal(1,"released target must ignore knob");
        keys=16'h8003; clocks(3);
        if(target!=15 || cents!=0) $fatal(1,"simultaneous onsets priority");
        clear=1; clocks(2); if(target!=0 || cents!=0) $fatal(1,"mode clear");
        $display("PASS EC11 forward/reverse, filtered bounce, partial reversal, invalid jumps, target selection, clamps and reset");
        $finish;
    end
    initial begin #10000000; $fatal(1,"timeout"); end
endmodule
