`timescale 1ns/1ps
module tb_integration;
    // Pixel/XY logic has separate exhaustive render/plot tests.
    initial begin force dut.display.h=0; force dut.display.v=0; force dut.display.scope.audio_toggle=0; end
    defparam dut.song.TIME_SHIFT=2;
    reg k0=1,k1=1,uart=1,ea=1,eb=1,esw=1;
    tri [3:0] rows;
    wire bck,ws,din,pa;
    reg board_clk=0; always #10 board_clk=~board_clk;
    dualmode_top #(.PANEL_UI(0)) dut(.clk_50m(board_clk),.key0_n(k0),.key1_n(k1),.UART_RX(uart),.BT_RX(1'b1),.BT_TX(),
        .enc_a_n(ea),.enc_b_n(eb),.enc_sw_n(esw),.beam_broken(7'b0),.soft_touch(1'b0),.bend_touch(1'b0),.timbre_touch(1'b0),.fx_touch(1'b0),.TOUCH_DRIVE(),
        .HP_BCK(bck),.HP_WS(ws),.HP_DIN(din),.PA_EN(pa),.UART_TX());
    task clocks(input integer n); repeat(n) @(negedge dut.clk); endtask
    always @(posedge dut.clk) if(dut.sample_tick!==dut.i2s_sample_tick)
        $fatal(1,"PT8211 and I2S sample capture differ");
    task frames(input integer n); repeat(n) @(negedge dut.sample_tick); @(negedge dut.clk); endtask
    task send_byte(input [7:0] b);
        @(negedge dut.clk); uart=0; clocks(228);
        for(integer j=0;j<8;j=j+1) begin uart=b[j]; clocks(228); end
        uart=1; clocks(240);
    endtask
    task parameter_write(input [7:0] id,input [7:0] value);
        send_byte(8'hf5); send_byte(id); send_byte(value); send_byte(8'hf5^id^value);
    endtask
    task turn_right;
        {ea,eb}=2'b10; clocks(20000); {ea,eb}=0; clocks(20000);
        {ea,eb}=1; clocks(20000); {ea,eb}=3; clocks(20000);
    endtask
    task check_sound;
        integer nonzero;
        begin
            nonzero=0;
            repeat(200) begin frames(1); if(dut.pcm!=0) nonzero=nonzero+1; end
            if(nonzero<150) $fatal(1,"expected audible output");
        end
    endtask
    initial begin
        frames(2200); if(pa || dut.pcm!=0) $fatal(1,"startup");
        send_byte(8'h90); frames(600); check_sound();
        parameter_write(1,1); parameter_write(2,4); parameter_write(3,120);
        parameter_write(4,3); parameter_write(5,10); clocks(4);
        if(dut.attack_sel!=1 || dut.decay_sel!=4 || dut.sustain_level!=120 ||
           dut.release_sel!=3 || dut.volume!=10 || dut.param_count!=5)
            $fatal(1,"top parameter routing");
        send_byte(8'h94); frames(100); turn_right();
        if(dut.bend_target!=4 || dut.bend_cents!=10) $fatal(1,"top encoder routing");
        esw=0; frames(600); esw=1;
        if(dut.bend_cents!=0) $fatal(1,"top encoder reset");
        k0=0; frames(700); k0=1;
        if(!dut.auto_mode) $fatal(1,"physical KEY0");
        // Autoplay must work independently of the host app.
        frames(3200); check_sound();
        k1=0; frames(700); k1=1;
        if(dut.auto_mode) $fatal(1,"physical KEY1");
        frames(600); if(dut.pcm!=0) $fatal(1,"held key leaked across modes");
        send_byte(8'h80); frames(2); send_byte(8'h90); frames(600); check_sound();
        send_byte(8'hf0); frames(700); if(dut.pcm!=0) $fatal(1,"stop");
        $display("PASS top integration at 26.25MHz: UART ADSR/volume, EC11 target/reset, mode changes, release and unused matrix isolation");
        $finish;
    end
    initial begin #2000000000; $fatal(1,"integration timeout"); end
endmodule
