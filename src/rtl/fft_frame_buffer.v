`timescale 1ns / 1ps
`default_nettype none
// Two 1024-sample banks. A ready/reading bank is never overwritten.
module fft_frame_buffer(
    input wire clk, input wire rst,
    input wire signed [15:0] pcm_data, input wire pcm_valid,
    output wire [15:0] stream_data, output wire stream_valid,
    output wire stream_last, input wire stream_ready,
    output reg [31:0] drop_count, output reg [31:0] frame_count
);
    (* ram_style = "block" *) reg [15:0] memory [0:2047];
    reg write_bank, read_bank;
    reg [9:0] write_index, read_index;
    reg [1:0] bank_ready;
    reg [1:0] read_state;
    reg [15:0] ram_data, output_data;
    localparam IDLE=0, FETCH=1, LOAD=2, HOLD=3;
    wire read_busy = read_state != IDLE;
    wire can_write = !bank_ready[write_bank] &&
                     !(read_busy && read_bank == write_bank);
    always @(posedge clk) begin
        if (pcm_valid && !rst && can_write)
            memory[{write_bank, write_index}] <= pcm_data;
        if (read_state == FETCH)
            ram_data <= memory[{read_bank, read_index}];
    end
    always @(posedge clk) begin
        if (rst) begin
            write_bank <= 0; read_bank <= 0; write_index <= 0; read_index <= 0;
            bank_ready <= 0; read_state <= IDLE; output_data <= 0;
            drop_count <= 0; frame_count <= 0;
        end else begin
            if (pcm_valid) begin
                if (can_write) begin
                    if (write_index == 1023) begin
                        bank_ready[write_bank] <= 1;
                        write_index <= 0; write_bank <= ~write_bank;
                        frame_count <= frame_count + 1'b1;
                    end else write_index <= write_index + 1'b1;
                end else drop_count <= drop_count + 1'b1;
            end
            case (read_state)
                IDLE: begin
                    if (bank_ready[0] || bank_ready[1]) begin
                        read_bank <= bank_ready[0] ? 1'b0 : 1'b1;
                        if (bank_ready[0]) bank_ready[0] <= 0;
                        else bank_ready[1] <= 0;
                        read_index <= 0;
                        read_state <= FETCH;
                    end
                end
                FETCH: read_state <= LOAD;
                LOAD: begin output_data <= ram_data; read_state <= HOLD; end
                HOLD: if (stream_ready) begin
                    if (read_index == 1023) read_state <= IDLE;
                    else begin read_index <= read_index + 1'b1; read_state <= FETCH; end
                end
            endcase
        end
    end
    assign stream_data = output_data;
    assign stream_valid = read_state == HOLD;
    assign stream_last = read_index == 1023;
endmodule
`default_nettype wire
