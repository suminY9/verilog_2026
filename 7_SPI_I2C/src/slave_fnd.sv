`timescale 1ns / 1ps

module slave_FND (
    input  logic       clk,
    input  logic       reset,
    input  logic       SCLK,
    input  logic       MOSI,
    input  logic       MISO,
    input  logic       SS,
    // internal signal
    output logic [7:0] fnd_data,
    output logic [3:0] fnd_digit
);

    logic i_done;
    logic [7:0] i_data;

    spi_slave U_SPI_SLAVE (
        .clk(clk),
        .reset(reset),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .MISO(MISO),
        .SS(SS),
        .i_done(i_done),
        .i_data(i_data)
    );
    control_unit U_CONTROL_UNIT (
        .clk(clk),
        .reset(reset),
        .done(i_done),
        .data(i_data),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );
endmodule

module control_unit (
    input  logic       clk,
    input  logic       reset,
    input  logic       done,
    input  logic [7:0] data,
    output logic [3:0] fnd_digit,
    output logic [7:0] fnd_data
);

    // synchronizer
    logic done_sync0, done_sync1;
    logic done_pose, done_nege;
    // reg
    logic [7:0] fnd_in_data;

    fnd_controller U_FND_CTRL (
        .clk(clk),
        .reset(reset),
        .in_data(fnd_in_data),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    always_ff @(posedge clk, posedge reset) begin
        if(reset) begin
            done_sync0 <= 0;
            done_sync1 <= 0;
        end else begin
            done_sync0 <= done;
            done_sync1 <= done_sync0;
        end
    end
    assign done_pose = done_sync0 & ~done_sync1;
    assign done_nege = ~done_sync0 & done_sync1;

    always_ff @(posedge clk, posedge reset) begin
        if(reset) begin
            fnd_in_data <= 0;
        end else begin
            if(done_pose) begin
                fnd_in_data <= data;
            end 
        end
    end
endmodule

module fnd_controller (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] in_data,
    output logic [3:0] fnd_digit,
    output logic [7:0] fnd_data
);
    //counter
    logic [2:0] digit_sel;
    logic w_1khz;
    // digit splitter
    logic [3:0] digit_1, digit_10;
    //mux
    logic [3:0] mux_out;

    clk_div U_CLK_DIV (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );
    counter_8 U_COUNTER_8 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(digit_sel)
    );
    decoder_2x4 U_DECODER_2x4 (
        .digit_sel  (digit_sel),
        .decoder_out(fnd_digit)
    );
    digit_splitter #(
        .BIT_WIDTH(8)
    ) U_FIRST_DS (
        .in_data (in_data),
        .digit_1 (digit_1),
        .digit_10(digit_10)
    );
    mux_8x1 U_MUX_DISPLAY (
        .sel(digit_sel),
        .digit_1(digit_1),
        .digit_10(digit_10),
        .digit_100(4'hf),
        .digit_1000(4'hf),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100(4'hf),
        .digit_dot_1000(4'hf),
        .mux_out(mux_out)
    );
    BCD U_BCD (
        .bcd(mux_out),
        .fnd_data(fnd_data)
    );
endmodule

module clk_div (
    input  logic clk,
    input  logic reset,
    output logic o_1khz
);
    reg [$clog2(100_000):0] counter_r;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;
            o_1khz    <= 1'b0;
        end else begin
            if (counter_r == 99_999) begin
                counter_r <= 0;
                o_1khz    <= 1'b1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz    <= 1'b0;
            end
        end
    end
endmodule

module counter_8 (
    input logic clk,
    input logic reset,
    output logic [2:0] digit_sel
);
    logic [2:0] counter_r;
    assign digit_sel = counter_r;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;
        end else begin
            counter_r <= counter_r + 1;
        end
    end
endmodule

module decoder_2x4 (
    input  logic [1:0] digit_sel,
    output logic [3:0] decoder_out
);
    always @digit_sel begin
        case (digit_sel)
            2'b00: decoder_out = 4'b1110;
            2'b01: decoder_out = 4'b1101;
            2'b10: decoder_out = 4'b1011;
            2'b11: decoder_out = 4'b0111;
        endcase
    end
endmodule

module mux_8x1 (
    input  logic [2:0] sel,
    input  logic [3:0] digit_1,
    input  logic [3:0] digit_10,
    input  logic [3:0] digit_100,
    input  logic [3:0] digit_1000,
    input  logic [3:0] digit_dot_1,
    input  logic [3:0] digit_dot_10,
    input  logic [3:0] digit_dot_100,
    input  logic [3:0] digit_dot_1000,
    output logic [3:0] mux_out
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
    parameter BIT_WIDTH = 8
) (
    input  logic [BIT_WIDTH - 1:0] in_data,
    output logic [            3:0] digit_1,
    output logic [            3:0] digit_10
);

    assign digit_1  = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;
endmodule

module BCD (
    input  logic [3:0] bcd,
    output logic [7:0] fnd_data
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
            4'd10: fnd_data = 8'h88;
            4'd11: fnd_data = 8'h83;
            4'd12: fnd_data = 8'hc6;
            4'd13: fnd_data = 8'ha1;
            4'd14: fnd_data = 8'h86;
            4'd15: fnd_data = 8'h8e;
            default: fnd_data = 8'hFF;
        endcase
    end

endmodule
