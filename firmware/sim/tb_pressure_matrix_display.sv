`timescale 1ns/1ps
// Production renderer pixels from explicit UI-state fixtures; not board photos.
module tb_pressure_matrix_display;
 GSR GSR(1'b1);
 reg clk=0;always #5 clk=~clk;reg frame=0;
 reg [10:0] x=0;reg [9:0] y=0;reg [255:0] info=0;reg [15:0] pressed=0,last=0,cue=1,score=0;
 reg ready=1,calibrating=0,running=1,finished=0;reg [2:0] feedback=0;wire [23:0] rgb;
 panel_renderer panel(.clk(clk),.frame_start(frame),.visible(1'b1),.x(x),.y(y),.performance_info(info),.page(3'd6),.fx_params(128'd0),.bend_cents(9'sd0),.instrument(2'd0),
  .stopped(1'b0),.auto_mode(1'b0),.game_page(1'b1),.game_running(running),.game_finished(finished),.volume(4'd8),.attack_sel(4'd0),.decay_sel(4'd5),.release_sel(4'd5),.sustain_level(8'd160),
  .live_keys(16'd0),.fsr_keys(pressed),.fsr_cal_mask(16'hffff),.fsr_ready(ready),.fsr_fault(1'b0),.fsr_calibrating(calibrating),.fsr_peak(14'd0),.fsr_delta(14'd0),.fsr_threshold(14'd20),.fsr_pressures(224'd0),
  .selected_pad(4'd0),.selected_raw(14'd0),.selected_baseline(14'd0),.selected_threshold(14'd0),.selected_gain(9'd256),.bt_rx_count(16'd0),.touch_errors(16'd0),.touch_online(1'b1),
  .game_score(score),.game_keys(last),.game_cue(cue),.game_combo(score==0?6'd0:6'd1),.game_progress(6'd0),.game_countdown(2'd0),.game_target(4'd0),.game_feedback(feedback),.game_position(11'sd0),
  .visual_mode(2'd0),.xy_pixel(1'b0),.xy_valid(1'b0),.wave_low(8'd0),.wave_high(8'd0),.spectrum_height(7'd0),.wave_valid(1'b0),.color(rgb));
 task snapshot;begin repeat(5)@(negedge clk);frame=1;@(negedge clk);frame=0;repeat(1200)@(negedge clk);end endtask
 task pixel(input integer px,py,input [23:0] wanted);begin
  @(negedge clk);x=px;y=py;repeat(8)@(negedge clk);
  if(rgb!==wanted)$fatal(1,"matrix pixel (%0d,%0d): %h expected %h",px,py,rgb,wanted);
 end endtask
 task capture(input string name);integer f,s;begin
  f=$fopen(name,"wb");$fwrite(f,"P6\n1024 600\n255\n");
  for(s=0;s<614403;s++)begin
   @(negedge clk);if(s<614400)begin x=s%1024;y=s/1024;end else begin x=0;y=0;end
   @(posedge clk);#1;if(s>=3)begin if($isunknown(rgb))$fatal(1,"matrix RGB unknown");$fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);end
  end $fclose(f);
 end endtask
 integer i;
 initial begin
  info[78:71]=120;info[221]=1;info[230]=1;info[231]=1;info[124:117]=42;
  snapshot();pixel(17,114,24'he9b34a);pixel(200,160,24'hfff0c2);pixel(300,200,24'hffffff);pixel(20,90,24'hf7f8fc);
  pixel(610,55,24'hdce7fc);if(panel.number_visible)$fatal(1,"legacy global volume number leaked into fullscreen header");
  if(panel.values[22]!=80||panel.values[50]!=1||panel.matrix_status!=1)$fatal(1,"matrix header values/state");
  capture("screen_matrix_target.ppm");
  pressed=8;last=8;feedback=4;snapshot();pixel(773,114,24'hd88083);pixel(17,114,24'he9b34a);
  if(panel.values[49]!=4||panel.matrix_feedback!=4)$fatal(1,"actual wrong cell number/feedback");capture("screen_matrix_wrong.ppm");
  pressed=1;last=1;feedback=1;score=100;snapshot();pixel(17,114,24'h4c9e7a);pixel(200,160,24'he0f1e7);capture("screen_matrix_correct.ppm");
  // Every physical Ax has its own spatial cell and large 01..16 number.
  feedback=0;last=0;
  for(i=0;i<16;i++)begin cue=16'd1<<i;pressed=0;snapshot();
   pixel(17+(i%4)*252,114+(i/4)*112,24'he9b34a);
   if(panel.values[32+i]!=i+1)$fatal(1,"matrix label %0d",i);
   pressed=16'd1<<i;snapshot();pixel(17+(i%4)*252,114+(i/4)*112,24'h4c9e7a);
  end
  info[81]=1;cue=0;pressed=1;last=1;snapshot();if(panel.matrix_status!=2)$fatal(1,"pause state");pixel(17,114,24'h7095d7);capture("screen_matrix_paused.ppm");
  info[81]=0;info[230]=0;ready=0;calibrating=1;pressed=0;snapshot();
  if(panel.matrix_status!=4||panel.enabled_q[90])$fatal(1,"calibration status/start availability");capture("screen_matrix_calibrating.ppm");
  $display("PASS pressure_matrix_display: all 16 spatial labels and target/actual colors, 2x digits, fullscreen, wrong/correct/last-key feedback, pause/calibration guards and five production-RGB captures");$finish;
 end
 initial begin #60000000;$fatal(1,"matrix display timeout");end
endmodule
