`timescale 1ns/1ps
`default_nettype none
// 50 MHz / 100 = 500 kbaud, 8N1. TX valid/ready accepts exactly one byte.
module recognition_uart_tx #(parameter DIVISOR=100)(
    input wire clk,rst,input wire [7:0] data,input wire valid,
    output wire ready,output reg tx);
    reg busy; reg [15:0] count; reg [3:0] bit_number; reg [9:0] word_q;
    assign ready=!busy;
    always @(posedge clk) begin
        if(rst) begin busy<=0;tx<=1;count<=0;bit_number<=0;word_q<=10'h3ff;end
        else if(!busy) begin
            tx<=1;
            if(valid) begin
                word_q<={1'b1,data,1'b0};tx<=0;busy<=1;count<=DIVISOR-1;bit_number<=0;
            end
        end else if(count!=0) count<=count-1'b1;
        else if(bit_number==9) begin busy<=0;tx<=1;end
        else begin bit_number<=bit_number+1'b1;tx<=word_q[bit_number+1'b1];count<=DIVISOR-1;end
    end
endmodule

module recognition_uart_rx #(parameter DIVISOR=100)(
    input wire clk,rst,rx,output reg [7:0] data,output reg valid,output reg framing_error);
    (* ASYNC_REG="TRUE" *) reg rx_meta=1,rx_sync=1;
    reg [1:0] state; reg [15:0] count; reg [2:0] bit_number; reg [7:0] word_q;
    always @(posedge clk) begin rx_meta<=rx;rx_sync<=rx_meta;end
    always @(posedge clk) begin
        valid<=0;framing_error<=0;
        if(rst) begin state<=0;count<=0;bit_number<=0;word_q<=0;data<=0;end
        else case(state)
            0:if(!rx_sync) begin state<=1;count<=DIVISOR/2-1;end
            1:if(count!=0) count<=count-1'b1;
              else if(rx_sync) state<=0;
              else begin state<=2;count<=DIVISOR-1;bit_number<=0;end
            2:if(count!=0) count<=count-1'b1;
              else begin
                  word_q[bit_number]<=rx_sync;count<=DIVISOR-1;
                  if(bit_number==7) state<=3;else bit_number<=bit_number+1'b1;
              end
            3:if(count!=0) count<=count-1'b1;
              else begin
                  state<=0;
                  if(rx_sync) begin data<=word_q;valid<=1;end else framing_error<=1;
              end
        endcase
    end
endmodule
`default_nettype wire
