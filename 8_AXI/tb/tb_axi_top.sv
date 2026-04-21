`timescale 1ns / 1ps

module tb_axi_top ();
    logic        ACLK;
    logic        ARESETn;
    logic        transfer;
    logic        ready;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic        write;
    logic [31:0] rdata;

    top_axi4_lite dut (.*);

    always #5 ACLK = ~ACLK;

    task axi_write(logic [31:0] address, logic [31:0] data);
        addr     <= address;
        wdata    <= data;
        write    <= 1'b1;
        transfer <= 1'b1;
        @(posedge ACLK);
        transfer <= 1'b0;
        do @(posedge ACLK); while (!ready);
    endtask
    task axi_read(logic [31:0] address);
        addr     <= address;
        write    <= 1'b0;
        transfer <= 1'b1;
        @(posedge ACLK);
        transfer <= 1'b0;
        do @(posedge ACLK); while (!ready);
    endtask

    initial begin
        ACLK    = 0;
        ARESETn = 0;
        repeat (3) @(posedge ACLK);
        ARESETn = 1;
        repeat (3) @(posedge ACLK);

        repeat (3) @(posedge ACLK);
        axi_write(32'h0000_0000, 32'h1111_1111);
        @(posedge ACLK);
        axi_write(32'h0000_0004, 32'h2222_2222);
        @(posedge ACLK);
        axi_write(32'h0000_0008, 32'h3333_3333);
        @(posedge ACLK);
        axi_write(32'h0000_000c, 32'h4444_4444);
        @(posedge ACLK);

        axi_read(32'h0000_0000);
        @(posedge ACLK);
        axi_read(32'h0000_0004);
        @(posedge ACLK);
        axi_read(32'h0000_0008);
        @(posedge ACLK);
        axi_read(32'h0000_000c);
        @(posedge ACLK);

        repeat(10) @(posedge ACLK);
        $finish;
    end
endmodule
