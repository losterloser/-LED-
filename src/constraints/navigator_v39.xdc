# Navigator ATK-DF7010/7020P V3.9 + XC7Z010 CLG400 core.
# Pin source: board_schematic_V3.9.pdf p2/p5 and official 7010 audio example.
set_property PACKAGE_PIN U18 [get_ports sys_clk]
create_clock -name board_50m -period 20.000 [get_ports sys_clk]
set_property PACKAGE_PIN N16 [get_ports sys_rst_n]
set_property PACKAGE_PIN L14 [get_ports {key_n[0]}]
set_property PACKAGE_PIN K16 [get_ports {key_n[1]}]
set_property PACKAGE_PIN H15 [get_ports {led[0]}]
set_property PACKAGE_PIN L15 [get_ports {led[1]}]
set_property PACKAGE_PIN E18 [get_ports aud_scl]
set_property PACKAGE_PIN F17 [get_ports aud_sda]
set_property PACKAGE_PIN M17 [get_ports aud_adcdat]
set_property PACKAGE_PIN L20 [get_ports aud_lrc]
set_property PACKAGE_PIN G17 [get_ports aud_dacdat]
set_property PACKAGE_PIN E19 [get_ports aud_mclk]
set_property PACKAGE_PIN M18 [get_ports aud_bclk]
# ATK MODULE U4 pin 1 (LED), GBC_LED=N15; old J3-33/T15 is now LCD_R3.
set_property PACKAGE_PIN N15 [get_ports rgb_data]
set_property IOSTANDARD LVCMOS33 [get_ports *]
set_property DRIVE 8 [get_ports {aud_mclk aud_bclk aud_lrc aud_dacdat rgb_data}]
set_property SLEW SLOW [get_ports {aud_mclk aud_bclk aud_lrc aud_dacdat rgb_data}]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS 0x4E375231 [current_design]

# ATK-MD0700R 0x7016 40-pin RGB-LCD interface, official Navigator pin map.
set_property PACKAGE_PIN W18 [get_ports {lcd_rgb[0]}]
set_property PACKAGE_PIN W19 [get_ports {lcd_rgb[1]}]
set_property PACKAGE_PIN R16 [get_ports {lcd_rgb[2]}]
set_property PACKAGE_PIN R17 [get_ports {lcd_rgb[3]}]
set_property PACKAGE_PIN W20 [get_ports {lcd_rgb[4]}]
set_property PACKAGE_PIN V20 [get_ports {lcd_rgb[5]}]
set_property PACKAGE_PIN P18 [get_ports {lcd_rgb[6]}]
set_property PACKAGE_PIN N17 [get_ports {lcd_rgb[7]}]
set_property PACKAGE_PIN V17 [get_ports {lcd_rgb[8]}]
set_property PACKAGE_PIN V18 [get_ports {lcd_rgb[9]}]
set_property PACKAGE_PIN T17 [get_ports {lcd_rgb[10]}]
set_property PACKAGE_PIN R18 [get_ports {lcd_rgb[11]}]
set_property PACKAGE_PIN Y18 [get_ports {lcd_rgb[12]}]
set_property PACKAGE_PIN Y19 [get_ports {lcd_rgb[13]}]
set_property PACKAGE_PIN P15 [get_ports {lcd_rgb[14]}]
set_property PACKAGE_PIN P16 [get_ports {lcd_rgb[15]}]
set_property PACKAGE_PIN V16 [get_ports {lcd_rgb[16]}]
set_property PACKAGE_PIN W16 [get_ports {lcd_rgb[17]}]
set_property PACKAGE_PIN T14 [get_ports {lcd_rgb[18]}]
set_property PACKAGE_PIN T15 [get_ports {lcd_rgb[19]}]
set_property PACKAGE_PIN Y17 [get_ports {lcd_rgb[20]}]
set_property PACKAGE_PIN Y16 [get_ports {lcd_rgb[21]}]
set_property PACKAGE_PIN T16 [get_ports {lcd_rgb[22]}]
set_property PACKAGE_PIN U17 [get_ports {lcd_rgb[23]}]
set_property PACKAGE_PIN N18 [get_ports lcd_hs]
set_property PACKAGE_PIN T20 [get_ports lcd_vs]
set_property PACKAGE_PIN U20 [get_ports lcd_de]
set_property PACKAGE_PIN M20 [get_ports lcd_bl]
set_property PACKAGE_PIN P19 [get_ports lcd_clk]
set_property PACKAGE_PIN L17 [get_ports lcd_rst_n]
set_property PACKAGE_PIN M19 [get_ports touch_rst_n]
set_property DRIVE 8 [get_ports {lcd_rgb[*] lcd_de lcd_clk lcd_hs lcd_vs lcd_bl lcd_rst_n touch_rst_n}]
set_property SLEW FAST [get_ports {lcd_rgb[*] lcd_de lcd_clk}]
# Source-synchronous: official 0x7016 profile, data changed on rising edge,
# panel sampling falling edge. EK79001 reference p32 specifies 5ns setup/hold;
# use 6ns each incl. a 1ns connection budget, pending actual IPS/cable checks.
create_generated_clock -name lcd_pclk -source [get_pins u_lcd/u_pixel_forward/C] -divide_by 1 [get_ports lcd_clk]
set_output_delay -clock lcd_pclk -clock_fall -max 6.000 [get_ports {lcd_rgb[*] lcd_de}]
set_output_delay -clock lcd_pclk -clock_fall -min -6.000 [get_ports {lcd_rgb[*] lcd_de}]

# The oversampling receiver explicitly synchronizes all three codec signals.
# Only these two internal domains are grouped; do not group board_50m together
# with its MMCM descendant or cut internal synchronous logic paths.
set_clock_groups -asynchronous -group [get_clocks board_50m] -group [get_clocks -of_objects [get_pins u_clock/u_codec_buf/O]]
# External asynchronous controls/I2C feedback terminate at first synchronizers.
set_false_path -from [get_ports {key_n[*]}] -to [get_cells -hier -filter {NAME =~ *u_controls/key_meta_reg*}]
set_false_path -from [get_ports aud_adcdat] -to [get_pins -hier -regexp {.*u_rx/sig_meta_reg\[0\]/D}]
set_false_path -from [get_ports aud_scl] -to [get_pins -hier -regexp {.*u_bus/scl_sync_reg\[0\]/D}]
set_false_path -from [get_ports aud_sda] -to [get_pins -hier -regexp {.*u_bus/sda_sync_reg\[0\]/D}]
# No fabricated delays for untimed human controls, open-drain I2C or WS2812.
# check_timing reports on external asynchronous/output ports are documented.

# CH340C routed to PL UART3 by P5 jumpers 3-5 and 4-6 (board schematic p6).
set_property PACKAGE_PIN T19 [get_ports recognition_rx]
set_property PACKAGE_PIN J15 [get_ports recognition_tx]
set_property IOSTANDARD LVCMOS33 [get_ports {recognition_rx recognition_tx}]
set_property PULLUP true [get_ports recognition_rx]
set_property DRIVE 8 [get_ports recognition_tx]
set_property SLEW SLOW [get_ports recognition_tx]
set_false_path -from [get_ports recognition_rx] -to [get_pins -hier -filter {NAME =~ *u_recognition_rx/rx_meta_reg/D}]
