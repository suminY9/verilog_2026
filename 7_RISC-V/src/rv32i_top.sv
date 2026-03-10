`timescale 1ns / 1ps

module rv32i_top(
    input clk,
    input rst
    );

    logic dwe;
    logic [9:0] alu_control;
    logic [31:0] instr_addr, instr_data, dwaddr, dwdata, drdata;

    instruction_mem U_INSTRUCTION_MEM (.*);
    rv32i_cpu U_RV32I (.*);
    data_mem U_DATA_MEM (.*);
endmodule
