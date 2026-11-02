`timescale 1ns/1ps
`default_nettype none
module rgb_music_ring #(
    parameter CLOCK_HZ=100000000,
    parameter REFRESH_HZ=50,
    parameter CHASE_HZ=8,
    parameter MAX_BRIGHTNESS=32,
    parameter LEVEL_SHIFT=3
)(input wire clk, input wire rst,
  input wire [159:0] levels, input wire levels_valid,
  input wire clear, input wire self_test,
  output wire data_out, output wire busy, output wire frame_done);
    localparam REFRESH_CYCLES=CLOCK_HZ/REFRESH_HZ;
    localparam CHASE_CYCLES=CLOCK_HZ/CHASE_HZ;
    reg [159:0] latest_levels;
    (* ASYNC_REG="TRUE" *) reg [1:0] selftest_sync;
    reg [31:0] refresh_count, chase_count;
    reg [3:0] chase_index;
    reg pending, tx_start;
    reg [159:0] map_levels;
    wire [383:0] colors;
    always @(posedge clk) begin
        if(rst) begin
            latest_levels<=0; selftest_sync<=0;
            refresh_count<=0; chase_count<=0; chase_index<=0;
            pending<=1; tx_start<=0;
        end else begin
            selftest_sync<={selftest_sync[0],self_test};
            // Clear wins over a simultaneous stale FFT result.
            if(clear) latest_levels<=0;
            else if(levels_valid) latest_levels<=levels;
            tx_start<=0;
            if(refresh_count==REFRESH_CYCLES-1) begin
                refresh_count<=0; pending<=1;
            end else refresh_count<=refresh_count+1'b1;
            // Keep only the latest full spectrum. The sender locks a full frame.
            if(pending && !busy && !tx_start) begin tx_start<=1; pending<=0; end
            if(!selftest_sync[1]) begin chase_count<=0; chase_index<=0; end
            else if(chase_count==CHASE_CYCLES-1) begin
                chase_count<=0; chase_index<=chase_index+1'b1;
            end else chase_count<=chase_count+1'b1;
        end
    end
    always @* begin
        map_levels=clear ? 160'b0 : latest_levels;
        if(selftest_sync[1]) begin
            map_levels=0;
            map_levels[chase_index*10 +: 10]=10'd420;
        end
    end
    rgb_spectrum_map #(.MAX_BRIGHTNESS(MAX_BRIGHTNESS),.LEVEL_SHIFT(LEVEL_SHIFT))
        u_map(.levels(map_levels),.colors(colors));
    ws2812_tx #(.NUM_LEDS(16),.BIT_CYCLES((CLOCK_HZ+400000)/800000),
        .T0H_CYCLES(((CLOCK_HZ/1000000)*35+99)/100),
        .T1H_CYCLES(((CLOCK_HZ/1000000)*70+99)/100),
        .RESET_CYCLES(CLOCK_HZ/2500)) u_tx(
        .clk(clk),.rst(rst),.colors(colors),.start(tx_start),
        .data_out(data_out),.busy(busy),.done(frame_done));
`ifndef SYNTHESIS
    initial begin
        if(REFRESH_CYCLES<1 || CHASE_CYCLES<1 ||
           MAX_BRIGHTNESS<1 || MAX_BRIGHTNESS>255 || LEVEL_SHIFT<0 || LEVEL_SHIFT>9)
            $fatal(1,"Invalid RGB music ring parameters");
    end
`endif
endmodule
`default_nettype wire
