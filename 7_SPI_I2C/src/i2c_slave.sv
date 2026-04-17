`timescale 1ns / 1ps

module i2c_slave (
    input  logic       clk,
    input  logic       reset,
    // I2C port
    input  logic       scl,
    inout  logic       sda,
    // internal signal
    output logic [7:0] i_data,
    output logic       i_done
);

    // slave address
    localparam slave_ADDR = 7'b100_0000;

    // synchronizer
    logic scl_sync0, scl_sync1;
    logic sda_sync0, sda_sync1;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            scl_sync0 <= 1'b0;
            scl_sync1 <= 1'b0;
            sda_sync0 <= 1'b0;
            sda_sync1 <= 1'b0;
        end else begin
            scl_sync0 <= scl;
            scl_sync1 <= scl_sync0;
            sda_sync0 <= sda;
            sda_sync1 <= sda_sync0;
        end
    end
    assign scl_pose = (scl_sync0 && ~scl_sync1) ? 1 : 0;
    assign scl_nege = (~scl_sync0 && scl_sync1) ? 1 : 0;
    assign sda_pose = (sda_sync0 && ~sda_sync1) ? 1 : 0;
    assign sda_nege = (~sda_sync0 && sda_sync1) ? 1 : 0;


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
            i_data <= 8'h00;
            i_done <= 1'b0;
        end else begin
            if (state == DATA && bit_cnt == 8 && scl_nege) begin
                i_data <= shift_reg;
                i_done <= 1'b1;
            end else begin
                i_done <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            bit_cnt   <= 0;
            sda_out   <= 1;
            sda_en    <= 0;
            shift_reg <= 0;
        end else begin
            if (scl_sync1 && sda_nege) begin
                state   <= ADDR;
                bit_cnt <= 0;
                sda_en  <= 0;
            end else if (scl_sync1 && sda_pose) begin
                state  <= IDLE;
                sda_en <= 1'b0;
            end else begin
                case (state)
                    IDLE: begin
                        sda_en <= 1'b0;
                    end
                    ADDR: begin
                        if (scl_pose) begin
                            shift_reg <= {shift_reg[6:0], sda_sync1};
                            bit_cnt   <= bit_cnt + 1;
                        end
                        if (bit_cnt == 8 && scl_nege) begin
                            bit_cnt <= 0;
                            if (shift_reg[7:1] == slave_ADDR) begin
                                state   <= ACK_ADDR;
                                sda_en  <= 1'b1;
                                sda_out <= 1'b0;
                            end else begin
                                state <= IDLE;
                            end
                        end
                    end
                    ACK_ADDR: begin
                        if (scl_nege) begin
                            sda_en <= 1'b0;
                            state  <= DATA;
                        end
                    end
                    DATA: begin
                        if (scl_pose) begin
                            shift_reg <= {shift_reg[6:0], sda_sync1};
                            bit_cnt   <= bit_cnt + 1;
                        end
                        if (bit_cnt == 8 && scl_nege) begin
                            bit_cnt <= 0;
                            state   <= ACK_DATA;
                            sda_en  <= 1'b1;
                            sda_out <= 1'b0;
                        end
                    end
                    ACK_DATA: begin
                        if (scl_nege) begin
                            sda_en <= 1'b0;
                            state  <= DATA;
                        end
                    end
                endcase
            end
        end
    end
endmodule
