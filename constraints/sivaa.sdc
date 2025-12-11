# SIVAA - Yantra Timing Constraints (SDC)
# For Sky130 @ 50MHz target

# Primary clock
create_clock -name clk -period 20.0 [get_ports clk]

# Clock uncertainty
set_clock_uncertainty 0.5 [get_clocks clk]

# Input/Output delays
set_input_delay -clock clk 2.0 [all_inputs]
set_output_delay -clock clk 2.0 [all_outputs]

# False paths for async signals
set_false_path -from [get_ports rst_n]

# Multicycle paths for Vedic multiplier (2 cycle operation)
# set_multicycle_path 2 -setup -from [get_cells *vedic*] -to [get_cells *regs*]
# set_multicycle_path 1 -hold -from [get_cells *vedic*] -to [get_cells *regs*]

# Max fanout
set_max_fanout 16 [current_design]

# Max transition for reliability
set_max_transition 0.5 [current_design]
