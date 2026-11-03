create_clock -name clk_50m -period 20 [get_ports {clk_50m}]
create_generated_clock -name lcd_sysclk -source [get_ports {clk_50m}] -multiply_by 21 -divide_by 20 [get_nets {lcd_sysclk}]
create_generated_clock -name audio_clk -source [get_nets {lcd_sysclk}] -divide_by 2 [get_nets {clk}]
