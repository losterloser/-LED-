`timescale 1ns/1ps
module tb_i2s_rx_stereo;
    reg clk=0; always #10 clk=~clk;
    reg rst=1,enable=1,bclk=0,lrck=1,data=0;
    wire signed [15:0] left_data,right_data;
    wire valid;
    wire [31:0] errors;
    integer pairs=0;
    reg [31:0] expected[0:3];
    i2s_rx_stereo dut(clk,rst,enable,bclk,lrck,data,left_data,right_data,valid,errors);
    always @(posedge clk) if(valid && !rst) begin
        if(pairs>3 || {left_data,right_data}!==expected[pairs])
            $fatal(1,"I2S pair %0d: %h/%h",pairs,left_data,right_data);
        pairs=pairs+1;
    end
    task slot(input bit channel,input reg[15:0] word_value,input integer length);
        integer k;
        begin
            for(k=0;k<length;k=k+1) begin
                bclk=0; lrck=channel;
                // I2S dummy bit at index 0; nonzero padding must be ignored.
                data=(k>=1 && k<=16) ? word_value[16-k] : (k%2);
                #163; bclk=1; #163;
            end
            bclk=0;
        end
    endtask
    initial begin
        expected[0]=32'h1234f234; expected[1]=32'h80007fff;
        expected[2]=32'h8001a55a; expected[3]=32'hcafebeef;
        #517; rst=0;
        slot(1,0,7); // Start partway through a right slot.
        slot(0,16'h1234,32); slot(1,16'hf234,32);
        slot(0,16'h8000,32); slot(1,16'h7fff,32);
        slot(0,16'h8001,32); slot(1,16'ha55a,32);
        // Bad left slot must not create a pair with a stale left word.
        slot(0,16'hdead,31); slot(1,16'h1111,32);
        slot(0,16'hcafe,32); slot(1,16'hbeef,32);
        slot(0,0,1); #500;
        if(pairs!=4 || errors!=1) $fatal(1,"Pairs/errors: %0d/%0d",pairs,errors);
        // Disable while serial clocks continue: no residual output or error.
        enable=0; slot(1,16'hffff,32);
        if(valid || errors!=0 || left_data!=0 || right_data!=0) $fatal(1,"Disable did not clear I2S state");
        $display("PASS tb_i2s_rx_stereo: asynchronous 32-bit-slot I2S, delay bit, signed stereo, padding, malformed-slot suppression, resynchronization");
        $finish;
    end
    initial begin #300000; $fatal(1,"I2S timeout"); end
endmodule
