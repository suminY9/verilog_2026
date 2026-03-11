`timescale 1ns / 1ps
`include "define.vh"

module rv32i_datapath (
    input         clk,
    input         rst,
    input         rf_we,
    input         alu_src,
    input         rf_wd_src,
    input  [ 3:0] alu_control,
    input  [31:0] instr_data,
    input  [31:0] drdata,
    output [31:0] instr_addr,
    output [31:0] daddr,
    output [31:0] dwdata
);

    logic [31:0] rd1, rd2, alu_result, imm_data, alurs2_data, ram2regfile;

    assign daddr = alu_result;
    assign dwdata = rd2;

    program_counter U_PC (
        .clk(clk),
        .rst(rst),
        .program_counter(instr_addr)
    );
    register_file U_REG_FILE (
        .clk(clk),
        .rst(rst),
        .RA1(instr_data[19:15]),
        .RA2(instr_data[24:20]),
        .WA(instr_data[11:7]),
        .wdata(alu_result),
        .rf_we(rf_we),
        .RD1(rd1),
        .RD2(rd2)
    );
    imm_extender U_IMM_EXTENDER (
        .instr_data(instr_data),
        .imm_data(imm_data)
    );
    mux_2x1 U_MUX_ALUSRC_RS2 (
        .in0(rd2),
        .in1(imm_data),
        .sel(alu_src),
        .out_mux(alurs2_data)
    );
    alu U_ALU (
        .rd1(rd1),
        .rd2(alurs2_data),
        .alu_control(alu_control),
        .alu_result(alu_result)
    );
    mux_2x1 U_MUX_WB_REGFILE (
        .in0(alu_result),
        .in1(drdata),
        .sel(rf_wd_src),
        .out_mux(ram2regfile)
    );
endmodule


/*****************SUB_MODULE*****************/
module mux_2x1 (
    input        [31:0] in0, // sel 0
    input        [31:0] in1, // sel 1
    input               sel,
    output logic [31:0] out_mux
);
    assign out_mux = (sel) ? in1 : in0;
endmodule


module imm_extender (
    input        [31:0] instr_data,
    output logic [31:0] imm_data
);

    always_comb begin
        imm_data = 32'd0;
        
        case(instr_data[6:0])   // opcode
            `S_TYPE: begin
                imm_data = {{20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]}; // instr_data[31]를 20회 반복
            end
            `IL_TYPE, `I_TYPE: begin // load
                imm_data = {{20{instr_data[31]}}, instr_data[31:20]};
            end
        endcase 
    end
endmodule


module register_file (
    input         clk,
    input         rst,
    input  [ 4:0] RA1,
    input  [ 4:0] RA2,
    input  [ 4:0] WA,
    input  [31:0] wdata,
    input         rf_we,
    output [31:0] RD1,
    output [31:0] RD2
);

    logic [31:0] register_file[1:31]; // x0 must have zero value

`ifdef SIMULATION
    initial begin
        for (int i = 1; i < 32; i++) begin
            register_file[i] = i;
        end
    end
`endif

    always_ff @(posedge clk) begin
        if (!rst & rf_we) begin
            register_file[WA] <= wdata;
        end
    end

    // output CL
    assign RD1 = (RA1!=0) ? register_file[RA1] : 0;
    assign RD2 = (RA1!=0) ? register_file[RA2] : 0;
endmodule


module alu (
    input        [31:0] rd1,          // RS1
    input        [31:0] rd2,          // RS2
    input        [ 3:0] alu_control,  // func7[5], funct3 : 4-bit
    output logic [31:0] alu_result
);

    always_comb begin
        alu_result = 0;
        
        case (alu_control)
            `ADD:  alu_result = rd1 + rd2;  // add RD = RS1 + RS2
            `SUB:  alu_result = rd1 - rd2;  // sub rd = rs1 - rs2
            `SLL:  alu_result = rd1 << rd2[4:0];     // sll rd = rs1 << rs2 // shift max 5-bit
            `SLT:  alu_result = ($signed(rd1) < $signed(rd2)) ? 1 : 0;  // slt rd = (rs1 < rs2) ? 1 : 0
            `SLTU: alu_result = (rd1 < rd2) ? 1 : 0;  // sltu rd = (rs1 < rs2) ? 1 : 0
            `XOR:  alu_result = rd1 ^ rd2;  // xor rd = rs1 ^ rs2
            `SRL:  alu_result = rd1 >> rd2[4:0];  // srl rd = rs1 >> rs2
            `SRA:  alu_result = $signed(rd1) >>> rd2[4:0];  // sra rd = rs1 >> rs2, msb extention
            `OR:   alu_result = rd1 | rd2;  // or rd = rs1 | rs2
            `AND:  alu_result = rd1 & rd2;  // and rd = rs1 & rs2
        endcase
        end
endmodule


module program_counter (
    input         clk,
    input         rst,
    output [31:0] program_counter
);

    logic [31:0] pc_alu_out;

    pc_alu U_PC_ALU_4 (
        .a(32'd4),
        .b(program_counter),
        .pc_alu_out(pc_alu_out)
    );
    register U_PC_REG (
        .clk(clk),
        .rst(rst),
        .data_in(pc_alu_out),
        .data_out(program_counter)
    );
endmodule


module pc_alu (
    input  [31:0] a,
    input  [31:0] b,
    output [31:0] pc_alu_out
);
    assign pc_alu_out = a + b;
endmodule


module register (
    input         clk,
    input         rst,
    input  [31:0] data_in,
    output [31:0] data_out
);

    logic [31:0] register;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            register <= 0;
        end else begin
            register <= data_in;
        end
    end

    assign data_out = register;
endmodule
