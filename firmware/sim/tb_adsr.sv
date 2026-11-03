`timescale 1ns/1ps
// Independent real-valued envelope oracle: no DUT rate table is reused.
module tb_adsr;
    reg clk=0; always #5 clk=~clk;
    reg tick=1,clear=0,gate=0;
    reg [3:0] a=0,d=0,r=0;
    reg [7:0] s=160;
    wire [15:0] level;
    wire [2:0] state;
    adsr_envelope dut(clk,tick,clear,gate,a,d,r,s,level,state);
    integer cases=0,checks=0;
    function integer duration(input integer sel);
        integer ms;
        begin
            case(sel)
                0:ms=1;1:ms=2;2:ms=5;3:ms=10;4:ms=20;
                5:ms=50;6:ms=100;7:ms=200;8:ms=500;default:ms=1000;
            endcase
            duration=$rtoi(26250000.0*ms/576000.0+0.5);
        end
    endfunction
    task step;
        @(posedge clk); #1; @(negedge clk);
    endtask
    task reset;
        clear=1; step(); clear=0; gate=0; step();
        if(level!==0 || state!==0) $fatal(1,"clear failed");
    endtask
    task close_to(input real expected,input integer tag);
        real error;
        begin
            error=level-expected;
            if(error>2.01 || error< -2.01)
                $fatal(1,"linear ramp tag=%0d level=%0d expected=%f",tag,level,expected);
            checks=checks+1;
        end
    endtask
    initial begin : test
        integer n,start_value,target_value,held;
        @(negedge clk);
        for(integer sel=0;sel<16;sel=sel+1) begin
            reset(); a=sel;d=sel;r=sel;s=64+sel*7;
            n=duration(sel);
            gate=1; step();
            if(state!=1 || level!=0) $fatal(1,"attack did not start continuously");
            for(integer i=1;i<=n;i=i+1) begin
                if(i==n/3) a=0; // An in-flight phase must retain its time.
                step(); close_to(65535.0*i/n,100+sel);
            end
            if(level!=65535) $fatal(1,"attack endpoint");
            step(); target_value=s*257;
            if(state!=2 || level!=65535) $fatal(1,"decay entry");
            for(integer i=1;i<=n;i=i+1) begin
                if(i==n/3) d=0;
                step(); close_to(65535.0+(target_value-65535.0)*i/n,200+sel);
            end
            step();
            if(state!=3 || level!=target_value) $fatal(1,"sustain endpoint");
            repeat(11) begin step(); if(level!=target_value) $fatal(1,"sustain drift"); end
            // Live sustain change must ramp continuously instead of jump.
            s=220;d=0;start_value=level;step();
            if(level!=start_value || state!=2) $fatal(1,"sustain edit jumped");
            repeat(46) step();step();
            if(level!=220*257 || state!=3) $fatal(1,"live sustain target");
            gate=0;start_value=level;step();
            if(level!=start_value || state!=4) $fatal(1,"release entry jumped");
            for(integer i=1;i<=n;i=i+1) begin
                if(i==n/3) r=0;
                step();close_to(start_value*(1.0-i*1.0/n),300+sel);
            end
            step(); if(level!=0 || state!=0) $fatal(1,"release endpoint");
            cases=cases+1;
        end
        // Early release during A; release uses the current amplitude.
        reset();a=4;d=2;r=1;s=100;gate=1;step();repeat(41)step();
        start_value=level;gate=0;step();
        if(state!=4 || level!=start_value) $fatal(1,"early release discontinuity");
        repeat(20)step();held=level;
        gate=1;step();
        if(state!=1 || level!=held) $fatal(1,"retrigger discontinuity");
        repeat(30)step();if(level<=held) $fatal(1,"retrigger not rising");
        // Clear in attack, decay, sustain, release, and reattack a held key.
        for(integer stage=1;stage<=4;stage=stage+1) begin
            reset();a=0;d=0;r=0;s=100;gate=1;step();
            if(stage>=2) begin repeat(46)step();step();end
            if(stage>=3) begin repeat(46)step();step();end
            if(stage==4) begin gate=0;step();repeat(7)step();end
            if(state!=stage) $fatal(1,"clear setup stage %0d",stage);
            clear=1;step();if(level!=0 || state!=0) $fatal(1,"clear stage %0d",stage);
            clear=0;gate=1;step();if(state!=1) $fatal(1,"held gate after clear");
        end
        // Zero sustain is silent while held; full sustain has no decay loss.
        for(integer extreme=0;extreme<=1;extreme=extreme+1) begin
            reset();a=0;d=0;r=0;s=extreme?255:0;gate=1;step();
            repeat(94)step();
            if(level!=(extreme?65535:0) || state!=3) $fatal(1,"S extreme");
            gate=0;step();repeat(48)step();if(level!=0) $fatal(1,"extreme release");
        end
        // Tick enable: system clock cycles between samples must not move ADSR.
        reset();gate=1;step();repeat(3)step();held=level;tick=0;
        repeat(20)step();if(level!=held) $fatal(1,"envelope updated without sample tick");
        $display("PASS ADSR cases=%0d linear_checks=%0d all 16 selectors, latched times, live S, early off, retrigger, clear, tick enable",cases,checks);
        $finish;
    end
    initial begin #50000000;$fatal(1,"timeout");end
endmodule
