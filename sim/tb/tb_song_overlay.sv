`timescale 1ns/1ps
module tb_song_overlay;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,clear=0,rv=0,re=0,fs=0;
    reg[7:0]rd=0;reg[9:0]x=0,y=0;
    wire area,on;wire[15:0]ack;wire[31:0]good,bad;
    reg[7:0]vector[0:7691];integer n,xx,yy;
    song_overlay #(.TIMEOUT_CYCLES(100),.TTL_CYCLES(2000000)) dut(
        clk,rst,clear,2'd2,16'd5,rd,rv,re,fs,x,y,area,on,ack,good,bad);
    function[15:0]crc_byte(input[15:0]c,input[7:0]b);
        integer i;reg[15:0]t;
        begin t=c^{b,8'b0};for(i=0;i<8;i=i+1)t=t[15]?(t<<1)^16'h1021:t<<1;crc_byte=t;end
    endfunction
    task byte_in(input[7:0]b);
        begin @(negedge clk);rd=b;rv=1;@(negedge clk);rv=0;end
    endtask
    task frame(input[15:0]seq,ep,input[7:0]md,input invert,corrupt);
        integer k;reg[7:0]b;reg[15:0]crc;
        begin
            crc=16'hffff;
            for(k=0;k<7690;k=k+1)begin
                b=vector[k];
                case(k)5:b=seq[7:0];6:b=seq[15:8];7:b=md;8:b=ep[7:0];9:b=ep[15:8];default:;endcase
                if(k>=10 && invert)b=~b;
                if(k>=2)crc=crc_byte(crc,b);
                byte_in(b);
            end
            byte_in(crc[7:0]);byte_in(crc[15:8]^{7'b0,corrupt});
            repeat(4)@(negedge clk);
        end
    endtask
    task boundary;
        begin @(negedge clk);fs=1;@(negedge clk);fs=0;end
    endtask
    task check_pixel(input integer px,py,input invert);
        reg expected;
        begin
            @(negedge clk);x=px+32;y=py+128;
            @(posedge clk);#1;expected=vector[10+py*120+px/8][7-px%8]^invert;
            if(!area || on!==expected)$fatal(1,"Overlay pixel mismatch %0d,%0d",px,py);
        end
    endtask
    initial begin
        $readmemh("overlay_test_packet.mem",vector);repeat(8)@(negedge clk);rst=0;
        frame(17,5,2,0,0);
        if(ack!=16'hffff || dut.enabled || !dut.pending)$fatal(1,"Partial/early bitmap commit");
        boundary();if(ack!=17 || good!=1)$fatal(1,"Missing frame-boundary ACK");
        for(yy=0;yy<64;yy=yy+1)for(xx=0;xx<960;xx=xx+1)check_pixel(xx,yy,0);
        frame(18,5,2,1,1);boundary();check_pixel(50,10,0);
        if(ack!=17 || bad!=1)$fatal(1,"Corrupt bitmap was accepted");
        frame(18,6,2,1,0);boundary();if(ack!=17)$fatal(1,"Stale epoch accepted");
        frame(18,5,1,1,0);boundary();if(ack!=17)$fatal(1,"Wrong mode accepted");
        frame(18,5,2,1,0);check_pixel(50,10,0);
        boundary();check_pixel(50,10,1);if(ack!=18)$fatal(1,"Replacement not atomic");
        byte_in(8'ha5);byte_in(8'h5a);byte_in(8'h20);repeat(110)@(negedge clk);
        if(dut.state!=0)$fatal(1,"Partial packet timeout");
        repeat(2000001)@(negedge clk);if(dut.enabled)$fatal(1,"Disconnected host title did not expire");
        frame(19,5,2,0,0);boundary();if(ack!=19)$fatal(1,"Recovery after timeout");
        clear=1;@(negedge clk);clear=0;@(negedge clk);
        if(dut.enabled || ack!=16'hffff)$fatal(1,"Mode reset did not invalidate title");
        $display("PASS tb_song_overlay: host-encoded Chinese bitmap, all 61440 pixels, CRC/mode/epoch guards, atomic bank swap, ACK, timeout, TTL, reset");$finish;
    end
    initial begin #60000000;$fatal(1,"Overlay timeout");end
endmodule
