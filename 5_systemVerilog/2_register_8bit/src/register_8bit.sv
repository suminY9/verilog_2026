`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Engineer: suminY9
// Create Date: 2026/02/25 14:10:28
// Design Name: 8-bit Register
// Module Name: register_8bit
// Project Name: 20260225_register_8bit
// Target Devices: Basys3
// Tool Versions: Vivado 2020.2
// Description: systemVerilog
// 
// Dependencies: 
// 
// Revision:
// Revision 1.01 - add write enable
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////


module register_8bit (
    input              clk,
    input              rst,
    input  logic       we,
    input  logic [7:0] wdata,
    output logic [7:0] rdata
);

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            rdata <= 8'b0;
        end else begin
            if(we)
                rdata <= wdata;
        end
    end

endmodule
