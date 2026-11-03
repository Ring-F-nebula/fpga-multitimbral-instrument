`timescale 1ns/1ps
module tb_game_bluetooth;
    reg bt=1,valid=0;
    reg [4:0] contacts=0;
    reg [59:0] xx=0,yy=0;
    tri1 scl,sda,irq;
    reg board_clk=0; always #10 board_clk=~board_clk;
    dualmode_top #(.PANEL_UI(0)) dut(.clk_50m(board_clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(1'b1),.BT_RX(bt),.BT_TX(),
        .enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'b0),.soft_touch(1'b0),.bend_touch(1'b0),.timbre_touch(1'b0),.fx_touch(1'b0),
        .touch_scl(scl),.touch_sda(sda),.touch_int(irq));
    defparam dut.game.SAMPLE_RATE=1000;
    defparam dut.game.BEAT_SAMPLES=500;
    initial begin
        // Raster and FFT are checked separately against full exported pixels/data.
        force dut.display.h=0;force dut.display.v=0;force dut.display.scope.audio_toggle=0;
        force dut.touch_frame=valid;force dut.touch_contacts=contacts;
        force dut.touch_x=xx;force dut.touch_y=yy;
    end
    task clocks(input integer n);repeat(n)@(negedge dut.clk);endtask
    task frames(input integer n);repeat(n)@(negedge dut.sample_tick);@(negedge dut.clk);endtask
    task send_byte(input [7:0] b);
        bt=0;clocks(2734);
        for(integer j=0;j<8;j=j+1)begin bt=b[j];clocks(2734);end
        bt=1;clocks(2740);
    endtask
    task mask(input [15:0] keys);
        send_byte(8'hf6);send_byte(keys[7:0]);send_byte(keys[15:8]);send_byte(8'hf6^keys[7:0]^keys[15:8]);clocks(8);
    endtask
    task parameter_write(input [7:0] id,input [7:0] value);
        send_byte(8'hf5);send_byte(id);send_byte(value);send_byte(8'hf5^id^value);clocks(8);
    endtask
    task touch(input integer x,input integer y,input bit down=1);
        @(negedge dut.clk);xx=x;yy=y;contacts=down?1:0;valid=1;
        @(negedge dut.clk);valid=0;clocks(8);
    endtask
    task audible;
        integer heard;
        begin heard=0;repeat(200)begin frames(1);if(dut.pcm!=0)heard=heard+1;end
            if(heard<80)$fatal(1,"Bluetooth/game PCM silent");end
    endtask
    initial begin
        frames(2200);parameter_write(5,10);mask(1);audible();mask(0);
        touch(920,24);frames(300);touch(0,0,0);
        if(!dut.game_page || dut.instrument!=0 || dut.auto_mode)$fatal(1,"Bluetooth/game entry");
        parameter_write(6,1);frames(300);
        if(dut.auto_mode)$fatal(1,"remote AUTO escaped game page isolation");
        parameter_write(5,11);
        if(dut.volume!=11)$fatal(1,"Bluetooth volume lost in game page");
        touch(80,70);touch(0,0,0);
        // A complete 9600-baud F6 frame lasts about 190 sample ticks. Send
        // before the expected note so the committed mask lands on the beat.
        wait(dut.game.song_time==2810);@(negedge dut.clk);mask(1);frames(1);
        if(!dut.game_running || dut.game_score!=100 || dut.game_hits!=1 || dut.live_keys!=0)
            $fatal(1,"Bluetooth game scoring/isolation score=%d time=%d",dut.game_score,dut.game.song_time);
        audible();mask(0);
        // A corrupt packet must not create a judge edge.
        send_byte(8'hf6);send_byte(8'h02);send_byte(0);send_byte(0);frames(1);
        if(dut.bt_keys!=0 || dut.game_hits!=1 || dut.game_wrong!=0)$fatal(1,"bad F6 packet affected game");
        touch(300,70);frames(350);
        if(dut.game_running || dut.game_music_gate || dut.pcm!=0)$fatal(1,"game STOP did not silence backing");
        touch(0,0,0);mask(1);touch(920,24);frames(350);
        if(dut.game_page || dut.live_keys!=0 || dut.pcm!=0)$fatal(1,"held Bluetooth note escaped BACK clear");
        touch(0,0,0);mask(0);mask(1);audible();
        if(dut.live_keys!=1)$fatal(1,"Bluetooth piano failed after game exit");
        mask(0);
        $display("PASS real 9600 UART: Bluetooth free play, game score, AUTO isolation, volume, corrupt packet rejection, STOP/BACK held-note blocking and retrigger");
        $finish;
    end
    initial begin #600000000;$fatal(1,"Bluetooth/game timeout");end
endmodule
