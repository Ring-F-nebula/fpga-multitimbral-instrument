`timescale 1ns/1ps
module tb_touch_ui;
    reg clk=0; always #5 clk=~clk;
    reg valid=0,key1=1,volume_event=0;
    reg [4:0] contacts=0;
    reg [59:0] xx=0,yy=0;
    reg [3:0] serial_volume=8;
    wire [15:0] keys;
    wire game_page,game_start;
    wire [1:0] instrument;
    wire [2:0] plot;
    wire [3:0] volume;
    wire ap,lp,sp,changed,down;
    wire [2:0] orientation,fingers;
    wire [10:0] cx;
    wire [9:0] cy;
    touch_ui #(.ORIENTATION_HOLD(12)) dut(clk,valid,key1,contacts,xx,yy,serial_volume,volume_event,
        keys,instrument,plot,volume,ap,lp,sp,changed,orientation,down,cx,cy,fingers,game_page,game_start);
    task frame(input integer x,input integer y,input bit pressed=1);
        @(negedge clk);contacts=pressed?1:0;xx=x;yy=y;valid=1;
        @(negedge clk);valid=0;
    endtask
    initial begin
        frame(50,550); if(keys!==1) $fatal(1,"C4 white");
        frame(120,420); if(keys!==2) $fatal(1,"C#4 black priority");
        @(negedge clk);xx={12'd800,12'd650,12'd530,12'd270,12'd50};
        yy={12'd550,12'd420,12'd550,12'd420,12'd550};contacts=31;valid=1;
        @(negedge clk);valid=0;
        if(fingers!=5 || keys!=(16'h1|16'h8|16'h80|16'h100|16'h800)) $fatal(1,"five-finger piano chord %h",keys);
        frame(300,70); if(instrument!=1 || !changed || !lp || keys) $fatal(1,"guitar tab");
        frame(100,390);if(keys!=1) $fatal(1,"open E2");
        frame(600,570);if(keys!=16'h800) $fatal(1,"fret2 F#4");
        frame(500,70);if(instrument!=2 || !changed) $fatal(1,"drum tab");
        frame(100,420);if(keys!=1) $fatal(1,"kick");
        frame(800,550);if(keys!=32) $fatal(1,"crash");
        frame(345,420);if(keys) $fatal(1,"drum gap must be silent");
        frame(400,200);if(volume!=9) $fatal(1,"volume +");
        frame(400,200);if(volume!=9) $fatal(1,"held button repeat");
        frame(0,0,0); frame(300,200);if(volume!=8) $fatal(1,"volume -");
        frame(930,112);if(plot!=1) $fatal(1,"plot selector");
        for(integer k=2;k<=5;k=k+1) begin
            frame(0,0,0);frame(930,112);
            if(plot!=(k%5)) $fatal(1,"five plot modes/wrap");
        end
        frame(810,70);if(!ap) $fatal(1,"auto mode button");
        frame(690,70);if(!sp || !lp || keys) $fatal(1,"stop");
        @(negedge clk);serial_volume=15;volume_event=1;
        @(negedge clk);volume_event=0;if(volume!=15) $fatal(1,"UART volume ownership");
        frame(0,0,0);frame(920,24);
        if(!game_page || instrument!=0 || !sp || !lp) $fatal(1,"game entry/piano routing");
        frame(0,0,0);frame(80,70);if(!game_start || !lp || keys) $fatal(1,"game START");
        frame(80,70);if(game_start) $fatal(1,"held START repeats");
        frame(300,70);if(!sp || !game_page) $fatal(1,"game STOP");
        frame(0,0,0);frame(500,70);if(volume!=14) $fatal(1,"game volume minus");
        frame(0,0,0);frame(700,70);if(volume!=15) $fatal(1,"game volume plus");
        frame(0,0,0);frame(50,550);if(keys!=1) $fatal(1,"game piano key map");
        frame(0,0,0);frame(920,24);if(game_page || sp || !lp) $fatal(1,"game BACK must resume live without STOP");
        frame(0,0,0);frame(500,70); // restore drums for the existing orientation check
        key1=0;repeat(20) @(negedge clk);
        if(orientation!=1) $fatal(1,"orientation long hold");
        repeat(20) @(negedge clk);if(orientation!=1) $fatal(1,"orientation must increment once per hold");
        key1=1;frame(923,420);if(keys!=1) $fatal(1,"mirrored kick");
        frame(0,0,0);if(keys || down || fingers) $fatal(1,"release all");
        $display("PASS touchscreen layout: piano black/white, five-point chords, guitar strings/fret, six drums, mode/stop/volume/plot and orientation");
        $finish;
    end
endmodule
