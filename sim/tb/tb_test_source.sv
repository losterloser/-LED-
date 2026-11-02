`timescale 1ns / 1ps
module tb_test_source;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    wire signed [15:0] pcm;
    wire valid;
    reg [15:0] reference_rom[0:1023];
    integer n, pass, cycles, previous_cycle;
    // Accelerate sample enables to one per 64 clocks; check ROM sequencing.
    test_source #(.CLOCK_HZ(3072000),.SAMPLE_HZ(48000)) dut(clk,rst,pcm,valid);
    initial begin
        $readmemh("test_tone.mem",reference_rom);
        for(pass=0;pass<2;pass=pass+1) begin
            rst=1;
            repeat(7) @(negedge clk);
            if(valid || pcm!==0) $fatal(1,"Reset did not clear sample output");
            rst=0; n=0; cycles=0; previous_cycle=0;
            while(n<2048) begin
                @(negedge clk); cycles=cycles+1;
                if(valid) begin
                    if(pcm!==reference_rom[n%1024])
                        $fatal(1,"ROM sequence mismatch at sample %0d",n);
                    if(cycles-previous_cycle!=64)
                        $fatal(1,"Sample interval mismatch");
                    previous_cycle=cycles; n=n+1;
                end
            end
            repeat(13) @(negedge clk);
        end
        $display("PASS tb_test_source: ROM wrap, sample cadence, restart after reset");
        $finish;
    end
    initial begin #4000000; $fatal(1,"ROM source timeout"); end
endmodule
