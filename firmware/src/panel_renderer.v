// Light native 1024x600 interface. Numbers come from actual engine
// state. Font and digit ROMs have two registered read stages; RGB adds one.
module panel_renderer(input clk,frame_start,visible,input [10:0] x,input [9:0] y,
    input [255:0] performance_info,input [2:0] page,input [127:0] fx_params,input signed [8:0] bend_cents,input [1:0] instrument,
    input stopped,auto_mode,game_page,game_running,game_finished,
    input [3:0] volume,attack_sel,decay_sel,release_sel,input [7:0] sustain_level,
    input [15:0] live_keys,fsr_keys,fsr_cal_mask,input fsr_ready,fsr_fault,fsr_calibrating,
    input [13:0] fsr_peak,fsr_delta,fsr_threshold,input [223:0] fsr_pressures,
    input [3:0] selected_pad,input [13:0] selected_raw,selected_baseline,selected_threshold,input [8:0] selected_gain,
    input [15:0] bt_rx_count,touch_errors,input touch_online,
    input [15:0] game_score,game_keys,game_cue,input [5:0] game_combo,game_progress,
    input [1:0] game_countdown,input [3:0] game_target,input [2:0] game_feedback,
    input signed [10:0] game_position,
    input [1:0] visual_mode,input xy_pixel,xy_valid,
    input [7:0] wave_low,wave_high,input [6:0] spectrum_height,input wave_valid,
    output reg [23:0] color=0) /* synthesis syn_srlstyle="registers" */;
    // Source states are stable for many clocks. Double synchronization followed
    // by a frame snapshot avoids mid-frame numeric/button changes.
    localparam STATE_BITS=914;
    wire [STATE_BITS-1:0] source_state={performance_info,visual_mode,bend_cents,page,fx_params,instrument,stopped,auto_mode,game_page,game_running,game_finished,
        volume,attack_sel,decay_sel,release_sel,sustain_level,live_keys,fsr_keys,fsr_cal_mask,
        fsr_ready,fsr_fault,fsr_calibrating,fsr_peak,fsr_delta,fsr_threshold,fsr_pressures,
        selected_pad,selected_raw,selected_baseline,selected_threshold,selected_gain,
        bt_rx_count,touch_errors,touch_online,game_score,game_keys,game_cue,game_combo,game_progress,
        game_countdown,game_target,game_feedback,game_position};
    (* async_reg="true" *) reg [STATE_BITS-1:0] meta=0,sync=0;
    reg [STATE_BITS-1:0] state=0;
    always @(posedge clk)begin meta<=source_state;sync<=meta;if(frame_start)state<=sync;end
    wire [2:0] page_q;wire [127:0] fx_q;wire [1:0] instrument_q;
    wire stopped_q,auto_q,game_q,running_q,finished_q,ready_q,fault_q,calibrating_q,online_q;
    wire [3:0] volume_q,attack_q,decay_q,release_q,selected_q,target_q;
    wire [7:0] sustain_q;wire [15:0] live_q,fsr_keys_q,cal_q,bt_q,errors_q,score_q,game_keys_q,cue_q;
    wire [13:0] peak_q,delta_q,threshold_q,raw_q,baseline_q,pad_threshold_q;
    wire [223:0] pressures_q;wire [8:0] gain_q;wire [5:0] combo_q,progress_q;
    wire [1:0] countdown_q;wire [2:0] feedback_q;wire signed [10:0] position_q;
    wire signed [8:0] bend_q;
    wire [1:0] view_q;
    wire [255:0] info_q;wire bank_q=info_q[38],hold_q=info_q[39];
    `include "guitar_chords.vh"
    wire [5:0] guitar_string_active,guitar_string_muted;
    genvar gs;generate for(gs=0;gs<6;gs=gs+1)begin: guitar_display_strings
        wire [7:0] note=guitar_note(info_q[228:226],gs);
        assign guitar_string_muted[gs]=note==255;
        assign guitar_string_active[gs]=note!=255&&info_q[note-8'd40];
    end endgenerate
    `include "panel_enable.vh"
    `include "adsr_presets.vh"
    // Match actual engine registers; edits from LCD, USB or Bluetooth all
    // clear/reselect the highlight without a separate shadow preset state.
    reg [2:0] adsr_match_q=0;
    genvar ap;
    generate for(ap=0;ap<3;ap=ap+1)begin: adsr_preset_matches
        always @(posedge clk)adsr_match_q[ap]<=
            {4'd0,attack_q}==adsr_preset_value(ap,0)&&
            {4'd0,decay_q}==adsr_preset_value(ap,1)&&
            sustain_q==adsr_preset_value(ap,2)&&
            {4'd0,release_q}==adsr_preset_value(ap,3);
    end endgenerate
    reg [159:0] enabled_q={160{1'b1}};
    genvar en;
    generate for(en=0;en<160;en=en+1)begin: control_availability
        localparam [7:0] ACTION=en;
        always @(posedge clk)enabled_q[en]<=panel_enabled(ACTION,instrument_q,volume_q,attack_q,decay_q,release_q,sustain_q,fx_q,info_q,page_q);
    end endgenerate
    reg [1:0] record_button_state=0;reg [2:0] event_label_state=0,audio_label_state=0,practice_label_state=0;
    reg audition_active=0;reg [10:0] event_progress_end=152,audio_progress_end=600;
    reg [2:0] matrix_status=0,matrix_feedback=0;
    always @(posedge clk)begin
        record_button_state<=(info_q[82]||info_q[217]||info_q[239])?1:info_q[83]?2:0;
        event_label_state<=info_q[83]?3:info_q[82]?(info_q[238]?2:1):info_q[125]?5:info_q[93:84]==0?0:info_q[238]?4:6;
        audio_label_state<=info_q[239]?1:info_q[217]?2:info_q[218]?3:(info_q[219]||(|info_q[216:200]))?4:0;
        practice_label_state<=(info_q[80:79]==3&&!info_q[108])?4:info_q[221]?(info_q[81]?2:1):info_q[222]?3:0;
        audition_active<=info_q[{3'd0,info_q[106:102]}];
        matrix_status<=(info_q[80:79]==3&&(!info_q[108]||!info_q[231]))?6:calibrating_q?4:!ready_q?5:finished_q?3:running_q?(info_q[81]?2:1):0;
        matrix_feedback<=!running_q||info_q[81]||!ready_q?0:feedback_q<=5?feedback_q:0;
        event_progress_end<=11'd152+(({1'b0,info_q[93:84]}*3)>>2);
        audio_progress_end<=11'd600+({3'd0,info_q[219],info_q[216:210]}*3);
    end
    assign {info_q,view_q,bend_q,page_q,fx_q,instrument_q,stopped_q,auto_q,game_q,running_q,finished_q,
        volume_q,attack_q,decay_q,release_q,sustain_q,live_q,fsr_keys_q,cal_q,
        ready_q,fault_q,calibrating_q,peak_q,delta_q,threshold_q,pressures_q,
        selected_q,raw_q,baseline_q,pad_threshold_q,gain_q,
        bt_q,errors_q,online_q,score_q,game_keys_q,cue_q,combo_q,progress_q,countdown_q,target_q,feedback_q,position_q}=state;
    function [15:0] envelope_ms;input [3:0] n;begin case(n)
        0:envelope_ms=1;1:envelope_ms=2;2:envelope_ms=5;3:envelope_ms=10;4:envelope_ms=20;
        5:envelope_ms=50;6:envelope_ms=100;7:envelope_ms=200;8:envelope_ms=500;default:envelope_ms=1000;
    endcase end endfunction
    function [15:0] glide_ms;input [7:0] n;begin case(n)
        0:glide_ms=10;1:glide_ms=20;2:glide_ms=40;3:glide_ms=80;4:glide_ms=120;
        5:glide_ms=200;6:glide_ms=300;7:glide_ms=500;8:glide_ms=750;default:glide_ms=1000;
    endcase end endfunction
    function [15:0] decay_ms;input [7:0] n;begin case(n)
        0:decay_ms=300;1:decay_ms=500;2:decay_ms=800;3:decay_ms=1200;4:decay_ms=1600;
        5:decay_ms=2400;6:decay_ms=3200;7:decay_ms=4800;8:decay_ms=6400;default:decay_ms=10000;
    endcase end endfunction
    function [15:0] percent;input [8:0] n;begin percent=(n*16'd100+16'd128)>>8;end endfunction
    wire [15:0] values[0:63];
    assign values[0]=volume_q;assign values[1]=envelope_ms(attack_q);assign values[2]=envelope_ms(decay_q);
    assign values[3]=percent({1'b0,sustain_q});assign values[4]=envelope_ms(release_q);
    assign values[5]=glide_ms(fx_q[87:80]);assign values[6]=fx_q[95:88];assign values[7]=fx_q[103:96];
    wire negative_bend=fx_q[6]?fx_q[119:112]<100:bend_q<0;
    wire positive_bend=fx_q[6]?fx_q[119:112]>100:bend_q>0;
    assign values[8]=fx_q[6]?(fx_q[119:112]>=100?(fx_q[119:112]-16'd100)*2:(16'd100-fx_q[119:112])*2):(bend_q<0?-bend_q:bend_q);
    assign values[9]=fx_q[111:104]==32?16'd0:fx_q[111:104]+16'd1;assign values[10]=fx_q[15:8]*16'd10;
    assign values[11]=percent({1'b0,fx_q[23:16]});assign values[12]=percent({1'b0,fx_q[31:24]});
    assign values[13]=fx_q[39:32];assign values[14]=fx_q[47:40];assign values[15]=percent({1'b0,fx_q[55:48]});
    assign values[16]=fx_q[63:56];assign values[17]=decay_ms(fx_q[71:64]);assign values[18]=percent({1'b0,fx_q[79:72]});
    function [15:0] throughput_k;input [5:0] n;begin case(n)
        6'd0:throughput_k=16'd0;
        6'd1:throughput_k=16'd46;
        6'd2:throughput_k=16'd91;
        6'd3:throughput_k=16'd137;
        6'd4:throughput_k=16'd182;
        6'd5:throughput_k=16'd228;
        6'd6:throughput_k=16'd273;
        6'd7:throughput_k=16'd319;
        6'd8:throughput_k=16'd365;
        6'd9:throughput_k=16'd410;
        6'd10:throughput_k=16'd456;
        6'd11:throughput_k=16'd501;
        6'd12:throughput_k=16'd547;
        6'd13:throughput_k=16'd592;
        6'd14:throughput_k=16'd638;
        6'd15:throughput_k=16'd684;
        6'd16:throughput_k=16'd729;
        6'd17:throughput_k=16'd775;
        6'd18:throughput_k=16'd820;
        6'd19:throughput_k=16'd866;
        6'd20:throughput_k=16'd911;
        6'd21:throughput_k=16'd957;
        6'd22:throughput_k=16'd1003;
        6'd23:throughput_k=16'd1048;
        6'd24:throughput_k=16'd1094;
        6'd25:throughput_k=16'd1139;
        6'd26:throughput_k=16'd1185;
        6'd27:throughput_k=16'd1230;
        6'd28:throughput_k=16'd1276;
        6'd29:throughput_k=16'd1322;
        6'd30:throughput_k=16'd1367;
        6'd31:throughput_k=16'd1413;
        6'd32:throughput_k=16'd1458;
        6'd33:throughput_k=16'd1504;default:throughput_k=0;endcase end endfunction
    assign values[19]=info_q[37:32];assign values[20]=45573;assign values[21]=throughput_k(info_q[37:32]);
    function [15:0] proof_frequency;input [4:0] voice;begin case(voice)
        5'd0:proof_frequency=16'd356;
        5'd1:proof_frequency=16'd445;
        5'd2:proof_frequency=16'd534;
        5'd3:proof_frequency=16'd623;
        5'd4:proof_frequency=16'd712;
        5'd5:proof_frequency=16'd801;
        5'd6:proof_frequency=16'd890;
        5'd7:proof_frequency=16'd979;
        5'd8:proof_frequency=16'd1068;
        5'd9:proof_frequency=16'd1157;
        5'd10:proof_frequency=16'd1246;
        5'd11:proof_frequency=16'd1335;
        5'd12:proof_frequency=16'd1424;
        5'd13:proof_frequency=16'd1513;
        5'd14:proof_frequency=16'd1602;
        5'd15:proof_frequency=16'd1691;
        5'd16:proof_frequency=16'd1780;
        5'd17:proof_frequency=16'd1869;
        5'd18:proof_frequency=16'd1958;
        5'd19:proof_frequency=16'd2047;
        5'd20:proof_frequency=16'd2136;
        5'd21:proof_frequency=16'd2225;
        5'd22:proof_frequency=16'd2314;
        5'd23:proof_frequency=16'd2403;
        5'd24:proof_frequency=16'd2492;
        5'd25:proof_frequency=16'd2581;
        5'd26:proof_frequency=16'd2670;
        5'd27:proof_frequency=16'd2759;
        5'd28:proof_frequency=16'd2848;
        5'd29:proof_frequency=16'd2937;
        5'd30:proof_frequency=16'd3026;
        5'd31:proof_frequency=16'd3115;
        default:proof_frequency=0;endcase end endfunction
    assign values[22]=page_q==6&&info_q[78:71]>80?16'd80:info_q[78:71];assign values[23]={14'd0,info_q[80:79]}+1'b1;assign values[24]=info_q[45:40]!=0?proof_frequency(info_q[106:102]):16'd0;
    assign values[25]=info_q[93:84];assign values[26]=info_q[135:128];assign values[27]=score_q;assign values[28]=combo_q;
    assign values[29]=info_q[116:109];assign values[30]=bt_q;assign values[31]=errors_q;
    genvar g;generate for(g=0;g<16;g=g+1)begin:pad_values assign values[32+g]=(page_q==6?0:bank_q?16:0)+g+1;end endgenerate
    function [15:0] matrix_pad_number;input [15:0] mask;integer n;begin
      matrix_pad_number=0;for(n=0;n<16;n=n+1)if(mask[n])matrix_pad_number=n+1;
    end endfunction
    assign values[48]=info_q[45:40];assign values[49]=page_q==6?matrix_pad_number(game_keys_q):{11'd0,info_q[106:102]}+1'b1;assign values[50]=page_q==6?matrix_pad_number(cue_q):bank_q+16'd1;
    wire signed [8:0] live_bend=info_q[63:55];
    assign values[51]=live_bend<0?-live_bend:live_bend;assign values[52]=info_q[70:64];assign values[53]=percent(info_q[54:46]);
    assign values[54]=info_q[255:240];assign values[55]=info_q[125];assign values[56]=info_q[151:136];
    assign values[57]=info_q[237:233];assign values[58]=hold_q;assign values[59]=info_q[82];assign values[60]=info_q[83];
    assign values[61]=info_q[108];assign values[62]=info_q[124:117];assign values[63]=info_q[107];
    // One shared binary-to-decimal converter. Fifty-one fields cost one
    // 16-bit datapath, not fifty-one division/modulo networks on the pixel path.
    // Packed flip-flops: the 138B has no writable distributed SRAM.
    reg [1279:0] bcd_storage=0;wire [19:0] bcd[0:63];
    generate for(g=0;g<64;g=g+1)begin:bcd_fields assign bcd[g]=bcd_storage[g*20+:20];end endgenerate
    reg [19:0] shift_bcd=0,adjusted;reg [15:0] shift_bin=0;
    reg [5:0] convert_index=0;reg [4:0] convert_bit=0;integer j,n;
    always @*begin adjusted=shift_bcd;for(n=0;n<5;n=n+1)if(shift_bcd[n*4+:4]>=5)adjusted[n*4+:4]=shift_bcd[n*4+:4]+4'd3;end
    always @(posedge clk)begin
        if(convert_bit==0)begin shift_bin<=values[convert_index];shift_bcd<=0;convert_bit<=1;end
        else begin
            shift_bcd<={adjusted[18:0],shift_bin[15]};shift_bin<={shift_bin[14:0],1'b0};
            if(convert_bit==16)begin bcd_storage[convert_index*20+:20]<={adjusted[18:0],shift_bin[15]};convert_index<=convert_index==63?0:convert_index+1'b1;convert_bit<=0;end
            else convert_bit<=convert_bit+1'b1;
        end
    end
    function rounded;input [10:0] px;input [9:0] py;input [10:0] ox;input [9:0] oy;input [10:0] w;input [9:0] h;
        reg [10:0] dx,rx;reg [9:0] dy,ry;reg [3:0] ex,ey;
        begin dx=px-ox;rx=ox+w-11'd1-px;dy=py-oy;ry=oy+h-10'd1-py;
            ex=dx<8?dx[3:0]:rx[3:0];ey=dy<8?dy[3:0]:ry[3:0];
            rounded=px>=ox && px<ox+w && py>=oy && py<oy+h &&
            ((dx>=8 && rx>=8)||(dy>=8 && ry>=8)||({1'b0,ex}+{1'b0,ey}>=5));end
    endfunction
    // Geometry is registered before selecting colors in the existing bg1
    // stage. This removes the rounded-hit + palette OR path from one cycle
    // without adding any pixel latency.
    `include "panel_hit_stage.vh"
    reg [23:0] bg,button_color,dot_color;reg card_hit,button_hit,dot_hit;
    reg overlay_hit=0,overlay_hit0=0;
    reg [23:0] base0=0,painted,bg0=0;
    `include "surface_compare_stage.vh"
    reg surface_hit;wire surface_hit0=surface_hit;
    reg [23:0] surface_color,matrix_edge;wire [23:0] surface_color0=surface_color;
    always @*begin
        `include "instrument_paint.vh"
        matrix_edge=24'he0e5ef;
        `include "pressure_matrix_paint.vh"
    end
    wire signed [9:0] bend_position=$signed({live_bend[8],live_bend})+10'sd200;
    // Constant coordinate tables remove division from the pixel clock path.
    reg [6:0] bend_pixels[0:511],vibrato_pixels[0:127];
    initial begin
        $readmemh("src/expression_x.hex",bend_pixels);
        $readmemh("src/expression_vibrato.hex",vibrato_pixels);
    end
    reg [8:0] bend_position_q=200;reg [6:0] bend_pixel_q=63,vibrato_pixel_q=0;
    reg [10:0] expr_x=799,expr_left=796,expr_right=802;
    reg [9:0] expr_y=212,expr_top=209,expr_bottom=215,vibrato_y=339;
    wire signed [11:0] marker=12'sd288+position_q;
    reg signed [11:0] marker_left=273,marker_right=303;
    always @(posedge clk)begin
        bend_position_q<=bend_position<0?9'd0:bend_position>400?9'd400:bend_position[8:0];
        bend_pixel_q<=bend_pixels[bend_position_q];vibrato_pixel_q<=vibrato_pixels[info_q[70:64]];
        expr_x<=11'd736+{4'd0,bend_pixel_q};vibrato_y<=10'd339-{3'd0,vibrato_pixel_q};
        expr_y<=10'd339-(info_q[54:46]==256?10'd127:(info_q[54:46]>>1));
        expr_left<=expr_x-11'd3;expr_right<=expr_x+11'd3;expr_top<=expr_y-10'd3;expr_bottom<=expr_y+10'd3;
        marker_left<=marker-12'sd15;marker_right<=marker+12'sd15;
    end
    always @*begin
        card_hit=0;button_hit=0;dot_hit=0;button_color=0;dot_color=0;
        case(page_q)
            `include "panel_paint.vh"
        endcase
        painted=base0;
        if(card_hit)painted=24'hffffff;
        if(button_hit)painted=button_color;
        if(dot_hit)painted=dot_color;
        if(overlay_hit0)painted=bg0;
        if(surface_hit0)painted=surface_color0;
    end
    always @*begin
        bg=0;overlay_hit=0;
        if(page_q==0)begin
            if(view_q==0 && x>=152 && x<664 && y==279)begin bg=24'he9edf7;overlay_hit=1;end
            if(view_q==1 && x>=152 && x<664 && (y==232 || y==276 || y==320))begin bg=24'he9edf7;overlay_hit=1;end
            if(view_q==2 && x>=280 && x<536 && y>=224 && y<336 && (x==408 || y==280))begin bg=24'he9edf7;overlay_hit=1;end
        end
        if(page_q==1 && x>=720 && x<734 && y>=438 && y<441)begin
            if(negative_bend||positive_bend)begin bg=24'h3b4056;overlay_hit=1;end
        end
        if(page_q==1 && positive_bend && x>=725 && x<728 && y>=433 && y<446)begin bg=24'h3b4056;overlay_hit=1;end
        if(page_q==3)begin
            if(x>=152 && x<984 && y>=410 && y<413)begin bg=24'he0e4f0;overlay_hit=1;end
            if(x>=286 && x<290 && y>=374 && y<450)begin bg=24'h8d9ee4;overlay_hit=1;end
            if(running_q && x>=152 && x<980 && y>=396 && y<426 &&
                $signed({1'b0,x})>=marker_left && $signed({1'b0,x})<marker_right)begin bg=24'hb6b4ef;overlay_hit=1;end
            if(feedback_q!=0 && x>=280 && x<296 && y>=432 && y<448)begin bg=feedback_q<=2?24'hb6b4ef:24'he7b498;overlay_hit=1;end
            if(finished_q && x>=128 && x<1008 && y>=488 && y<492)begin bg=24'hb6b4ef;overlay_hit=1;end
        end
        if(page_q==5&&y>=340&&y<350)begin
            if(x>=152&&x<536)begin bg=x<event_progress_end?(info_q[82]?24'hd88083:24'h7095d7):24'he8edf5;overlay_hit=1;end
            if(x>=600&&x<984)begin bg=x<audio_progress_end?(info_q[217]?24'hd88083:24'h7095d7):24'he8edf5;overlay_hit=1;end
        end
    end
    // Decode one numeric field per pixel. ROM digits are 16-pixel fixed width.
    reg number_visible,matrix_number;reg [5:0] slot;reg [2:0] digit_count;reg decimal_point;
    reg [10:0] nx,origin_x;reg [9:0] ny,origin_y;reg [3:0] digit_code;reg [2:0] char_index,digit_index,digit_select;
    reg [5:0] slot_q=0;reg [2:0] count_q=1;reg decimal_q=0,numeric_q=0,matrix_number_q=0,matrix_empty_q=0;
    reg [10:0] nx_q=0;reg [9:0] ny_q=0;
    reg [19:0] number;reg [8:0] digit_address=0;reg [3:0] number_x1=0,number_x2=0;
    reg number_on1=0,number_on2=0;reg [23:0] ink,ink1=0,ink2=0;
    always @*begin
        number_visible=0;matrix_number=0;slot=0;digit_count=0;decimal_point=0;origin_x=0;origin_y=0;
        `include "panel_numbers.vh"
        `include "instrument_numbers.vh"
        `include "pressure_matrix_numbers.vh"
        nx=x-origin_x;ny=y-origin_y;
        if(matrix_number)begin nx=nx>>1;ny=ny>>1;end
        ink=24'h343a50;
        `include "instrument_ink.vh"
        if(page_q==1 && instrument_q==2 && x>=128 && x<552)ink=24'h999eac;
        if(page_q==1 && instrument_q==2 && x>=576 && y>=170 && y<524)ink=24'h999eac;
    end
    always @*begin
        char_index=nx_q[6:4];digit_index=char_index;number=bcd[slot_q];digit_code=15;digit_select=0;
        if(matrix_empty_q)digit_code=(char_index==count_q-3'd1) ? 4'd10 : 4'd15;
        else if(decimal_q && char_index==count_q-3'd1)digit_code=11;
        else begin
            if(decimal_q && char_index==count_q)digit_index=char_index-1'b1;
            digit_select=count_q-3'd1-digit_index;
            case(digit_select)
                0:digit_code=number[3:0];1:digit_code=number[7:4];2:digit_code=number[11:8];
                3:digit_code=number[15:12];4:digit_code=number[19:16];default:digit_code=15;
            endcase
            if(!matrix_number_q && digit_select!=0 && !(decimal_q && digit_select==1) && (number>>{digit_select,2'b00})==0)digit_code=15;
        end
    end
    wire [13:0] map_address;
    panel_map_address map_decode(.x(x),.y(y),.page_q(page_q),.instrument_q(instrument_q),
        .record_button_state(record_button_state),.event_label_state(event_label_state),
        .audio_label_state(audio_label_state),.practice_label_state(practice_label_state),
        .matrix_status(matrix_status),.matrix_feedback(matrix_feedback),
        .running_q(running_q),.finished_q(finished_q),.info_q(info_q),.map_address(map_address));
    reg [13:0] map_address_q=0;reg [3:0] map_row_q=0,text_x0=0;
    wire [31:0] text_row,digit_row;reg [3:0] text_x1=0,text_x2=0;
    panel_rom font(.clk(clk),.map_address(map_address_q),.row(map_row_q),.text_row(text_row),
        .digit_address(digit_address),.digit_row(digit_row));
    reg [23:0] bg1=0,bg2=0,ink0=0;reg visible0=0,visible1=0,visible2=0;
    reg expression_panel0=0,expression_cross0=0,expression_dot0=0,vibrato_panel0=0,vibrato_fill0=0;
    // Match two analyzer read clocks, then register overlay decisions before
    // the final font blend. XY RAM has one read clock, so delay it once more.
    reg [10:0] plot_x0=0,plot_x1=0;
    reg [9:0] plot_y0=0,plot_y1=0;
    reg xy_d0=0,xy_valid0=0;
    reg wave_draw=0,spectrum_draw=0,xy_draw=0;
    wire [10:0] spectrum_column=plot_x1-152;
    wire [9:0] wave_row=plot_y1-220;
    reg [23:0] plot_bg;
    always @*begin
        plot_bg=bg2;
        if(page_q==0)begin
            if(wave_draw)plot_bg=24'h8d9ee4;
            if(spectrum_draw || xy_draw)plot_bg=24'h7095d7;
        end
    end
    wire [1:0] ta=(text_row>>(text_x2*2))&3;
    wire [1:0] da=number_on2?((digit_row>>(number_x2*2))&3):2'd0;
    wire [1:0] alpha=da>ta?da:ta;
    function [7:0] blend;input [7:0] background,foreground;input [1:0] a;
        begin case(a)
            0:blend=background;1:blend=(background>>1)+(background>>2)+(foreground>>2);
            2:blend=(background>>2)+(foreground>>1)+(foreground>>2);default:blend=foreground;
        endcase end
    endfunction
    always @(posedge clk)begin
        slot_q<=slot;count_q<=digit_count;decimal_q<=decimal_point;numeric_q<=number_visible;matrix_number_q<=matrix_number;nx_q<=nx;ny_q<=ny;
        matrix_empty_q<=page_q==6&&((slot==49&&game_keys_q==0)||(slot==50&&cue_q==0));

        map_address_q<=map_address;map_row_q<=y[3:0];text_x0<=x[3:0];
        expression_panel0<=page_q==0&&x>=736&&x<864&&y>=212&&y<340;
        expression_cross0<=x==800||y==276;
        expression_dot0<=x>=expr_left&&x<=expr_right&&y>=expr_top&&y<=expr_bottom;
        vibrato_panel0<=page_q==0&&x>=936&&x<984&&y>=212&&y<340;vibrato_fill0<=y>=vibrato_y;
        bg0<=bg;overlay_hit0<=overlay_hit;base0<=page_q!=6&&x<104?24'hf1f3f8:24'hf7f8fc;
        bg1<=expression_panel0?(expression_dot0?24'h7095d7:expression_cross0?24'hccd5e8:24'he9edf7):
             vibrato_panel0?(vibrato_fill0?24'hb2c5ed:24'he9edf7):painted;
        bg2<=bg1;ink0<=ink;ink1<=ink0;ink2<=ink1;visible0<=visible;visible1<=visible0;visible2<=visible1;
        plot_x0<=x;plot_x1<=plot_x0;plot_y0<=y;plot_y1<=plot_y0;
        xy_d0<=xy_pixel;xy_valid0<=xy_valid;
        wave_draw<=view_q==0 && wave_valid && plot_x1>=152 && plot_x1<664 && plot_y1>=220 && plot_y1<340 &&
            wave_row>=wave_low && wave_row<=wave_high;
        spectrum_draw<=view_q==1 && wave_valid && plot_x1>=152 && plot_x1<664 && plot_y1>=232 && plot_y1<320 &&
            spectrum_column[2:0]<6 && (10'd320-plot_y1)<=spectrum_height;
        xy_draw<=view_q==2 && xy_valid0 && xy_d0 && plot_x1>=280 && plot_x1<536 && plot_y1>=224 && plot_y1<336;
        text_x1<=text_x0;text_x2<=text_x1;number_x1<=nx_q[3:0];number_x2<=number_x1;
        number_on1<=numeric_q;number_on2<=number_on1;digit_address<={digit_code,ny_q[4:0]};
        color<=visible2?{blend(plot_bg[23:16],ink2[23:16],alpha),blend(plot_bg[15:8],ink2[15:8],alpha),blend(plot_bg[7:0],ink2[7:0],alpha)}:24'd0;
    end
endmodule
