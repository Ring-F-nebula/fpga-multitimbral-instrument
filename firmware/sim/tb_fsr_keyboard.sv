`timescale 1ns/1ps
module tb_fsr_keyboard;
    reg clk=0;always #5 clk=~clk;
    reg reset_n=0,tick=0,toggle=0,online=0,recalibrate=0;
    reg [223:0] samples=0;
    wire [15:0] keys,calibrated;
    wire [143:0] gains;wire [223:0] pressures;
    wire [13:0] peak;wire ready,calibrating,fault;
    reg [13:0] source_peak;
    always @* begin
        source_peak=0;
        for(integer j=0;j<16;j=j+1) if(samples[j*14 +: 14]>source_peak) source_peak=samples[j*14 +: 14];
    end
    fsr_keyboard #(.STALE_CYCLES(5000),.ON_DELTA_MIN(64),.OFF_DELTA_MIN(32),.GAIN_SHIFT(1)) dut(.clk(clk),.reset_n(reset_n),.sample_tick(tick),.recalibrate(recalibrate),
        .samples_async(samples),.peak_async(source_peak),.frame_toggle_async(toggle),.online_async(online),
        .keys(keys),.gains(gains),.pressures(pressures),.peak(peak),.ready(ready),
        .calibrating(calibrating),.fault(fault),.calibrated_mask(calibrated));
    integer map[0:15]='{0,4,11,15,1,5,10,14,2,6,9,13,3,7,8,12};
    reg [13:0] base[0:15];
    task clocks(input integer n);repeat(n) @(negedge clk);endtask
    task publish;@(negedge clk);toggle=~toggle;clocks(30);endtask
    task rest;for(integer i=0;i<16;i=i+1) samples[map[i]*14 +: 14]=base[i];endtask
    task press(input integer pad,input integer delta);samples[map[pad]*14 +: 14]=base[pad]+delta;endtask
    task restart;reset_n=0;toggle=0;clocks(3);reset_n=1;online=1;clocks(4);endtask
    task calibrate;
        repeat(34) publish();
        if(!ready || fault || calibrated!=16'hffff || keys) $fatal(1,"calibration did not settle");
    endtask
    task ticks(input integer n);repeat(n) begin tick=1;clocks(1);tick=0;clocks(1);end endtask
    initial begin
        for(integer i=0;i<16;i=i+1) base[i]=100+i*13;
        rest();restart();
        repeat(33) begin publish();if(keys || ready) $fatal(1,"premature calibration");end
        publish();if(keys || !ready || calibrated!=16'hffff) $fatal(1,"startup calibration");
        // A quiet run followed by one large spike sounded a key previously.
        press(0,800);publish();if(keys) $fatal(1,"isolated high spike sounded");
        rest();publish();if(keys) $fatal(1,"spike release sounded");
        for(integer i=0;i<16;i=i+1) begin
            rest();publish();press(i,256);publish();if(keys) $fatal(1,"one-scan attack");publish();
            if(keys!==(16'b1<<i) || gains[i*9 +: 9]!=128 || pressures[i*14 +: 14]!=base[i]+256)
                $fatal(1,"pad %0d mapping/baseline/velocity",i);
        end
        rest();publish();press(0,256);press(1,512);publish();publish();
        if(keys!=3 || gains[0 +: 9]!=128 || gains[9 +: 9]!=256) $fatal(1,"independent polyphony");
        press(0,384);publish();ticks(20);
        if(gains[0 +: 9]!=148 || gains[9 +: 9]!=256) $fatal(1,"pressure slew");
        press(0,33);publish();if(!keys[0]) $fatal(1,"hysteresis hold");
        press(0,32);publish();if(keys[0] || gains[0 +: 9]!=148) $fatal(1,"release tail gain");
        rest();publish();press(0,64);publish();if(keys[0]) $fatal(1,"light debounce");
        publish();if(!keys[0] || gains[0 +: 9]!=32) $fatal(1,"confirmed light touch");
        // P is hexadecimal. Cover 0x100..0x2ff independent idle excursions.
        restart();
        publish();publish(); // Discard pre-calibration/in-flight sweeps.
        for(integer f=0;f<32;f=f+1) begin
            for(integer i=0;i<16;i=i+1) samples[map[i]*14 +: 14]=256+((f+i)%2)*511;
            publish();if(keys) $fatal(1,"noisy idle during calibration");
        end
        if(!ready || fault) $fatal(1,"bounded noise calibration failed");
        for(integer f=0;f<400;f=f+1) begin
            for(integer i=0;i<16;i=i+1) samples[map[i]*14 +: 14]=256+((f*17+i*31)%512);
            publish();if(keys) $fatal(1,"noisy idle produced phantom keys f=%0d K=%h",f,keys);
        end
        // Noise-aware velocity must not saturate immediately at onset.
        samples[0 +:14]=850;publish();publish();
        if(keys!=1 || gains[0 +:9]<32 || gains[0 +:9]>65) $fatal(1,"noisy light touch");
        samples[0 +:14]=1184;publish();ticks(200);
        if(keys!=1 || gains[0 +:9]<180) $fatal(1,"noisy heavy touch");
        samples[0 +:14]=400;publish();if(keys) $fatal(1,"noisy release");
        recalibrate=1;clocks(1);recalibrate=0;
        for(integer i=0;i<16;i=i+1) base[i]=100+i*13;
        rest();calibrate();
        for(integer i=0;i<16;i=i+1) press(i,256);
        publish();publish();if(keys || !fault || calibrated) $fatal(1,"common-mode jump sounded");
        rest();calibrate();
        for(integer i=0;i<8;i=i+1) press(i,256);publish();publish();
        for(integer i=8;i<16;i=i+1) press(i,512);publish();publish();
        if(keys!=16'hffff) $fatal(1,"16-note staggered polyphony");
        samples[map[5]*14 +:14]=14'h3fff;publish();
        if(keys!=(16'hffff & ~(16'b1<<5)) || !fault) $fatal(1,"invalid channel isolation");
        online=0;clocks(8);if(keys || ready || calibrated) $fatal(1,"ADC source loss");
        online=1;clocks(8);rest();calibrate();
        press(0,512);publish();publish();if(keys!=1) $fatal(1,"fresh key after recovery");
        clocks(5010);if(keys || ready || calibrated) $fatal(1,"stopped source watchdog");
        rest();calibrate();
        @(negedge clk);toggle=~toggle;clocks(8);toggle=~toggle;clocks(35);
        if(keys || !fault) $fatal(1,"mailbox overrun not inhibited");
        reset_n=0;clocks(2);if(keys || ready || gains!=0) $fatal(1,"reset");
        $display("PASS FSR16 fix: 32-scan noise window, 0x100..0x2ff idle silence, isolated spikes, 16 mappings, two-scan attacks, per-key light/heavy pressure/slew, release, recalibration, 16-note polyphony, common-mode/rail/source-loss guards");
        $finish;
    end
    initial begin #3000000;$fatal(1,"keyboard timeout");end
endmodule
