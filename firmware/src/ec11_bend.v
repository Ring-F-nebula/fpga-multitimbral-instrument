// Full quadrature decoding. Contact bounce reverses/cancels partial motion;
// an illegal two-bit jump discards the partial detent instead of guessing.
module ec11_decoder #(parameter integer FILTER_CYCLES=13125)(
    input clk,input a_n,input b_n,output reg clockwise=0,counterclockwise=0
);
    reg [1:0] meta=2'b11,sync=2'b11,stable=2'b11,previous=2'b11;
    reg [1:0] candidate=2'b11;
    reg [15:0] filter_count=0;
    reg signed [3:0] quarter_steps=0;
    reg signed [2:0] direction;
    always @* begin
        case({previous,stable})
            4'b1110,4'b1000,4'b0001,4'b0111: direction=1;
            4'b1101,4'b0100,4'b0010,4'b1011: direction=-1;
            default: direction=0;
        endcase
    end
    always @(posedge clk) begin
        meta<={a_n,b_n}; sync<=meta;
        clockwise<=0; counterclockwise<=0;
        if(sync!=candidate) begin candidate<=sync; filter_count<=0; end
        else if(sync==stable) filter_count<=0;
        else if(filter_count==FILTER_CYCLES-1) begin
            stable<=sync; filter_count<=0;
        end else filter_count<=filter_count+1'b1;
        if(stable!=previous) begin
            previous<=stable;
            if(direction==0) quarter_steps<=0;
            else if(direction==1 && quarter_steps==3) begin
                clockwise<=1; quarter_steps<=0;
            end else if(direction==-1 && quarter_steps==-3) begin
                counterclockwise<=1; quarter_steps<=0;
            end else quarter_steps<=quarter_steps+direction;
        end
    end
endmodule

// The most recently pressed manual note is selected. Simultaneous onsets
// select the highest index. Selecting a new note resets bend to concert pitch.
// Push resets bend; rotation without the selected key held is ignored.
module single_note_bend #(parameter integer CENTS_PER_STEP=10)(
    input clk,input clear,input [15:0] live_keys,
    input clockwise,counterclockwise,reset_bend,
    output reg [3:0] bend_target=0,output reg signed [8:0] bend_cents=0
);
    localparam signed [8:0] STEP=CENTS_PER_STEP;
    reg [15:0] previous_keys=0;
    wire [15:0] newly_pressed=live_keys & ~previous_keys;
    reg [3:0] newest;
    integer i;
    always @* begin
        newest=0;
        for(i=0;i<16;i=i+1) if(newly_pressed[i]) newest=i;
    end
    always @(posedge clk) begin
        previous_keys<=live_keys;
        if(clear) begin bend_target<=0; bend_cents<=0; end
        else if(newly_pressed!=0) begin bend_target<=newest; bend_cents<=0; end
        else if(reset_bend) bend_cents<=0;
        else if(live_keys[bend_target]) begin
            if(clockwise && !counterclockwise) begin
                if(bend_cents>=200-CENTS_PER_STEP) bend_cents<=200;
                else bend_cents<=bend_cents+STEP;
            end else if(counterclockwise && !clockwise) begin
                if(bend_cents<=-200+CENTS_PER_STEP) bend_cents<=-200;
                else bend_cents<=bend_cents-STEP;
            end
        end
    end
endmodule
