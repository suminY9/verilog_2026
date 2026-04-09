`ifndef DRIVER_SV
`define DRIVER_SV

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "ram_seq_item.sv"

class ram_driver extends uvm_driver #(ram_seq_item); 
    `uvm_component_utils(ram_driver)

    virtual ram_interface r_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual ram_interface)::get(this, "", "r_if", r_if))
            `uvm_fatal(get_type_name(), "ram interface를 config_db에서 가져올 수 없음.")
    endfunction
    virtual task run_phase(uvm_phase phase);
        ram_seq_item item;
        forever begin
            seq_item_port.get_next_item(item);

            // WRITE
            r_if.drv_cb.wr <= item.wr;
            r_if.drv_cb.addr <= item.addr;
            r_if.drv_cb.wdata <= item.wdata;
            @(r_if.drv_cb);
            // READ   need 2 clocks
            if(!item.wr) begin
                @(r_if.drv_cb);
            end

            `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM);
            seq_item_port.item_done();
        end
    endtask
endclass




`endif 