// Native LCD controls. The renderer reads actual engine registers, never shadow
// knob positions. Actions fire on the leading contact edge; note pads are held.
module panel_ui #(parameter ORIENTATION_HOLD=47250000)(
    input clk,reset_n,frame_valid,key1_n,input [4:0] contacts,input [59:0] point_x,point_y,
    input [3:0] serial_volume,input serial_volume_event,
    input [127:0] fx_params,input [255:0] performance_info,input practice_running,input [4:0] practice_target,input hold_state,input [1:0] instrument_state,input [7:0] bpm_state,input [1:0] song_state,input [4:0] test_selected,input test_mute,
    output reg bank=0,output reg [2:0] axis_valid=0,output reg signed [8:0] axis_bend=0,output reg [8:0] axis_gain=256,output reg [6:0] axis_vibrato=0,input [3:0] attack_sel,decay_sel,release_sel,input [7:0] sustain_level,
    output reg [31:0] keys=0,output reg [1:0] instrument=0,output reg [2:0] plot_mode=0,
    output reg [3:0] volume=8,output reg auto_press=0,live_press=0,stop_press=0,instrument_changed=0,
    output wire [2:0] orientation,output reg cursor_down=0,output reg [10:0] cursor_x=0,
    output reg [9:0] cursor_y=0,output reg [2:0] finger_count=0,
    output reg game_page=0,game_start=0,output reg [2:0] page=0,output reg [3:0] selected_pad=0,
    output reg recalibrate=0,commit=0,output reg [7:0] param_id=0,param_value=0
);
    `include "panel_hit.vh"
    `include "guitar_chords.vh"
    `include "instrument_notes.vh"
    `include "panel_enable.vh"
    `include "adsr_presets.vh"
    `include "fx_defaults.vh"
    reg navigation_guard=0;
    reg mirror=0;assign orientation={2'b0,mirror};
    reg [1:0] key_sync=3;reg [25:0] hold_count=0;reg hold_fired=0;
    reg [127:0] held_actions=0;reg [127:0] actions;
    reg [31:0] decoded_keys;reg [3:0] pad;reg [2:0] count;
    reg [10:0] cx;reg [9:0] cy;reg found;reg [11:0] px,py;reg [7:0] action,selected_action;
    reg busy=0;reg [2:0] point_index=0;reg [59:0] report_x=0,report_y=0;reg [4:0] report_contacts=0;
    reg [127:0] accumulated_actions=0;reg [31:0] accumulated_keys=0;
    reg [2:0] accumulated_count=0;reg accumulated_found=0;
    reg [10:0] accumulated_x=0;reg [9:0] accumulated_y=0;
    reg [3:0] accumulated_pad=0;reg [7:0] accumulated_action=0;
    reg [2:0] accumulated_axes=0,decoded_axes;reg signed [8:0] decoded_bend,accumulated_bend=0;reg [8:0] decoded_gain,accumulated_gain=256;reg [6:0] decoded_vibrato,accumulated_vibrato=0;
    wire apply_frame=busy && point_index==4;
    // Decode one contact per clock. Five contacts take five clocks, avoiding
    // five copies of the complete button decoder on the audio clock path.
    always @(posedge clk)begin
        if(!reset_n)busy<=0;
        else if(frame_valid && !busy)begin
            busy<=1;point_index<=0;report_x<=point_x;report_y<=point_y;report_contacts<=contacts;
            accumulated_actions<=0;accumulated_keys<=0;accumulated_axes<=0;accumulated_bend<=axis_bend;accumulated_gain<=axis_gain;accumulated_vibrato<=axis_vibrato;accumulated_count<=0;accumulated_found<=0;
            accumulated_x<=0;accumulated_y<=0;accumulated_pad<=selected_pad;accumulated_action<=0;
        end else if(busy)begin
            accumulated_actions<=actions;accumulated_keys<=decoded_keys;accumulated_axes<=decoded_axes;accumulated_bend<=decoded_bend;accumulated_gain<=decoded_gain;accumulated_vibrato<=decoded_vibrato;accumulated_count<=count;
            accumulated_found<=found;accumulated_x<=cx;accumulated_y<=cy;accumulated_pad<=pad;accumulated_action<=selected_action;
            if(point_index==4)busy<=0;else point_index<=point_index+1'b1;
        end
    end
    always @* begin
        actions=accumulated_actions;decoded_keys=accumulated_keys;decoded_axes=accumulated_axes;decoded_bend=accumulated_bend;decoded_gain=accumulated_gain;decoded_vibrato=accumulated_vibrato;count=accumulated_count;
        cx=accumulated_x;cy=accumulated_y;found=accumulated_found;action=0;selected_action=accumulated_action;pad=accumulated_pad;
            px=report_x[point_index*12+:12];py=report_y[point_index*12+:12];if(mirror && px<1024)px=1023-px;
            if(report_contacts[point_index] && px<1024 && py<600)begin
                count=count+1'b1;if(!found)begin cx=px;cy=py;found=1;end
                action=panel_action_at(page,px[10:0],py[9:0]);
                if(page==0 && instrument_state<2 && px>=128 && py>=376)action=instrument_note_at(instrument_state,bank,performance_info[228:226],performance_info[229],px[10:0],py[9:0]);
                if(!panel_enabled(action,instrument_state,serial_volume,attack_sel,decay_sel,release_sel,sustain_level,fx_params,performance_info,page))action=0;
                if(page==0&&instrument_state==1&&action>=128&&action<160)begin
                    decoded_keys[action-128]=1;
                    // Horizontal pick position provides a separate loudness axis.
                    decoded_axes[1]=1;decoded_gain=px<368?9'd64:px>=984?9'd256:9'd64+((px-368)>>2)+((px-368)>>4);
                end else if(page==0 && px>=736 && px<864 && py>=212 && py<340)begin
                    decoded_axes[1:0]=3;decoded_bend=px==863?9'sd200:($signed({1'b0,px})-13'sd736)*400/128-200;
                    decoded_gain=py==212?9'd256:(14'd339-py)*2;
                end else if(page==0&&px>=936&&px<984&&py>=212&&py<340)begin
                    decoded_axes[2]=1;decoded_vibrato=py==212?7'd100:((14'd339-py)*100)>>7;
                end else if(action>=128 && action<144)decoded_keys[(bank?16:0)+action-128]=1;
                else if(action==159)decoded_keys[test_selected]=1;
                else if(action>=160 && action<176)pad=action-160;
                else if(action>0 && action<128)begin
                    actions[action]=1;
                    if(!held_actions[action] && selected_action==0) selected_action=action;
                end
            end
        // STOP wins even when another finger touches a parameter or a note.
        if(actions[7] && !held_actions[7])selected_action=7;
        if(navigation_guard)begin decoded_keys=0;if(selected_action!=7)selected_action=0;end
    end
    function [7:0] clipped;
        input [7:0] current;input integer step,lo,hi;integer v;
        begin v=current+step;if(v<lo)v=lo;if(v>hi)v=hi;clipped=v;end
    endfunction
    reg command_valid=0;reg [7:0] command=0;
    always @(posedge clk)begin command_valid<=apply_frame;if(apply_frame)command<=selected_action;end
    reg restoring=0;reg [3:0] restore_index=0;reg enable_remote_pending=0;
    reg [2:0] local_sequence=0;reg [1:0] sequence_index=0;reg [7:0] pending_midi=60;
    reg [1:0] adsr_preset_index=3;
    task write_param;input [7:0] id,value;begin commit<=1;param_id<=id;param_value<=value;end endtask
    always @(posedge clk)begin
        commit<=0;axis_valid<=0;auto_press<=0;live_press<=0;stop_press<=0;instrument_changed<=0;game_start<=0;recalibrate<=0;
        key_sync<={key_sync[0],key1_n};
        if(!reset_n)begin page<=0;keys<=0;held_actions<=0;volume<=8;instrument<=0;plot_mode<=0;bank<=0;axis_bend<=0;axis_gain<=256;axis_vibrato<=0;game_page<=0;mirror<=0;restoring<=0;enable_remote_pending<=0;navigation_guard<=0;local_sequence<=0;end
        else begin
            if(key_sync[1])begin hold_count<=0;hold_fired<=0;end
            else if(!hold_fired)begin
                if(hold_count==ORIENTATION_HOLD-1)begin mirror<=~mirror;hold_fired<=1;keys<=0;held_actions<=0;end
                else hold_count<=hold_count+1'b1;
            end
            instrument<=instrument_state;if(game_page&&practice_running)bank<=practice_target[4];if(serial_volume_event)volume<=serial_volume;
            if(restoring)begin write_param(8'h10+restore_index,fx_default_byte(restore_index));if(restore_index==14)restoring<=0;else restore_index<=restore_index+1'b1;end
            else if(enable_remote_pending)begin write_param(8'h10,fx_params[7:0]|8'h40);enable_remote_pending<=0;end
            else if(local_sequence==1)begin write_param(8'h31,pending_midi);local_sequence<=0;end
            else if(local_sequence==2)begin
                write_param(8'd1+{6'd0,sequence_index},adsr_preset_value(adsr_preset_index,sequence_index));
                sequence_index<=sequence_index+1'b1;if(sequence_index==3)local_sequence<=0;
            end else if(local_sequence==3)begin
                if(sequence_index==0)begin write_param('h1e,100);sequence_index<=1;end
                else begin write_param('h10,fx_params[7:0]&8'haf);local_sequence<=0;end
            end
            if(apply_frame)begin
                keys<=decoded_keys;axis_valid<=decoded_axes;axis_bend<=decoded_bend;axis_gain<=decoded_gain;axis_vibrato<=decoded_vibrato;held_actions<=actions;selected_pad<=pad;
                cursor_down<=found;cursor_x<=cx;cursor_y<=cy;finger_count<=count;
                if(navigation_guard&&report_contacts==0)navigation_guard<=0;
            end
            if(command_valid)begin
                // Navigation always releases screen-held notes. Physical FSR,
                // USB and Bluetooth voices continue in all parameter pages.
                if(command>=1 && command<=5)begin
                    page<=command-1;keys<=0;
                    if(game_page||(performance_info[45:40]!=0&&command!=5))begin game_page<=0;live_press<=1;end
                end
                case(command)
                    6:begin page<=0;game_page<=0;keys<=0;live_press<=1;end
                    7:begin stop_press<=1;keys<=0;end
                    8:if(serial_volume>0)write_param(5,serial_volume-1'b1);
                    9:if(serial_volume<15)write_param(5,serial_volume+1'b1);
                    10,11,12:begin instrument<=command-10;write_param('h23,command-10);instrument_changed<=1;live_press<=1;keys<=0;end
                    // Display only: no clear, mode change or held-key release.
                    13,14,15:plot_mode<=command-13;
                    16:if(instrument_state!=1)bank<=~bank;
                    17:if(instrument_state!=1)write_param('h2a,!hold_state);
                    18:write_param('h2b,1);19:begin write_param('h53,1);local_sequence<=3;sequence_index<=0;end
                    20,21:if(instrument!=2)write_param(1,clipped({4'b0,attack_sel},command[0]?1:-1,0,9));
                    22,23:if(instrument!=2)write_param(2,clipped({4'b0,decay_sel},command[0]?1:-1,0,9));
                    24,25:if(instrument!=2)write_param(3,clipped(sustain_level,command[0]?16:-16,0,255));
                    26,27:if(instrument!=2)write_param(4,clipped({4'b0,release_sel},command[0]?1:-1,0,9));
                    28,29,57:if(instrument_state!=2)begin
                        adsr_preset_index<=command==28?2'd0:command==29?2'd1:2'd2;
                        local_sequence<=2;sequence_index<=0;
                    end
                    42:begin adsr_preset_index<=3;local_sequence<=2;sequence_index<=0;end
                    43,44,45,46,47,48,49:begin write_param('h54,command-43);keys<=0;end
                    30:write_param('h10,fx_params[7:0]^8'h08);
                    31,32:write_param('h1a,clipped(fx_params[87:80],command==32?1:-1,0,9));
                    33:write_param('h10,fx_params[7:0]^8'h10);
                    34,35:write_param('h1b,clipped(fx_params[95:88],command[0]?1:-1,1,200));
                    36,37:write_param('h1c,clipped(fx_params[103:96],command[0]?2:-2,0,100));
                    38,39:begin write_param('h1e,clipped(fx_params[119:112],command[0]?5:-5,0,200));enable_remote_pending<=1;end
                    40:write_param('h1d,fx_params[111:104]==0?8'd32:fx_params[111:104]-1'b1);
                    41:write_param('h1d,fx_params[111:104]==32?8'd0:fx_params[111:104]+1'b1);
                    50:write_param('h10,(fx_params[7:0]^8'h01)&8'hdf);
                    51,52:write_param('h11,clipped(fx_params[15:8],command==52?1:-1,1,100));
                    53,54:write_param('h12,clipped(fx_params[23:16],command==54?8:-8,0,230));
                    55,56:write_param('h13,clipped(fx_params[31:24],command==56?8:-8,0,255));
                    60:write_param('h10,(fx_params[7:0]^8'h02)&8'hdf);
                    61,62:write_param('h14,clipped(fx_params[39:32],command==62?1:-1,1,100));
                    63,64:write_param('h15,clipped(fx_params[47:40],command==64?5:-5,0,100));
                    65,66:write_param('h16,clipped(fx_params[55:48],command==66?8:-8,0,255));
                    70:write_param('h10,(fx_params[7:0]^8'h04)&8'hdf);
                    71,72:write_param('h17,clipped(fx_params[63:56],command==72?5:-5,0,100));
                    73,74:write_param('h18,clipped(fx_params[71:64],command==74?1:-1,0,9));
                    75,76:write_param('h19,clipped(fx_params[79:72],command==76?8:-8,0,255));
                    80:write_param('h10,fx_params[7:0]^8'h20);
                    81:begin restoring<=1;restore_index<=0;end
                    90:begin game_page<=1;game_start<=1;live_press<=1;keys<=0;write_param('h2e,1);end
                    91:begin game_page<=0;auto_press<=1;keys<=0;write_param('h2e,1);end
                    92:write_param('h2e,2);93:write_param('h2e,3);94:write_param('h2e,0);
                    95:write_param('h2c,clipped(bpm_state,-5,40,200));96:write_param('h2c,clipped(bpm_state,5,40,200));
                    97:write_param('h2d,song_state==3?0:song_state+1'b1);
                    100:write_param('h27,4);101:write_param('h27,8);102:write_param('h27,16);103:write_param('h27,32);104:write_param('h27,0);
                    105:write_param('h28,test_selected==0?performance_info[45:40]-1'b1:test_selected-1'b1);106:write_param('h28,test_selected+1>=performance_info[45:40]?0:test_selected+1'b1);
                    107:write_param('h29,!test_mute);108:write_param('h50,1);109:write_param('h50,0);110:write_param('h50,2);111:write_param('h50,3);112:write_param('h60,1);113:write_param('h60,0);
                    114:begin page<=5;keys<=0;if(game_page||performance_info[45:40]!=0)begin game_page<=0;live_press<=1;end end
                    115:begin write_param('h63,1);page<=0;game_page<=0;keys<=0;navigation_guard<=1;end
                    116:write_param('h63,0);117:write_param('h63,2);118:write_param('h63,3);
                    119:write_param('h63,(performance_info[82]||performance_info[217]||performance_info[239]||performance_info[83])?0:1);
                    120:write_param('h28,test_selected==0?31:test_selected-1'b1);
                    121:write_param('h28,test_selected==31?0:test_selected+1'b1);
                    122,123:begin write_param('h30,{3'd0,test_selected});pending_midi<=performance_info[135:128]+(command==123?8'd1:8'hff);local_sequence<=1;end
                    124:write_param('h32,1);
                    125:begin page<=6;game_page<=1;keys<=0;live_press<=1;write_param('h2e,0);end
                    126:write_param('h2e,performance_info[81]?3:2);
                    127:begin page<=3;game_page<=0;keys<=0;live_press<=1;write_param('h2e,0);end
                endcase
            end
        end
    end
endmodule
