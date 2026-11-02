`timescale 1ns / 1ps
`default_nettype none
// Display magnitude approximation, not power or calibrated dB.
// Each band holds a PEAK, so unequal band widths are not summed together.
module spectrum_bands #(
    parameter DISPLAY_SHIFT = 14,
    parameter FALL_STEP = 8
)(input wire clk, input wire rst,
  input wire signed [26:0] fft_real, fft_imag,
  input wire [9:0] fft_index, input wire fft_valid, fft_last,
  output reg [159:0] levels, output reg levels_valid,
  output reg [31:0] result_count);
    reg [27:0] peaks [0:15];
    wire signed [27:0] ext_real = {fft_real[26], fft_real};
    wire signed [27:0] ext_imag = {fft_imag[26], fft_imag};
    wire [27:0] abs_real = ext_real[27] ? -ext_real : ext_real;
    wire [27:0] abs_imag = ext_imag[27] ? -ext_imag : ext_imag;
    wire [27:0] magnitude = abs_real + abs_imag;
    integer i;
    reg [3:0] band;
    reg [27:0] scaled;
    reg [9:0] target, old_level;
    function [3:0] band_for_bin(input [9:0] k);
        begin
            if (k<2) band_for_bin=0; else if (k<3) band_for_bin=1;
            else if (k<4) band_for_bin=2; else if (k<6) band_for_bin=3;
            else if (k<8) band_for_bin=4; else if (k<11) band_for_bin=5;
            else if (k<15) band_for_bin=6; else if (k<21) band_for_bin=7;
            else if (k<30) band_for_bin=8; else if (k<43) band_for_bin=9;
            else if (k<61) band_for_bin=10; else if (k<87) band_for_bin=11;
            else if (k<124) band_for_bin=12; else if (k<177) band_for_bin=13;
            else if (k<252) band_for_bin=14; else band_for_bin=15;
        end
    endfunction
    always @(posedge clk) begin
        if (rst) begin
            for (i=0;i<16;i=i+1) peaks[i] <= 0;
            levels <= 0; levels_valid <= 0; result_count <= 0;
        end else begin
            levels_valid <= 0;
            if (fft_valid) begin
                if (fft_index == 0)
                    for (i=0;i<16;i=i+1) peaks[i] <= 0;
                else if (fft_index < 512) begin
                    band = band_for_bin(fft_index);
                    if (magnitude > peaks[band]) peaks[band] <= magnitude;
                end
                if (fft_last) begin
                    for (i=0;i<16;i=i+1) begin
                        scaled = peaks[i] >> DISPLAY_SHIFT;
                        target = scaled > 420 ? 10'd420 : scaled[9:0];
                        old_level = levels[i*10 +: 10];
                        if (target >= old_level) levels[i*10 +: 10] <= target;
                        else if (old_level > FALL_STEP && old_level-FALL_STEP > target)
                            levels[i*10 +: 10] <= old_level-FALL_STEP;
                        else levels[i*10 +: 10] <= target;
                    end
                    levels_valid <= 1;
                    result_count <= result_count + 1'b1;
                end
            end
        end
    end
endmodule
`default_nettype wire
