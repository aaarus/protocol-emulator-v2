puts "Reading liberty"
flush stdout
read_liberty $::env(LIBERTY)
puts "Reading mapped netlist"
flush stdout
read_verilog flat.v
puts "Linking design"
flush stdout
link_design top
puts "Reading constraints"
flush stdout
read_sdc constraints.sdc
puts "\nPRE-ROUTE STA: scoped v0.9 model, typical corner, ideal clock, no wire parasitics"
report_units
check_setup -verbose
puts "\nSETUP PATHS"
report_checks -path_delay max -group_path_count 3 -format full_clock_expanded -fields {slew cap fanout} -digits 3
puts "\nHOLD PATHS"
report_checks -path_delay min -group_path_count 3 -format full_clock_expanded -digits 3
puts "\nWORST SLACK"
report_worst_slack -max
report_worst_slack -min
report_tns
puts "\nELECTRICAL LIMITS"
report_check_types -max_slew -max_capacitance -violators
puts "\nUNCONSTRAINED PATH CHECK"
report_checks -unconstrained -group_path_count 3 -digits 3
