`timescale 1ns / 1ps
`include "define.vh"

module rv32i_datapath (
    input         clk,
    input         rst,
    input         rf_we,
    input         alu_src,
    input  [ 1:0] rf_wd_src,
    input         branch,
    input         JAL,
    input         JALR,
    input  [ 3:0] alu_control,
    input  [31:0] instr_data,
    input  [31:0] drdata,
    output [31:0] instr_addr,
    output [31:0] daddr,
    output [31:0] dwdata
);

    logic btaken;
    logic [31:0] rs1, rs2, alu_result, imm_data, alurs2_data, ram2regfile, pc2regfile;

    assign daddr = alu_result;
    assign dwdata = rs2;

    program_counter U_PC (
        .clk(clk),
        .rst(rst),
        .branch(branch),
        .JAL(JAL),
        .JALR(JALR),
        .btaken(btaken),
        .rs1(rs1),
        .imm_data(imm_data),
        .pc_add4(pc2regfile),
        .program_counter(instr_addr)
    );
    register_file U_REG_FILE (
        .clk(clk),
        .rst(rst),
        .ra1(instr_data[19:15]),
        .ra2(instr_data[24:20]),
        .wa(instr_data[11:7]),
        .wdata(ram2regfile),
        .rf_we(rf_we),
        .rs1(rs1),
        .rs2(rs2)
    );
    imm_extender U_IMM_EXTENDER (
        .instr_data(instr_data),
        .imm_data(imm_data)
    );
    mux_2x1 U_MUX_ALUSRC_RS2 (
        .in0(rs2),
        .in1(imm_data),
        .sel(alu_src),
        .out_mux(alurs2_data)
    );
    alu U_ALU (
        .rs1(rs1),
        .rs2(alurs2_data),
        .alu_control(alu_control),
        .alu_result(alu_result),
        .btaken(btaken)
    );
    mux_4x1 U_MUX_WB_REGFILE (
        .in0(alu_result),
        .in1(drdata),
        .in2(imm_data),
        .in3(pc2regfile),
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


module mux_4x1 (
    input        [31:0] in0, // sel 0
    input        [31:0] in1, // sel 1
    input        [31:0] in2, // sel 2
    input        [31:0] in3, // sel 3
    input        [ 1:0] sel,
    output logic [31:0] out_mux
);
    assign out_mux = (sel == 2'd0) ? in0 :
                     (sel == 2'd1) ? in1 :
                     (sel == 2'd2) ? in2 : in3;
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
            `B_TYPE: begin
                imm_data = {
                    {19{instr_data[31]}},
                    instr_data[31],
                    instr_data[7],
                    instr_data[30:25],
                    instr_data[11:8],
                    1'b0
                };
            end
        endcase 
    end
endmodule


module register_file (
    input         clk,
    input         rst,
    input  [ 4:0] ra1,
    input  [ 4:0] ra2,
    input  [ 4:0] wa,
    input  [31:0] wdata,
    input         rf_we,
    output [31:0] rs1,
    output [31:0] rs2
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
            register_file[wa] <= wdata;
        end
    end

    // output CL
    assign rs1 = (ra1!=0) ? register_file[ra1] : 0;
    assign rs2 = (ra1!=0) ? register_file[ra2] : 0;
endmodule


module alu (
    input        [31:0] rs1,          // rs1
    input        [31:0] rs2,          // RS2
    input        [ 3:0] alu_control,  // func7[5], funct3 : 4-bit
    output logic [31:0] alu_result,
    output logic        btaken
);

    always_comb begin
        alu_result = 0;
        
        case (alu_control)
            `ADD:  alu_result = rs1 + rs2;  // add RD = rs1 + RS2
            `SUB:  alu_result = rs1 - rs2;  // sub rd = rs1 - rs2
            `SLL:  alu_result = rs1 << rs2[4:0];     // sll rd = rs1 << rs2 // shift max 5-bit
            `SLT:  alu_result = ($signed(rs1) < $signed(rs2)) ? 1 : 0;  // slt rd = (rs1 < rs2) ? 1 : 0
            `SLTU: alu_result = (rs1 < rs2) ? 1 : 0;  // sltu rd = (rs1 < rs2) ? 1 : 0
            `XOR:  alu_result = rs1 ^ rs2;  // xor rd = rs1 ^ rs2
            `SRL:  alu_result = rs1 >> rs2[4:0];  // srl rd = rs1 >> rs2
            `SRA:  alu_result = $signed(rs1) >>> rs2[4:0];  // sra rd = rs1 >> rs2, msb extention
            `OR:   alu_result = rs1 | rs2;  // or rd = rs1 | rs2
            `AND:  alu_result = rs1 & rs2;  // and rd = rs1 & rs2
        endcase
        end

    // B-type comparator
    always_comb begin
        btaken = 0;
        case(alu_control)
            `BEQ: if(rs1 == rs2) btaken = 1;  // ture:  pc = pc + IMM
            `BNE: if(rs1 != rs2) btaken = 1;
            `BLT: if($signed(rs1) < $signed(rs2))  btaken = 1;
            `BGE: if($signed(rs1) >= $signed(rs2)) btaken = 1;
            `BLTU: if(rs1 < rs2)  btaken = 1;
            `BGEU: if(rs1 >= rs2) btaken = 1;
            default: btaken = 0;              // false: pc = pc + 4
        endcase
    end
endmodule


module program_counter (
    input         clk,
    input         rst,
    input         branch,
    input         JAL,
    input         JALR,
    input         btaken,
    input  [31:0] rs1,
    input  [31:0] imm_data,
    output [31:0] pc_add4,
    output [31:0] program_counter
);

    logic [31:0] pc_alu_out, j_alu_out, pc_mux_out, jalr_mux_out;

    assign pc_add4 = pc_alu_out;

    mux_2x1 U_MUX_RS_IMM (
        .in0(imm_data),
        .in1(rs1),
        .sel(JALR),
        .out_mux(jalr_mux_out)
    );
    pc_alu U_PC_ALU_4 (
        .a(32'h4),
        .b(program_counter),
        .pc_alu_out(pc_alu_out)
    );
    pc_alu U_PC_ALU_J (
        .a(jalr_mux_out),
        .b(program_counter),
        .pc_alu_out(j_alu_out)
    );
    mux_2x1 U_MUX_PC (
        .in0(pc_alu_out),
        .in1(j_alu_out),
        .sel(JAL||(branch && btaken)),
        .out_mux(pc_mux_out)
    );
    register U_PC_REG (
        .clk(clk),
        .rst(rst),
        .data_in(pc_mux_out),
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
