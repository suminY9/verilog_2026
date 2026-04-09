`ifndef RAM_AGENT_SV
`define RAM_AGENT_SV

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "ram_seq_item.sv"
`include "ram_driver.sv"
`include "ram_monitor.sv"

class ram_agent extends uvm_agent;
    `uvm_component_utils(ram_agent)
    ram_driver drv;
    ram_monitor mon;
    uvm_sequencer#(ram_seq_item) sqr; // uvm에서 기본 제공하는 sequnecer 사용

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = ram_driver::type_id::create("drv", this);
        mon = ram_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(ram_seq_item)::type_id::create("sqr", this);
    endfunction
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

`endif 