`timescale 1ns/1ps
module tb_game_top;
    reg k0=1,k1=1,valid=0;
    reg [4:0] contacts=0;
    reg [59:0] xx=0,yy=0;
    tri1 scl,sda,irq;
    reg board_clk=0; always #10 board_clk=~board_clk;
    dualmode_top #(.PANEL_UI(0)) dut(.clk_50m(board_clk),.key0_n(k0),.key1_n(k1),.UART_RX(1'b1),.BT_RX(1'b1),.BT_TX(),.enc_a_n(5'h1f),
        .enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'b0),.soft_touch(1'b0),.bend_touch(1'b0),.timbre_touch(1'b0),.fx_touch(1'b0),.touch_scl(scl),.touch_sda(sda),.touch_int(irq));
    defparam dut.game.SAMPLE_RATE=1000;
    defparam dut.game.BEAT_SAMPLES=500;
    initial begin
        force dut.display.h=0;force dut.display.v=0;force dut.display.scope.audio_toggle=0;
        force dut.touch_frame=valid;force dut.touch_contacts=contacts;
        force dut.touch_x=xx;force dut.touch_y=yy;
    end
    task frames(input integer n);repeat(n) @(negedge dut.sample_tick);@(negedge dut.clk);endtask
    task touch(input integer x,input integer y,input bit down=1);
        @(negedge dut.clk);xx=x;yy=y;contacts=down?1:0;valid=1;
        @(negedge dut.clk);valid=0;
    endtask
    integer heard;
    initial begin
        frames(2200);
        for(integer i=0;i<4;i=i+1) begin touch(930,112);touch(0,0,0);end
        if(dut.plot_mode!=4) $fatal(1,"reference selector setup");
        touch(920,24);frames(200);
        if(!dut.game_page || dut.instrument!=0 || dut.auto_mode) $fatal(1,"game entry routing");
        touch(0,0,0);touch(80,70);frames(3005);
        if(!dut.game_running || !dut.game_music_gate || dut.game_countdown) $fatal(1,"countdown/backing playback");
        touch(50,550);frames(1);
        if(dut.game_score!=100 || dut.live_keys) $fatal(1,"touch-to-score or manual voice isolation");
        heard=0;repeat(100) begin frames(1);if(dut.pcm!=0) heard=heard+1;end
        if(heard<50) $fatal(1,"game backing PCM is silent");
        touch(0,0,0);wait(dut.game.judge_index==1 && dut.game.song_time==dut.game.judge_time);
        touch(120,420);frames(1);
        if(dut.game_wrong!=1 || dut.game_score!=100) $fatal(1,"wrong-key game route");
        touch(0,0,0);touch(50,550);frames(1);
        if(dut.game_score!=200 || dut.game_hits!=2) $fatal(1,"second tap score");
        touch(300,70);frames(350);
        if(dut.game_running || dut.game_music_gate || dut.pcm!=0) $fatal(1,"game STOP/mute");
        touch(0,0,0);touch(80,70);frames(2);
        if(!dut.game_running || dut.game_score || dut.game_hits) $fatal(1,"game retry");
        touch(920,24);frames(350);
        if(dut.game_page || dut.game_music_gate || dut.plot_mode!=4 || dut.pcm!=0) $fatal(1,"BACK/restored graphs/mute");
        touch(0,0,0);touch(50,550);frames(400);
        if(dut.live_keys!=1 || dut.pcm==0) $fatal(1,"free piano after game exit");
        $display("PASS full game integration: GAME/START, timed backing PCM, correct/wrong touch score, voice isolation, STOP, retry, BACK, preserved XY/reference selection and free piano");
        $finish;
    end
    initial begin #600000000;$fatal(1,"game integration timeout");end
endmodule
