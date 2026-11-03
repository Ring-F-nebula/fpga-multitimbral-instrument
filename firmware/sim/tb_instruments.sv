`timescale 1ns/1ps
module tb_instruments;
    reg clk=0;always #5 clk=~clk;
    reg [5:0] divider=0;
    always @(posedge clk) divider<=divider+1'b1;
    wire tick=divider==0;
    reg clear=0;
    reg [1:0] instrument=0;
    reg [15:0] keys=0;
    wire signed [15:0] pcm;
    wire [15:0] active,phase;
    wire [7:0] env;
    performance_synth dut(.clk(clk),.sample_tick(tick),.clear(clear),.instrument(instrument),
        .live_keys(keys),.song_gate(1'b0),.song_step(24'd192630),.pluck_mode(1'b0),
        .volume(4'd15),.global_bend(1'b0),.mode_gain(9'd256),.attack_sel(4'd0),.decay_sel(4'd2),
        .release_sel(4'd5),.sustain_level(8'd160),.bend_target(4'd0),.bend_cents(9'sd0),
        .pcm(pcm),.active_envelopes(active),.phase0(phase),.envelope0(env));
    integer file,peak,nonzero;
    task frames(input integer n,input bit save=0);
        repeat(n) begin
            @(negedge tick);repeat(60) @(negedge clk);
            if($isunknown(pcm)) $fatal(1,"unknown PCM");
            if(pcm>32640 || pcm< -32640) $fatal(1,"mix headroom %d",pcm);
            if(pcm!=0) nonzero=nonzero+1;
            if(pcm>peak) peak=pcm;
            if(save) $fwrite(file,"%c%c",pcm[7:0],pcm[15:8]);
        end
    endtask
    task reset_voice(input [1:0] kind);
        @(negedge clk);clear=1;instrument=kind;keys=0;
        repeat(3) @(negedge clk);clear=0;frames(2);peak=0;nonzero=0;
    endtask
    initial begin
        reset_voice(0);file=$fopen("piano.raw","wb");keys=1;frames(24000,1);keys=0;frames(6000,1);$fclose(file);
        if(peak<500 || nonzero<20000 || pcm!=0) $fatal(1,"piano attack/release %d %d",peak,nonzero);
        reset_voice(1);file=$fopen("guitar.raw","wb");keys=1;frames(160,1);keys=0;frames(45413,1);$fclose(file);
        if(peak<500 || nonzero<16000 || pcm!=0 || active!=0) $fatal(1,"guitar pluck decay");
        reset_voice(2);file=$fopen("drums.raw","wb");
        for(integer i=0;i<6;i=i+1) begin
            keys=1<<i;frames(100,1);keys=0;frames(36000,1);
            if(active!=0) $fatal(1,"drum decay pad %d active=%h",i,active);
        end
        $fclose(file);if(peak<500 || nonzero<40000) $fatal(1,"percussion silent");
        for(integer k=0;k<3;k=k+1) begin
            reset_voice(k);keys=16'hffff;frames(16000);keys=0;frames(46000);
            if(pcm!=0 || active!=0) $fatal(1,"chord release kind=%d",k);
        end
        reset_voice(0);keys=16'hffff;frames(100);clear=1;frames(2);
        if(pcm!=0 || active!=0) $fatal(1,"emergency clear");
        $display("PASS instrument audio: piano ADSR, E2 plucked-guitar decay, six percussion pads, 16-voice bounds, clear and release; raw audio exported");$finish;
    end
endmodule
