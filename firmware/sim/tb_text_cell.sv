`timescale 1ns/1ps
module tb_text_cell;
    `include "ui_font.vh"
    reg clk=0;always #5 clk=~clk;
    reg [10:0] x=0,long_x=0;
    reg [9:0] y=0,long_y=0;
    reg [7:0] ch=0;
    reg [319:0] long_text=0;
    wire [2:0] pixels;
    wire long_pixel;
    genvar n;
    generate for(n=0;n<3;n=n+1) begin: sized
        text_cell #(.LENGTH(1),.OX(37),.OY(53),.SCALE(n)) cell_inst(clk,1'b1,x,y,{312'd0,ch},pixels[n]);
    end endgenerate
    text_cell #(.LENGTH(40),.OX(5),.OY(7)) long_cell(clk,1'b1,long_x,long_y,long_text,long_pixel);
    integer checks=0;
    initial begin
        for(integer c=0;c<256;c=c+1)
            for(integer scale=0;scale<3;scale=scale+1)
                for(integer yy=0;yy<(8<<scale);yy=yy+1)
                    for(integer xx=0;xx<(8<<scale);xx=xx+1) begin
                        @(negedge clk);ch=c;x=37+xx;y=53+yy;
                        @(posedge clk);#1;
                        if(pixels[scale]!==text_on(ch,1,x,y,37,53,scale)) $fatal(1,"pipelined glyph mismatch");
                        checks=checks+1;
                    end
        for(integer i=0;i<40;i=i+1) long_text[(39-i)*8+:8]=32+i;
        for(integer yy=0;yy<8;yy=yy+1)
            for(integer xx=0;xx<320;xx=xx+1) begin
                @(negedge clk);long_x=5+xx;long_y=7+yy;
                @(posedge clk);#1;
                if(long_pixel!==text_on(long_text,40,long_x,long_y,5,7,0)) $fatal(1,"parallel character selection mismatch");
                checks=checks+1;
            end
        $display("PASS pipelined text cell: all 256 bytes, three scales, all pixels and all 40 character positions; exact one-cycle equivalence; checks=%0d",checks);
        $finish;
    end
endmodule
