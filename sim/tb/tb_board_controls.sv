`timescale 1ns/1ps
module tb_board_controls;
    reg clk=0; always #5 clk=~clk;
    reg rst=1;
    reg [1:0] key_n=2'b11;
    wire [1:0] mode;
    wire self_test;
    board_controls #(.STABLE_CYCLES(12)) dut(clk,rst,key_n,mode,self_test);
    task settle; repeat(30) @(negedge clk); endtask
    task press(input integer index);
        begin key_n[index]=0; settle; key_n[index]=1; settle; end
    endtask
    initial begin
        settle; rst=0; settle;
        if(mode!=0 || self_test) $fatal(1,"Wrong power-on mode");
        key_n=0; repeat(4) @(negedge clk); key_n=3; settle;
        if(mode!=0 || self_test) $fatal(1,"Contact bounce changed mode");
        press(0); if(mode!=1) $fatal(1,"ROM to MIC failed");
        key_n[0]=0; settle; repeat(150) @(negedge clk);
        if(mode!=2) $fatal(1,"Held key repeated or LINE selection failed");
        key_n[0]=1; settle;
        press(0); if(mode!=0) $fatal(1,"LINE to ROM failed");
        press(1); if(!self_test || mode!=0) $fatal(1,"Self-test enable failed");
        press(0); if(mode!=1 || !self_test) $fatal(1,"Keys interfere");
        press(1); if(self_test || mode!=1) $fatal(1,"Self-test disable failed");
        rst=1; settle;
        if(mode!=0 || self_test) $fatal(1,"Reset did not restore ROM/music mode");
        $display("PASS tb_board_controls: debounce, single press, hold, ROM/MIC/LINE cycling, independent chase toggle and reset");
        $finish;
    end
    initial begin #100000; $fatal(1,"Controls simulation timeout"); end
endmodule
