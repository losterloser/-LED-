`timescale 1ns / 1ps
module tb_spectrum_pipeline;
    reg clk=0;
    always #5 clk=~clk;
    reg rst=1;
    reg signed [15:0] pcm=0;
    reg valid=0;
    wire [15:0] stream;
    wire stream_valid, stream_last, stream_ready;
    wire [31:0] drops, frames, errors, results;
    wire signed [26:0] real_value, imag_value;
    wire [9:0] index;
    wire fft_valid, fft_last, levels_valid;
    wire [159:0] levels;
    reg [15:0] rom[0:1023];
    integer i, n, output_points=0, complete=0, csv;
    reg saw16=0, saw64=0;
    longint mag;
    fft_frame_buffer u_buffer(clk,rst,pcm,valid,stream,stream_valid,stream_last,stream_ready,drops,frames);
    fft_analyzer u_fft(clk,rst,stream,stream_valid,stream_last,stream_ready,
        real_value,imag_value,fft_valid,fft_last,index,errors);
    spectrum_bands u_bands(clk,rst,real_value,imag_value,index,fft_valid,fft_last,levels,levels_valid,results);
    always @(posedge clk) begin
        if(!rst && fft_valid) begin
            if(index != output_points%1024) $fatal(1,"FFT output index mismatch");
            output_points=output_points+1;
            mag=(real_value<0 ? -longint'(real_value) : longint'(real_value))+
                (imag_value<0 ? -longint'(imag_value) : longint'(imag_value));
            if(complete==0) $fdisplay(csv,"%0d,%0d,%0d",index,real_value,imag_value);
            if(index==16) begin
                if(mag<4500000 || mag>4800000) $fatal(1,"750 Hz peak magnitude incorrect: %0d",mag);
                saw16=1;
            end
            if(index==64) begin
                if(mag<2950000 || mag>3200000) $fatal(1,"3000 Hz peak magnitude incorrect: %0d",mag);
                saw64=1;
            end
            if(fft_last) begin
                if(index!=1023 || !saw16 || !saw64) $fatal(1,"Incomplete FFT frame");
                complete=complete+1; saw16=0; saw64=0;
            end
        end
        if(!rst && levels_valid) begin
            if(levels[7*10 +: 10]<270 || levels[11*10 +: 10]<175)
                $fatal(1,"Expected bands 7 and 11 are not active");
        end
    end
    initial begin
        $readmemh("test_tone.mem",rom);
        csv=$fopen("fft_first_frame.csv","w");
        $fdisplay(csv,"bin,real,imag");
        repeat(20) @(negedge clk);
        rst=0;
        // Faster than live 48 kHz but slow enough for continuous burst processing.
        for(n=0;n<4;n=n+1) for(i=0;i<1024;i=i+1) begin
            @(negedge clk); pcm=rom[i]; valid=1;
            @(negedge clk); valid=0;
            repeat(62) @(negedge clk);
        end
        wait(results==4);
        repeat(5) @(negedge clk);
        if(drops!=0 || errors!=0 || frames!=4 || output_points!=4096)
            $fatal(1,"Pipeline counters incorrect drops=%0d errors=%0d frames=%0d points=%0d",drops,errors,frames,output_points);
        $fclose(csv);
        $display("PASS tb_spectrum_pipeline: 4 real FFT frames, bins 16/64, bands 7/11, no drops");
        $finish;
    end
    initial begin #6000000; $fatal(1,"Pipeline timeout"); end
endmodule
