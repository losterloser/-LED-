`timescale 1ns/1ps
module tb_es8388_init;
    reg clk=0; always #10 clk=~clk;
    reg rst=1, use_mic=1, ack=1;
    integer nack_byte=-1, nack_transaction=-1;
    tri1 scl,sda;
    wire done,error;
    wire [4:0] index;
    es8388_init #(.POWERUP_CYCLES(20),.REFERENCE_CYCLES(100),
        .I2C_STEP_CYCLES(8),.BUS_TIMEOUT_CYCLES(200)) dut(
        clk,rst,use_mic,scl,sda,done,error,index);
    i2c_slave_model slave(rst,ack,nack_byte,nack_transaction,scl,sda);
    reg [15:0] expected[0:23];
    integer k;
    task reset_profile(input bit mic);
        begin
            @(negedge clk); rst=1; use_mic=mic;
            repeat(8) @(negedge clk); rst=0;
        end
    endtask
    task verify_profile;
        begin
            wait(done || error); #1;
            if(error || slave.writes!=24 || index!=23) $fatal(1,"Incomplete codec profile");
            for(k=0;k<24;k=k+1)
                if(slave.packets[k]!=={8'h20,expected[k]})
                    $fatal(1,"Codec physical write %0d: %h != %h",k,slave.packets[k],{8'h20,expected[k]});
        end
    endtask
    initial begin
        expected[0]=16'h0080; expected[1]=16'h0006; expected[2]=16'h0150;
        expected[3]=16'h02f3; expected[4]=16'h03fc; expected[5]=16'h04c0;
        expected[6]=16'h0800; expected[7]=16'h0988; expected[8]=16'h0af0;
        expected[9]=16'h0b00; expected[10]=16'h0c4c; expected[11]=16'h0d02;
        expected[12]=16'h0e30; expected[13]=16'h0f24; expected[14]=16'h1000;
        expected[15]=16'h1100; expected[16]=16'h1200; expected[17]=16'h1926;
        expected[18]=16'h2700; expected[19]=16'h2a00; expected[20]=16'h2b80;
        expected[21]=16'h0308; expected[22]=16'h0255; expected[23]=16'h0f20;
        reset_profile(1); verify_profile();
        expected[7]=16'h0900; expected[8]=16'h0a50; expected[10]=16'h0c0c;
        reset_profile(0); verify_profile();
        // One rejected address is retried, then the complete profile succeeds.
        nack_byte=0; nack_transaction=1;
        reset_profile(0); verify_profile();
        if(slave.transactions!=25) $fatal(1,"Address NACK was not retried once");
        // Any of the three missing ACKs must prevent a false ready state.
        nack_transaction=-1;
        for(k=0;k<3;k=k+1) begin
            nack_byte=k; reset_profile(1); wait(error || done); #1;
            if(done || slave.transactions!=3 || index!=0) $fatal(1,"NACK byte %0d failure/retry handling",k);
        end
        $display("PASS tb_es8388_init: pin-level 24-write MIC/LINE profiles, 0x20 address, DAC off, transient retry, all three NACK positions");
        $finish;
    end
    initial begin #2000000; $fatal(1,"Codec configuration timeout"); end
endmodule
