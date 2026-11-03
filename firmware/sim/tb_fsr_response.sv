`timescale 1ns/1ps
// Production clocks, scan/keyboard/voice gains/ADSR/mixer/effect bypass and DAC.
// Only the analog ADC uses its documented nominal digital timing surrogate.
module tb_fsr_response;
 reg adc_clk=0;always #200 adc_clk=~adc_clk;
 reg clk=0;always #19.047619048 clk=~clk;
 reg reset_n=0;reg [13:0] code0=20;
 wire [3:0] select;wire [13:0] peak;wire [223:0] samples;
 wire [15:0] update_mask;wire toggle,online,ready;wire [15:0] keys;wire [143:0] gains;
 fsr_adc adc(.clk(adc_clk),.reset_n(reset_n),.select(select),.peak(peak),.samples(samples),.update_mask(update_mask),.frame_toggle(toggle),.online(online));
 wire [13:0] analog_code=select==0 ? code0:14'd20;
 initial force adc.adc_i.sample_code=analog_code;
 wire tick;wire signed [15:0] dry,wet,pcm;wire synth_active,dry_valid,fx_valid;wire bck,ws,din;wire [7:0] envelope0;
 fsr_keyboard #(.CALIBRATION_LOG2(1),.STREAMING(1),.GAIN_SMOOTH_LOG2(7)) keyboard(.clk(clk),.reset_n(reset_n),.sample_tick(tick),.recalibrate(1'b0),
 .samples_async(samples),.update_mask_async(update_mask),.peak_async(peak),.frame_toggle_async(toggle),.online_async(online),.keys(keys),.gains(gains),.ready(ready));
 performance_synth #(.USE_NOTE_GAINS(1),.USE_PITCH_FX(1)) synth(.clk(clk),.sample_tick(tick),.clear(!reset_n),.instrument(2'd0),
 .live_keys(keys),.note_gains(gains),.song_gate(1'b0),.song_step(24'd0),.pluck_mode(1'b1),
 .volume(4'd8),.mode_gain(9'd256),.global_bend(1'b0),.attack_sel(4'd0),.decay_sel(4'd5),
 .release_sel(4'd0),.sustain_level(8'd160),.bend_target(4'd0),.bend_cents(9'sd0),.fx_params({8'd0,8'd100,8'd16,8'd18,8'd50,8'd3,8'd64,8'd4,8'd45,8'd51,8'd30,8'd8,8'd64,8'd90,8'd18,8'd0}),.pcm_valid(dry_valid),.pcm(dry),.audio_active(synth_active),.envelope0(envelope0));
 audio_effects fx(.clk(clk),.reset_n(reset_n),.sample_tick(dry_valid),.enable(1'b0),.params(128'd0),.dry(dry),.wet(wet),.valid(fx_valid));
 audio_conditioner quiet(.clk(clk),.reset_n(reset_n),.tick(fx_valid),.active(synth_active || wet!=0),.pcm_in(wet),.pcm_out(pcm));
 pt8211_tx dac(.clk(clk),.pcm_next(pcm),.bck(bck),.ws(ws),.din(din),.sample_tick(tick));
 reg started=0;reg [15:0] serial_word=0;integer bit_count=0;
 reg armed=0;realtime first_nonzero=-1,last_nonzero=-1,t0,t1,period_ns,gate_ns,full_attack_ns,serial_ns,worst_serial=0,worst_full=0;
 always @(posedge bck) begin
 if(!started) started=1;
 else begin
 serial_word={serial_word[14:0],din};
 if(bit_count==15) begin bit_count=0;if($signed(serial_word)>=32 || $signed(serial_word)<= -32) begin last_nonzero=$realtime;if(armed && first_nonzero<0) first_nonzero=$realtime;end end
 else bit_count=bit_count+1;
 end
 end
 initial begin
 #5000;reset_n=1;wait(ready);begin @(toggle);while(update_mask!=1) @(toggle);end t0=$realtime;begin @(toggle);while(update_mask!=1) @(toggle);end period_ns=$realtime-t0;
 for(integer phase=0;phase<20;phase=phase+1) begin
 code0=20;wait(keys==0);wait(envelope0==0);wait(pcm==0);repeat(16) @(negedge tick);
 begin @(toggle);while(update_mask!=1) @(toggle);end#((phase<16 ? phase*period_ns/16 : period_ns-(phase==16?61000:phase==17?59000:phase==18?30000:1000)));code0=36;t0=$realtime;first_nonzero=-1;armed=1;
 wait(keys[0]);gate_ns=$realtime-t0;
 wait(envelope0==255);full_attack_ns=$realtime-t0;
 wait(first_nonzero>=t0);serial_ns=first_nonzero-t0;armed=0;
 // First complete DAC word with magnitude >=32, not a one-code rounding residue.
 if(gate_ns>4600000 || full_attack_ns>=6200000 || serial_ns>=5000000)
 $fatal(1,"5ms first-output budget phase=%0d gate=%f full=%f serial=%f",phase,gate_ns/1e6,full_attack_ns/1e6,serial_ns/1e6);
 if(serial_ns>worst_serial) worst_serial=serial_ns;
 if(full_attack_ns>worst_full) worst_full=full_attack_ns;
 $display("RESPONSE phase=%0d gate_ms=%f envelope_full_ms=%f first_output_ms=%f",phase,gate_ns/1e6,full_attack_ns/1e6,serial_ns/1e6);
 end
 $display("PASS nominal digital FSR first output <5ms at all 20 scan phases: worst_full_attack_ms=%f worst_first_output_ms=%f; analog front end and speaker not measured",worst_full/1e6,worst_serial/1e6);$finish;
 end
 initial begin #600000000;$fatal(1,"FSR response timeout");end
endmodule
config cfg_tb_fsr_response;
 design work.tb_fsr_response;default liblist work;
 instance tb_fsr_response.adc.adc_i use work.fsr_adc_test_stub;
endconfig
