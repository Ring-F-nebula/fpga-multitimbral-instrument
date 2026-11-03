`timescale 1ns/1ps
module tb_bt_audio;
    // Screen pixels and XY rendering are independently checked in the original tests.
    initial begin force dut.display.h=0; force dut.display.v=0; force dut.display.scope.audio_toggle=0; end
    reg bt=1,usb=1;
    wire bck,ws,din;
    reg board_clk=0; always #10 board_clk=~board_clk;
    dualmode_top #(.PANEL_UI(0)) dut(.clk_50m(board_clk),.key0_n(1'b1),.key1_n(1'b1),.UART_RX(usb),.BT_RX(bt),.BT_TX(),
        .enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),.beam_broken(7'b0),.soft_touch(1'b0),.bend_touch(1'b0),.timbre_touch(1'b0),.fx_touch(1'b0),.TOUCH_DRIVE(),
        .HP_BCK(bck),.HP_WS(ws),.HP_DIN(din),.PA_EN(),.UART_TX());
    task clocks(input integer n);repeat(n)@(negedge dut.clk);endtask
    task frames(input integer n);repeat(n)@(negedge dut.sample_tick);@(negedge dut.clk);endtask
    task byte_out(input [7:0] b,input integer port);
        if(port==0)bt=0;else usb=0;clocks(port==0?2734:228);
        for(integer j=0;j<8;j=j+1)begin if(port==0)bt=b[j];else usb=b[j];clocks(port==0?2734:228);end
        if(port==0)bt=1;else usb=1;clocks(port==0?2740:240);
    endtask
    task param_out(input [7:0] id,input [7:0] v,input integer port);
        byte_out(8'hf5,port);byte_out(id,port);byte_out(v,port);byte_out(8'hf5^id^v,port);clocks(5);
    endtask
    task mask(input [15:0] m);
        byte_out(8'hf6,0);byte_out(m[7:0],0);byte_out(m[15:8],0);byte_out(8'hf6^m[7:0]^m[15:8],0);clocks(5);
    endtask
    integer nonzero=0,transitions=0;reg prev_din=0;
    always @(posedge dut.clk)begin if(din!=prev_din)transitions<=transitions+1;prev_din<=din;end
    initial begin
        frames(2200);
        param_out(1,1,0);param_out(2,4,0);param_out(3,180,0);param_out(4,1,0);param_out(5,12,0);
        if(dut.volume!=12||dut.attack_sel!=1||dut.sustain_level!=180)$fatal(1,"Bluetooth params");
        // A USB volume update must not reset Bluetooth ADSR.
        param_out(5,9,1);if(dut.volume!=9||dut.attack_sel!=1||dut.sustain_level!=180)$fatal(1,"dual-port parameter arbitration");
        mask(16'h0011);frames(150);
        repeat(150)begin frames(1);if(dut.pcm!=0)nonzero=nonzero+1;end
        if(dut.live_keys!==16'h0011||nonzero<130||transitions<100)$fatal(1,"Bluetooth to synth / DAC path");
        mask(0);frames(500);if(dut.pcm!=0)$fatal(1,"Bluetooth release tail");
        param_out(6,1,0);frames(300);if(!dut.auto_mode)$fatal(1,"remote auto");
        param_out(6,0,0);frames(300);if(dut.auto_mode)$fatal(1,"remote manual");
        mask(16'h8000);frames(200);if(dut.live_keys!==16'h8000)$fatal(1,"highest note after mode change");
        mask(0);frames(500);if(dut.pcm!=0)$fatal(1,"final stop");
        $display("PASS Bluetooth end-to-end RTL: 9600 packets -> parameters -> chord PCM -> PT8211 data -> release; USB coexistence; remote auto/manual");$finish;
    end
    initial begin #300000000;$fatal(1,"timeout");end
endmodule
