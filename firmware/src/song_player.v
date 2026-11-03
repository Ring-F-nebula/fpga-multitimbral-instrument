// Event sequencer analogous to reference autoplay: ROM -> timed note -> loop.
// ROM is synchronous. Sixteenth durations alternate fractional sample counts
// in generated data, so 125 BPM has no cumulative timing drift.
module song_player #(parameter integer TIME_SHIFT=0)(
    input clk,input sample_tick,input enable,
    output reg gate=0,output reg [23:0] step=0);
    reg [9:0] address=0;
    wire [23:0] rom_step;
    wire [23:0] rom_duration;
    wire last_event;
    score_rom rom(clk,address,rom_step,rom_duration,last_event);
    reg [2:0] state=0;
    reg [23:0] remaining=0;
    reg last_latched=0;
    wire [23:0] duration=(rom_duration>>TIME_SHIFT)<2 ? 24'd2 : (rom_duration>>TIME_SHIFT);
    // Stop 14 ms before each note boundary: release reaches zero before
    // changing pitch. No extra time is inserted into the score.
    localparam integer RELEASE_SAMPLES=(TIME_SHIFT==0)?640:1;
    always @(posedge clk) begin
        if(!enable) begin state<=0; address<=0; gate<=0; remaining<=0; step<=0; end
        else case(state)
            0: state<=1;
            1: state<=2;
            2,4: if(sample_tick) begin
                step<=rom_step; gate<=(rom_step!=0); remaining<=duration;
                last_latched<=last_event; state<=3;
            end
            3: if(sample_tick) begin
                if(remaining<=RELEASE_SAMPLES+1) gate<=0;
                if(remaining==2) begin
                    address<=last_latched?10'd0:address+1'b1;
                    state<=4;
                end else remaining<=remaining-1'b1;
            end
            // State 4 prefetches the next event during the last sample period.
            default: state<=0;
        endcase
    end
endmodule
