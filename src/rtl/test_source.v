`timescale 1ns / 1ps
`default_nettype none
// 48 kHz average sample enable from a 100 MHz clock. No derived logic clock.
module test_source #(
    parameter CLOCK_HZ = 100000000,
    parameter SAMPLE_HZ = 48000
)(input wire clk, input wire rst,
  output reg signed [15:0] pcm_data, output reg pcm_valid);
    reg [26:0] phase;
    reg [9:0] address;
    // Keep this small diagnostic ROM in LUTs. Vivado can fold a synchronous
    // address reset into a BRAM enable, reintroducing an asynchronous control
    // from the reset synchronizer during opt_design (REQP-1840).
    (* rom_style = "distributed" *) reg [15:0] rom [0:1023];
    reg [15:0] rom_data;
    initial $readmemh("test_tone.mem", rom);
    // Read continuously into a plain register; the ROM has no control/reset pin.
    // Address stays unchanged between 48 kHz strobes, so data is ready in time.
    always @(posedge clk)
        rom_data <= rom[address];
    always @(posedge clk) begin
        if (rst) begin
            phase <= 0; address <= 0; pcm_data <= 0; pcm_valid <= 0;
        end else begin
            pcm_valid <= 0;
            if (phase >= CLOCK_HZ - SAMPLE_HZ) begin
                phase <= phase + SAMPLE_HZ - CLOCK_HZ;
                pcm_data <= rom_data;
                address <= address + 1'b1;
                pcm_valid <= 1;
            end else phase <= phase + SAMPLE_HZ;
        end
    end
endmodule
`default_nettype wire
