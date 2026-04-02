`timescale 1ns / 1ps

module tb_apb_master();

    logic PCLK, PRESETn;
    logic [31:0] Addr, Rdata, Wdata;
    logic WREQ, RREQ, Ready;
    logic [31:0] PADDR;
    logic [31:0] PWDATA;
    logic        PENABLE;
    logic        PWRITE;
    logic        PSEL0;    // RAM
    logic        PSEL1;    // GPO
    logic        PSEL2;    // GPI
    logic        PSEL3;    // GPIO
    logic        PSEL4;    // FND
    logic        PSEL5;    // UART
    logic [31:0] PRDATA0;  // from RAM 
    logic [31:0] PRDATA1;  // from GPO
    logic [31:0] PRDATA2;  // from GPI
    logic [31:0] PRDATA3;  // from GPIO
    logic [31:0] PRDATA4;  // from FND
    logic [31:0] PRDATA5;  // from UART
    logic        PREADY0;  // from RAM
    logic        PREADY1;  // from GPO
    logic        PREADY2;  // from GPI
    logic        PREADY3;  // from GPIO
    logic        PREADY4;  // from FND
    logic        PREADY5;

    APB_Master dut (.*);

    always #5 PCLK = ~PCLK;

    initial begin
        PCLK = 0;
        PRESETn = 0; // Reset
        
        @(negedge PCLK);
        @(negedge PCLK);
        PRESETn = 1; // not reset

        // RAM WRITE TEST, 0x1000_0000
        // T1
        // delay after posedge + 1ns
        @(posedge PCLK);
        #1;
        Addr  = 32'h1000_0000;
        Wdata = 32'h0000_0041; // 'a'
        WREQ  = 1'b1;
        
        // T2
        @(PSEL0 & PENABLE);
            PREADY0 = 1'b1;

        // T3
        @(posedge PCLK);
        #1;
        PREADY0 = 1'b0;
        WREQ = 1'b0;

        // UART READ Test, 0x2000_4000, waiting 2 cycle
        @(posedge PCLK);
        #1;
        RREQ = 1'b1;
        Addr = 32'h2000_4000;

        @(PSEL5 && PENABLE);
        @(posedge PCLK);
        @(posedge PCLK);
        #1;
            PREADY5 = 1'b1;
            PRDATA5 = 32'h0000_0041; // 'a'
        @(posedge PCLK);
        #1;
        PREADY5 = 1'b0;
        RREQ = 1'b0;

        @(posedge PCLK);
        @(posedge PCLK);
        $stop;
    end
endmodule
