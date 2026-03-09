`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/06 16:24:38
// Design Name: 
// Module Name: instruction_mem
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


module instruction_mem(
    input [31:0] instr_addr,
    output [31:0] instr_data
    );

    logic [31:0] rom[0:31];

    initial begin   // for simulation. sysnthesis x
        rom[0] = 32'h004182b3;
        rom[1] = 32'h005201b3; //나머지 메모리 공간은 모두 x로 채워짐
    end

    assign instr_data = rom[instr_addr[31:2]]; // word adressing

endmodule
