`timescale 1ns/1ps
module tb_ws2812_tx;
    reg clk=0; always #5 clk=~clk;
    reg rst=1, start=0;
    reg [383:0] colors=0, first_frame=0;
    wire data_out,busy,done;
    integer i,rises=0;
    always @(posedge data_out) rises=rises+1;
    ws2812_tx dut(clk,rst,colors,start,data_out,busy,done);
    task receive_and_check(input reg [383:0] expected);
        integer k;
        time rise_time,fall_time,next_rise;
        begin
            rises=0;
            @(posedge data_out); rise_time=$time;
            for(k=383;k>=0;k=k-1) begin
                @(negedge data_out); fall_time=$time;
                if(fall_time-rise_time != (expected[k] ? 650 : 350))
                    $fatal(1,"Pulse width/order mismatch bit %0d: %0t",k,fall_time-rise_time);
                if(k>0) begin
                    @(posedge data_out); next_rise=$time;
                    if(next_rise-rise_time!=1250) $fatal(1,"Bit period is not 1250 ns");
                    rise_time=next_rise;
                end
            end
            @(posedge done);
            if(rises!=384) $fatal(1,"Frame contained %0d pulses instead of exactly 384",rises);
            if($time-fall_time<400000) $fatal(1,"Reset/latch low interval too short");
            if(data_out!==0 || busy!==0) $fatal(1,"Done did not leave sender idle/low");
        end
    endtask
    initial begin
        for(i=0;i<16;i=i+1)
            first_frame[(15-i)*24 +: 24]={8'(i*13+3),8'(255-i*9),8'(128^i)};
        repeat(5) @(negedge clk); rst=0;
        wait(!busy);
        if($time<400000) $fatal(1,"Missing power-up reset gap");
        fork
            receive_and_check(first_frame);
            begin
                @(negedge clk); colors=first_frame; start=1;
                @(negedge clk); start=0;
                // Mutating input and asserting start while busy must not tear a frame.
                #25000; colors=~first_frame; start=1;
                repeat(10) @(negedge clk); start=0;
            end
        join
        repeat(10) @(negedge clk);
        if(data_out || busy || done) $fatal(1,"Busy start was queued or done is not a pulse");
        fork
            receive_and_check({384{1'b1}});
            begin
                @(negedge clk); colors={384{1'b1}}; start=1;
                @(negedge clk); start=0;
            end
        join
        // Aborting a transfer must force low and establish a fresh reset gap.
        @(negedge clk); colors={384{1'b1}}; start=1;
        @(negedge clk); start=0;
        repeat(50) @(negedge clk); rst=1;
        repeat(2) @(negedge clk);
        if(data_out!==0) $fatal(1,"Reset failed to force low");
        rst=0;
        wait(!busy);
        fork
            receive_and_check(384'b0);
            begin
                @(negedge clk); colors=0; start=1;
                @(negedge clk); start=0;
            end
        join
        $display("PASS tb_ws2812_tx: 384 bits, GRB/MSB order, 350/650 ns highs, 1250 ns period, 400 us reset, locked frame and reset recovery");
        $finish;
    end
    initial begin #5000000; $fatal(1,"WS2812 sender timeout"); end
endmodule
