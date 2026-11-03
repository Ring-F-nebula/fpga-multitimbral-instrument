`timescale 1ns/1ps
module tb_native_display;
GSR GSR(1'b1);
reg clk=0;always #5 clk=~clk;
reg [8:0] divider=0;always @(posedge clk)divider<=divider+1'b1;
wire tick=divider==0;wire signed [15:0] pcm;reg blank=0;
reg [31:0] engine_keys=32'h80010001;reg engine_test=0;reg [1:0] engine_instrument=0;reg [255:0] engine_notes;wire [5:0] engine_active;
reg [3:0] adsr_a=0,adsr_d=5,adsr_r=5;reg [7:0] adsr_s=160;
poly32_synth audio_source(.clk(clk),.sample_tick(tick),.clear(1'b0),.keys(engine_keys),.note_numbers(engine_notes),.voice_gains({32{9'd192}}),.instrument(engine_instrument),
 .song_gate(1'b0),.song_step(24'd0),.volume(4'd8),.mode_gain(engine_test?9'd91:9'd256),.attack_sel(adsr_a),.decay_sel(adsr_d),.release_sel(adsr_r),.sustain_level(adsr_s),
 .expression_bend(9'sd100),.expression_vibrato(7'd40),.target_voice(5'd31),.fx_params(128'd0),.test_mode(engine_test),.test_voice_count(engine_test?6'd32:6'd0),.pcm(pcm),.active_count(engine_active));
reg [255:0] info=0;reg [2:0] view=0;reg [2:0] page=0;reg [10:0] h=0;reg [9:0] v=0;
reg [127:0] fx={8'd0,8'd100,8'd32,8'd35,8'd55,8'd5,8'd115,8'd5,8'd70,8'd115,8'd70,8'd12,8'd102,8'd128,8'd24,8'h00};
wire [7:0] r,g,b;wire de,hs,vs,pclk;reg [223:0] pressures;
instrument_screen #(.SHOW_FSR(1),.PANEL_UI(1)) dut(.clk(clk),.audio_clk(clk),.sample_tick(tick),.pcm(pcm),
 .performance_info({info[255:46],(engine_test?6'd32:6'd0),info[39:38],engine_active,engine_keys}),.panel_page(page),.fx_params(fx),.panel_bend(9'sd0),.selected_pad(4'd10),.selected_raw(14'd84),.selected_baseline(14'd20),.selected_threshold(14'd16),.selected_gain(9'd256),
 .fsr_pressures(pressures),.bt_rx_count(16'd128),.game_position(11'sd180),
 .fsr_ready(1'b1),.fsr_fault(1'b0),.fsr_calibrating(1'b0),.fsr_peak(14'd420),.fsr_keys(16'h0411),.fsr_delta(14'd64),.fsr_threshold(14'd16),.fsr_cal_mask(16'hffff),
 .auto_mode(1'b0),.stopped(1'b0),.game_page(page==3),.game_running(1'b1),.game_finished(1'b0),.game_score(16'd1250),.game_keys(16'h0010),.game_cue(16'h0010),
 .game_combo(6'd12),.game_max(6'd12),.game_hits(6'd13),.game_misses(6'd0),.game_progress(6'd13),.game_wrong(10'd0),.game_feedback(3'd1),.game_countdown(2'd0),.game_target(4'd4),.game_next(4'd5),
 .instrument(engine_instrument),.touch_chip(2'd1),.plot_mode(view),.live_keys(16'h0411),.volume(4'd8),.attack_sel(adsr_a),.decay_sel(adsr_d),.sustain_level(adsr_s),.release_sel(adsr_r),
 .touch_online(1'b1),.cursor_down(1'b0),.cursor_x(11'd0),.cursor_y(10'd0),.orientation(3'd0),.finger_count(3'd0),.touch_errors(16'd0),
 .touch_raw_status(8'd0),.touch_raw_count(4'd0),.touch_report_count(16'd128),.touch_raw_x(12'd0),.touch_raw_y(12'd0),.touch_max_x(12'd1023),.touch_max_y(12'd599),
 .r(r),.g(g),.b(b),.de(de),.hsync(hs),.vsync(vs),.pclk(pclk));
initial begin force dut.h=h;force dut.v=v;force dut.boot=22'h3fffff;force dut.analyzer.frame_blank=blank;force dut.scope.frame_blank=blank;end
integer f,p,s,ink,white,wave_pixels,spectrum_pixels,capture=-1;
task render(input integer pg,mode);
begin
 page=pg;view=mode;h=0;v=0;repeat(1200)@(negedge clk);
 if(dut.native_panel.panel.page_q!=pg)$fatal(1,"page CDC");
 if(pg==2)begin
  if(dut.native_panel.panel.bcd[10]!=20'h00240||dut.native_panel.panel.bcd[11]!=20'h00050||dut.native_panel.panel.bcd[12]!=20'h00040||
     dut.native_panel.panel.bcd[13]!=20'h00012||dut.native_panel.panel.bcd[14]!=20'h00070||dut.native_panel.panel.bcd[15]!=20'h00045||
     dut.native_panel.panel.bcd[16]!=20'h00070||dut.native_panel.panel.bcd[17]!=20'h02400||dut.native_panel.panel.bcd[18]!=20'h00045)$fatal(1,"strong defaults LCD numeric values");
 end
 if(capture>=11&&capture<=14)begin
  if(dut.native_panel.panel.adsr_match_q!==(capture==14?3'b000:3'b001<<(capture-11)))$fatal(1,"preset highlight must match actual registers");
 end
 if(dut.native_panel.panel.bcd[19]!=(engine_test?20'h00032:20'h00003) || dut.native_panel.panel.bcd[20]!=20'h45573)$fatal(1,"real engine/decimal telemetry");
 f=$fopen(capture>=11?$sformatf("screen_adsr_%0d.ppm",capture-11):engine_instrument==1?$sformatf("screen_guitar_view_%0d.ppm",mode):pg!=0?$sformatf("screen_page_%0d.ppm",pg):mode==0?"screen_native_0.ppm":$sformatf("screen_view_%0d.ppm",mode),"wb");$fwrite(f,"P6\n1024 600\n255\n");ink=0;white=0;wave_pixels=0;spectrum_pixels=0;
 for(s=0;s<614405;s++)begin
 @(negedge clk);if(s<614400)begin h=308+s%1024;v=23+s/1024;end else begin h=0;v=0;end
 @(posedge clk);#1;
 if(s>=5)begin
 if(!de || $isunknown({r,g,b}))$fatal(1,"invalid pixel/DE page %0d stream %0d",pg,s);
 if({r,g,b}==24'h343a50)ink++;if({r,g,b}==24'hffffff)white++;
 if({r,g,b}==24'h8d9ee4 && pg==0)wave_pixels++;
 if({r,g,b}==24'h7095d7 && pg==0)spectrum_pixels++;
 $fwrite(f,"%c%c%c",r,g,b);
 end
 end
 $fclose(f);if(ink<3500 || white<30000)$fatal(1,"text/background absent %d %d",ink,white);
 if(pg==0 && mode==0 && wave_pixels<300)$fatal(1,"actual PCM waveform absent");
 if(pg==0 && mode!=0 && spectrum_pixels<50)$fatal(1,"actual PCM spectrum absent");
 repeat(8)@(negedge clk);if(de || {r,g,b}!==0)$fatal(1,"blanking");
 $display("PASS native_display view %0d: real RGB/DE pipeline, Chinese ROM, dynamic digits, %0d text pixels",mode,ink);
end endtask
initial begin
 if($value$plusargs("CAPTURE=%d",capture))begin if(capture<0||capture>14)$fatal(1,"capture selection");end
 case(capture)
  11:begin adsr_a=7;adsr_d=8;adsr_s=192;adsr_r=9;end
  12:begin adsr_a=0;adsr_d=6;adsr_s=0;adsr_r=5;end
  13:begin adsr_a=9;adsr_d=8;adsr_s=255;adsr_r=9;end
  14:begin adsr_a=8;adsr_d=8;adsr_s=255;adsr_r=9;end
 endcase
 for(p=0;p<32;p++)engine_notes[p*8+:8]=60+p;info[31:0]=32'h80010001;info[37:32]=32;info[39]=1;info[45:40]=32;info[54:46]=192;info[63:55]=100;info[70:64]=40;info[78:71]=120;info[80:79]=1;info[93:84]=64;info[101:94]=42;info[106:102]=31;info[108]=1;info[116:109]=13;info[124:117]=42;info[216:210]=48;info[220]=1;info[221]=1;info[238]=1;info[135:128]=91;info[255:240]=12;info[237:233]=10;
 if(capture==7)begin info[82]=1;info[217]=1;end
 for(p=0;p<16;p++)pressures[p*14+:14]=20+p*7;
 // Per-pad calibration can have different idle baselines. Pad 1 uses 356;
 // pads 5/11 use 20, giving the same 64-code net pressure at this snapshot.
 pressures[0*14+:14]=420;pressures[4*14+:14]=84;pressures[10*14+:14]=84;
 if(capture==4)begin engine_test=1;engine_keys=32'hffffffff;end
 if(capture>=8&&capture<=10)begin
  engine_instrument=1;engine_keys=32'h01108000;info[228:226]=1;
  // Deliberately leave legacy info[229] low: it must never hide the analyzer.
  for(p=0;p<32;p++)engine_notes[p*8+:8]=40+p;
 end
 repeat(8)@(negedge clk);wait(dut.analyzer.state==15);@(negedge clk);blank=1;@(negedge clk);blank=0;
 if(!dut.analyzer_valid)$fatal(1,"waveform never published");
 wait(dut.scope.state==3);@(negedge clk);blank=1;@(negedge clk);blank=0;
 for(p=0;p<3;p++)if(capture<0||capture==p||capture==8+p)render(0,p);if(capture<0||capture==3)render(3,0);
 if(capture<0||capture==5)render(1,0);
 if(capture>=11&&capture<=14)render(1,0);
 if(capture<0||capture==6)render(2,0);
 if(capture<0||capture==7)render(5,0);
 if(capture<0||capture==4)begin
 engine_test=1;engine_keys=32'hffffffff;
 // Publish a fresh FFT block generated by all 32 actual sine DDS voices.
 @(negedge clk);blank=1;@(negedge clk);blank=0;wait(dut.analyzer.state!=15);wait(dut.analyzer.state==15);
 @(negedge clk);blank=1;@(negedge clk);blank=0;render(4,0);
 end
 $display("PASS native_display: actual PCM/RGB capture selection %0d",capture);$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
config cfg_tb_native_display;
 design work.tb_native_display;default liblist work;
 cell work.text_cell use work.legacy_text_test_stub;
 cell work.game_screen use work.legacy_game_test_stub;
 cell work.status_decimal use work.legacy_decimal_test_stub;
endconfig
