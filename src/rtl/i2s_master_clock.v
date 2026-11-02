`timescale 1ns/1ps
`default_nettype none
// 256 MCLK ticks per stereo frame, 64 BCLK ticks, 32-bit channel slots.
// LRCK changes on the falling BCLK edge, one BCLK before the I2S MSB.
module i2s_master_clock(input wire codec_clk, input wire rst,
    output wire mclk, bclk, lrck);
    reg [7:0] phase;
    always @(posedge codec_clk) if(rst) phase<=0; else phase<=phase+1'b1;
    assign bclk=phase[1];
    assign lrck=phase[7];
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("SYNC")) u_mclk_forward(
        .Q(mclk),.C(codec_clk),.CE(1'b1),.D1(1'b1),.D2(1'b0),.R(1'b0),.S(1'b0));
endmodule
`default_nettype wire
