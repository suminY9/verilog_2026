`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: suminY9
// 
// Create Date: 2026/03/06 18:39:08
// Design Name: RISC-V
// Module Name: tb_dedicated_cpu2
// Project Name: 20260306_dedicated_cpu2
// Target Devices: Basys3
// Tool Versions: Vivado 2020.2
// Description: 
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module tb_dedicated_cpu2 ();
    logic       clk;
    logic       rst;
    logic [7:0] out;

    dedicated_cpu2 dut (
        .clk(clk),
        .rst(rst),
        .out(out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        @(posedge clk);
        @(negedge clk);
        rst = 0;
        repeat(500)
        @(posedge clk);
        $stop;
    end
endmodule
