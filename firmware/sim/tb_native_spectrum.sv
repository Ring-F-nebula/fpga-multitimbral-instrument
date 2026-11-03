`timescale 1ns/1ps
module tb_native_spectrum;
GSR GSR(1'b1);
reg clk=0;always #5 clk=~clk;
reg [5:0] divider=0;always @(posedge clk)divider<=divider+1'b1;
wire tick=divider==0;reg signed [15:0] pcm=0;integer sample_number=0;integer tone_bin=8;reg blank=0;
always @(posedge clk)if(tick)begin sample_number<=sample_number+1;pcm<=$rtoi(tone_bin==0?0:6000*$sin(6.283185307179586*tone_bin*sample_number/1024.0));end
reg [2:0] view=1;reg [2:0] page=0;reg [10:0] h=0;reg [9:0] v=0;
reg [127:0] fx={8'd0,8'd105,8'd16,8'd18,8'd50,8'd3,8'd64,8'd4,8'd45,8'd51,8'd30,8'd8,8'd64,8'd90,8'd18,8'h5f};
wire [7:0] r,g,b;wire de,hs,vs,pclk;reg [223:0] pressures;
instrument_screen #(.SHOW_FSR(1),.PANEL_UI(1)) dut(.clk(clk),.audio_clk(clk),.sample_tick(tick),.pcm(pcm),
 .performance_info(256'd0),.panel_page(page),.fx_params(fx),.panel_bend(9'sd0),.selected_pad(4'd10),.selected_raw(14'd84),.selected_baseline(14'd20),.selected_threshold(14'd16),.selected_gain(9'd256),
 .fsr_pressures(pressures),.bt_rx_count(16'd128),.game_position(11'sd180),
 .fsr_ready(1'b1),.fsr_fault(1'b0),.fsr_calibrating(1'b0),.fsr_peak(14'd420),.fsr_keys(16'h0411),.fsr_delta(14'd64),.fsr_threshold(14'd16),.fsr_cal_mask(16'hffff),
 .auto_mode(1'b0),.stopped(1'b0),.game_page(page==3),.game_running(1'b1),.game_finished(1'b0),.game_score(16'd1250),.game_keys(16'h0010),.game_cue(16'h0010),
 .game_combo(6'd12),.game_max(6'd12),.game_hits(6'd13),.game_misses(6'd0),.game_progress(6'd13),.game_wrong(10'd0),.game_feedback(3'd1),.game_countdown(2'd0),.game_target(4'd4),.game_next(4'd5),
 .instrument(2'd0),.touch_chip(2'd1),.plot_mode(view),.live_keys(16'h0411),.volume(4'd8),.attack_sel(4'd0),.decay_sel(4'd5),.sustain_level(8'd160),.release_sel(4'd5),
 .touch_online(1'b1),.cursor_down(1'b0),.cursor_x(11'd0),.cursor_y(10'd0),.orientation(3'd0),.finger_count(3'd0),.touch_errors(16'd0),
 .touch_raw_status(8'd0),.touch_raw_count(4'd0),.touch_report_count(16'd128),.touch_raw_x(12'd0),.touch_raw_y(12'd0),.touch_max_x(12'd1023),.touch_max_y(12'd599),
 .r(r),.g(g),.b(b),.de(de),.hsync(hs),.vsync(vs),.pclk(pclk));
initial begin force dut.h=h;force dut.v=v;force dut.boot=22'h3fffff;force dut.analyzer.frame_blank=blank;force dut.scope.frame_blank=blank;end

integer height[0:63];integer i,j,xp,yp,stream,band,expected_band,peak_band,peak_height;
integer low_peak=-1,high_peak=-1,checks=0;reg expected_bar,actual_bar;
task publish_next;
begin
 wait(dut.analyzer.state!=15);wait(dut.analyzer.state==15);
 @(negedge clk);blank=1;@(negedge clk);blank=0;repeat(4)@(negedge clk);
 if(!dut.analyzer_valid)$fatal(1,"FFT frame not published");
end endtask

task check_plot(input integer mode);
begin
 tone_bin=mode;
 // Discard the block that may straddle the tone change.
 publish_next();publish_next();
 h=0;v=0;repeat(1200)@(negedge clk);
 peak_height=0;peak_band=0;
 for(i=0;i<64;i++)begin
  height[i]=dut.analyzer.bank?dut.analyzer.spectrum1[i]:dut.analyzer.spectrum0[i];
  if(height[i]>peak_height)begin peak_height=height[i];peak_band=i;end
 end
 if(mode==0)begin
  for(i=0;i<64;i++)if(height[i]!=0)$fatal(1,"silence leaves stale FFT band %d=%d",i,height[i]);
 end else begin
  expected_band=0;while(dut.analyzer.band_end(expected_band)<mode)expected_band++;
  if(peak_height<20 || peak_band<expected_band-1 || peak_band>expected_band+1)
   $fatal(1,"tone peak mismatch bin=%d peak=%d expected=%d height=%d",mode,peak_band,expected_band,peak_height);
  if(mode==8)low_peak=peak_band;else high_peak=peak_band;
 end
 // Each 8-pixel band has exactly 6 colored columns and 2 clear gaps.
 // Compare real serialized RGB/DE with the published FFT, including bounds.
 for(yp=232;yp<=320;yp++)begin
  for(stream=0;stream<549;stream++)begin
   @(negedge clk);
   if(stream<544)begin h=308+136+stream;v=23+yp;end else begin h=0;v=0;end
   @(posedge clk);#1;
   if(stream>=5)begin
    xp=136+stream-5;
    if(!de || $isunknown({r,g,b}))$fatal(1,"invalid RGB/DE");
    expected_bar=0;
    if(xp>=152 && xp<664 && yp<320)begin
     band=(xp-152)/8;
     expected_bar=((xp-152)%8<6 && 320-yp<=height[band]);
    end
    actual_bar=({r,g,b}==24'h7095d7);
    if(actual_bar!==expected_bar)$fatal(1,"FFT pixel mismatch mode=%d x=%d y=%d band=%d actual=%d expected=%d",mode,xp,yp,band,actual_bar,expected_bar);
    checks++;
   end
  end
 end
 $display("PASS spectrum RGB bin=%d peak_band=%d peak_height=%d all 64 bands/gaps/bounds",mode,peak_band,peak_height);
end endtask

reg expected_xy;integer xy_count;reg pixels[0:32767];
task check_xy;
begin
 tone_bin=8;
 repeat(3)begin
  wait(dut.scope.state==3);@(negedge clk);blank=1;@(negedge clk);blank=0;repeat(4)@(negedge clk);
 end
 if(!dut.graph_valid)$fatal(1,"actual audio XY not published");
 for(i=0;i<32768;i++)pixels[i]=dut.scope.bank?dut.scope.memory1[i]:dut.scope.memory0[i];
 view=2;h=0;v=0;repeat(1200)@(negedge clk);xy_count=0;
 for(yp=220;yp<340;yp++)begin
  for(stream=0;stream<269;stream++)begin
   @(negedge clk);if(stream<264)begin h=308+276+stream;v=23+yp;end else begin h=0;v=0;end
   @(posedge clk);#1;
   if(stream>=5)begin
    xp=276+stream-5;expected_xy=0;
    if(xp>=280 && xp<536 && yp>=224 && yp<336)expected_xy=pixels[(yp-224)*256+xp-280];
    if(!de || $isunknown({r,g,b}) || ({r,g,b}==24'h7095d7)!==expected_xy)
     $fatal(1,"XY pixel mismatch x=%d y=%d expected=%d",xp,yp,expected_xy);
    if(expected_xy)xy_count++;
    checks++;
   end
  end
 end
 if(xy_count<200)$fatal(1,"audio XY has no real trace");
 $display("PASS audio XY native RGB: actual/delayed PCM bitmap, exact alignment/bounds, %d trace pixels",xy_count);
end endtask
initial begin
 pressures=0;
 check_plot(8);check_plot(96);check_plot(0);check_xy();
 if(high_peak<=low_peak+10)$fatal(1,"different tone did not move visible spectrum");
 $display("PASS native_spectrum: actual PCM FFT to native RGB, low/high tone shift, exact bar alignment, silence clears, audio XY matches bitmap; %d pixel checks",checks);$finish;
end
initial begin #100000000;$fatal(1,"native spectrum timeout");end
endmodule
