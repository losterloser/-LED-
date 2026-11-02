set root [file normalize [file join [file dirname [info script]] ..]]
set checkpoint [file join $root board vivado navigator7010_music_rgb_lcd_recognizer.runs impl_1 top_music_rgb_routed.dcp]
if {![file exists $checkpoint]} {error "Missing routed checkpoint"}
open_checkpoint $checkpoint
set part [get_property PART [current_design]]
set access [get_property BITSTREAM.CONFIG.USR_ACCESS [current_design]]
if {$part ne "xc7z010clg400-1" || [string tolower $access] ne "0x4e375231"} {error "Wrong part or extension image ID: $part $access"}
if {[get_property PACKAGE_PIN [get_ports recognition_rx]] ne "T19" ||
    [get_property PACKAGE_PIN [get_ports recognition_tx]] ne "J15"} {error "Wrong PL UART pin map"}
report_clocks -file [file join $root build current clocks_impl.txt]
set fh [open [file join $root build current implemented_properties.txt] w]
puts $fh "part=$part"
puts $fh "usr_access=$access"
puts $fh "uart_baud=500000"
puts $fh "recognition_pcm_rate=12000"
puts $fh "flash_written=0"
foreach p [lsort [get_ports]] {
    puts $fh "$p package_pin=[get_property PACKAGE_PIN $p] iostandard=[get_property IOSTANDARD $p]"
}
close $fh
close_design
puts "RECOGNITION_POST_CHECKPOINT_PASSED"
exit
