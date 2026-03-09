`timescale 1ns / 1ps

module data_mem (
    input         clk,
    input         rst,
    input         dwe,
    input  [ 3:0] alu_control,
    input  [31:0] dwaddr,
    input  [31:0] dwdata,
    output [31:0] drdata
);

    logic [7:0] dmem[0:31];
    logic [29:0] block;
    logic [31:0] store_start;

    always_ff @(posedge clk, posedge rst) begin
        if(rst) begin

        end else begin
            if(dwe) begin
                case(alu_control)
                    4'b0_000: begin //SB
                        dmem[store_start] <= dwdata[7:0];
                    end
                    4'b0_001: begin //SH
                        dmem[store_start]   <= dwdata[7:0];
                        dmem[store_start+1] <= dwdata[15:8];
                    end
                    4'b0_010: begin //SW
                        dmem[store_start+0] <= dwdata[7:0];
                        dmem[store_start+1] <= dwdata[15:8];
                        dmem[store_start+2] <= dwdata[23:16];
                        dmem[store_start+3] <= dwdata[31:24];
                    end
                //dmem[dwaddr+0] <= dwdata[7:0];
                //dmem[dwaddr+1] <= dwdata[15:8];
                //dmem[dwaddr+2] <= dwdata[23:16];
                //dmem[dwaddr+3] <= dwdata[31:24];
                endcase
            end
        end
    end

    always_comb begin
        block       = 0;
        store_start = 0;

        if(dwe) begin
            block = dwaddr[31:2];
            case(alu_control)
            4'b0_000: begin //SB
                store_start = dwaddr;
            end
            4'b0_001: begin //SH
                store_start = ((4*block) + ((dwaddr[1:0] >> 1) << 1));
            end
            4'b0_010: begin //SW
                store_start = (4*block);
            end
            endcase
        end
    end

    assign drdata = {dmem[dwaddr+0], dmem[dwaddr+1], dmem[dwaddr+2], dmem[dwaddr+3]};
endmodule
