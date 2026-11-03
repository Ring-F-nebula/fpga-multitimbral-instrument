// 16 performance voices x 2 stateful DDS oscillators = 32 manual oscillators,
// plus one unchanged score oscillator. This is 16-note polyphony, NOT 32 notes.
// Each manual voice owns two phase accumulators with different frequency steps.
// Piano/guitar: A uses the original instrument table; B is a detuned sine.
// Drums: A retains the original sine/noise model; B adds a 3:2 sine component.
// A:B = 3:1 before the shared per-note envelope. A shared ROM/multiplier scans
// the voices in 55 clocks after each sample tick (576 clocks on the board).
// Convex oscillator mixing preserves the existing 17-voice headroom bound.
module performance_synth #(
    // B = A + floor(A / 2**shift), about +6.75 cents at the default of 8.
    // Use 1..23 when changing this compile-time tone parameter.
    parameter integer SECOND_DETUNE_SHIFT=8,
    parameter integer USE_NOTE_GAINS=0,
    parameter integer USE_PITCH_FX=0
)(input clk,sample_tick,clear,
    input [1:0] instrument,
    input [15:0] live_keys,input song_gate,input [23:0] song_step,input pluck_mode,
    input [143:0] note_gains,
    input [3:0] volume,input [8:0] mode_gain,input global_bend,
    input [3:0] attack_sel,decay_sel,release_sel,input [7:0] sustain_level,
    input [3:0] bend_target,input signed [8:0] bend_cents,
    input [127:0] fx_params,
    output reg signed [15:0] pcm=0,
    output reg pcm_valid=0,
    output wire audio_active,
    output wire [15:0] active_envelopes,phase0,output wire [7:0] envelope0);
    function [23:0] piano_step;
        input integer n;
        begin case(n)
            0:piano_step=96315;1:piano_step=102042;2:piano_step=108110;3:piano_step=114538;
            4:piano_step=121349;5:piano_step=128565;6:piano_step=136210;7:piano_step=144309;
            8:piano_step=152890;9:piano_step=161982;10:piano_step=171614;11:piano_step=181818;
            12:piano_step=192630;13:piano_step=204084;14:piano_step=216220;15:piano_step=229077;
            default:piano_step=0;
        endcase end
    endfunction
    function [23:0] guitar_step;
        input integer n;
        begin case(n)
            // E2 A2 D3 G3 B3 E4, then the same strings at fret 2.
            0:guitar_step=30337;1:guitar_step=40496;2:guitar_step=54055;
            3:guitar_step=72155;4:guitar_step=90909;5:guitar_step=121349;
            6:guitar_step=34052;7:guitar_step=45455;8:guitar_step=60675;
            9:guitar_step=80991;10:guitar_step=102042;11:guitar_step=136210;
            default:guitar_step=piano_step(n);
        endcase end
    endfunction
    function [15:0] drum_decay;
        input integer n;
        begin case(n%6)
            0:drum_decay=7;1:drum_decay=9;2:drum_decay=23;
            3:drum_decay=3;4:drum_decay=5;default:drum_decay=2;
        endcase end
    endfunction
    wire [16:0] bend_coeff;
    pitch_coeff_rom bend_rom(.cents(bend_cents),.coeff(bend_coeff));
    wire [23:0] glide_steps[0:15];
    reg [15:0] previous_keys=0;
    reg [23:0] vibrato_phase=0;
    wire [15:0] new_keys=live_keys & ~previous_keys;
    wire [15:0] held_keys=live_keys & previous_keys;
    integer k,new_count,held_count;
    reg [3:0] held_index;
    always @* begin
        new_count=0;held_count=0;held_index=0;
        for(k=0;k<16;k=k+1)begin
            if(new_keys[k])new_count=new_count+1;
            if(held_keys[k])begin held_count=held_count+1;held_index=k;end
        end
    end
    wire legato=(new_count==1 && held_count==1);
    wire [23:0] vibrato_rate=(fx_params[95:88]*24'd9424)>>8;
    always @(posedge clk) begin
        if(clear)begin previous_keys<=0;vibrato_phase<=0;end
        else if(sample_tick)begin previous_keys<=live_keys;vibrato_phase<=vibrato_phase+vibrato_rate;end
    end
    wire signed [8:0] vibrato_triangle=vibrato_phase[23]?$signed({1'b0,~vibrato_phase[22:15]})-9'sd128:
        $signed({1'b0,vibrato_phase[22:15]})-9'sd128;
    wire signed [17:0] vib_product=vibrato_triangle*$signed({1'b0,fx_params[103:96]});
    wire signed [9:0] vibrato_cents=fx_params[4]?($signed(vib_product)>>>7):10'sd0;
    wire signed [9:0] remote_cents=($signed({1'b0,fx_params[119:112]})-10'sd100)<<<1;
    wire signed [9:0] selected_cents=fx_params[6]?remote_cents:{{1{bend_cents[8]}},bend_cents};
    wire [3:0] selected_target=fx_params[111:104]==16?bend_target:fx_params[107:104];
    wire [16:0] mod_coeff;
    fx_pitch_coeff modulation_rom(.cents(selected_cents+vibrato_cents),.coeff(mod_coeff));
    wire [23:0] phase_snapshot[0:16];
    wire [23:0] secondary_phase_snapshot[0:16];
    wire [15:0] envelope_snapshot[0:16];
    wire score_active;
    assign audio_active=(|active_envelopes) || score_active;
    wire [8:0] gain_snapshot[0:16];
    reg [16:0] random_bits=17'h1ab73;
    reg signed [7:0] noise=0,previous_noise=0;
    always @(posedge clk) if(sample_tick) begin
        random_bits<={random_bits[15:0],random_bits[16]^random_bits[13]};
        noise<=random_bits[15:8]; previous_noise<=noise;
    end
    genvar v;
    generate for(v=0;v<17;v=v+1) begin: voices
        if(v<16 && USE_NOTE_GAINS) begin: pressure_velocity
            reg [8:0] gain_q=256;
            always @(posedge clk) if(sample_tick)
                gain_q<=note_gains[v*9 +: 9]>256 ? 9'd256 : note_gains[v*9 +: 9];
            assign gain_snapshot[v]=gain_q;
        end else begin: fixed_velocity
            assign gain_snapshot[v]=9'd256;
        end
        reg [23:0] phase=0,phase_q=0;
        reg [15:0] env_q=0,natural=0;
        reg previous_gate=0;
        wire gate;
        wire [15:0] envelope;
        wire [2:0] envelope_state;
        wire [23:0] step;
        wire [15:0] selected_env;
        if(v==16) begin: score_voice
            assign score_active=(selected_env!=0);
            assign gate=song_gate; assign step=song_step;
            assign secondary_phase_snapshot[v]=24'd0;
            assign selected_env=envelope;
            adsr_envelope env(.clk(clk),.tick(sample_tick),.clear(clear),.gate(gate),
                .attack_sel(4'd0),.decay_sel(4'd2),.release_sel(pluck_mode?4'd9:4'd2),
                .sustain_level(8'd255),.level(envelope),.state(envelope_state));
        end else begin: manual_voice
            // Separate storage and feedback: B is not derived from A's phase.
            reg [23:0] phase_b=0,phase_b_q=0;
            wire [23:0] step_b=instrument==2 ? step+(step>>1) :
                step+(step>>SECOND_DETUNE_SHIFT);
            assign secondary_phase_snapshot[v]=phase_b_q;
            reg [16:0] coeff_smooth=65536;
            wire [16:0] target=global_bend ? 17'd73562 :
                (USE_PITCH_FX ? ((selected_target==v)?mod_coeff:17'd65536) :
                ((bend_target==v)?bend_coeff:17'd65536));
            wire [23:0] base_step=instrument==1 ? guitar_step(v):piano_step(v);
            if(USE_PITCH_FX)begin: glide
                note_glide portamento(.clk(clk),.tick(sample_tick),.clear(clear),
                    .enable(fx_params[3] && instrument!=2),.attack(gate&&!previous_gate),
                    .legato(legato),.time_sel(fx_params[83:80]),.base(base_step),
                    .from_step(glide_steps[held_index]),.step(glide_steps[v]));
            end else begin: no_glide
                assign glide_steps[v]=base_step;
            end
            wire [40:0] scaled_step=glide_steps[v]*coeff_smooth+41'd32768;
            reg [23:0] drum_step=0;
            assign gate=live_keys[v];
            assign selected_env=(instrument==0)?envelope:natural;
            assign active_envelopes[v]=(selected_env!=0);
            assign step=instrument==2 ? drum_step:scaled_step[39:16];
            adsr_envelope env(.clk(clk),.tick(sample_tick),.clear(clear),.gate(gate),
                .attack_sel(attack_sel),.decay_sel(decay_sel),.release_sel(release_sel),
                .sustain_level(sustain_level),.level(envelope),.state(envelope_state));
            always @(posedge clk) begin
                if(clear) begin phase_b<=0; phase_b_q<=0; end
                else if(sample_tick) begin
                    phase_b_q<=phase_b;
                    // Quarter-cycle start keeps the two oscillators distinct
                    // even during the first samples of a newly triggered note.
                    if(gate && !previous_gate) phase_b<=24'h400000;
                    else if(gate || selected_env!=0) phase_b<=phase_b+step_b;
                    else phase_b<=0;
                end
            end
            always @(posedge clk) begin
                if(clear) begin coeff_smooth<=65536; drum_step<=0; end
                else if(sample_tick) begin
                    if(target>coeff_smooth) coeff_smooth<=target-coeff_smooth>32?coeff_smooth+17'd32:target;
                    else if(target<coeff_smooth) coeff_smooth<=coeff_smooth-target>32?coeff_smooth-17'd32:target;
                    if(gate && !previous_gate) begin
                        case(v%6)
                            0:drum_step<=24'd51540; // kick: 140 -> 49 Hz pitch drop
                            1:drum_step<=24'd66250;
                            2,3:drum_step<=24'd3000000;
                            4:drum_step<=24'd80991;
                            default:drum_step<=24'd1900000;
                        endcase
                    end else if(v%6==0 && drum_step>18000) drum_step<=drum_step-24'd12;
                    else if(v%6==4 && drum_step>50000) drum_step<=drum_step-24'd4;
                end
            end
        end
        assign phase_snapshot[v]=phase_q;
        assign envelope_snapshot[v]=env_q;
        always @(posedge clk) begin
            if(clear) begin phase<=0; phase_q<=0; env_q<=0; natural<=0; previous_gate<=0; end
            else if(sample_tick) begin
                previous_gate<=gate;
                phase_q<=phase; env_q<=selected_env;
                if(gate && !previous_gate) begin natural<=65535; phase<=0; end
                else begin
                    if(instrument==1) begin
                        if(natural>0) natural<=natural-((natural>>14)+16'd1);
                    end else if(instrument==2) begin
                        if(natural>drum_decay(v)) natural<=natural-drum_decay(v); else natural<=0;
                    end
                    if(gate || selected_env!=0) phase<=phase+step; else phase<=0;
                end
            end
        end
    end endgenerate
    assign phase0=voices[0].phase[23:8];
    assign envelope0=voices[0].selected_env[15:8];
    reg [4:0] index=0;
    reg [3:0] state=0;
    reg signed [28:0] mix=0;
    reg signed [24:0] product=0;
    reg signed [34:0] velocity_product=0;
    reg [8:0] volume_smooth=128;
    wire [8:0] volume_target={1'b0,volume,4'b0000};
    wire [8:0] bounded_gain=mode_gain>256?9'd256:mode_gain;
    wire secondary_lookup=(state==2 && index<16);
    wire [1:0] wave_kind=secondary_lookup?2'd0:
        (index==16?2'd1:(instrument==2?2'd0:(instrument==1?2'd2:2'd1)));
    wire [7:0] lookup_phase=secondary_lookup ? secondary_phase_snapshot[index][23:16] :
        phase_snapshot[index][23:16];
    wire signed [7:0] tonal;
    instrument_wave_table table_rom(.phase(lookup_phase),.kind(wave_kind),.value(tonal));
    reg signed [8:0] primary_wave=0;
    wire signed [10:0] primary_extended={{2{primary_wave[8]}},primary_wave};
    wire signed [10:0] secondary_extended={{3{tonal[7]}},tonal};
    wire signed [10:0] pair_sum=(primary_extended<<<2)-primary_extended+secondary_extended;
    wire signed [10:0] pair_average=pair_sum>>>2;
    wire signed [8:0] voice_wave=index==16 ? primary_wave : pair_average[8:0];
    reg signed [8:0] wave;
    wire signed [8:0] noise_difference=($signed({noise[7],noise})-$signed({previous_noise[7],previous_noise}))>>>1;
    always @* begin
        wave=$signed({tonal[7],tonal});
        if(instrument==2 && index<16) case(index%6)
            1:wave=($signed({noise[7],noise})>>>1)+($signed({tonal[7],tonal})>>>2);
            2,3:wave=noise_difference;
            5:wave=$signed({noise[7],noise})>>>1;
            default:wave=$signed({tonal[7],tonal});
        endcase
        if(wave>127) wave=127; else if(wave< -128) wave=-128;
    end
    reg signed [17:0] scaled=0;
    reg signed [27:0] volume_product=0,gain_product=0;
    wire signed [17:0] volume_pcm=volume_product[25:8];
    always @(posedge clk) begin
        pcm_valid<=0;
        if(clear) begin state<=0; pcm<=0; mix<=0; index<=0; product<=0; velocity_product<=0;
            primary_wave<=0; volume_smooth<=volume_target; scaled<=0; volume_product<=0; gain_product<=0; end
        else case(state)
            0: if(sample_tick) begin
                index<=0; mix<=0; state<=1;
                if(volume_smooth<volume_target) volume_smooth<=volume_smooth+1'b1;
                else if(volume_smooth>volume_target) volume_smooth<=volume_smooth-1'b1;
            end
            1: begin primary_wave<=wave; state<=2; end
            2: begin product<=voice_wave*$signed({1'b0,envelope_snapshot[index]}); state<=3; end
            3: begin
                if(USE_NOTE_GAINS) begin
                    velocity_product<=product*$signed({1'b0,gain_snapshot[index]}); state<=8;
                end else begin
                    mix<=mix+{{4{product[24]}},product};
                    if(index==16) state<=4; else begin index<=index+1'b1; state<=1; end
                end
            end
            8: begin
                mix<=mix+($signed(velocity_product)>>>8);
                if(index==16) state<=4; else begin index<=index+1'b1; state<=1; end
            end
            4: begin scaled<=mix>>>12; state<=5; end
            5: begin volume_product<=scaled*$signed({1'b0,volume_smooth}); state<=6; end
            6: begin gain_product<=volume_pcm*$signed({1'b0,bounded_gain}); state<=7; end
            7: begin pcm<=gain_product[23:8]; pcm_valid<=1; state<=0; end
            default:state<=0;
        endcase
    end
endmodule
