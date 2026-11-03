module touch_ui #(parameter integer ORIENTATION_HOLD=47250000,parameter [2:0] INITIAL_ORIENTATION=0)(
    input wire clk,frame_valid,key1_n,
    input wire [4:0] contacts,
    input wire [59:0] point_x,point_y,
    input wire [3:0] serial_volume,
    input wire serial_volume_event,
    output reg [15:0] keys=0,
    output reg [1:0] instrument=0,
    output reg [2:0] plot_mode=0,
    output reg [3:0] volume=8,
    output reg auto_press=0,live_press=0,stop_press=0,instrument_changed=0,
    output wire [2:0] orientation,
    output reg cursor_down=0,
    output reg [10:0] cursor_x=0,
    output reg [9:0] cursor_y=0,
    output reg [2:0] finger_count=0,
    output reg game_page=0,game_start=0
);
    `include "ui_layout.vh"
    reg mirror_x=INITIAL_ORIENTATION[0];
    assign orientation={INITIAL_ORIENTATION[2:1],mirror_x};
    reg [10:0] previous_actions=0;
    reg [1:0] key_sync=3;
    reg [25:0] hold_count=0;
    reg hold_fired=0;
    reg [15:0] decoded_keys;
    reg [10:0] actions,new_actions;
    reg [11:0] raw_x,raw_y,tx,ty;
    reg [4:0] note;
    reg [3:0] action;
    reg [2:0] count;
    reg found;
    reg [10:0] cx;
    reg [9:0] cy;
    integer i;
    always @* begin
        decoded_keys=0; actions=0; count=0; found=0; cx=0; cy=0;
        raw_x=0; raw_y=0; tx=0; ty=0; note=31; action=0;
        for(i=0;i<5;i=i+1) begin
            raw_x=point_x[i*12 +:12]; raw_y=point_y[i*12 +:12];
            tx=orientation[2] ? raw_y:raw_x;
            ty=orientation[2] ? raw_x:raw_y;
            if(orientation[0] && tx<1024) tx=1023-tx;
            if(orientation[1] && ty<600) ty=599-ty;
            if(contacts[i] && tx<1024 && ty<600) begin
                count=count+1'b1;
                if(!found) begin found=1; cx=tx[10:0]; cy=ty[9:0]; end
                note=music_key_at(game_page?2'd0:instrument,tx[10:0],ty[9:0]);
                if(note<16) decoded_keys[note]=1;
                action=game_page?game_action_at(tx[10:0],ty[9:0]):action_at(tx[10:0],ty[9:0]);
                if(action!=0) actions[action]=1;
            end
        end
        new_actions=actions & ~previous_actions;
    end
    always @(posedge clk) begin
        auto_press<=0; live_press<=0; stop_press<=0; instrument_changed<=0;game_start<=0;
        key_sync<={key_sync[0],key1_n};
        if(key_sync[1]) begin hold_count<=0; hold_fired<=0; end
        else if(!hold_fired) begin
            if(hold_count==ORIENTATION_HOLD-1) begin
                mirror_x<=~mirror_x; hold_fired<=1;
                keys<=0; previous_actions<=0;
            end else hold_count<=hold_count+1'b1;
        end
        if(serial_volume_event) volume<=serial_volume;
        if(frame_valid) begin
            keys<=decoded_keys; previous_actions<=actions;
            cursor_down<=found; cursor_x<=cx; cursor_y<=cy; finger_count<=count;
            if(!game_page && (new_actions[1] || new_actions[2] || new_actions[3])) begin
                if(new_actions[1]) instrument<=0;
                else if(new_actions[2]) instrument<=1;
                else instrument<=2;
                keys<=0; instrument_changed<=1; live_press<=1;
            end
            if(new_actions[5]) auto_press<=1;
            if(new_actions[6]) live_press<=1;
            if(new_actions[7] && volume>0) volume<=volume-1'b1;
            if(new_actions[8] && volume<15) volume<=volume+1'b1;
            if(new_actions[9]) plot_mode<=plot_mode==4 ? 3'd0 : plot_mode+1'b1;
            if(new_actions[4]) begin stop_press<=1; live_press<=1; keys<=0; end
            if(game_page && new_actions[1]) begin game_start<=1;keys<=0;live_press<=1;end
            if(new_actions[10]) begin
                game_page<=~game_page;keys<=0;live_press<=1;stop_press<=!game_page;
                if(!game_page) begin instrument<=0;instrument_changed<=1;end
            end
        end
    end
endmodule
