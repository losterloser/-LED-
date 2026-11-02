`timescale 1ns/1ps
module tb_fft_lcd_integration;
    reg clk=0;always #10 clk=~clk;
    reg rst=1;reg[15:0]pcm=0;reg valid=0;
    wire[15:0]stream;wire sv,sl,sr;
    wire[31:0]drops,frames,errors,results;
    wire signed[26:0]re,im;wire[9:0]idx;
    wire fv,fl,lv;wire[159:0]levels;
    wire[23:0]rgb;wire de,hs,vs,pclk,bl,rn,fs;
    wire[159:0]snapshot;wire[1:0]fm;wire ft,fr,fe;wire[31:0]fc;
    reg[15:0]rom[0:1023];integer n,i,f,pixels=0,images=0;
    reg capture=0;integer cyan=0,purple=0;
    fft_frame_buffer b(clk,rst,pcm,valid,stream,sv,sl,sr,drops,frames);
    fft_analyzer a(clk,rst,stream,sv,sl,sr,re,im,fv,fl,idx,errors);
    spectrum_bands s(clk,rst,re,im,idx,fv,fl,levels,lv,results);
    lcd_visualizer #(.RESET_HOLD_CYCLES(8),.SETTLE_CYCLES(8)) lcd(
        clk,rst,levels,lv,1'b0,2'b0,1'b0,results!=0,1'b0,rgb,de,hs,vs,pclk,bl,rn,
        snapshot,fm,ft,fr,fe,fs,fc,1'b0,1'b0,,);
    always @(negedge pclk) if(!rst && de && capture) begin
        $fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
        if(rgb==24'h00ffff)cyan=cyan+1;if(rgb==24'h8000ff)purple=purple+1;
        pixels=pixels+1;
        if(pixels==614400)begin
            capture=0;$fclose(f);images=1;
        end
    end
    initial begin
        $readmemh("test_tone.mem",rom);
        repeat(20)@(negedge clk);rst=0;
        for(n=0;n<4;n=n+1)for(i=0;i<1024;i=i+1)begin
            @(negedge clk);pcm=rom[i];valid=1;@(negedge clk);valid=0;repeat(62)@(negedge clk);
        end
        wait(results==4);wait(fs);@(posedge clk);#1;
        if(snapshot[7*10+:10]!=281 || snapshot[11*10+:10]!=187)$fatal(1,"LCD did not latch real FFT frame");
        f=$fopen("lcd_spectrum.ppm","wb");$fwrite(f,"P6\n1024 600\n255\n");capture=1;
        wait(images==1);
        if(cyan!=44*210 || purple!=44*140 || errors || drops)$fatal(1,"FFT-to-screen bar areas/counters: cyan=%0d purple=%0d",cyan,purple);
        $display("PASS tb_fft_lcd_integration: real FFT IP to complete 1024x600 LCD image, exact cyan/purple bar pixel areas, no drop/protocol errors; lcd_spectrum.ppm generated");$finish;
    end
    initial begin #40000000;$fatal(1,"FFT LCD integration timeout");end
endmodule
