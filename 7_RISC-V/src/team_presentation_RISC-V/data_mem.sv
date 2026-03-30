`timescale 1ns / 1ps
`include "define.vh"
module data_mem (
    input               clk,
    input               dwe,
    input        [ 2:0] i_funct3,
    input        [31:0] daddr,
    input        [31:0] dwdata,
    output logic [31:0] drdata
);

    // byte address
    //    logic [7:0] dmem[0:31];

    //    always_ff @(posedge clk) begin
    //        if (dwe) begin
    //            dmem[dwaddr+0] <= dwdata[7:0];
    //            dmem[dwaddr+1] <= dwdata[15:8];
    //            dmem[dwaddr+2] <= dwdata[23:16];
    //            dmem[dwaddr+3] <= dwdata[31:24];
    //        end
    //    end

    //    assign drdata = {
    //        dmem[dwaddr], dmem[dwaddr+1], dmem[dwaddr+2], dmem[dwaddr+3]
    //    };
    logic [31:0] w_wdata, w_drdata;
    data_ram U_DMEM (
        .clk(clk),
        .dwe(dwe),
        .daddr(daddr),
        .data_in(w_wdata),
        .data_out(w_drdata)

    );
    // S-type control for byte to word address
    always_comb begin
        w_wdata = dwdata;
        case (i_funct3)
            `SW: w_wdata = dwdata;
            `SH: begin
                if (daddr[1] == 1'b1) w_wdata[31:16] = dwdata[15:0];  // 
                else w_wdata[15:0] = dwdata[15:0];  // if (daddr[1] == 1'b0) 
            end
            `SB: begin
                case (daddr[1:0])
                    2'b00: w_wdata[7:0] = dwdata[7:0];
                    2'b01: w_wdata[15:8] = dwdata[7:0];
                    2'b10: w_wdata[23:16] = dwdata[7:0];
                    2'b11: w_wdata[31:24] = dwdata[7:0];
                endcase
            end
        endcase
    end
    // IL-type control 
    always_comb begin
        drdata = w_drdata;
        case (i_funct3)
            `LW: drdata = w_drdata;
            `LH: begin
                if (daddr[1] == 1'b1)
                    drdata[31:0] = {{16{w_drdata[31]}}, w_drdata[31:16]};  // 
                else
                    drdata[15:0] = {
                        {16{w_drdata[15]}}, w_drdata[15:0]
                    };  // if (daddr[1] == 1'b0) 
            end
            `LB: begin
                case (daddr[1:0])
                    2'b00: drdata[31:0] = {{24{w_drdata[7]}}, w_drdata[7:0]};
                    2'b01: drdata[31:0] = {{24{w_drdata[15]}}, w_drdata[15:8]};
                    2'b10: drdata[31:0] = {{24{w_drdata[23]}}, w_drdata[23:16]};
                    2'b11: drdata[31:0] = {{24{w_drdata[31]}}, w_drdata[31:24]};
                endcase
            end
            `LHU: begin
                if (daddr[1] == 1'b1)
                    drdata[31:0] = {{16{1'b0}}, w_drdata[31:16]};  // 
                else
                    drdata[15:0] = {
                        {16{1'b0}}, w_drdata[15:0]
                    };  // if (daddr[1] == 1'b0) 
            end
            `LBU: begin
                case (daddr[1:0])
                    2'b00: drdata[31:0] = {{24{1'b0}}, w_drdata[7:0]};
                    2'b01: drdata[31:0] = {{24{1'b0}}, w_drdata[15:8]};
                    2'b10: drdata[31:0] = {{24{1'b0}}, w_drdata[23:16]};
                    2'b11: drdata[31:0] = {{24{1'b0}}, w_drdata[31:24]};
                endcase
            end
        endcase
    end

endmodule
module data_ram (
    input         clk,
    input         dwe,
    input  [31:0] daddr,
    input  [31:0] data_in,
    output [31:0] data_out
);
    logic [31:0] dmem[0:255];
    always_ff @(posedge clk) begin
        if (dwe) begin
            dmem[daddr[31:2]] <= data_in;  // SW
        end
    end

    assign data_out = dmem[daddr[31:2]];


endmodule
