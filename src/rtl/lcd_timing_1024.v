`timescale 1ns/1ps
`default_nettype none
// ATK 0x7016 profile, DE mode: 1344 x 635 total, 1024 x 600 active.
// At the board's 50 MHz clock this is 58.585 Hz, matching the 7010 example.
module lcd_timing_1024(input wire clk,rst,
    output wire active,frame_start,
    output wire [9:0] x,y,
    output reg [10:0] h_count,v_count);
    localparam H_TOTAL=1344,V_TOTAL=635,H_START=160,V_START=23;
    always @(posedge clk) begin
        if(rst) begin h_count<=0;v_count<=0;end
        else if(h_count==H_TOTAL-1) begin
            h_count<=0;
            if(v_count==V_TOTAL-1) v_count<=0;else v_count<=v_count+1'b1;
        end else h_count<=h_count+1'b1;
    end
    assign active=h_count>=H_START && h_count<H_START+1024 && v_count>=V_START && v_count<V_START+600;
    assign x=active ? h_count-H_START : 0;
    assign y=active ? v_count-V_START : 0;
    assign frame_start=h_count==0 && v_count==0;
endmodule
`default_nettype wire
