create_clock -name clk_50m -period 20 [get_ports {clk_50m}]
create_generated_clock -name lcd_sysclk -source [get_ports {clk_50m}] -multiply_by 21 -divide_by 20 [get_nets {lcd_sysclk}]
create_generated_clock -name audio_clk -source [get_nets {lcd_sysclk}] -divide_by 2 [get_nets {clk}]

# AD7606 input pads feed synchronizer stages in the 50 MHz domain.
set_false_path -from [get_ports {AD7606_DOUTA AD7606_BUSY AD7606_FRSTDATA}]
# Asynchronous assertion / synchronous release: only these two reset-chain
# registers accept the audio-domain reset asynchronously. All downstream
# ADC registers are released by the synchronized 50 MHz reset.
set_false_path -from [get_clocks {audio_clk}] -to [get_regs {adc_laser.receiver/reset_sync*}]
# The 128-bit sample bus is held for >=1ms. The detector waits for a
# two-stage toggle/status synchronizer and one extra capture cycle.
# Bound this bus instead of constraining unrelated nearest clock edges.
set_max_delay -from [get_clocks {clk_50m}] -to [get_clocks {audio_clk}] 20
set_max_delay -from [get_clocks {clk_50m}] -to [get_ports {AD7606_RESET AD7606_CONVST AD7606_CS_N AD7606_SCLK}] 20
