`timescale 1ns / 1ps
`include "define.vh"

module rv32i_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    output [31:0] instr_addr,
    output        dwe,
    output [31:0] dwaddr,
    output [31:0] dwdata
);

    logic rf_we, alu_src;
    logic [3:0] alu_control;

    control_unit U_CONTROL_UNIT (
        .funct7(instr_data[31:25]),
        .funct3(instr_data[14:12]),
        .opcode(instr_data[6:0]),
        .rf_we(rf_we),
        .alu_src(alu_src),
        .alu_control(alu_control),
        .dwe(dwe)
    );
    rv32i_datapath U_DATAPATH (
        .clk(clk),
        .rst(rst),
        .rf_we(rf_we),
        .alu_src(alu_src),
        .alu_control(alu_control),
        .instr_data(instr_data),
        .instr_addr(instr_addr),
        .dwaddr(dwaddr),
        .dwdata(dwdata)
    );
endmodule


module control_unit (
    input        [ 6:0] funct7,
    input        [ 2:0] funct3,
    input        [ 6:0] opcode,
    output logic        rf_we,
    output logic        alu_src,
    output logic [ 3:0] alu_control,
    output logic        dwe
);

    always_comb begin
        rf_we       = 1'b0;
        alu_src     = 1'b0;
        alu_control = 4'b0_000;  //initialize
        dwe         = 1'b0;

        case (opcode)
            `R_TYPE: begin
                rf_we       = 1'b1;
                alu_src     = 1'b0;
                alu_control = {funct7[5], funct3};
                dwe         = 1'b0;
            end
            `S_TYPE: begin
                rf_we       = 1'b0;
                alu_src     = 1'b1;
                alu_control = {1'b0, funct3};
                dwe         = 1'b1;
            end
        endcase
    end
endmodule


//module imm_extender (
//    input         clk,
//    input         rst,
//    input  [11:0] imm_in,
//    output [31:0] imm_out
//);
//
//    always_ff @(posedge clk, posedge rst) begin
//        if(rst) begin
//            
//        end else begin
//            if(imm_in[0]) begin
//                imm_out <= {20'b0, imm_in};
//            end else begin
//                imm_out <= {20'b1, imm_in};
//            end
//        end
//    end
//
//endmodule
