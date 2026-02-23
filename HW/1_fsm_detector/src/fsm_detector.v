`timescale 1ns / 1ps

module top_fsm(
    input clk,
    input rst,
    input din_bit,
    output dout_bit
);

    wire w_mealy_out, w_moore_out;

    assign dout_bit = (w_mealy_out && w_moore_out) ?  1'b1 : 1'b0;

    mealy_detector U_MEALY (
        .clk(clk),
        .rst(rst),
        .din_bit(din_bit),
        .dout_bit(w_mealy_out)
    );

    moore_detector U_MOORE (
        .clk(clk),
        .rst(rst),
        .din_bit(din_bit),
        .dout_bit(w_moore_out)
    );
endmodule

module moore_detector(
    input clk,
    input rst,
    input din_bit,
    output dout_bit
);

    // state
    parameter START = 3'b000;
    parameter S0    = 3'b001;
    parameter S1    = 3'b010;
    parameter S2    = 3'b011;
    parameter S3    = 3'b100;

    // state variable
    reg [2:0] current_st, next_st;

    // state register(SL)
    always @(posedge clk, posedge rst) begin
        if(rst) begin
                current_st <= S0;
        end else begin
            current_st <= next_st;
        end
    end

    // next state combinational logic (CL)
    always @(*) begin
        // initialize
        next_st = current_st;

        case (current_st)
        START: begin
            if(din_bit == 1'b0)      next_st = S0;
            else if(din_bit == 1'b1) next_st = START;
        end
        S0: begin
            if(din_bit == 1'b0)      next_st = S0;
            else if(din_bit == 1'b1) next_st = S1;
        end
        S1: begin
            if(din_bit == 1'b0)      next_st = S2;
            else if(din_bit == 1'b1) next_st = START;
        end
        S2: begin
            if(din_bit == 1'b0)      next_st = S0;
            else if(din_bit == 1'b1) next_st = S3;
        end
        S3: begin
            if(din_bit == 1'b0)      next_st = S0;
            else if(din_bit == 1'b1) next_st = START;
        end
        endcase
    end

    // output combinational logic (CL)
    assign dout_bit = (current_st == S3) ? 1'b1 : 1'b0;

endmodule

module mealy_detector(
    input clk,
    input rst,
    input din_bit,
    output dout_bit
    );

    // state
    parameter START     = 3'b000;
    parameter RD0       = 3'b001;
    parameter RD0_1     = 3'b010;
    parameter RD0_1_0   = 3'b011;
    parameter RD0_1_0_1 = 3'b100;

    // state variable
    reg [2:0] state_reg, next_st;

    // state register (SL)
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg <= START;
        end else begin
            state_reg <= next_st;
        end
    end

    // next state combinational logic(CL)
    always @(*) begin
        // inintialize
        next_st = START;
        
        case(state_reg)
        START:  begin
            if(din_bit == 1'b0)      next_st = RD0;
            else if(din_bit == 1'b1) next_st = START;
        end
        RD0: begin
            if(din_bit == 1'b0)      next_st = RD0;
            else if(din_bit == 1'b1) next_st = RD0_1;
        end
        RD0_1: begin
            if(din_bit == 1'b0)      next_st = RD0_1_0;
            else if(din_bit == 1'b0) next_st = START;
        end
        RD0_1_0: begin
            if(din_bit == 1'b0)      next_st = RD0;
            else if(din_bit == 1'b1) next_st = RD0_1_0_1;
        end
        RD0_1_0_1: begin
            if(din_bit == 1'b0)      next_st = RD0_1_0;
            else if(din_bit == 1'b1) next_st = START;
        end
        endcase
    end

    // outptu combinational logic (CL)
    assign dout_bit = ((state_reg == RD0_1_0_1) && (din_bit == 1'b1)) ? 1'b1 : 1'b0;

endmodule

