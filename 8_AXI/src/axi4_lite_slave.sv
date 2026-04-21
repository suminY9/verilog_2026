`timescale 1ns / 1ps

module axi4_lite_slave (
    // Global Signals
    input  logic        ACLK,
    input  logic        ARESETn,
    // AW channel
    input  logic [31:0] AWADDR,
    input  logic        AWVALID,
    output logic        AWREADY,
    // W channel
    input  logic [31:0] WDATA,
    input  logic        WVALID,
    output logic        WREADY,
    // B channel
    output logic [ 1:0] BRESP,
    output logic        BVALID,
    input  logic        BREADY,
    // AR channel
    input  logic [31:0] ARADDR,
    input  logic        ARVALID,
    output logic        ARREADY,
    // R channel
    output logic [31:0] RDATA,
    output logic        RVALID,
    input  logic        RREADY,
    output logic [ 1:0] RRESP
);

    bit [31:0] write_addr, read_addr;
    bit [31:0] wdata, rdata;
    bit [31:0] slave_register[0:31];

    bit w_addr_done, write_done;
    bit r_addr_done, read_done;

    assign RDATA = rdata;
    assign RRESP = 2'b00; // always okay

    /******************** WRITE TRANSACTION **********************/

    // AW Channel
    typedef enum {
        AW_IDLE,
        AW_BUSY
    } aw_state_e;
    aw_state_e aw_state;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            aw_state   <= AW_IDLE;
            write_addr <= 32'b0;
            AWREADY    <= 1'b1;
            w_addr_done  <= 1'b0;
        end else begin
            case (aw_state)
                AW_IDLE: begin
                    if (AWVALID & AWREADY) begin
                        write_addr  <= AWADDR;
                        AWREADY     <= 1'b0;
                        w_addr_done <= 1'b1;
                        aw_state    <= AW_BUSY;
                    end
                end
                AW_BUSY: begin
                    if (write_done) begin
                        AWREADY     <= 1'b1;
                        w_addr_done <= 1'b0;
                        aw_state <= AW_IDLE;
                    end
                end
            endcase
        end
    end

    // W channel
    typedef enum {
        W_IDLE,
        W_BUSY,
        W_WRITE
    } w_state_e;
    w_state_e w_state;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            w_state    <= W_IDLE;
            wdata      <= 32'b0;
            WREADY     <= 1'b1;
            write_done <= 1'b0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    if (WVALID & WREADY) begin
                        wdata   <= WDATA;
                        WREADY  <= 1'b0;
                        w_state <= W_BUSY;
                    end
                end
                W_BUSY: begin
                    if (w_addr_done) begin
                        slave_register[write_addr[7:2]] <= wdata; // byte addressing
                        write_done <= 1'b1;
                        w_state    <= W_WRITE;
                    end
                end
                W_WRITE: begin
                    WREADY     <= 1'b1;
                    w_state    <= W_IDLE;
                end
            endcase
        end
    end

    // B channel
    typedef enum {
        B_IDLE,
        B_BUSY
    } b_state_e;
    b_state_e b_state;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            b_state <= B_IDLE;
            BVALID  <= 1'b0;
        end else begin
            case (b_state)
                B_IDLE: begin
                    if (write_done) begin
                        BRESP   <= 2'b00;  // always okay
                        BVALID  <= 1'b1;
                        b_state <= B_BUSY;
                    end
                end
                B_BUSY: begin
                    BVALID  <= 1'b0;
                    b_state <= B_IDLE;
                end
            endcase
        end
    end


    /******************** READ TRANSACTION **********************/

    // AR channel
    typedef enum {
        AR_IDLE,
        AR_BUSY
    } ar_state_e;
    ar_state_e ar_state;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            ar_state <= AR_IDLE;
            ARREADY  <= 1'b1;
        end else begin
            case (ar_state)
                AR_IDLE: begin
                    if (ARVALID) begin
                        read_addr   <= ARADDR;
                        ARREADY     <= 1'b0;
                        r_addr_done <= 1'b1;
                        ar_state    <= AR_BUSY;
                    end
                end
                AR_BUSY: begin
                    if (read_done) begin
                        ARREADY     <= 1'b1;
                        r_addr_done <= 1'b0;
                        ar_state    <= AR_IDLE;
                    end
                end
            endcase
        end
    end

    // R channel
    typedef enum {
        R_IDLE,
        R_BUSY,
        R_READ
    } r_state_e;
    r_state_e r_state;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            r_state   <= R_IDLE;
            rdata     <= 32'b0;
            RVALID    <= 1'b0;
            read_done <= 1'b0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    RVALID <= 1'b0;
                    if (r_addr_done) begin
                        r_state <= R_BUSY;
                    end
                end
                R_BUSY: begin
                    rdata     <= slave_register[read_addr[7:2]]; // byte addressing
                    read_done <= 1'b1;
                    r_state   <= R_READ;
                end
                R_READ: begin
                    read_done <= 1'b0;
                    RVALID    <= 1'b1;
                    if(RREADY) begin
                        r_state   <= R_IDLE;
                    end
                end
            endcase
        end
    end
endmodule
