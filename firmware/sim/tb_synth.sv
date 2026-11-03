`timescale 1ns/1ps
// Mix/oscillator oracle uses integer arithmetic, not DUT mix/products/steps.
// Per-voice ADSR levels feed this isolated mixer oracle; tb_adsr independently
// checks the envelope time/shape against a real-valued linear reference.
module tb_synth;
    reg clk=0; always #5 clk=~clk;
    reg [5:0] count=0;
    always @(posedge clk) count<=count+1'b1;
    wire tick=(count==0);
    reg clear=0,square=0,sg=0,worst_case=0;
    reg [15:0] keys=0;
    reg [23:0] ss=181818;
    reg [3:0] volume=15,a=0,d=0,r=0,target=0;
    reg [7:0] sustain=160;
    reg signed [8:0] cents=0;
    reg [8:0] gain=256;
    wire signed [15:0] pcm;
    wire [15:0] active;
    wire [15:0] phase0;
    wire [7:0] envelope0;
    safe_synth dut(.clk(clk),.sample_tick(tick),.clear(clear),
        .live_keys(keys),.song_gate(sg),.song_step(ss),.pluck_mode(1'b0),
        .square_tone(square),.volume(volume),.mode_gain(gain),
        .attack_sel(a),.decay_sel(d),.release_sel(r),.sustain_level(sustain),
        .bend_target(target),.bend_cents(cents),
        .pcm(pcm),.active_envelopes(active),.phase0(phase0),.envelope0(envelope0));
    wire [15:0] levels[0:16];
    wire [23:0] actual_phases[0:16];
    wire [16:0] actual_coeffs[0:15];
    genvar g;
    generate for(g=0;g<17;g=g+1) begin: observe
        assign levels[g]=dut.voices[g].envelope;
        assign actual_phases[g]=dut.voices[g].phase;
        if(g<16) assign actual_coeffs[g]=dut.voices[g].manual_voice.coeff_smooth;
        // Adversarial full-scale coincident negative peaks, independent of
        // whether different musical frequencies naturally align in this run.
        always @(worst_case) begin
            if(worst_case) begin
                force dut.voices[g].phase=24'd0;
                force dut.voices[g].envelope=16'hffff;
            end else begin
                release dut.voices[g].phase;
                release dut.voices[g].envelope;
            end
        end
    end endgenerate
    integer phases[0:16],coeffs[0:15],steps[0:15];
    integer vol=128,expected=0,triangle_ref,clamped,goal,step_ref;
    integer checked=0,peak=0,p,base0,held_envelope,csv;
    longint signed mix_ref,weighted,scaled;
    initial begin
        csv=$fopen("synth_samples.csv","w");
        $fwrite(csv,"sample,mask,pcm,expected\n");
        for(integer i=0;i<17;i=i+1) phases[i]=0;
        for(integer i=0;i<16;i=i+1) begin
            coeffs[i]=65536;
            steps[i]=$rtoi(440.0*(2.0**((60.0+i-69.0)/12.0))*16777216.0/(26250000.0/576.0)+0.5);
        end
    end
    always @(posedge clk) begin
        if(clear) begin
            for(integer j=0;j<17;j=j+1) phases[j]=0;
            for(integer j=0;j<16;j=j+1) coeffs[j]=65536;
            vol=volume*16;expected=0;
        end else if(tick) begin
            if(dut.state!=0) $fatal(1,"sample missed: synth busy");
            if(vol<volume*16) vol=vol+1; else if(vol>volume*16) vol=vol-1;
            clamped=cents;if(clamped>200)clamped=200;if(clamped< -200)clamped=-200;
            mix_ref=0;
            for(integer j=0;j<17;j=j+1) begin
                if(!worst_case && actual_phases[j]!==phases[j])
                    $fatal(1,"phase continuity voice %0d got %0d expected %0d",j,actual_phases[j],phases[j]);
                triangle_ref=((worst_case?0:phases[j])>>15)&255;
                if(!worst_case && (phases[j]&24'h800000)) triangle_ref=255-triangle_ref;
                triangle_ref=triangle_ref-128;
                weighted=triangle_ref; weighted=weighted*levels[j];
                mix_ref=mix_ref+weighted;
                if(j<16) begin
                    if(actual_coeffs[j]!==coeffs[j]) $fatal(1,"coefficient isolation/slew voice %0d",j);
                    weighted=steps[j];weighted=weighted*coeffs[j];
                    step_ref=(weighted+32768)>>16;
                    goal=(j==target)?$rtoi(65536.0*(2.0**(clamped/1200.0))+0.5):65536;
                    if(goal>coeffs[j]) coeffs[j]=((goal-coeffs[j])>32)?coeffs[j]+32:goal;
                    else if(goal<coeffs[j]) coeffs[j]=((coeffs[j]-goal)>32)?coeffs[j]-32:goal;
                end else step_ref=ss;
                if((j==16?sg:keys[j]) || levels[j]!=0)
                    phases[j]=(phases[j]+step_ref)&24'hffffff;
                else phases[j]=0;
            end
            scaled=mix_ref>>>12;
            scaled=(scaled*vol)>>>8;
            expected=(scaled*(gain>256?256:gain))>>>8;
        end
        if(!clear && dut.state==5) begin
            #1;
            if(pcm!==expected) $fatal(1,"PCM mismatch sample=%0d got=%0d expected=%0d",checked,pcm,expected);
            if(pcm>32640 || pcm< -32640) $fatal(1,"headroom violated %0d",pcm);
            if((pcm<0?-pcm:pcm)>peak) peak=(pcm<0?-pcm:pcm);
            $fwrite(csv,"%0d,%0d,%0d,%0d\n",checked,keys,pcm,expected);
            checked=checked+1;
        end
    end
    task frames(input integer n);
        repeat(n) begin
            @(posedge clk);while(!tick)@(posedge clk);#1;
            wait(dut.state==0);@(negedge clk);
        end
    endtask
    task reset;
        clear=1;frames(2);clear=0;keys=0;sg=0;frames(2);
    endtask
    initial begin
        @(negedge clk);reset();
        for(integer n=0;n<16;n=n+1) begin
            keys=16'h0001<<n;frames(180);
            if(active!==keys) $fatal(1,"voice activity %0d",n);
            p=0;
            repeat(400) begin frames(1);if((pcm<0?-pcm:pcm)>p)p=(pcm<0?-pcm:pcm);end
            if(p<1000) $fatal(1,"voice %0d silent peak=%0d",n,p);
            keys=0;frames(70);if(active!=0 || pcm!=0)$fatal(1,"voice release %0d",n);
        end
        keys=16'hffff;sg=1;frames(350);
        // Other 15 voices must stay nominal while voice 0 is bent.
        target=0;cents=200;frames(400);
        if(actual_coeffs[0]!=73562) $fatal(1,"+200 cents endpoint");
        if(envelope0!=sustain) $fatal(1,"bend retriggered envelope");
        for(integer n=1;n<16;n=n+1)
            if(actual_coeffs[n]!=65536)$fatal(1,"other voice bent");
        cents=-200;frames(600);
        if(actual_coeffs[0]!=58386)$fatal(1,"-200 cents endpoint got %0d",actual_coeffs[0]);
        // Clamp out-of-range controls and smoothly return old target to center.
        cents=255;target=7;frames(600);
        if(actual_coeffs[0]!=65536 || actual_coeffs[7]!=73562)$fatal(1,"retarget/clamp");
        cents=-256;frames(600);if(actual_coeffs[7]!=58386)$fatal(1,"negative clamp");
        cents=0;frames(400);
        // Fixed gain must preserve a sustain-level change for the whole chord.
        sustain=64;frames(100);if(envelope0!=64)$fatal(1,"S update");
        sustain=255;frames(100);if(envelope0!=255)$fatal(1,"full S");
        volume=0;frames(300);if(pcm!=0)$fatal(1,"volume zero failed");
        volume=15;frames(300);gain=0;frames(2);if(pcm!=0)$fatal(1,"gain zero failed");
        gain=511;frames(10); // Defensive clamp, never wrap under invalid gain.
        worst_case=1;frames(300);
        if(pcm!= -32640)$fatal(1,"adversarial 17 voice bound got %0d",pcm);
        clear=1;worst_case=0;frames(2);clear=0;keys=0;sg=0;gain=256;frames(5);
        if(pcm!=0 || active!=0)$fatal(1,"clear failed");
        // Each gate in a chord owns its envelope and can release independently.
        keys=16'hffff;frames(200);keys=16'hfffe;frames(60);
        if(active!=16'hfffe)$fatal(1,"independent release");
        r=9;keys=0;sg=1;frames(300);sg=0;frames(260);
        if(levels[16]!=0)$fatal(1,"automatic short release must ignore user long R");
        if(active==0)$fatal(1,"manual long release was not retained");
        reset();volume=0;clear=1;frames(2);clear=0;sg=1;frames(300);
        if(pcm!=0)$fatal(1,"muted clear/mode transition leaked sound");
        sg=0;frames(260);if(pcm!=0)$fatal(1,"muted automatic tail leaked sound");
        $display("PASS synth samples=%0d peak=%0d exact independent PCM oracle; all 16 voices, 17-voice bound, pitch isolation/continuity/slew/clamp, independent ADSR, clear",checked,peak);
        $fclose(csv);$finish;
    end
    // Entire signed 9-bit input space, independent analytic LUT oracle.
    reg signed [8:0] rom_input=0;
    wire [16:0] rom_output;
    pitch_coeff_rom rom_test(rom_input,rom_output);
    initial begin : rom_check
        integer limit,reference_value;
        for(integer v=-256;v<=255;v=v+1) begin
            rom_input=v;#2;limit=v;if(limit>200)limit=200;if(limit< -200)limit=-200;
            reference_value=$rtoi(65536.0*(2.0**(limit/1200.0))+0.5);
            if(rom_output!==reference_value)$fatal(1,"pitch ROM mismatch cents %0d",v);
        end
        $display("PASS pitch ROM all 512 signed controls and clamps");
    end
    initial begin #100000000;$fatal(1,"timeout");end
endmodule
