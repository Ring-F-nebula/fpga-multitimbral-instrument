`timescale 1ns/1ps
module tb_ui_font;
    `include "ui_font.vh"
    reg [34:0] mask;
    reg expected;
    integer checks=0;
    initial begin
        for(integer ch=0;ch<256;ch=ch+1) begin
            mask=glyph(ch[7:0]);
            for(integer scale=0;scale<3;scale=scale+1)
                for(integer yy=0;yy<(8<<scale);yy=yy+1)
                    for(integer xx=0;xx<(8<<scale);xx=xx+1) begin
                        expected=((yy>>scale)<7 && (xx>>scale)<5)?mask[34-(yy>>scale)*5-(xx>>scale)]:0;
                        if(text_on(ch[7:0],1,37+xx,53+yy,37,53,scale)!==expected)
                            $fatal(1,"font bit equivalence ch=%d scale=%d x=%d y=%d",ch,scale,xx,yy);
                        checks=checks+1;
                    end
        end
        $display("PASS font optimization exact glyph-pixel equivalence: all 256 bytes, all three scales, all 7 rows, five ink columns and blank cells; checks=%0d",checks);
        $finish;
    end
endmodule
