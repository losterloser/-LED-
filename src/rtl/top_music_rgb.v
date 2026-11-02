`timescale 1ns/1ps
`default_nettype none
module top_music_rgb #(
    parameter STARTUP_CYCLES=32768,
    parameter KEY_STABLE_CYCLES=250000,
    parameter CODEC_POWERUP_CYCLES=5000000,
    parameter CODEC_REFERENCE_CYCLES=5000000,
    parameter I2C_STEP_CYCLES=167,
    parameter TEST_SAMPLE_HZ=48000,
    parameter RGB_REFRESH_HZ=50,
    parameter AUDIO_TIMEOUT_CYCLES=10000000,
    parameter LCD_RESET_HOLD_CYCLES=10000000,
    parameter LCD_SETTLE_CYCLES=6000000
)(input wire sys_clk, sys_rst_n, input wire [1:0] key_n,
  inout wire aud_scl, aud_sda, input wire aud_adcdat,
  output wire aud_mclk, aud_bclk, aud_lrc, aud_dacdat,
  output wire rgb_data, output wire [1:0] led,
  output wire [23:0] lcd_rgb,
  output wire lcd_de,lcd_hs,lcd_vs,lcd_bl,lcd_clk,lcd_rst_n,touch_rst_n,
  input wire recognition_rx,output wire recognition_tx);
    localparam CORE_HZ=50000000;
    wire core_clk, codec_clk, codec_locked, core_rst, codec_rst;
    audio_clock_tree u_clock(.sys_clk(sys_clk),.reset(!sys_rst_n),
        .core_clk(core_clk),.codec_clk(codec_clk),.codec_locked(codec_locked));
    (* ASYNC_REG="TRUE" *) reg [1:0] lock_sync=0;
    reg [31:0] startup=0;
    always @(posedge core_clk) begin
        lock_sync<={lock_sync[0],codec_locked};
        if(startup<STARTUP_CYCLES) startup<=startup+1'b1;
    end
    reset_sync u_core_reset(.clk(core_clk),
        .arst(!sys_rst_n || !lock_sync[1] || startup<STARTUP_CYCLES),.rst(core_rst));
    reset_sync u_codec_reset(.clk(codec_clk),.arst(!sys_rst_n || !codec_locked),.rst(codec_rst));
    i2s_master_clock u_audio_clocks(.codec_clk(codec_clk),.rst(codec_rst),
        .mclk(aud_mclk),.bclk(aud_bclk),.lrck(aud_lrc));
    wire [1:0] mode;
    wire self_test;
    board_controls #(.STABLE_CYCLES(KEY_STABLE_CYCLES)) u_controls(
        .clk(core_clk),.rst(core_rst),.key_n(key_n),.mode(mode),.self_test(self_test));
    reg [1:0] previous_mode;
    reg [4:0] flush_count;
    always @(posedge core_clk) begin
        if(core_rst) begin previous_mode<=0; flush_count<=16; end
        else begin
            previous_mode<=mode;
            if(mode!=previous_mode) flush_count<=16;
            else if(flush_count!=0) flush_count<=flush_count-1'b1;
        end
    end
    wire analysis_rst=core_rst || flush_count!=0;
    wire init_rst=core_rst || ((mode==2)!=(previous_mode==2));
    wire init_done, init_error;
    wire [4:0] init_index;
    es8388_init #(.POWERUP_CYCLES(CODEC_POWERUP_CYCLES),
        .REFERENCE_CYCLES(CODEC_REFERENCE_CYCLES),.I2C_STEP_CYCLES(I2C_STEP_CYCLES)) u_init(
        .clk(core_clk),.rst(init_rst),.use_mic(mode!=2),.scl(aud_scl),.sda(aud_sda),
        .init_done(init_done),.init_error(init_error),.register_index(init_index));
    wire signed [15:0] left_data, right_data, test_data;
    wire pair_valid, test_valid;
    wire [31:0] format_errors;
    i2s_rx_stereo u_rx(.clk(core_clk),.rst(init_rst),.enable(init_done),
        .bclk_in(aud_bclk),.lrck_in(aud_lrc),.data_in(aud_adcdat),
        .left_data(left_data),.right_data(right_data),.pair_valid(pair_valid),.format_error_count(format_errors));
    test_source #(.CLOCK_HZ(CORE_HZ),.SAMPLE_HZ(TEST_SAMPLE_HZ)) u_test(
        .clk(core_clk),.rst(analysis_rst),.pcm_data(test_data),.pcm_valid(test_valid));
    wire [15:0] pcm_data=mode==0 ? test_data : left_data;
    wire pcm_valid=mode==0 ? test_valid : pair_valid && init_done;
    assign aud_dacdat=1'b0;
    wire [15:0] stream_data;
    wire stream_valid, stream_last, stream_ready;
    wire [31:0] drop_count, frame_count, protocol_errors, result_count;
    wire signed [26:0] fft_real, fft_imag;
    wire [9:0] fft_index;
    wire fft_valid, fft_last, levels_valid;
    wire [159:0] levels;
    fft_frame_buffer u_frames(.clk(core_clk),.rst(analysis_rst),.pcm_data(pcm_data),.pcm_valid(pcm_valid),
        .stream_data(stream_data),.stream_valid(stream_valid),.stream_last(stream_last),
        .stream_ready(stream_ready),.drop_count(drop_count),.frame_count(frame_count));
    fft_analyzer u_analyzer(.clk(core_clk),.rst(analysis_rst),.stream_data(stream_data),
        .stream_valid(stream_valid),.stream_last(stream_last),.stream_ready(stream_ready),
        .fft_real(fft_real),.fft_imag(fft_imag),.fft_valid(fft_valid),.fft_last(fft_last),
        .fft_index(fft_index),.protocol_error_count(protocol_errors));
    spectrum_bands u_bands(.clk(core_clk),.rst(analysis_rst),.fft_real(fft_real),.fft_imag(fft_imag),
        .fft_index(fft_index),.fft_valid(fft_valid),.fft_last(fft_last),.levels(levels),
        .levels_valid(levels_valid),.result_count(result_count));
    reg [31:0] audio_hold;
    always @(posedge core_clk)
        if(init_rst || !init_done) audio_hold<=0;
        else if(pair_valid) audio_hold<=AUDIO_TIMEOUT_CYCLES;
        else if(audio_hold!=0) audio_hold<=audio_hold-1'b1;
    wire audio_alive=audio_hold!=0;
    wire clear_spectrum=analysis_rst || (mode!=0 && !audio_alive);
    wire rgb_busy, rgb_frame_done;
    rgb_music_ring #(.CLOCK_HZ(CORE_HZ),.REFRESH_HZ(RGB_REFRESH_HZ)) u_rgb(
        .clk(core_clk),.rst(core_rst),.levels(levels),.levels_valid(levels_valid),
        .clear(clear_spectrum),.self_test(self_test),.data_out(rgb_data),
        .busy(rgb_busy),.frame_done(rgb_frame_done));
    reg [25:0] heartbeat;
    always @(posedge core_clk) if(core_rst) heartbeat<=0; else heartbeat<=heartbeat+1'b1;
    wire stream_error=drop_count!=0 || protocol_errors!=0 || format_errors!=0;
    wire error_active=stream_error || (mode!=0 && init_error);
    wire ready=mode==0 ? result_count!=0 : init_done && audio_alive;
    // Raw PCM branch is independent of the visualizer and never stalls it.
    wire recognition_clear=analysis_rst || mode!=previous_mode || (mode!=0 && !init_done);
    wire [15:0] recognition_epoch,recognition_display_ack;
    wire [31:0] recognition_dropped,recognition_good,recognition_bad;
    wire [7:0] recognition_byte;
    wire recognition_byte_valid,recognition_framing_error;
    wire song_pixel_area,song_pixel_on;
    wire [9:0] song_x,song_y;
    wire [15:0] recognition_pcm;
    wire recognition_pcm_valid;
    recognition_decimator u_recognition_filter(.clk(core_clk),.rst(core_rst || recognition_clear),
        .pcm_data(pcm_data),.pcm_valid(pcm_valid),.out_data(recognition_pcm),.out_valid(recognition_pcm_valid));
    music_pcm_uart u_recognition_stream(.clk(core_clk),.rst(core_rst),.clear(recognition_clear),
        .mode(mode),.pcm_data(recognition_pcm),.pcm_valid(recognition_pcm_valid),.display_ack(recognition_display_ack),
        .tx(recognition_tx),.epoch(recognition_epoch),.dropped_samples(recognition_dropped));
    recognition_uart_rx u_recognition_rx(.clk(core_clk),.rst(core_rst),.rx(recognition_rx),
        .data(recognition_byte),.valid(recognition_byte_valid),.framing_error(recognition_framing_error));
    song_overlay u_song(.clk(core_clk),.rst(core_rst),.clear(recognition_clear),.mode(mode),
        .epoch(recognition_epoch),.rx_byte(recognition_byte),.rx_valid(recognition_byte_valid),
        .rx_error(recognition_framing_error),.frame_start(lcd_frame_start),.x(song_x),.y(song_y),
        .pixel_area(song_pixel_area),.pixel_on(song_pixel_on),.display_ack(recognition_display_ack),
        .good_packets(recognition_good),.bad_packets(recognition_bad));
    assign touch_rst_n=1'b0; // Touch controller held reset; controls use PL keys.
    wire [159:0] lcd_frame_levels;
    wire [1:0] lcd_frame_mode;
    wire lcd_frame_self_test,lcd_frame_ready,lcd_frame_error,lcd_frame_start;
    wire [31:0] lcd_frame_count;
    lcd_visualizer #(.RESET_HOLD_CYCLES(LCD_RESET_HOLD_CYCLES),.SETTLE_CYCLES(LCD_SETTLE_CYCLES),.ENABLE_SONG_OVERLAY(1)) u_lcd(
        .clk(core_clk),.rst(core_rst),.levels(levels),.levels_valid(levels_valid),.clear(clear_spectrum),
        .mode(mode),.self_test(self_test),.ready(ready),.error(error_active),
        .lcd_rgb(lcd_rgb),.lcd_de(lcd_de),.lcd_hs(lcd_hs),.lcd_vs(lcd_vs),.lcd_clk(lcd_clk),
        .lcd_bl(lcd_bl),.lcd_rst_n(lcd_rst_n),.frame_levels(lcd_frame_levels),
        .frame_mode(lcd_frame_mode),.frame_self_test(lcd_frame_self_test),.frame_ready(lcd_frame_ready),
        .frame_error(lcd_frame_error),.frame_start(lcd_frame_start),.frame_count(lcd_frame_count),
        .song_pixel_area(song_pixel_area),.song_pixel_on(song_pixel_on),.song_x(song_x),.song_y(song_y));
    assign led[0]=heartbeat[25];
    assign led[1]=error_active ? heartbeat[22] : (self_test || ready);
