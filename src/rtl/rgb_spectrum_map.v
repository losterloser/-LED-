`timescale 1ns/1ps
`default_nettype none
// The spectrum already has fast attack / slow decay in spectrum_bands.
// No artificial animation is added to the music mode.
module rgb_spectrum_map #(
    parameter MAX_BRIGHTNESS=32,
    parameter LEVEL_SHIFT=3
)(input wire [159:0] levels, output reg [383:0] colors);
    integer i;
    reg [9:0] height, scaled;
    reg [7:0] bright, r, g, b;
    always @* begin
        colors=0; height=0; scaled=0; bright=0; r=0; g=0; b=0;
        for(i=0;i<16;i=i+1) begin
            height=levels[i*10 +: 10];
            if(height>420) height=420;
            scaled=height>>LEVEL_SHIFT;
            bright=scaled>MAX_BRIGHTNESS ? MAX_BRIGHTNESS : scaled[7:0];
            r=0; g=0; b=0;
            case(i)
                 0: begin r=bright; end
                 1: begin r=bright; g=bright>>2; end
                 2: begin r=bright; g=bright>>1; end
                 3: begin r=bright; g=bright; end
                 4: begin r=bright>>1; g=bright; end
                 5: begin g=bright; end
                 6: begin g=bright; b=bright>>1; end
                 7: begin g=bright; b=bright; end
                 8: begin g=bright>>1; b=bright; end
                 9: begin b=bright; end
                10: begin r=bright>>2; b=bright; end
                11: begin r=bright>>1; b=bright; end
                12: begin r=bright; b=bright; end
                13: begin r=bright; b=bright>>1; end
                14: begin r=bright; b=bright>>2; end
                15: begin r=bright; g=bright; b=bright; end
            endcase
            colors[(15-i)*24 +: 24]={g,r,b};
        end
    end
endmodule
`default_nettype wire
