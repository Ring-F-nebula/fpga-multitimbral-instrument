`timescale 1ns/1ps
module tb_fsr_volume;
    reg clk=0; always #5 clk=~clk;
    reg [3:0] divider=0; always @(posedge clk) divider<=divider+1'b1;
    wire tick=divider==0;
    reg reset_n=0,toggle=0,online=0;
    reg [13:0] peak=0;
    reg signed [15:0] pcm_in=20000;
    wire signed [15:0] pcm_out;
    wire [8:0] gain;
    wire [13:0] pressure;
    fsr_volume dut(.clk(clk),.reset_n(reset_n),.sample_tick(tick),
        .peak_async(peak),.frame_toggle_async(toggle),.online_async(online),
        .pcm_in(pcm_in),.pcm_out(pcm_out),.gain(gain),.pressure(pressure));
    integer previous_gain=0,current_gain;
    always @(negedge clk) if(reset_n) begin
        current_gain=gain;
        if(current_gain>256 || current_gain>previous_gain+1 || current_gain<previous_gain-1)
            $fatal(1,"gain bounds/slew");
        previous_gain=gain;
    end
    task frames(input integer n); repeat(n) @(negedge tick); repeat(4) @(negedge clk); endtask
    task publish(input [13:0] value);
        @(negedge clk); peak=value; toggle=~toggle;
    endtask
    initial begin
        repeat(4) @(negedge clk); reset_n=1; frames(10);
        if(gain!=0 || pcm_out!=0) $fatal(1,"unconnected input must mute");
        online=1; publish(32); frames(30);
        if(gain!=0 || pcm_out!=0) $fatal(1,"zero dead zone");
        publish(544); frames(150);
        if(pressure!=544 || gain!=128 || pcm_out!=10000) $fatal(1,"half pressure gain");
        pcm_in=-20001; frames(2);
        if(pcm_out!=-10001) $fatal(1,"signed PCM rounding");
        publish(1056); frames(150);
        if(gain!=256 || pcm_out!=-20001) $fatal(1,"full pressure unity");
        pcm_in=-32768; publish(16383); frames(10);
        if(gain!=256 || pcm_out!=-32768) $fatal(1,"upper clamp/signed minimum");
        pcm_in=32767; frames(2);
        if(pcm_out!=32767) $fatal(1,"signed maximum");
        online=0; frames(270);
        if(gain!=0 || pcm_out!=0) $fatal(1,"ADC fault must fade to mute");
        online=1; frames(270);
        if(gain!=0 || pcm_out!=0) $fatal(1,"stale pressure resurrected without new frame");
        publish(1056); frames(270);
        if(gain!=256) $fatal(1,"new frame recovery");
        publish(0); frames(270);
        if(gain!=0 || pcm_out!=0) $fatal(1,"release to zero");
        $display("PASS FSR volume: CDC frame capture, dead zone, half/full gain, signed PCM extrema/rounding, 1-step slew, upper clamp, release, fault mute, fresh-frame recovery");
        $finish;
    end
    initial begin #1000000; $fatal(1,"volume timeout"); end
endmodule
