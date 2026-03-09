`timescale 1ns / 1ps

module rv32i_top(
    input clk,
    input rst
    );

    logic dwe;
    logic [31:0] instr_addr, instr_data, dwaddr, dwdata, drdata;

    instruction_mem U_INSTRUCTION_MEM (.*);
    rv32i_cpu U_RV32I (.*);
    data_mem U_DATA_MEM (.*,
        .alu_control({1'b0, instr_data[14:12]}));
endmodule
