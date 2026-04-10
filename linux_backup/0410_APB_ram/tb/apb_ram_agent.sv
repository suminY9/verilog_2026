`ifndef AGENT_SV
`define AGENT_SV

`include "apb_ram_seq_item.sv"
`include "apb_ram_driver.sv"
`include "apb_ram_monitor.sv"

typedef uvm_sequencer #(apb_seq_item) apb_sequencer;
class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)
    apb_driver drv;
    apb_monitor mon;
    uvm_sequencer#(apb_seq_item) sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = apb_driver::type_id::create("drv", this);
        mon = apb_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(apb_seq_item)::type_id::create("sqr", this);
    endfunction
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

`endif 