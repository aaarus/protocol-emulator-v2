# Illustrative 10 MHz target; time in ns, capacitance in pF.
create_clock -name core_clk -period 100.0 [get_ports clk]
set_clock_uncertainty -setup 0.5 [get_clocks core_clk]
set_clock_uncertainty -hold 0.1 [get_clocks core_clk]
set_clock_transition 0.1 [get_clocks core_clk]
set data_inputs [get_ports {gpio_pad_in[*] imem_wr_en imem_wr_addr[*] imem_wr_data[*] estimate_smth}]
set_input_delay -clock core_clk -max 20.0 $data_inputs
set_input_delay -clock core_clk -min 2.0 $data_inputs
set_input_transition 0.1 $data_inputs
set_output_delay -clock core_clk -max 20.0 [all_outputs]
set_output_delay -clock core_clk -min 0.0 [all_outputs]
set_load 0.01 [all_outputs]
# Active-low reset held inactive. Reset release timing is outside this analysis.
set_case_analysis 1 [get_ports rst]
