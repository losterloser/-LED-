`timescale 1ns/1ps
module tb_fft_rgb_integration;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,valid=0;
    reg signed [15:0] pcm=0;
    reg [15:0] rom[0:1023];
    wire [15:0] stream;
    wire stream_valid,stream_last,stream_ready;
    wire [31:0] drops,frames,errors,results;
    wire signed [26:0] real_value,imag_value;
    wire [9:0] index;
    wire fft_valid,fft_last,levels_valid;
    wire [159:0] levels;
    wire data_out,busy,done;
    reg [383:0] captured=0,expected=0;
    integer i,k;
    time begin_high;
    fft_frame_buffer u_buffer(clk,rst,pcm,valid,stream,stream_valid,stream_last,stream_ready,drops,frames);
    fft_analyzer u_fft(clk,rst,stream,stream_valid,stream_last,stream_ready,
        real_value,imag_value,fft_valid,fft_last,index,errors);
    spectrum_bands u_bands(clk,rst,real_value,imag_value,index,fft_valid,fft_last,levels,levels_valid,results);
    rgb_music_ring #(.REFRESH_HZ(1000)) ring(
        .clk(clk),.rst(rst),.levels(levels),.levels_valid(levels_valid),
        .clear(1'b0),.self_test(1'b0),.data_out(data_out),.busy(busy),.frame_done(done));
    initial begin
        $readmemh("test_tone.mem",rom);
        repeat(20) @(negedge clk); rst=0;
        for(i=0;i<1024;i=i+1) begin
            @(negedge clk); pcm=rom[i]; valid=1;
            @(negedge clk); valid=0;
            repeat(62) @(negedge clk);
        end
    end
    initial begin
        wait(results==1);
        // Skip the in-flight initial black frame; decode the next whole frame.
        @(posedge done);
        for(k=383;k>=0;k=k-1) begin
            @(posedge data_out); begin_high=$time;
            @(negedge data_out); captured[k]=($time-begin_high>500);
        end
        expected[(15-7)*24 +: 24]=24'h200020;
        expected[(15-11)*24 +: 24]=24'h000b17;
        if(captured!==expected) $fatal(1,"Real FFT output did not reach expected physical LED words");
        if(drops || errors || frames!=1) $fatal(1,"FFT/RGB integration counters failed");
        $display("PASS tb_fft_rgb_integration: real FFT IP, ROM bin16/bin64, LED8/LED12 exact GRB words, no drop/protocol errors");
        $finish;
    end
    initial begin #4000000; $fatal(1,"FFT to RGB integration timeout"); end
endmodule
