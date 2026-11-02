set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root board vivado navigator7010_music_rgb_lcd_recognizer.xpr]
open_run impl_1
report_bus_skew -file [file join $root build current bus_skew_impl.txt]
report_clocks -file [file join $root build current clocks_impl.txt]
set fh [open [file join $root build current implemented_properties.txt] w]
puts $fh "part=[get_property PART [current_design]]"
puts $fh "usr_access=[get_property BITSTREAM.CONFIG.USR_ACCESS [current_design]]"
puts $fh "cfgbvs=[get_property CFGBVS [current_design]]"
puts $fh "config_voltage=[get_property CONFIG_VOLTAGE [current_design]]"
puts $fh "ila_instances=[get_cells -hier -filter {REF_NAME == ila_music}]"
foreach p [lsort [get_ports]] {
    puts $fh "$p package_pin=[get_property PACKAGE_PIN $p] iostandard=[get_property IOSTANDARD $p]"
}
close $fh
close_project
puts "POST_ROUTE_REPORTS_COMPLETE"
exit
