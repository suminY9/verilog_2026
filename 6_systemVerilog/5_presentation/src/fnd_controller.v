`timescale 1ns / 1ps

module fnd_controller (
    input clk,
    input reset,
    input send_start,
    input sel_display,
    input [23:0] fnd_in_data,
    output [3:0] fnd_digit,
    output [7:0]  fnd_data,   // 여기서 fnd_data는 연결만하고 값을 저장하지 않는다. wire.
    output [31:0] sender_data
);
    wire [3:0] w_digit_msec_1, w_digit_msec_10;
    wire [3:0] w_digit_sec_1, w_digit_sec_10;
    wire [3:0] w_digit_min_1, w_digit_min_10;
    wire [3:0] w_digit_hour_1, w_digit_hour_10;
    wire [3:0] w_mux_hour_min_out, w_mux_sec_msec_out;
    wire [3:0] w_mux_2x1_out;
    wire [2:0] w_digit_sel;
    wire w_1khz;
    wire w_dot_onoff;

    // hour
    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_HOUR_DS (
        .in_data (fnd_in_data[23:19]),
        .digit_1 (w_digit_hour_1),
        .digit_10(w_digit_hour_10)
    );
    // min
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_MIN_DS (
        .in_data(fnd_in_data[18:13]),
        .digit_1(w_digit_min_1),  // 분 일의 자리
        .digit_10(w_digit_min_10)  // 분 십의 자리
    );
    // sec
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_SEC_DS (
        .in_data (fnd_in_data[12:7]),
        .digit_1 (w_digit_sec_1),
        .digit_10(w_digit_sec_10)
    );
    // msec
    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_MSEC_DS (
        .in_data (fnd_in_data[6:0]),
        .digit_1 (w_digit_msec_1),
        .digit_10(w_digit_msec_10)
    );

    dot_onoff_comp U_DOT_COMP (
        .msec(fnd_in_data[6:0]),
        .dot_onoff(w_dot_onoff)
    );


    mux_8x1 U_Mux_HOUR_MIN (
        .sel(w_digit_sel),
        .digit_1(w_digit_min_1),
        .digit_10(w_digit_min_10),
        .digit_100(w_digit_hour_1),
        .digit_1000(w_digit_hour_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_hour_min_out)
    );

    mux_8x1 U_Mux_SEC_MSEC (
        .sel(w_digit_sel),
        .digit_1(w_digit_msec_1),
        .digit_10(w_digit_msec_10),
        .digit_100(w_digit_sec_1),
        .digit_1000(w_digit_sec_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_sec_msec_out)
    );

    mux_2x1 U_MUX_2x1 (
        .sel(sel_display),
        .i_sel0(w_mux_sec_msec_out),
        .i_sel1(w_mux_hour_min_out),
        .o_mux(w_mux_2x1_out)
    );

    clk_div U_CLK_DIV (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    counter_8 U_COUNTER_8 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    decoder_2x4 U_DECODER_2x4 (
        .digit_sel(w_digit_sel[1:0]),
        .fnd_digit(fnd_digit)
    );

    bcd U_BCD (
        .bcd(w_mux_2x1_out),  // 8bit 중 하위 4bit만 사용.
        .fnd_data(fnd_data)
    );

    digit_out_for_ASCiiSender U_DIGIT_OUT (
        .send_start(send_start),
        .module_sel(2'b00),  //swtich control -> 00: watch, 01: SR04, 10: DHT11
        .watch_digit({
            w_digit_hour_10,
            w_digit_hour_1,
            w_digit_min_10,
            w_digit_min_1,
            w_digit_sec_10,
            w_digit_sec_1,
            w_digit_msec_10,
            w_digit_msec_1
        }),
        .SR04_digit(),
        .DHT11_digit(),
        .out_digit(sender_data)
    );

endmodule

module digit_out_for_ASCiiSender (
    input             send_start,
    input      [ 1:0] module_sel,
    input      [31:0] watch_digit,
    input      [31:0] SR04_digit,
    input      [31:0] DHT11_digit,
    output reg [31:0] out_digit
);

    always @(*) begin
        if(send_start) begin
            case (module_sel)
                // watch
                2'b00: out_digit = watch_digit;
                // SR04
                2'b01: out_digit = {16'b0, SR04_digit};
                //DHT11
                2'b10: out_digit = DHT11_digit;
            endcase
        end
    end
endmodule

module dot_onoff_comp (
    input [6:0] msec,
    output dot_onoff
);

    assign dot_onoff = (msec < 50); //msec 값이 50보다 작을 때만 dot_onoff가 1이다.

endmodule


module mux_2x1 (
    input        sel,
    input  [3:0] i_sel0,
    input  [3:0] i_sel1,
    output [3:0] o_mux
);
    // sel = 1 : i_sel1, sel = 0: i_sel0
    assign o_mux = (sel) ? i_sel1 : i_sel0;

endmodule


module clk_div (
    input clk,
    input reset,
    output reg o_1khz
);
    reg [$clog2(
100_000
):0] counter_r;  //counter 모듈의 counter_r과 다른거다. 모듈이 다르니까.

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;
            o_1khz <= 1'b0;
        end else begin
            if (counter_r == 99_999) begin
                counter_r <= 0;
                o_1khz <= 1'b1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz <= 1'b0;
            end
        end
    end
endmodule


module counter_8 (
    input clk,
    input reset,
    output [2:0] digit_sel
);
    reg [2:0] counter_r;

    assign digit_sel = counter_r;   // reg 뒤에 assign이 오는게 좋다. 안그러면 문법오류 생길 수 있음.

    always @(posedge clk, posedge reset) begin
        if (reset == 1) begin       // reset == 1 말고 reset이라고만 써도 같은 동작 함.
            // init counter_r
            counter_r <= 0;  // reset이 1이면 0으로 초기화 해라.
        end else begin
            // to do
            counter_r <= counter_r + 1;
        end
    end

endmodule


module decoder_2x4 (
    input      [1:0] digit_sel,
    output reg [3:0] fnd_digit
);
    always @digit_sel begin
        case (digit_sel)
            2'b00: fnd_digit = 4'b1110;
            2'b01: fnd_digit = 4'b1101;
            2'b10: fnd_digit = 4'b1011;
            2'b11: fnd_digit = 4'b0111;
        endcase
    end
endmodule



module mux_8x1 (
    input      [2:0] sel,
    input      [3:0] digit_1,
    input      [3:0] digit_10,
    input      [3:0] digit_100,
    input      [3:0] digit_1000,
    input      [3:0] digit_dot_1,
    input      [3:0] digit_dot_10,
    input      [3:0] digit_dot_100,
    input      [3:0] digit_dot_1000,
    output reg [3:0] mux_out
);
    always @(*) begin
        case (sel)
            3'b000: mux_out = digit_1;
            3'b001: mux_out = digit_10;
            3'b010: mux_out = digit_100;
            3'b011: mux_out = digit_1000;
            3'b100: mux_out = digit_dot_1;
            3'b101: mux_out = digit_dot_10;
            3'b110: mux_out = digit_dot_100;
            3'b111: mux_out = digit_dot_1000;
        endcase
    end
endmodule

module digit_splitter #(
    parameter BIT_WIDTH = 7
) (
    input [BIT_WIDTH-1:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10
);

    assign digit_1  = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;

endmodule

module bcd (
    input [3:0] bcd,
    output reg [7:0] fnd_data   // always 블록 안에서 값을 대입받는 신호는 reg 타입이어야 함.
);

    always @(bcd) begin
        case (bcd)
            4'd0: fnd_data = 8'hc0;
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
            default:
            fnd_data = 8'hFF;  // 나머지 경우는 default를 실행.
        endcase
    end

endmodule
