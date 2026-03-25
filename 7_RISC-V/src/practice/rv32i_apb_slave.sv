`timescale 1ns / 1ps

module apb_slave (
    input               PCLK,
    input               PRESET,
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PSEL,
    input               PENABLE,
    input               PWRITE,
    output logic [31:0] PRDATA,
    output logic        Ready
);

    typedef enum {
        IDLE,
        SETUP,
        ACCESS
    } state;
    state n_state, c_state;

    logic [31:0] PADDR_RAM;
    logic PWRITE_RAM;

    always_ff @(posedge PCLK, negedge PRESET) begin
        if (!PRESET) begin
            c_state <= IDLE;
        end else begin
            c_state <= n_state;
        end
    end

    always_comb begin
        n_state = c_state;

        case (c_state)
            IDLE: begin
                if (PSEL) begin // Master state: SETUP
                    n_state = SETUP;
                end
            end
            SETUP: begin
                if (PENABLE) begin  // Master state: ACCESS
                    Ready   = 0;
                    n_state = ACCESS;
                end
            end
            ACCESS: begin
                PADDR_RAM = PADDR;
                PWRITE_RAM = PWRITE;
                Ready   = 1;
                n_state = IDLE;
            end
        endcase
    end

    data_ram RAM (
        .clk(PCLK),
        .dwe(PWRITE_RAM),
        .daddr(PADDR_RAM),
        .data_in(PWDATA),
        .data_out(PRDATA)
    );
    
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
            dmem[daddr[31:2]] <= data_in;
        end
    end

    assign data_out = dmem[daddr[31:2]];
endmodule
