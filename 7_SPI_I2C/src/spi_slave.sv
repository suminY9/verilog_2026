`timescale 1ns / 1ps

module spi_slave (
    // master
    input  logic       clk,
    input  logic       reset,
    input  logic       SCLK,
    input  logic       MOSI,
    output logic       MISO,
    input  logic       SS,
    // logic
    output logic       i_done,
    output logic [7:0] i_data
);

    // synchronizer
    logic sclk_sync0, sclk_sync1;
    logic sclk_posedge, sclk_negedge;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sclk_sync0 <= 0;
            sclk_sync1 <= 0;
        end else begin
            sclk_sync0 <= SCLK;
            sclk_sync1 <= sclk_sync0;
        end
    end
    assign sclk_posedge = sclk_sync0 & ~sclk_sync1;
    assign sclk_negedge = ~sclk_sync0 & sclk_sync1;


    /**** to Master ****/
    typedef enum logic {
        IDLE = 1'b0,
        DATA = 1'b1
    } input_state_e;

    input_state_e state;
    // to Master
    logic [7:0] tx_shift_reg, rx_shift_reg, data_reg;
    logic [2:0] bit_cnt;
    logic done;
    
    assign i_done = done;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt      <= 3'b0;
            done         <= 1'b0;
            MISO         <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    bit_cnt <= 3'b0;
                    if (!SS) begin
                        state <= DATA;
                        MISO <= tx_shift_reg[7];
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                    end
                end
                DATA: begin
                    if (SS) begin
                        state <= IDLE;
                    end else begin
                        if (sclk_posedge) begin
                            rx_shift_reg <= {rx_shift_reg[6:0], MOSI};

                            if (bit_cnt == 3'd7) begin
                                state <= IDLE;
                                done  <= 1'b1;
                                i_data <= {rx_shift_reg[6:0], MOSI};
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                        if (sclk_negedge) begin
                            MISO <= tx_shift_reg[7];
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        end
                    end
                end
            endcase
        end
    end
endmodule
