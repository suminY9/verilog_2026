`timescale 1ns / 1ps

module data_mem (
    input         clk,
    input         rst,
    input         dwe,
    input  [ 2:0] funct3,
    input  [31:0] daddr,
    input  [31:0] dwdata,
    output [31:0] drdata
);

    logic [7:0] dmem[0:1023];
    logic [29:0] block;
    logic [31:0] start_addr;

    always_ff @(posedge clk, posedge rst) begin
        if(rst) begin

        end else begin
            if(dwe) begin
                case(funct3)
                    3'b000: begin //SB
                        dmem[start_addr] <= dwdata[7:0];
                    end
                    3'b001: begin //SH
                        dmem[start_addr]   <= dwdata[7:0];
                        dmem[start_addr+1] <= dwdata[15:8];
                    end
                    3'b010: begin //SW
                        dmem[start_addr+0] <= dwdata[7:0];
                        dmem[start_addr+1] <= dwdata[15:8];
                        dmem[start_addr+2] <= dwdata[23:16];
                        dmem[start_addr+3] <= dwdata[31:24];
                    end
                endcase
            end
        end
    end

    always_comb begin
        block       = 0;
        start_addr = 0;

        block = daddr[31:2];
        case(funct3)
        3'b000: begin //SB, LB
            start_addr = daddr;
        end
        3'b001: begin //SH, LH
            start_addr = ((4*block) + ((daddr[1:0] >> 1) << 1));
        end
        3'b010: begin //SW, LW
            start_addr = (4*block);
        end
        3'b100: begin //LBU
            start_addr = daddr;
        end
        3'b101: begin //LHU
            start_addr = ((4*block) + ((daddr[1:0] >> 1) << 1));
        end
        endcase
    end

    // little endian
    assign drdata = (funct3 == 3'b000) ? {{24{dmem[start_addr][7]}}, dmem[start_addr]} : // LB
                    (funct3 == 3'b001) ? {{16{dmem[start_addr+1][7]}}, dmem[start_addr+1], dmem[start_addr+0]} : // LH
                    (funct3 == 3'b010) ? {dmem[start_addr+3], dmem[start_addr+2], dmem[start_addr+1], dmem[start_addr+0]} : // LW
                    (funct3 == 3'b100) ? {24'b0, dmem[start_addr]} : // LBU
                    (funct3 == 3'b101) ? {16'b0, dmem[start_addr+1], dmem[start_addr+0]} : // LHU
                    32'b0; // default
endmodule
