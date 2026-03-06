`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/06 10:59:33
// Design Name: 
// Module Name: tb_dedicated_cpu1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_dedicated_cpu1();

    logic clk, rst;
    logic [7:0] out;

    dedicated_cpu1 dut(
        .clk(clk),
        .rst(rst),
        .out(out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        repeat(50)
        @(posedge clk);
        $stop;
    end
endmodule