`ifdef HARDWARE_DEBUG
`ifndef SIMULATION
    reg [31:0] timestamp;
    reg rgb_previous;
    reg [7:0] status_probe;
    reg [15:0] state_probe;
    always @(posedge core_clk) begin
        if(core_rst) begin timestamp<=0; rgb_previous<=0; status_probe<=0; state_probe<=0; end
        else begin
            timestamp<=timestamp+1'b1; rgb_previous<=rgb_data;
            status_probe<={result_count[4],stream_error,audio_alive,init_error,init_done,mode!=0,lock_sync[1],heartbeat[25]};
            state_probe<={init_index,mode,self_test,lock_sync[1],analysis_rst,init_done,init_error,
                          pair_valid,stream_last,stream_ready,stream_valid};
        end
    end
    wire rgb_edge=rgb_data ^ rgb_previous;
    wire rgb_capture_valid=rgb_edge || rgb_frame_done;
    ila_music u_ila(.clk(core_clk),.probe0({fft_imag,fft_real,fft_index}),.probe1(fft_valid),
        .probe2(levels),.probe3({protocol_errors,drop_count,frame_count,result_count}),
        .probe4(status_probe),.probe5(state_probe),.probe6(timestamp),
        .probe7({rgb_frame_done,rgb_busy,rgb_edge,rgb_data}),.probe8({right_data,left_data}),
        .probe9(format_errors),.probe10(rgb_capture_valid),.probe11(pair_valid),
        .probe12(lcd_frame_count),
        .probe13({lcd_frame_error,lcd_frame_ready,lcd_frame_self_test,lcd_frame_mode,lcd_de,lcd_bl,lcd_rst_n}));
`endif
`endif
endmodule
`default_nettype wire
