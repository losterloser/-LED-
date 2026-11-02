`timescale 1ns/1ps
`default_nettype none
// 50 MHz PL oscillator, independent of the ARM/PS and any FCLK setup.
// MCLK = 50 MHz * 18.125 / 73.75 = 12.288135593 MHz (about +11.04 ppm).
// This is a divider calculation, not a calibrated measurement of the oscillator.
module audio_clock_tree(input wire sys_clk, input wire reset,
    output wire core_clk, codec_clk, codec_locked);
    wire clock_in, feedback_raw, feedback, codec_raw;
    IBUF u_input(.I(sys_clk),.O(clock_in));
    BUFG u_core_buf(.I(clock_in),.O(core_clk));
    MMCME2_BASE #(.BANDWIDTH("OPTIMIZED"),.CLKIN1_PERIOD(20.000),
        .DIVCLK_DIVIDE(1),.CLKFBOUT_MULT_F(18.125),.CLKOUT0_DIVIDE_F(73.750),
        .STARTUP_WAIT("FALSE")) u_mmcm(
        .CLKIN1(clock_in),.CLKFBIN(feedback),.CLKFBOUT(feedback_raw),
        .CLKOUT0(codec_raw),.LOCKED(codec_locked),.RST(reset),.PWRDWN(1'b0));
    BUFG u_feedback_buf(.I(feedback_raw),.O(feedback));
    BUFG u_codec_buf(.I(codec_raw),.O(codec_clk));
endmodule
`default_nettype wire
