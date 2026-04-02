`timescale 1ns / 1ps

module tb_uart_fnd ();

    logic clk, rst;
    logic [7:0] GPI;
    wire  [7:0] GPO;
    wire  [15:0] GPIO;
    wire  [ 3:0] fnd_digit;
    wire  [ 7:0] fnd_data;

    logic uart_rx;
    wire  uart_tx;

    logic [7:0] sw_in;
    assign GPIO[7:0]  = sw_in;
    assign GPIO[15:8] = 8'bz;

    // MCU Instance
    rv32I_mcu dut (
        .clk      (clk),
        .rst      (rst),
        .GPI      (GPI),
        .GPO      (GPO),
        .GPIO     (GPIO),
        .fnd_digit(fnd_digit),
        .fnd_data (fnd_data),
        .uart_rx  (uart_rx),
        .uart_tx  (uart_tx)
    );

    // -------------------------------------------------------
    // [최종 튜닝] hold=200 / gap=10000
    // hold: 폴링 루프를 약 11회 반복 가능 (확실한 캐치)
    // gap: 처리 시간(760clk) 이후 루프 복귀 및 안정화 보장
    // -------------------------------------------------------
    task uart_inject(input [7:0] data);
        begin
            force dut.U_APB_UART.RX_DATA_REG = data;
            force dut.U_APB_UART.w_rx_done   = 1'b1;

            // CPU가 폴링 루프에서 데이터를 인지할 수 있도록 충분히 유지
            repeat(200) @(posedge clk); 
            
            release dut.U_APB_UART.w_rx_done;
            release dut.U_APB_UART.RX_DATA_REG;
            
            // 연산 및 FND 쓰기(760clk)를 완전히 마칠 때까지 대기
            repeat(10000) @(posedge clk); 
        end
    endtask

    always #5 clk = ~clk;

    initial begin
        clk     = 0;
        rst     = 1;
        GPI     = 8'h00;
        sw_in   = 8'h00;
        uart_rx = 1'b1;

        @(negedge clk);
        @(negedge clk);
        rst = 0;

        repeat(2000) @(posedge clk);

        // =====================================================
        // [SCENARIO 1] UP: 0 → 1 → 3 → ... → 136
        // =====================================================
        $display("=== [UP] SCENARIO START ===");
        
        for (int i = 0; i <= 9; i++) begin
            uart_inject(8'h30 + i); // '0'~'9'
            $display("  Input: '%c' | FND Value: %d", 8'h30+i, dut.U_APB_FND.FND_DATA_REG);
        end
        for (int i = 0; i <= 5; i++) begin
            uart_inject(8'h61 + i); // 'a'~'f'
            $display("  Input: '%c' | FND Value: %d", 8'h61+i, dut.U_APB_FND.FND_DATA_REG);
        end

        repeat(5000) @(posedge clk);

        // =====================================================
        // [SCENARIO 2] DOWN: 136 → ... → 0
        // =====================================================
        $display("=== [DOWN] SCENARIO START ===");
        
        for (int i = 0; i <= 9; i++) begin
            uart_inject(8'h30 + i);
            $display("  Input: '%c' | FND Value: %d", 8'h30+i, dut.U_APB_FND.FND_DATA_REG);
        end
        for (int i = 0; i <= 5; i++) begin
            uart_inject(8'h61 + i);
            $display("  Input: '%c' | FND Value: %d", 8'h61+i, dut.U_APB_FND.FND_DATA_REG);
        end

        repeat(5000) @(posedge clk);
        $display("=== [SUCCESS] Final FND Value: %d ===", dut.U_APB_FND.FND_DATA_REG);
        $stop;
    end
endmodule