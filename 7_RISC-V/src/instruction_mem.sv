`timescale 1ns / 1ps

module instruction_mem(
    input [31:0] instr_addr,
    output [31:0] instr_data
    );

    logic [31:0] rom[0:31];

    initial begin   // for simulation. sysnthesis x
        //나머지 메모리 공간은 모두 x로 채워짐
        // R-type
        rom[0] = 32'h004182b3;
        rom[1] = 32'h405201b3;
        rom[2] = 32'h002092b3;
        rom[3] = 32'h0011a2b3;
        rom[4] = 32'h0030a2b3;
        rom[5] = 32'h0011b2b3;
        rom[6] = 32'h0030b2b3;
        rom[7] = 32'h00aa32b3;
        rom[8] = 32'h0011d2b3;
        rom[9] = 32'h4011d2b3;
        rom[10] = 32'h00ab62b3;
        rom[11] = 32'h00ab72b3;
        // S-type
        rom[12] = 32'h003083a3;
        rom[13] = 32'h00308423;
        rom[14] = 32'h00310423;
        rom[15] = 32'h003104a3;
        rom[16] = 32'h00309623;
        rom[17] = 32'h003116a3;
        rom[18] = 32'h00322723;
    end

    assign instr_data = rom[instr_addr[31:2]]; // word adressing

endmodule