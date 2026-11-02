set root [file normalize [file join [file dirname [info script]] ..]]
set project_file [file join $root board vivado navigator7010_music_rgb_lcd_recognizer.xpr]
if {[file exists $project_file]} {error "Project already exists: $project_file"}
foreach dir {{build current} {board output}} {file mkdir [file join $root {*}$dir]}
create_project navigator7010_music_rgb_lcd_recognizer [file join $root board vivado] -part xc7z010clg400-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property sim.use_ip_compiled_libs false [current_project]
add_files -norecurse [glob [file join $root src rtl *.v]]
add_files -norecurse [glob [file join $root data *.mem]]
add_files -fileset constrs_1 -norecurse [file join $root src constraints navigator_v39.xdc]
add_files -fileset sim_1 -norecurse [glob [file join $root sim tb *.sv]]
set_property top top_music_rgb [get_filesets sources_1]
set_property verilog_define {HARDWARE_DEBUG} [get_filesets sources_1]
set_property top tb_fft_rgb_integration [get_filesets sim_1]
set_property verilog_define {SIMULATION} [get_filesets sim_1]
set_property xsim.simulate.runtime {0ns} [get_filesets sim_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
create_ip -name xfft -vendor xilinx.com -library ip -version 9.1 -module_name fft_1024
set_property -dict [list CONFIG.transform_length {1024} CONFIG.implementation_options {radix_2_burst_io} CONFIG.data_format {fixed_point} CONFIG.input_width {16} CONFIG.phase_factor_width {16} CONFIG.scaling_options {unscaled} CONFIG.output_ordering {natural_order} CONFIG.throttle_scheme {nonrealtime} CONFIG.aresetn {true}] [get_ips fft_1024]
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_music
set_property -dict [list CONFIG.C_NUM_OF_PROBES {14} CONFIG.C_DATA_DEPTH {1024} CONFIG.C_EN_STRG_QUAL {1} CONFIG.C_PROBE0_WIDTH {64} CONFIG.C_PROBE1_WIDTH {1} CONFIG.C_PROBE2_WIDTH {160} CONFIG.C_PROBE3_WIDTH {128} CONFIG.C_PROBE4_WIDTH {8} CONFIG.C_PROBE5_WIDTH {16} CONFIG.C_PROBE6_WIDTH {32} CONFIG.C_PROBE7_WIDTH {4} CONFIG.C_PROBE8_WIDTH {32} CONFIG.C_PROBE9_WIDTH {32} CONFIG.C_PROBE10_WIDTH {1} CONFIG.C_PROBE11_WIDTH {1} CONFIG.C_PROBE12_WIDTH {32} CONFIG.C_PROBE13_WIDTH {8}] [get_ips ila_music]
generate_target all [get_ips]
export_ip_user_files -of_objects [get_ips] -no_script -sync -force -quiet
set_property used_in_simulation false [get_files -all *ila_music.xci]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "PROJECT_READY: $project_file"
close_project
