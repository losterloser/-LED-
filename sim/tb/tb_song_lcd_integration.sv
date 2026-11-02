`timescale 1ns/1ps
module tb_song_lcd_integration;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,rv=0;reg[7:0]rd=0;reg[159:0]levels=0;
    wire[9:0]x,y;wire area,on;wire[15:0]ack;wire[31:0]good,bad;
    wire[23:0]rgb;wire de,hs,vs,pclk,bl,rn,fs;wire[159:0]snapshot;
    wire[1:0]fm;wire ft,fr,fe;wire[31:0]fc;
    reg[7:0]vector[0:7691];integer n,f,pixels=0,xx,yy;
    reg capture=0,expected;
    song_overlay overlay(clk,rst,1'b0,2'd2,16'd5,rd,rv,1'b0,fs,x,y,area,on,ack,good,bad);
    lcd_visualizer #(.RESET_HOLD_CYCLES(8),.SETTLE_CYCLES(8),.ENABLE_SONG_OVERLAY(1)) lcd(
        clk,rst,levels,1'b1,1'b0,2'd2,1'b0,1'b1,1'b0,rgb,de,hs,vs,pclk,bl,rn,
        snapshot,fm,ft,fr,fe,fs,fc,area,on,x,y);
    always @(negedge pclk)if(!rst && de && capture)begin
        xx=pixels%1024;yy=pixels/1024;
        if(xx>=32 && xx<992 && yy>=128 && yy<192)begin
            expected=vector[10+(yy-128)*120+(xx-32)/8][7-(xx-32)%8];
            if(rgb!==(expected?24'he7f4ff:24'h070e1b))$fatal(1,"LCD bitmap pipeline mismatch %0d,%0d",xx,yy);
        end
        if(xx==480 && yy==360 && rgb!==24'h00ffff)$fatal(1,"Spectrum cyan bar changed");
        if(xx==736 && yy==400 && rgb!==24'h8000ff)$fatal(1,"Spectrum purple bar changed");
        $fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);pixels=pixels+1;
        if(pixels==614400)begin
            $fclose(f);capture=0;
            if(bad || good!=1 || ack!=17)$fatal(1,"LCD integration protocol state");
            $display("PASS tb_song_lcd_integration: full 1024x600 frame, all Unicode overlay pixels, unchanged spectrum, 50MHz-domain pipeline alignment");$finish;
        end
    end
    initial begin
        $readmemh("overlay_test_packet.mem",vector);levels[7*10+:10]=281;levels[11*10+:10]=187;
        repeat(8)@(negedge clk);rst=0;
        for(n=0;n<7692;n=n+1)begin @(negedge clk);rd=vector[n];rv=1;@(negedge clk);rv=0;end
        wait(ack==17);f=$fopen("lcd_song_overlay.ppm","wb");$fwrite(f,"P6\n1024 600\n255\n");capture=1;
    end
    initial begin #40000000;$fatal(1,"Song LCD integration timeout");end
endmodule
