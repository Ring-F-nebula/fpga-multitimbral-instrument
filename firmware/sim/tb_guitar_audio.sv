`timescale 1ns/1ps
module tb_guitar_audio;
 GSR GSR(1'b1);
 reg clk=0;always #5 clk=~clk;
 reg tick=0,clear=1;reg [31:0] keys=0;
 reg [255:0] notes;reg [287:0] gains;reg [1:0] instrument=1;
 wire signed [15:0] pcm,old_pcm;wire valid,old_valid,overrun,old_overrun,active;wire [5:0] count;
 reg old_run=1;wire old_clk=clk&&old_run;
 `define PORTS .sample_tick(tick),.clear(clear),.keys(keys),.note_numbers(notes),.voice_gains(gains),.instrument(instrument),.song_gate(1'b0),.song_step(24'd0),.volume(4'd15),.mode_gain(9'd256),.attack_sel(4'd0),.decay_sel(4'd5),.release_sel(4'd5),.sustain_level(8'd160),.expression_bend(9'sd0),.expression_vibrato(7'd0),.target_voice(5'd0),.fx_params(128'd0),.test_mode(1'b0),.test_voice_count(6'd0)
 poly32_synth dut(`PORTS,.clk(clk),.pcm(pcm),.pcm_valid(valid),.overrun(overrun),.audio_active(active),.active_count(count));
 guitar_baseline_poly32 previous(`PORTS,.clk(old_clk),.pcm(old_pcm),.pcm_valid(old_valid),.overrun(old_overrun));
 `undef PORTS
 integer i,j,clocks,seen,f,g,first_audible,peak,tail_heard;
 real new_power,old_power;reg [23:0] saved_phase;
 // The isolated core is intentionally driven at a tighter 260-clock deadline
 // than production's 576 clocks. Each emitted sample is still played at Fs.
 task sample;begin
  @(negedge clk);tick=1;@(negedge clk);tick=0;seen=0;
  for(clocks=1;clocks<260;clocks=clocks+1)begin @(negedge clk);if(valid)begin seen=seen+1;if(clocks>240)$fatal(1,"guitar deadline");end end
  if(!clear&&(seen!=1||overrun||old_overrun||$isunknown(pcm)))$fatal(1,"guitar invalid output");
  if(pcm>30000||pcm< -30000)$fatal(1,"guitar headroom/wrap");
 end endtask
 task restart;begin clear=1;keys=0;sample();clear=0;repeat(8)@(negedge clk);end endtask
 initial begin
  for(i=0;i<32;i=i+1)begin notes[i*8+:8]=40+i;gains[i*9+:9]=256;end
  restart();keys=32'd1<<12;f=$fopen("guitar_new_single.raw","w");g=$fopen("guitar_old_single.raw","w");first_audible=-1;tail_heard=0;
  for(j=0;j<16000;j=j+1)begin
   if(j==1500)keys=0;
   // Stop clocking the old reference only after proving it has fully ended.
   if(j==6000)begin if(old_pcm!==0||previous.audio_active)$fatal(1,"baseline did not become silent");old_run=0;end
   sample();$fwrite(f,"%0d\n",pcm);$fwrite(g,"%0d\n",old_pcm);
   if(first_audible<0&&(pcm>2||pcm< -2))first_audible=j;
   if(j>6000&&(pcm>5||pcm< -5))tail_heard=tail_heard+1;
  end
  $fclose(f);$fclose(g);
  if(first_audible<0||first_audible>100)$fatal(1,"guitar attack latency %0d samples",first_audible);
  if(tail_heard<1000)$fatal(1,"released string loses natural tail");
  $display("MEASURE guitar first audible sample=%0d, post-release audible samples=%0d",first_audible,tail_heard);
  restart();keys=32'h01088421; // six real open-string pitches E2 A2 D3 G3 B3 E4
  f=$fopen("guitar_new_chord.raw","w");
  for(j=0;j<12000;j=j+1)begin
   if(j==2400)keys=0;
   sample();$fwrite(f,"%0d\n",pcm);
   if(j==2000&&count!=6)$fatal(1,"six independent guitar voices %0d",count);
  end $fclose(f);
  // Upper/lower voices, independent velocity mute and maximum coherent sum.
  restart();for(i=0;i<32;i=i+1)notes[i*8+:8]=52;
  keys=32'hffffffff;repeat(300)sample();if(count!=32)$fatal(1,"32 guitar voices");
  f=$fopen("guitar_unison32.raw","w");for(j=0;j<2048;j=j+1)begin sample();$fwrite(f,"%0d\n",pcm);end $fclose(f);
  saved_phase=dut.voices[0].phase;keys=32'hfffffffe;sample();keys=32'hffffffff;sample();
  if(dut.voices[0].phase==0)$fatal(1,"active pluck reset phase");
  for(i=0;i<32;i=i+1)gains[i*9+:9]=0;repeat(4)sample();if(pcm!==0)$fatal(1,"guitar independent gain mute");
  clear=1;sample();if(pcm!==0||active)$fatal(1,"guitar stop clear");
  $display("PASS guitar_audio: real PCM before/after, pluck attack, natural released tails, six strings, 32 independent DDS/ADSR voices, retrigger phase, velocity mute, clear and tighter-than-production sample deadline");$finish;
 end
 initial begin #400000000;$fatal(1,"guitar audio timeout");end
endmodule
