`timescale 1ns / 1ps

module rv32I_mcu (
    input         clk,
    input         rst,
    input  [7:0] GPI,
    output [7:0] GPO,
    inout  [15:0] GPIO,


    //fnd output
    output [3:0] fnd_digit,
    output [7:0] fnd_data,


    //uart
    input  uart_rx,
    output uart_tx



);

    logic [2:0] o_funct3;
    logic [31:0] instr_addr, instr_data, bus_addr, bus_wdata, bus_rdata;
    logic bus_wreq, bus_rreq, bus_ready;
    logic [31:0] PADDR, PWDATA;
    logic PENABLE, PWRITE;
    logic PSEL0, PSEL1, PSEL2, PSEL3, PSEL4, PSEL5;
    logic PREADY0, PREADY1, PREADY2, PREADY3, PREADY4, PREADY5;
    logic [31:0] PRDATA0, PRDATA1, PRDATA2, PRDATA3, PRDATA4, PRDATA5;



    instruction_mem U_INSTRUTION_MEM (.*);
    rv32i_cpu U_RV32I (
        .*,
        .o_funct3(o_funct3)
    );

    APB_Master U_APB_MASTER (
        //BUS global signal
        .PCLK  (clk),
        .PRESET(rst),


        //Soc internal signal with cpu
        .addr (bus_addr),
        .Wdata(bus_wdata),
        .WREQ (bus_wreq),   //from cpu with request, signal cpu : dwe
        .RREQ (bus_rreq),   //from cpu, read request, signal cpu : dre
        //output        SlvERR,
        .Rdata(bus_rdata),
        .Ready(bus_ready),


        //APB Interface signal
        .PADDR  (PADDR),
        .PWDATA (PWDATA),
        .PWRITE (PWRITE),
        .PENABLE(PENABLE),
        .PSEL0  (PSEL0),    //RAM
        .PSEL1  (PSEL1),    //GPO
        .PSEL2  (PSEL2),    //GPI
        .PSEL3  (PSEL3),    //GPIO
        .PSEL4  (PSEL4),    //FND
        .PSEL5  (PSEL5),    //UART



        .PRDATA0(PRDATA0),  //RAM
        .PRDATA1(PRDATA1),  //GPO
        .PRDATA2(PRDATA2),  //GPI
        .PRDATA3(PRDATA3),  //GPIO
        .PRDATA4(PRDATA4),  //FND
        .PRDATA5(PRDATA5),  //UART

        .PREADY0(PREADY0),  //RAM
        .PREADY1(PREADY1),  //GPO
        .PREADY2(PREADY2),  //GPI
        .PREADY3(PREADY3),  //GPIO
        .PREADY4(PREADY4),  //FND
        .PREADY5(PREADY5)   //UART

    );

    BRAM U_BRAM (
        .*,
        .PCLK  (clk),
        .PSEL  (PSEL0),    //RAM
        .PRDATA(PRDATA0),  //RAM
        .PREADY(PREADY0)   //RAM
    );

    APB_GPO U_APB_GPO (
        .PCLK   (clk),
        .PRESET (rst),
        .PADDR  (PADDR),
        .PWDATA (PWDATA),
        .PENABLE(PENABLE),
        .PWRITE (PWRITE),
        .PSEL   (PSEL1),
        .PRDATA (PRDATA1),
        .PREADY (PREADY1),
        .GPO_OUT(GPO)
    );

    APB_GPI U_APB_GPI (

        .PCLK   (clk),
        .PRESET (rst),
        .PADDR  (PADDR),
        .PWDATA (PWDATA),
        .PENABLE(PENABLE),
        .PWRITE (PWRITE),
        .PSEL   (PSEL2),
        .GPI    (GPI),
        .PRDATA (PRDATA2),
        .PREADY (PREADY2)
    );

    APB_GPIO U_APB_GPIO (

        .PCLK   (clk),
        .PRESET (rst),
        .PADDR  (PADDR),
        .PWDATA (PWDATA),
        .PENABLE(PENABLE),
        .PWRITE (PWRITE),
        .PSEL   (PSEL3),
        .PRDATA (PRDATA3),
        .PREADY (PREADY3),
        .GPIO   (GPIO)
    );

    APB_FND U_APB_FND (
        .PCLK     (clk),
        .PRESET   (rst),
        .PADDR    (PADDR),
        .PWDATA   (PWDATA),
        .PENABLE  (PENABLE),
        .PWRITE   (PWRITE),
        .PSEL     (PSEL4),
        .PRDATA   (PRDATA4),
        .PREADY   (PREADY4),
        .fnd_digit(fnd_digit),
        .fnd_data (fnd_data)
    );

    APB_UART U_APB_UART (
        .PCLK   (clk),
        .PRESET (rst),
        .PADDR  (PADDR),
        .PWDATA (PWDATA),
        .PENABLE(PENABLE),
        .PWRITE (PWRITE),
        .PSEL   (PSEL5),
        .PRDATA (PRDATA5),
        .PREADY (PREADY5),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx)
    );
endmodule
