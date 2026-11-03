// Fixed 42-note public-domain Twinkle melody. A sample-clock timeline drives
// both the audible note onsets and scoring; touch-report edges are consumed
// at the fast clock, so no edge can disappear between sample ticks.
module rhythm_game #(parameter integer SAMPLE_RATE=45573,
    parameter integer BEAT_SAMPLES=22786)(
    input clk,sample_tick,enabled,start,stop,input [15:0] keys,
    output reg running=0,finished=0,music_gate=0,
    output reg [23:0] music_step=0,
    output wire [15:0] cue_keys,output wire [3:0] target_note,next_note,
    output wire [1:0] countdown,
    output reg [15:0] score=0,
    output reg [5:0] combo=0,max_combo=0,hits=0,misses=0,
    output reg [9:0] wrong=0,
    output reg [2:0] feedback=0,
    output wire [5:0] progress,output wire signed [10:0] cue_position);
    localparam integer LEAD=SAMPLE_RATE*150/1000;
    localparam integer PERFECT=SAMPLE_RATE*60/1000;
    localparam integer RELEASE=SAMPLE_RATE*14/1000;
    localparam integer COUNT_IN=3*SAMPLE_RATE;
    localparam integer END_TIME=COUNT_IN+48*BEAT_SAMPLES;
    reg [23:0] song_time=0,judge_time=COUNT_IN;
    reg [23:0] audio_next=COUNT_IN,audio_release=0;
    reg [5:0] audio_index=0,judge_index=0;
    reg judge_done=0,judged=0,audio_done=0;
    reg [15:0] previous_keys=0;
    reg [15:0] feedback_hold=0;
    wire [15:0] pressed=keys & ~previous_keys;
    function [3:0] melody_note;
        input [5:0] index;
        begin case(index)
            0,1,13,28,29,41:melody_note=0;
            11,12,20,27,39,40:melody_note=2;
            9,10,18,19,25,26,37,38:melody_note=4;
            7,8,16,17,23,24,35,36:melody_note=5;
            2,3,6,14,15,21,22,30,31,34:melody_note=7;
            4,5,32,33:melody_note=9;
            default:melody_note=0;
        endcase
        end
    endfunction
    function [23:0] note_duration;
        input [5:0] index;
        begin case(index)
            6,13,20,27,34,41:note_duration=2*BEAT_SAMPLES;
            default:note_duration=BEAT_SAMPLES;
        endcase end
    endfunction
    function [23:0] phase_step;
        input [3:0] note;
        begin case(note)
            0:phase_step=96315;2:phase_step=108110;4:phase_step=121349;
            5:phase_step=128565;7:phase_step=144309;9:phase_step=161982;
            default:phase_step=0;
        endcase end
    endfunction
    assign target_note=melody_note(judge_index);
    assign next_note=melody_note(judge_index==41?6'd41:judge_index+1'b1);
    wire in_window=running && !judge_done && song_time+LEAD>=judge_time && song_time<=judge_time+LEAD;
    assign cue_keys=(in_window && !judged)?(16'h0001<<target_note):16'd0;
    assign countdown=!running || song_time>=COUNT_IN?2'd0:
        song_time<SAMPLE_RATE?2'd3:song_time<2*SAMPLE_RATE?2'd2:2'd1;
    assign progress=audio_done?6'd42:audio_index;
    wire signed [24:0] time_delta=$signed({1'b0,judge_time})-$signed({1'b0,song_time});
    wire signed [24:0] position=time_delta>>>7;
    assign cue_position=position>600?11'sd600:position< -64?-11'sd64:position[10:0];
    wire perfect_timing=(song_time+PERFECT>=judge_time && song_time<=judge_time+PERFECT);
    always @(posedge clk) begin
        previous_keys<=keys;
        if(!enabled) begin running<=0;finished<=0;music_gate<=0;feedback<=0;end
        else if(start) begin
            running<=1;finished<=0;music_gate<=0;music_step<=0;
            song_time<=0;judge_time<=COUNT_IN;audio_next<=COUNT_IN;audio_release<=0;
            audio_index<=0;judge_index<=0;judge_done<=0;judged<=0;audio_done<=0;
            previous_keys<=keys;score<=0;combo<=0;max_combo<=0;hits<=0;misses<=0;
            wrong<=0;feedback<=0;feedback_hold<=0;
        end else if(stop) begin running<=0;finished<=0;music_gate<=0;feedback<=0;end
        else if(running) begin
            if(sample_tick) begin
                song_time<=song_time+1'b1;
                if(feedback_hold!=0) feedback_hold<=feedback_hold-1'b1;
                else feedback<=0;
                if(!audio_done && song_time==audio_next) begin
                    music_step<=phase_step(melody_note(audio_index));music_gate<=1;
                    audio_release<=audio_next+note_duration(audio_index)-RELEASE;
                    audio_next<=audio_next+note_duration(audio_index);
                    if(audio_index==41) audio_done<=1;
                    else audio_index<=audio_index+1'b1;
                end
                if(music_gate && song_time==audio_release) music_gate<=0;
                if(!judge_done && song_time>judge_time+LEAD) begin
                    if(!judged) begin misses<=misses+1'b1;combo<=0;feedback<=3;feedback_hold<=SAMPLE_RATE*2/5;end
                    judged<=0;
                    if(judge_index==41) judge_done<=1;
                    else begin judge_index<=judge_index+1'b1;judge_time<=judge_time+note_duration(judge_index);end
                end
                if(song_time>=END_TIME) begin running<=0;finished<=1;music_gate<=0;end
            end
            if(pressed!=0 && !judged && !judge_done && (in_window || song_time>=COUNT_IN)) begin
                if(in_window && pressed==(16'h0001<<target_note)) begin
                    score<=score+(perfect_timing?16'd100:16'd50);hits<=hits+1'b1;
                    combo<=combo+1'b1;
                    if(combo+1'b1>max_combo) max_combo<=combo+1'b1;
                    feedback<=perfect_timing?3'd1:3'd2;judged<=1;
                end else begin
                    if(wrong<999) wrong<=wrong+1'b1;
                    combo<=0;feedback<=4;
                end
                feedback_hold<=SAMPLE_RATE*2/5;
            end
        end
    end
endmodule
