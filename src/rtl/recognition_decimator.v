`timescale 1ns/1ps
`default_nettype none
// Recognition branch only. 48 kHz -> 12 kHz, 127-tap Kaiser FIR, Q16.
// A convolution takes 127 core cycles, versus >=1041 between real ADC samples.
// Warm-up is suppressed so uninitialized history is never sent to the host.
module recognition_decimator(input wire clk,rst,
    input wire signed [15:0] pcm_data,input wire pcm_valid,
    output reg signed [15:0] out_data,output reg out_valid);
    reg signed [15:0] history[0:127];
    reg signed [15:0] coefficients[0:127];
    reg [6:0] wr_ptr,anchor,tap;
    reg [7:0] warmup;
    reg [1:0] phase;
    reg busy;
    reg signed [39:0] accumulator;
    wire [6:0] address=anchor-tap;
    wire signed [31:0] product=history[address]*coefficients[tap];
    wire signed [39:0] sum=accumulator+{{8{product[31]}},product};
    wire signed [39:0] scaled=sum>>>16;
    initial $readmemh("recognition_fir.mem",coefficients);
    always @(posedge clk) begin
        out_valid<=0;
        if(rst) begin wr_ptr<=0;anchor<=0;tap<=0;warmup<=0;phase<=0;busy<=0;accumulator<=0;out_data<=0;end
        else begin
            if(pcm_valid) begin
                history[wr_ptr]<=pcm_data;wr_ptr<=wr_ptr+1'b1;phase<=phase+1'b1;
                if(warmup<128) warmup<=warmup+1'b1;
                if(phase==3 && warmup>=127 && !busy) begin
                    anchor<=wr_ptr;tap<=0;accumulator<=0;busy<=1;
                end
            end
            if(busy) begin
                accumulator<=sum;
                if(tap==126) begin
                    busy<=0;out_valid<=1;
                    out_data<=scaled>32767 ? 16'sh7fff : scaled< -32768 ? 16'sh8000 : scaled[15:0];
                end else tap<=tap+1'b1;
            end
        end
    end
endmodule
`default_nettype wire
