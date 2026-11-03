`timescale 1ns/1ps
// Reproduce the hardware report with a constant high idle ADC value, then
// rail garbage: neither may press keys or silence the ordinary touch source.
module tb_fsr_guard_top;
    reg board_clk=0;always #10 board_clk=~board_clk;
    reg [13:0] analog_code=1056;
    reg [6:0] unused_beams=7'h7f;
    reg [3:0] unused_pads=4'hf;
    dualmode_top #(.PANEL_UI(0)) dut(.clk_50m(board_clk),.key0_n(1'b1),.key1_n(1'b1),
        .UART_RX(1'b1),.BT_RX(1'b1),.enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),
        .beam_broken(unused_beams),.soft_touch(unused_pads[0]),.bend_touch(unused_pads[1]),
        .timbre_touch(unused_pads[2]),.fx_touch(unused_pads[3]));
    defparam dut.pressure_keys.CALIBRATION_LOG2=1;
    defparam dut.fsr_adc.scan.SETTLE_CYCLES=20;
    defparam dut.fsr_adc.adc_i.CONVERSION_CYCLES=128;
    initial begin
        force dut.display.h=0;force dut.display.v=0;force dut.display.scope.audio_toggle=0;
        force dut.fsr_adc.adc_value=analog_code;
    end
    task frames(input integer n);
        repeat(n) @(negedge dut.sample_tick);@(negedge dut.clk);
    endtask
    task audible;
        integer heard;
        heard=0;repeat(100) begin frames(1);if(dut.pcm!=0) heard=heard+1;end
        if(heard<70) $fatal(1,"ordinary source muted by pressure guard");
    endtask
    initial begin
        frames(3300);
        if(!dut.fsr_ready || dut.fsr_keys || dut.live_keys || dut.pcm!=0 || dut.display.live_keys)
            $fatal(1,"high idle produces noise/lit keys");
        force dut.touch_keys=16'h0004;frames(500);audible();
        if(dut.live_keys!=4) $fatal(1,"screen input lost after high-idle calibration");
        analog_code=14'h3fff;frames(1700);audible();
        if(!dut.fsr_input_fault || dut.fsr_keys || dut.live_keys!=4 || dut.clear)
            $fatal(1,"rail garbage interferes with normal input/UI");
        analog_code=1056;frames(4000);audible();
        if(!dut.fsr_ready || dut.fsr_input_fault || dut.fsr_keys || dut.live_keys!=4)
            $fatal(1,"recovery generated phantom keys");
        release dut.touch_keys;frames(3000);
        if(dut.pcm!=0 || dut.live_keys || dut.display.live_keys) $fatal(1,"final release");
        repeat(8) begin
            unused_beams=~unused_beams;unused_pads=~unused_pads;frames(200);
            if(dut.live_keys || dut.pad_controls || dut.clear || dut.pcm!=0)
                $fatal(1,"unused legacy inputs reached safe profile audio");
        end
        force dut.ui_stop=1'b1;frames(1);release dut.ui_stop;frames(400);
        force dut.fsr_keys=16'h1190;force dut.touch_keys=16'h0001;frames(500);
        if(!dut.performance_stopped || dut.live_keys || dut.pcm!=0) $fatal(1,"STOP latch failed");
        force dut.fsr_keys=16'h0020;frames(300);
        if(dut.live_keys || dut.pcm!=0) $fatal(1,"sensor transition restarted STOP");
        force dut.fsr_keys=16'h0000;force dut.touch_keys=16'h0000;
        force dut.ui_live=1'b1;frames(1);release dut.ui_live;frames(400);
        force dut.touch_keys=16'h0001;frames(400);audible();
        if(dut.performance_stopped || dut.live_keys!=1) $fatal(1,"LIVE resume");
        release dut.fsr_keys;release dut.touch_keys;frames(3000);
        force dut.press1=1'b1;frames(1);release dut.press1;
        if(dut.fsr_ready || dut.fsr_keys) $fatal(1,"KEY1 did not restart calibration");
        $display("PASS hardware-failure regression: all 16 ADC channels idle at 1056 -> no noise/no lit keys; saturated input -> FSR inhibited, screen audio/UI retained; stable recalibration -> no phantom retrigger");
        $display("PASS FSR safe profile: unused laser/RC inputs isolated, screen releases to exact PCM zero, STOP remains silent through new 0x1190/random keys, LIVE resumes, KEY1 recalibrates");
        $finish;
    end
    initial begin #600000000;$fatal(1,"guard top timeout");end
endmodule
