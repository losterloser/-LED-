`timescale 1ns/1ps
`default_nettype none
// ES8388 Rev5 registers, ADC-only profile for Navigator V3.9.
// CE/AD0 is low on the board: 7-bit I2C address 0x10, write byte 0x20.
// MIC1 is LIN1-RIN1 differential; LINE_IN is L/R INPUT2, not the WM8731 map.
module es8388_init #(
    parameter POWERUP_CYCLES=5000000,
    parameter REFERENCE_CYCLES=5000000,
    parameter I2C_STEP_CYCLES=167,
    parameter BUS_TIMEOUT_CYCLES=500000
)(input wire clk, rst, use_mic, inout wire scl, sda,
  output reg init_done, init_error, output reg [4:0] register_index);
    localparam WAIT_POWER=0, ISSUE=1, WAIT_DONE=2, NEXT_REG=3, WAIT_REFERENCE=4, FINISHED=5;
    reg [2:0] state;
    reg [31:0] delay_count;
    reg [1:0] retry;
    reg start, profile_mic;
    reg [15:0] control_word;
    wire busy, done, error;
    always @* begin
        case(register_index)
             0: control_word=16'h0080; // Software reset
             1: control_word=16'h0006; // Reference enabled, 500k VMID divider
             2: control_word=16'h0150; // Analog/reference bias, vendor base setting
             3: control_word=16'h02f3; // Digital reset while selecting the profile
             4: control_word=16'h03fc; // ADC inputs down while configuring
             5: control_word=16'h04c0; // DACs down, every analog output disabled
             6: control_word=16'h0800; // Slave I2S; FPGA generates BCLK/LRCK
             7: control_word=profile_mic ? 16'h0988 : 16'h0900; // +24dB MIC / 0dB LINE
             8: control_word=profile_mic ? 16'h0af0 : 16'h0a50; // Differential INPUT1 / stereo INPUT2
             9: control_word=16'h0b00; // DS=0 -> LIN1-RIN1, no analog mono mixing
            10: control_word=profile_mic ? 16'h0c4c : 16'h0c0c; // 16-bit I2S; MIC left copied to right
            11: control_word=16'h0d02; // Single speed, 256 MCLK/LRCK
            12: control_word=16'h0e30; // ADC high-pass filters enabled
            13: control_word=16'h0f24; // ADC soft-ramp and mute during startup
            14: control_word=16'h1000; // ADC digital left gain 0dB
            15: control_word=16'h1100; // ADC digital right gain 0dB
            16: control_word=16'h1200; // ALC off; brightness follows actual level
            17: control_word=16'h1926; // DAC mute
            18: control_word=16'h2700; // Left analog mixer/bypass off
            19: control_word=16'h2a00; // Right analog mixer/bypass off
            20: control_word=16'h2b80; // Common LRCK selection
            21: control_word=16'h0308; // Both ADCs and input amplifiers on, external MIC bias
            22: control_word=16'h0255; // ADC running; DAC digital/DLL/reference remain down
            23: control_word=16'h0f20; // Unmute ADC
            default: control_word=16'h1926;
        endcase
    end
    i2c_write24 #(.QUARTER_CYCLES(I2C_STEP_CYCLES),.TIMEOUT_CYCLES(BUS_TIMEOUT_CYCLES)) u_bus(
        .clk(clk),.rst(rst),.start(start),.packet({8'h20,control_word}),
        .scl(scl),.sda(sda),.busy(busy),.done(done),.error(error));
    always @(posedge clk) begin
        if(rst) begin
            state<=WAIT_POWER; delay_count<=0; retry<=0; start<=0;
            profile_mic<=use_mic; register_index<=0; init_done<=0; init_error<=0;
        end else begin
            start<=0;
            case(state)
                WAIT_POWER: begin
                    if(delay_count==0) profile_mic<=use_mic;
                    if(delay_count==POWERUP_CYCLES-1) begin delay_count<=0; state<=ISSUE; end
                    else delay_count<=delay_count+1'b1;
                end
                ISSUE: if(!busy) begin start<=1; state<=WAIT_DONE; end
                WAIT_DONE: if(done) begin
                    if(error) begin
                        if(retry==2) begin init_error<=1; state<=FINISHED; end
                        else begin retry<=retry+1'b1; state<=ISSUE; end
                    end else begin retry<=0; state<=NEXT_REG; end
                end
                NEXT_REG: begin
                    if(register_index==23) begin init_done<=1; state<=FINISHED; end
                    else begin
                        register_index<=register_index+1'b1;
                        if(register_index==1) begin delay_count<=0; state<=WAIT_REFERENCE; end
                        else state<=ISSUE;
                    end
                end
                WAIT_REFERENCE: if(delay_count==REFERENCE_CYCLES-1) begin delay_count<=0; state<=ISSUE; end
                                else delay_count<=delay_count+1'b1;
                FINISHED: state<=FINISHED;
                default: state<=WAIT_POWER;
            endcase
        end
    end
`ifndef SYNTHESIS
    initial if(POWERUP_CYCLES<1 || REFERENCE_CYCLES<1) $fatal(1,"Invalid codec delay");
`endif
endmodule
`default_nettype wire
