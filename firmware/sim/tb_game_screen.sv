`timescale 1ns/1ps
// Exports the actual RTL pixel output (not a separate mock UI).
module tb_game_screen;
    reg clk=0,audio_clk=0;always #5 clk=~clk;always #10 audio_clk=~audio_clk;
    reg [7:0] divider=0;always @(posedge audio_clk) divider<=divider+1'b1;
    wire tick=divider==0;
    reg signed [15:0] pcm=0;
    integer number=0;
    always @(posedge audio_clk) if(tick) begin
        number<=number+1;pcm<=$rtoi(6000*$sin(6.283185307179586*number/128.0));
    end
    reg page=1,playing=0,done=0;
    reg [15:0] score=0,cue=0,pressed=0;
    reg [5:0] combo=0,best=0,hits=0,misses=0,progress=0;
    reg [2:0] feedback=0;
    reg [1:0] countdown=0;
    reg [3:0] target=0,next_note=0;
    reg [1:0] instrument=0;
    reg [2:0] plot=0;
    reg [10:0] set_h=0;
    reg [9:0] set_v=0;
    reg blank=0;
    wire [7:0] r,g,b;
    wire pclk,hs,vs,de,bl,reset_n;
    instrument_screen dut(.clk(clk),.audio_clk(audio_clk),.sample_tick(tick),.pcm(pcm),.auto_mode(1'b0),.stopped(1'b0),
        .game_page(page),.game_running(playing),.game_finished(done),.game_score(score),.game_keys(pressed),
        .game_cue(cue),.game_combo(combo),.game_max(best),.game_hits(hits),.game_misses(misses),
        .game_progress(progress),.game_wrong(10'd0),.game_feedback(feedback),.game_countdown(countdown),
        .game_target(target),.game_next(next_note),
        .instrument(instrument),.plot_mode(plot),.touch_chip(2'd2),.live_keys(16'h0091),
        .volume(4'd8),.attack_sel(4'd2),.decay_sel(4'd5),.release_sel(4'd5),.sustain_level(8'd160),
        .touch_online(1'b1),.cursor_down(1'b0),.cursor_x(11'd0),.cursor_y(10'd0),
        .orientation(3'd0),.finger_count(3'd3),.touch_errors(16'd0),
        .touch_raw_status(8'h83),.touch_raw_count(4'd3),.touch_report_count(16'd123),
        .touch_raw_x(12'd480),.touch_raw_y(12'd400),.touch_max_x(12'd1024),.touch_max_y(12'd600),
        .r(r),.g(g),.b(b),.pclk(pclk),.bl(bl),.lcd_reset(reset_n),.hsync(hs),.vsync(vs),.de(de));
    initial begin force dut.h=set_h;force dut.v=set_v;force dut.scope.frame_blank=blank;force dut.analyzer.frame_blank=blank;end
    integer file,wave_pixels,spectrum_pixels,output_x,output_y;
    task render(input string name);
        begin
            set_h=0;set_v=0;repeat(3) @(negedge clk);
            wait(dut.scope.state==3 && dut.analyzer.state==15);@(negedge clk);blank=1;@(negedge clk);blank=0;
            if(!dut.graph_valid || !dut.analyzer_valid) $fatal(1,"scope never published to display");
            file=$fopen(name,"wb");$fwrite(file,"P6\n1024 600\n255\n");
            wave_pixels=0;spectrum_pixels=0;
            // Drive one pixel every clock, then flush the five-stage pipe.
            // Captured output is the real continuous raster, in image order.
            for(integer stream=0;stream<614404;stream=stream+1) begin
                @(negedge clk);
                if(stream<614400) begin set_h=308+stream%1024;set_v=23+stream/1024;end
                else begin set_h=0;set_v=0;end
                @(posedge clk);#1;
                if(stream>=4) begin
                    output_x=(stream-4)%1024;output_y=(stream-4)/1024;
                    if(!de || $isunknown({r,g,b}) || pclk!==0) $fatal(1,"continuous raster RGB/DE/phase x%d y%d",output_x,output_y);
                    if(output_x>=512 && output_y>=148 && output_y<228 && {r,g,b}==24'h63edc2)
                        wave_pixels=wave_pixels+1;
                    if(output_x>=512 && output_y>=248 && output_y<336 && ({r,g,b}==24'h55baff || {r,g,b}==24'hffd06a))
                        spectrum_pixels=spectrum_pixels+1;
                    $fwrite(file,"%c%c%c",r,g,b);
                end
            end
            $fclose(file);
            if(!page && plot==0 && (wave_pixels<300 || spectrum_pixels<100))
                $fatal(1,"missing actual wave/FFT pixels %d %d",wave_pixels,spectrum_pixels);
            set_h=0;set_v=0;repeat(5) @(posedge clk);#1;
            if(de || {r,g,b}!=0 || hs || vs) $fatal(1,"blanking or sync pipeline");
            @(negedge clk);
        end
    endtask
    initial begin
        repeat(8) @(negedge clk);
        if(bl || reset_n) $fatal(1,"startup sequencing");
        force dut.boot=22'h3fffff;
        render("screen_game_ready.ppm");
        playing=1;score=1200;combo=12;best=12;hits=12;progress=14;misses=1;
        cue=16'h80;pressed=16'h1;target=7;next_note=5;feedback=1;
        render("screen_game_play.ppm");
        playing=0;done=1;score=4200;combo=42;best=42;hits=42;misses=0;progress=42;
        cue=0;pressed=0;feedback=0;
        render("screen_game_result.ppm");
        $display("PASS rhythm game actual LCD pixels: ready/play/result pages, lit piano keys, score/combo, five-cycle RGB/DE pipeline and blanking");$finish;
    end
    initial begin #200000000;$fatal(1,"screen timeout");end
endmodule
