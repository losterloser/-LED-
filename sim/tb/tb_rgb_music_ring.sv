`timescale 1ns/1ps
module tb_rgb_music_ring;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,clear=0,self_test=0,levels_valid=0;
    reg [159:0] levels=0;
    wire data_out,busy,done;
    reg [383:0] captured,expected;
    integer i,lit;
    rgb_music_ring #(.REFRESH_HZ(1000),.CHASE_HZ(10000)) dut(
        .clk(clk),.rst(rst),.levels(levels),.levels_valid(levels_valid),
        .clear(clear),.self_test(self_test),.data_out(data_out),.busy(busy),.frame_done(done));
    task receive_frame(output reg [383:0] frame);
        integer k;
        time begin_high;
        begin
            frame=0;
            for(k=383;k>=0;k=k-1) begin
                @(posedge data_out); begin_high=$time;
                @(negedge data_out);
                frame[k]=($time-begin_high>500);
            end
        end
    endtask
    initial begin
        repeat(5) @(negedge clk); rst=0;
        @(negedge clk); levels[7*10 +: 10]=281; levels[11*10 +: 10]=187; levels_valid=1;
        @(negedge clk); levels_valid=0;
        // Contract: band 7 = cyan at capped 32; band 11 = purple R11 B23.
        expected=0; expected[(15-7)*24 +: 24]=24'h200020;
        expected[(15-11)*24 +: 24]=24'h000b17;
        fork
            receive_frame(captured);
            begin
                @(posedge data_out); #100000;
                @(negedge clk); clear=1; levels={160{1'b1}}; levels_valid=1;
                @(negedge clk); levels_valid=0;
            end
        join
        if(captured!==expected) $fatal(1,"Ring spectrum mapping or in-flight snapshot incorrect");
        receive_frame(captured);
        if(captured!==0) $fatal(1,"Clear did not transmit an all-black frame");
        @(negedge clk); clear=0;
        receive_frame(captured);
        if(captured!==0) $fatal(1,"A stale spectrum returned after clear");
        @(negedge clk); levels=0;
        levels[0 +: 10]=1023; levels[15*10 +: 10]=16; levels_valid=1;
        @(negedge clk); levels_valid=0;
        expected=0; expected[383 -: 24]=24'h002000; expected[23:0]=24'h020202;
        receive_frame(captured);
        if(captured!==expected) $fatal(1,"Brightness clamp, LED0 order or white endpoint incorrect");
        @(negedge clk); self_test=1; clear=1;
        repeat(10) @(negedge clk);
        receive_frame(captured);
        lit=0;
        for(i=0;i<16;i=i+1) begin
            if(captured[i*24 +: 24]!=0) lit=lit+1;
            if(captured[i*24 +: 8]>32 || captured[i*24+8 +: 8]>32 ||
               captured[i*24+16 +: 8]>32) $fatal(1,"Self test exceeded brightness cap");
        end
        if(lit!=1) $fatal(1,"Self test did not transmit exactly one lit LED");
        @(negedge clk); self_test=0;
        repeat(10) @(negedge clk);
        receive_frame(captured);
        if(captured!==0) $fatal(1,"Self test did not return to cleared music mode");
        $display("PASS tb_rgb_music_ring: exact GRB colors, 16 LEDs, live-frame isolation, clear priority, no stale replay, brightness cap, self test and mode return");
        $finish;
    end
    initial begin #9000000; $fatal(1,"Music ring timeout"); end
endmodule
