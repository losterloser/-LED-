`timescale 1ns/1ps
module tb_recognition_decimator;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,valid=0;reg signed[15:0]pcm=0;
    wire signed[15:0]out;wire ov;
    reg[15:0]inputs[0:1023],expected[0:224];
    integer n,received=0;
    recognition_decimator dut(clk,rst,pcm,valid,out,ov);
    always @(posedge clk) begin
        #1;
        if(!rst && ov)begin
            if(received>=225 || out!==expected[received])$fatal(1,"FIR mismatch n=%0d got=%0d expected=%0d",received,out,$signed(expected[received]));
            received=received+1;
        end
    end
    initial begin
        $readmemh("fir_input.mem",inputs);$readmemh("fir_expected.mem",expected);
        repeat(8)@(negedge clk);rst=0;
        for(n=0;n<1024;n=n+1)begin
            pcm=inputs[n];valid=1;@(negedge clk);valid=0;repeat(1041)@(negedge clk);
        end
        if(received!=225)$fatal(1,"FIR output count %0d",received);
        rst=1;repeat(4)@(negedge clk);rst=0;
        repeat(500)@(negedge clk);
        if(ov)$fatal(1,"Stale FIR output after reset");
        $display("PASS tb_recognition_decimator: all 225 outputs bit-exact vs independent Q16 convolution, warmup/reset");$finish;
    end
    initial begin #30000000;$fatal(1,"FIR timeout");end
endmodule
