`timescale 1ns/1ps
`default_nettype none
// Independent monitor of the existing PCM stream: never backpressures FFT/I2S.
// A5 5A, type=01, u16 payload size, u16 sequence, payload, CRC16/CCITT-FALSE.
// Payload: u8 mode,u16 epoch,u32 Fs,u32 first_index,u32 dropped,u16 LCD_ack,
//          128 little-endian signed PCM16 samples. All multibyte fields LE.
module music_pcm_uart #(parameter UART_DIVISOR=100,parameter SAMPLE_HZ=12000)(
    input wire clk,rst,clear,input wire [1:0] mode,
    input wire [15:0] pcm_data,input wire pcm_valid,input wire [15:0] display_ack,
    output wire tx,output reg [15:0] epoch,output reg [31:0] dropped_samples);
    reg [15:0] memory[0:511];
    reg [8:0] wr_ptr,rd_ptr;
    reg [9:0] count;
    reg [31:0] read_index,packet_index,packet_dropped;
    reg [15:0] sequence_q,packet_ack;
    reg [1:0] packet_mode;
    reg [15:0] packet_epoch,crc;
    reg [8:0] position;
    reg streaming,previous_clear;
    reg [7:0] tx_byte;
    wire tx_ready;
    wire overflow=pcm_valid && count==512 && !clear;
    wire flush=rst || clear || overflow;
    wire accepted=streaming && tx_ready;
    wire pop=accepted && position>=24 && position<280 && position[0];
    wire push=pcm_valid && !flush;
    function [15:0] crc_byte(input [15:0] c,input [7:0] b);
        integer i;reg [15:0] t;
        begin t=c^{b,8'b0};for(i=0;i<8;i=i+1)t=t[15] ? (t<<1)^16'h1021 : t<<1;crc_byte=t;end
    endfunction
    recognition_uart_tx #(.DIVISOR(UART_DIVISOR)) u_tx(
        .clk(clk),.rst(flush),.data(tx_byte),.valid(streaming),.ready(tx_ready),.tx(tx));
    always @* begin
        tx_byte=0;
        case(position)
            0:tx_byte=8'ha5;1:tx_byte=8'h5a;2:tx_byte=1;
            3:tx_byte=8'h11;4:tx_byte=1;
            5:tx_byte=sequence_q[7:0];6:tx_byte=sequence_q[15:8];
            7:tx_byte={6'b0,packet_mode};8:tx_byte=packet_epoch[7:0];9:tx_byte=packet_epoch[15:8];
            10:tx_byte=SAMPLE_HZ&255;11:tx_byte=(SAMPLE_HZ>>8)&255;
            12:tx_byte=(SAMPLE_HZ>>16)&255;13:tx_byte=(SAMPLE_HZ>>24)&255;
            14:tx_byte=packet_index[7:0];15:tx_byte=packet_index[15:8];
            16:tx_byte=packet_index[23:16];17:tx_byte=packet_index[31:24];
            18:tx_byte=packet_dropped[7:0];19:tx_byte=packet_dropped[15:8];
            20:tx_byte=packet_dropped[23:16];21:tx_byte=packet_dropped[31:24];
            22:tx_byte=packet_ack[7:0];23:tx_byte=packet_ack[15:8];
            280:tx_byte=crc[7:0];281:tx_byte=crc[15:8];
            default:tx_byte=position[0] ? memory[rd_ptr][15:8] : memory[rd_ptr][7:0];
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin epoch<=0;previous_clear<=1;dropped_samples<=0;end
        else begin
            previous_clear<=clear;
            if((clear && !previous_clear) || overflow) epoch<=epoch+1'b1;
            if(overflow) dropped_samples<=dropped_samples+{22'b0,count}+1'b1;
        end
        if(flush) begin
            wr_ptr<=0;rd_ptr<=0;count<=0;read_index<=0;packet_index<=0;
            sequence_q<=0;packet_ack<=16'hffff;packet_mode<=0;packet_epoch<=0;
            packet_dropped<=0;crc<=16'hffff;position<=0;streaming<=0;
        end else begin
            if(push) begin memory[wr_ptr]<=pcm_data;wr_ptr<=wr_ptr+1'b1;end
            if(pop) begin rd_ptr<=rd_ptr+1'b1;read_index<=read_index+1'b1;end
            case({push,pop})
                2'b10:count<=count+1'b1;
                2'b01:count<=count-1'b1;
                default:;
            endcase
            if(!streaming) begin
                if(count>=128) begin
                    streaming<=1;position<=0;crc<=16'hffff;packet_index<=read_index;
                    packet_mode<=mode;packet_epoch<=epoch;packet_dropped<=dropped_samples;packet_ack<=display_ack;
                end
            end else if(accepted) begin
                if(position>=2 && position<280) crc<=crc_byte(crc,tx_byte);
                if(position==281) begin streaming<=0;sequence_q<=sequence_q+1'b1;end
                else position<=position+1'b1;
            end
        end
    end
endmodule
`default_nettype wire
