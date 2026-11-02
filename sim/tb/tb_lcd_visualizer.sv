`timescale 1ns/1ps
module tb_lcd_visualizer;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,valid=0,clear=0,self_test=0,ready=1,error=0;
    reg[1:0]mode=0;reg[159:0]levels=0;
    wire[23:0]rgb;wire de,hs,vs,pclk,bl,reset_n,start;
    wire[159:0]snapshot;wire[1:0]snapshot_mode;
    wire snapshot_test,snapshot_ready,snapshot_error;
    wire[31:0]frame_count;
    integer frames=0,index=0,xx,yy,line_pixels=0;
    realtime previous_clock=0,last_bus_change=0;
    reg[159:0]expected_first=0,expected_second=0;
    lcd_visualizer #(.RESET_HOLD_CYCLES(8),.SETTLE_CYCLES(8)) dut(
        clk,rst,levels,valid,clear,mode,self_test,ready,error,rgb,de,hs,vs,pclk,bl,reset_n,
        snapshot,snapshot_mode,snapshot_test,snapshot_ready,snapshot_error,start,frame_count,1'b0,1'b0,,);
    always @(rgb or de) last_bus_change=$realtime;
    always @(negedge pclk) if(!rst) begin
        if(previous_clock!=0 && ($realtime-previous_clock<19.999 || $realtime-previous_clock>20.001))
            $fatal(1,"LCD clock period %f",$realtime-previous_clock);
        previous_clock=$realtime;
        if(!hs || !vs || !reset_n)$fatal(1,"LCD DE-mode controls");
        if(de) begin
            if($realtime-last_bus_change<10.0)$fatal(1,"LCD data/DE not stable before sampling edge");
            xx=index%1024;yy=index/1024;
            if(frames==0 && snapshot!==expected_first)$fatal(1,"First frame tearing");
            if(frames==1 && (snapshot!==expected_second || snapshot_mode!=1))$fatal(1,"Second frame snapshot");
            if(frames>=2 && snapshot!==0)$fatal(1,"Clear lost to stale valid frame");
            if(frames==3 && !snapshot_test)$fatal(1,"Self-test metadata not latched");
            if(frames==0 && xx==480 && yy==360 && rgb!==24'h00ffff)$fatal(1,"First-frame cyan bar");
            if(frames==1 && xx==32 && yy==300 && rgb!==24'hff0000)$fatal(1,"Second-frame red bar");
            if(frames==2 && yy==300 && xx==32 && rgb!==24'h0c1526)$fatal(1,"Cleared frame not blank");
            if(frames==3 && yy==300 && xx==64 && rgb!==24'hffffff)$fatal(1,"LCD colorbar self-test");
            index=index+1;line_pixels=line_pixels+1;
            if(index==614400)begin index=0;frames=frames+1;end
        end else begin
            if(rgb!==24'bz)$fatal(1,"LCD RGB should release during blanking");
            if(line_pixels!=0 && line_pixels!=1024)$fatal(1,"DE line length %0d",line_pixels);
            line_pixels=0;
        end
    end
    task publish;
        begin @(negedge clk);valid=1;@(negedge clk);valid=0;end
    endtask
    initial begin
        expected_first[7*10+:10]=281;expected_first[11*10+:10]=187;levels=expected_first;
        expected_second[0+:10]=420;
        repeat(8)@(negedge clk);rst=0;publish();
        wait(index==100);levels=expected_second;mode=1;publish();
        wait(frames==1);wait(index==100);clear=1;levels={160{1'b1}};publish();
        wait(frames==3);self_test=1;
        wait(frames==4);
        if(!bl || frame_count<4)$fatal(1,"Backlight warm-up");
        @(negedge clk);rst=1;@(negedge clk);
        if(de || bl || reset_n)$fatal(1,"LCD reset recovery");
        $display("PASS tb_lcd_visualizer: 4 full frames, no tearing, next-frame mode update, clear priority, colorbar test, 50MHz falling-edge sampling, 10ns setup, backlight and reset");$finish;
    end
    initial begin #75000000;$fatal(1,"LCD visualizer timeout");end
endmodule
