`timescale 1ns/1ps
`default_nettype none
// Same 50MHz domain as the FFT: whole-frame snapshots, no CDC of the wide bus.
// RGB/DE are registered on rising core edges; the official 0x7016/EK79001
// profile samples the falling LCD_CLK edge, half a core cycle later.
module lcd_visualizer #(
    parameter RESET_HOLD_CYCLES=10000000, // 200ms active-low reset
    parameter ENABLE_SONG_OVERLAY=0,
    parameter SETTLE_CYCLES=6000000      // 120ms after reset release
)(input wire clk,rst,input wire [159:0] levels,input wire levels_valid,clear,
  input wire [1:0] mode,input wire self_test,ready,error,
  output wire [23:0] lcd_rgb,output reg lcd_de,output wire lcd_hs,lcd_vs,lcd_clk,
  output reg lcd_bl,output reg lcd_rst_n,
  output reg [159:0] frame_levels,output reg [1:0] frame_mode,
  output reg frame_self_test,frame_ready,frame_error,
  output wire frame_start,output reg [31:0] frame_count,
  input wire song_pixel_area,song_pixel_on,output wire [9:0] song_x,song_y);
    localparam START_CYCLES=RESET_HOLD_CYCLES+SETTLE_CYCLES;
    reg [31:0] startup;
    wire panel_run=startup==START_CYCLES;
    assign lcd_hs=1'b1;assign lcd_vs=1'b1; // Manufacturer DE mode.
    wire active,frame_tick;
    wire [9:0] x,y;
    wire [10:0] h_count,v_count;
    wire [23:0] pixel;
    assign song_x=x;assign song_y=y;
    reg [23:0] pixel_delay;
    reg active_delay,self_test_delay;
    reg [159:0] latest;
    (* IOB="TRUE" *) reg [23:0] color_q;
    reg [1:0] warmup_frames;
    lcd_timing_1024 u_scan(.clk(clk),.rst(rst || !panel_run),.active(active),
        .frame_start(frame_tick),.x(x),.y(y),.h_count(h_count),.v_count(v_count));
    spectrum_renderer u_render(.x(x),.y(y),.levels(frame_levels),.mode(frame_mode),
        .self_test(frame_self_test),.ready(frame_ready),.error(frame_error),.pixel(pixel));
    assign frame_start=panel_run && frame_tick;
    // Match the official RGB-LCD example: release ID/data lines in blanking.
    assign lcd_rgb=lcd_de ? color_q : 24'bz;
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("SYNC")) u_pixel_forward(
        .Q(lcd_clk),.C(clk),.CE(1'b1),.D1(1'b1),.D2(1'b0),.R(rst || !panel_run),.S(1'b0));
    always @(posedge clk) begin
        if(rst) begin
            startup<=0;latest<=0;frame_levels<=0;frame_mode<=0;
            frame_self_test<=0;frame_ready<=0;frame_error<=0;
            pixel_delay<=0;active_delay<=0;self_test_delay<=0;
            color_q<=0;lcd_de<=0;lcd_bl<=0;lcd_rst_n<=0;warmup_frames<=0;frame_count<=0;
        end else begin
            if(!panel_run) startup<=startup+1'b1;
            if(startup>=RESET_HOLD_CYCLES-1) lcd_rst_n<=1;
            if(clear) latest<=0;else if(levels_valid) latest<=levels;
            pixel_delay<=pixel;active_delay<=panel_run && active;self_test_delay<=frame_self_test;
            if(ENABLE_SONG_OVERLAY) begin
                lcd_de<=active_delay;
                color_q<=(song_pixel_area && !self_test_delay) ?
                    (song_pixel_on ? 24'he7f4ff : 24'h070e1b) : pixel_delay;
            end else begin lcd_de<=panel_run && active;color_q<=pixel;end
            if(frame_start) begin
                frame_levels<=clear ? 160'b0 : (levels_valid ? levels : latest);
                frame_mode<=mode;frame_self_test<=self_test;
                frame_ready<=ready;frame_error<=error;frame_count<=frame_count+1'b1;
                if(warmup_frames!=3) warmup_frames<=warmup_frames+1'b1;
                if(warmup_frames>=2) lcd_bl<=1;
            end
        end
    end
`ifndef SYNTHESIS
    initial if(RESET_HOLD_CYCLES<1 || SETTLE_CYCLES<1) $fatal(1,"Invalid LCD power-up delays");
`endif
endmodule
`default_nettype wire
