`ifndef RAM_SEQUENCE_SV
`define RAM_SEQUENCE_SV

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "ram_seq_item.sv"

class ram_random_sequence extends uvm_sequence#(ram_seq_item);
    `uvm_object_utils(ram_random_sequence)
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
    `uvm_object_utils(ram_write_read_sequence)
    int num_transaction = 0;

    function new(string name = "ram_sequence");
        super.new(name);
    endfunction

    virtual task body();
        repeat(num_transaction) begin
            ram_seq_item item = ram_seq_item::type_id::create("item");
        
            start_item(item);
                if(!item.randomize() with {wr == 1;})
                    `uvm_fatal(get_type_name(), "Randomization Fail.");
            finish_item(item);

            start_item(item);
                item.wr = 0;
            finish_item(item);
        end
    endtask
endclass

class ram_full_sweep_sequence extends uvm_sequence#(ram_seq_item);
    `uvm_object_utils(ram_full_sweep_sequence)

    function new(string name = "ram_sequence");
        super.new(name);
    endfunction

    virtual task body();
        ram_seq_item item = ram_seq_item::type_id::create("item");

        // Write
        for(int i = 0; i < 2**8; i++) begin
            start_item(item);
            if(!item.randomize() with { wr == 1; addr == i; })
                `uvm_fatal(get_type_name(), "Randomization Fail!");
            finish_item(item);
        end

        // Read
        for(int i = 0; i < 2**8; i++) begin
            start_item(item);
            item.wr = 0;
            item.addr = i;
            finish_item(item);
        end   
    endtask
endclass
`endif 