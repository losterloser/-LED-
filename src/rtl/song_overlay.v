`timescale 1ns/1ps
`default_nettype none
// Host renders Chinese/Unicode into 960x64 monochrome bitmap, MSB first.
// Type20 payload: u8 mode,u16 epoch,7680 row-major bytes. CRC guards COMMIT.
// Only an entire valid packet can become visible, at LCD frame boundary.
module song_overlay #(parameter TIMEOUT_CYCLES=500000,parameter TTL_CYCLES=250000000)(
    input wire clk,rst,clear,input wire [1:0] mode,input wire [15:0] epoch,
    input wire [7:0] rx_byte,input wire rx_valid,rx_error,
    input wire frame_start,input wire [9:0] x,y,
    output reg pixel_area,output wire pixel_on,output reg [15:0] display_ack,
    output reg [31:0] good_packets,bad_packets);
    (* ram_style="block" *) reg [7:0] bank0[0:8191];
    (* ram_style="block" *) reg [7:0] bank1[0:8191];
    reg active_bank,enabled,pending,receiving_allowed;
    reg [3:0] state;
    reg [15:0] length_q,sequence_q,crc,rx_crc,payload_index;
    reg [7:0] packet_mode;
    reg [15:0] packet_epoch,pending_seq;
    reg [31:0] idle_count,ttl;
    reg [7:0] read0_q,read1_q;
    reg read_bank_q;
    wire [7:0] read_byte=read_bank_q ? read1_q : read0_q;
    reg [2:0] read_bit;
    wire in_overlay=x>=32 && x<992 && y>=128 && y<192;
    wire [9:0] local_x=x-10'd32;
    wire [5:0] local_y=y-10'd128;
    wire [12:0] read_address=in_overlay ? {local_y,7'b0}-{local_y,3'b0}+{6'b0,local_x[9:3]} : 13'b0;
    wire [12:0] write_address=payload_index[12:0]-13'd3;
    assign pixel_on=read_byte[read_bit];
    function [15:0] crc_byte(input [15:0] c,input [7:0] b);
        integer i;reg [15:0] t;
        begin t=c^{b,8'b0};for(i=0;i<8;i=i+1)t=t[15] ? (t<<1)^16'h1021 : t<<1;crc_byte=t;end
    endfunction
    always @(posedge clk) begin
        // Each RAM needs its own synchronous output register for BRAM inference.
        // Select the registered outputs, rather than muxing asynchronous reads.
        read0_q<=bank0[read_address];read1_q<=bank1[read_address];read_bank_q<=active_bank;
        read_bit<=3'd7-local_x[2:0];pixel_area<=enabled && in_overlay && !clear && !rst;
        if(rx_valid && state==7 && payload_index>=3 && receiving_allowed && !rst && !clear) begin
            if(active_bank) bank0[write_address]<=rx_byte;
            else bank1[write_address]<=rx_byte;
        end
        if(rst) begin
            active_bank<=0;enabled<=0;pending<=0;receiving_allowed<=0;
            state<=0;length_q<=0;sequence_q<=0;crc<=16'hffff;rx_crc<=0;payload_index<=0;
            packet_mode<=0;packet_epoch<=0;pending_seq<=0;display_ack<=16'hffff;
            idle_count<=0;ttl<=0;good_packets<=0;bad_packets<=0;pixel_area<=0;
        end else if(clear) begin
            state<=0;pending<=0;enabled<=0;display_ack<=16'hffff;idle_count<=0;ttl<=0;
        end else begin
            if(enabled) begin
                if(ttl>=TTL_CYCLES-1) enabled<=0;else ttl<=ttl+1'b1;
            end
            if(frame_start && pending) begin
                active_bank<=!active_bank;enabled<=1;pending<=0;display_ack<=pending_seq;ttl<=0;
            end
            if(state!=0) begin
                if(idle_count>=TIMEOUT_CYCLES-1 || rx_error) begin state<=0;bad_packets<=bad_packets+1'b1;end
                else idle_count<=idle_count+1'b1;
            end
            if(rx_valid && !rx_error) begin
                idle_count<=0;
                case(state)
                    0:if(rx_byte==8'ha5) state<=1;
                    1:if(rx_byte==8'h5a) begin state<=2;crc<=16'hffff;receiving_allowed<=!pending;end
                      else if(rx_byte!=8'ha5) state<=0;
                    2:begin
                        if(rx_byte!=8'h20) begin state<=0;bad_packets<=bad_packets+1'b1;end
                        else begin crc<=crc_byte(crc,rx_byte);state<=3;end
                    end
                    3:begin length_q[7:0]<=rx_byte;crc<=crc_byte(crc,rx_byte);state<=4;end
                    4:begin
                        length_q[15:8]<=rx_byte;crc<=crc_byte(crc,rx_byte);
                        if({rx_byte,length_q[7:0]}!=7683) begin state<=0;bad_packets<=bad_packets+1'b1;end
                        else state<=5;
                    end
                    5:begin sequence_q[7:0]<=rx_byte;crc<=crc_byte(crc,rx_byte);state<=6;end
                    6:begin sequence_q[15:8]<=rx_byte;crc<=crc_byte(crc,rx_byte);state<=7;payload_index<=0;end
                    7:begin
                        crc<=crc_byte(crc,rx_byte);
                        case(payload_index)
                            0:packet_mode<=rx_byte;
                            1:packet_epoch[7:0]<=rx_byte;
                            2:packet_epoch[15:8]<=rx_byte;
                            default:;
                        endcase
                        if(payload_index==7682) state<=8;else payload_index<=payload_index+1'b1;
                    end
                    8:begin rx_crc[7:0]<=rx_byte;state<=9;end
                    9:begin
                        state<=0;
                        if({rx_byte,rx_crc[7:0]}==crc && receiving_allowed &&
                           packet_mode=={6'b0,mode} && packet_epoch==epoch) begin
                            pending<=1;pending_seq<=sequence_q;good_packets<=good_packets+1'b1;
                        end else bad_packets<=bad_packets+1'b1;
                    end
                    default:state<=0;
                endcase
            end
        end
    end
endmodule
`default_nettype wire
