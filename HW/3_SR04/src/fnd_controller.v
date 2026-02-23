`timescale 1ns / 1ps

module fnd_controller (
    input         clk,
    input         reset,
    input  [11:0] fnd_in_data,
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data
);

    // counter
    wire [1:0] w_digit_sel;
    wire w_1khz;
    // digit splitter
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000;
    // dot comparision
    wire w_dot_onoff;
    // MUX
    wire [3:0] w_mux_out;

    clk_div U_CLK_DIV (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    // counter 4
    counter_4 U_COUNTER_4 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    // decoder
    decoder_2x4 U_DECODER_2x4 (
        .digit_sel  (w_digit_sel[1:0]),
        .decoder_out(fnd_digit)
    );

    // MUX
    mux_4x1 U_MUX_4X1 (
        .sel(w_digit_sel),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000),
        .mux_out(w_mux_out)
    );

    digit_splitter #(12) U_DIGIT_SPLITTER (
        .in_data(fnd_in_data),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000)
    );

    // BCD
    BCD U_BCD (
        .bcd(w_mux_out),
        .fnd_data(fnd_data)
    );
endmodule

module dot_onoff_comp (
    input [6:0] msec,
    output dot_onoff
);

    // dot_onoff = 0: on / 1: off
    assign dot_onoff = (msec < 50);

endmodule

module mux_2x1 (
    input sel,
    input [3:0] i_sel0,
    input [3:0] i_sel1,
    output [3:0] o_mux
);

    assign o_mux = (sel) ? i_sel1 : i_sel0;

endmodule

module clk_div (
    input clk,
    input reset,
    output reg o_1khz
);

    reg [$clog2(100_000):0] counter_r;  // $clog2: 자동으로 2진수를 계산해줌

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;     // 출력하지 않고 무조건 X를 푶시
            o_1khz <= 1'b0;
        end else begin
            if (counter_r == 49_999) begin      // 최댓값을 찍으면 0으로 돌아오도록 명시해줘야 함
                counter_r <= 0;
                o_1khz <= ~o_1khz;
            end else begin
                counter_r <= counter_r + 1;
                //o_1khz <= 1;
            end
        end
    end
endmodule

module counter_4 (
    input clk,
    input reset,
    output [1:0] digit_sel
);

    reg [2:0] counter_r;  // 0~8 값을 유지해야 하기 때문에 reg type

    assign digit_sel = counter_r;   // 선언보다 assign이 뒤에 와야 함에 주의

    // 순차논리회로 -> 항상 always문 사용
    // posedge clk or posedge reset 과 같은 뜻 (콤마(,) = or)
    // 하나의 모듈 안에서는 posedge, negedge 둘 중 하나로 통일. edge를 둘 다 쓰기보다는 주파수를 2배 높이면 됨.
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            // init counter_r
            counter_r <= 0;     // 순차 논리일 때에는 '<=' 사용(non-blocking 연산)
        end else begin
            // to do
            counter_r <= counter_r + 1;     // counter_r이 2-bit이므로 3 다음에 4가 되지 않고 0이 됨. overflow carry는 버려짐.
        end
    end
endmodule

module decoder_2x4 (
    input [1:0] digit_sel,
    output reg [3:0] decoder_out
);

    always @(digit_sel) begin
        case (digit_sel)
            2'b00: decoder_out = 4'b1110;
            2'b01: decoder_out = 4'b1101;
            2'b10: decoder_out = 4'b1011;
            2'b11: decoder_out = 4'b0111;
        endcase
    end
endmodule

module mux_4x1 (
    input      [1:0] sel,
    input      [3:0] digit_1,
    input      [3:0] digit_10,
    input      [3:0] digit_100,
    input      [3:0] digit_1000,
    output reg [3:0] mux_out
);

    always @(*) begin
        case (sel)
            3'b00: mux_out = digit_1;
            3'b01: mux_out = digit_10;
            3'b10: mux_out = digit_100;
            3'b11: mux_out = digit_1000;
        endcase
    end
endmodule

module digit_splitter #(
    parameter BIT_WIDTH = 12
) (
    input [BIT_WIDTH-1:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);

    assign digit_1  = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;
    assign digit_100 = (in_data / 100) % 10;
    assign digit_1000 = (in_data / 1000) % 10;

endmodule

module BCD (
    input [3:0] bcd,
    output reg [7:0] fnd_data
);

    always @(bcd) begin
        case (bcd)
            4'd0: fnd_data = 8'hC0;
            4'd1: fnd_data = 8'hf9;
            4'd2: fnd_data = 8'ha4;
            4'd3: fnd_data = 8'hb0;
            4'd4: fnd_data = 8'h99;
            4'd5: fnd_data = 8'h92;
            4'd6: fnd_data = 8'h82;
            4'd7: fnd_data = 8'hf8;
            4'd8: fnd_data = 8'h80;
            4'd9: fnd_data = 8'h90;
            4'd10: fnd_data = 8'hff;
            4'd11: fnd_data = 8'hff;
            4'd12: fnd_data = 8'hff;
            4'd13: fnd_data = 8'hff;
            4'd14: fnd_data = 8'h7f;
            4'd15: fnd_data = 8'hff;
            default: fnd_data = 8'hFF;
        endcase
    end

endmodule
