`ifndef COVERAGE_SV
`define COVERAGE_SV

class uart_coverage extends uvm_subscriber#(uart_seq_item);
    `uvm_component_utils(uart_coverage)
    uart_seq_item tx;

    covergroup uart_cg;
        cp_data: coverpoint tx.data { bins big_letter   = {[8'h41 : 8'h5A]};
                                     bins small_letter = {[8'h61 : 8'h7A]}; }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        uart_cg = new();
    endfunction

    function void write (uart_seq_item t);
        tx = t;
        uart_cg.sample();
    endfunction
    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "  ===== Coverage Summary =====  ", UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("   data : %.1f%%", uart_cg.cp_data.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), "  ===== Coverage Summary =====  \n\n", UVM_LOW);
    endfunction
endclass
`endif 