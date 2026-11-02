`timescale 1ns/1ps
module tb_recognition_uart;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,valid=0,manual=0,manual_rx=1,checking=1;
    reg[7:0]data=0;
    wire ready,tx,rv,err;wire[7:0]rd;
    integer received=0,errors=0,i;
    recognition_uart_tx dut(clk,rst,data,valid,ready,tx);
    recognition_uart_rx rx(clk,rst,manual?manual_rx:tx,rd,rv,err);
    always @(posedge clk) begin
        #1;
        if(!rst && err)errors=errors+1;
        if(!rst && rv && checking)begin
            if(rd!==((received*73+19)&255))$fatal(1,"UART byte/order mismatch");
            received=received+1;
        end
    end
    task send(input[7:0]b);
        begin wait(ready);@(negedge clk);data=b;valid=1;@(negedge clk);valid=0;wait(!ready);wait(ready);end
    endtask
    initial begin
        repeat(8)@(negedge clk);rst=0;
        for(i=0;i<32;i=i+1)send((i*73+19)&255);
        wait(received==32);checking=0;manual=1;manual_rx=0;
        repeat(1000)@(negedge clk);manual_rx=1;repeat(300)@(negedge clk);
        if(errors==0)$fatal(1,"Missing framing error on invalid stop");
        manual=0;send(8'hac);#1;
        if(rd!==8'hac)$fatal(1,"UART did not recover after framing error");
        $display("PASS tb_recognition_uart: 500k 8N1, 32 ordered bytes, bad stop, recovery");$finish;
    end
    initial begin #2000000;$fatal(1,"UART timeout");end
endmodule
