`timescale 1ns/1ps
module tb_music_quality;
GSR GSR(1'b1);
reg clk=0;always #5 clk=~clk;
reg tick=0,clear=1;reg [31:0] keys=0;reg [255:0] notes;reg [287:0] gains;
reg [1:0] instrument=0;reg [3:0] attack=1,decay=9,release_time=6;reg [7:0] sustain=0;
reg signed [8:0] bend=0;wire signed [15:0] raw,pcm;wire valid,active,overrun;wire [5:0] count;
poly32_synth dut(.clk(clk),.sample_tick(tick),.clear(clear),.keys(keys),.note_numbers(notes),.voice_gains(gains),.instrument(instrument),
 .song_gate(1'b0),.song_step(24'd0),.volume(4'd15),.mode_gain(9'd256),.attack_sel(attack),.decay_sel(decay),.release_sel(release_time),.sustain_level(sustain),
 .expression_bend(bend),.expression_vibrato(7'd0),.target_voice(5'd0),.fx_params(128'd0),.test_mode(1'b0),.test_voice_count(6'd0),
 .pcm(raw),.pcm_valid(valid),.audio_active(active),.active_count(count),.overrun(overrun));
audio_conditioner filter(.clk(clk),.reset_n(!clear),.tick(valid),.active(active||raw!=0),.pcm_in(raw),.pcm_out(pcm));
integer i,j,clocks,seen,f,peak;reg [31:0] mask;
task sample;begin
 @(negedge clk);tick=1;@(negedge clk);tick=0;seen=0;
 for(clocks=1;clocks<576;clocks++)begin @(negedge clk);if(valid)begin seen++;if(clocks>440)$fatal(1,"music deadline");end end
 if(!clear&&(seen!=1||overrun||$isunknown(pcm)))$fatal(1,"music output invalid");
 if(raw>27000||raw< -27000)$fatal(1,"music headroom/wrap %0d",raw);
end endtask
task reset_voice;begin
 clear=1;keys=0;repeat(4)@(negedge clk);sample();clear=0;repeat(40)@(negedge clk);
end endtask
task capture(input string name,input integer frames);begin
 f=$fopen(name,"w");peak=0;
 for(j=0;j<frames;j++)begin sample();$fwrite(f,"%0d\n",pcm);if(pcm>peak)peak=pcm;if(-pcm>peak)peak=-pcm;end
 $fclose(f);if(peak<1000)$fatal(1,"music output too quiet %s peak=%0d",name,peak);
 $display("PASS music capture %s: %0d real RTL samples, peak=%0d",name,frames,peak);
end endtask
initial begin
 for(i=0;i<32;i++)begin notes[i*8+:8]=60+i;gains[i*9+:9]=256;end
 reset_voice();keys=1;capture("music_piano_single.raw",12000);
 keys=0;repeat(4800)sample();if(active||pcm!=0)$fatal(1,"piano release did not become silent");
 reset_voice();keys=32'h91;capture("music_piano_chord.raw",12000);
 if(count!=3)$fatal(1,"piano chord lost a voice");
 instrument=1;reset_voice();keys=32'h91;capture("music_guitar_chord.raw",12000);
 if(count!=3)$fatal(1,"guitar chord lost a voice");
 instrument=0;bend=200;notes[7:0]=108;reset_voice();keys=1;repeat(1000)sample();
 capture("music_high_note.raw",4096);if(dut.harmonic_bank[0]!=1)$fatal(1,"high note did not select bounded harmonic bank");
 bend=0;attack=0;decay=0;sustain=255;for(i=0;i<32;i++)notes[i*8+:8]=60;
 reset_voice();keys=32'hffffffff;repeat(200)sample();capture("music_unison32.raw",2048);
 if(count!=32)$fatal(1,"unison lost voices");
 $display("PASS music_quality: piano/guitar single/chord captures, changing timbre, high-note bank, real output filter, release silence and 32 equal-frequency headroom");$finish;
end
initial begin #600000000;$fatal(1,"music quality timeout");end
endmodule
