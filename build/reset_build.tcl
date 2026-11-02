set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root board vivado navigator7010_music_rgb_lcd_recognizer.xpr]
catch {stop_runs impl_1}
reset_run synth_1
close_project
puts "BUILD_RUNS_RESET"
exit
