// Optional binding for legacy audio-only top tests; real LCD pixels and game integration are tested separately.
module lcd_test_stub #(parameter integer SHOW_FSR=0,parameter integer PANEL_UI=0)(input clk,audio_clk,sample_tick,
    input fsr_ready,fsr_fault,fsr_calibrating,input [13:0] fsr_peak,input [15:0] fsr_keys,
    input [13:0] fsr_delta,fsr_threshold,input [15:0] fsr_cal_mask,
    input [255:0] performance_info,input [2:0] panel_page,input [127:0] fx_params,input signed [8:0] panel_bend,input [3:0] selected_pad,
    input [13:0] selected_raw,selected_baseline,selected_threshold,input [8:0] selected_gain,
    input [223:0] fsr_pressures,input [15:0] bt_rx_count,input signed [10:0] game_position,
    input signed [15:0] pcm,input auto_mode,stopped,
    input game_page,game_running,game_finished,
    input [15:0] game_score,game_keys,game_cue,
    input [5:0] game_combo,game_max,game_hits,game_misses,game_progress,
    input [9:0] game_wrong,input [2:0] game_feedback,input [1:0] game_countdown,
    input [3:0] game_target,game_next,
    input [1:0] instrument,touch_chip,
    input [2:0] plot_mode,
    input [15:0] live_keys,
    input [3:0] volume,attack_sel,decay_sel,release_sel,
    input [7:0] sustain_level,
    input touch_online,cursor_down,
    input [10:0] cursor_x,input [9:0] cursor_y,
    input [2:0] orientation,finger_count,
    input [15:0] touch_errors,
    input [7:0] touch_raw_status,
    input [3:0] touch_raw_count,
    input [15:0] touch_report_count,
    input [11:0] touch_raw_x,touch_raw_y,touch_max_x,touch_max_y,
    output wire [7:0] r,g,b,
    output wire pclk,bl,lcd_reset,
    output reg hsync=0,vsync=0,de=0);
    reg [10:0] h=0;
    reg [9:0] v=0;
    lcd_stub_scope scope();
    assign r=0;assign g=0;assign b=0;
    assign pclk=~clk;assign bl=1;assign lcd_reset=1;
endmodule
module lcd_stub_scope;
    reg audio_toggle=0;
endmodule
config cfg_tb_integration;
    design work.tb_integration;
    default liblist work;
    instance tb_integration.dut.display use work.lcd_test_stub;
    instance tb_integration.dut.clock_gen use work.merged_clock_test_stub;
    instance tb_integration.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig
config cfg_tb_touch_top;
    design work.tb_touch_top;
    default liblist work;
    instance tb_touch_top.dut.display use work.lcd_test_stub;
    instance tb_touch_top.dut.clock_gen use work.merged_clock_test_stub;
    instance tb_touch_top.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig

config cfg_tb_laser_merge;
 design work.tb_laser_merge;
 default liblist work;
 instance tb_laser_merge.dut.display use work.lcd_test_stub;
    instance tb_laser_merge.dut.clock_gen use work.merged_clock_test_stub;
    instance tb_laser_merge.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig

config cfg_tb_touch_bluetooth_merge;
 design work.tb_touch_bluetooth_merge;
 default liblist work;
 instance tb_touch_bluetooth_merge.dut.display use work.lcd_test_stub;
    instance tb_touch_bluetooth_merge.dut.clock_gen use work.merged_clock_test_stub;
    instance tb_touch_bluetooth_merge.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig

config cfg_tb_fsr_top;
    design work.tb_fsr_top;
    default liblist work;
    instance tb_fsr_top.dut.display use work.lcd_test_stub;
    instance tb_fsr_top.dut.clock_gen use work.merged_clock_test_stub;
    instance tb_fsr_top.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig

config cfg_tb_fsr_guard_top;
    design work.tb_fsr_guard_top;
    default liblist work;
    instance tb_fsr_guard_top.dut.display use work.lcd_test_stub;
    instance tb_fsr_guard_top.dut.clock_gen use work.merged_clock_test_stub;
    instance tb_fsr_guard_top.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig

// Functional integration clock model. The actual Gowin PLL is separately tested
// by tb_merged_clock with the vendor primitive model and no substitution.
`timescale 1ns/1ps
module merged_clock_test_stub(input clkin,output reg clkout=0,output reg locked=0);
 initial begin
  repeat(50) @(posedge clkin);locked=1;
  forever #9.523809524 clkout=~clkout;
 end
endmodule

config cfg_tb_bt_audio;
 design work.tb_bt_audio;
 default liblist work;
 instance tb_bt_audio.dut.display use work.lcd_test_stub;
 instance tb_bt_audio.dut.clock_gen use work.merged_clock_test_stub;
 instance tb_bt_audio.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig

config cfg_tb_game_bluetooth;
 design work.tb_game_bluetooth;
 default liblist work;
 instance tb_game_bluetooth.dut.display use work.lcd_test_stub;
 instance tb_game_bluetooth.dut.clock_gen use work.merged_clock_test_stub;
 instance tb_game_bluetooth.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig

config cfg_tb_game_top;
 design work.tb_game_top;
 default liblist work;
 instance tb_game_top.dut.display use work.lcd_test_stub;
 instance tb_game_top.dut.clock_gen use work.merged_clock_test_stub;
 instance tb_game_top.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig

config cfg_tb_fx_stop_top;
 design work.tb_fx_stop_top;default liblist work;
 instance tb_fx_stop_top.dut.display use work.lcd_test_stub;
 instance tb_fx_stop_top.dut.clock_gen use work.merged_clock_test_stub;
 instance tb_fx_stop_top.dut.fsr_adc.adc_i use work.fsr_adc_test_stub;
endconfig
