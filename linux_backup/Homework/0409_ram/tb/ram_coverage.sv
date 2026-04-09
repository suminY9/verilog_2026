`ifndef COMPONENT_SV
`define COMPONENT_SV

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "ram_seq_item.sv"

class ram_coverage extends uvm_subscriber#(ram_seq_item);
    `uvm_component_utils(ram_coverage)

    ram_seq_item item;

    covergroup ram_cg;
        cp_wr: coverpoint item.wr { bins read={0}; bins write={1}; }
        cp_addr: coverpoint item.addr { bins zero={0};
                                        bins d000={[1:99]};
                                        bins d100={[100:199]};
                                        bins d200={[200:254]};
                                        bins max={2**8-1}; }
        cp_data: coverpoint item.wdata { bins zero={0};
                                         bins h0001={[1:15]};
                                         bins h0011={[16:255]};
                                         bins h0111={[256:4095]};
                                         bins h1111={[4096:65534]};
                                         bins max={65535}; }
        cx_wr_addr: cross cp_wr, cp_addr;
        cx_wr_data: cross cp_wr, cp_data;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ram_cg = new();
    endfunction

    virtual function void write(ram_seq_item t);
        item = t;
        ram_cg.sample();
        `uvm_info(get_type_name(), $sformatf("ram_cg sampled: %s", item.convert2string()), UVM_MEDIUM)
    endfunction
    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "===== Coverage Summary =====", UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("   Overall: %.1f%%", ram_cg.get_coverage()), UVM_LOW);    
        `uvm_info(get_type_name(), $sformatf("   wr     : %.1f%%", ram_cg.cp_wr.get_coverage()), UVM_LOW);    
        `uvm_info(get_type_name(), $sformatf("   addr   : %.1f%%", ram_cg.cp_addr.get_coverage()), UVM_LOW);    
        `uvm_info(get_type_name(), $sformatf("   data   : %.1f%%", ram_cg.cp_data.get_coverage()), UVM_LOW);    
        `uvm_info(get_type_name(), $sformatf("   cross(wr, addr): %.1f%%", ram_cg.cx_wr_addr.get_coverage()), UVM_LOW);    
        `uvm_info(get_type_name(), $sformatf("   cross(wr, data): %.1f%%", ram_cg.cx_wr_data.get_coverage()), UVM_LOW);    
        `uvm_info(get_type_name(), " ===== Coverage Summary =====\n\n", UVM_LOW);
    endfunction
endclass




`endif 