`ifndef RAM_SEQUENCE_SV
`define RAM_SEQUENCE_SV

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "ram_seq_item.sv"

class ram_sequence extends uvm_sequence#(ram_seq_item);
    `uvm_object_utils(ram_sequence)
    int num_transaction = 0;

    function new(string name = "ram_sequence");
        super.new(name);
    endfunction

    virtual task body();
        repeat(num_transaction) begin
            ram_seq_item item = ram_seq_item::type_id::create("item");
        
            start_item(item);
                if(!item.randomize()) `uvm_fatal(get_type_name(), "Randomization Fail.");
            finish_item(item);
        end
    endtask
endclass

class ram_write_read_sequence extends uvm_sequence#(ram_seq_item);
    `uvm_object_utils(ram_sequence)
    int num_transaction = 0;

    function new(string name = "ram_sequence");
        super.new(name);
    endfunction

    virtual task body();
        repeat(num_transaction) begin
            ram_seq_item item = ram_seq_item::type_id::create("item");
        
            start_item(item);
                if(!item.randomize() with {wr == 1;}) `uvm_fatal(get_type_name(), "Randomization Fail.");
            finish_item(item);
        end
    endtask
endclass

`endif 