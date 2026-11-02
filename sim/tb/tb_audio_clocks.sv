`timescale 1ns/1ps
module tb_audio_clocks;
    reg sys_clk=0; always #10 sys_clk=~sys_clk;
    reg reset=1;
    wire core,codec,locked,mclk,bclk,lrck;
    wire rst;
    audio_clock_tree dut(sys_clk,reset,core,codec,locked);
    reset_sync rs(codec,reset || !locked,rst);
    i2s_master_clock clocks(codec,rst,mclk,bclk,lrck);
    realtime t0,t1,period_mclk;
    integer n;
    initial begin
        #200; reset=0; wait(locked); wait(!rst);
        repeat(10) @(posedge mclk);
        t0=$realtime; repeat(100) @(posedge mclk); t1=$realtime;
        period_mclk=(t1-t0)/100.0;
        if(period_mclk<81.2 || period_mclk>81.6) $fatal(1,"MCLK period %f",period_mclk);
        @(posedge core); t0=$realtime; @(posedge core);
        if($realtime-t0!=20.0) $fatal(1,"Core clock is not 50 MHz");
        @(posedge bclk); t0=$realtime; repeat(10) @(posedge bclk);
        if(($realtime-t0)/10.0 < period_mclk*3.99 || ($realtime-t0)/10.0 > period_mclk*4.01)
            $fatal(1,"BCLK ratio");
        @(posedge lrck); t0=$realtime; repeat(2) @(posedge lrck);
        if(($realtime-t0)/2.0 < period_mclk*255.9 || ($realtime-t0)/2.0 > period_mclk*256.1)
            $fatal(1,"LRCK ratio");
        reset=1; #500;
        if(locked || bclk || lrck) $fatal(1,"Clock reset failed");
        reset=0; wait(locked); wait(!rst); @(posedge lrck);
        $display("PASS tb_audio_clocks: real MMCM/BUFG/ODDR simulation, core 50MHz, MCLK~12.288136MHz, BCLK=MCLK/4, LRCK=MCLK/256, reset/relock");
        $finish;
    end
    initial begin #500000; $fatal(1,"Clock timeout"); end
endmodule
