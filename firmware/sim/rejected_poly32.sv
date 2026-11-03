// 32 independently gated DDS voices: independent phase/frequency/ADSR/gain.
// Frequency/NCO/ADSR architecture is retained. One shared high-resolution
// tone reader/mixer completes all 33 slots in < 440 / 576 audio clocks.
module rejected_poly32(input clk,sample_tick,clear,input [31:0] keys,
 input [255:0] note_numbers,input [287:0] voice_gains,input [1:0] instrument,
 input song_gate,input [23:0] song_step,input [3:0] volume,input [8:0] mode_gain,
 input [3:0] attack_sel,decay_sel,release_sel,input [7:0] sustain_level,
 input signed [8:0] expression_bend,input [6:0] expression_vibrato,input [4:0] target_voice,
 input [127:0] fx_params,input test_mode,
 output reg signed [15:0] pcm=0,output reg pcm_valid=0,output audio_active,
 output [31:0] active_envelopes,output [15:0] phase0,output [7:0] envelope0,
 output reg [5:0] active_count=0,output reg overrun=0);
 // Pipeline asynchronous-to-sample control decoding at the fabric clock.
 reg [31:0] keys_q=0;reg [1:0] instrument_q=0;reg test_mode_q=0;
 reg [127:0] fx_params_q=0;reg song_gate_q=0;reg [23:0] song_step_q=0;
 reg signed [8:0] expression_bend_q=0;reg [6:0] expression_vibrato_q=0;reg [4:0] target_voice_q=0;
 always @(posedge clk)begin
  keys_q<=clear?32'd0:keys;song_gate_q<=clear?1'b0:song_gate;
  instrument_q<=instrument;test_mode_q<=test_mode;fx_params_q<=fx_params;song_step_q<=song_step;
  expression_bend_q<=expression_bend;expression_vibrato_q<=expression_vibrato;target_voice_q<=target_voice;
 end
 reg [23:0] vib_phase=0;
 wire [23:0] vib_rate=(fx_params_q[95:88]*24'd9424)>>8;
 wire signed [8:0] vib_triangle=vib_phase[23]?$signed({1'b0,~vib_phase[22:15]})-9'sd128:$signed({1'b0,vib_phase[22:15]})-9'sd128;
 wire [7:0] depth={1'b0,expression_vibrato_q};
 reg signed [17:0] vp=0;
 always @(posedge clk)if(clear)vp<=0;else vp<=vib_triangle*$signed({1'b0,depth});
 wire signed [10:0] remote_bend=fx_params_q[6]?($signed({1'b0,fx_params_q[119:112]})-11'sd100)*2:11'sd0;
 wire signed [10:0] cents_sum=$signed(expression_bend_q)+remote_bend+($signed(vp)>>>7);
 wire signed [9:0] cents=cents_sum>300?10'sd300:cents_sum< -300?-10'sd300:cents_sum[9:0];
 reg signed [9:0] cents_q=0;wire [16:0] coefficient_wire;reg [16:0] coefficient=65536;
 fx_pitch_coeff pitch(.cents(cents_q),.coeff(coefficient_wire));
 always @(posedge clk)if(clear)begin cents_q<=0;coefficient<=65536;end
 else begin cents_q<=cents;coefficient<=coefficient_wire;end
 always @(posedge clk)if(clear)vib_phase<=0;else if(sample_tick)vib_phase<=vib_phase+vib_rate;
 wire [767:0] bank_steps;wire frequency_done,frequency_overrun;
 frequency_bank4 frequency_bank(.clk(clk),.clear(clear),.frame_tick(sample_tick),.keys(keys_q),.notes(note_numbers),
  .glide_enable(fx_params_q[3]&&!test_mode_q&&instrument_q!=2),.glide_time(fx_params_q[83:80]),
  .coefficient(coefficient),.target_voice(target_voice_q),.expression_enable(!test_mode_q&&instrument_q!=2),
  .phase_steps(bank_steps),.done(frequency_done),.overrun(frequency_overrun));
 reg frame_test=0;reg [1:0] frame_instrument=0;reg [23:0] frame_song_step=0;
 always @(posedge clk)if(sample_tick)begin frame_test<=test_mode_q;frame_instrument<=instrument_q;frame_song_step<=song_step_q;end
 wire [23:0] phases[0:32];wire [15:0] envelopes[0:32];wire [8:0] gains[0:32];
 wire [7:0] brightness[0:32];wire [1:0] harmonic_bank[0:32];
 wire score_active;assign audio_active=(|active_envelopes)||score_active;
 reg [16:0] random_bits=17'h1ab73;reg signed [7:0] noise=0,old_noise=0;
 always @(posedge clk)if(sample_tick)begin random_bits<={random_bits[15:0],random_bits[16]^random_bits[13]};noise<=random_bits[15:8];old_noise<=noise;end
 genvar v;
 generate for(v=0;v<33;v=v+1)begin: voices
  reg [23:0] phase=0,phase_q=0;reg [15:0] env_q=0,natural=0,bright=0;
  reg [7:0] bright_q=0;reg [1:0] band_q=0;reg previous_gate=0,phase_attack=0,phase_running=0;
  wire gate;wire [23:0] step;wire [15:0] env,selected_env;wire [2:0] env_state;
  if(v==32)begin: score
   assign gate=song_gate_q;assign step=frame_song_step;assign selected_env=env;assign score_active=(env!=0);assign gains[v]=256;
   adsr_envelope envelope(.clk(clk),.tick(sample_tick),.clear(clear),.gate(gate),.attack_sel(4'd0),.decay_sel(4'd2),.release_sel(4'd2),.sustain_level(8'd255),.level(env),.state(env_state));
  end else begin: manual
   reg [8:0] gain_q=256;reg [23:0] drum_step=0,drum_snapshot=0;
   assign gate=keys_q[v];assign gains[v]=gain_q;
   // Coherent FFT bins 8,14,...194. Each is a separately gated sine DDS.
   assign step=frame_test?((24'd8+v*24'd6)<<14):frame_instrument==2?drum_snapshot:bank_steps[v*24+:24];
   assign selected_env=(test_mode_q||instrument_q==0)?env:instrument_q==1?(natural<env?natural:env):natural;
   assign active_envelopes[v]=(selected_env!=0);
   // Preserve local control registers so 32 ADSRs do not share one long mode fanout path.
   reg [3:0] env_attack /* synthesis syn_preserve=1 */ =0;
   reg [3:0] env_decay /* synthesis syn_preserve=1 */ =0;
   reg [3:0] env_release /* synthesis syn_preserve=1 */ =0;
   reg [7:0] env_sustain /* synthesis syn_preserve=1 */ =0;
   always @(posedge clk)begin
    env_attack<=test_mode?4'd0:attack_sel;env_decay<=test_mode?4'd0:decay_sel;
    env_release<=test_mode?4'd0:release_sel;env_sustain<=test_mode?8'd255:sustain_level;
   end
   adsr_envelope envelope(.clk(clk),.tick(sample_tick),.clear(clear),.gate(gate),
    .attack_sel(env_attack),.decay_sel(env_decay),.release_sel(env_release),
    .sustain_level(env_sustain),.level(env),.state(env_state));
   always @(posedge clk)if(clear)begin gain_q<=256;drum_step<=0;drum_snapshot<=0;end
   else if(sample_tick)begin
    drum_snapshot<=drum_step;
    gain_q<=test_mode_q?9'd256:voice_gains[v*9+:9]>256?9'd256:voice_gains[v*9+:9];
    if(gate&&!previous_gate)case(v%6)
     0:drum_step<=51540;1:drum_step<=66250;2,3:drum_step<=3000000;4:drum_step<=80991;default:drum_step<=1900000;
    endcase
    else if(v%6==0&&drum_step>18000)drum_step<=drum_step-12;
    else if(v%6==4&&drum_step>50000)drum_step<=drum_step-4;
   end
  end
  assign phases[v]=phase_q;assign envelopes[v]=env_q;assign brightness[v]=bright_q;assign harmonic_bank[v]=band_q;
  // Conservative note bands include the full +/-300-cent expression range:
  // at MIDI 98 + 3 semitones eight harmonics still fit below Nyquist;
  // at MIDI 110 + 3 semitones four fit. No runtime divider is needed.
  if(v<32)always @(posedge clk)band_q<=note_numbers[v*8+:8]>=111?2:note_numbers[v*8+:8]>=99?1:0;
  else always @(posedge clk)band_q<=0;
  always @(posedge clk)if(clear)begin bright<=0;bright_q<=0;end
  else if(sample_tick)begin
   bright_q<=bright[15:8];
   if(gate&&!previous_gate)bright<=65535;
   else if(bright!=0)bright<=bright-((bright>>(instrument_q==1?12:11))+1'b1);
  end
  // Every voice retains its own physical accumulator and envelope state.
  always @(posedge clk)if(clear)phase<=0;
  else if(frequency_done)begin
   if(phase_attack)phase<=0;else if(phase_running)phase<=phase+step;else phase<=0;
  end
  always @(posedge clk)if(clear)begin phase_q<=0;env_q<=0;natural<=0;previous_gate<=0;phase_attack<=0;phase_running<=0;end
  else if(sample_tick)begin
   previous_gate<=gate;phase_q<=phase;env_q<=selected_env;
   phase_attack<=gate&&!previous_gate;phase_running<=gate||selected_env!=0;
   if(gate&&!previous_gate)begin natural<=65535;end
   else begin
    if(instrument_q==1)begin if(natural!=0)natural<=natural-((natural>>14)+1'b1);end
    else if(instrument_q==2)begin if(natural>8)natural<=natural-8;else natural<=0;end
   end
  end
 end endgenerate
 assign phase0=voices[0].phase[23:8];assign envelope0=voices[0].selected_env[15:8];
 reg [5:0] index=0;reg [4:0] state=0;reg signed [38:0] mix=0;
 reg signed [32:0] product=0;reg signed [42:0] velocity_product=0;
 reg signed [20:0] scaled=0;reg signed [30:0] normalization_product=0;
 reg signed [15:0] normalized=0;reg [8:0] normalization=256;
 reg signed [27:0] volume_product=0,gain_product=0;
 reg [8:0] volume_smooth=128;wire [8:0] volume_target={1'b0,volume,4'b0};
 reg [13:0] table_address=0;wire signed [15:0] table_value;
 tone_rom wavetable(.clk(clk),.address(table_address),.value(table_value));
 wire [3:0] body_group=(frame_test||frame_instrument==2)?4'd0:(frame_instrument==1?4'd9:4'd3)+{2'd0,harmonic_bank[index]};
 wire [3:0] attack_group=(frame_test||frame_instrument==2)?4'd0:(frame_instrument==1?4'd12:4'd6)+{2'd0,harmonic_bank[index]};
 reg [3:0] attack_group_q=0;reg [9:0] phase_index=0,next_phase_index=0;
 reg [7:0] fraction=0,bright_gain=0;reg [15:0] envelope_scan=0;reg [8:0] gain_scan=0;
 reg signed [15:0] body_a=0,body_b=0,attack_a=0,wave=0;
 reg signed [25:0] body_interpolation=0,attack_interpolation=0;
 reg signed [16:0] body_wave=0,attack_wave=0;reg signed [26:0] morph_product=0;
 wire signed [16:0] body_difference=$signed({body_b[15],body_b})-$signed({body_a[15],body_a});
 wire signed [16:0] attack_difference=$signed({table_value[15],table_value})-$signed({attack_a[15],attack_a});
 wire signed [17:0] morph_difference=$signed({attack_wave[16],attack_wave})-$signed({body_wave[16],body_wave});
 wire signed [8:0] noise_difference=($signed({noise[7],noise})-$signed({old_noise[7],old_noise}))>>>1;
 function signed [15:0] clip;input signed [38:0] x;
  begin clip=x>32767?16'sd32767:x< -32768?-16'sd32768:x[15:0];end
 endfunction
 function [8:0] normalize;input [5:0] voices;
  begin case(voices)
   0,1,2,3,4:normalize=256;
   `include "poly_mix_gain.vh"
   default:normalize=31;
  endcase end
 endfunction
 reg [5:0] count_work=0;
 always @(posedge clk)begin
  pcm_valid<=0;
  if(clear)begin state<=0;pcm<=0;mix<=0;index<=0;product<=0;velocity_product<=0;scaled<=0;volume_product<=0;gain_product<=0;normalization_product<=0;normalized<=0;overrun<=0;active_count<=0;count_work<=0;volume_smooth<=volume_target;end
  else begin
   if((sample_tick&&state!=0)||frequency_overrun)overrun<=1;
   case(state)
    0:if(sample_tick)begin index<=0;mix<=0;count_work<=0;state<=1;
     if(volume_smooth<volume_target)volume_smooth<=volume_smooth+1'b1;else if(volume_smooth>volume_target)volume_smooth<=volume_smooth-1'b1;
    end
    1:begin
     table_address<={body_group,phases[index][23:14]};phase_index<=phases[index][23:14];next_phase_index<=phases[index][23:14]+10'd1;
     fraction<=phases[index][13:6];attack_group_q<=attack_group;bright_gain<=brightness[index];
     envelope_scan<=envelopes[index];gain_scan<=gains[index];state<=2;
    end
    2:begin table_address<={body_group,next_phase_index};state<=3;end
    3:begin body_a<=table_value;table_address<={attack_group_q,phase_index};state<=4;end
    4:begin body_b<=table_value;table_address<={attack_group_q,next_phase_index};state<=5;end
    5:begin attack_a<=table_value;state<=6;end
    6:begin body_interpolation<=body_difference*$signed({1'b0,fraction});attack_interpolation<=attack_difference*$signed({1'b0,fraction});state<=7;end
    7:begin body_wave<=$signed(body_a)+(body_interpolation>>>8);attack_wave<=$signed(attack_a)+(attack_interpolation>>>8);state<=8;end
    8:begin morph_product<=morph_difference*$signed({1'b0,bright_gain});state<=9;end
    9:begin
     wave<=body_wave+(morph_product>>>8);
     if(!frame_test&&frame_instrument==2&&index<32)case(index%6)
      1:wave<=($signed({noise,8'd0})>>>1)+(body_wave>>>2);
      2,3:wave<=$signed(noise_difference)*16'sd256;
      5:wave<=$signed({noise,8'd0})>>>1;
      default:wave<=body_wave;
     endcase
     state<=10;
    end
    10:begin product<=wave*$signed({1'b0,envelope_scan});state<=11;end
    11:begin velocity_product<=product*$signed({1'b0,gain_scan});state<=12;end
    12:begin mix<=mix+($signed(velocity_product)>>>8);if(envelope_scan!=0)count_work<=count_work+1'b1;
     if(index==32)state<=13;else begin index<=index+1'b1;state<=1;end
    end
    // Wide accumulation first; music has four-voice headroom, then an exact
    // bounded 4/N gain for larger chords. Acceptance scaling stays constant.
    13:begin scaled<=frame_test?mix>>>22:mix>>>18;normalization<=frame_test?9'd256:normalize(count_work);active_count<=count_work;state<=14;end
    14:begin normalization_product<=scaled*$signed({1'b0,normalization});state<=15;end
    15:begin normalized<=clip(normalization_product>>>8);state<=16;end
    16:begin volume_product<=normalized*$signed({1'b0,volume_smooth});state<=17;end
    17:begin gain_product<=$signed(volume_product[25:8])*$signed({1'b0,mode_gain>256?9'd256:mode_gain});state<=18;end
    18:begin pcm<=clip($signed(gain_product)>>>8);pcm_valid<=1;state<=0;end
    default:state<=0;
   endcase
  end
 end
endmodule
