`timescale 1ns/1ps
module tb_i2c_faults;
    reg clk=0; always #10 clk=~clk;
    reg rst=1,start=0,stretch=0;
    tri1 scl,sda;
    wire busy,done,error;
    assign scl=stretch ? 1'b0 : 1'bz;
    i2c_write24 #(.QUARTER_CYCLES(12),.TIMEOUT_CYCLES(400)) dut(
        clk,rst,start,24'h200c4c,scl,sda,busy,done,error);
    i2c_slave_model slave(rst,1'b1,-1,-1,scl,sda);
    task request;
        begin @(negedge clk); start=1; @(negedge clk); start=0; end
    endtask
    initial begin
        repeat(10) @(negedge clk); rst=0;
        request();
        wait(slave.bits==3); @(negedge scl); stretch=1;
        repeat(100) @(negedge clk); stretch=0;
        wait(done); #1;
        if(error || slave.writes!=1 || slave.packets[0]!=24'h200c4c)
            $fatal(1,"Clock stretching corrupted write");
        @(negedge clk); rst=1; repeat(4) @(negedge clk); rst=0;
        stretch=1; request(); wait(done); #1;
        if(!error || busy) $fatal(1,"Stuck SCL did not terminate with error");
        stretch=0; #1000;
        request(); wait(done); #1;
        if(error || slave.writes!=1) $fatal(1,"Bus did not recover after timeout");
        $display("PASS tb_i2c_faults: clock stretching, stuck-low timeout, bus release and next-write recovery");
        $finish;
    end
    initial begin #200000; $fatal(1,"I2C fault test timeout"); end
endmodule
