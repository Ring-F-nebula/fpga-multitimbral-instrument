// Tang Mega NEO 138K, silicon revision B. All audio generated in FPGA fabric.
module dualmode_top #(
    // Legacy parameters preserve project compatibility. This version uses
    // local touch, USB UART, Bluetooth and the independent digital WAX UART.
    // Legacy analog/laser paths stay inactive; five EC11 controls are enabled.
    parameter integer ENABLE_LASER_INPUTS=0,
    parameter integer ENABLE_RC_PADS=0,
    parameter integer ENABLE_FSR_INPUTS=0,
    parameter integer ENABLE_ENCODER=1,
    parameter integer TOUCH_I2C_QUARTER=17,
    parameter integer PANEL_UI=1
)(
    input wire clk_50m,
    input wire key0_n, key1_n, UART_RX, BT_RX,
    output wire BT_TX,
    input wire WAX_RX,output wire WAX_TX,
    input wire [4:0] enc_a_n, enc_b_n,input wire enc_sw_n,
    input wire [6:0] beam_broken,
    input wire soft_touch,bend_touch,timbre_touch,fx_touch,
    output wire HP_BCK, HP_WS, HP_DIN, PA_EN, UART_TX,
    output wire [7:0] lcd_r,lcd_g,lcd_b,
    output wire lcd_clk,lcd_hsync,lcd_vsync,lcd_de,lcd_bl,lcd_reset,
    inout wire touch_scl,touch_sda,touch_int,
    output wire touch_reset_n
);
    wire lcd_sysclk,clock_locked;reg clk=0;
    merged_clock clock_gen(.clkin(clk_50m),.clkout(lcd_sysclk),.locked(clock_locked));
    always @(posedge lcd_sysclk)clk<=~clk;
    reg [7:0] powerup=0;always @(posedge clk)if(!clock_locked)powerup<=0;else if(!(&powerup))powerup<=powerup+1'b1;
    wire reset_n=&powerup;
    wire press0,press1;button_press key0(clk,key0_n,press0);button_press key1(clk,key1_n,press1);
    wire signed [15:0] pcm;wire sample_tick;
    pt8211_tx dac(clk,pcm,HP_BCK,HP_WS,HP_DIN,sample_tick);
    // J14-23/25/26 are the user-confirmed encoder inputs.
    // Board audio remains on HP_BCK/HP_WS/HP_DIN; i2s_tx.v is retained in source.
    wire [15:0] usb_lo,usb_hi,bt_lo,bt_hi,usb_rx_count,bt_rx_count,usb_edges,bt_edges;
    wire [11:0] usb_bit_clocks,bt_bit_clocks;wire usb_trained,bt_trained;
    wire usb_commit,bt_commit,usb_mode_event,bt_mode_event,usb_auto,bt_auto;wire [7:0] usb_id,bt_id,usb_value,bt_value,usb_last,bt_last,usb_params,bt_params;
    uart_link usb(.clk(clk),.rx(UART_RX),.pressed(usb_lo),.upper_pressed(usb_hi),.rx_count(usb_rx_count),.last_byte(usb_last),.edges(usb_edges),.bit_clocks(usb_bit_clocks),.trained(usb_trained),.param_count(usb_params),.config_commit(usb_commit),.committed_id(usb_id),.committed_value(usb_value),.mode_event(usb_mode_event),.mode_auto(usb_auto));
    uart_link #(.DEFAULT_BIT_CLOCKS(2734),.ALLOW_LEGACY_KEYS(0)) bluetooth(.clk(clk),.rx(BT_RX),.pressed(bt_lo),.upper_pressed(bt_hi),.rx_count(bt_rx_count),.last_byte(bt_last),.edges(bt_edges),.bit_clocks(bt_bit_clocks),.trained(bt_trained),.param_count(bt_params),.config_commit(bt_commit),.committed_id(bt_id),.committed_value(bt_value),.mode_event(bt_mode_event),.mode_auto(bt_auto));
    wire [31:0] serial_keys={usb_hi,usb_lo}|{bt_hi,bt_lo};
    wire touch_frame,touch_online;wire [1:0] touch_chip;wire [4:0] contacts;wire [59:0] points_x,points_y;
    wire [15:0] touch_errors,touch_report_count;wire [7:0] touch_raw_status;wire [3:0] touch_raw_count;
    wire [11:0] touch_raw_x,touch_raw_y,touch_max_x,touch_max_y;
    capacitive_touch #(.I2C_QUARTER(TOUCH_I2C_QUARTER)) touch_reader(.clk(clk),.scl(touch_scl),.sda(touch_sda),.interrupt(touch_int),.reset_n(touch_reset_n),
      .online(touch_online),.frame_valid(touch_frame),.chip(touch_chip),.contacts(contacts),.point_x(points_x),.point_y(points_y),.error_count(touch_errors),
      .raw_status(touch_raw_status),.raw_count(touch_raw_count),.report_count(touch_report_count),.raw_x(touch_raw_x),.raw_y(touch_raw_y),.max_x(touch_max_x),.max_y(touch_max_y));
    wire [255:0] info;reg [255:0] display_info=0;wire replaying;
    always @(posedge clk)display_info<=info;
    wire [31:0] touch_keys,control_keys;wire [2:0] page,plot_mode,orientation,finger_count,axis_valid;
    wire bank,ui_stop,ui_live,ui_auto,ui_game_start,ui_commit,game_page,cursor_down;wire [10:0] cursor_x;wire [9:0] cursor_y;
    wire [7:0] ui_id,ui_value;wire signed [8:0] axis_bend,bend;wire [8:0] axis_gain,gain;wire [6:0] axis_vibrato,vibrato;
    wire [3:0] volume,attack,decay,release_time;wire [7:0] sustain;wire [1:0] instrument;wire [2:0] guitar_chord;wire guitar_analysis;
    wire stopped,clear_audio,hold_mode,test_muted,vibrato_override;wire [6:0] effective_vibrato;wire [5:0] test_count;wire [4:0] selected,newest_voice;
    wire [7:0] bpm,upload_expected,upload_received;wire [1:0] song,practice_command,record_command;
    wire audio_command_valid,record_auto_trigger,mapping_reset_done;wire [1:0] audio_command;
    wire practice_command_valid,record_command_valid,upload_ready,upload_matrix_ok;wire [8:0] record_query;
    wire [255:0] note_numbers;wire [287:0] voice_gains;wire [6:0] song_address;wire [7:0] song_note,song_duration;
    wire [127:0] fx_params;wire [7:0] fx_revision;assign effective_vibrato=vibrato_override?vibrato:fx_params[4]?fx_params[102:96]:7'd0;
    wire practice_running,practice_paused,practice_finished,practice_gate;wire [23:0] practice_step;
    wire [31:0] practice_cue;wire [4:0] practice_target;wire [7:0] practice_progress,practice_length;
    wire [15:0] practice_score;wire [5:0] practice_combo,practice_hits,practice_misses;wire [2:0] practice_feedback;
    wire [1:0] practice_countdown;wire signed [10:0] practice_position;
    panel_ui ui(.clk(clk),.reset_n(reset_n),.frame_valid(touch_frame),.key1_n(1'b1),.contacts(contacts),.point_x(points_x),.point_y(points_y),
      .serial_volume(volume),.serial_volume_event(1'b1),.fx_params(fx_params),.hold_state(hold_mode),.instrument_state(instrument),.bpm_state(bpm),.song_state(song),.test_selected(selected),.test_mute(test_muted),
      .performance_info(info),.practice_running(practice_running),.practice_target(practice_target),.bank(bank),.axis_valid(axis_valid),.axis_bend(axis_bend),.axis_gain(axis_gain),.axis_vibrato(axis_vibrato),
      .attack_sel(attack),.decay_sel(decay),.release_sel(release_time),.sustain_level(sustain),.keys(touch_keys),.plot_mode(plot_mode),
      .auto_press(ui_auto),.live_press(ui_live),.stop_press(ui_stop),.orientation(orientation),.cursor_down(cursor_down),.cursor_x(cursor_x),.cursor_y(cursor_y),.finger_count(finger_count),
      .game_page(game_page),.game_start(ui_game_start),.page(page),.commit(ui_commit),.param_id(ui_id),.param_value(ui_value));
    wire external_commit=ui_commit||bt_commit||usb_commit||bt_mode_event||usb_mode_event||press0;
    wire knob_commit;wire [7:0] knob_id,knob_value;wire [1:0] knob_envelope;
    knob5_controls knobs(.clk(clk),.reset_n(reset_n),.a_n(enc_a_n),.b_n(enc_b_n),.sw_n({enc_sw_n,4'hf}),
      .grant(!external_commit&&ENABLE_ENCODER!=0),.volume(volume),.bend(bend),.attack(attack),.decay(decay),.sustain(sustain),.release_time(release_time),
      .fx(fx_params),.commit(knob_commit),.id(knob_id),.value(knob_value),.envelope_selection(knob_envelope));
    wire commit=external_commit||knob_commit;
    wire [7:0] command_id=ui_commit?ui_id:bt_commit?bt_id:usb_commit?usb_id:external_commit?8'h2e:knob_id;
    wire [7:0] command_value=ui_commit?ui_value:bt_commit?bt_value:usb_commit?usb_value:press0?8'd1:bt_mode_event?{7'd0,bt_auto}:usb_mode_event?{7'd0,usb_auto}:knob_value;
    wire local_fx_commit=ui_commit||knob_commit;
    wire [7:0] local_fx_id=ui_commit?ui_id:knob_id,local_fx_value=ui_commit?ui_value:knob_value;
    // WAX protocol/settings and pressure equations restored from the 20261101
    // handoff; pressure RAM reads staged for timing. Clock stays 26.25 MHz.
    wire [15:0] wax_keys,wax_cal,wax_good,wax_bad,wax_on,wax_off;
    wire [143:0] wax_gains;wire [383:0] wax_raw,wax_baselines,wax_thresholds;
    wire [7:0] wax_model;wire [23:0] wax_full,wax_peak,wax_delta;
    wire wax_enabled,wax_continuous,wax_configured,wax_online,wax_ready,wax_calibrating,wax_noisy,wax_frame;
    wax_pressure_frontend wax_input(.clk(clk),.reset_n(reset_n),.sample_tick(sample_tick),.WAX_RX(WAX_RX),.WAX_TX(WAX_TX),
      .config_commit(commit),.config_id(command_id),.config_value(command_value),.pressure_keys(wax_keys),.pressure_gains(wax_gains),
      .raw_values(wax_raw),.baselines(wax_baselines),.thresholds(wax_thresholds),.calibrated_mask(wax_cal),.good_frames(wax_good),.bad_frames(wax_bad),
      .model(wax_model),.enabled(wax_enabled),.continuous(wax_continuous),.configured(wax_configured),.online(wax_online),.ready(wax_ready),
      .calibrating(wax_calibrating),.noisy(wax_noisy),.on_delta(wax_on),.off_delta(wax_off),.full_scale(wax_full),.peak(wax_peak),.delta_peak(wax_delta),.frame_valid(wax_frame));
    wire [223:0] wax_display;wire [783:0] wax_telemetry;genvar wp;
    assign wax_telemetry[7:0]={1'b0,wax_online,wax_configured,wax_continuous,wax_enabled,wax_noisy,wax_calibrating,wax_ready};
    assign wax_telemetry[15:8]=wax_model;assign wax_telemetry[31:16]=wax_good;assign wax_telemetry[47:32]=wax_bad;
    assign wax_telemetry[63:48]=wax_keys;assign wax_telemetry[79:64]=wax_on;assign wax_telemetry[95:80]=wax_off;
    assign wax_telemetry[119:96]=wax_full;assign wax_telemetry[143:120]=wax_peak;
    generate for(wp=0;wp<16;wp=wp+1)begin:wax_values
      assign wax_display[wp*14+:14]=wax_raw[wp*24+:24]>16383?14'd16383:wax_raw[wp*24+:14];
      assign wax_telemetry[(18+wp*3)*8+:24]=wax_raw[wp*24+:24];
      assign wax_telemetry[(66+wp*2)*8+:16]={7'd0,wax_gains[wp*9+:9]};
    end endgenerate
    wire [23:0] wax_selected_raw=wax_raw[selected[3:0]*24+:24],wax_selected_base=wax_baselines[selected[3:0]*24+:24],wax_selected_threshold=wax_thresholds[selected[3:0]*24+:24];
    competition_control #(.ENABLE_PRESSURE(1)) control(.pressure_keys(wax_keys),.pressure_gains(wax_gains),.clk(clk),.reset_n(reset_n),.tick(sample_tick),.touch_keys(touch_keys),.serial_keys({usb_hi,usb_lo}),.bluetooth_keys({bt_hi,bt_lo}),
      .commit(commit),.id(command_id),.value(command_value),.effect_flags(fx_params[7:0]),.ui_stop(ui_stop||press1),.ui_live(ui_live),.record_playing(replaying),.axis_valid(axis_valid),.axis_bend(axis_bend),.axis_gain(axis_gain),.axis_vibrato(axis_vibrato),
      .volume(volume),.attack(attack),.decay(decay),.release_time(release_time),.sustain(sustain),.instrument(instrument),.guitar_chord(guitar_chord),.guitar_analysis(guitar_analysis),.stopped(stopped),.clear_audio(clear_audio),
      .hold_mode(hold_mode),.test_count(test_count),.selected(selected),.test_muted(test_muted),.bend(bend),.gain(gain),.vibrato(vibrato),.vibrato_override(vibrato_override),.bpm(bpm),.song(song),
      .practice_command_valid(practice_command_valid),.practice_command(practice_command),.record_command_valid(record_command_valid),.record_command(record_command),.record_query(record_query),
      .audio_command_valid(audio_command_valid),.audio_command(audio_command),.record_auto_trigger(record_auto_trigger),.mapping_reset_done(mapping_reset_done),
      .note_numbers(note_numbers),.performance_keys(control_keys),.newest_voice(newest_voice),.voice_gains(voice_gains),
      .upload_expected(upload_expected),.upload_received(upload_received),.upload_ready(upload_ready),.upload_matrix_ok(upload_matrix_ok),.song_read_address(song_address),.song_note(song_note),.song_duration(song_duration));
    fx_registers fx_control(.clk(clk),.reset_n(reset_n),.usb_commit(usb_commit),.bt_commit(bt_commit),.usb_id(usb_id),.usb_value(usb_value),.bt_id(bt_id),.bt_value(bt_value),.ui_commit(local_fx_commit),.ui_id(local_fx_id),.ui_value(local_fx_value),.stopped(stopped),.snapshot(fx_params),.revision(fx_revision));
    wire matrix_mode=page==6;
    // WAX updates its sixteen key bits while scanning a verified frame.
    // Sample the completed vector for scoring after the pressure scan's
    // bounded pipelined pass. This adds 512 clocks (~19.5us) only to guidance;
    // the instrument audio continues to use the original immediate keys.
    reg [15:0] matrix_scoring_keys=0;reg [8:0] matrix_settle=0;reg matrix_pending=0;
    always @(posedge clk)begin
      if(!reset_n)begin matrix_scoring_keys<=0;matrix_settle<=0;matrix_pending<=0;end
      else begin
        if(wax_frame)begin matrix_settle<=511;matrix_pending<=1;end
        else if(matrix_pending)begin
          if(matrix_settle==0)begin matrix_scoring_keys<=wax_ready?wax_keys:16'd0;matrix_pending<=0;end
          else matrix_settle<=matrix_settle-1'b1;
        end
        if(!wax_ready)matrix_scoring_keys<=0;
      end
    end
    wire [7:0] practice_bpm=matrix_mode&&bpm>80?8'd80:bpm;
    // Matrix guidance accepts only real pressure-pad edges. Touch/USB/BT can
    // still play audio, but cannot produce a matrix-training score.
    practice32 #(.ENABLE_PRESSURE_MODE(1)) practice(.clk(clk),.reset_n(reset_n),.tick(sample_tick),.bpm(practice_bpm),.song(song),.note_numbers(note_numbers),
      .pressure_mode(matrix_mode),.pressure_ready(wax_ready),
      .command_valid(practice_command_valid||ui_live),.command(practice_command_valid?practice_command:2'd0),.halt(stopped||test_count!=0),.keys(matrix_mode?{16'd0,matrix_scoring_keys}:(touch_keys|serial_keys|{16'd0,wax_keys})),
      .upload_ready(upload_ready&&(!matrix_mode||upload_matrix_ok)),.upload_length(upload_expected),.uploaded_note(song_note),.uploaded_duration(song_duration),.read_address(song_address),
      .running(practice_running),.paused(practice_paused),.finished(practice_finished),.gate(practice_gate),.step(practice_step),.cue(practice_cue),.progress(practice_progress),.length(practice_length),
      .score(practice_score),.combo(practice_combo),.hits(practice_hits),.misses(practice_misses),.feedback(practice_feedback),.target_note(practice_target),.countdown(practice_countdown),.position(practice_position));
    wire [8:0] query_index_valid;wire recording,record_overflow;wire [9:0] record_count;wire [31:0] replay_keys,query_time,query_keys;wire record_has_notes;wire [15:0] record_seconds;
    event_recorder recorder(.clk(clk),.reset_n(reset_n),.tick(sample_tick),.keys(control_keys),.command_valid(record_command_valid),.command(record_command),.halt(stopped||(practice_running&&replaying)),.query_index(record_query),
      .auto_trigger(record_auto_trigger),.has_notes(record_has_notes),.duration_seconds(record_seconds),.query_time(query_time),.query_keys(query_keys),.query_index_valid(query_index_valid),.recording(recording),.playing(replaying),.overflow(record_overflow),.count(record_count),.playback_keys(replay_keys));
    // Practice is a silent visual guide. User note gates remain connected.
    wire [31:0] live_keys=stopped?32'd0:test_count!=0?control_keys:practice_running?control_keys:replaying?replay_keys:control_keys;
    wire [4:0] bend_target=fx_params[111:104]==32?newest_voice:fx_params[108:104];
    wire signed [15:0] dry_pcm,fx_pcm,conditioned_pcm;wire dry_valid,fx_valid,fx_ready,synth_active,overrun;wire [31:0] active_envelopes;wire [5:0] active_count;wire [15:0] phase0;wire [7:0] envelope0;
    // Fixed level for each selected proof profile; muting a voice does not
    // change this coefficient or the levels of all the other voices.
    wire [8:0] proof_gain=test_count==8?9'd181:test_count==16?9'd128:test_count==32?9'd91:9'd256;
    poly32_synth #(.EXTERNAL_MASTER(1)) synth(.clk(clk),.sample_tick(sample_tick),.clear(!reset_n||clear_audio||stopped),.keys(live_keys),.note_numbers(note_numbers),.voice_gains(voice_gains),.instrument(instrument),
      .song_gate(1'b0),.song_step(24'd0),.volume(volume),.mode_gain(proof_gain),.attack_sel(attack),.decay_sel(decay),.release_sel(release_time),.sustain_level(sustain),
      .expression_bend(bend),.expression_vibrato(effective_vibrato),.target_voice(bend_target),.fx_params(fx_params),.test_mode(test_count!=0),.test_voice_count(test_count),.pcm(dry_pcm),.pcm_valid(dry_valid),.audio_active(synth_active),.active_envelopes(active_envelopes),.active_count(active_count),.phase0(phase0),.envelope0(envelope0),.overrun(overrun));
    // Acceptance tones bypass effect memories and output filtering so that no
    // dry sine component can be hidden by a user wet=100% setting.
    audio_effects effects(.clk(clk),.reset_n(reset_n&&!clear_audio&&!stopped),.sample_tick(dry_valid),.enable(1'b0),.dry(dry_pcm),.params(test_count!=0?128'd0:fx_params),.wet(fx_pcm),.valid(fx_valid),.ready(fx_ready));
    audio_conditioner output_filter(.clk(clk),.reset_n(reset_n&&!clear_audio&&!stopped),.tick(fx_valid),.active(synth_active||fx_pcm!=0),.pcm_in(fx_pcm),.pcm_out(conditioned_pcm));
    audio_master master(.clk(clk),.reset_n(reset_n),.tick(sample_tick),.mute(stopped||!fx_ready),.volume(volume),
      .pcm_in(test_count!=0?dry_pcm:conditioned_pcm),.pcm_out(pcm));
    reg [11:0] startup=0;always @(posedge clk)if(sample_tick&&startup<2048)startup<=startup+1'b1;
    assign PA_EN=(startup<2048);
    reg [31:0] frame_count=0;reg [15:0] peak=0;wire [15:0] magnitude=pcm[15]?-pcm:pcm;
    always @(posedge clk)if(sample_tick)begin frame_count<=frame_count+1'b1;if(magnitude>peak)peak<=magnitude;else if(peak>16)peak<=peak-16;else peak<=0;end
    // Report-processing cycles only. This excludes the sensor's internal scan.
    reg [15:0] report_counter=0,report_latency=0;reg report_pending=0;
    always @(posedge clk)begin
     if(touch_frame)begin report_counter<=0;report_pending<=1;end
     else if(report_pending)begin if(report_counter!=65535)report_counter<=report_counter+1'b1;if(dry_valid)begin report_latency<=report_counter;report_pending<=0;end end
    end
    wire audio_recording,audio_full,audio_armed;wire [4:0] audio_tenths;wire [17:0] audio_count;wire [15:0] audio_read_data;wire [16:0] usb_audio_address,bt_audio_address;
    reg usb_audio_high=0,bt_audio_high=0;
    always @(posedge clk)begin if(usb_commit&&usb_id==8'h62)usb_audio_high<=usb_value[0];if(bt_commit&&bt_id==8'h62)bt_audio_high<=bt_value[0];end
    wire usb_audio_busy,bt_audio_busy,usb_audio_waiting,bt_audio_waiting;
    audio_capture captured_audio(.clk(clk),.reset_n(reset_n),.tick(sample_tick),.pcm(pcm),.command_valid(audio_command_valid),.command(audio_command),
      .read_address(bt_audio_busy?bt_audio_address:usb_audio_address),.read_data(audio_read_data),.recording(audio_recording),.armed(audio_armed),.tenths(audio_tenths),.full(audio_full),.count(audio_count));
    assign info={record_seconds,{audio_armed,record_has_notes,audio_tenths,overrun},{upload_matrix_ok,wax_ready,guitar_analysis,guitar_chord,mapping_reset_done,instrument,practice_finished,practice_running,1'b1,audio_count[17],audio_full,audio_recording,audio_count[16:0]},frame_count,peak,report_latency,note_numbers[selected*8+:8],
      stopped,(test_count!=0),record_overflow,practice_length,practice_progress,upload_ready,test_muted,selected,upload_received,record_count,replaying,recording,practice_paused,song,bpm,effective_vibrato,bend,gain,test_count,hold_mode,bank,active_count,live_keys};
    wire [335:0] telemetry={{7'd0,query_index_valid},query_keys,query_time,info};
    reg [15:0] matrix_last_keys=0;reg [7:0] matrix_previous_progress=0;
    always @(posedge clk)begin
      matrix_previous_progress<=practice_progress;
      if(!reset_n||!matrix_mode||(practice_command_valid&&practice_command==1)||practice_progress!=matrix_previous_progress)matrix_last_keys<=0;
      else if(!practice_paused&&matrix_scoring_keys!=0)matrix_last_keys<=matrix_scoring_keys;
    end
    wire [15:0] visible_keys=bank?live_keys[31:16]:live_keys[15:0];wire [15:0] visible_cue=bank?practice_cue[31:16]:practice_cue[15:0];
    instrument_screen #(.SHOW_FSR(0),.PANEL_UI(1)) display(.clk(lcd_sysclk),.audio_clk(clk),.sample_tick(sample_tick),.pcm(pcm),.performance_info(display_info),.panel_page(page),.fx_params(fx_params),.panel_bend(bend),.selected_pad(selected[3:0]),
      .selected_raw(wax_selected_raw>16383?14'd16383:wax_selected_raw[13:0]),.selected_baseline(wax_selected_base>16383?14'd16383:wax_selected_base[13:0]),.selected_threshold(wax_selected_threshold>16383?14'd16383:wax_selected_threshold[13:0]),.selected_gain(wax_gains[selected[3:0]*9+:9]),.fsr_pressures(wax_display),.bt_rx_count(bt_rx_count),.game_position(practice_position),
      .fsr_ready(wax_ready),.fsr_fault(wax_noisy),.fsr_calibrating(wax_calibrating),.fsr_peak(wax_peak>16383?14'd16383:wax_peak[13:0]),.fsr_keys(matrix_mode?matrix_scoring_keys:wax_keys),.fsr_delta(wax_delta>16383?14'd16383:wax_delta[13:0]),.fsr_threshold(wax_on>16383?14'd16383:wax_on[13:0]),.fsr_cal_mask(wax_cal),
      .auto_mode(practice_running),.stopped(stopped),.game_page(game_page),.game_running(practice_running),.game_finished(practice_finished),.game_score(practice_score),.game_keys(matrix_mode?matrix_last_keys:(bank?(touch_keys[31:16]|serial_keys[31:16]):(touch_keys[15:0]|serial_keys[15:0]|wax_keys))),.game_cue(matrix_mode?practice_cue[15:0]:visible_cue),
      .game_combo(practice_combo),.game_max(practice_combo),.game_hits(practice_hits),.game_misses(practice_misses),.game_progress(practice_progress[5:0]),.game_wrong(10'd0),.game_feedback(practice_feedback),.game_countdown(practice_countdown),.game_target(practice_target[3:0]),.game_next(practice_target[3:0]),
      .instrument(instrument),.touch_chip(touch_chip),.plot_mode(plot_mode),.live_keys(visible_keys),.volume(volume),.attack_sel(attack),.decay_sel(decay),.sustain_level(sustain),.release_sel(release_time),
      .touch_online(touch_online),.cursor_down(cursor_down),.cursor_x(cursor_x),.cursor_y(cursor_y),.orientation(orientation),.finger_count(finger_count),.touch_errors(touch_errors),
      .touch_raw_status(touch_raw_status),.touch_raw_count(touch_raw_count),.touch_report_count(touch_report_count),.touch_raw_x(touch_raw_x),.touch_raw_y(touch_raw_y),.touch_max_x(touch_max_x),.touch_max_y(touch_max_y),
      .r(lcd_r),.g(lcd_g),.b(lcd_b),.pclk(lcd_clk),.hsync(lcd_hsync),.vsync(lcd_vsync),.de(lcd_de),.bl(lcd_bl),.lcd_reset(lcd_reset));
    competition_status #(.ENABLE_WAX(1)) usb_status(.wax(wax_telemetry),.audio_request(usb_commit&&usb_id==8'h61),.audio_block({usb_audio_high,usb_value}),.audio_count(audio_count),.audio_recording(audio_recording),
      .audio_available(!bt_audio_busy&&!bt_audio_waiting),.audio_data(audio_read_data),.audio_address(usb_audio_address),.audio_busy(usb_audio_busy),.audio_waiting(usb_audio_waiting),.clk(clk),.bit_clocks(usb_bit_clocks),.payload(telemetry),.fx(fx_params),.fx_revision(fx_revision),.flags({4'd0,usb_trained,touch_online,clear_audio,practice_running}),
      .rx_count(usb_rx_count),.serial_keys(serial_keys[15:0]),.live_keys(live_keys[15:0]),.active_envelopes(active_envelopes[15:0]),.peak(peak),.phase0(phase0),.frame_count(frame_count[15:0]),
      .last_byte(usb_last),.envelope0(envelope0),.attack({4'd0,attack}),.decay({4'd0,decay}),.sustain(sustain),.release_time({4'd0,release_time}),.param_count(usb_params+bt_params),.volume(volume),.tx(UART_TX));
    competition_status #(.ENABLE_WAX(1)) bt_status(.wax(wax_telemetry),.audio_request(bt_commit&&bt_id==8'h61),.audio_block({bt_audio_high,bt_value}),.audio_count(audio_count),.audio_recording(audio_recording),
      .audio_available(!usb_audio_busy),.audio_data(audio_read_data),.audio_address(bt_audio_address),.audio_busy(bt_audio_busy),.audio_waiting(bt_audio_waiting),.clk(clk),.bit_clocks(bt_bit_clocks),.payload(telemetry),.fx(fx_params),.fx_revision(fx_revision),.flags({4'd0,bt_trained,touch_online,clear_audio,practice_running}),
      .rx_count(bt_rx_count),.serial_keys(serial_keys[15:0]),.live_keys(live_keys[15:0]),.active_envelopes(active_envelopes[15:0]),.peak(peak),.phase0(phase0),.frame_count(frame_count[15:0]),
      .last_byte(bt_last),.envelope0(envelope0),.attack({4'd0,attack}),.decay({4'd0,decay}),.sustain(sustain),.release_time({4'd0,release_time}),.param_count(usb_params+bt_params),.volume(volume),.tx(BT_TX));
endmodule

// Asynchronous active-low button: two-flop synchronizer, 10 ms debounce.
module button_press #(parameter integer DEBOUNCE_CYCLES=262500)(
    input clk,input button_n,output reg press=0
);
    reg meta=1,sync=1,stable=1;
    reg [18:0] count=0;
    always @(posedge clk) begin
        meta<=button_n; sync<=meta; press<=0;
        if(sync==stable) count<=0;
        else if(count==DEBOUNCE_CYCLES-1) begin
            stable<=sync; count<=0;
            if(!sync) press<=1;
        end else count<=count+1'b1;
    end
endmodule

// Mode change: 1.4 ms fade-out, clear/settle 0.7 ms, 1.4 ms fade-in.
// KEY1 wins simultaneous presses. KEY0 in autoplay restarts from the beginning.
module mode_control(input clk,input sample_tick,input press0,input press1,
    output reg auto_mode=0,output wire clear,output wire [8:0] gain);
    reg [6:0] gain_units=0;
    assign gain={gain_units,2'b00};
    reg desired=0,pending=0;
    reg [1:0] state=3;
    reg [5:0] hold_count=0;
    assign clear=(state==2);
    always @(posedge clk) begin
        if(sample_tick) case(state)
            0: if(pending) state<=1;
            1: if(gain_units!=0) gain_units<=gain_units-1'b1;
               else begin auto_mode<=desired; pending<=0; hold_count<=0; state<=2; end
            2: if(hold_count==31) state<=3;
               else hold_count<=hold_count+1'b1;
            3: if(pending) state<=1;
               else if(gain_units==64) state<=0;
               else gain_units<=gain_units+1'b1;
        endcase
        if(press0) begin desired<=1; pending<=1; end
        if(press1) begin desired<=0; pending<=1; end
    end
endmodule

// 26.25 MHz / (9*2*32) = 45572.9166667 sample frames/s.
// PT8211: 16-bit slots, WS=0 right / WS=1 left, MSB at the WS transition.
module pt8211_tx(input clk,input signed [15:0] pcm_next,
    output reg bck=0,output reg ws=0,output reg din=0,output wire sample_tick);
    reg [3:0] divider=0;
    reg [4:0] bit_index=0;
    reg [15:0] pcm=0;
    assign sample_tick=(divider==8)&&bck&&(bit_index==0);
    always @(posedge clk) begin
        if(divider==8) begin
            divider<=0; bck<=~bck;
            if(bck) begin
                if(bit_index==0) begin ws<=0; din<=pcm_next[15]; pcm<=pcm_next; end
                else if(bit_index<16) din<=pcm[15-bit_index];
                else if(bit_index==16) begin ws<=1; din<=pcm[15]; end
                else din<=pcm[31-bit_index];
                bit_index<=bit_index+1'b1;
            end
        end else divider<=divider+1'b1;
    end
endmodule
