`timescale 1ns/1ps
`default_nettype none
// Oversampled 16-bit I2S receiver. Validate both full 32-bit slots before
// publishing a pair, skipping the one-bit I2S delay and all padding bits.
module i2s_rx_stereo(input wire clk, rst, enable,
    input wire bclk_in, lrck_in, data_in,
    output reg signed [15:0] left_data, right_data,
    output reg pair_valid, output reg [31:0] format_error_count);
    (* ASYNC_REG="TRUE" *) reg [2:0] sig_meta, sig_sync;
    reg bclk_previous, started, channel, have_boundary;
    reg [5:0] slot_bit;
    reg [15:0] shift, left_word, right_word;
    reg word_seen, left_valid;
    wire bclk_rise=sig_sync[1] && !bclk_previous;
    wire [15:0] next_word={shift[14:0],sig_sync[0]};
    always @(posedge clk) begin
        if(rst || !enable) begin
            sig_meta<=0; sig_sync<=0; bclk_previous<=0;
            started<=0; channel<=0; have_boundary<=0; slot_bit<=0;
            shift<=0; left_word<=0; right_word<=0; word_seen<=0; left_valid<=0;
            left_data<=0; right_data<=0; pair_valid<=0; format_error_count<=0;
        end else begin
            sig_meta<={lrck_in,bclk_in,data_in}; sig_sync<=sig_meta;
            bclk_previous<=sig_sync[1]; pair_valid<=0;
            if(bclk_rise) begin
                if(!started) begin
                    started<=1; channel<=sig_sync[2]; slot_bit<=0;
                end else if(sig_sync[2]!=channel) begin
                    if(have_boundary && (slot_bit!=31 || !word_seen))
                        format_error_count<=format_error_count+1'b1;
                    if(!channel) left_valid<=have_boundary && slot_bit==31 && word_seen;
                    else begin
                        if(have_boundary && slot_bit==31 && word_seen && left_valid) begin
                            left_data<=left_word; right_data<=right_word; pair_valid<=1;
                        end
                        left_valid<=0;
                    end
                    channel<=sig_sync[2]; slot_bit<=0; have_boundary<=1;
                    shift<=0; word_seen<=0;
                end else begin
                    if(slot_bit!=63) slot_bit<=slot_bit+1'b1;
                    if(have_boundary && slot_bit<16) begin
                        shift<=next_word;
                        if(slot_bit==15) begin
                            if(channel) right_word<=next_word; else left_word<=next_word;
                            word_seen<=1;
                        end
                    end
                end
            end
        end
    end
endmodule
`default_nettype wire
