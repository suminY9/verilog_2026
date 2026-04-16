`timescale 1ns / 1ps

module i2c_slave (
    input  logic       clk,
    input  logic       reset,
    // I2C port
    input  logic       scl,
    inout  logic       sda,
    // internal signal
    output logic [7:0] reg_data_out,
    output logic       reg_we
);

    // slave address
    localparam slave_ADDR = 7'b100_0000;

    // synchronizer
    logic scl_sync0, scl_sync1;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            scl_sync0 <= 1'b0;
            scl_sync1 <= 1'b0;
        end else begin
            scl_sync0 <= scl;
            scl_sync1 <= scl_sync0;
        end
    end
    assign scl_pose = (scl_sync0 && ~scl_sync1) ? 1 : 0;
    assign scl_nege = (~scl_sync0 && scl_sync1) ? 1 : 0;


    /**** to Master ****/
    typedef enum logic [2:0] {
        IDLE = 3'd0,
        START,
        ADDR,
        ACK_ADDR,
        DATA,
        ACK_DATA,
        STOP
    } slave_state_e;
    slave_state_e state;

    logic [3:0] bit_cnt;
    logic [7:0] shift_reg;
    logic sda_out, sda_en;

    assign sda = sda_en ? (sda_out ? 1'bz : 1'b0) : 1'bz;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state  <= IDLE;
        end else begin
            case (state) 
                ADDR: begin
                end
                ACK_ADDR: begin
                    
                end
                DATA: begin
                    
                end
                ACK_DATA: begin

                end
            endcase
        end
    end
endmodule