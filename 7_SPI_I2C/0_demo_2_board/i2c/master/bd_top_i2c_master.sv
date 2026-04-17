`timescale 1ns / 1ps

module board_top_i2c_master (
    input  logic       clk,
    input  logic       reset,
    input  logic       btn,         // btn_r
    input  logic       WR,          // sw[15]
    input  logic [7:0] tx_data,     // sw[7:0]
    output wire        scl,
    inout  logic       sda,
    // led output
    output logic [7:0] led,         // led[7:0]
    output logic ack_out            // led[15]
);

    logic o_btn;
    logic cmd_start, cmd_write, cmd_read, cmd_stop, done, busy;
    logic [7:0] i_tx_data;

    typedef enum logic [2:0] {
        IDLE = 3'd0,
        START,
        ADDR,
        WRITE,
        READ,
        STOP,
        DONE
    } btn_state_e;
    btn_state_e state;

    always_ff @(posedge clk, posedge reset) begin
        if(reset) begin
            state <= IDLE;
            cmd_start <= 0;
            cmd_write <= 0;
            cmd_read  <= 0;
            cmd_stop  <= 0;
        end else begin
            cmd_start <= 0;
            cmd_write <= 0;
            cmd_read  <= 0;
            cmd_stop  <= 0;

            case (state)
                IDLE: begin
                    if(o_btn) begin
                        state <= START;
                        cmd_start <= 1'b1;
                    end
                end
                START: begin
                    if(done) begin
                        state <= ADDR;
                        i_tx_data <= {7'b100_0000, WR}; // addr
                        cmd_write <= 1'b1;
                    end
                end
                ADDR: begin
                    if(done) begin
                        if(WR == 0) begin
                            state <= WRITE;
                            i_tx_data <= tx_data; // send data
                            cmd_write <= 1'b1;
                        end else begin
                            state <= READ;
                            cmd_read <= 1'b1;
                        end
                    end
                end
                WRITE, READ: begin
                    if(done) begin
                        state <= STOP;
                        cmd_stop <= 1'b1;
                    end
                end
                STOP: begin
                    if(done) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    btn_debounce U_BTN_DEB (
        .clk(clk),
        .reset(reset),
        .i_btn(btn),
        .o_btn(o_btn)
    );
    I2C_Master U_I2C_MASTER (
        .clk(clk),
        .reset(reset),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read(cmd_read),
        .cmd_stop(cmd_stop),
        .tx_data(i_tx_data),
        .ack_in(0),
        .rx_data(led),
        .done(done),
        .ack_out(ack_out),
        .busy(busy),
        .scl(scl),
        .sda(sda)
    );
endmodule
