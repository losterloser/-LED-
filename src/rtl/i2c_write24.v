`timescale 1ns / 1ps
`default_nettype none
// Open-drain write-only I2C engine: address byte + 16 control bits.
// Supports clock stretching, bus timeout and checks all three ACKs.
module i2c_write24 #(
    parameter QUARTER_CYCLES=250,
    parameter TIMEOUT_CYCLES=1000000
)(input wire clk, input wire rst, input wire start, input wire [23:0] packet,
  inout wire scl, inout wire sda,
  output reg busy, output reg done, output reg error);
    localparam IDLE=0, START_WAIT=1, START_HOLD=2,
        BIT_SETUP=3, BIT_RISE=4, BIT_HIGH=5,
        ACK_SETUP=6, ACK_RISE=7, ACK_HIGH=8,
        STOP_LOW=9, STOP_RISE=10, STOP_HIGH=11;
    reg [3:0] state;
    reg [23:0] saved;
    reg [4:0] bit_index;
    reg scl_low, sda_low;
    reg [15:0] divider;
    reg [31:0] wait_cycles;
    (* ASYNC_REG="TRUE" *) reg [1:0] scl_sync, sda_sync;
    wire tick = divider == QUARTER_CYCLES-1;
    wire waiting = busy && ((!scl_low && !scl_sync[1]) ||
                           (state==START_WAIT && !sda_sync[1]));
    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE; saved<=0; bit_index<=23; scl_low<=0; sda_low<=0;
            divider<=0; wait_cycles<=0; busy<=0; done<=0; error<=0;
            scl_sync<=2'b11; sda_sync<=2'b11;
        end else begin
            scl_sync<={scl_sync[0],scl}; sda_sync<={sda_sync[0],sda};
            done<=0;
            if(tick) divider<=0; else divider<=divider+1'b1;
            if(waiting) wait_cycles<=wait_cycles+1'b1; else wait_cycles<=0;
            if(waiting && wait_cycles>=TIMEOUT_CYCLES-1) begin
                scl_low<=0; sda_low<=0; state<=IDLE;
                busy<=0; done<=1; error<=1; wait_cycles<=0;
            end else if(state==IDLE) begin
                if(start) begin
                    saved<=packet; bit_index<=23; busy<=1; error<=0;
                    scl_low<=0; sda_low<=0; divider<=0; state<=START_WAIT;
                end
            end else if(tick) begin
                case(state)
                    START_WAIT: if(scl_sync[1] && sda_sync[1]) begin
                        sda_low<=1; state<=START_HOLD;
                    end
                    START_HOLD: begin scl_low<=1; state<=BIT_SETUP; end
                    BIT_SETUP: begin sda_low<=!saved[bit_index]; state<=BIT_RISE; end
                    BIT_RISE: begin scl_low<=0; state<=BIT_HIGH; end
                    BIT_HIGH: if(scl_sync[1]) begin
                        scl_low<=1;
                        if(bit_index[2:0]==0) state<=ACK_SETUP;
                        else begin bit_index<=bit_index-1'b1; state<=BIT_SETUP; end
                    end
                    ACK_SETUP: begin sda_low<=0; state<=ACK_RISE; end
                    ACK_RISE: begin scl_low<=0; state<=ACK_HIGH; end
                    ACK_HIGH: if(scl_sync[1]) begin
                        if(sda_sync[1]) error<=1;
                        scl_low<=1;
                        if(bit_index==0 || sda_sync[1]) state<=STOP_LOW;
                        else begin bit_index<=bit_index-1'b1; state<=BIT_SETUP; end
                    end
                    STOP_LOW: begin sda_low<=1; state<=STOP_RISE; end
                    STOP_RISE: begin scl_low<=0; state<=STOP_HIGH; end
                    STOP_HIGH: if(scl_sync[1]) begin
                        sda_low<=0; busy<=0; done<=1; state<=IDLE;
                    end
                    default: state<=IDLE;
                endcase
            end
        end
    end
endmodule
`default_nettype wire
