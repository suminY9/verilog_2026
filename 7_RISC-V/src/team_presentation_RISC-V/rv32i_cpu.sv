`timescale 1ns / 1ps
`include "define.vh"

module rv32i_cpu (
    input               clk,
    input               rst,
    input        [31:0] instr_data,
    input        [31:0] bus_rdata,
    input               bus_ready,
    output logic [31:0] instr_addr,
    output logic        bus_wreq,
    output logic        bus_rreq,
    output logic [31:0] bus_addr,
    output logic [ 2:0] o_funct3,
    output logic [31:0] bus_wdata
);

    logic rf_we, alu_src, branch, jal, jalr, pc_en, ir_en;
    logic [2:0] rfwd_src;
    logic [3:0] alu_control;
    logic [31:0] instr_reg; // Instruction Register

    // FETCH 상태일 때만 명령어를 래치하여 긴 타이밍 경로를 차단
    always_ff @(posedge clk or posedge rst) begin
        if (rst) instr_reg <= 32'b0;
        else if (ir_en) instr_reg <= instr_data;
    end

    control_unit U_CONTROL_UNIT (
        .clk        (clk),
        .rst        (rst),
        .funct7     (instr_reg[31:25]),  // 래치된 명령어 사용
        .funct3     (instr_reg[14:12]),
        .opcode     (instr_reg[6:0]),
        .ready      (bus_ready),
        .pc_en      (pc_en),
        .ir_en      (ir_en),
        .rf_we      (rf_we),
        .dwe        (bus_wreq),
        .dre        (bus_rreq),
        .jal        (jal),               // JAL  : J_TYPE  (PC  기준 점프)
        .jalr       (jalr),              // JALR : JL_TYPE (rs1 기준 점프)
        .alu_src    (alu_src),
        .rfwd_src   (rfwd_src),
        .alu_control(alu_control),
        .o_funct3   (o_funct3),
        .branch     (branch)
    );

    rv32i_datapath U_DATAPATH (
        .clk        (clk),
        .rst        (rst),
        .alu_src    (alu_src),
        .alu_control(alu_control),
        .jal        (jal),
        .jalr       (jalr),
        .pc_en      (pc_en),
        .rf_we      (rf_we),
        .branch     (branch),
        .rfwd_src   (rfwd_src),
        .bus_rdata  (bus_rdata),
        .instr_data (instr_reg),         // 래치된 명령어 사용
        .instr_addr (instr_addr),
        .bus_addr   (bus_addr),
        .bus_wdata  (bus_wdata)
    );

endmodule

// ==========================================

