`timescale 1ns/1ps
module tb_audio_regression;
 GSR GSR(1'b1);
 reg clk=0;always #5 clk=~clk;
 reg tick=0,clear=1;reg [31:0] keys=15,reference_keys=15;
 reg [255:0] notes;reg [287:0] gains;
 wire signed [15:0] current,reference_pcm,rejected;
 wire cv,rv,bv;wire co,ro,bo;
 `define AUDIO_PORTS .clk(clk),.sample_tick(tick),.clear(clear),.note_numbers(notes),.voice_gains(gains),.instrument(2'd0),.song_gate(1'b0),.song_step(24'd0),.volume(4'd8),.mode_gain(9'd256),.attack_sel(4'd0),.decay_sel(4'd0),.release_sel(4'd0),.sustain_level(8'd255),.expression_bend(9'sd0),.expression_vibrato(7'd0),.target_voice(5'd0),.fx_params(128'd0),.test_mode(1'b0)
 poly32_synth dut(`AUDIO_PORTS,.test_voice_count(6'd0),.keys(keys),.pcm(current),.pcm_valid(cv),.overrun(co));
 reference_poly32 reference_dut(`AUDIO_PORTS,.keys(reference_keys),.pcm(reference_pcm),.pcm_valid(rv),.overrun(ro));
 rejected_poly32 rejected_dut(`AUDIO_PORTS,.keys(keys),.pcm(rejected),.pcm_valid(bv),.overrun(bo));
 `undef AUDIO_PORTS
 integer i,f,seen;real old_power,bad_power;
 task frame;begin
  @(negedge clk);tick=1;@(negedge clk);tick=0;seen=0;
  repeat(575)begin @(negedge clk);if(cv)seen++;end
  if(co||ro||bo||seen!=1||$isunknown(current))$fatal(1,"audio sample/deadline");
 end endtask
 initial begin
  for(i=0;i<32;i++)begin notes[i*8+:8]=60;gains[i*9+:9]=256;end
  gains[4*9+:9]=0;
  repeat(4)@(negedge clk);clear=0;
  repeat(300)frame();old_power=0;bad_power=0;f=$fopen("audio_reference_compare.csv","w");
  for(i=0;i<512;i++)begin
   frame();if(current!==reference_pcm)$fatal(1,"restored piano differs from COMPETITION32 at %0d: %0d != %0d",i,current,reference_pcm);
   old_power+=real'(reference_pcm)*real'(reference_pcm);bad_power+=real'(rejected)*real'(rejected);
   $fwrite(f,"%0d,%0d,%0d\n",reference_pcm,current,rejected);
  end
  $fclose(f);
  $display("MEASURE previous UI/reference four-note RMS ratio=%f",$sqrt(bad_power/old_power));
  if($sqrt(bad_power/old_power)<8)$fatal(1,"failed to reproduce excessive prior level");
  keys=31;repeat(100)begin
   frame();if(current!==reference_pcm)$fatal(1,"silent fifth voice changes existing chord");
  end
  if(rejected_dut.normalization!=204)$fatal(1,"failed to reproduce prior 4-to-5 voice gain step");
  $display("REPRODUCED previous UI count normalization 256 -> %0d on a zero-gain fifth voice",rejected_dut.normalization);
  keys=14;repeat(2)frame();keys=15;frame();
  if(dut.voices[0].phase==0||dut.voices[0].env_q==0)$fatal(1,"active retrigger reset phase");
  $display("PASS audio_regression: exact COMPETITION32 piano PCM, no count-dependent gain step, active retrigger phase continuity, reproduced rejected-version defects");$finish;
 end
 initial begin #40000000;$fatal(1,"audio regression timeout");end
endmodule
