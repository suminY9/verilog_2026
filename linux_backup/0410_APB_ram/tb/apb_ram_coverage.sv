`ifndef COVERAGE_SV
`define COVERAGE_SV

`include "apb_ram_seq_item.sv"

class apb_coverage extends uvm_subscriber#(apb_seq_item);
    `uvm_component_utils(apb_coverage)
    apb_seq_item tx;

    covergroup apb_cg;
        cp_addr: coverpoint tx.paddr {   bins addr_low     = {[8'h00 : 8'h3C]};
                                         bins addr_mid_low = {[8'h40 : 8'h7C]};
                                         bins addr_mid_hi  = {[8'h80 : 8'hBC]};
                                         bins addr_high    = {[8'hC0 : 8'hFC]};    }
        cp_write: coverpoint tx.pwrite { bins write_op = {1'b1};
                                         bins read_op  = {1'b0}; }
        cp_wdata: coverpoint tx.pwdata { bins all_zeros = {32'h0000_0000};
                                         bins all_ones  = {32'hFFFF_FFFF};
                                         bins all_a     = {32'haaaa_aaaa};   // a = 1010
                                         bins all_5     = {32'h5555_5555};   // 5 = 0101
                                         bins other     = default; }
        cp_rdata: coverpoint tx.prdata { bins all_zeros = {32'h0000_0000};
                                         bins all_ones  = {32'hFFFF_FFFF};
                                         bins all_a     = {32'haaaa_aaaa};   // a = 1010
                                         bins all_5     = {32'h5555_5555};   // 5 = 0101
                                         bins other     = default; }
        cx_addr_rx: cross cp_addr, cp_write;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_cg = new();
    endfunction

    function void write (apb_seq_item t);
        tx = t;
        apb_cg.sample();
    endfunction
    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "  ===== Coverage Summary =====  ", UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("   Overall: %.1f%%", apb_cg.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("   addr   : %.1f%%", apb_cg.cp_addr.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("   write  : %.1f%%", apb_cg.cp_write.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("   wdata  : %.1f%%", apb_cg.cp_wdata.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("   radta  : %.1f%%", apb_cg.cp_rdata.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("   cross(addr, write) : %.1f%%", apb_cg.cx_addr_rx.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), "  ===== Coverage Summary =====  \n\n", UVM_LOW);
    endfunction
endclass

`endif 