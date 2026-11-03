// Optional wiring-only adapter for the four UNCHANGED production WAX modules.
// Clock contract: clk = 26.25 MHz. sample_tick is a one-cycle audio sample strobe.
// config_* is a decoded MAIN-project command interface, not raw WAX bytes.
// This adapter is NOT included in the frozen baseline bitstream/project.
module wax_pressure_frontend(
 input clk,reset_n,sample_tick,
 input WAX_RX,output WAX_TX,
 input config_commit,input [7:0] config_id,config_value,
 output [15:0] pressure_keys,output [143:0] pressure_gains,
 output [383:0] raw_values,baselines,thresholds,
 output [15:0] calibrated_mask,good_frames,bad_frames,
 output [7:0] model,
 output enabled,continuous,configured,online,ready,calibrating,noisy,
 output [15:0] on_delta,off_delta,
 output [23:0] full_scale,peak,delta_peak,
 output frame_valid
);
 wire byte_valid,byte_error,ack_valid,ack_ok,recalibrate;
 wire [7:0] byte_data;
 wire [383:0] samples;
 wax_uart_rx rx(.clk(clk),.reset_n(reset_n),.rx(WAX_RX),
   .valid(byte_valid),.data(byte_data),.error(byte_error));
 wax_packet parser(.clk(clk),.reset_n(reset_n),.byte_valid(byte_valid),
   .byte_error(byte_error),.byte_data(byte_data),.frame_valid(frame_valid),
   .pressures(samples),.model(model),.good_frames(good_frames),.bad_frames(bad_frames),
   .ack_valid(ack_valid),.ack_ok(ack_ok));
 wax_settings settings(.clk(clk),.reset_n(reset_n),.commit(config_commit),
   .id(config_id),.value(config_value),.frame_valid(frame_valid),.detected_model(model),
   .ack_valid(ack_valid),.ack_ok(ack_ok),.recalibrate(recalibrate),.enabled(enabled),
   .continuous(continuous),.on_delta(on_delta),.off_delta(off_delta),.full_scale(full_scale),
   .tx(WAX_TX),.configured(configured));
 wax_pressure pressure(.clk(clk),.reset_n(reset_n),.tick(sample_tick),
   .frame_valid(frame_valid),.recalibrate(recalibrate),.enabled(enabled),
   .continuous(continuous),.samples(samples),.model(model),.min_on(on_delta),
   .min_off(off_delta),.full_scale(full_scale),.keys(pressure_keys),.gains(pressure_gains),
   .raw_values(raw_values),.baselines(baselines),.calibrated_mask(calibrated_mask),
   .online(online),.ready(ready),.calibrating(calibrating),.noisy(noisy),
   .peak(peak),.delta_peak(delta_peak),.thresholds(thresholds));
endmodule
