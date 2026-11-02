`timescale 1ns/1ps
// Pin-level ACK model and transaction recorder, never substitutes for RTL.
module i2c_slave_model(input wire rst, input wire ack_enable,
    input integer nack_byte, input integer nack_transaction,
    inout wire scl, sda);
    reg slave_low=0, active=0;
    integer bits=0, byte_no=0, transactions=0, writes=0;
    reg [23:0] packet=0;
    reg [23:0] packets[0:255];
    assign sda=slave_low ? 1'b0 : 1'bz;
    always @(posedge rst) begin
        slave_low=0; active=0; bits=0; byte_no=0;
        transactions=0; writes=0; packet=0;
    end
    always @(negedge sda) if(!rst && scl===1'b1) begin
        active=1; bits=0; byte_no=0; packet=0; transactions=transactions+1;
    end
    always @(posedge sda) if(scl===1'b1) active=0;
    always @(negedge scl) slave_low=!rst && active && bits==8 && ack_enable &&
        !((byte_no-1)==nack_byte && (nack_transaction<0 || transactions==nack_transaction));
    always @(posedge scl) if(!rst && active) begin
        if(bits==8) bits=0;
        else begin
            packet={packet[22:0],sda}; bits=bits+1;
            if(bits==8) begin
                if(byte_no==2) begin
                    packets[writes]=packet; writes=writes+1;
                end
                byte_no=byte_no+1;
            end
        end
    end
endmodule
