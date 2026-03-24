`timescale 1ns / 1ps

module rv32i_apb ();
endmodule


module apb_master (
    input               pclk,
    input               presetn,
    input        [31:0] addr,
    input        [31:0] wdata,
    input               wreq,
    input               rreq,
    output       [31:0] paddr,
    output       [31:0] pwdata,
    output       [ 5:0] psel,
    output logic        penable,
    output              pwrite, //direction. 1: write, 0: read
    input               psuerr0,
    input        [31:0] prdata0,
    input        [31:0] prdata1,
    input        [31:0] prdata2,
    input        [31:0] prdata3,
    input        [31:0] prdata4,
    input        [31:0] prdata5,
    input        [31:0] prdata6,
    input               pready0,
    output              suerr,
    output       [31:0] rdata,
    output              ready
);

    register U_REG_ADDR (
        .clk(pclk),
        .rst(presetn),
        .data_in(addr),
        .data_out(paddr)
    );
    register U_REG_WDATA (
        .clk(pclk),
        .rst(presetn),
        .data_in(wdata),
        .data_out(pwdata)
    );
    decoder U_ADDRESS_DECODER (
        .addr (paddr),
        .psel0(psel[0]),
        .psel1(psel[1]),
        .psel2(psel[2]),
        .psel3(psel[3]),
        .psel4(psel[4]),
        .psed5(psel[5]),
        .psel6(psel[6])
    );
    mux_7x1 U_MUX_RDATA (
        .addr  (paddr),
        .rdata0(prdata0),
        .rdata1(prdata1),
        .rdata2(prdata2),
        .rdata3(prdata3),
        .rdata4(prdata4),
        .rdata5(prdata5),
        .rdata6(prdata6),
        .rdata (rdata)
    );

    typedef enum {
        IDLE,
        SETUP,
        ACCESS
    } state;

    state n_state, c_state;

    always_ff @(posedge pclk, posedge presetn) begin
        if (presetn) begin
            c_state <= IDLE;
        end else begin
            c_state <= n_state;
        end
    end

    always_comb begin
        n_state = c_state;
        case (c_state)
            IDLE: begin

            end
            SETUP: begin
                penable = 1'b0;
            end
            ACCESS: begin
                penable = 1'b1;
            end
        endcase
    end

endmodule

/***** SUB MODULE *****/
module apb_slave (
    input  [31:0] daddr,
    input  [31:0] wdata,
    input         sel,
    output [31:0] rdata
);

endmodule


module register (
    input               clk,
    input               rst,
    input        [31:0] data_in,
    output logic [31:0] data_out
);
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            data_out <= 32'b0;
        end else begin
            data_out <= data_in;
        end
    end
endmodule


module decoder (
    input        [31:0] addr,
    output logic        psel0,
    output logic        psel1,
    output logic        psel2,
    output logic        psel3,
    output logic        psel4,
    output logic        psel5,
    output logic        psel6
);

    always_comb begin
        psel0 = 1'b0;
        psel1 = 1'b0;
        psel2 = 1'b0;
        psel3 = 1'b0;
        psel4 = 1'b0;
        psel5 = 1'b0;
        psel6 = 1'b0;

        case (addr[31:28])
            0000: psel0 = 1'b1;  //ROM
            0001: psel1 = 1'b1;  //RAM
            0010: begin
                case (addr[15:12])
                    0000: psel2 = 1'b1;  // GPO
                    0001: psel3 = 1'b1;  // GPI
                    0010: psel4 = 1'b1;  // GPIO
                    0011: psel5 = 1'b1;  // FND
                    0100: psel6 = 1'b1;  // UART
                endcase
            end
        endcase
    end
endmodule


module mux_7x1 (
    input        [31:0] addr,
    input        [31:0] rdata0,
    input        [31:0] rdata1,
    input        [31:0] rdata2,
    input        [31:0] rdata3,
    input        [31:0] rdata4,
    input        [31:0] rdata5,
    input        [31:0] rdata6,
    output logic [31:0] rdata
);

    always_comb begin
        case (addr[31:28])
            0000: assign rdata = rdata0;  //ROM
            0001: assign rdata = rdata1;  //RAM
            0010: begin
                case (addr[15:12])
                    0000: assign rdata = rdata2;  // GPO
                    0001: assign rdata = rdata3;  // GPI
                    0010: assign rdata = rdata4;  // GPIO
                    0011: assign rdata = rdata5;  // FND
                    0100: assign rdata = rdata6;  // UART
                endcase
            end
        endcase
    end
endmodule
