`timescale 1ns/1ps
module tb_top_music_rgb;
    reg clk=0; always #10 clk=~clk;
    reg rst_n=0;
    reg [1:0] keys=2'b11;
    reg adc=0;
    tri1 scl,sda;
    wire mclk,bclk,lrck,dac,rgb,recognition_tx;
    wire [1:0] leds;
    wire [23:0] lcd_rgb;
    wire lcd_de,lcd_hs,lcd_vs,lcd_bl,lcd_clk,lcd_rst_n,touch_rst_n;
    integer nack_byte=-1,nack_transaction=-1;
    top_music_rgb #(.STARTUP_CYCLES(32),.KEY_STABLE_CYCLES(12),
        .CODEC_POWERUP_CYCLES(20),.CODEC_REFERENCE_CYCLES(20),.I2C_STEP_CYCLES(8),
        .TEST_SAMPLE_HZ(781250),.RGB_REFRESH_HZ(1000),.AUDIO_TIMEOUT_CYCLES(10000),.LCD_RESET_HOLD_CYCLES(20),.LCD_SETTLE_CYCLES(20)) dut(
        clk,rst_n,keys,scl,sda,adc,mclk,bclk,lrck,dac,rgb,leds,lcd_rgb,lcd_de,lcd_hs,lcd_vs,lcd_bl,lcd_clk,lcd_rst_n,touch_rst_n,1'b1,recognition_tx);
    i2c_slave_model slave(!rst_n,1'b1,nack_byte,nack_transaction,scl,sda);
    reg [15:0] rom[0:1023];
    integer sample_index=0,position=0;
    reg old_lrck=1;
    reg [15:0] sample_word=0;
    // Mock the external ADC at the actual generated 48kHz/32-bit-slot I2S pins.
    always @(negedge bclk) begin
        #1;
        if(lrck!=old_lrck) begin
            old_lrck=lrck; position=0;
            if(!lrck) begin sample_word=rom[sample_index]; sample_index=(sample_index+1)%1024; end
        end else position=position+1;
        adc=(position>=1 && position<=16) ? sample_word[16-position] : 0;
    end
    task press(input integer key_number);
        begin
            @(negedge clk); keys[key_number]=0;
            repeat(30) @(negedge clk); keys[key_number]=1;
            repeat(30) @(negedge clk);
        end
    endtask
    task receive_rgb(output reg[383:0] frame);
        integer k;
        realtime t0,last_start;
        begin
            frame=0; last_start=0;
            for(k=383;k>=0;k=k-1) begin
                @(posedge rgb); t0=$realtime;
                if(k!=383 && t0-last_start!=1260.0) $fatal(1,"50MHz RGB bit period");
                last_start=t0;
                @(negedge rgb);
                if($realtime-t0!=360.0 && $realtime-t0!=700.0) $fatal(1,"50MHz RGB high time %f",$realtime-t0);
                frame[k]=($realtime-t0>500.0);
            end
        end
    endtask
    reg [383:0] frame,expected;
    integer writes_before,i,lit;
    initial begin
        $readmemh("test_tone.mem",rom);
        #1000; rst_n=1;
        wait(dut.result_count>=2);
        if(dut.mode!=0 || dut.drop_count || dut.protocol_errors || dut.format_errors || dac!==0)
            $fatal(1,"ROM startup/counters/DAC state");
        @(posedge dut.rgb_frame_done); receive_rgb(frame);
        expected=0; expected[(15-7)*24 +:24]=24'h200020;
        expected[(15-11)*24 +:24]=24'h000b17;
        if(frame!==expected) $fatal(1,"Full top ROM-to-GRB mismatch");
        press(1); @(posedge dut.rgb_frame_done); receive_rgb(frame);
        lit=0; for(i=0;i<16;i=i+1) if(frame[i*24 +:24]!=0) lit=lit+1;
        if(lit!=1) $fatal(1,"KEY1 chase self-test");
        press(1); press(0);
        if(dut.mode!=1) $fatal(1,"KEY0 MIC selection");
        wait(dut.init_done); wait(dut.result_count>=1); #1;
        if(dut.levels[7*10 +:10]<270 || dut.levels[11*10 +:10]<175 ||
           dut.drop_count || dut.protocol_errors || dut.format_errors)
            $fatal(1,"Real-rate I2S-to-FFT MIC path");
        if(slave.packets[7]!==24'h200988 || slave.packets[8]!==24'h200af0 || slave.packets[10]!==24'h200c4c)
            $fatal(1,"MIC profile not transmitted");
        writes_before=slave.writes; press(0);
        wait(!dut.init_done); wait(dut.init_done);
        if(dut.mode!=2 || slave.writes!=writes_before+24 ||
           slave.packets[writes_before+7]!==24'h200900 ||
           slave.packets[writes_before+8]!==24'h200a50 ||
           slave.packets[writes_before+10]!==24'h200c0c)
            $fatal(1,"LINE switch did not reconfigure codec");
        wait(dut.result_count>=1); #1;
        if(dut.drop_count || dut.protocol_errors || dut.format_errors) $fatal(1,"LINE stream error");
        // Lost receiver stream (not ordinary quiet music): expire and clear.
        force dut.u_rx.enable=0;
        wait(!dut.audio_alive); @(posedge dut.rgb_frame_done); receive_rgb(frame);
        if(frame!==0) $fatal(1,"Audio stream timeout did not clear LEDs");
        release dut.u_rx.enable;
        if(dut.lcd_frame_count<2 || !lcd_bl || !lcd_rst_n || touch_rst_n) $fatal(1,"LCD startup/frame count/touch isolation");
        press(0); wait(dut.result_count>=1);
        if(dut.mode!=0) $fatal(1,"Mode cycle back to ROM");
        rst_n=0; #1000; rst_n=1; wait(!dut.core_rst);
        if(dut.mode!=0 || dut.self_test) $fatal(1,"PL reset did not restore defaults");
        $display("PASS tb_top_music_rgb: real MMCM and generated I2S, ROM+MIC+LINE FFT, 50MHz exact GRB timing/colors, codec profile changes, controls, lost-stream clear, reset");
        $finish;
    end
    initial begin #100000000; $fatal(1,"Top integration timeout"); end
endmodule
