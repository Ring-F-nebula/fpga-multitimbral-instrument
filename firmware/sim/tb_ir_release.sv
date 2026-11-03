`timescale 1ns/1ps
module tb_ir_release;
    reg clk=0; always #5 clk=~clk;
    reg [5:0] count=0;
    always @(posedge clk) count<=count+1'b1;
    wire tick=(count==0);
    reg gate=0;
    wire signed [15:0] pcm;
    safe_synth dut(.clk(clk),.sample_tick(tick),.clear(1'b0),
        .live_keys(16'b0),.song_gate(gate),.song_step(24'd192630),.pluck_mode(1'b1),
        .square_tone(1'b0),.volume(4'd8),.mode_gain(9'd256),
        .attack_sel(4'd9),.decay_sel(4'd9),.release_sel(4'd0),.sustain_level(8'd0),
        .bend_target(4'b0),.bend_cents(9'sd0),.pcm(pcm),
        .active_envelopes(),.phase0(),.envelope0());
    task frames(input integer n); repeat(n) @(negedge tick); @(negedge clk); endtask
    initial begin
        frames(10); gate=1; frames(365); gate=0; frames(10);
        if(dut.voices[16].envelope<64000) $fatal(1,"IR peak / independent ADSR");
        frames(22786);
        if(dut.voices[16].envelope<32000 || dut.voices[16].envelope>33500)
            $fatal(1,"IR half-second linear decay");
        frames(23000);
        if(pcm!=0 || dut.voices[16].envelope!=0) $fatal(1,"IR release must finish in 1 second");
        $display("PASS IR synthesis: fixed 1ms attack, independent keyboard ADSR, 1000ms release, half-level and zero PCM endpoints");
        $finish;
    end
    initial begin #100000000; $fatal(1,"release timeout"); end
endmodule
