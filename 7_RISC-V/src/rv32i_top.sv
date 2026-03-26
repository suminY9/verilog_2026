`timescale 1ns / 1ps

module rv32i_mcu (
    input          clk,
    input          rst,
    output  [15:0] LED
);

    logic [2:0] funct3;
    logic [31:0] instr_addr, instr_data; //daddr, dwdata, drdata;
    //APB_bus
    logic [31:0] bus_addr, bus_wdata, bus_rdata;
    logic [31:0] paddr, pwdata;
    logic bus_wreq, bus_rreq, bus_ready, penable, pwrite;
    //APB_slave
    logic psel0, psel1, psel2, psel3, psel4, psel5;
    logic pready0, pready1, pready2, pready3, pready4, pready5;
    logic [31:0] prdata0, prdata1, prdata2, prdata3, prdata4, prdata5;

    instruction_mem U_INSTRUCTION_MEM (.*);
    rv32i_cpu U_RV32I (.*);
    APB_Master U_APB_MASTER (
        .PCLK(clk),
        .PRESET(rst),
        .Addr(bus_addr),
        .Wdata(bus_wdata),
        .WREQ(bus_wreq),
        .RREQ(bus_rreq),
        //.SlvERR(),
        .Rdata(bus_rdata),
        .Ready(bus_ready),
        .PADDR(paddr),
        .PWDATA(pwdata),
        .PSEL0(psel0),
        .PSEL1(psel1),
        .PSEL2(psel2),
        .PSEL3(psel3),
        .PSEL4(psel4),
        .PSEL5(psel5),
        .PENABLE(penable),
        .PWRITE(pwrite),
        .PRDATA0(prdata0),
        .PRDATA1(prdata1),
        .PRDATA2(prdata2),
        .PRDATA3(prdata3),
        .PRDATA4(prdata4),
        .PRDATA5(prdata5),
        .PREADY0(pready0),
        .PREADY1(pready1),
        .PREADY2(pready2),
        .PREADY3(pready3),
        .PREADY4(pready4),
        .PREADY5(pready5)
    );
    BRAM U_BRAM (
        .PCLK(clk),
        .PADDR(paddr),
        .PWDATA(pwdata),
        .PENABLE(penable),
        .PWRITE(pwrite),
        .PSEL(psel0),
        .PRDATA(prdata0),
        .PREADY(pready0)
    );
    APB_GPO U_APB_GPO (
        .PCLK(clk),
        .PRESET(rst),
        .PADDR(paddr),
        .PWDATA(pwdata),
        .PENABLE(penable),
        .PWRITE(pwrite),
        .PSEL(psel1),
        .PRDATA(prdata1),
        .PREADY(pready1),
        .GPO_OUT(LED)
    );
    //data_mem U_DATA_MEM (
    //    .clk(clk),
    //    .rst(rst),
    //    .dwe(bus_wreq),
    //    .funct3(funct3),
    //    .daddr(bus_addr),
    //    .dwdata(bus_wdata),
    //    .drdata(bus_rdata)
    //);
endmodule
