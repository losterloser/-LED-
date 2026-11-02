`timescale 1ns/1ps
module tb_spectrum_renderer;
    reg [9:0] x=0,y=0;reg [159:0] levels=0;reg[1:0]mode=0;
    reg self_test=0,ready=1,error=0;
    wire[23:0]pixel;
    reg[23:0] palette[0:15],bars[0:7];
    integer i;
    spectrum_renderer dut(x,y,levels,mode,self_test,ready,error,pixel);
    task at(input integer xx,yy,input reg[23:0]expected);
        begin x=xx;y=yy;#10;if(pixel!==expected)$fatal(1,"Pixel (%0d,%0d) %h expected %h",xx,yy,pixel,expected);end
    endtask
    initial begin
        palette[0]=24'hff0000;palette[1]=24'hff4000;palette[2]=24'hff8000;palette[3]=24'hffff00;
        palette[4]=24'h80ff00;palette[5]=24'h00ff00;palette[6]=24'h00ff80;palette[7]=24'h00ffff;
        palette[8]=24'h0080ff;palette[9]=24'h0000ff;palette[10]=24'h4000ff;palette[11]=24'h8000ff;
        palette[12]=24'hff00ff;palette[13]=24'hff0080;palette[14]=24'hff0040;palette[15]=24'hffffff;
        for(i=0;i<16;i=i+1) levels[i*10+:10]=420;
        for(i=0;i<16;i=i+1) at(i*64+32,300,palette[i]);
        levels=0;levels[7*10+:10]=281;levels[11*10+:10]=187;
        at(480,309,24'h0c1526);at(480,310,24'h00ffff);
        at(736,379,24'h0c1526);at(736,380,24'h8000ff);
        levels[0+:10]=1023;at(32,204,24'h0c1526);at(32,206,24'hff0000);
        at(32,16,24'h101d32);at(36,16,24'h73e3ef); // A top row 01110.
        at(32,104,24'hdbeaf9); // INPUT text is visible.
        // The first letter of READY and ERROR has a set top-left pixel.
        at(736,104,24'h5cf0a2);error=1;at(736,104,24'hff6464);error=0;
        bars[0]=24'hffffff;bars[1]=24'hffff00;bars[2]=24'h00ffff;bars[3]=24'h00ff00;
        bars[4]=24'hff00ff;bars[5]=24'hff0000;bars[6]=24'h0000ff;bars[7]=24'h000000;
        self_test=1;for(i=0;i<8;i=i+1)at(i*128+64,300,bars[i]);
        $display("PASS tb_spectrum_renderer: 16 colors, exact tone bar heights, clamp, bitmap text, ready/error status, 8-color screen self-test");$finish;
    end
    initial begin #100000;$fatal(1,"Renderer combinational timeout");end
endmodule
