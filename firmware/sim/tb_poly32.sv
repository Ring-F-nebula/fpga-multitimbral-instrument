`timescale 1ns/1ps
module tb_poly32;
GSR GSR(1'b1);
reg clk=0;always #5 clk=~clk;
reg [5:0] test_total=4;
reg tick=0,clear=1;reg [31:0] keys=0;reg [255:0] notes;reg [287:0] gains;
reg [1:0] instrument=0;reg test_mode=1;reg signed [8:0] bend=0;reg [6:0] vibrato=0;
wire [8:0] proof_level=!test_mode?9'd256:test_total==8?9'd181:test_total==16?9'd128:test_total==32?9'd91:9'd256;
wire signed [15:0] pcm;wire valid,active,overrun;wire [31:0] envelopes;wire [5:0] count;
poly32_synth dut(.clk(clk),.sample_tick(tick),.clear(clear),.keys(keys),.note_numbers(notes),.voice_gains(gains),.instrument(instrument),
 .song_gate(1'b0),.song_step(24'd0),.volume(4'd15),.mode_gain(proof_level),.attack_sel(4'd0),.decay_sel(4'd0),.release_sel(4'd0),.sustain_level(8'd255),
 .expression_bend(bend),.expression_vibrato(vibrato),.target_voice(5'd31),.fx_params({8'd0,8'd100,8'd32,8'd0,8'd50,88'd0}),.test_mode(test_mode),.test_voice_count(test_total),
 .pcm(pcm),.pcm_valid(valid),.audio_active(active),.active_envelopes(envelopes),.active_count(count),.overrun(overrun));
integer clocks,seen,heard,i,j,n,f;reg [23:0] previous_phase;
task sample;
begin
 @(negedge clk);tick=1;@(negedge clk);tick=0;seen=0;
 for(clocks=1;clocks<576;clocks++)begin @(negedge clk);if(valid)begin seen++;if(clocks>440)$fatal(1,"scheduler deadline");end end
 if(!clear&&(seen!=1||overrun||$isunknown(pcm)))$fatal(1,"one valid result per audio frame");
end endtask
initial begin
 for(i=0;i<32;i++)begin notes[i*8+:8]=60+i;gains[i*9+:9]=256;end
 repeat(3)@(negedge clk);clear=0;
 for(n=4;n<=32;n=n*2)begin
  test_total=n;keys=n==32?32'hffffffff:(32'h1<<n)-1;clear=1;sample();clear=0;repeat(220)sample();
  if(count!=n)$fatal(1,"active independent voices %d != %d",count,n);
  f=$fopen($sformatf("poly32_%0d.raw",n),"w");heard=0;
  for(j=0;j<4096;j++)begin sample();$fwrite(f,"%0d\n",pcm);if(pcm!=0)heard++;if(pcm>20000||pcm< -20000)$fatal(1,"headroom");end
  $fclose(f);if(heard<3900)$fatal(1,"silent oscillators");
  $display("PASS poly32 %d independently enveloped sine DDS, 4096 PCM frames, deadline/headroom",n);
 end
 // Remove just the top gate: all other independent envelopes keep sounding.
 keys=32'h7fffffff;repeat(100)sample();if(envelopes!==32'h7fffffff||count!=31)$fatal(1,"independent release");
 test_mode=0;keys=32'h80000000;repeat(200)sample();previous_phase=dut.voices[31].phase;sample();
 if(dut.voices[31].phase==previous_phase||envelopes!==32'h80000000)$fatal(1,"upper music voice");
 gains[31*9+:9]=0;repeat(5)sample();if(pcm!==0)$fatal(1,"independent gain mute");
 gains[31*9+:9]=256;repeat(5)sample();heard=0;repeat(40)begin sample();if(pcm!=0)heard++;end;if(heard<30)$fatal(1,"gain restore");
 clear=1;sample();if(pcm!==0||active)$fatal(1,"clear");
 $display("PASS poly32: 32 independent gates/phases/envelopes/gains, upper notes, 4/8/16/32 proof PCM and 576-clock sample deadline");$finish;
end
initial begin #300000000;$fatal(1,"poly32 timeout");end
endmodule
