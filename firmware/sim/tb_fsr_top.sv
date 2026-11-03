`timescale 1ns/1ps
// Actual scan/CDC/synth/effects/DAC logic; analog conversion, LCD pixels and
// functional PLL timing use explicitly named digital test bindings.
module tb_fsr_top;
    reg board_clk=0; always #10 board_clk=~board_clk;
    reg [6:0] beams=0;
    reg [13:0] codes[0:15];
    reg [13:0] analog_code=0;
    wire [3:0] select; wire enable_n;
    dualmode_top #(.PANEL_UI(0),.ENABLE_LASER_INPUTS(1)) dut(.clk_50m(board_clk),.key0_n(1'b1),.key1_n(1'b1),
        .UART_RX(1'b1),.BT_RX(1'b1),.enc_a_n(5'h1f),.enc_b_n(5'h1f),.enc_sw_n(1'b1),
        .beam_broken(beams),.soft_touch(1'b0),.bend_touch(1'b0),
        .timbre_touch(1'b0),.fx_touch(1'b0),.FSR_SELECT(select),.FSR_EN_N(enable_n));
    // The keyboard bench exercises all 32 calibration scans. Shorten this
    // digital integration fixture; it does not measure hardware latency.
    defparam dut.pressure_keys.CALIBRATION_LOG2=1;
    // Speed up only the digital ADC/settle surrogate. The scanner bench
    // independently tests ordering, settling and timeout; no analog claim.
    defparam dut.fsr_adc.scan.SETTLE_CYCLES=20;
    defparam dut.fsr_adc.adc_i.CONVERSION_CYCLES=128;
    always @* analog_code=codes[select];
    initial begin
        force dut.display.h=0; force dut.display.v=0; force dut.display.scope.audio_toggle=0;
        force dut.fsr_adc.adc_value=analog_code;
    end
    task frames(input integer n);
        repeat(n) @(negedge dut.sample_tick); @(negedge dut.clk);
    endtask
    task audible;
        integer heard;
        heard=0;
        repeat(120) begin frames(1); if(dut.pcm!=0) heard=heard+1; end
        if(heard<85) $fatal(1,"no sustained PCM from held input: %0d",heard);
    endtask
    initial begin
        for(integer i=0;i<16;i=i+1) codes[i]=0;
        frames(2200);
        if(!dut.fsr_ready || dut.fsr_keys || dut.live_keys || dut.pcm!=0)
            $fatal(1,"unpressed startup");
        force dut.touch_keys=16'h0004; frames(400); audible();
        if(dut.live_keys!=4 || dut.note_gains[18 +: 9]!=256) $fatal(1,"screen independence");
        release dut.touch_keys; frames(2500);
        codes[0]=32; codes[4]=64; frames(400); audible();
        if(dut.fsr_keys!=3 || dut.live_keys!=3 || dut.note_gains[0 +: 9]!=128 || dut.note_gains[9 +: 9]!=256)
            $fatal(1,"FSR alone must play two independent notes");
        codes[0]=0; frames(400);
        if(dut.fsr_keys!=2 || dut.live_keys!=2) $fatal(1,"independent release K=%h live=%h",dut.fsr_keys,dut.live_keys);
        codes[0]=32; frames(400); beams=1; frames(400);
        if(dut.note_gains[0 +: 9]!=256 || dut.live_keys!=3) $fatal(1,"shared note normal-source priority");
        force dut.fsr_adc.adc_ready=1'b0; frames(400); audible();
        if(!dut.fsr_fault || dut.fsr_keys!=0 || dut.live_keys!=1)
            $fatal(1,"ADC fault must preserve other input sources");
        release dut.fsr_adc.adc_ready; frames(800);
        if(dut.fsr_fault || !dut.fsr_ready || dut.fsr_keys!=0) $fatal(1,"held pressure must not retrigger after fault");
        // Recovery while held deliberately keeps a held-at-recovery baseline.
        // Explicit calibration with hands away is needed to reacquire zero.
        codes[0]=0;codes[4]=0;
        force dut.pressure_keys.recalibrate=1'b1;frames(1);
        release dut.pressure_keys.recalibrate;frames(800);
        codes[0]=32;codes[4]=64;frames(400);
        if(dut.fsr_keys!=3) $fatal(1,"new pressure after recalibration K=%h cal=%h base0=%d base1=%d on0=%d on1=%d",dut.fsr_keys,dut.fsr_calibrated_mask,dut.pressure_keys.baseline[0],dut.pressure_keys.baseline[1],dut.pressure_keys.on_delta[0],dut.pressure_keys.on_delta[1]);
        beams=0; codes[0]=0; codes[4]=0; frames(2500);
        if(dut.live_keys || dut.pcm!=0) $fatal(1,"release all notes");
        force dut.fsr_adc.adc_ready=1'b0; frames(400);
        force dut.touch_keys=16'h0010; frames(500); audible();
        if(dut.live_keys!=16 || dut.fsr_keys) $fatal(1,"screen works through ADC fault");
        $display("PASS FSR keyboard top: pressure-alone polyphony, independent half/full velocity, release, screen without pressure, laser/shared-note coexistence, ADC fault preserves other sources, recovery and silence");
        $finish;
    end
    initial begin #1200000000; $fatal(1,"FSR integration timeout"); end
endmodule
