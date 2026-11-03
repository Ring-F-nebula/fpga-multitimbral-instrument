onerror {quit -code 1}
set root [file normalize $env(WAX_HANDOFF_ROOT)]
set scratch [file normalize $env(WAX_HANDOFF_TEST_WORK)]
cd [file join $scratch core]
vlib work
vlog -sv [file join $root pressure_port rtl wax_uart_rx.v] [file join $root pressure_port rtl wax_packet.v] [file join $root pressure_port rtl wax_pressure.v] [file join $root pressure_port rtl wax_settings.v] [file join $root pressure_port rtl wax_pressure_frontend.v] [file join $root pressure_port optional uart_tx.v] [file join $root pressure_port tests tb_wax_protocol.sv] [file join $root pressure_port tests tb_wax_settings.sv] [file join $root pressure_port tests tb_wax_pressure.sv]
foreach bench {tb_wax_protocol tb_wax_settings tb_wax_pressure} {
 vsim -onfinish stop work.$bench
 run -all
 quit -sim
}
vsim -onfinish stop work.wax_pressure_frontend
run 0 ns
quit -sim
foreach mode {legacy patched} {
 cd [file join $scratch $mode]
 vlib work
 vlog -sv +incdir+. uart_link_review.v [file join $root pressure_port rtl wax_settings.v] [file join $root pressure_port rtl wax_uart_rx.v] [file join $root pressure_port tests tb_wax_host_config.sv]
 if {$mode eq "legacy"} {vsim -onfinish stop -gEXPECT_LEGACY_BLOCK=1 work.tb_wax_host_config} else {vsim -onfinish stop work.tb_wax_host_config}
 run -all
 quit -sim
}
quit -code 0
