`timescale 1ns/1ps
module tb_lcd_status;
    reg clk=0,auto=0,ready=0,active=0;
    reg [15:0] keys=0;
    reg [3:0] vol=8,a=1,d=2,rr=3;
    reg [7:0] ss=160;
    wire [7:0] red,green,blue;
    wire pclk,hs,vs,de,bl,rst;
    always #9.5238095 clk=~clk; // 52.5 MHz
    lcd_status dut(.clk(clk),.auto_mode(auto),.live_keys(keys),
        .volume(vol),.attack_sel(a),.decay_sel(d),.sustain_level(ss),
        .release_sel(rr),.sensor_ready(ready),.sensor_active(active),
        .r(red),.g(green),.b(blue),.pclk(pclk),.hsync(hs),
        .vsync(vs),.de(de),.bl(bl),.lcd_reset(rst));
    integer pixels;
    initial begin
        if(de || bl || rst) $fatal(1,"LCD must stay reset/blank at boot");
        dut.boot=22'd2097150;
        repeat(3) @(negedge clk);
        if(!bl || !rst) $fatal(1,"LCD boot sequencing");
        dut.h=1343; dut.v=634;
        @(negedge clk);
        if(dut.h!==0 || dut.v!==0) $fatal(1,"frame wrap");
        dut.h=307; dut.v=23; keys=16'h0001; ready=1;
        repeat(3) @(negedge clk);
        dut.h=307;
        pixels=0;
        repeat(1025) begin
            @(negedge clk);
            if(de) pixels=pixels+1;
            if(de && (red==0 && green==0 && blue==0))
                $fatal(1,"active pixels cannot be black");
        end
        if(pixels!=1024) $fatal(1,"active width %0d, expected 1024",pixels);
        dut.h=308; dut.v=22;
        @(negedge clk);
        if(de) $fatal(1,"vertical porch");
        dut.h=308; dut.v=23;
        @(negedge clk);
        if(!de) $fatal(1,"first visible line");
        dut.h=308; dut.v=622;
        @(negedge clk);
        if(!de) $fatal(1,"last visible line");
        dut.h=308; dut.v=623;
        @(negedge clk);
        if(de) $fatal(1,"first blank line");
        if(pclk!==~clk) $fatal(1,"pixel clock phase");
        if(dut.status_char(1,6,0,1,0,0,8,1,2,3,160)!="M" ||
           dut.status_char(1,7,0,1,0,0,8,1,2,3,160)!="A" ||
           dut.status_char(1,8,0,1,0,0,8,1,2,3,160)!="N")
            $fatal(1,"manual-mode text");
        if(dut.status_char(5,8,0,1,0,0,8,1,2,3,160)!="R" ||
           dut.status_char(5,9,0,1,0,0,8,1,2,3,160)!="E" ||
           dut.status_char(5,10,0,1,0,0,8,1,2,3,160)!="A" ||
           dut.status_char(5,11,0,1,0,0,8,1,2,3,160)!="D" ||
           dut.status_char(5,12,0,1,0,0,8,1,2,3,160)!="Y")
            $fatal(1,"sensor READY text");
        $display("PASS LCD 1024x600 DE geometry, 52.5MHz phase, startup and RGB");
        $finish;
    end
endmodule
