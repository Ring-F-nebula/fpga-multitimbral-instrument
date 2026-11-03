`timescale 1ns/1ps
module tb_pitch_fx;
reg clk=0;always #5 clk=~clk;
reg tick=0,clear=1;reg [15:0] keys=0;reg [1:0] instrument=0;reg [127:0] p=0;
wire signed [15:0] pcm;
performance_synth #(.USE_PITCH_FX(1)) dut(.clk(clk),.sample_tick(tick),.clear(clear),
 .instrument(instrument),.live_keys(keys),.song_gate(1'b0),.song_step(24'd0),.pluck_mode(1'b0),.note_gains(144'd0),
 .volume(4'd8),.mode_gain(9'd256),.global_bend(1'b0),.attack_sel(4'd0),.decay_sel(4'd0),.release_sel(4'd0),.sustain_level(8'd255),
 .bend_target(4'd4),.bend_cents(9'sd0),.fx_params(p),.pcm(pcm),.pcm_valid(),.active_envelopes(),.phase0(),.envelope0());
task sample;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(80)@(negedge clk);end endtask
integer i,prev,lo,hi;
initial begin
 p[7:0]=8;p[87:80]=0;p[95:88]=50;p[103:96]=50;p[111:104]=4;p[119:112]=100;
 repeat(4)@(negedge clk);clear=0;keys=1;sample();sample();
 if(dut.glide_steps[0]!=96315)$fatal(1,"first note should not glide");
 keys=17;sample();
 if(dut.glide_steps[4]!=96315)$fatal(1,"legato did not start from held note");
 prev=96315;
 for(i=0;i<456;i=i+1)begin sample();if(dut.glide_steps[4]<prev || dut.glide_steps[4]>121349)$fatal(1,"nonmonotonic glide");prev=dut.glide_steps[4];end
 if(dut.glide_steps[4]!=121349)$fatal(1,"glide missed target/duration");
 keys=0;sample();keys=3;sample();
 if(dut.glide_steps[0]!=96315 || dut.glide_steps[1]!=102042)$fatal(1,"chord attack was glided");
 keys=17;p[7:0]=16;lo=200000;hi=0;
 for(i=0;i<10000;i=i+1)begin
  sample();if(dut.voices[0].step!=96315)$fatal(1,"vibrato changed untargeted note");
  if(dut.voices[4].step<lo)lo=dut.voices[4].step;
  if(dut.voices[4].step>hi)hi=dut.voices[4].step;
 end
 if(lo>118500 || hi<124300)$fatal(1,"vibrato depth/rate missing %d %d",lo,hi);
 p[7:0]=64;p[119:112]=200;repeat(300)sample();
 if(dut.voices[4].step<136190 || dut.voices[4].step>136230)$fatal(1,"+200 cents frequency wrong %d",dut.voices[4].step);
 instrument=2;keys=0;sample();keys=1;sample();sample();
 if(dut.voices[0].step!=51528)$fatal(1,"melodic effects changed kick pitch %d",dut.voices[0].step);
 clear=1;sample();if(pcm!==0)$fatal(1,"clear failed");
 $display("PASS pitch_fx: legato timing, chords, selected-note vibrato, +200 cents, drum isolation, clear");$finish;
end
initial begin #100000000;$fatal(1,"timeout");end
endmodule
