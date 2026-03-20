`timescale 1ns / 1ps
`include "define.vh"

module rv32i_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    input  [31:0] drdata,
    output [31:0] instr_addr,
    output        dwe,
    output [ 2:0] funct3,
    output [31:0] daddr,
    output [31:0] dwdata
);

    logic rf_we, alu_src, branch, JAL, JALR;
    logic [2:0] rf_wd_src;
    logic [3:0] alu_control;

    control_unit U_CONTROL_UNIT (
        .clk(clk),
        .rst(rst),
        .funct7(instr_data[31:25]),
        .funct3(instr_data[14:12]),
        .opcode(instr_data[6:0]),
        .rf_we(rf_we),
        .branch(branch),
        .JAL(JAL),
        .JALR(JALR),
        .alu_src(alu_src),
        .alu_control(alu_control),
        .rf_wd_src(rf_wd_src),
        .o_funct3(funct3),
        .dwe(dwe)
    );
    rv32i_datapath U_DATAPATH (
        .clk(clk),
        .rst(rst),
        .rf_we(rf_we),
        .alu_src(alu_src),
        .rf_wd_src(rf_wd_src),
        .branch(branch),
        .JAL(JAL),
        .JALR(JALR),
        .alu_control(alu_control),
        .instr_data(instr_data),
        .drdata(drdata),
        .instr_addr(instr_addr),
        .daddr(daddr),
        .dwdata(dwdata)
    );
endmodule


module control_unit (
    input              clk,
    input              rst,
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    output logic       pc_en,
    output logic       rf_we,
    output logic       branch,
    output logic       JAL,
    output logic       JALR,
    output logic       alu_src,
    output logic [3:0] alu_control,
    output logic [2:0] rf_wd_src,
    output logic [2:0] o_funct3,
    output logic       dwe
);

    typedef enum logic {
        FETCH,
        DECODE,
        EXECUTE,
        EXE_R,
        EXE_I,
        EXE_S,
        EXE_B,
        EXE_IL,
        EXE_J,
        EXE_JL,
        EXE_U,
        EXE_UA,
        MEM_S,
        MEM_IL,
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
        n_state     = c_state;
        
        case (c_state)
            FETCH: begin
                n_state = DECODE;
            end
            DECODE: begin
                //n_state = EXECUTE;
                case (opcode) 
                    `R_TYPE: n_state = EXE_R;
                    `I_TYPE: n_state = EXE_I;
                    `B_TYPE: n_state = EXE_B;
                    `S_TYPE: n_state = EXE_S;
                    `IL_TYPE: n_state = EXE_IL;
                    `LUI: n_state = EXE_U;
                    `AUIPC: n_state = EXE_UA;
                    `JAL: n_state = EXE_J;
                    `JALR: n_state = EXE_JL;
                endcase
            end
            EXECUTE: begin
                //
            end
            MEM_S: begin
                //
            end
            WB: begin
                n_state = FETCH;
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
        rf_wd_src   = 3'b000;
        o_funct3    = 3'b000;

        case (c_state)
            FETCH: begin
                pc_en       = 1'b1;
                rf_we       = 1'b0;
                branch      = 1'b0;
                JAL         = 1'b0;
                JALR        = 1'b0;
                alu_src     = 1'b0;
                alu_control = 4'b0_000;
                dwe         = 1'b0;
                rf_wd_src   = 3'b000;
                o_funct3    = 3'b000;
            end
            DECODE: begin
                pc_en       = 1'b0;
                rf_we       = 1'b0;
                branch      = 1'b0;
                JAL         = 1'b0;
                JALR        = 1'b0;
                alu_src     = 1'b0;
                alu_control = 4'b0_000;
                dwe         = 1'b0;
                rf_wd_src   = 3'b000;
                o_funct3    = 3'b000;
            end
            EXECUTE: begin
            //    case (opcode) 
            //        `R_TYPE: n_state = EXE_R;
            //        `I_TYPE: n_state = EXE_I;
            //        `B_TYPE: n_state = EXE_B;
            //        `S_TYPE: n_state = EXE_S;
            //        `IL_TYPE: n_state = EXE_IL;
            //        `LUI: n_state = EXE_U;
            //        `AUIPC: n_state = EXE_UA;
            //        `JAL: n_state = EXE_J;
            //        `JALR: n_state = EXE_JL;
            //    endcase
            end
            EXE_R: begin
                alu_src = 1'b0;
                alu_control = {funct7[5], funct3};
            end
            EXE_I: begin
                alu_src = 1'b1;
                if(funct3 == 3'b101) alu_control = {funct7[5], funct3};
                else alu_control =  {1'b0, funct3};
            end
            EXE_B: begin
                branch = 1'b1;
                alu_src = 1'b0;
                alu_control = {1'b0, funct3};
            end
            EXE_S: begin
                alu_src = 1'b1;
                alu_control = 4'b0000;
                o_funct3 = funct3;
                dwe = 1'b1;
            end
            EXE_IL: begin
                alu_src = 1'b1;
                alu_control = 4'b0000;
                o_funct3 = funct3;
                dwe = 1'b0;
            end
            EXE_U: begin
                //
            end
            EXE_UA: begin
                //
            end
            EXE_J: begin
                JAL = 1'b1;
                JALR = 1'b0;

            end
            EXE_JL: begin
                JAL = 1'b1;
                JALR = 1'b1;
            end
            MEM_S: begin
                //
            end
            MEM_IL: begin
                //
            end
            WB: begin
                //
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
//        rf_wd_src   = 3'b000;
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
//                rf_wd_src   = 3'b000;
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
//                rf_wd_src   = 3'b000;
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
//                rf_wd_src   = 3'b001;
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
//                rf_wd_src = 3'b000;
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
//                rf_wd_src   = 3'b000;
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
//                rf_wd_src   = 3'b010;
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
//                rf_wd_src   = 3'b100;
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
//                rf_wd_src   = 3'b011;
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
//                rf_wd_src   = 3'b011;
//                o_funct3    = 3'b000;
//            end
//        endcase
//    end
endmodule