module control_unit (
    input              clk,
    input              rst,
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    input              ready,
    output logic       pc_en,
    output logic       ir_en,
    output logic       rf_we,
    output logic       dwe,
    output logic       dre,
    output logic       jal,              // JAL  : PC  기준 점프 (J_TYPE)
    output logic       jalr,             // JALR : rs1 기준 점프 (JL_TYPE)
    output logic [2:0] rfwd_src,
    output logic       alu_src,
    output logic [2:0] o_funct3,
    output logic [3:0] alu_control,
    output logic       branch
);

    typedef enum logic [2:0] {
        FETCH   = 3'd0,
        DECODE  = 3'd1,
        EXECUTE = 3'd2,
        MEM     = 3'd3,
        WB      = 3'd4
    } state_e;

    state_e c_st, n_st;

    // ─── State Register ───────────────────────────────────────────────
    always_ff @(posedge clk or posedge rst) begin
        if (rst) c_st <= FETCH;
        else     c_st <= n_st;
    end

    // ─── Next State Logic ─────────────────────────────────────────────
    always_comb begin
        n_st = c_st;
        case (c_st)
            FETCH:  n_st = DECODE;
            DECODE: n_st = EXECUTE;
            EXECUTE: begin
                case (opcode)
                    `R_TYPE, `I_TYPE,
                    `UL_TYPE, `UA_TYPE,
                    `J_TYPE,  `JL_TYPE,
                    `B_TYPE:             n_st = FETCH;
                    `S_TYPE, `IL_TYPE:   n_st = MEM;
                    default:             n_st = FETCH;
                endcase
            end
            MEM: begin
                case (opcode)
                    `IL_TYPE: if (ready) n_st = WB;
                    `S_TYPE:  if (ready) n_st = FETCH;
                    default:             n_st = FETCH;
                endcase
            end
            WB:      n_st = FETCH;
            default: n_st = FETCH;
        endcase
    end

    // ─── Output Logic ────────────────────────────────────────────────
    always_comb begin
        pc_en       = 1'b0;
        ir_en       = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;
        branch      = 1'b0;
        rfwd_src    = 3'b000;
        dwe         = 1'b0;
        dre         = 1'b0;
        rf_we       = 1'b0;
        alu_src     = 1'b0;
        alu_control = 4'b0000;
        o_funct3    = 3'b000;

        case (c_st)
            FETCH: begin
                ir_en = 1'b1;       // 명령어 래치 활성화
            end

            DECODE: begin
                // RS1 / RS2 / IMM 레지스터 래치 대기
            end

            EXECUTE: begin
                case (opcode)
                    `R_TYPE: begin
                        rf_we       = 1'b1;
                        rfwd_src    = 3'b000;   // ALU result
                        alu_src     = 1'b0;     // RS2
                        alu_control = {funct7[5], funct3};
                        pc_en       = 1'b1;
                    end
                    `I_TYPE: begin
                        rf_we       = 1'b1;
                        rfwd_src    = 3'b000;   // ALU result
                        alu_src     = 1'b1;     // IMM
                        alu_control = (funct3 == 3'b101) ?
                                      {funct7[5], funct3} : {1'b0, funct3};
                        pc_en       = 1'b1;
                    end
                    `B_TYPE: begin
                        branch      = 1'b1;
                        alu_src     = 1'b0;     // RS2
                        alu_control = {1'b0, funct3};
                        pc_en       = 1'b1;
                    end
                    `S_TYPE, `IL_TYPE: begin
                        alu_src     = 1'b1;     // IMM (주소 계산)
                        alu_control = 4'b0000;  // ADD
                        // pc_en은 MEM에서 ready 확인 후 세팅
                    end
                    `JL_TYPE: begin             // JALR : rs1 + imm
                        rf_we       = 1'b1;
                        rfwd_src    = 3'b100;   // PC + 4
                        jal         = 1'b1;     // PC_NEXT_MUX : 점프 선택
                        jalr        = 1'b1;     // PC_JTYPE_MUX: rs1 선택
                        alu_src     = 1'b1;
                        pc_en       = 1'b1;
                    end
                    `J_TYPE: begin              // JAL : PC + imm
                        rf_we       = 1'b1;
                        rfwd_src    = 3'b100;   // PC + 4
                        jal         = 1'b1;     // PC_NEXT_MUX : 점프 선택
                        jalr        = 1'b0;     // PC_JTYPE_MUX: PC 선택
                        pc_en       = 1'b1;
                    end
                    `UL_TYPE: begin             // LUI
                        rf_we       = 1'b1;
                        rfwd_src    = 3'b010;   // IMM
                        pc_en       = 1'b1;
                    end
                    `UA_TYPE: begin             // AUIPC
                        rf_we       = 1'b1;
                        rfwd_src    = 3'b011;   // PC + IMM
                        pc_en       = 1'b1;
                    end
                endcase
            end

            MEM: begin
                o_funct3 = funct3;
                if (opcode == `S_TYPE) begin
                    dwe  = 1'b1;
                    dre  = 1'b0;
                    if (ready) pc_en = 1'b1;    // Store 완료 시 PC 업데이트
                end else begin                  // IL_TYPE (Load)
                    dwe  = 1'b0;
                    dre  = 1'b1;
                end
            end

            WB: begin
                rf_we    = 1'b1;
                rfwd_src = 3'b001;  // 메모리에서 읽은 값
                pc_en    = 1'b1;    // Load 완료 시 PC 업데이트
            end
        endcase
    end

endmodule