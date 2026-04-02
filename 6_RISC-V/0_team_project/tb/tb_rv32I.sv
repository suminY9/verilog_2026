`timescale 1ns / 1ps

module tb_rv32I ();

    logic clk, rst;
    logic [7:0] GPI;      // 8 → 16
    wire  [7:0] GPO;      // 8 → 16
    wire  [15:0] GPIO;
    wire  [ 3:0] fnd_digit;
    wire  [ 7:0] fnd_data;

    logic [7:0] sw_in;
    assign GPIO[7:0]  = sw_in;
    assign GPIO[15:8] = 8'bz;

    rv32I_mcu dut (
        .clk      (clk),
        .rst      (rst),
        .GPI      (GPI),
        .GPO      (GPO),
        .GPIO     (GPIO),
        .fnd_digit(fnd_digit),
        .fnd_data (fnd_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        rst   = 1;
        GPI   = 16'h0000;  // 8 → 16
        sw_in = 8'h00;

        @(negedge clk);
        @(negedge clk);
        rst = 0;

        repeat (500000) @(negedge clk);
        $stop;
    end
endmodule


