`timescale 1ns / 1ps
`default_nettype none
// Synchronize the asynchronous request, then register the reset synchronously.
// RAM addresses/enables must never be driven by an asynchronously reset FF.
module reset_sync(input wire clk, input wire arst, output reg rst = 1'b1);
    (* ASYNC_REG = "TRUE" *) reg [2:0] stages = 3'b111;
    always @(posedge clk or posedge arst)
        if (arst) stages <= 3'b111;
        else stages <= {stages[1:0], 1'b0};
    always @(posedge clk)
        rst <= stages[2];
endmodule
`default_nettype wire
