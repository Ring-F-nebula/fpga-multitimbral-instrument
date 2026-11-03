`timescale 1ns/1ps
module tb_font_equivalence;
    `include "ui_font.vh"
    // Independent oracle uses the teammate's original arithmetic, including
    // character placement, scaling, clipping and glyph bit numbering.
    function reference_text;
        input [319:0] text;
        input integer length,px,py,ox,oy,scale;
        integer col,gx,gy,index;
        reg [34:0] original_bits;
        begin
            reference_text=0;
            if(px>=ox && px<ox+(length<<(3+scale)) && py>=oy && py<oy+(7<<scale))begin
                col=(px-ox)>>(3+scale);gx=((px-ox)>>scale)&7;gy=(py-oy)>>scale;
                original_bits=glyph(text[(length-1-col)*8+:8]);index=34-(gy*5+gx);
                if(gx<5)reference_text=original_bits[index];
            end
        end
    endfunction
    reg [319:0] text;integer checks=0;
    initial begin
        // All character codes, all supported scales, glyph edges and padding.
        for(integer c=0;c<256;c=c+1)begin
            text=c;
            for(integer scale=0;scale<3;scale=scale+1)
                for(integer y=-1;y<=(7<<scale);y=y+1)
                    for(integer x=-1;x<=(8<<scale);x=x+1)begin
                        if(text_on(text,1,x+528,y+109,528,109,scale)!==reference_text(text,1,x+528,y+109,528,109,scale))
                            $fatal(1,"font changed c=%h scale=%d x=%d y=%d",c,scale,x,y);
                        checks=checks+1;
                    end
        end
        text="X PCM / Y PCM DELAY 32 SAMPLES";
        for(integer y=353;y<=362;y=y+1)for(integer x=527;x<=768;x=x+1)begin
            if(text_on(text,30,x,y,528,354,0)!==reference_text(text,30,x,y,528,354,0))$fatal(1,"long caption changed");
            checks=checks+1;
        end
        $display("PASS font equivalence: %0d pixels, all 256 characters, scales 0/1/2, clipping and long captions unchanged",checks);$finish;
    end
endmodule
