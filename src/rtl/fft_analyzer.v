`timescale 1ns / 1ps
`default_nettype none
// Matches scripts/create_project.tcl: 1024, 16-bit, unscaled, natural order.
// Generated Vivado 2022.2 IP has 27 useful bits per output, padded to 32.
module fft_analyzer(
    input wire clk, input wire rst,
    input wire [15:0] stream_data, input wire stream_valid, stream_last,
    output wire stream_ready,
    output wire signed [26:0] fft_real, fft_imag,
    output wire fft_valid, fft_last, output reg [9:0] fft_index,
    output reg [31:0] protocol_error_count
);
    reg configured;
    wire config_ready, input_ready;
    wire [63:0] fft_data;
    wire event_missing, event_unexpected;
    wire unused_started, unused_status, unused_input, unused_output;
    always @(posedge clk) begin
        if (rst) begin configured <= 0; fft_index <= 0; protocol_error_count <= 0; end
        else begin
            if (config_ready && !configured) configured <= 1;
            if (fft_valid) begin
                if (fft_last) fft_index <= 0;
                else fft_index <= fft_index + 1'b1;
            end
            if (event_missing || event_unexpected)
                protocol_error_count <= protocol_error_count + 1'b1;
        end
    end
    assign stream_ready = configured && input_ready;
    assign fft_real = fft_data[26:0];
    assign fft_imag = fft_data[58:32];
    fft_1024 u_fft (
        .aclk(clk), .aresetn(~rst),
        .s_axis_config_tdata(8'h01), // FWD_INV=1; fixed length, no scaling field.
        .s_axis_config_tvalid(!configured && !rst),
        .s_axis_config_tready(config_ready),
        .s_axis_data_tdata({16'b0, stream_data}),
        .s_axis_data_tvalid(stream_valid && configured && !rst),
        .s_axis_data_tready(input_ready), .s_axis_data_tlast(stream_last),
        .m_axis_data_tdata(fft_data), .m_axis_data_tvalid(fft_valid),
        .m_axis_data_tready(1'b1), .m_axis_data_tlast(fft_last),
        .event_frame_started(unused_started),
        .event_tlast_unexpected(event_unexpected), .event_tlast_missing(event_missing),
        .event_status_channel_halt(unused_status),
        .event_data_in_channel_halt(unused_input),
        .event_data_out_channel_halt(unused_output)
    );
endmodule
`default_nettype wire
