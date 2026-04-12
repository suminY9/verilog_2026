`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

// 포트를 구분 가능하게 해줌
`uvm_analysis_imp_decl(_drv)
`uvm_analysis_imp_decl(_mon)

class uart_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(uart_scoreboard)
    
    uvm_analysis_imp_drv #(uart_seq_item, uart_scoreboard) ap_drv_imp;
    uvm_analysis_imp_mon #(uart_seq_item, uart_scoreboard) ap_mon_imp;

    logic [7:0] ref_q[$];
    int num_rx = 0;
    int num_tx = 0;
    int num_errors = 0;
    logic [7:0] expected;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_drv_imp = new("ap_drv_imp", this);
        ap_mon_imp = new("ap_mon_imp", this);
    endfunction
    function void write_drv(uart_seq_item tx);
        ref_q.push_back(tx.data);
        num_tx++;
    endfunction
    function void write_mon(uart_seq_item tx);
        num_rx++;
        
        if (ref_q.size() > 0) begin
            expected = ref_q.pop_front(); // 가장 먼저 들어온 데이터 꺼냄
            
            if (expected !== tx.data) begin
                num_errors++;
                `uvm_error(get_type_name(), $sformatf("== FAIL == Expected: %s(0x%h), Actual: %s(0x%h)", expected, expected, tx.data, tx.data))
            end else begin
                `uvm_info(get_type_name(), $sformatf("== PASS == Data Matched: %s(0x%h)", tx.data, tx.data), UVM_MEDIUM)
            end
        end else begin
            num_errors++;
            `uvm_error(get_type_name(), "== FAIL == Unexpected RX Data received (Ref Queue is empty!)")
        end
    endfunction
    virtual function void report_phase(uvm_phase phase);
        string result = (num_errors == 0 && num_tx == num_rx) ? "** PASS **" : "** FAIL **";
        `uvm_info(get_type_name(), "========== UART Loopback Summary ==========", UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" Result      : %s", result), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" TX Count    : %0d", num_tx), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" RX Count    : %0d", num_rx), UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf(" Error Count : %0d", num_errors), UVM_MEDIUM)
        `uvm_info(get_type_name(), "************************************", UVM_MEDIUM)
    endfunction
endclass

`endif 