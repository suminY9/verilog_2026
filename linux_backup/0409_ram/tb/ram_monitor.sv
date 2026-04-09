`ifndef RAM_MONITOR_SV
`define RAM_MONITOR_SV

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "ram_seq_item.sv"

class ram_monitor extends uvm_monitor;
    `uvm_component_utils(ram_monitor)

    virtual ram_interface r_if;
    uvm_analysis_port #(ram_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if(!uvm_config_db#(virtual ram_interface)::get(this, "", "r_if", r_if))
            `uvm_fatal(get_type_name(), "ram interface를 config_db에서 가져올 수 없음.")
    endfunction
    virtual task run_phase(uvm_phase phase);
        ram_seq_item item;

        forever begin
            ram_seq_item item = ram_seq_item::type_id::create("item");
            
            // Write
            @(r_if.mon_cb);
            item.wr    = r_if.mon_cb.wr;
            item.addr  = r_if.mon_cb.addr;
            item.wdata = r_if.mon_cb.wdata;
            // Read
            if(!item.wr) begin
                @(r_if.mon_cb);
                item.rdata = r_if.mon_cb.rdata;
            end
            // interface로부터 받은 값을 item에 넣어서 itme을 scb, cov에 전송
            
            ap.write(item);
        end
    endtask
endclass




`endif 