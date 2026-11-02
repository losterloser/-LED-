`timescale 1ns/1ps
module tb_reset_sync;
    reg clk=0, arst=1;
    always #5 clk=~clk;
    wire rst;
    reset_sync dut(clk,arst,rst);
    integer i;
    task check_release;
        begin
            for(i=0;i<3;i=i+1) begin
                @(posedge clk); #1;
                if(rst!==1) $fatal(1,"Reset released before synchronizer settled");
            end
            @(posedge clk); #1;
            if(rst!==0) $fatal(1,"Reset did not release after four clocks");
        end
    endtask
    initial begin
        #12; arst=0;
        check_release();
        // A sub-clock asynchronous pulse must be retained until a clock edge.
        @(negedge clk); #2; arst=1;
        #1;
        if(rst!==0) $fatal(1,"Consumer reset changed asynchronously");
        arst=0;
        @(posedge clk); #1;
        if(rst!==1) $fatal(1,"Short reset pulse was lost");
        repeat(2) begin @(posedge clk); #1; if(rst!==1) $fatal(1,"Reset pulse too short"); end
        @(posedge clk); #1;
        if(rst!==0) $fatal(1,"Reset remained asserted");
        // Holding the request high must hold reset regardless of clock count.
        @(negedge clk); arst=1;
        repeat(8) begin @(posedge clk); #1; if(rst!==1) $fatal(1,"Held reset released"); end
        @(negedge clk); arst=0;
        check_release();
        $display("PASS tb_reset_sync: synchronous output, short pulse retained, held reset and clean release");
        $finish;
    end
    initial begin #1000; $fatal(1,"Reset test timeout"); end
endmodule
