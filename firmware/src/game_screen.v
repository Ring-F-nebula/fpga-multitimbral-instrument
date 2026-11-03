// Parallel four-cycle renderer. instrument_screen selects its registered
// color in the fifth RGB stage, with the same latency for DE/sync.
module game_screen(input clk,frame_start,visible,input [10:0] raster_x,
    input [9:0] raster_y,input running,finished,
    input [15:0] score,keys,cue_keys,input [5:0] combo,max_combo,hits,misses,progress,
    input [9:0] wrong,input [2:0] feedback,input [1:0] countdown,
    input [3:0] target_note,next_note,volume,
    output reg [23:0] pixel_color=0);
    `include "ui_layout.vh"
    wire [28:0] font_pixels;
    `include "ui_font.vh"
    reg run_q=0,done_q=0;
    reg [15:0] score_q=0,keys_q=0,cue_q=0;
    reg [5:0] combo_q=0,max_q=0,hits_q=0,miss_q=0,progress_q=0;
    reg [9:0] wrong_q=0;
    reg [2:0] feedback_q=0;
    reg [1:0] count_q=0;
    reg [3:0] target_q=0,next_q=0,vol_q=8;
    reg format_pending=0;
    always @(posedge clk) begin
        format_pending<=frame_start;
        if(frame_start) begin
            run_q<=running;done_q<=finished;score_q<=score;keys_q<=keys;cue_q<=cue_keys;
            combo_q<=combo;max_q<=max_combo;hits_q<=hits;miss_q<=misses;
            progress_q<=progress;wrong_q<=wrong;feedback_q<=feedback;count_q<=countdown;
            target_q<=target_note;next_q<=next_note;vol_q<=volume;
        end
    end
    function [7:0] digit;
        input [15:0] n;
        begin digit=8'd48+n%10;end
    endfunction
    function [23:0] decimal3;
        input [15:0] n;
        begin decimal3={digit(n/100),digit(n/10),digit(n)};end
    endfunction
    function [15:0] decimal2;
        input [15:0] n;
        begin decimal2={digit(n/10),digit(n)};end
    endfunction
    function [15:0] note_name;
        input [3:0] n;
        begin case(n)
            0:note_name="C4";2:note_name="D4";4:note_name="E4";
            5:note_name="F4";7:note_name="G4";9:note_name="A4";11:note_name="B4";
            default:note_name="C5";
        endcase end
    endfunction
    function [3:0] white_note;
        input integer n;
        begin case(n)
            0:white_note=0;1:white_note=2;2:white_note=4;3:white_note=5;
            4:white_note=7;5:white_note=9;6:white_note=11;default:white_note=12;
        endcase end
    endfunction
    reg [31:0] score_text="0000";
    reg [15:0] combo_text="00",max_text="00",hit_text="00",miss_text="00",progress_text="00",volume_text="08";
    reg [23:0] wrong_text="000";
    reg [7:0] count_text="3";
    reg [10:0] progress_end=16;
    wire [61:0] format_state={score_q,combo_q,max_q,hits_q,miss_q,wrong_q,progress_q,vol_q,count_q};
    reg [61:0] formatted_state={62{1'b1}};
    // Change-driven formatting avoids repeatedly executing decimal functions
    // in integration tests that deliberately hold the raster at frame start.
    always @(posedge clk) if(format_pending && format_state!=formatted_state) begin
        formatted_state<=format_state;
        combo_text<=decimal2(combo_q);max_text<=decimal2(max_q);hit_text<=decimal2(hits_q);
        miss_text<=decimal2(miss_q);progress_text<=decimal2(progress_q);volume_text<=decimal2(vol_q);
        wrong_text<=decimal3(wrong_q);count_text<=digit(count_q);
        progress_end<=16+progress_q*23;
    end
    // Convert the arbitrary score with one double-dabble step per clock,
    // rather than a 16-bit divide/remainder chain on the 52.5MHz pixel clock.
    reg [15:0] converted_score=16'hffff;
    reg [31:0] bcd_work=0,bcd_adjust,bcd_next;
    reg [4:0] bcd_left=0;
    integer j;
    always @* begin
        bcd_adjust=bcd_work;
        for(j=16;j<32;j=j+4) if(bcd_work[j+:4]>=5) bcd_adjust[j+:4]=bcd_work[j+:4]+4'd3;
        bcd_next=bcd_adjust<<1;
    end
    always @(posedge clk) begin
        if(format_pending && score_q!=converted_score) begin
            converted_score<=score_q;bcd_work<={16'd0,score_q};bcd_left<=16;
        end else if(bcd_left!=0) begin
            bcd_work<=bcd_next;bcd_left<=bcd_left-1'b1;
            if(bcd_left==1) score_text<={4'h3,bcd_next[31:28],4'h3,bcd_next[27:24],
                                       4'h3,bcd_next[23:20],4'h3,bcd_next[19:16]};
        end
    end
    (* syn_preserve=1, syn_keep=1 *) reg [10:0] x=0;
    (* syn_preserve=1, syn_keep=1 *) reg [9:0] y=0;
    reg v1=0,v2=0;
    reg [4:0] hit=31;
    reg [3:0] action=0;
    always @(posedge clk) begin
        x<=raster_x;y<=raster_y;v1<=visible;
        hit<=music_key_at(2'd0,raster_x,raster_y);
        action<=game_action_at(raster_x,raster_y);
    end
    reg [23:0] base,base_q=0,base_pre=0;
    reg v_pre=0;
    reg [23:0] ink,ink_q=0;
    reg dark,dark_q=0,black;
    integer i;
    always @* begin
        base=24'h0b1421;ink=0;dark=0;
        black=(hit==1 || hit==3 || hit==6 || hit==8 || hit==10) && y<500;
        if(y<48) base=24'h12283b;
        if(action==10) base=24'h28556a;
        if(action==1) base=24'h267f83;
        if(action==4) base=24'h823a4a;
        if(action==7 || action==8) base=24'h28556a;
        if(x>=16 && x<496 && y>=112 && y<352) base=24'h132438;
        if(x>=512 && x<1008 && y>=112 && y<352) base=24'h102936;
        if(y>=360 && y<368 && x>=16 && x<1008) base=x<progress_end?24'h63edc2:24'h20364b;
        if(x>=16 && x<1008 && y>=376 && y<592) begin
            base=black?24'h182232:24'he6edf0;
            if(hit<16 && cue_q[hit]) base=24'hffc65b;
            if(hit<16 && keys_q[hit]) base=24'h64cfca;
            for(i=0;i<8;i=i+1) if(x==16+i*124 || x==17+i*124) base=24'h192a3a;
            if(y>=588) base=24'h192a3a;
        end
        ink[0]=font_pixels[0];
        ink[1]=font_pixels[1];
        ink[2]=font_pixels[2] || font_pixels[3];
        ink[3]=font_pixels[4];
        ink[17]=font_pixels[5];
        ink[4]=font_pixels[6];
        ink[5]=font_pixels[7];
        ink[6]=font_pixels[8];
        ink[19]=font_pixels[9];
        ink[7]=font_pixels[10];
        ink[8]=font_pixels[11];
        ink[18]=font_pixels[12];
        ink[9]=font_pixels[13];
        ink[10]=font_pixels[14];
        ink[11]=font_pixels[15];
        ink[12]=font_pixels[16];
        ink[13]=font_pixels[17];
        ink[14]=font_pixels[18];
        ink[15]=font_pixels[19];
        ink[16]=font_pixels[20];
        if(font_pixels[21]) dark=1;
        if(font_pixels[22]) dark=1;
        if(font_pixels[23]) dark=1;
        if(font_pixels[24]) dark=1;
        if(font_pixels[25]) dark=1;
        if(font_pixels[26]) dark=1;
        if(font_pixels[27]) dark=1;
        if(font_pixels[28]) dark=1;
        if(!v1) base=0;
    end
    always @(posedge clk) begin base_pre<=base;v_pre<=v1;base_q<=base_pre;ink_q<=ink & {24{v_pre}};dark_q<=dark && v_pre;v2<=v_pre;end
    always @(posedge clk) pixel_color<=!v2?24'd0:(|ink_q)?24'he9f3f8:dark_q?24'h24384b:base_q;
    text_cell #(.LENGTH(14),.OX(16),.OY(8),.SCALE(2)) text_0(.clk(clk),.visible(v1),.x(x),.y(y),.text("RHYTHM GAME V4"),.pixel(font_pixels[0]));
    text_cell #(.LENGTH(4),.OX(896),.OY(18),.SCALE(1)) text_1(.clk(clk),.visible(v1),.x(x),.y(y),.text("BACK"),.pixel(font_pixels[1]));
    text_cell #(.LENGTH(5),.OX(72),.OY(69),.SCALE(1)) text_2(.clk(clk),.visible(v1),.x(x),.y(y),.text(run_q?"RETRY":"START"),.pixel(font_pixels[2]));
    text_cell #(.LENGTH(4),.OX(288),.OY(69),.SCALE(1)) text_3(.clk(clk),.visible(v1),.x(x),.y(y),.text("STOP"),.pixel(font_pixels[3]));
    text_cell #(.LENGTH(5),.OX(488),.OY(69),.SCALE(1)) text_4(.clk(clk),.visible(v1),.x(x),.y(y),.text("VOL -"),.pixel(font_pixels[4]));
    text_cell #(.LENGTH(8),.OX(664),.OY(69),.SCALE(1)) text_5(.clk(clk),.visible(v1),.x(x),.y(y),.text({"VOL + ",volume_text}),.pixel(font_pixels[5]));
    text_cell #(.LENGTH(5),.OX(32),.OY(128),.SCALE(1)) text_6(.clk(clk),.visible(v1),.x(x),.y(y),.text("SCORE"),.pixel(font_pixels[6]));
    text_cell #(.LENGTH(4),.OX(32),.OY(158),.SCALE(2)) text_7(.clk(clk),.visible(v1),.x(x),.y(y),.text(score_text),.pixel(font_pixels[7]));
    text_cell #(.LENGTH(8),.OX(32),.OY(208),.SCALE(1)) text_8(.clk(clk),.visible(v1),.x(x),.y(y),.text({"COMBO ",combo_text}),.pixel(font_pixels[8]));
    text_cell #(.LENGTH(7),.OX(192),.OY(208),.SCALE(1)) text_9(.clk(clk),.visible(v1),.x(x),.y(y),.text({"BEST ",max_text}),.pixel(font_pixels[9]));
    text_cell #(.LENGTH(14),.OX(32),.OY(244),.SCALE(1)) text_10(.clk(clk),.visible(v1),.x(x),.y(y),.text({"HIT ",hit_text," MISS ",miss_text}),.pixel(font_pixels[10]));
    text_cell #(.LENGTH(9),.OX(32),.OY(278),.SCALE(1)) text_11(.clk(clk),.visible(v1),.x(x),.y(y),.text({"WRONG ",wrong_text}),.pixel(font_pixels[11]));
    text_cell #(.LENGTH(10),.OX(192),.OY(278),.SCALE(1)) text_12(.clk(clk),.visible(v1),.x(x),.y(y),.text({"NOTE ",progress_text,"/42"}),.pixel(font_pixels[12]));
    text_cell #(.LENGTH(21),.OX(32),.OY(324),.SCALE(0)) text_13(.clk(clk),.visible(v1),.x(x),.y(y),.text("PERFECT 100 / GOOD 50"),.pixel(font_pixels[13]));
    text_cell #(.LENGTH(15),.OX(544),.OY(128),.SCALE(1)) text_14(.clk(clk),.visible(v1),.x(x),.y(y),.text("TWINKLE TWINKLE"),.pixel(font_pixels[14]));
    text_cell #(.LENGTH(8),.OX(544),.OY(160),.SCALE(1)) text_15(.clk(clk),.visible(v1),.x(x),.y(y),.text(done_q?"FINISHED":!run_q?"READY   ":count_q!=0?"GET SET ":"PLAY    "),.pixel(font_pixels[15]));
    text_cell #(.LENGTH(2),.OX(752),.OY(176),.SCALE(2)) text_16(.clk(clk),.visible(v1),.x(x),.y(y),.text(count_q!=0?{count_text,8'd32}:note_name(target_q)),.pixel(font_pixels[16]));
    text_cell #(.LENGTH(7),.OX(544),.OY(220),.SCALE(1)) text_17(.clk(clk),.visible(v1),.x(x),.y(y),.text({"NEXT ",note_name(next_q)}),.pixel(font_pixels[17]));
    text_cell #(.LENGTH(7),.OX(544),.OY(256),.SCALE(1)) text_18(.clk(clk),.visible(v1),.x(x),.y(y),.text(feedback_q==1?"PERFECT":feedback_q==2?"GOOD   ":feedback_q==3?"MISS   ":feedback_q==4?"WRONG  ":"       "),.pixel(font_pixels[18]));
    text_cell #(.LENGTH(24),.OX(544),.OY(304),.SCALE(0)) text_19(.clk(clk),.visible(v1),.x(x),.y(y),.text("TAP THE GOLD KEY IN TIME"),.pixel(font_pixels[19]));
    text_cell #(.LENGTH(27),.OX(544),.OY(324),.SCALE(0)) text_20(.clk(clk),.visible(v1),.x(x),.y(y),.text("RELEASE BEFORE THE NEXT TAP"),.pixel(font_pixels[20]));
    text_cell #(.LENGTH(2),.OX(70),.OY(548),.SCALE(1)) text_21(.clk(clk),.visible(v1),.x(x),.y(y),.text(note_name(white_note(0))),.pixel(font_pixels[21]));
    text_cell #(.LENGTH(2),.OX(194),.OY(548),.SCALE(1)) text_22(.clk(clk),.visible(v1),.x(x),.y(y),.text(note_name(white_note(1))),.pixel(font_pixels[22]));
    text_cell #(.LENGTH(2),.OX(318),.OY(548),.SCALE(1)) text_23(.clk(clk),.visible(v1),.x(x),.y(y),.text(note_name(white_note(2))),.pixel(font_pixels[23]));
    text_cell #(.LENGTH(2),.OX(442),.OY(548),.SCALE(1)) text_24(.clk(clk),.visible(v1),.x(x),.y(y),.text(note_name(white_note(3))),.pixel(font_pixels[24]));
    text_cell #(.LENGTH(2),.OX(566),.OY(548),.SCALE(1)) text_25(.clk(clk),.visible(v1),.x(x),.y(y),.text(note_name(white_note(4))),.pixel(font_pixels[25]));
    text_cell #(.LENGTH(2),.OX(690),.OY(548),.SCALE(1)) text_26(.clk(clk),.visible(v1),.x(x),.y(y),.text(note_name(white_note(5))),.pixel(font_pixels[26]));
    text_cell #(.LENGTH(2),.OX(814),.OY(548),.SCALE(1)) text_27(.clk(clk),.visible(v1),.x(x),.y(y),.text(note_name(white_note(6))),.pixel(font_pixels[27]));
    text_cell #(.LENGTH(2),.OX(938),.OY(548),.SCALE(1)) text_28(.clk(clk),.visible(v1),.x(x),.y(y),.text(note_name(white_note(7))),.pixel(font_pixels[28]));
endmodule
