`timescale 1ns/1ps
`default_nettype none
module board_controls #(
    parameter STABLE_CYCLES=500000
)(input wire clk, input wire rst, input wire [1:0] key_n,
  output reg [1:0] mode, output reg self_test);
    (* ASYNC_REG="TRUE" *) reg [1:0] key_meta, key_sync;
    reg [1:0] stable, previous;
    reg [31:0] count[0:1];
    integer k;
    always @(posedge clk) begin
        if(rst) begin
            key_meta<=2'b11; key_sync<=2'b11;
            stable<=2'b11; previous<=2'b11;
            count[0]<=0; count[1]<=0;
            mode<=0; self_test<=0;
        end else begin
            key_meta<=key_n; key_sync<=key_meta; previous<=stable;
            for(k=0;k<2;k=k+1) begin
                if(key_sync[k]==stable[k]) count[k]<=0;
                else if(count[k]==STABLE_CYCLES-1) begin
                    stable[k]<=key_sync[k]; count[k]<=0;
                end else count[k]<=count[k]+1'b1;
            end
            if(previous[0] && !stable[0]) mode<=mode==2 ? 0 : mode+1'b1;
            if(previous[1] && !stable[1]) self_test<=!self_test;
        end
    end
`ifndef SYNTHESIS
    initial if(STABLE_CYCLES<1) $fatal(1,"Invalid key debounce interval");
`endif
endmodule
`default_nettype wire
