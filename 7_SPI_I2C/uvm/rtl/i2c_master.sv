`timescale 1ns / 1ps

module I2C_Master(
    input  logic       clk,
    input  logic       reset,
    // command port
    input  logic       cmd_start,
    input  logic       cmd_write,
    input  logic       cmd_read,
    input  logic       cmd_stop,
    input  logic [7:0] tx_data,
    input  logic       ack_in,
    // internal output
    output logic [7:0] rx_data,
    output logic       done,
    output logic       ack_out,
    output logic       busy,
    // external i2c port
    output logic       scl,
    inout  wire        sda
);

    logic sda_o, sda_i;

    assign sda_i = sda;
    assign sda = sda_o ? 1'bz : 1'b0;   // tri-state buffer

    // 상위 모듈에서는 .*(wildcard)를 쓰되 sda_o, sda_i만 명시적으로 연결
    i2c_master U_I2C_MASTER (
        .*,
        .sda_o(sda_o),
        .sda_i(sda_i)
    );
endmodule


module i2c_master (
    input  logic       clk,
    input  logic       reset,
    // command port
    input  logic       cmd_start,
    input  logic       cmd_write,
    input  logic       cmd_read,
    input  logic       cmd_stop,
    input  logic [7:0] tx_data,
    input  logic       ack_in,
    // internal output
    output logic [7:0] rx_data,
    output logic       done,
    output logic       ack_out,
    output logic       busy,
    // external i2c port
    output logic       scl,
    output logic       sda_o,
    input  logic       sda_i
);

    typedef enum logic [2:0] {
        IDLE = 3'b000,
        START,
        WAIT_CMD,
        DATA,
        ACK,
        STOP
    } i2c_state_e;

    // register & signals
    i2c_state_e state;
    logic [7:0] div_cnt;
    logic qtr_tick;
    logic [2:0] bit_cnt;
    logic scl_r, sda_r, ack_in_r;
    logic [7:0] tx_shift_reg;
    logic [7:0] rx_shift_reg;
    logic [1:0] step;
    logic is_read;

    assign scl   = scl_r;
    assign sda_o = sda_r;
    assign busy  = (state != IDLE);

    // ---------------------------------------------------------
    // 1. 분주기(Clock Divider) 블록 - div_cnt 할당은 여기서만 수행!
    // ---------------------------------------------------------
    // 1. 분주기 블록 - 리셋 조건을 명령 진입 시점으로 단순화
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            div_cnt  <= 0;
            qtr_tick <= 1'b0;
        end else begin
            // IDLE 상태일 때만 리셋을 유지합니다. 
            // IDLE을 벗어나는 순간(START 상태 진입)부터 카운트가 바로 시작됩니다.
            if (state == IDLE) begin
                div_cnt  <= 0;
                qtr_tick <= 1'b0;
            end else if (div_cnt == 250 - 1) begin
                div_cnt  <= 0;
                qtr_tick <= 1'b1;
            end else begin
                div_cnt  <= div_cnt + 1;
                qtr_tick <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------
    // 2. 메인 상태 머신 (FSM) 블록
    // ---------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            scl_r        <= 1'b1;
            sda_r        <= 1'b1;
            step         <= 0;
            done         <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            is_read      <= 1'b0;
            bit_cnt      <= 0;
            ack_out      <= 1'b0;
            rx_data      <= 8'h00;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    scl_r <= 1'b1;
                    sda_r <= 1'b1;
                    step  <= 0;
                    if (cmd_start) state <= START;
                end

                START: begin
                    // START 진입 직후 qtr_tick이 오기 전이라도 기본값(1,1)을 유지하게 함
                    if (step == 0 && !qtr_tick) begin
                        scl_r <= 1'b1;
                        sda_r <= 1'b1;
                    end
                    
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin scl_r <= 1'b1; sda_r <= 1'b1; step <= 2'd1; end
                            2'd1: begin sda_r <= 1'b0; step <= 2'd2; end
                            2'd2: begin step  <= 2'd3; end
                            2'd3: begin 
                                scl_r <= 1'b0; 
                                step  <= 2'd0; 
                                done  <= 1'b1; 
                                state <= WAIT_CMD; 
                            end
                        endcase
                    end
                end

                WAIT_CMD: begin
                    step <= 0;
                    // SCL은 0으로 유지하여 Master가 버스 제어권을 유지함
                    if (cmd_write) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt      <= 0;
                        is_read      <= 1'b0;
                        state        <= DATA;
                    end else if (cmd_read) begin
                        bit_cnt      <= 0;
                        is_read      <= 1'b1;
                        ack_in_r     <= ack_in;
                        state        <= DATA;
                    end else if (cmd_stop) begin
                        state <= STOP;
                    end else if (cmd_start) begin
                        state <= START;
                    end
                end

                DATA: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                sda_r <= is_read ? 1'b1 : tx_shift_reg[7];
                                step  <= 2'd1;
                            end
                            2'd1: begin scl_r <= 1'b1; step <= 2'd2; end
                            2'd2: begin
                                if (is_read) rx_shift_reg <= {rx_shift_reg[6:0], sda_i};
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                if (!is_read) tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                step  <= 2'd0;
                                if (bit_cnt == 7) state <= ACK;
                                else bit_cnt <= bit_cnt + 1;
                            end
                        endcase
                    end
                end

                ACK: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                sda_r <= is_read ? ack_in_r : 1'b1;
                                step  <= 2'd1;
                            end
                            2'd1: begin scl_r <= 1'b1; step <= 2'd2; end
                            2'd2: begin
                                if (!is_read) ack_out <= sda_i; // Slave의 ACK 수신
                                else          rx_data <= rx_shift_reg;
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                done  <= 1'b1;
                                step  <= 2'd0;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end

                STOP: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin sda_r <= 1'b0; scl_r <= 1'b0; step <= 2'd1; end
                            2'd1: begin scl_r <= 1'b1; step <= 2'd2; end
                            2'd2: begin sda_r <= 1'b1; step <= 2'd3; end // STOP Condition
                            2'd3: begin
                                step  <= 2'd0;
                                done  <= 1'b1;
                                state <= IDLE;
                            end
                        endcase
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule