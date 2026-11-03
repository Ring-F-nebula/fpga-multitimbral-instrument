// One authoritative hardware state for local touch and validated UART writes.
module competition_control #(parameter integer ENABLE_PRESSURE=0)(input clk,reset_n,tick,input [31:0] touch_keys,serial_keys,bluetooth_keys,
 input [15:0] pressure_keys,input [143:0] pressure_gains,
 input commit,input [7:0] id,value,effect_flags,input ui_stop,ui_live,record_playing,input [2:0] axis_valid,
 input signed [8:0] axis_bend,input [8:0] axis_gain,input [6:0] axis_vibrato,
 output reg [3:0] volume=8,attack=0,decay=5,release_time=5,output reg [7:0] sustain=160,
 output reg [1:0] instrument=0,output reg [2:0] guitar_chord=0,output reg guitar_analysis=1,output reg stopped=0,output reg clear_audio=0,
 output reg hold_mode=0,output reg [5:0] test_count=0,output reg [4:0] selected=0,
 output reg test_muted=0,output reg signed [8:0] bend=0,output reg [8:0] gain=256,
 output reg vibrato_override=0,output reg [6:0] vibrato=0,output reg [7:0] bpm=120,output reg [1:0] song=0,
 output reg practice_command_valid=0,output reg [1:0] practice_command=0,
 output reg record_command_valid=0,output reg [1:0] record_command=0,
 output reg audio_command_valid=0,output reg [1:0] audio_command=0,output reg record_auto_trigger=0,
 output reg mapping_reset_done=0,output reg [8:0] record_query=0,output [255:0] note_numbers,
 output [31:0] performance_keys,output reg [4:0] newest_voice=0,
 output [287:0] voice_gains,
 output reg [7:0] upload_expected=0,upload_received=0,output reg upload_ready=0,upload_matrix_ok=0,
 input [6:0] song_read_address,output reg [7:0] song_note=255,song_duration=4);
 reg [31:0] held=0,previous_touch=0,previous_keys=0,blocked_touch=0,blocked_serial=0,blocked_bluetooth=0;
 reg [255:0] midi=0;reg [287:0] gains=0;reg [4:0] map_index=0;
 reg [7:0] upload_index=0,upload_note=255,upload_duration=4,upload_crc=0;
 reg upload_matrix_candidate=1;
 reg [15:0] song_memory[0:127];
 always @(posedge clk)begin {song_note,song_duration}<=song_memory[song_read_address];end
 reg [15:0] blocked_pressure=0;reg [31:0] previous_other=0;
 wire [15:0] allowed_pressure=ENABLE_PRESSURE?(pressure_keys&~blocked_pressure):16'd0;
 wire [31:0] other_physical=(touch_keys&~blocked_touch)|(serial_keys&~blocked_serial)|(bluetooth_keys&~blocked_bluetooth);
 wire [31:0] physical_keys=other_physical|{16'd0,allowed_pressure};wire [31:0] raw=hold_mode?held:physical_keys;
 wire [31:0] test_keys;integer i;
 assign performance_keys=stopped?32'd0:test_count!=0?test_keys:raw;
 genvar n;generate for(n=0;n<32;n=n+1)begin: packed_state
  // Fixed chromatic guitar slots E2..B4 keep recording events self-contained:
  // changing a chord chooses different slots, never retunes a ringing voice.
  assign note_numbers[n*8+:8]=(instrument==1)?8'd40+n:midi[n*8+:8];
  assign voice_gains[n*9+:9]=gains[n*9+:9];
  assign test_keys[n]=(n<test_count)&&!(test_muted&&selected==n);
 end endgenerate
 reg [8:0] old_gain=256;
 always @(posedge clk)begin
  clear_audio<=0;practice_command_valid<=0;record_command_valid<=0;audio_command_valid<=0;
  if(!reset_n)begin
   volume<=8;attack<=0;decay<=5;release_time<=5;sustain<=160;instrument<=0;guitar_chord<=0;guitar_analysis<=1;stopped<=0;held<=0;hold_mode<=0;
   blocked_pressure<=0;previous_other<=0;previous_touch<=0;previous_keys<=0;blocked_touch<=0;blocked_serial<=0;blocked_bluetooth<=0;test_count<=0;selected<=0;test_muted<=0;bend<=0;gain<=256;vibrato<=0;vibrato_override<=0;bpm<=120;song<=0;
   upload_ready<=0;upload_matrix_ok<=0;upload_matrix_candidate<=1;upload_expected<=0;upload_received<=0;record_query<=0;newest_voice<=0;old_gain<=256;mapping_reset_done<=0;
   for(i=0;i<32;i=i+1)begin midi[i*8+:8]<=60+i;gains[i*9+:9]<=256;end
  end else begin
   previous_touch<=physical_keys;previous_keys<=performance_keys;previous_other<=other_physical;old_gain<=gain;
   if(stopped)blocked_pressure<=pressure_keys;else blocked_pressure<=blocked_pressure&pressure_keys;
   if(stopped)begin blocked_touch<=touch_keys;blocked_serial<=serial_keys;blocked_bluetooth<=bluetooth_keys;held<=0;end else begin blocked_touch<=blocked_touch&touch_keys;blocked_serial<=blocked_serial&serial_keys;blocked_bluetooth<=blocked_bluetooth&bluetooth_keys;end
   if(hold_mode&&!stopped)held<=held^(physical_keys&~previous_touch);
   for(i=0;i<32;i=i+1)begin
    if(performance_keys[i]&&!previous_keys[i])begin newest_voice<=i;gains[i*9+:9]<=gain;end
    else if(newest_voice==i&&gain!=old_gain)gains[i*9+:9]<=gain;
    // Merge only at per-voice gain registers. Other physical inputs retain
    // priority; pressure cannot change proof-profile or replay amplitudes.
    if(ENABLE_PRESSURE && i<16 && test_count==0 && !record_playing && !stopped)begin
     if(other_physical[i]&&!previous_other[i])gains[i*9+:9]<=gain;
     else if(allowed_pressure[i]&&!other_physical[i])gains[i*9+:9]<=pressure_gains[i*9+:9];
    end
   end
   if(axis_valid[0])bend<=axis_bend;
   if(axis_valid[1])gain<=axis_gain;
   if(axis_valid[2])begin vibrato<=axis_vibrato;vibrato_override<=1;end
   if(ui_stop)begin stopped<=1;clear_audio<=1;held<=0;test_count<=0;record_command_valid<=1;record_command<=0;audio_command_valid<=1;audio_command<=0;end
   else if(ui_live)begin stopped<=0;clear_audio<=stopped||test_count!=0;test_count<=0;test_muted<=0;if(record_playing===1'b1)begin record_command_valid<=1;record_command<=0;end end
   if(commit)case(id)
    1:attack<=value[3:0];2:decay<=value[3:0];3:sustain<=value;4:release_time<=value[3:0];5:volume<=value[3:0];
    8'h23:begin instrument<=value[1:0];clear_audio<=1;held<=0;if(value[1:0]==1)hold_mode<=0;blocked_pressure<=pressure_keys;blocked_touch<=touch_keys;blocked_serial<=serial_keys;blocked_bluetooth<=bluetooth_keys;end
    8'h24:bend<=($signed({1'b0,value})-9'sd100)*2;
    8'h25:gain<=value==255?9'd256:{1'b0,value};
    8'h26:begin vibrato<=value[6:0];vibrato_override<=1;end
    8'h27:begin test_count<=value[5:0];test_muted<=0;selected<=0;held<=0;blocked_pressure<=pressure_keys;blocked_touch<=touch_keys;blocked_serial<=serial_keys;blocked_bluetooth<=bluetooth_keys;clear_audio<=1;end
    8'h28:selected<=value[4:0];8'h29:test_muted<=value[0];
    8'h2a:begin hold_mode<=value[0];held<=value[0]?physical_keys:32'd0;end
    8'h2b:begin held<=0;blocked_pressure<=pressure_keys;blocked_touch<=touch_keys;blocked_serial<=serial_keys;blocked_bluetooth<=bluetooth_keys;clear_audio<=1;end
    8'h2c:bpm<=value;8'h2d:begin song<=value[1:0];practice_command_valid<=1;practice_command<=0;end
    8'h2e:begin practice_command_valid<=1;practice_command<=value[1:0];if(value==1)begin stopped<=0;clear_audio<=1;held<=0;hold_mode<=0;test_count<=0;test_muted<=0;end end
    8'h30:map_index<=value[4:0];8'h31:begin midi[map_index*8+:8]<=value;mapping_reset_done<=0;end
    8'h32:begin
     for(i=0;i<32;i=i+1)midi[i*8+:8]<=60+i;
     mapping_reset_done<=1;selected<=0;map_index<=0;held<=0;hold_mode<=0;clear_audio<=1;
     blocked_pressure<=pressure_keys;blocked_touch<=touch_keys;blocked_serial<=serial_keys;blocked_bluetooth<=bluetooth_keys;
    end
    8'h40:begin upload_expected<=value;upload_received<=0;upload_ready<=0;upload_matrix_ok<=0;upload_matrix_candidate<=1;upload_crc<=value;upload_index<=0;end
    8'h41:upload_index<=value;
    8'h42:upload_note<=value;
    8'h43:upload_duration<=value;
    8'h44:if(upload_index==upload_received&&upload_received<upload_expected&&upload_expected<=128)begin
     song_memory[upload_index[6:0]]<={upload_note,upload_duration};upload_received<=upload_received+1'b1;upload_crc<=upload_crc^upload_note^upload_duration;
     if(upload_note>=16&&upload_note!=255)upload_matrix_candidate<=0;
    end
    8'h45:begin upload_ready<=(upload_received==upload_expected&&upload_expected!=0&&upload_crc==value);
      upload_matrix_ok<=(upload_received==upload_expected&&upload_expected!=0&&upload_crc==value&&upload_matrix_candidate);end
    8'h50:begin record_command_valid<=1;record_command<=value[1:0];record_auto_trigger<=0;if(value==2)begin stopped<=0;held<=0;test_count<=0;end end
    8'h60:begin audio_command_valid<=1;audio_command<=value[1:0];end
    8'h63:begin
     record_command_valid<=1;record_command<=value[1:0];record_auto_trigger<=1;
     audio_command_valid<=1;audio_command<=value==1?2'd3:value==3?2'd2:2'd0;
     if(value==1)begin
      practice_command_valid<=1;practice_command<=0;
      stopped<=0;clear_audio<=1;held<=0;hold_mode<=0;test_count<=0;test_muted<=0;
      blocked_pressure<=pressure_keys;blocked_touch<=touch_keys;blocked_serial<=serial_keys;blocked_bluetooth<=bluetooth_keys;
     end
     if(value==2)begin stopped<=0;clear_audio<=1;held<=0;hold_mode<=0;test_count<=0;practice_command_valid<=1;practice_command<=0;end
    end
    8'h10:if(value[4]!=effect_flags[4])begin vibrato_override<=0;vibrato<=0;end
    8'h1c:vibrato_override<=0;
    8'h51:record_query[7:0]<=value;8'h52:record_query[8]<=value[0];
    8'h53:begin bend<=0;gain<=256;vibrato<=0;vibrato_override<=0;end
    8'h54:begin guitar_chord<=value[2:0];held<=0;hold_mode<=0;blocked_pressure<=pressure_keys;blocked_touch<=touch_keys;end
    // Legacy layout command remains accepted; the analyzer is now permanent.
    8'h55:guitar_analysis<=1'b1;
    8'h1f:begin stopped<=value[0];clear_audio<=1;held<=0;test_count<=0;end
   endcase
  end
 end
endmodule
