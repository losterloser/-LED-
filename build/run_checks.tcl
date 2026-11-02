set root [file normalize [file join [file dirname [info script]] ..]]
set mode [lindex $argv 0]
if {$mode eq ""} {set mode all}
if {$mode ni {all simulate synth implement bitstream}} {error "Use all/ simulate/ synth/ implement/ bitstream"}
set project_file [file join $root board vivado navigator7010_music_rgb_lcd_recognizer.xpr]
if {![file exists $project_file]} {source [file join $root build create_project.tcl]}
open_project $project_file
foreach f [concat [glob [file join $root src rtl *.v]] [glob [file join $root data *.mem]]] {
    if {![llength [get_files -quiet $f]]} {add_files -norecurse $f}
}
update_compile_order -fileset sources_1
set_param general.maxThreads 4
if {$mode in {all simulate}} {
    foreach f [glob [file join $root sim tb *.sv]] {
        if {![llength [get_files -quiet $f]]} {add_files -fileset sim_1 -norecurse $f}
    }
    update_compile_order -fileset sim_1
}
set tests {tb_reset_sync tb_board_controls tb_test_source tb_es8388_init tb_i2c_faults tb_i2s_rx_stereo tb_audio_clocks tb_spectrum_pipeline tb_ws2812_tx tb_rgb_music_ring tb_fft_rgb_integration tb_lcd_timing tb_spectrum_renderer tb_lcd_visualizer tb_fft_lcd_integration tb_top_music_rgb tb_recognition_uart tb_recognition_decimator tb_pcm_uart tb_song_overlay tb_song_lcd_integration}
if {$mode in {all simulate}} {
    set requested [lrange $argv 1 end]
    if {[llength $requested]} {set tests $requested}
    foreach tb $tests {
        set_property top $tb [get_filesets sim_1]
        launch_simulation -simset sim_1 -mode behavioral
        run all
        close_sim
        set logpath [file join $root board vivado navigator7010_music_rgb_lcd_recognizer.sim sim_1 behav xsim simulate.log]
        file copy -force $logpath [file join $root build current ${tb}.log]
        set fh [open $logpath r]; set contents [read $fh]; close $fh
        if {[string first "PASS $tb" $contents]<0 || [regexp -nocase {fatal:} $contents]} {error "FAILED $tb; see reports/${tb}.log"}
        puts "TEST_PASSED: $tb"
        if {$tb eq "tb_spectrum_pipeline"} {
            file copy -force [file join [file dirname $logpath] fft_first_frame.csv] [file join $root build current fft_first_frame.csv]
        }
        if {$tb eq "tb_fft_lcd_integration"} {
            file copy -force [file join [file dirname $logpath] lcd_spectrum.ppm] [file join $root build current lcd_spectrum.ppm]
        }
        if {$tb eq "tb_pcm_uart"} {
            file copy -force [file join [file dirname $logpath] pcm_uart_capture.hex] [file join $root build current pcm_uart_capture.hex]
        }
        if {$tb eq "tb_song_lcd_integration"} {
            file copy -force [file join [file dirname $logpath] lcd_song_overlay.ppm] [file join $root build current lcd_song_overlay.ppm]
        }
    }
    set_property top tb_top_music_rgb [get_filesets sim_1]
}
if {$mode ne "simulate"} {
    if {[get_property NEEDS_REFRESH [get_runs synth_1]]} {reset_run synth_1}
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
        launch_runs synth_1 -jobs 4
        wait_on_run synth_1
    }
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
    open_run synth_1
    report_utilization -file [file join $root build current utilization_synth.txt]
    report_timing_summary -file [file join $root build current timing_synth.txt]
    report_cdc -file [file join $root build current cdc_synth.txt]
    if {$mode ne "synth"} {
        close_design
        if {[get_property NEEDS_REFRESH [get_runs impl_1]] || [string match -nocase {*ERROR*} [get_property STATUS [get_runs impl_1]]]} {reset_run impl_1}
        set need_bit [expr {$mode in {all bitstream}}]
        set bit_file [file join $root board vivado navigator7010_music_rgb_lcd_recognizer.runs impl_1 top_music_rgb.bit]
        if {[get_property PROGRESS [get_runs impl_1]] ne "100%" || ($need_bit && ![file exists $bit_file])} {
            if {$need_bit} {launch_runs impl_1 -to_step write_bitstream -jobs 4} else {launch_runs impl_1 -jobs 4}
            wait_on_run impl_1
        }
        if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
        open_run impl_1
        report_utilization -file [file join $root build current utilization_impl.txt]
        report_timing_summary -report_unconstrained -file [file join $root build current timing_impl.txt]
        report_cdc -file [file join $root build current cdc_impl.txt]
        report_bus_skew -file [file join $root build current bus_skew_impl.txt]
        report_drc -file [file join $root build current drc_impl.txt]
        check_timing -verbose -file [file join $root build current check_timing_impl.txt]
        report_io -file [file join $root build current io_impl.txt]
        set setup_path [get_timing_paths -delay_type max -max_paths 1]
        set hold_path [get_timing_paths -delay_type min -max_paths 1]
        if {[llength $setup_path]==0 || [get_property SLACK $setup_path]<0} {error "Setup timing not met"}
        if {[llength $hold_path]==0 || [get_property SLACK $hold_path]<0} {error "Hold timing not met"}
        if {[llength [get_ports -quiet -filter {PACKAGE_PIN == ""}]]} {error "Unassigned I/O pin"}
        if {[llength [get_ports -quiet -filter {IOSTANDARD == DEFAULT}]]} {error "Missing I/O standard"}
        if {$mode in {all bitstream}} {
            foreach ext {bit ltx} {
                set artifact [file join $root board vivado navigator7010_music_rgb_lcd_recognizer.runs impl_1 top_music_rgb.$ext]
                if {![file exists $artifact]} {error "Missing $ext artifact"}
                file copy -force $artifact [file join $root board output navigator7010_music_rgb_lcd_recognizer.$ext]
            }
        }
        puts "IMPLEMENTATION_PASSED: setup/hold met, all I/O assigned"
    }
}
close_project
puts "CHECKS_COMPLETE: $mode"
exit
