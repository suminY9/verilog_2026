`timescale 1ns / 1ps

module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);

    // clock divider for debounce shift register
    // 100Mhz -> 100Khz
    // count 1000
    parameter CLK_DIV = 100_000;  // 100K
    parameter F_COUNT = 100_000_000 / CLK_DIV;  // 1000
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    reg clk_100khz_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_100khz_reg <= 0;
        end else begin
            counter_reg <= counter_reg + 1'b1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                clk_100khz_reg <= 1'b1;
            end else begin
                clk_100khz_reg <= 1'b0;
            end
        end
    end

    // series 8 tab F/F (8bit Shift Register)
    reg [7:0] debounce_reg;
    wire w_debounce;

    // SL
    always @(posedge clk_100khz_reg, posedge reset) begin
        if (reset) begin
            debounce_reg <= 0;
        end else begin
            // Sequential In
            // Bit Shift
            debounce_reg <= {i_btn, debounce_reg[7:1]};
        end
    end

    // debounce, 8 input AND
    assign w_debounce = &debounce_reg;

    reg edge_reg;
    // edge detection
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            edge_reg <= 0;
        end else begin
            edge_reg <= w_debounce;
        end
    end
    assign o_btn = w_debounce & (~edge_reg);

endmodule
