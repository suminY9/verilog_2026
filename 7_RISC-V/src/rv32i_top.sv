`timescale 1ns / 1ps

module rv32i_mcu (
    input         clk,
    input         rst,
    output [15:0] led
);

    logic [2:0] funct3;
    logic [31:0] instr_addr, instr_data; //daddr, dwdata, drdata;
    //APB_bus
    logic [31:0] bus_addr, bus_wdata, bus_rdata;
    logic bus_wreq, bus_rreq, bus_ready;

    instruction_mem U_INSTRUCTION_MEM (.*);
    rv32i_cpu U_RV32I (.*);
    APB_Master U_APB_MASTER (
        .PCLK(clk),
        .PRESETn(rst),
        .Addr(bus_addr),
        .Wdata(bus_wdata),
        .WREQ(bus_wreq),
        .RREQ(bus_rreq),
        //.SlvERR(),
        .Rdata(bus_rdata),
        .Ready(bus_ready),
        .PADDR(),
        .PWDATA(),
        .PSEL0(),
        .PSEL1(),
        .PSEL2(),
        .PSEL3(),
        .PSEL4(),
        .PSEL5(),
        .PENABLE(),
        .PWRITE(),
        .PRDATA0(),
        .PRDATA1(),
        .PRDATA2(),
        .PRDATA3(),
        .PRDATA4(),
        .PRDATA5(),
        .PREADY0(),
        .PREADY1(),
        .PREADY2(),
        .PREADY3(),
        .PREADY4(),
        .PREADY5()
    );
    data_mem U_DATA_MEM (
        .clk(clk),
        .rst(rst),
        .dwe(bus_wreq),
        .funct3(funct3),
        .daddr(bus_addr),
        .dwdata(bus_wdata),
        .drdata(bus_rdata)
    );
endmodule
