`timescale 1ns / 1ps

module instruction_mem(
    input [31:0] instr_addr,
    output [31:0] instr_data
    );

    logic [31:0] rom[0:127];

    initial begin   // for simulation. sysnthesis x
        $readmemh("APB_GPO.mem", rom);

        // 정의하지 않은 메모리 공간은 모두 x로 채워짐
        // R-type
        //rom[0] = 32'h004182b3;
        //rom[1] = 32'h405201b3;
        //rom[2] = 32'h002092b3;
        //rom[3] = 32'h0011a2b3;
        //rom[4] = 32'h0030a2b3;
        //rom[5] = 32'h0011b2b3;
        //rom[6] = 32'h0030b2b3;
        //rom[7] = 32'h00c542b3;
        //rom[8] = 32'h0011d2b3;
        //rom[9] = 32'h4011d2b3;
        //rom[10] = 32'h00ab62b3;
        //rom[11] = 32'h00ab72b3;
        //// S-type
        //rom[12] = 32'h003083a3;
        //rom[13] = 32'h00308423;
        //rom[14] = 32'h00310423;
        //rom[15] = 32'h003104a3;
        //rom[16] = 32'h00309623;
        //rom[17] = 32'h003116a3;
        //rom[18] = 32'h00322723;
        // IL-type
        //rom[19] = 32'h00802283; // LW
        //rom[20] = 32'h00d01283; // LH
        //rom[21] = 32'h00a00283; // LB
        //rom[22] = 32'h00804283; // LBU
        //rom[23] = 32'h00805283; // LHU
        // I-type
        //rom[19] = 32'h00118293; // ADDI
        //rom[20] = 32'h0011a293; // SLTI
        //rom[21] = 32'h0011b293; // SLTIU
        //rom[22] = 32'h00c54293; // XORI
        //rom[23] = 32'h00ab6293; // ORI
        //rom[24] = 32'h00ab7293; // ANDI
        //rom[25] = 32'h00219293; // SLLI
        //rom[26] = 32'h0021d293; // SRLI
        //rom[27] = 32'h4021d293; // SRAI
        // B-type
        //rom[0] = 32'h402081b3;
        //rom[1] = 32'h00108463; // BEQ true
        //rom[3] = 32'h00209463; // BNE true
        //rom[5] = 32'h0011c463; // BLT true
        //rom[7] = 32'h0030d463; // BGE true
        //rom[9] = 32'h0030e463; // BLTU true
        //rom[11] = 32'h0011f463; // BGEU true
        //rom[13] = 32'h00208463; // BEQ fail
        //rom[14] = 32'h00109463; // BNE fail
        //rom[15] = 32'h0010c463; // BLT fail
        //rom[16] = 32'h0020d463; // BGE fail
        //rom[17] = 32'h0011e463; // BLTU fail
        //rom[18] = 32'h0030f463; // BGEU fail
        //rom[19] = 32'h000012b7; // LUI
        //rom[20] = 32'h00001297; // AUIPC
        //rom[21] = 32'h008002ef; // JAL
        //rom[23] = 32'h060202e7; // JALR
        //rom[25] = 32'h004182b3;
    end

    assign instr_data = rom[instr_addr[31:2]]; // word adressing

endmodule