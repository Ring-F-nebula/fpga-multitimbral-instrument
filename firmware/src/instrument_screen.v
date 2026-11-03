// Registered RGB888 output, 1024x600, 52.5 MHz. Touch targets use ui_layout.vh.
module instrument_screen #(parameter integer SHOW_FSR=0,parameter integer PANEL_UI=0)(input clk,audio_clk,sample_tick,
    input fsr_ready,fsr_fault,fsr_calibrating,input [13:0] fsr_peak,input [15:0] fsr_keys,
    input [13:0] fsr_delta,fsr_threshold,input [15:0] fsr_cal_mask,
    input [255:0] performance_info,input [2:0] panel_page,input [127:0] fx_params,input signed [8:0] panel_bend,input [3:0] selected_pad,
    input [13:0] selected_raw,selected_baseline,selected_threshold,input [8:0] selected_gain,
    input [223:0] fsr_pressures,input [15:0] bt_rx_count,input signed [10:0] game_position,
    input signed [15:0] pcm,input auto_mode,stopped,
    input game_page,game_running,game_finished,
    input [15:0] game_score,game_keys,game_cue,
    input [5:0] game_combo,game_max,game_hits,game_misses,game_progress,
    input [9:0] game_wrong,input [2:0] game_feedback,input [1:0] game_countdown,
    input [3:0] game_target,game_next,
    input [1:0] instrument,touch_chip,
    input [2:0] plot_mode,
    input [15:0] live_keys,
    input [3:0] volume,attack_sel,decay_sel,release_sel,
    input [7:0] sustain_level,
    input touch_online,cursor_down,
    input [10:0] cursor_x,input [9:0] cursor_y,
    input [2:0] orientation,finger_count,
    input [15:0] touch_errors,
    input [7:0] touch_raw_status,
    input [3:0] touch_raw_count,
    input [15:0] touch_report_count,
    input [11:0] touch_raw_x,touch_raw_y,touch_max_x,touch_max_y,
    output wire [7:0] r,g,b,
    output wire pclk,bl,lcd_reset,
    output reg hsync=0,vsync=0,de=0);
    `include "ui_layout.vh"
    wire [23:0] panel_color;
    wire [76:0] font_pixels;
    `include "ui_font.vh"
    localparam HTOTAL=1344,VTOTAL=635,HSTART=308,VSTART=23;
    reg [10:0] h=0;
    reg [9:0] v=0;
    reg [21:0] boot=0;
    always @(posedge clk) begin
        if(h==HTOTAL-1) begin h<=0; if(v==VTOTAL-1) v<=0; else v<=v+1'b1; end
        else h<=h+1'b1;
        if(boot!=22'h3fffff) boot<=boot+1'b1;
    end
    assign pclk=~clk;
    assign lcd_reset=boot>=1048576;
    assign bl=boot>=2097152;
    wire raster_visible=(h>=HSTART && h<HSTART+1024 && v>=VSTART && v<VSTART+600 && lcd_reset);
    wire [10:0] raster_x=h-HSTART;
    wire [9:0] raster_y=v-VSTART;
    // Pipeline the coordinate/hit decoder separately from the font/color
    // renderer; division for string/key indices must not feed a font lookup
    // and the entire RGB priority tree in one 52.5 MHz cycle.
    (* syn_preserve=1, syn_keep=1 *) reg [10:0] x=0;
    (* syn_preserve=1, syn_keep=1 *) reg [9:0] y=0;
    reg visible=0,hs1=0,vs1=0;
    reg hs2=0,vs2=0,de2=0;
    reg hs3=0,vs3=0,de3=0;
    reg hs4=0,vs4=0,de4=0;
    always @(posedge clk)begin hs4<=hs3;vs4<=vs3;de4<=de3;end
    reg [23:0] rgb_q=0;
    reg [23:0] base_pre=0;
    reg graph_pre=0,axis_pre=0,cursor_pre=0,analyzer_pre=0,visible_pre=0,hs_pre=0,vs_pre=0;
    reg [7:0] graph_y_pre=0;
    reg [2:0] bar_x_pre=0;
    reg graph_pixel_pre=0;
    reg [7:0] wave_low_d=60,wave_high_d=60;
    reg [6:0] spectrum_height_d=0;
    wire graph_region=visible && x>=512 && y>=128 && y<352;
    wire [10:0] graph_x=PANEL_UI?x-152:x-512;
    // Three native views share one plot: waveform, FFT, or actual PCM XY.
    wire [5:0] spectrum_address=graph_x[8:3];
    wire [9:0] graph_y=y-128;
    wire [10:0] native_xy_x=x-280;
    wire [9:0] native_xy_y=y-224;
    wire [14:0] graph_address=PANEL_UI?{native_xy_y[6:0],native_xy_x[7:0]}:{graph_y[7:1],graph_x[8:1]};
    wire graph_pixel,graph_valid;
    wire [1:0] xy_mode=PANEL_UI?2'd0:(plot_mode==0 ? 2'd0 : plot_mode-1'b1);
    wire [7:0] wave_low,wave_high;
    wire [6:0] spectrum_height;
    wire analyzer_valid;
    audio_analyzer analyzer(.clk(clk),.audio_clk(audio_clk),.sample_tick(sample_tick),.pcm(pcm),
        .frame_blank(h==0 && v==623),.wave_address(graph_x[8:1]),.band_address(spectrum_address),
        .wave_low(wave_low),.wave_high(wave_high),.spectrum_height(spectrum_height),
        .display_valid(analyzer_valid));
    xy_scope scope(.clk(clk),.audio_clk(audio_clk),.sample_tick(sample_tick),.pcm(pcm),
        .plot_mode(xy_mode),.frame_blank(h==0 && v==623),
        .read_address(graph_address),.pixel(graph_pixel),.display_valid(graph_valid));
    // Snapshot UI values once per frame; coordinates/notes cannot tear mid-label.
    reg mode_q=0,online_q=0,cursor_q=0,game_page_q=0,stopped_q=0;
    reg [1:0] inst_q=0,chip_q=0;
    reg [2:0] plot_q=0;
    reg [15:0] keys_q=0,errors_q=0;
    reg [3:0] vol_q=8,a_q=2,d_q=5,r_q=5;
    reg [7:0] s_q=160;
    reg [2:0] orient_q=0,fingers_q=0;
    reg [10:0] cx_q=0;
    reg [9:0] cy_q=0;
    reg [7:0] status_q=0;
    reg [3:0] raw_count_q=0;
    reg [15:0] reports_q=0;
    reg [11:0] raw_x_q=0,raw_y_q=0,max_x_q=0,max_y_q=0;
    (* async_reg="true" *) reg [1:0] fsr_ready_sync=0,fsr_fault_sync=0;
    (* async_reg="true" *) reg [1:0] fsr_cal_sync=0;
    reg [13:0] fsr_peak_meta=0,fsr_peak_sync=0,fsr_peak_q=0;
    reg [15:0] fsr_keys_meta=0,fsr_keys_sync=0,fsr_keys_q=0;
    reg fsr_ready_q=0,fsr_fault_q=0,fsr_cal_q=0;
    reg [43:0] diag_meta=0,diag_sync=0,diag_q=0;
    always @(posedge clk) begin
        fsr_ready_sync<={fsr_ready_sync[0],fsr_ready};
        fsr_fault_sync<={fsr_fault_sync[0],fsr_fault};
        fsr_cal_sync<={fsr_cal_sync[0],fsr_calibrating};
        diag_meta<={fsr_cal_mask,fsr_threshold,fsr_delta};diag_sync<=diag_meta;
        fsr_peak_meta<=fsr_peak; fsr_peak_sync<=fsr_peak_meta;
        fsr_keys_meta<=fsr_keys; fsr_keys_sync<=fsr_keys_meta;
    end
    always @(posedge clk) if(h==0 && v==0) begin
        diag_q<=diag_sync;
        mode_q<=auto_mode; inst_q<=instrument; plot_q<=plot_mode;game_page_q<=game_page;stopped_q<=stopped;
        chip_q<=touch_chip; online_q<=touch_online; keys_q<=live_keys;
        vol_q<=volume; a_q<=attack_sel; d_q<=decay_sel; r_q<=release_sel; s_q<=sustain_level;
        cursor_q<=cursor_down; cx_q<=cursor_x; cy_q<=cursor_y;
        orient_q<=orientation; fingers_q<=finger_count; errors_q<=touch_errors;
        status_q<=touch_raw_status; raw_count_q<=touch_raw_count; reports_q<=touch_report_count;
        raw_x_q<=touch_raw_x; raw_y_q<=touch_raw_y; max_x_q<=touch_max_x; max_y_q<=touch_max_y;
        fsr_peak_q<=fsr_peak_sync; fsr_keys_q<=fsr_keys_sync;
        fsr_ready_q<=fsr_ready_sync[1]; fsr_fault_q<=fsr_fault_sync[1];
        fsr_cal_q<=fsr_cal_sync[1];
    end
    function [7:0] digit;
        input [15:0] n;
        begin digit=8'd48+n%10; end
    endfunction
    function [31:0] dec4;
        input [15:0] n;
        begin dec4={digit(n/1000),digit(n/100),digit(n/10),digit(n)}; end
    endfunction
    function [7:0] hex_digit;
        input [3:0] n;
        begin hex_digit=n<10?8'd48+n:8'd65+n-10; end
    endfunction
    function [23:0] dec3;
        input [15:0] n;
        begin dec3={digit(n/100),digit(n/10),digit(n)}; end
    endfunction
    function [15:0] ms;
        input [3:0] sel;
        begin case(sel)
            0:ms=1;1:ms=2;2:ms=5;3:ms=10;4:ms=20;
            5:ms=50;6:ms=100;7:ms=200;8:ms=500;default:ms=1000;
        endcase end
    endfunction
    function [31:0] note_name;
        input [4:0] n;
        input [1:0] inst;
        begin
            note_name="--  ";
            if(inst==1) case(n)
                0:note_name="E2  ";1:note_name="A2  ";2:note_name="D3  ";
                3:note_name="G3  ";4:note_name="B3  ";5:note_name="E4  ";
                6:note_name="F#2 ";7:note_name="B2  ";8:note_name="E3  ";
                9:note_name="A3  ";10:note_name="C#4 ";11:note_name="F#4 ";
                default:note_name="HIGH";
            endcase
            else case(n)
                0:note_name="C4  ";1:note_name="C#4 ";2:note_name="D4  ";3:note_name="D#4 ";
                4:note_name="E4  ";5:note_name="F4  ";6:note_name="F#4 ";7:note_name="G4  ";
                8:note_name="G#4 ";9:note_name="A4  ";10:note_name="A#4 ";11:note_name="B4  ";
                12:note_name="C5  ";13:note_name="C#5 ";14:note_name="D5  ";15:note_name="D#5 ";
            endcase
        end
    endfunction
    function [63:0] drum_name;
        input [4:0] n;
        begin case(n)
            0:drum_name="KICK    ";1:drum_name="SNARE   ";2:drum_name="C.HAT   ";
            3:drum_name="O.HAT   ";4:drum_name="LOW TOM ";5:drum_name="CRASH   ";
            default:drum_name="--      ";
        endcase end
    endfunction
    function [4:0] white_note;
        input integer i;
        begin case(i)
            0:white_note=0;1:white_note=2;2:white_note=4;3:white_note=5;
            4:white_note=7;5:white_note=9;6:white_note=11;default:white_note=12;
        endcase end
    endfunction
    // Decimal conversion is independent of the pixel path. These registers
    // settle during vertical blank after the once-per-frame status snapshot.
    reg [31:0] a_text="0005",d_text="0050",r_text="0050";
    reg [23:0] s_text="160";
    wire [23:0] error_text;
    reg [15:0] volume_text="08";
    reg [7:0] finger_text="0",orientation_text="0";
    reg [15:0] status_text="00";
    reg [7:0] raw_count_text="0";
    wire [31:0] report_text,error_decimal;
    assign error_text=error_decimal[23:0];
    status_decimal report_digits(.clk(clk),.value(reports_q),.text(report_text));
    status_decimal error_digits(.clk(clk),.value(errors_q),.text(error_decimal));
    reg [31:0] raw_x_text="0000",raw_y_text="0000",max_x_text="0000",max_y_text="0000";
    reg [31:0] fsr_peak_text="0000",fsr_keys_text="0000";
    reg [31:0] delta_text="0000",threshold_text="0000",cal_mask_text="0000";
    always @(posedge clk) begin
        a_text<=dec4(ms(a_q));d_text<=dec4(ms(d_q));r_text<=dec4(ms(r_q));
        s_text<=dec3(s_q);
        volume_text<={digit(vol_q/10),digit(vol_q)};
        finger_text<=digit(fingers_q);orientation_text<=digit(orient_q);
        status_text<={hex_digit(status_q[7:4]),hex_digit(status_q[3:0])};
        raw_count_text<=hex_digit(raw_count_q);
        raw_x_text<=dec4(raw_x_q); raw_y_text<=dec4(raw_y_q);
        max_x_text<=dec4(max_x_q); max_y_text<=dec4(max_y_q);
        delta_text<={hex_digit({2'b0,diag_q[13:12]}),hex_digit(diag_q[11:8]),hex_digit(diag_q[7:4]),hex_digit(diag_q[3:0])};
        threshold_text<={hex_digit({2'b0,diag_q[27:26]}),hex_digit(diag_q[25:22]),hex_digit(diag_q[21:18]),hex_digit(diag_q[17:14])};
        cal_mask_text<={hex_digit(diag_q[43:40]),hex_digit(diag_q[39:36]),hex_digit(diag_q[35:32]),hex_digit(diag_q[31:28])};
        fsr_peak_text<={hex_digit({2'b0,fsr_peak_q[13:12]}),hex_digit(fsr_peak_q[11:8]),hex_digit(fsr_peak_q[7:4]),hex_digit(fsr_peak_q[3:0])};
        fsr_keys_text<={hex_digit(fsr_keys_q[15:12]),hex_digit(fsr_keys_q[11:8]),hex_digit(fsr_keys_q[7:4]),hex_digit(fsr_keys_q[3:0])};
    end
    reg [4:0] first_note;
    reg [4:0] hit_note=31;
    reg [3:0] action=0;
    reg [23:0] color,base_q=0;
    // Keep each dynamic diagnostic label in its own registered group. A
    // combined multi-line font OR tree exceeded the 52.5MHz pixel budget.
    reg [31:0] ink_groups,ink_q=0;
    reg dark_ink,dark_ink_q=0,black_key,axis_pixel,graph_q=0,axis_q=0,cursor_pixel,cursor_pixel_q=0;
    reg [7:0] graph_y_q=0;
    reg [2:0] bar_x_q=0;
    reg analyzer_q=0;
    integer i;
    always @(posedge clk) begin
        x<=raster_x; y<=raster_y; visible<=raster_visible;
        hs1<=h>=148; vs1<=v>=3;
        hit_note<=music_key_at(inst_q,raster_x,raster_y);
        action<=action_at(raster_x,raster_y);
    end
    always @* begin
        first_note=31;
        for(i=15;i>=0;i=i-1) if(keys_q[i]) first_note=i[4:0];
        black_key=(hit_note==1 || hit_note==3 || hit_note==6 || hit_note==8 || hit_note==10) && y<500;
        color=24'h0b1421; ink_groups=0; dark_ink=0;
        ink_groups[15]=SHOW_FSR && (font_pixels[71] || font_pixels[72] || font_pixels[73] || font_pixels[74] || font_pixels[75] || font_pixels[76]);
        axis_pixel=graph_region && (graph_x==256 || graph_y==112 ||
            graph_x[6:0]==0 || graph_y[5:0]==0);
        if(y<48) color=24'h12283b;
        if(action>=1 && action<=3) color=(inst_q==action-1)?24'h267f83:24'h20364b;
        if(action==4) color=24'h823a4a;
        if(action==5) color=mode_q?24'hb27926:24'h20364b;
        if(action==6) color=!mode_q?24'h267f83:24'h20364b;
        if(action==7 || action==8) color=24'h28556a;
        if(action==9 || action==10) color=24'h28556a;
        if(y>=104 && y<352 && x>=16 && x<496) color=24'h132438;
        if(action==7 || action==8) color=24'h28556a;
        if(x>=16 && x<32 && y>=116 && y<132) color=online_q?24'h57e3a8:24'he7616b;
        if(y>=376 && y<592 && x>=16 && x<1008) begin
            if(inst_q==0) begin
                color=black_key?24'h182232:24'he6edf0;
                if(hit_note<16 && keys_q[hit_note]) color=black_key?24'h927ce8:24'h64cfca;
                for(i=0;i<8;i=i+1)
                    if(x==16+i*124 || x==17+i*124) color=24'h192a3a;
                if(y>=588) color=24'h192a3a;
            end else if(inst_q==1) begin
                color=24'h49392c;
                if(hit_note<16 && keys_q[hit_note]) color=24'h3c837b;
                if(x>=508 && x<516) color=24'hb7c6ca;
                for(i=0;i<6;i=i+1)
                    if(y>=393+i*36 && y<395+i*36) color=24'hd8c28d;
            end else if(hit_note<6) begin
                color=keys_q[hit_note]?24'he6ba67:(hit_note<3?24'h25536c:24'h594371);
            end
        end
        // All text uses a common synthesizable font renderer.
        ink_groups[0]=font_pixels[0] ||
            font_pixels[1] ||
            font_pixels[2] || font_pixels[3] ||
            font_pixels[4] || font_pixels[5] ||
            font_pixels[6] || font_pixels[7];
        ink_groups[1]=font_pixels[8];
        ink_groups[16]=font_pixels[9];
        ink_groups[17]=font_pixels[10];
        ink_groups[2]=font_pixels[11] ||
           font_pixels[12] ||
           font_pixels[13] || font_pixels[14];
        ink_groups[3]=font_pixels[15];
        ink_groups[31]=font_pixels[16];
        ink_groups[4]=font_pixels[17];
        ink_groups[29]=font_pixels[18];
        ink_groups[30]=font_pixels[19];
        ink_groups[18]=font_pixels[20];
        ink_groups[24]=font_pixels[21];
        ink_groups[25]=font_pixels[22];
        ink_groups[19]=font_pixels[23];
        ink_groups[26]=font_pixels[24];
        ink_groups[27]=font_pixels[25];
        ink_groups[28]=font_pixels[26];
        ink_groups[20]=font_pixels[27];
        if(inst_q==2) begin
            ink_groups[5]=font_pixels[28];
        end else ink_groups[5]=font_pixels[29];
        ink_groups[6]=font_pixels[30];
        ink_groups[22]=font_pixels[31];
        ink_groups[23]=font_pixels[32];
        ink_groups[21]=plot_q==0 && (font_pixels[33] ||
            font_pixels[34] ||
            font_pixels[35] || font_pixels[36] ||
            font_pixels[37]);
        if(inst_q==0) begin
            if(font_pixels[38]) dark_ink=1;
            if(font_pixels[39]) dark_ink=1;
            if(font_pixels[40]) dark_ink=1;
            if(font_pixels[41]) dark_ink=1;
            if(font_pixels[42]) dark_ink=1;
            if(font_pixels[43]) dark_ink=1;
            if(font_pixels[44]) dark_ink=1;
            if(font_pixels[45]) dark_ink=1;
            ink_groups[7]=font_pixels[46] || font_pixels[47] ||
               font_pixels[48] || font_pixels[49] ||
               font_pixels[50];
        end else if(inst_q==1) begin
            ink_groups[8]=font_pixels[51] || font_pixels[52];
            ink_groups[9]=font_pixels[53] || font_pixels[54];
            ink_groups[10]=font_pixels[55] || font_pixels[56];
            ink_groups[11]=font_pixels[57] || font_pixels[58];
            ink_groups[12]=font_pixels[59] || font_pixels[60];
            ink_groups[13]=font_pixels[61] || font_pixels[62];
            ink_groups[14]=font_pixels[63] || font_pixels[64];
        end else begin
            ink_groups[8]=font_pixels[65];
            ink_groups[9]=font_pixels[66];
            ink_groups[10]=font_pixels[67];
            ink_groups[11]=font_pixels[68];
            ink_groups[12]=font_pixels[69];
            ink_groups[13]=font_pixels[70];
        end
        cursor_pixel=cursor_q && ((x>=cx_q && x<=cx_q+2 && y+8>=cy_q && y<=cy_q+8) ||
            (y>=cy_q && y<=cy_q+2 && x+8>=cx_q && x<=cx_q+8));
        if(SHOW_FSR && y>=582) color=24'h0b1421;
        if(!visible) color=0;
    end
    always @(posedge clk) begin
        base_pre<=color;graph_pre<=graph_region;axis_pre<=axis_pixel;
        graph_y_pre<=graph_y[7:0];bar_x_pre<=graph_x[2:0];analyzer_pre<=plot_q==0;
        visible_pre<=visible;cursor_pre<=cursor_pixel && visible;hs_pre<=hs1;vs_pre<=vs1;
        base_q<=base_pre;graph_q<=graph_pre;axis_q<=axis_pre;
        graph_y_q<=graph_y_pre;bar_x_q<=bar_x_pre;analyzer_q<=analyzer_pre;
        ink_q<=ink_groups & {32{visible_pre}};dark_ink_q<=dark_ink && visible_pre;
        cursor_pixel_q<=cursor_pre;hs2<=hs_pre;vs2<=vs_pre;de2<=visible_pre;
        graph_pixel_pre<=graph_pixel;
        wave_low_d<=wave_low;wave_high_d<=wave_high;spectrum_height_d<=spectrum_height;
    end
    reg [23:0] base2=0;
    reg [31:0] ink2=0;
    reg dark2=0,cursor2=0,graph2=0,axis2=0,analyzer2=0,xy_pixel2=0;
    reg [7:0] graph_y2=0;
    reg [2:0] bar_x2=0;
    // Match the analyzer's registered coordinate conversion. The unchanged
    // XY module has one RAM read cycle, so its pixel gets one matching delay.
    always @(posedge clk) begin
        base2<=base_q;ink2<=ink_q;dark2<=dark_ink_q;cursor2<=cursor_pixel_q;
        graph2<=graph_q;axis2<=axis_q;analyzer2<=analyzer_q;xy_pixel2<=graph_pixel_pre;
        graph_y2<=graph_y_q;bar_x2<=bar_x_q;hs3<=hs2;vs3<=vs2;de3<=de2;
    end
    wire [23:0] ui_color=(|ink2)?24'he9f3f8:(dark2?24'h24384b:base2);
    wire wave_on=analyzer_valid && graph_y2>=wave_low_d && graph_y2<=wave_high_d &&
        graph_y2>=20 && graph_y2<100;
    wire spectrum_on=analyzer_valid && graph_y2>=120 && graph_y2<208 &&
        (208-graph_y2)<=spectrum_height_d && bar_x2<6;
    wire analyzer_axis=(graph_y2==60 || graph_y2==207 || graph_y2==164);
    wire [23:0] analyzer_color=(|ink2)?24'he9f3f8:wave_on?24'h63edc2:
        spectrum_on?(graph_y2<148?24'hffd06a:24'h55baff):
        analyzer_axis?24'h254352:24'h0b1824;
    wire [23:0] final_color=cursor2?24'hff718d:
        (graph2 ? (analyzer2?analyzer_color:xy_pixel2?24'h63edc2:(axis2?24'h254352:24'h0b1824)):ui_color);
    wire [23:0] game_color;
    game_screen game_view(.clk(clk),.frame_start(h==0 && v==0),.visible(raster_visible),
        .raster_x(raster_x),.raster_y(raster_y),.running(game_running),.finished(game_finished),
        .score(game_score),.keys(game_keys),.cue_keys(game_cue),.combo(game_combo),.max_combo(game_max),
        .hits(game_hits),.misses(game_misses),.progress(game_progress),.wrong(game_wrong),
        .feedback(game_feedback),.countdown(game_countdown),.target_note(game_target),.next_note(game_next),
        .volume(volume),.pixel_color(game_color));
    // Register the final color, including waveform gain/height comparisons,
    // before the panel's opposite clock edge. Delay sync/DE by the same cycle.
    always @(posedge clk) begin
        rgb_q<=PANEL_UI?panel_color:game_page_q?game_color:final_color;hsync<=PANEL_UI?hs4:hs3;vsync<=PANEL_UI?vs4:vs3;de<=PANEL_UI?de4:de3;
    end
    generate if(PANEL_UI)begin: native_panel
    panel_renderer panel(.performance_info(performance_info),.clk(clk),.frame_start(h==0 && v==0),.visible(visible),.x(x),.y(y),
        .page(panel_page),.fx_params(fx_params),.bend_cents(panel_bend),.instrument(instrument),.stopped(stopped),.auto_mode(auto_mode),
        .game_page(game_page),.game_running(game_running),.game_finished(game_finished),
        .volume(volume),.attack_sel(attack_sel),.decay_sel(decay_sel),.release_sel(release_sel),.sustain_level(sustain_level),
        .live_keys(live_keys),.fsr_keys(fsr_keys),.fsr_cal_mask(fsr_cal_mask),.fsr_ready(fsr_ready),.fsr_fault(fsr_fault),.fsr_calibrating(fsr_calibrating),
        .fsr_peak(fsr_peak),.fsr_delta(fsr_delta),.fsr_threshold(fsr_threshold),.fsr_pressures(fsr_pressures),
        .selected_pad(selected_pad),.selected_raw(selected_raw),.selected_baseline(selected_baseline),.selected_threshold(selected_threshold),.selected_gain(selected_gain),
        .bt_rx_count(bt_rx_count),.touch_errors(touch_errors),.touch_online(touch_online),
        .game_score(game_score),.game_keys(game_keys),.game_cue(game_cue),.game_combo(game_combo),.game_progress(game_progress),
        .game_countdown(game_countdown),.game_target(game_target),.game_feedback(game_feedback),.game_position(game_position),
        .visual_mode(plot_mode[1:0]),.xy_pixel(graph_pixel),.xy_valid(graph_valid),
        .wave_low(wave_low),.wave_high(wave_high),.spectrum_height(spectrum_height),.wave_valid(analyzer_valid),.color(panel_color));
    end else begin assign panel_color=0;end endgenerate
    assign r=rgb_q[23:16]; assign g=rgb_q[15:8]; assign b=rgb_q[7:0];
    // Short independent labels bound each character selector's logic depth.
    // One dynamic 23-character cell failed the 52.5 MHz display timing budget.
    text_cell #(.LENGTH(9),.OX(32),.OY(586),.SCALE(0)) fsr_status_text(
        .clk(clk),.visible(visible),.x(x),.y(y),
        .text({"FSR ",fsr_fault_q?"FAULT":fsr_cal_q?"CALIB":fsr_ready_q?"READY":"WAIT "}),
        .pixel(font_pixels[71]));
    text_cell #(.LENGTH(7),.OX(104),.OY(586),.SCALE(0)) fsr_pressure_text(
        .clk(clk),.visible(visible),.x(x),.y(y),.text({" P ",fsr_peak_text}),.pixel(font_pixels[72]));
    text_cell #(.LENGTH(7),.OX(160),.OY(586),.SCALE(0)) fsr_mask_text(
        .clk(clk),.visible(visible),.x(x),.y(y),.text({" K ",fsr_keys_text}),.pixel(font_pixels[73]));
    text_cell #(.LENGTH(7),.OX(216),.OY(586),.SCALE(0)) fsr_delta_text(
        .clk(clk),.visible(visible),.x(x),.y(y),.text({" D ",delta_text}),.pixel(font_pixels[74]));
    text_cell #(.LENGTH(7),.OX(272),.OY(586),.SCALE(0)) fsr_threshold_text(
        .clk(clk),.visible(visible),.x(x),.y(y),.text({" T ",threshold_text}),.pixel(font_pixels[75]));
    text_cell #(.LENGTH(7),.OX(328),.OY(586),.SCALE(0)) fsr_cal_mask_text(
        .clk(clk),.visible(visible),.x(x),.y(y),.text({" C ",cal_mask_text}),.pixel(font_pixels[76]));
    text_cell #(.LENGTH(18),.OX(16),.OY(8),.SCALE(2)) text_0(.clk(clk),.visible(visible),.x(x),.y(y),.text("FSR16 STREAM3 B   "),.pixel(font_pixels[0]));
    text_cell #(.LENGTH(4),.OX(896),.OY(18),.SCALE(1)) text_1(.clk(clk),.visible(visible),.x(x),.y(y),.text("GAME"),.pixel(font_pixels[1]));
    text_cell #(.LENGTH(5),.OX(72),.OY(69),.SCALE(1)) text_2(.clk(clk),.visible(visible),.x(x),.y(y),.text("PIANO"),.pixel(font_pixels[2]));
    text_cell #(.LENGTH(6),.OX(272),.OY(69),.SCALE(1)) text_3(.clk(clk),.visible(visible),.x(x),.y(y),.text("GUITAR"),.pixel(font_pixels[3]));
    text_cell #(.LENGTH(5),.OX(488),.OY(69),.SCALE(1)) text_4(.clk(clk),.visible(visible),.x(x),.y(y),.text("DRUMS"),.pixel(font_pixels[4]));
    text_cell #(.LENGTH(4),.OX(664),.OY(69),.SCALE(1)) text_5(.clk(clk),.visible(visible),.x(x),.y(y),.text("STOP"),.pixel(font_pixels[5]));
    text_cell #(.LENGTH(4),.OX(792),.OY(69),.SCALE(1)) text_6(.clk(clk),.visible(visible),.x(x),.y(y),.text("AUTO"),.pixel(font_pixels[6]));
    text_cell #(.LENGTH(4),.OX(920),.OY(69),.SCALE(1)) text_7(.clk(clk),.visible(visible),.x(x),.y(y),.text("LIVE"),.pixel(font_pixels[7]));
    text_cell #(.LENGTH(11),.OX(48),.OY(117),.SCALE(1)) text_8(.clk(clk),.visible(visible),.x(x),.y(y),.text(online_q?"TOUCH READY":"TOUCH WAIT "),.pixel(font_pixels[8]));
    text_cell #(.LENGTH(6),.OX(368),.OY(117),.SCALE(1)) text_9(.clk(clk),.visible(visible),.x(x),.y(y),.text(chip_q==1?"FT5446":chip_q==0?"NO I2C":"GT911 "),.pixel(font_pixels[9]));
    text_cell #(.LENGTH(9),.OX(32),.OY(151),.SCALE(1)) text_10(.clk(clk),.visible(visible),.x(x),.y(y),.text(stopped_q?"STOPPED  ":mode_q?"AUTO SONG":"LIVE PLAY"),.pixel(font_pixels[10]));
    text_cell #(.LENGTH(3),.OX(32),.OY(197),.SCALE(1)) text_11(.clk(clk),.visible(visible),.x(x),.y(y),.text("VOL"),.pixel(font_pixels[11]));
    text_cell #(.LENGTH(2),.OX(112),.OY(185),.SCALE(2)) text_12(.clk(clk),.visible(visible),.x(x),.y(y),.text(volume_text),.pixel(font_pixels[12]));
    text_cell #(.LENGTH(1),.OX(308),.OY(197),.SCALE(1)) text_13(.clk(clk),.visible(visible),.x(x),.y(y),.text("-"),.pixel(font_pixels[13]));
    text_cell #(.LENGTH(1),.OX(396),.OY(197),.SCALE(1)) text_14(.clk(clk),.visible(visible),.x(x),.y(y),.text("+"),.pixel(font_pixels[14]));
    text_cell #(.LENGTH(16),.OX(32),.OY(237),.SCALE(1)) text_15(.clk(clk),.visible(visible),.x(x),.y(y),.text({"A ",a_text," D ",d_text," MS"}),.pixel(font_pixels[15]));
    text_cell #(.LENGTH(15),.OX(32),.OY(265),.SCALE(1)) text_16(.clk(clk),.visible(visible),.x(x),.y(y),.text({"S ",s_text," R ",r_text," MS"}),.pixel(font_pixels[16]));
    text_cell #(.LENGTH(9),.OX(32),.OY(297),.SCALE(1)) text_17(.clk(clk),.visible(visible),.x(x),.y(y),.text({"FINGERS ",finger_text}),.pixel(font_pixels[17]));
    text_cell #(.LENGTH(4),.OX(192),.OY(297),.SCALE(1)) text_18(.clk(clk),.visible(visible),.x(x),.y(y),.text({"OR ",orientation_text}),.pixel(font_pixels[18]));
    text_cell #(.LENGTH(7),.OX(272),.OY(297),.SCALE(1)) text_19(.clk(clk),.visible(visible),.x(x),.y(y),.text({"ERR ",error_text}),.pixel(font_pixels[19]));
    text_cell #(.LENGTH(5),.OX(32),.OY(316),.SCALE(0)) text_20(.clk(clk),.visible(visible),.x(x),.y(y),.text({"ST ",status_text}),.pixel(font_pixels[20]));
    text_cell #(.LENGTH(7),.OX(80),.OY(316),.SCALE(0)) text_21(.clk(clk),.visible(visible),.x(x),.y(y),.text({"RAW N ",raw_count_text}),.pixel(font_pixels[21]));
    text_cell #(.LENGTH(7),.OX(144),.OY(316),.SCALE(0)) text_22(.clk(clk),.visible(visible),.x(x),.y(y),.text({"FR ",report_text}),.pixel(font_pixels[22]));
    text_cell #(.LENGTH(7),.OX(32),.OY(328),.SCALE(0)) text_23(.clk(clk),.visible(visible),.x(x),.y(y),.text({"XY ",raw_x_text}),.pixel(font_pixels[23]));
    text_cell #(.LENGTH(4),.OX(96),.OY(328),.SCALE(0)) text_24(.clk(clk),.visible(visible),.x(x),.y(y),.text(raw_y_text),.pixel(font_pixels[24]));
    text_cell #(.LENGTH(8),.OX(136),.OY(328),.SCALE(0)) text_25(.clk(clk),.visible(visible),.x(x),.y(y),.text({"MAX ",max_x_text}),.pixel(font_pixels[25]));
    text_cell #(.LENGTH(4),.OX(208),.OY(328),.SCALE(0)) text_26(.clk(clk),.visible(visible),.x(x),.y(y),.text(max_y_text),.pixel(font_pixels[26]));
    text_cell #(.LENGTH(30),.OX(32),.OY(344),.SCALE(0)) text_27(.clk(clk),.visible(visible),.x(x),.y(y),.text("KEY1: FSR / KEY1+KNOB: FLIP X"),.pixel(font_pixels[27]));
    text_cell #(.LENGTH(8),.OX(224),.OY(151),.SCALE(1)) text_28(.clk(clk),.visible(visible),.x(x),.y(y),.text(drum_name(first_note)),.pixel(font_pixels[28]));
    text_cell #(.LENGTH(4),.OX(272),.OY(151),.SCALE(1)) text_29(.clk(clk),.visible(visible),.x(x),.y(y),.text(mode_q?"SONG":note_name(first_note,inst_q)),.pixel(font_pixels[29]));
    text_cell #(.LENGTH(8),.OX(528),.OY(109),.SCALE(1)) text_30(.clk(clk),.visible(visible),.x(x),.y(y),.text(plot_q==0?"WAVE+FFT":plot_q==1?"AUDIO XY":plot_q==2?"REF 1:1 ":plot_q==3?"REF 1:2 ":"REF 2:3 "),.pixel(font_pixels[30]));
    text_cell #(.LENGTH(4),.OX(912),.OY(109),.SCALE(1)) text_31(.clk(clk),.visible(visible),.x(x),.y(y),.text("NEXT"),.pixel(font_pixels[31]));
    text_cell #(.LENGTH(30),.OX(528),.OY(354),.SCALE(0)) text_32(.clk(clk),.visible(visible),.x(x),.y(y),.text(plot_q==0?"FFT 1024 / LOG FREQ / 44.5HZ  ":plot_q==1?"X PCM / Y PCM DELAY 32 SAMPLES":"REFERENCE SINE / QUADRATURE   "),.pixel(font_pixels[32]));
    text_cell #(.LENGTH(23),.OX(528),.OY(130),.SCALE(0)) text_33(.clk(clk),.visible(visible),.x(x),.y(y),.text("WAVE 22.5MS / AUTO GAIN"),.pixel(font_pixels[33]));
    text_cell #(.LENGTH(8),.OX(528),.OY(238),.SCALE(0)) text_34(.clk(clk),.visible(visible),.x(x),.y(y),.text("SPECTRUM"),.pixel(font_pixels[34]));
    text_cell #(.LENGTH(2),.OX(688),.OY(338),.SCALE(0)) text_35(.clk(clk),.visible(visible),.x(x),.y(y),.text("1K"),.pixel(font_pixels[35]));
    text_cell #(.LENGTH(2),.OX(896),.OY(338),.SCALE(0)) text_36(.clk(clk),.visible(visible),.x(x),.y(y),.text("5K"),.pixel(font_pixels[36]));
    text_cell #(.LENGTH(6),.OX(976),.OY(338),.SCALE(0)) text_37(.clk(clk),.visible(visible),.x(x),.y(y),.text("20K HZ"),.pixel(font_pixels[37]));
    text_cell #(.LENGTH(4),.OX(54),.OY(548),.SCALE(1)) text_38(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(white_note(0),0)),.pixel(font_pixels[38]));
    text_cell #(.LENGTH(4),.OX(178),.OY(548),.SCALE(1)) text_39(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(white_note(1),0)),.pixel(font_pixels[39]));
    text_cell #(.LENGTH(4),.OX(302),.OY(548),.SCALE(1)) text_40(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(white_note(2),0)),.pixel(font_pixels[40]));
    text_cell #(.LENGTH(4),.OX(426),.OY(548),.SCALE(1)) text_41(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(white_note(3),0)),.pixel(font_pixels[41]));
    text_cell #(.LENGTH(4),.OX(550),.OY(548),.SCALE(1)) text_42(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(white_note(4),0)),.pixel(font_pixels[42]));
    text_cell #(.LENGTH(4),.OX(674),.OY(548),.SCALE(1)) text_43(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(white_note(5),0)),.pixel(font_pixels[43]));
    text_cell #(.LENGTH(4),.OX(798),.OY(548),.SCALE(1)) text_44(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(white_note(6),0)),.pixel(font_pixels[44]));
    text_cell #(.LENGTH(4),.OX(922),.OY(548),.SCALE(1)) text_45(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(white_note(7),0)),.pixel(font_pixels[45]));
    text_cell #(.LENGTH(2),.OX(132),.OY(466),.SCALE(0)) text_46(.clk(clk),.visible(visible),.x(x),.y(y),.text("C#"),.pixel(font_pixels[46]));
    text_cell #(.LENGTH(2),.OX(256),.OY(466),.SCALE(0)) text_47(.clk(clk),.visible(visible),.x(x),.y(y),.text("D#"),.pixel(font_pixels[47]));
    text_cell #(.LENGTH(2),.OX(504),.OY(466),.SCALE(0)) text_48(.clk(clk),.visible(visible),.x(x),.y(y),.text("F#"),.pixel(font_pixels[48]));
    text_cell #(.LENGTH(2),.OX(628),.OY(466),.SCALE(0)) text_49(.clk(clk),.visible(visible),.x(x),.y(y),.text("G#"),.pixel(font_pixels[49]));
    text_cell #(.LENGTH(2),.OX(752),.OY(466),.SCALE(0)) text_50(.clk(clk),.visible(visible),.x(x),.y(y),.text("A#"),.pixel(font_pixels[50]));
    text_cell #(.LENGTH(4),.OX(40),.OY(380),.SCALE(1)) text_51(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(0,1)),.pixel(font_pixels[51]));
    text_cell #(.LENGTH(4),.OX(540),.OY(380),.SCALE(1)) text_52(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(6,1)),.pixel(font_pixels[52]));
    text_cell #(.LENGTH(4),.OX(40),.OY(416),.SCALE(1)) text_53(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(1,1)),.pixel(font_pixels[53]));
    text_cell #(.LENGTH(4),.OX(540),.OY(416),.SCALE(1)) text_54(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(7,1)),.pixel(font_pixels[54]));
    text_cell #(.LENGTH(4),.OX(40),.OY(452),.SCALE(1)) text_55(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(2,1)),.pixel(font_pixels[55]));
    text_cell #(.LENGTH(4),.OX(540),.OY(452),.SCALE(1)) text_56(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(8,1)),.pixel(font_pixels[56]));
    text_cell #(.LENGTH(4),.OX(40),.OY(488),.SCALE(1)) text_57(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(3,1)),.pixel(font_pixels[57]));
    text_cell #(.LENGTH(4),.OX(540),.OY(488),.SCALE(1)) text_58(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(9,1)),.pixel(font_pixels[58]));
    text_cell #(.LENGTH(4),.OX(40),.OY(524),.SCALE(1)) text_59(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(4,1)),.pixel(font_pixels[59]));
    text_cell #(.LENGTH(4),.OX(540),.OY(524),.SCALE(1)) text_60(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(10,1)),.pixel(font_pixels[60]));
    text_cell #(.LENGTH(4),.OX(40),.OY(560),.SCALE(1)) text_61(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(5,1)),.pixel(font_pixels[61]));
    text_cell #(.LENGTH(4),.OX(540),.OY(560),.SCALE(1)) text_62(.clk(clk),.visible(visible),.x(x),.y(y),.text(note_name(11,1)),.pixel(font_pixels[62]));
    text_cell #(.LENGTH(12),.OX(240),.OY(362),.SCALE(0)) text_63(.clk(clk),.visible(visible),.x(x),.y(y),.text("OPEN STRINGS"),.pixel(font_pixels[63]));
    text_cell #(.LENGTH(6),.OX(768),.OY(362),.SCALE(0)) text_64(.clk(clk),.visible(visible),.x(x),.y(y),.text("FRET 2"),.pixel(font_pixels[64]));
    text_cell #(.LENGTH(8),.OX(64),.OY(418),.SCALE(1)) text_65(.clk(clk),.visible(visible),.x(x),.y(y),.text(drum_name(0)),.pixel(font_pixels[65]));
    text_cell #(.LENGTH(8),.OX(400),.OY(418),.SCALE(1)) text_66(.clk(clk),.visible(visible),.x(x),.y(y),.text(drum_name(1)),.pixel(font_pixels[66]));
    text_cell #(.LENGTH(8),.OX(736),.OY(418),.SCALE(1)) text_67(.clk(clk),.visible(visible),.x(x),.y(y),.text(drum_name(2)),.pixel(font_pixels[67]));
    text_cell #(.LENGTH(8),.OX(64),.OY(534),.SCALE(1)) text_68(.clk(clk),.visible(visible),.x(x),.y(y),.text(drum_name(3)),.pixel(font_pixels[68]));
    text_cell #(.LENGTH(8),.OX(400),.OY(534),.SCALE(1)) text_69(.clk(clk),.visible(visible),.x(x),.y(y),.text(drum_name(4)),.pixel(font_pixels[69]));
    text_cell #(.LENGTH(8),.OX(736),.OY(534),.SCALE(1)) text_70(.clk(clk),.visible(visible),.x(x),.y(y),.text(drum_name(5)),.pixel(font_pixels[70]));
endmodule
