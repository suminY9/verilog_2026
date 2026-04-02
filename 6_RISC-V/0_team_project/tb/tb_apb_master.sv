`timescale 1ns / 1ps

module tb_apb_master ();
    logic        PCLK;
    logic        PRESETn;
    logic [31:0] addr;
    logic [31:0] Wdata;
    logic        WREQ;
    logic        RREQ;

    logic [31:0] Rdata;
    logic        Ready;



    logic [31:0] PADDR, PWDATA;
    logic PWRITE, PENABLE;
    logic PSEL0, PSEL1, PSEL2, PSEL3, PSEL4, PSEL5;

    logic [31:0] PRDATA0;
    logic [31:0] PRDATA1;
    logic [31:0] PRDATA2;
    logic [31:0] PRDATA3;
    logic [31:0] PRDATA4;
    logic [31:0] PRDATA5;

    logic PREADY0;
    logic PREADY1;
    logic PREADY2;
    logic PREADY3;
    logic PREADY4;
    logic PREADY5;

    APB_Master dut (.*);

    always #5 PCLK = ~PCLK;

    initial begin
        PCLK = 0;
        PRESETn = 0;

        @(negedge PCLK);
        @(negedge PCLK);
        PRESETn = 1;

        //RAM write Test, 0x1000_0000
        @(posedge PCLK);
        #1;
        WREQ  = 1'b1;
        addr  = 32'h1000_0000;
        Wdata = 32'h0000_0041;

        //@(posedge PCLK);
        //#1;

        @(PSEL0 && PENABLE);
        PREADY0 = 1'b1;
        @(posedge PCLK);
        #1;
        PREADY0 = 1'b0;
        WREQ = 1'b0;

        ////////////////////////// UART Read Test , 0x//////////////////////////////
        
        @(posedge PCLK);
        #1;
        RREQ = 1'b1;
        addr = 32'h2000_4000;

        @(PSEL5 && PENABLE);
        @(posedge PCLK);
        @(posedge PCLK);
        #1;
        PREADY5 = 1'b1;
        PRDATA5 = 32'h0000_0041;
        @(posedge PCLK);
        #1;
        PREADY5 = 1'b0;
        RREQ = 1'b0;

        @(posedge PCLK);
        @(posedge PCLK);
        $stop;
    end
endmodule
