// 16 independent manual oscillators + a score oscillator; no CPU or PCM ROM.
// Keep v3's generate-local phase/envelope state (no indexed state writeback).
// Fixed mix gain preserves ADSR level changes even for large chords:
// 17 * 128 * 65535 / 4096 * (240/256) <= 32640 counts at unity mode gain.
// Mode gain clamps at 256. No dynamic envelope-sum normalization or divider.
module safe_synth(input clk,input sample_tick,input clear,
    input [15:0] live_keys,input song_gate,input [23:0] song_step,input pluck_mode,
    input square_tone,input [3:0] volume,input [8:0] mode_gain,
    input [3:0] attack_sel,decay_sel,release_sel,
    input [7:0] sustain_level,
    input [3:0] bend_target,input signed [8:0] bend_cents,
    output reg signed [15:0] pcm=0,
    output wire [15:0] active_envelopes,phase0,
    output wire [7:0] envelope0);
    reg [8:0] volume_smooth=128;
    wire [8:0] volume_target={1'b0,volume,4'b0000};
    wire [8:0] bounded_gain=(mode_gain>9'd256)?9'd256:mode_gain;
    reg [2:0] state=0;
    reg [4:0] index=0;
    reg signed [28:0] mix=0;
    wire tick=sample_tick && state==0;
    wire [16:0] bend_coeff;
    pitch_coeff_rom bend_table(.cents(bend_cents),.coeff(bend_coeff));

    function [23:0] note_step;
        input [4:0] n;
        begin case(n)
             0:note_step=96315;  1:note_step=102042;
             2:note_step=108110; 3:note_step=114538;
             4:note_step=121349; 5:note_step=128565;
             6:note_step=136210; 7:note_step=144309;
             8:note_step=152890; 9:note_step=161982;
            10:note_step=171614;11:note_step=181818;
            12:note_step=192630;13:note_step=204084;
            14:note_step=216220;15:note_step=229077;
            default:note_step=0;
        endcase end
    endfunction
    wire signed [25:0] voice_product[0:16];
    genvar v;
    generate for(v=0;v<17;v=v+1) begin: voices
        reg [23:0] phase=0;
        wire [15:0] envelope;
        wire [2:0] envelope_state;
        reg signed [25:0] product_snapshot=0;
        wire gate;
        wire [23:0] step;
        if(v==16) begin: score_voice
            assign gate=song_gate;
            assign step=song_step;
            // Existing song gates end only 14 ms before the next note.
            // 1 ms A, 5 ms D, full sustain, 5 ms R finish safely before it.
            // User ADSR controls apply to manual voices, not this legacy score.
            // In manual mode this otherwise unused score voice is the IR C5
            // pluck: 8 ms gate followed by a fixed 1000 ms linear release.
            // It stays independent of the keyboard's ADSR and does not add
            // another voice to the proven 17-voice mix headroom bound.
            adsr_envelope env(.clk(clk),.tick(tick),.clear(clear),.gate(gate),
                .attack_sel(4'd0),.decay_sel(4'd2),.release_sel(pluck_mode ? 4'd9 : 4'd2),
                .sustain_level(8'd255),.level(envelope),.state(envelope_state));
        end else begin: manual_voice
            reg [16:0] coeff_smooth=17'd65536;
            wire [16:0] target=(bend_target==v)?bend_coeff:17'd65536;
            wire [40:0] scaled_step=note_step(v)*coeff_smooth;
            wire [40:0] rounded_step=scaled_step+41'd32768;
            assign gate=live_keys[v];
            assign step=rounded_step[39:16];
            assign active_envelopes[v]=(envelope!=0);
            adsr_envelope env(.clk(clk),.tick(tick),.clear(clear),.gate(gate),
                .attack_sel(attack_sel),.decay_sel(decay_sel),
                .release_sel(release_sel),.sustain_level(sustain_level),
                .level(envelope),.state(envelope_state));
            // At most ~0.95 cents/sample, <=5.6 ms center-to-endpoint.
            // Retargeting lets the former target glide back to nominal pitch.
            always @(posedge clk) begin
                if(clear) coeff_smooth<=17'd65536;
                else if(tick) begin
                    if(target>coeff_smooth)
                        coeff_smooth<=target-coeff_smooth>17'd32 ? coeff_smooth+17'd32:target;
                    else if(target<coeff_smooth)
                        coeff_smooth<=coeff_smooth-target>17'd32 ? coeff_smooth-17'd32:target;
                end
            end
        end
        wire signed [8:0] triangle=phase[23] ?
            $signed({1'b0,~phase[22:15]})-9'sd128 :
            $signed({1'b0,phase[22:15]})-9'sd128;
        assign voice_product[v]=product_snapshot;
        always @(posedge clk) begin
            if(clear) begin phase<=0; product_snapshot<=0; end
            else if(tick) begin
                product_snapshot<=triangle*$signed({1'b0,envelope});
                if(gate || envelope!=0) phase<=phase+step;
                else phase<=0;
            end
        end
    end endgenerate
    // square_tone remains reserved, as in the v3 triangle-only baseline.
    assign phase0=voices[0].phase[23:8];
    assign envelope0=voices[0].envelope[15:8];
    wire signed [25:0] product=voice_product[index];
    reg signed [17:0] scaled_mix=0;
    reg signed [27:0] volume_product=0;
    reg signed [27:0] gain_product=0;
    // Dropped upper bits are sign extension under the fixed 17-voice bound.
    // Explicit slices retain arithmetic-shift rounding without width warnings.
    wire signed [17:0] volume_pcm=volume_product[25:8];
    always @(posedge clk) begin
        if(clear) begin
            state<=0; pcm<=0; mix<=0; index<=0; scaled_mix<=0;
            volume_product<=0; gain_product<=0; volume_smooth<=volume_target;
        end else begin
            case(state)
                0: if(sample_tick) begin
                    index<=0; mix<=0; state<=1;
                    if(volume_smooth<volume_target) volume_smooth<=volume_smooth+1'b1;
                    else if(volume_smooth>volume_target) volume_smooth<=volume_smooth-1'b1;
                end
                1: begin
                    mix<=mix+{{3{product[25]}},product};
                    if(index==16) state<=2; else index<=index+1'b1;
                end
                2: begin scaled_mix<=mix>>>12; state<=3; end
                3: begin volume_product<=scaled_mix*$signed({1'b0,volume_smooth}); state<=4; end
                4: begin gain_product<=volume_pcm*$signed({1'b0,bounded_gain}); state<=5; end
                5: begin pcm<=gain_product[23:8]; state<=0; end
                default: state<=0;
            endcase
        end
    end
endmodule
