`timescale 1ns/1ps
module tb_testtone_quality;
 GSR GSR(1'b1);
 reg clk=0;always #5 clk=~clk;
 reg tick=0,clear=1,test_mode=0;reg [5:0] total=0;
 reg [31:0] keys=0;reg [1:0] instrument=0;
 reg [255:0] notes;reg [287:0] gains;
 wire [8:0] level=!test_mode?9'd256:total==8?9'd181:total==16?9'd128:total==32?9'd91:9'd256;
 wire signed [15:0] current,previous;wire cv,pv,co,po;wire [5:0] active;
 `define COMMON .clk(clk),.sample_tick(tick),.clear(clear),.keys(keys),.note_numbers(notes),.voice_gains(gains),.instrument(instrument),.song_gate(1'b0),.song_step(24'd0),.volume(4'd15),.attack_sel(4'd0),.decay_sel(4'd5),.release_sel(4'd5),.sustain_level(8'd160),.expression_bend(9'sd0),.expression_vibrato(7'd0),.target_voice(5'd0),.fx_params(128'd0),.test_mode(test_mode)
 poly32_synth dut(`COMMON,.test_voice_count(total),.mode_gain(level),.pcm(current),.pcm_valid(cv),.overrun(co),.active_count(active));
 stable_poly32 reference_dut(`COMMON,.mode_gain(9'd256),.pcm(previous),.pcm_valid(pv),.overrun(po));
 `undef COMMON
 task sample;integer seen;begin
  @(negedge clk);tick=1;@(negedge clk);tick=0;seen=0;
  repeat(575)begin @(negedge clk);if(cv)seen++;end
  if(!clear&&(seen!=1||co||po||$isunknown({current,previous})))$fatal(1,"sample/deadline");
 end endtask
 task restart;begin clear=1;repeat(4)@(negedge clk);sample();clear=0;repeat(80)@(negedge clk);end endtask
 task capture(input string name,input integer frames);integer f,j;begin
  f=$fopen(name,"w");for(j=0;j<frames;j++)begin sample();$fwrite(f,"%0d\n",current);end $fclose(f);
 end endtask
 integer i,j,f,g;
 initial begin
  for(i=0;i<32;i++)begin notes[i*8+:8]=60+i;gains[i*9+:9]=256;end
  // Piano and drums retain the stable path. Guitar is intentionally replaced
  // and is measured separately by tb_guitar_audio and tb_guitar_rom.
  for(i=0;i<3;i++)begin
   if(i!=1)begin
   instrument=i;test_mode=0;total=0;keys=32'h91;restart();
   for(j=0;j<256;j++)begin sample();if(current!==previous)$fatal(1,"ordinary instrument changed %0d frame%0d",i,j);end
   keys=0;repeat(10)sample();keys=32'h91;
   for(j=0;j<64;j++)begin sample();if(current!==previous)$fatal(1,"ordinary retrigger changed %0d",i);end
   end
  end
  instrument=0;test_mode=1;total=32;keys=32'hffffffff;restart();repeat(300)sample();
  f=$fopen("testtone32_current.raw","w");g=$fopen("testtone32_previous.raw","w");
  for(j=0;j<2048;j++)begin sample();$fwrite(f,"%0d\n",current);$fwrite(g,"%0d\n",previous);end
  $fclose(f);$fclose(g);
  if(active!=32)$fatal(1,"32 voices not active");
  keys=32'h7fffffff;repeat(100)sample();if(active!=31||level!=91)$fatal(1,"mute profile changed level");
  capture("testtone32_muted31.raw",1024);
  keys=32'hffffffff;repeat(100)sample();if(active!=32||level!=91)$fatal(1,"restore profile changed level");
  capture("testtone32_restored.raw",1024);
  $display("PASS testtone_quality: piano/drums and retriggers bit-identical to stable release; real 32-tone before/after, fixed profile on mute/restore, sample deadlines");$finish;
 end
 initial begin #70000000;$fatal(1,"testtone quality timeout");end
endmodule
