`timescale 1ns/1ps
`default_nettype none
module spectrum_renderer(input wire [9:0] x,y,input wire [159:0] levels,
    input wire [1:0] mode,input wire self_test,ready,error,
    output reg [23:0] pixel);
    wire [3:0] band=x[9:6];
    wire [9:0] raw_level=levels[band*10 +:10];
    wire [9:0] level=raw_level>420 ? 10'd420 : raw_level;
    wire [11:0] tripled={2'b0,level}+({2'b0,level}<<1);
    wire [9:0] height=tripled[11:2];
    reg [7:0] character;
    reg [2:0] glyph_row,glyph_col;
    reg text_area;
    reg [23:0] text_color;
    wire [4:0] glyph;
    reg [8*64-1:0] text_line;
    reg [5:0] column;
    reg [31:0] frequency;
    reg [23:0] bar_color;
    font5x7 u_font(character,glyph_row,glyph);
    always @* begin
        case(band)
             0:begin bar_color=24'hff0000;frequency="47  ";end
             1:begin bar_color=24'hff4000;frequency="94  ";end
             2:begin bar_color=24'hff8000;frequency="141 ";end
             3:begin bar_color=24'hffff00;frequency="211 ";end
             4:begin bar_color=24'h80ff00;frequency="305 ";end
             5:begin bar_color=24'h00ff00;frequency="422 ";end
             6:begin bar_color=24'h00ff80;frequency="586 ";end
             7:begin bar_color=24'h00ffff;frequency="750 ";end
             8:begin bar_color=24'h0080ff;frequency="1K2 ";end
             9:begin bar_color=24'h0000ff;frequency="1K7 ";end
            10:begin bar_color=24'h4000ff;frequency="2K4 ";end
            11:begin bar_color=24'h8000ff;frequency="3K4 ";end
            12:begin bar_color=24'hff00ff;frequency="4K9 ";end
            13:begin bar_color=24'hff0080;frequency="7K  ";end
            14:begin bar_color=24'hff0040;frequency="10K ";end
            15:begin bar_color=24'hffffff;frequency="16K ";end
        endcase
    end
    always @* begin
        pixel=y<80 ? 24'h101d32 : 24'h070e1b;
        if(y==78) pixel=24'h25b9d0;
        if(y>=200 && y<=520) begin
            pixel=24'h0c1526;
            if(x[5:0]==0 || y==205 || y==310 || y==415 || y==520) pixel=24'h24344a;
            if(x[5:0]>=10 && x[5:0]<54 && y<520 && height!=0 && y>=520-height)
                pixel=bar_color;
            if(self_test && y>=200 && y<520) begin
                case(x[9:7])
                    0:pixel=24'hffffff;1:pixel=24'hffff00;2:pixel=24'h00ffff;3:pixel=24'h00ff00;
                    4:pixel=24'hff00ff;5:pixel=24'hff0000;6:pixel=24'h0000ff;7:pixel=24'h000000;
                endcase
            end
        end
        character=" ";glyph_row=0;glyph_col=0;text_area=0;text_color=24'hdbeaf9;
        text_line={64{8'h20}};column=0;
        if(y>=16 && y<44 && x>=32 && x<544) begin
            text_area=1;column=(x-32)>>5;
            text_line[511 -:128]=self_test ? "DISPLAY TEST    " : "AUDIO SPECTRUM  ";
            glyph_row=(y-16)>>2;glyph_col=((x-32)&31)>>2;text_color=24'h73e3ef;
            character=text_line[511-column*8 -:8];
        end else if(y>=58 && y<72 && x>=32 && x<992) begin
            text_area=1;column=(x-32)>>4;
            text_line[511 -:272]="1024 FFT / 48 KHZ / 16 BANDS      ";
            glyph_row=(y-58)>>1;glyph_col=((x-32)&15)>>1;
            character=text_line[511-column*8 -:8];
        end else if(y>=104 && y<118 && x>=32 && x<672) begin
            text_area=1;column=(x-32)>>4;
            case(mode)
                0:text_line[511 -:192]="INPUT: ROM TEST TONE    ";
                1:text_line[511 -:192]="INPUT: BOARD MICROPHONE ";
                default:text_line[511 -:192]="INPUT: LINE IN          ";
            endcase
            glyph_row=(y-104)>>1;glyph_col=((x-32)&15)>>1;
            character=text_line[511-column*8 -:8];
        end else if(y>=104 && y<118 && x>=736 && x<992) begin
            text_area=1;column=(x-736)>>4;
            if(error) begin text_line[511 -:128]="ERROR           ";text_color=24'hff6464;end
            else if(ready) begin text_line[511 -:128]="READY           ";text_color=24'h5cf0a2;end
            else begin text_line[511 -:128]="WAIT AUDIO      ";text_color=24'hffcc66;end
            glyph_row=(y-104)>>1;glyph_col=((x-736)&15)>>1;
            character=text_line[511-column*8 -:8];
        end else if(y>=156 && y<170 && x>=32 && x<992) begin
            text_area=1;column=(x-32)>>4;
            text_line[511 -:336]="LEVEL: APPROXIMATE MAGNITUDE / AUTO DECAY ";
            glyph_row=(y-156)>>1;glyph_col=((x-32)&15)>>1;
            character=text_line[511-column*8 -:8];
        end else if(y>=530 && y<544) begin
            text_area=1;glyph_row=(y-530)>>1;glyph_col=x[3:1];
            case(x[5:4])
                0:character="B";
                1:character=band<9 ? "0" : "1";
                2:character=band<9 ? 8'd49+band : 8'd39+band;
                3:character=" ";
            endcase
        end else if(y>=550 && y<564) begin
            text_area=1;glyph_row=(y-550)>>1;glyph_col=x[3:1];
            character=frequency[31-x[5:4]*8 -:8];
        end else if(y>=580 && y<594 && x>=32 && x<992) begin
            text_area=1;column=(x-32)>>4;
            text_line[511 -:480]="KEY0: ROM/MIC/LINE   KEY1: SCREEN+RING TEST   RESET: ROM    ";
            glyph_row=(y-580)>>1;glyph_col=((x-32)&15)>>1;
            character=text_line[511-column*8 -:8];
        end
        if(text_area && glyph_col<5 && glyph_row<7 && glyph[4-glyph_col]) pixel=text_color;
    end
endmodule
`default_nettype wire
