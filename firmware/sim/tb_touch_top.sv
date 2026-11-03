`timescale 1ns/1ps
module tb_touch_top;
    reg k0=1,k1=1,uart=1;
    tri1 scl,sda,irq;
    reg valid=0;
    reg [4:0] contacts=0;
    reg [59:0] xx=0,yy=0;
    reg board_clk=0; always #10 board_clk=~board_clk;
    dualmode_top #(.PANEL_UI(0)) dut(.clk_50m(board_clk),.key0_n(k0),.key1_n(k1),.UART_RX(uart),.BT_RX(1'b1),.BT_TX(),.enc_a_n(5'h1f),
        .enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'b0),.soft_touch(1'b0),.bend_touch(1'b0),.timbre_touch(1'b0),.fx_touch(1'b0),.touch_scl(scl),.touch_sda(sda),.touch_int(irq));
    initial begin
        force dut.display.h=0;force dut.display.v=0;
        force dut.display.scope.audio_toggle=0;
        force dut.touch_frame=valid;force dut.touch_contacts=contacts;
        force dut.touch_x=xx;force dut.touch_y=yy;
    end
    task frames(input integer n);repeat(n) @(negedge dut.sample_tick);@(negedge dut.clk);endtask
    task touch(input integer x,input integer y,input bit down=1);
        @(negedge dut.clk);xx=x;yy=y;contacts=down?1:0;valid=1;
        @(negedge dut.clk);valid=0;
    endtask
    task audible;
        integer heard;
        begin heard=0;repeat(300) begin frames(1);if(dut.pcm!=0) heard=heard+1;end
            if(heard<100) $fatal(1,"touch -> PCM silent instrument %d",dut.instrument);
        end
    endtask
    initial begin
        frames(2200);touch(50,550);audible();
        touch(810,70);frames(400);if(!dut.auto_mode) $fatal(1,"touch AUTO route");
        touch(0,0,0);touch(930,70);frames(400);if(dut.auto_mode) $fatal(1,"touch LIVE route");
        touch(0,0,0);touch(300,70);frames(400);
        if(dut.instrument!=1) $fatal(1,"instrument switch commit");
        touch(50,390);audible();
        touch(0,0,0);touch(500,70);frames(400);
        if(dut.instrument!=2) $fatal(1,"drum switch commit");
        touch(50,420);audible();touch(0,0,0);
        for(integer i=0;i<8;i=i+1) begin touch(300,200);touch(0,0,0);end
        frames(400);if(dut.volume!=0 || dut.pcm!=0) $fatal(1,"touch volume mute");
        touch(690,70);frames(400);if(dut.pcm!=0 || dut.live_keys!=0) $fatal(1,"touch STOP route");
        $display("PASS top touch-to-audio: piano/guitar/drums, AUTO/LIVE, faded instrument commit, touch volume mute and STOP");$finish;
    end
    initial begin #400000000;$fatal(1,"top touchscreen timeout");end
endmodule
