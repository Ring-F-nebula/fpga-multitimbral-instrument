`timescale 1ns/1ps
// Contract tests for the ACTIVE performance_synth, not the legacy safe_synth.
// Golden PCM is computed with wide integer arithmetic outside the DUT pipeline.
module tb_oscillators32;
    reg clk=0;
    always #5 clk=~clk;
    reg [5:0] divider=0;
    always @(posedge clk) divider<=divider+1'b1;
    wire tick=divider==0; // 64 clocks: tighter than the board's 576 clocks.
    reg clear=1;
    reg [1:0] instrument=0;
    reg [15:0] keys=0;
    reg song_gate=0;
    reg [23:0] song_step=192630;
    reg [3:0] volume=15;
    reg [8:0] gain=256;
    reg bend=0;
    wire signed [15:0] pcm;
    wire [15:0] active,phase0;
    wire [7:0] envelope0;
    performance_synth dut(.clk(clk),.sample_tick(tick),.clear(clear),.instrument(instrument),
        .live_keys(keys),.song_gate(song_gate),.song_step(song_step),.pluck_mode(1'b0),
        .volume(volume),.mode_gain(gain),.global_bend(bend),
        .attack_sel(4'd0),.decay_sel(4'd0),.release_sel(4'd0),.sustain_level(8'd255),
        .bend_target(4'd0),.bend_cents(9'sd0),.pcm(pcm),
        .active_envelopes(active),.phase0(phase0),.envelope0(envelope0));

    reg [15:0] moved_a=0,moved_b=0;
    reg check_feedback=1;
    wire [23:0] phase_a[0:15],phase_b[0:15];
    genvar v;
    generate for(v=0;v<16;v=v+1) begin: observe
        assign phase_a[v]=dut.voices[v].phase;
        assign phase_b[v]=dut.voices[v].manual_voice.phase_b;
        reg [23:0] old_a,old_b,expected_a,expected_b;
        always @(posedge clk) if(tick && !clear && check_feedback) begin
            old_a=phase_a[v]; old_b=phase_b[v];
            if(keys[v] && !dut.voices[v].previous_gate) begin
                expected_a=0; expected_b=24'h400000;
            end else if(keys[v] || dut.voices[v].selected_env!=0) begin
                expected_a=old_a+dut.voices[v].step;
                expected_b=old_b+dut.voices[v].manual_voice.step_b;
            end else begin expected_a=0; expected_b=0; end
            #1;
            if(phase_a[v]!==expected_a || phase_b[v]!==expected_b)
                $fatal(1,"phase feedback channel %0d A=%h/%h B=%h/%h",v,
                    phase_a[v],expected_a,phase_b[v],expected_b);
            if(phase_a[v]!=old_a) moved_a[v]=1;
            if(phase_b[v]!=old_b) moved_b[v]=1;
        end
    end endgenerate

    // One pair of reference table ports, independent of the DUT's shared port.
    reg [7:0] ref_phase_a=0,ref_phase_b=0;
    reg [1:0] ref_kind=0;
    wire signed [7:0] ref_a,ref_b;
    instrument_wave_table golden_a(.phase(ref_phase_a),.kind(ref_kind),.value(ref_a));
    instrument_wave_table golden_b(.phase(ref_phase_b),.kind(2'd0),.value(ref_b));
    integer checked=0,nonzero=0,max_cycles=0;
    integer clock_count=0,started_at=0;
    reg was_busy=0;
    always @(posedge clk) begin
        clock_count=clock_count+1;
        if(!clear && tick && dut.state!=0) $fatal(1,"sample deadline missed");
        #2;
        if(clear) was_busy=0;
        else begin
            if(!was_busy && dut.state!=0) started_at=clock_count;
            if(was_busy && dut.state==0 && clock_count-started_at>max_cycles)
                max_cycles=clock_count-started_at;
            was_busy=(dut.state!=0);
        end
    end

    task frames(input integer n);
        longint signed total,w,secondary,blended,result,bounded_gain;
        integer a_noise,b_noise;
        repeat(n) begin
            @(negedge tick); #1;
            total=0;
            a_noise=$signed(dut.noise); b_noise=$signed(dut.previous_noise);
            for(integer k=0;k<17;k=k+1) begin
                ref_phase_a=dut.phase_snapshot[k][23:16];
                ref_phase_b=dut.secondary_phase_snapshot[k][23:16];
                ref_kind=k==16 ? 1 : (instrument==2 ? 0 : (instrument==1 ? 2 : 1));
                #1;
                w=$signed(ref_a); secondary=$signed(ref_b);
                if(instrument==2 && k<16) case(k%6)
                    1:w=(a_noise>>>1)+(w>>>2);
                    2,3:w=(a_noise-b_noise)>>>1;
                    5:w=a_noise>>>1;
                    default:begin end
                endcase
                if(w>127) w=127; else if(w< -128) w=-128;
                blended=k==16 ? w : (3*w+secondary)>>>2;
                total=total+blended*longint'(dut.envelope_snapshot[k]);
            end
            result=total>>>12;
            result=(result*longint'(dut.volume_smooth))>>>8;
            bounded_gain=gain>256 ? 256 : gain;
            result=(result*bounded_gain)>>>8;
            repeat(58) @(negedge clk); #1;
            if(dut.state!==0) $fatal(1,"mix unfinished before next tick");
            if($isunknown(pcm) || $signed(pcm)!=result)
                $fatal(1,"PCM scoreboard kind=%0d got=%0d expected=%0d",instrument,pcm,result);
            if(pcm>32640 || pcm< -32640) $fatal(1,"17-voice mix headroom");
            checked=checked+1;
            if(pcm!=0) nonzero=nonzero+1;
        end
    endtask
    task reset_kind(input [1:0] kind);
        @(negedge clk); clear=1; keys=0; song_gate=0; instrument=kind; bend=0;
        volume=15; gain=256;
        repeat(3) @(negedge clk);
        clear=0; frames(2);
    endtask

    integer b_peak,b_trough;
    initial begin
        for(integer kind=0;kind<3;kind=kind+1) begin
            reset_kind(kind);
            keys=16'hffff; song_gate=1; frames(400);
            if(active!==16'hffff || moved_a!==16'hffff || moved_b!==16'hffff)
                $fatal(1,"not all 32 manual oscillators active");
            for(integer k=0;k<16;k=k+1)
                if(phase_a[k]==phase_b[k]) $fatal(1,"oscillator phase alias channel %0d",k);
            keys=16'hfffe; frames(60);
            if(kind==0 && active!==16'hfffe) $fatal(1,"independent note release");
            bend=1; frames(350); bend=0; frames(350);
            gain=511; frames(16); // Mode gain must clamp, not wrap.
            gain=128; volume=6; frames(160);
            // Musical guitar/drum decay deliberately outlasts key release;
            // their full natural tails are covered by tb_instruments.
            keys=0; song_gate=0;
            if(kind==0) begin
                frames(300); if(pcm!=0 || active!=0) $fatal(1,"piano/score release");
            end
            @(negedge clk); clear=1; repeat(2) @(negedge clk);
            if(pcm!=0 || active!=0) $fatal(1,"emergency clear");
            for(integer k=0;k<16;k=k+1)
                if(phase_a[k]!=0 || phase_b[k]!=0) $fatal(1,"clear both phases");
        end
        // Establish that B affects audible PCM independently of A: freeze the
        // same A at a zero crossing, vary only B, and compare output polarity.
        reset_kind(0); keys=1; frames(120); check_feedback=0;
        force dut.voices[0].phase=24'd0;
        force dut.voices[0].manual_voice.phase_b=24'h400000;
        frames(3); b_peak=$signed(pcm);
        force dut.voices[0].manual_voice.phase_b=24'hc00000;
        frames(3); b_trough=$signed(pcm);
        if(b_peak<100 || b_trough> -100) $fatal(1,"secondary oscillator disconnected");
        if(dut.voices[0].phase!==0) $fatal(1,"B altered A phase");
        release dut.voices[0].phase;
        release dut.voices[0].manual_voice.phase_b;
        if(nonzero<2000 || max_cycles!=55) $fatal(1,"coverage/deadline %0d %0d",nonzero,max_cycles);
        $display("PASS 32 manual DDS oscillators + score: all phase feedback, golden PCM (%0d frames), three instruments, 17-voice headroom, independent note release, bend, gain clamp, clear, B-only audible contribution; %0d/64 clocks",checked,max_cycles);
        $finish;
    end
    initial begin #10000000; $fatal(1,"32-oscillator test timeout"); end
endmodule
