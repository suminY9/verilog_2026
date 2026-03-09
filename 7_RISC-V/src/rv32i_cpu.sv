`timescale 1ns / 1ps
`include "define.vh"

module rv32i_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    output [31:0] instr_addr
);

    logic rf_we;
    logic [3:0] alu_control;

    control_unit U_CONTROL_UNIT (
        .funct7(instr_data[31:25]),
        .funct3(instr_data[14:12]),
        .opcode(instr_data[6:0]),
        .rf_we(rf_we),
        .alu_control(alu_control)
    );
    rv32i_datapath U_DATAPATH (
        .clk(clk),
        .rst(rst),
        .rf_we(rf_we),
        .alu_control(alu_control),
        .instr_data(instr_data),
        .instr_addr(instr_addr)
    );
endmodule


module control_unit (
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    output logic       rf_we,
    output logic [3:0] alu_control
);

    always_comb begin
        rf_we       = 1'b0;
        alu_control = 4'b0_000;  //initialize

        case (opcode)
            `R_TYPE: begin
                rf_we = 1'b1;
                alu_control = {funct7[5], funct3};
            end
        endcase
    end
endmodule
