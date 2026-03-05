`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: suminY9
// 
// Create Date: 2026/03/05 14:37:08
// Design Name: RISC-V
// Module Name: tb_dedicated_cpu
// Project Name: 20260305_dedicated_cpu
// Target Devices: Basys3
// Tool Versions: Vivado 2020.2
// Description: 
// 
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module tb_dedicated_cpu();

    logic clk, rst;
    logic [7:0] out;

    dedicated_cpu0 dut(
        .clk(clk),
        .rst(rst),
        .out(out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        #20;
        rst = 0;
        #400;
        $stop;
    end
endmodule
