`timescale 1ns/1ps
module tb_dac;
    reg clk=0; always #5 clk=~clk;
    reg signed [15:0] pcm=16'h5239;
    wire bck,ws,din,tick;
    pt8211_tx dut(clk,pcm,bck,ws,din,tick);
    integer slot=0,frames=0,cycles=0,last_cycle=0;
    reg [15:0] shift=0,expected=0;
    reg start=0;
    always @(posedge clk) begin
        cycles=cycles+1;
        if(tick) begin
            if(start && cycles-last_cycle!=576) $fatal(1,"frame interval");
            last_cycle=cycles; expected=pcm; start=1; slot=0;
        end
    end
    always @(posedge bck) if(start) begin
        if(ws!==(slot>=16)) $fatal(1,"WS alignment slot %0d",slot);
        shift={shift[14:0],din};
        if(slot==15 || slot==31) begin
            if(shift!==expected) $fatal(1,"PT8211 got %h expected %h",shift,expected);
        end
        if(slot==31) begin
            frames=frames+1; pcm=pcm+16'h3741;
            if(frames==100) begin $display("PASS PT8211 100 stereo frames, 16-bit LSBJ, signed samples, frame interval 576"); $finish; end
        end
        slot=slot+1;
    end
    initial begin #10000000; $fatal(1,"timeout"); end
endmodule
