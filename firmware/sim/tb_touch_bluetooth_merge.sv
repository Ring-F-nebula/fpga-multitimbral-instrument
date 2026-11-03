`timescale 1ns/1ps
module tb_touch_bluetooth_merge;
    reg bt=1,usb=1,valid=0;
    reg [4:0] contacts=0;
    reg [59:0] xx=0,yy=0;
    wire bt_tx,usb_tx;
    tri1 scl,sda,irq;
    reg board_clk=0; always #10 board_clk=~board_clk;
    dualmode_top #(.PANEL_UI(0)) dut(.clk_50m(board_clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(usb),.BT_RX(bt),
        .BT_TX(bt_tx),.UART_TX(usb_tx),.enc_a_n(5'h1f),.enc_b_n(5'h1f),
        .enc_sw_n(1'b1),.beam_broken(7'b0),.soft_touch(1'b0),.bend_touch(1'b0),.timbre_touch(1'b0),.fx_touch(1'b0),.touch_scl(scl),.touch_sda(sda),.touch_int(irq));
    defparam dut.status_link.PERIOD=60000;
    defparam dut.bluetooth_status.PERIOD=60000;
    // I2C startup and actual RGB pixels have independent original regressions.
    initial begin
        force dut.display.h=0;force dut.display.v=0;force dut.display.scope.audio_toggle=0;
        force dut.touch_frame=valid;force dut.touch_contacts=contacts;
        force dut.touch_x=xx;force dut.touch_y=yy;force dut.touch_online=1;
    end
    task clocks(input integer n);repeat(n)@(negedge dut.clk);endtask
    task frames(input integer n);repeat(n)@(negedge dut.sample_tick);@(negedge dut.clk);endtask
    task send_byte(input [7:0] b,input integer port);
        integer period;
        begin period=port==0?2734:228;
            if(port==0)bt=0;else usb=0;clocks(period);
            for(integer j=0;j<8;j=j+1)begin if(port==0)bt=b[j];else usb=b[j];clocks(period);end
            if(port==0)bt=1;else usb=1;clocks(period+6);
        end
    endtask
    task parameter_write(input [7:0] id,input [7:0] value,input integer port);
        send_byte(8'hf5,port);send_byte(id,port);send_byte(value,port);send_byte(8'hf5^id^value,port);clocks(8);
    endtask
    task mask(input [15:0] keys);
        send_byte(8'hf6,0);send_byte(keys[7:0],0);send_byte(keys[15:8],0);send_byte(8'hf6^keys[7:0]^keys[15:8],0);clocks(8);
    endtask
    task touch(input integer x,input integer y,input bit down=1);
        @(negedge dut.clk);xx=x;yy=y;contacts=down?1:0;valid=1;
        @(negedge dut.clk);valid=0;clocks(8);
    endtask
    task audible;
        integer heard;
        begin heard=0;repeat(300)begin frames(1);if(dut.pcm!=0)heard=heard+1;end
            if(heard<100)$fatal(1,"merged audio silent, instrument %d",dut.instrument);
        end
    endtask
    wire [15:0] bt_frames,usb_frames;
    merge_status_monitor #(.PERIOD(2734)) bt_monitor(dut.clk,bt_tx,bt_frames);
    merge_status_monitor #(.PERIOD(228)) usb_monitor(dut.clk,usb_tx,usb_frames);
    initial begin
        frames(2200);
        parameter_write(1,1,0);parameter_write(3,180,0);parameter_write(5,12,0);
        touch(300,200); // Screen volume down, without resetting Bluetooth ADSR.
        if(dut.volume!=11 || dut.attack_sel!=1 || dut.sustain_level!=180)$fatal(1,"touch/BT parameter ownership");
        touch(0,0,0);parameter_write(5,9,1);
        if(dut.volume!=9 || dut.attack_sel!=1 || dut.sustain_level!=180)$fatal(1,"USB overwrote unrelated BT parameters");
        mask(16'h0010);send_byte(8'h97,1);touch(50,550);clocks(10);
        if(dut.live_keys!==16'h0091)$fatal(1,"touch + USB + BT chord lost: %h",dut.live_keys);
        audible();mask(0);clocks(10);
        if(dut.live_keys!==16'h0081)$fatal(1,"Bluetooth release silenced other sources");
        touch(0,0,0);send_byte(8'h87,1);clocks(10);
        if(dut.live_keys!==0)$fatal(1,"independent releases");
        // Touch-selected instruments must also sound from the Bluetooth port.
        touch(300,70);frames(400);touch(0,0,0);
        if(dut.instrument!=1)$fatal(1,"guitar lost in merge");mask(1);audible();mask(0);
        touch(500,70);frames(400);touch(0,0,0);
        if(dut.instrument!=2)$fatal(1,"drums lost in merge");mask(1);audible();mask(0);
        touch(100,70);frames(400);touch(0,0,0);
        if(dut.instrument!=0)$fatal(1,"piano return");
        mask(1);touch(690,70);frames(400);
        if(dut.live_keys!=0)$fatal(1,"touch STOP failed to block held Bluetooth note");
        touch(0,0,0);mask(0);mask(1);frames(100);
        if(dut.live_keys!=0 || !dut.performance_stopped)$fatal(1,"STOP must remain latched");
        mask(0);touch(930,70);frames(400);touch(0,0,0);mask(1);frames(100);
        if(dut.live_keys!=1)$fatal(1,"Bluetooth could not resume after LIVE");mask(0);
        parameter_write(6,1,0);frames(400);if(!dut.auto_mode)$fatal(1,"Bluetooth AUTO lost");
        touch(930,70);frames(400);if(dut.auto_mode)$fatal(1,"touch LIVE lost");
        touch(0,0,0);parameter_write(6,0,0);frames(400);
        // Both full 40-byte wire frames must survive the merge, including touch flag.
        if(bt_frames==0 || usb_frames==0)$fatal(1,"missing physical UART status frames");
        $display("PASS merged touch/USB/BT: independent chord releases, parameter ownership, touch STOP, Bluetooth piano/guitar/drums, modes, both UART status checksums/build66");
        $finish;
    end
    initial begin #500000000;$fatal(1,"merge timeout");end
endmodule

// Decode the actual TX pins, not internal packet registers.
module merge_status_monitor #(parameter integer PERIOD=228)(input clk,input tx,output reg [15:0] frames=0);
    reg [7:0] bytes[0:39];reg [7:0] value,sum;integer index=0,extended_frames=0;
    initial forever begin
        @(negedge tx);repeat(PERIOD/2)@(negedge clk);
        if(tx!==0)$fatal(1,"status start bit");
        for(integer bitno=0;bitno<8;bitno=bitno+1)begin repeat(PERIOD)@(negedge clk);value[bitno]=tx;end
        repeat(PERIOD)@(negedge clk);if(tx!==1)$fatal(1,"status stop bit");
        bytes[index]=value;
        if(index==2 && value!=4 && value!=5)$fatal(1,"unknown status frame type");
        if(index==(bytes[2]==5?21:39))begin
            sum=0;for(integer j=2;j<index;j=j+1)sum=sum^bytes[j];
            if(bytes[0]!=8'ha5 || bytes[1]!=8'h5a || sum!=bytes[index])$fatal(1,"status framing/checksum");
            if(bytes[2]==4)begin
                if(bytes[30]!=8'h66)$fatal(1,"wrong legacy build id");
                if(!bytes[3][2])$fatal(1,"touch-online status lost");
                frames=frames+1;
            end else begin
                if(bytes[3]!=8'h66)$fatal(1,"wrong effects build id");
                extended_frames=extended_frames+1;
            end
            index=0;
        end else index=index+1;
    end
endmodule
