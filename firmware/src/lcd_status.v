// ATK-MD0700R-1024600, 24-bit parallel RGB, 52.5 MHz.
// 1344 x 635 total -> 61.50 Hz. The screen is used in DE mode.
// Keep data stable at the rising edge of the external pixel clock.
module lcd_status(
    input wire clk,
    input wire auto_mode,
    input wire [15:0] live_keys,
    input wire [3:0] volume,attack_sel,decay_sel,release_sel,
    input wire [7:0] sustain_level,
    input wire sensor_ready,sensor_active,
    output reg [7:0] r=0,g=0,b=0,
    output wire pclk,hsync,vsync,de,bl,lcd_reset
);
    localparam integer HTOTAL=1344, VTOTAL=635;
    localparam integer HSTART=308, VSTART=23;
    reg [10:0] h=0;
    reg [9:0] v=0;
    reg [21:0] boot=0;
    reg mode_q=0,ready_q=0,active_q=0;
    reg [15:0] keys_q=0;
    reg [3:0] vol_q=0,a_q=0,d_q=0,r_q=0;
    reg [7:0] s_q=0;
    always @(posedge clk) begin
        if(h==HTOTAL-1) begin
            h<=0;
            if(v==VTOTAL-1) v<=0;
            else v<=v+1'b1;
        end else h<=h+1'b1;
        if(boot!=22'h3fffff) boot<=boot+1'b1;
        // Visual status only; all sound/control logic remains in the 26.25 MHz domain.
        mode_q<=auto_mode; keys_q<=live_keys; vol_q<=volume;
        a_q<=attack_sel; d_q<=decay_sel; s_q<=sustain_level;
        r_q<=release_sel; ready_q<=sensor_ready; active_q<=sensor_active;
    end
    assign lcd_reset=(boot>=22'd1048576);
    assign bl=(boot>=22'd2097152);
    assign pclk=~clk;
    assign hsync=(h>=148);
    assign vsync=(v>=3);
    assign de=(h>=HSTART && h<HSTART+1024 &&
               v>=VSTART && v<VSTART+600 && lcd_reset);
    wire [10:0] x=h-HSTART;
    wire [9:0] y=v-VSTART;

    reg [4:0] first_note;
    integer n;
    always @* begin
        first_note=5'd16;
        for(n=15;n>=0;n=n-1)
            if(keys_q[n]) first_note=n[4:0];
    end
    function [7:0] digit;
        input [3:0] value;
        begin digit=8'd48+value; end
    endfunction
    function [7:0] note_letter;
        input [4:0] number;
        begin
            case(number)
                0,1,12,13: note_letter="C";
                2,3,14,15: note_letter="D";
                4: note_letter="E";
                5,6: note_letter="F";
                7,8: note_letter="G";
                9,10: note_letter="A";
                11: note_letter="B";
                default: note_letter="-";
            endcase
        end
    endfunction
    function [7:0] status_char;
        input [2:0] row;
        input [5:0] col;
        input mode,ready,active;
        input [4:0] note;
        input [3:0] vol,aa,dd,rr;
        input [7:0] ss;
        begin
            status_char=" ";
            case(row)
                0: case(col)
                    0:status_char="F";1:status_char="P";2:status_char="G";
                    3:status_char="A";5:status_char="P";6:status_char="I";
                    7:status_char="A";8:status_char="N";9:status_char="O";
                endcase
                1: case(col)
                    0:status_char="M";1:status_char="O";2:status_char="D";
                    3:status_char="E";4:status_char=":";
                    6:status_char=mode?"A":"M";
                    7:status_char=mode?"U":"A";
                    8:status_char=mode?"T":"N";
                    9:status_char=mode?"O":" ";
                endcase
                2: case(col)
                    0:status_char="N";1:status_char="O";2:status_char="T";
                    3:status_char="E";4:status_char=":";
                    6:status_char=mode?"S":note_letter(note);
                    7:status_char=mode?"O":((note==1 || note==3 || note==6 ||
                       note==8 || note==10 || note==13 || note==15)?"#":
                       ((note<16)?digit((note>=12)?5:4):" "));
                    8:status_char=mode?"N":((note<16 && (note==1 || note==3 ||
                       note==6 || note==8 || note==10 || note==13 || note==15))?
                       digit((note>=12)?5:4):" ");
                    9:status_char=mode?"G":" ";
                endcase
                3: case(col)
                    0:status_char="V";1:status_char="O";2:status_char="L";
                    3:status_char=":";5:status_char=digit((vol>=10)?1:0);
                    6:status_char=digit((vol>=10)?vol-10:vol);
                endcase
                4: case(col)
                    0:status_char="A";1:status_char=":";
                    2:status_char=digit(aa);
                    4:status_char="D";5:status_char=":";
                    6:status_char=digit(dd);
                    8:status_char="S";9:status_char=":";
                    10:status_char=digit(ss/100);
                    11:status_char=digit((ss%100)/10);
                    12:status_char=digit(ss%10);
                    14:status_char="R";15:status_char=":";
                    16:status_char=digit(rr);
                endcase
                5: case(col)
                    0:status_char="S";1:status_char="E";2:status_char="N";
                    3:status_char="S";4:status_char="O";5:status_char="R";
                    6:status_char=":";
                    8:status_char=mode?"S":(active?"A":(ready?"R":"W"));
                    9:status_char=mode?"O":(active?"C":(ready?"E":"A"));
                    10:status_char=mode?"N":(active?"T":(ready?"A":"I"));
                    11:status_char=mode?"G":(active?"I":(ready?"D":"T"));
                    12:status_char=(active && !mode)?"V":
                       ((ready && !mode)?"Y":" ");
                    13:status_char=(active && !mode)?"E":" ";
                endcase
            endcase
        end
    endfunction
    // 5x7 uppercase font, each concatenated group is one scanline.
    function [34:0] glyph;
        input [7:0] c;
        begin
            case(c)
                "A":glyph={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
                "B":glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110};
                "C":glyph={5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
                "D":glyph={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
                "E":glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
                "F":glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b10000};
                "G":glyph={5'b01111,5'b10000,5'b10000,5'b10111,5'b10001,5'b10001,5'b01111};
                "I":glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111};
                "L":glyph={5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
                "M":glyph={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
                "N":glyph={5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001};
                "O":glyph={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
                "P":glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
                "R":glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
                "S":glyph={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
                "T":glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
                "U":glyph={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
                "V":glyph={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100};
                "W":glyph={5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b10101,5'b01010};
                "Y":glyph={5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
                "0":glyph={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
                "1":glyph={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
                "2":glyph={5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
                "3":glyph={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
                "4":glyph={5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
                "5":glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
                "6":glyph={5'b01111,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
                "7":glyph={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
                "8":glyph={5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
                "9":glyph={5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b11110};
                ":":glyph={5'b00000,5'b00100,5'b00100,5'b00000,5'b00100,5'b00100,5'b00000};
                "#":glyph={5'b01010,5'b11111,5'b01010,5'b01010,5'b11111,5'b01010,5'b00000};
                "-":glyph={5'b00000,5'b00000,5'b00000,5'b11111,5'b00000,5'b00000,5'b00000};
                default:glyph=35'b0;
            endcase
        end
    endfunction
    reg [2:0] row;
    reg [5:0] col;
    reg [2:0] gx,gy;
    reg [7:0] ch;
    reg [34:0] bitmap;
    reg text_pixel;
    integer xx,yy;
    always @* begin
        row=7; col=0; gx=0; gy=0; ch=" "; bitmap=0;
        text_pixel=0; xx=0; yy=0;
        if(de && x>=40) begin
            xx=x-40;
            if(y>=20 && y<76) begin row=0; yy=y-20; end
            else if(y>=128 && y<184) begin row=1; yy=y-128; end
            else if(y>=232 && y<288) begin row=2; yy=y-232; end
            else if(y>=336 && y<392) begin row=3; yy=y-336; end
            else if(y>=456 && y<484) begin row=4; yy=y-456; end
            else if(y>=536 && y<564) begin row=5; yy=y-536; end
            if(row<4) begin
                col=xx/48; gx=(xx%48)/8; gy=yy/8;
            end else if(row<6) begin
                col=xx/24; gx=(xx%24)/4; gy=yy/4;
            end
            if(row<6 && col<24 && gx<5 && gy<7) begin
                ch=status_char(row,col,mode_q,ready_q,active_q,
                               first_note,vol_q,a_q,d_q,r_q,s_q);
                bitmap=glyph(ch);
                text_pixel=bitmap[34-(gy*5+gx)];
            end
        end
        r=0;g=0;b=0;
        if(de) begin
            r=8'h0d;g=8'h1b;b=8'h2a;
            if(y<96) begin r=8'h14;g=8'h49;b=8'h5a; end
            if(y>=420 && y<424) begin r=8'h2d;g=8'h8a;b=8'h9e; end
            if(text_pixel) begin
                r=8'he9;g=8'hf5;b=8'hf8;
                if(row==0) begin r=8'hff;g=8'hd1;b=8'h66; end
                if(row==5 && ready_q && !mode_q) begin
                    r=8'h60;g=8'he0;b=8'hac;
                end
            end
        end
    end
endmodule
