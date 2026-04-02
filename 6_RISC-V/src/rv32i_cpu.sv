`timescale 1ns / 1ps
`include "define.vh"

module rv32i_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    input  [31:0] bus_rdata,
    input         bus_ready,
    output [31:0] instr_addr,
    output        bus_wreq,
    output        bus_rreq,
    output [ 2:0] funct3,
    output [31:0] bus_addr,
    output [31:0] bus_wdata
);

    logic pc_en, rf_we, alu_src, branch, JAL, JALR;
    logic [2:0] rf_wb_src;
    logic [3:0] alu_control;

    control_unit U_CONTROL_UNIT (
        .clk(clk),
        .rst(rst),
        .funct7(instr_data[31:25]),
        .funct3(instr_data[14:12]),
        .opcode(instr_data[6:0]),
        .ready(bus_ready),
        .pc_en(pc_en),
        .rf_we(rf_we),
        .branch(branch),
        .JAL(JAL),
        .JALR(JALR),
        .alu_src(alu_src),
        .alu_control(alu_control),
        .rf_wb_src(rf_wb_src),
        .o_funct3(funct3),
        .dwe(bus_wreq),
        .dre(bus_rreq)
    );
    rv32i_datapath U_DATAPATH (
        .clk(clk),
        .rst(rst),
        .pc_en(pc_en),
        .rf_we(rf_we),
        .alu_src(alu_src),
        .rf_wb_src(rf_wb_src),
        .branch(branch),
        .JAL(JAL),
        .JALR(JALR),
        .alu_control(alu_control),
        .instr_data(instr_data),
        .drdata(bus_rdata),
        .instr_addr(instr_addr),
        .daddr(bus_addr),
        .dwdata(bus_wdata)
    );
endmodule


