`timescale 1ns/1ps
`default_nettype none
// One-wire GRB, MSB first. LED0 occupies the most significant 24 bits.
// All timing parameters are CLOCK CYCLES of clk, not nanoseconds.
module ws2812_tx #(
    parameter NUM_LEDS=16,
    parameter BIT_CYCLES=125,
    parameter T0H_CYCLES=35,
    parameter T1H_CYCLES=65,
    parameter RESET_CYCLES=40000
)(input wire clk, input wire rst,
  input wire [NUM_LEDS*24-1:0] colors, input wire start,
  output reg data_out, output wire busy, output reg done);
    localparam TOTAL_BITS=NUM_LEDS*24;
    localparam INDEX_W=$clog2(TOTAL_BITS)>0 ? $clog2(TOTAL_BITS) : 1;
    localparam MAX_CYCLES=RESET_CYCLES>BIT_CYCLES ? RESET_CYCLES : BIT_CYCLES;
    localparam COUNT_W=$clog2(MAX_CYCLES)>0 ? $clog2(MAX_CYCLES) : 1;
    localparam IDLE=0, SEND=1, LATCH=2;
    reg [1:0] state;
    reg [TOTAL_BITS-1:0] shift;
    reg [INDEX_W-1:0] bit_index;
    reg [COUNT_W-1:0] cycles;
    reg frame_active;
    wire [COUNT_W-1:0] high_cycles=shift[TOTAL_BITS-1] ? T1H_CYCLES : T0H_CYCLES;
    assign busy=state!=IDLE;
    always @(posedge clk) begin
        if(rst) begin
            state<=LATCH; cycles<=0; shift<=0; bit_index<=0;
            data_out<=0; done<=0; frame_active<=0;
        end else begin
            done<=0;
            case(state)
                IDLE: begin
                    data_out<=0;
                    if(start) begin
                        shift<=colors; bit_index<=0; cycles<=0;
                        data_out<=1; frame_active<=1; state<=SEND;
                    end
                end
                SEND: begin
                    if(cycles==high_cycles-1) data_out<=0;
                    if(cycles==BIT_CYCLES-1) begin
                        cycles<=0;
                        if(bit_index==TOTAL_BITS-1) begin
                            state<=LATCH; data_out<=0;
                        end else begin
                            shift<={shift[TOTAL_BITS-2:0],1'b0};
                            bit_index<=bit_index+1'b1;
                            data_out<=1;
                        end
                    end else cycles<=cycles+1'b1;
                end
                LATCH: begin
                    data_out<=0;
                    if(cycles==RESET_CYCLES-1) begin
                        cycles<=0; state<=IDLE;
                        done<=frame_active; frame_active<=0;
                    end else cycles<=cycles+1'b1;
                end
                default: begin
                    state<=LATCH; cycles<=0; data_out<=0; frame_active<=0;
                end
            endcase
        end
    end
`ifndef SYNTHESIS
    initial begin
        if(NUM_LEDS<1 || T0H_CYCLES<1 || T1H_CYCLES<=T0H_CYCLES ||
           T1H_CYCLES>=BIT_CYCLES || RESET_CYCLES<1)
            $fatal(1,"Invalid WS2812 timing/length parameters");
    end
`endif
endmodule
`default_nettype wire
