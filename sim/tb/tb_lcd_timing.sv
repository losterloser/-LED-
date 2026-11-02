`timescale 1ns/1ps
module tb_lcd_timing;
    reg clk=0;always #10 clk=~clk;
    reg rst=1;
    wire active,start;
    wire [9:0] x,y;
    wire [10:0] h,v;
    integer ticks=0,pixels=0,lines=0,frames=0;
    lcd_timing_1024 dut(clk,rst,active,start,x,y,h,v);
    always @(posedge clk) if(!rst) begin
        if(start && ticks!=0) begin
            if(ticks!=853440 || pixels!=614400 || lines!=600) $fatal(1,"LCD frame geometry %0d %0d %0d",ticks,pixels,lines);
            frames=frames+1;ticks=0;pixels=0;lines=0;
        end
        if(active) begin
            if(h<160 || h>=1184 || v<23 || v>=623 || x!=h-160 || y!=v-23) $fatal(1,"LCD active coordinate");
            pixels=pixels+1;if(x==0) lines=lines+1;
        end else if(x || y) $fatal(1,"Blanking coordinates not zero");
        ticks=ticks+1;
    end
    initial begin
        repeat(8) @(negedge clk);rst=0;
        wait(frames==2);
        @(negedge clk);rst=1;@(negedge clk);
        if(h || v || active) $fatal(1,"LCD scan reset");
        $display("PASS tb_lcd_timing: 2 complete 1344x635 frames, 614400 active pixels/frame, 600 lines, coordinates and reset");$finish;
    end
    initial begin #40000000;$fatal(1,"LCD timing timeout");end
endmodule
