`timescale 1ns/1ps
module tb_instrument_surface;
 GSR GSR(1'b1);
 reg clk=0;always #5 clk=~clk;
 reg reset_n=0,frame=0;reg [4:0] contacts=0;reg [59:0] points_x=0,points_y=0;
 reg [1:0] tone=0;wire bank;wire [31:0] keys;wire [2:0] page;
 reg [255:0] info=0;
 wire commit;wire [7:0] param_id,param_value;reg [7:0] last_id=0,last_value=0;
 always @(posedge clk)if(commit)begin last_id<=param_id;last_value<=param_value;end
 panel_ui ui(.clk(clk),.reset_n(reset_n),.frame_valid(frame),.key1_n(1'b1),.contacts(contacts),.point_x(points_x),.point_y(points_y),
  .serial_volume(4'd8),.serial_volume_event(1'b0),.fx_params(128'd0),.performance_info(info),.practice_running(1'b0),.practice_target(5'd0),
  .hold_state(1'b0),.instrument_state(tone),.bpm_state(8'd120),.song_state(2'd0),.test_selected(5'd0),.test_mute(1'b0),
  .attack_sel(4'd0),.decay_sel(4'd5),.release_sel(4'd5),.sustain_level(8'd160),.bank(bank),.keys(keys),.page(page),.commit(commit),.param_id(param_id),.param_value(param_value));
 `include "surface_test_points.vh"
 task report;begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(24)@(negedge clk);end endtask
 task up;begin contacts=0;report();if(keys!==0)$fatal(1,"stuck note on release");end endtask
 task down(input integer x,y);begin contacts=1;points_x=x;points_y=y;report();end endtask
 task tap(input integer x,y);begin up();down(x,y);up();end endtask
 integer i,j,k,row,col;reg [31:0] expected;
 reg paint_frame=0;reg [10:0] x=0;reg [9:0] y=0;reg [1:0] paint_tone=0;reg paint_bank=0;
 reg [31:0] sounding=0;reg [2:0] paint_chord=0;reg paint_analysis=0;reg [255:0] paint_info;wire [23:0] rgb;
 always @*begin paint_info=0;paint_info[31:0]=sounding;paint_info[38]=paint_bank;paint_info[228:226]=paint_chord;paint_info[229]=paint_analysis;end
 panel_renderer panel(.clk(clk),.frame_start(paint_frame),.visible(1'b1),.x(x),.y(y),.performance_info(paint_info),.page(3'd0),.fx_params(128'd0),.bend_cents(9'sd0),.instrument(paint_tone),
  .stopped(1'b0),.auto_mode(1'b0),.game_page(1'b0),.game_running(1'b0),.game_finished(1'b0),.volume(4'd8),.attack_sel(4'd0),.decay_sel(4'd5),.release_sel(4'd5),.sustain_level(8'd160),
  .live_keys(16'd0),.fsr_keys(16'd0),.fsr_cal_mask(16'd0),.fsr_ready(1'b0),.fsr_fault(1'b0),.fsr_calibrating(1'b0),.fsr_peak(14'd0),.fsr_delta(14'd0),.fsr_threshold(14'd0),.fsr_pressures(224'd0),
  .selected_pad(4'd0),.selected_raw(14'd0),.selected_baseline(14'd0),.selected_threshold(14'd0),.selected_gain(9'd256),.bt_rx_count(16'd0),.touch_errors(16'd0),.touch_online(1'b1),
  .game_score(16'd0),.game_keys(16'd0),.game_cue(16'd0),.game_combo(6'd0),.game_progress(6'd0),.game_countdown(2'd0),.game_target(4'd0),.game_feedback(3'd0),.game_position(11'sd0),
  .visual_mode(2'd0),.xy_pixel(1'b0),.xy_valid(1'b0),.wave_low(8'd0),.wave_high(8'd0),.spectrum_height(7'd0),.wave_valid(1'b0),.color(rgb));
 task snapshot;begin repeat(5)@(negedge clk);paint_frame=1;@(negedge clk);paint_frame=0;repeat(1200)@(negedge clk);end endtask
 task pixel(input integer px,py,input [23:0] wanted);begin
  @(negedge clk);x=px;y=py;repeat(8)@(negedge clk);
  if(rgb!==wanted)$fatal(1,"surface pixel (%0d,%0d) got %h expected %h",px,py,rgb,wanted);
 end endtask
 task capture(input string name);integer f,s;begin
  f=$fopen(name,"wb");$fwrite(f,"P6\n1024 600\n255\n");
  for(s=0;s<614403;s++)begin
   @(negedge clk);if(s<614400)begin x=s%1024;y=s/1024;end else begin x=0;y=0;end
   @(posedge clk);#1;if(s>=3)$fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
  end $fclose(f);
 end endtask
 initial begin
  repeat(5)@(negedge clk);reset_n=1;
  for(j=0;j<2;j++)begin
   for(i=0;i<16;i++)begin down(piano_test_x(j,i),piano_test_y(j,i));if(keys!==(32'd1<<(16*j+i)))$fatal(1,"piano mapping bank%0d slot%0d %h",j,i,keys);up();end
   if(j==0)tap(850,130);
  end
  tap(850,130); // Lower bank again.
  down(205,430);if(keys!==2)$fatal(1,"black key must override covered white");up();
  down(205,540);if(keys!==1)$fatal(1,"white tail under black key");up();
  contacts=31;expected=32'h00000913;
  for(i=0;i<5;i++)begin case(i)0:k=0;1:k=1;2:k=4;3:k=8;default:k=11;endcase points_x[i*12+:12]=piano_test_x(0,k);points_y[i*12+:12]=piano_test_y(0,k);end
  report();if(keys!==expected)$fatal(1,"five-contact chord %h",keys);up();
  down(500,390);if(keys!==0)$fatal(1,"heading must not trigger a note");up();
  tap(48,452);if(page!=5)$fatal(1,"lower sidebar navigation was masked by note decoder");tap(48,148);
  tone=1;
  for(i=0;i<6;i++)begin
   case(i)0:k=24;1:k=19;2:k=15;3:k=10;4:k=5;default:k=0;endcase
   down(920,440+24*i);if(keys!==(32'd1<<k))$fatal(1,"open guitar string %0d %h",i,keys);up();
  end
  for(i=0;i<7;i++)begin
   tap(194+124*i,396);if(last_id!=8'h54||last_value!=i)$fatal(1,"chord selector %0d",i);
  end
  info[228:226]=1;down(920,560);if(keys!==0)$fatal(1,"C sixth string must be muted");up();
  down(920,464);if(keys!==(32'd1<<20))$fatal(1,"C chord B-string C4 mapping");up();
  tap(960,130);if(last_id!=8'h54||last_value!=6)$fatal(1,"guitar status heading must not send a command");info[229]=1;info[228:226]=0;
  for(i=0;i<6;i++)begin
   case(i)0:k=24;1:k=19;2:k=15;3:k=10;4:k=5;default:k=0;endcase
   down(920,440+24*i);if(keys!==(32'd1<<k))$fatal(1,"analyzer guitar string %0d %h",i,keys);up();
  end
  tone=2;
  for(i=0;i<16;i++)begin down(232+(i%4)*224,424+(i/4)*44);if(keys!==(32'd1<<i))$fatal(1,"drum pad mapping");up();end
  paint_tone=0;paint_bank=0;sounding=3;snapshot();
  pixel(140,530,24'hc5def7);pixel(205,450,24'h497eaa);pixel(280,530,24'hffffff);capture("screen_surface_piano.ppm");
  sounding=0;snapshot();pixel(140,530,24'hffffff);pixel(205,450,24'h293344);
  paint_bank=1;sounding=32'h80000000;snapshot();pixel(980,530,24'hc5def7);pixel(140,530,24'hffffff);capture("screen_surface_piano_upper.ppm");
  paint_bank=0;paint_tone=1;paint_chord=1;sounding=32'h01008000;snapshot();
  pixel(920,440,24'h397f9e);pixel(920,464,24'h94846c);pixel(920,560,24'hc5b8a6);pixel(800,276,24'hccd5e8);capture("screen_surface_guitar.ppm");
  sounding=0;snapshot();pixel(920,440,24'h94846c);
  paint_analysis=1;sounding=32'h01008000;snapshot();pixel(920,440,24'h397f9e);pixel(800,276,24'hccd5e8);capture("screen_surface_guitar_analysis.ppm");
  $display("PASS instrument_surface: both piano banks and black priority, five-finger chord, six compact strings, seven chord selectors, muted strings, permanent expression panel with either legacy bit, real-mask highlights and RGB captures");$finish;
 end
 initial begin #40000000;$fatal(1,"instrument surface timeout");end
endmodule
