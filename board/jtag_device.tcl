# Read-only by default; 'program' writes volatile PL RAM, never Flash.
set root [file normalize [file join [file dirname [info script]] ..]]
set action [lindex $argv 0]
if {$action eq ""} {set action probe}
if {$action ni {probe program}} {error "Use probe or program"}
set artifact_dir [lindex $argv 1]
if {$artifact_dir eq ""} {set artifact_dir artifacts}
if {$artifact_dir ni {artifacts output}} {error "Choose artifacts (snapshot) or output (rebuilt)"}
set result_dir [file join $root board current jtag_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $result_dir
set failed [catch {
    open_hw_manager
    connect_hw_server -url localhost:3121
    set targets [get_hw_targets -quiet]
    if {[llength $targets]!=1} {error "Expected exactly one JTAG downloader"}
    set target [lindex $targets 0]
    current_hw_target $target
    set_property PARAM.FREQUENCY 1000000 $target
    open_hw_target $target
    set devices [get_hw_devices -quiet -filter {PART =~ xc7z010*}]
    if {[llength $devices]!=1} {error "Expected exactly one XC7Z010"}
    set device [lindex $devices 0]
    current_hw_device $device
    if {$action eq "program"} {
        foreach ext {bit ltx} {
            set path [file join $root board $artifact_dir navigator7010_music_rgb_lcd_recognizer.$ext]
            if {![file exists $path]} {error "Missing $ext in $artifact_dir"}
        }
        set_property PROGRAM.FILE [file join $root board $artifact_dir navigator7010_music_rgb_lcd_recognizer.bit] $device
        set_property PROBES.FILE [file join $root board $artifact_dir navigator7010_music_rgb_lcd_recognizer.ltx] $device
        set_property FULL_PROBES.FILE [file join $root board $artifact_dir navigator7010_music_rgb_lcd_recognizer.ltx] $device
        program_hw_devices $device
    }
    refresh_hw_device $device
    report_property -file [file join $result_dir device.txt] $device
    set done [get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $device]
    set crc [get_property REGISTER.CONFIG_STATUS.BIT00_CRC_ERROR $device]
    set access [string tolower [get_property REGISTER.USR_ACCESS $device]]
    if {$action eq "program" && ($done ne "1" || $crc ne "0" || [string trimleft $access 0x] ne "4e375231")} {error "Configuration DONE/CRC/image identity check failed"}
    set fh [open [file join $result_dir status.txt] w]
    puts $fh "action=$action\ndevice=$device\nprogrammed=[expr {$action eq {program}}]\nflash_written=0\ndone=$done\ncrc_error=$crc\nusr_access=$access"
    close $fh
    puts "JTAG_ACTION_COMPLETE: $action; reports=$result_dir"
} message options]
catch {close_hw_target}
catch {disconnect_hw_server}
catch {close_hw_manager}
if {$failed} {return -options $options $message}
exit
