// Coordinate/character decoding is registered separately from the glyph
// lookup. All labels keep this identical one-cycle latency.
module text_cell #(parameter integer LENGTH=1,OX=0,OY=0,SCALE=0)(
    input clk,visible,input [10:0] x,input [9:0] y,
    input [319:0] text,output wire pixel);
    `include "ui_font.vh"
    wire in_view=visible && x>=OX && x<OX+(LENGTH<<(3+SCALE)) &&
        y>=OY && y<OY+(7<<SCALE);
    wire [10:0] dx=x-OX;
    wire [9:0] dy=y-OY;
    wire [5:0] column=in_view ? dx>>(3+SCALE):6'd0;
    wire [2:0] gx=dx>>SCALE,gy=dy>>SCALE;
    // Parallel constant byte selection avoids a reversed 320-bit variable
    // slice address and its subtract/carry chain.
    wire [7:0] selected[0:LENGTH];
    assign selected[0]=0;
    genvar n;
    generate for(n=0;n<LENGTH;n=n+1) begin: select_byte
        assign selected[n+1]=selected[n] | ({8{column==n}} & text[(LENGTH-1-n)*8+:8]);
    end endgenerate
    wire [14:0] candidate=in_view?{gx<5,gy,gx,selected[LENGTH]}:15'd0;
    reg [14:0] decoded=0;
    always @(posedge clk) decoded<=candidate;
    wire [34:0] shape=glyph(decoded[7:0]);
    reg [4:0] row;
    always @* case(decoded[13:11])
        0:row=shape[34:30];1:row=shape[29:25];2:row=shape[24:20];
        3:row=shape[19:15];4:row=shape[14:10];5:row=shape[9:5];
        default:row=shape[4:0];
    endcase
    assign pixel=decoded[14] && row[4-decoded[10:8]];
endmodule
