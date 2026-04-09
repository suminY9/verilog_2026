`ifndef RAM_ENV_SV
`define RAM_ENV_SV

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "ram_agent.sv"
`include "ram_scoreboard.sv"
`include "ram_coverage.sv"

class ram_env extends uvm_env;
    `uvm_component_utils(ram_env)

    ram_agent agt;
    ram_scoreboard scb;
    ram_coverage cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = ram_agent::type_id::create("agt", this);
        scb = ram_scoreboard::type_id::create("scb", this);
        cov = ram_coverage::type_id::create("cov", this);
    endfunction
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.ap_imp);
        agt.mon.ap.connect(cov.analysis_export);
    endfunction
endclass

`endif 