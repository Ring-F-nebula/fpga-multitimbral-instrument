// Standard I2S: 16-bit two's-complement, WS=0 left / WS=1 right.
// NXP UM11732 section 3: WS changes one BCK before the next word's MSB.
// 26.25 MHz / (9*2*32) = 45572.9167 nominal stereo frames/second.
// Mono is duplicated AFTER latching, so L/R cannot straddle two samples.
// sample_tick deliberately matches the retained pt8211_tx: both outputs
// latch pcm_next on the same clk edge. The two serial formats are different.
module i2s_tx(
    input wire clk,
    input wire signed [15:0] pcm_next,
    output reg bck=0,
    output reg ws=0,
    output reg din=0,
    output wire sample_tick
);
    reg [3:0] divider=0;
    reg [4:0] bit_index=0;
    reg [15:0] pcm=0;
    reg primed=0;
    assign sample_tick=(divider==8) && bck && (bit_index==0);

    always @(posedge clk) begin
        if(divider==8) begin
            divider<=0;
            bck<=~bck;
            // All data/WS transitions occur on the BCK falling edge.
            if(bck) begin
                if(bit_index==0) begin
                    pcm<=pcm_next;
                    din<=primed ? pcm_next[15] : 1'b0;
                end else if(bit_index<16)
                    din<=primed ? pcm[15-bit_index] : 1'b0;
                else
                    din<=primed ? pcm[31-bit_index] : 1'b0;

                // The old channel's LSB shares the WS transition, not MSB.
                if(bit_index==15) ws<=1;
                if(bit_index==31) begin
                    ws<=0;
                    primed<=1;
                end
                bit_index<=bit_index+1'b1;
            end
        end else divider<=divider+1'b1;
    end
endmodule
