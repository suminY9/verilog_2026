`timescale 1ns / 1ps

module tb_i2c_master();
    logic       clk;
    logic       reset;
    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic       cmd_stop;
    logic [7:0] tx_data;
    logic       ack_in;
    logic [7:0] rx_data;
    logic       done;
    logic       ack_out;
    logic       busy;
    logic       scl;
    wire        sda;

    // pull-up resistance
    assign scl = 1'b1;
    // assign sda = 1'b1;

    localparam SLA = 8'h12;

    top_I2C_Master dut (.*);

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        repeat(3) @(posedge clk);
        reset = 0;
        @(posedge clk);

        // start
        cmd_start = 1'b1;
        cmd_write = 1'b0;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait(done);
        @(posedge clk);

        // tx_data = address & R/W
        tx_data = (SLA << 1) + 1'b0; 
        cmd_start = 1'b0;
        cmd_write = 1'b1;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait(done);
        @(posedge clk);

        // tx_data = data
        tx_data = 8'h55;
        cmd_start = 1'b0;
        cmd_write = 1'b1;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait(done);
        @(posedge clk);

        // stop 
        cmd_start = 1'b0;
        cmd_write = 1'b0;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b1;
        @(posedge clk);
        wait(done);
        @(posedge clk);

        // IDLE state
        #100;
        $finish;
    end 
endmodule
