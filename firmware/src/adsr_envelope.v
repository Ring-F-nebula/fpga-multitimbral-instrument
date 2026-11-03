// Per-voice linear ADSR. Tick rate MUST be 26.25 MHz / 576.
// Times latch on phase entry: 0..9 = 1,2,5,10,20,50,100,200,500,1000 ms.
// 10..15 clamp to 1000 ms. Sustain is a level, expanded 8 -> 16 bits.
// A gate edge starts the phase at the existing amplitude. The N following
// ticks complete an N-sample ramp. Early release/retrigger never reset level.
// Q16.16 ramp increments use precomputed reciprocals, not a divider.
module adsr_envelope(
    input clk, input tick, input clear, input gate,
    input [3:0] attack_sel, decay_sel, release_sel,
    input [7:0] sustain_level,
    output wire [15:0] level,
    output reg [2:0] state=0
);
    localparam IDLE=3'd0, ATTACK=3'd1, DECAY=3'd2,
               SUSTAIN=3'd3, RELEASE=3'd4;
    reg previous_gate=0;
    reg [31:0] value=0, rate=0;
    reg [15:0] remaining=0, target=0;
    reg rising=0;
    assign level=value[31:16];
    wire [15:0] sustain={sustain_level,sustain_level};
    function [15:0] duration;
        input [3:0] sel;
        begin case(sel)
            0:duration=46; 1:duration=91; 2:duration=228;
            3:duration=456; 4:duration=911; 5:duration=2279;
            6:duration=4557; 7:duration=9115; 8:duration=22786;
            default:duration=45573;
        endcase end
    endfunction
    // floor(2**32 / duration). See scripts/generate_audio_tables.py.
    function [31:0] reciprocal;
        input [3:0] sel;
        begin case(sel)
            0:reciprocal=93368854; 1:reciprocal=47197442;
            2:reciprocal=18837575; 3:reciprocal=9418787;
            4:reciprocal=4714563; 5:reciprocal=1884584;
            6:reciprocal=942498; 7:reciprocal=471197;
            8:reciprocal=188491; default:reciprocal=94243;
        endcase end
    endfunction
    reg start_ramp;
    reg [2:0] requested_state;
    reg [3:0] requested_time;
    reg [15:0] requested_target;
    // A->D has one sample of peak hold. D->S stays amplitude-continuous.
    // Changing the S control while sustaining ramps using the selected D time.
    always @* begin
        start_ramp=0; requested_state=state; requested_time=0;
        requested_target=target;
        if(gate && !previous_gate) begin
            start_ramp=1; requested_state=ATTACK;
            requested_time=attack_sel; requested_target=16'hffff;
        end else if(!gate && previous_gate) begin
            start_ramp=1; requested_state=RELEASE;
            requested_time=release_sel; requested_target=0;
        end else if(state==ATTACK && remaining==0) begin
            start_ramp=1; requested_state=DECAY;
            requested_time=decay_sel; requested_target=sustain;
        end else if(state==SUSTAIN && gate && sustain!=target) begin
            start_ramp=1; requested_state=DECAY;
            requested_time=decay_sel; requested_target=sustain;
        end
    end
    wire [15:0] distance=(requested_target>=level) ?
        requested_target-level : level-requested_target;
    wire [47:0] rate_product=distance*reciprocal(requested_time);
    wire [32:0] sum={1'b0,value}+{1'b0,rate};
    wire [31:0] endpoint={target,16'b0};
    always @(posedge clk) begin
        if(clear) begin
            value<=0; rate<=0; remaining<=0; target<=0;
            rising<=0; previous_gate<=0; state<=IDLE;
        end else if(tick) begin
            previous_gate<=gate;
            if(start_ramp) begin
                state<=requested_state; remaining<=duration(requested_time);
                target<=requested_target; rising<=(requested_target>=level);
                rate<=rate_product[47:16];
            end else if(remaining!=0) begin
                remaining<=remaining-1'b1;
                if(remaining==1) value<=endpoint;
                else if(rising) value<=sum>{1'b0,endpoint} ? endpoint:sum[31:0];
                else value<=(value<=rate || value-rate<endpoint) ? endpoint:value-rate;
            end else begin
                if(state==DECAY) state<=SUSTAIN;
                if(state==RELEASE) begin state<=IDLE; value<=0; end
            end
        end
    end
endmodule
