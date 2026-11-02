`timescale 1ns/1ps
module tb_pcm_uart;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,clear=1,valid=0;reg[1:0]mode=2;reg[15:0]pcm=0;
    wire tx;wire[15:0]epoch;wire[31:0]drops;
    wire[7:0]rd;wire rv,err;
    integer f,n,bytes_received=0;
    music_pcm_uart dut(clk,rst,clear,mode,pcm,valid,16'h1234,tx,epoch,drops);
    recognition_uart_rx rx(clk,rst,tx,rd,rv,err);
    always @(posedge clk)begin
        #1;
        if(!rst && err)$fatal(1,"Framing error on PCM link");
        if(!rst && rv)begin $fwrite(f,"%02x\n",rd);bytes_received=bytes_received+1;end
    end
    task sample(input integer value);
        begin @(negedge clk);pcm=value;valid=1;@(negedge clk);valid=0;repeat(4165)@(negedge clk);end
    endtask
    initial begin
        f=$fopen("pcm_uart_capture.hex","w");repeat(8)@(negedge clk);rst=0;clear=0;
        for(n=0;n<384;n=n+1)sample(n*97-23000);
        wait(bytes_received==846);repeat(300)@(negedge clk);
        clear=1;mode=1;repeat(8)@(negedge clk);clear=0;
        for(n=0;n<128;n=n+1)sample(12000-n*47);
        wait(bytes_received==1128);repeat(200)@(negedge clk);$fclose(f);
        if(drops || epoch!=1)$fatal(1,"Unexpected PCM overflow/epoch");
        $display("PASS tb_pcm_uart: four real-500k framed packets, PCM continuity, mode/session reset; host CRC check follows");$finish;
    end
    initial begin #65000000;$fatal(1,"PCM link timeout");end
endmodule