module control_unit (
    input              clk,
    input              rst,
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    input              ready,
    output logic       pc_en,
    output logic       rf_we,
    output logic       branch,
    output logic       JAL,
    output logic       JALR,
    output logic       alu_src,
    output logic [3:0] alu_control,
    output logic [2:0] rf_wb_src,
    output logic [2:0] o_funct3,
    output logic       dwe,
    output logic       dre
    );

    typedef enum {
        FETCH,
        DECODE,
        EXECUTE,
        MEM,
        WB
    } state_e;

    state_e c_state, n_state;

    always_ff @(posedge clk, posedge rst) begin // FPGA의 button 입력으로 rst을 함. neg이든 pose이든 타이밍 상에 큰 문제 없음.
                                                // 항상 top 설계 지도자가 지정해주는 방식을 사용할 것.
        if(rst) begin
            c_state <= FETCH;
        end else begin
            c_state <= n_state;
        end
    end

    // next CL
    always_comb begin
        n_state = c_state;
        
        case (c_state)
            FETCH: begin
                n_state = DECODE;
            end
            DECODE: begin
                n_state = EXECUTE;
            end
            EXECUTE: begin
                case(opcode)
                    `R_TYPE, `I_TYPE, `B_TYPE, `LUI, `AUIPC, `JAL, `JALR: n_state = FETCH;
                    `S_TYPE, `IL_TYPE: n_state = MEM;
                    default: n_state = FETCH;
                endcase
            end
            MEM: begin
                case(opcode)
                    `S_TYPE: begin
                        if(ready) begin
                            n_state = FETCH;
                        end
                    end
                    `IL_TYPE: n_state = WB;
                    default: n_state = FETCH;
                endcase
            end
            WB: begin
                if(ready) begin
                    n_state = FETCH;
                end
            end
        endcase
    end

    //output CL
    always_comb begin
        pc_en       = 1'b0;
        rf_we       = 1'b0;
        branch      = 1'b0;
        JAL         = 1'b0;
        JALR        = 1'b0;
        alu_src     = 1'b0;
        alu_control = 4'b0_000;
        dwe         = 1'b0;
        rf_wb_src   = 3'b000;
        o_funct3    = 3'b000;
        dwe         = 1'b0;
        dre         = 1'b0;

        case (c_state)
            FETCH: begin
                pc_en       = 1'b1;
            end
            DECODE: begin
            end
            EXECUTE: begin
                case(opcode)
                    `R_TYPE: begin
                        rf_we = 1'b1; // 바로 저장 (MEM 접근 안하고 바로 FETCH로 감)
                        alu_src = 1'b0;
                        alu_control = {funct7[5], funct3};
                    end
                    `I_TYPE: begin
                        rf_we = 1'b1; // 바로 저장
                        alu_src = 1'b1;
                        if(funct3 == 3'b101) alu_control = {funct7[5], funct3};
                        else alu_control = {1'b0, funct3};
                    end
                    `B_TYPE: begin
                        branch = 1'b1;
                        alu_src = 1'b0;
                        alu_control = {1'b0, funct3};
                    end
                    `S_TYPE: begin
                        alu_src = 1'b1;
                        alu_control = 4'b0000;
                    end
                    `IL_TYPE: begin
                        alu_src = 1'b1;
                        alu_control = 4'b0000;
                    end
                    `LUI: begin
                        rf_we = 1'b1; // 바로 저장
                        alu_src     = 1'b0;
                        alu_control = 4'b1_111;  // for btaken = 0, ADD
                        rf_wb_src = 3'b010;
                    end
                    `AUIPC: begin
                        rf_we = 1'b1; // 바로 저장
                        alu_src     = 1'b1;
                        alu_control = 4'b1_111;  // for btaken = 0
                        rf_wb_src = 3'b100;
                    end
                    `JAL: begin
                        rf_we = 1'b1; // 바로 저장
                        alu_src     = 1'b1;
                        alu_control = 4'b0_000;
                        rf_wb_src = 3'b011;
                        JAL = 1'b1;
                        JALR = 1'b0;
                    end
                    `JALR: begin
                        rf_we = 1'b1; // 바로 저장
                        alu_src     = 1'b1;
                        alu_control = 4'b0_000;                        
                        rf_wb_src = 3'b011;
                        JAL = 1'b1;
                        JALR = 1'b1;
                    end
                endcase
            end
            MEM: begin
                case(opcode)
                    `S_TYPE: begin
                        dwe = 1'b1;
                        dre = 1'b0;
                        o_funct3 = funct3;
                    end
                    `IL_TYPE: begin
                        dwe = 1'b0;
                        dre = 1'b1;
                        o_funct3 = funct3;
                    end
                endcase
            end
            WB: begin
                case(opcode)
                    `R_TYPE: begin
                        rf_we = 1'b1;
                        rf_wb_src = 3'd0;
                    end
                    `I_TYPE: begin
                        rf_we = 1'b1;
                        rf_wb_src = 3'd0;
                    end
                    `B_TYPE: begin
                        rf_we = 1'b0;
                        rf_wb_src = 3'd0;
                    end
                    `S_TYPE: begin
                        rf_we = 1'b0;
                        rf_wb_src = 3'd0;
                    end
                    `IL_TYPE: begin
                        rf_we = 1'b1;
                        rf_wb_src = 3'd1;
//                        dre = 1'b1;
                    end
                    `LUI: begin
                        rf_we = 1'b1;
                        rf_wb_src = 3'd2;
                    end
                    `AUIPC: begin
                        rf_we = 1'b1;
                        rf_wb_src = 3'd4;
                    end
                    `JAL: begin
                        rf_we = 1'b1;
                        rf_wb_src = 3'd3;
                    end
                    `JALR: begin
                        rf_we = 1'b1;
                        rf_wb_src = 3'd3;
                    end
                endcase
            end
        endcase
    end

//    always_comb begin
//        rf_we       = 1'b0;
//        branch      = 1'b0;
//        JAL         = 1'b0;
//        JALR        = 1'b0;
//        alu_src     = 1'b0;
//        alu_control = 4'b0_000;  //initialize
//        dwe         = 1'b0;
//        rf_wb_src   = 3'b000;
//        o_funct3    = 3'b000;
//
//        case (opcode)
//            `R_TYPE: begin
//                rf_we       = 1'b1;
//                branch      = 1'b0;
//                JAL         = 1'b0;
//                JALR        = 1'b0;
//                alu_src     = 1'b0;
//                alu_control = {funct7[5], funct3};
//                dwe         = 1'b0;
//                rf_wb_src   = 3'b000;
//                o_funct3    = 3'b000;
//            end
//            `S_TYPE: begin
//                rf_we       = 1'b0;
//                branch      = 1'b0;
//                JAL         = 1'b0;
//                JALR        = 1'b0;
//                alu_src     = 1'b1;
//                alu_control = 4'b0_000;  // S-type only do ADD
//                dwe         = 1'b1;
//                rf_wb_src   = 3'b000;
//                o_funct3    = funct3;  // send funct3 to data_mem(for dw)
//            end
//            `IL_TYPE: begin
//                rf_we       = 1'b1;
//                branch      = 1'b0;
//                JAL         = 1'b0;
//                JALR        = 1'b0;
//                alu_src     = 1'b1;
//                alu_control = 4'b0_000;  // only do ADD
//                dwe         = 1'b0;
//                rf_wb_src   = 3'b001;
//                o_funct3    = funct3;  // send funct3 to data_mem(for dr)
//            end
//            `I_TYPE: begin
//                rf_we   = 1'b1;
//                branch  = 1'b0;
//                JAL     = 1'b0;
//                JALR    = 1'b0;
//                alu_src = 1'b1;
//                if (funct3 == 3'b101)
//                    alu_control = {
//                        funct7[5], funct3
//                    };  // SRLI: {0, 101}, SRAI: {1, 101}
//                else alu_control = {1'b0, funct3};
//                dwe       = 1'b0;
//                rf_wb_src = 3'b000;
//                o_funct3  = 3'b000;
//            end
//            `B_TYPE: begin
//                rf_we       = 1'b0;
//                branch      = 1'b1;
//                JAL         = 1'b0;
//                JALR        = 1'b0;
//                alu_src     = 1'b0;
//                alu_control = {1'b0, funct3};
//                dwe         = 1'b0;
//                rf_wb_src   = 3'b000;
//                o_funct3    = 3'b000;
//            end
//            `LUI: begin
//                rf_we       = 1'b1;
//                branch      = 1'b0;
//                JAL         = 1'b0;
//                JALR        = 1'b0;
//                alu_src     = 1'b0;
//                alu_control = 4'b1_111;  // for btaken = 0, ADD
//                dwe         = 1'b0;
//                rf_wb_src   = 3'b010;
//                o_funct3    = 3'b000;
//            end
//            `AUIPC: begin
//                rf_we       = 1'b1;
//                branch      = 1'b0;
//                JAL         = 1'b0;
//                JALR        = 1'b0;
//                alu_src     = 1'b1;
//                alu_control = 4'b1_111;  // for btaken = 0
//                dwe         = 1'b0;
//                rf_wb_src   = 3'b100;
//                o_funct3    = 3'b000;
//            end
//            `JAL: begin
//                rf_we       = 1'b1;
//                branch      = 1'b1;
//                JAL         = 1'b1;
//                JALR        = 1'b0;
//                alu_src     = 1'b1;
//                alu_control = 4'b0_000;
//                dwe         = 1'b0;
//                rf_wb_src   = 3'b011;
//                o_funct3    = 3'b000;
//            end
//            `JALR: begin
//                rf_we       = 1'b1;
//                branch      = 1'b1;
//                JAL         = 1'b1;
//                JALR        = 1'b1;
//                alu_src     = 1'b1;
//                alu_control = 4'b0_000;  // only do ADD
//                dwe         = 1'b0;
//                rf_wb_src   = 3'b011;
//                o_funct3    = 3'b000;
//            end
//        endcase
//    end
endmodule
