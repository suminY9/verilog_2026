`ifndef APB_SEQUENCE_SV
`define APB_SEQUENCE_SV

`include "apb_ram_seq_item.sv"

class apb_base_seq extends uvm_sequence#(apb_seq_item);
    `uvm_object_utils(apb_base_seq)

    function new(string name = "apb_base_seq");
        super.new(name);
    endfunction

    task do_write(bit [7:0] addr, bit [31:0] data);
        apb_seq_item item;
        item = apb_seq_item::type_id::create("item");

        start_item(item);
            if(!item.randomize() with { pwrite == 1'b1; paddr == addr; pwdata == data; })
                `uvm_fatal(get_type_name(), "do_write() Rnadomize() fail!")
        finish_item(item);
        `uvm_info(get_type_name(), $sformatf("do_write() write 전송 완료: addr=0x%02h data=0x%08h", addr, data), UVM_MEDIUM) 
    endtask 
    task do_read(bit [7:0] addr, output bit [31:0] rdata);
        apb_seq_item item;
        item = apb_seq_item::type_id::create("item");

        start_item(item);
            if(!item.randomize() with { pwrite == 1'b0; paddr == addr; })
                `uvm_fatal(get_type_name(), "do_write() Rnadomize() fail!")
        finish_item(item);
        rdata = item.prdata;
        `uvm_info(get_type_name(), $sformatf("do_read() write 전송 완료: addr=0x%02h rdata=0x%08h", addr, rdata), UVM_MEDIUM) 
    endtask 
endclass

class apb_write_read_seq extends apb_base_seq;
    `uvm_object_utils(apb_write_read_seq)
    int num_loop = 0;
    bit [7:0] addr;
    bit [31:0] wdata, rdata;

    function new(string name = "apb_write_read_seq");
        super.new(name);
    endfunction

    virtual task body();
        for(int i = 0; i < num_loop; i++) begin
            apb_seq_item item = apb_seq_item::type_id::create("item");
            addr = (i % 64) * 4; // byte addressing, 0~64 
            wdata = $urandom();
            do_write(addr, wdata);
            do_read(addr, rdata);
        
            // start_item(item);
            //    if(!item.randomize() with {}) `uvm_fatal(get_type_name(), "Randomization Fail.");
            //    do_write(addr, wdata);
            //    do_read(addr, rdata);
            //finish_item(item);
        end
    endtask
endclass

class apb_rand_seq extends apb_base_seq;
    `uvm_object_utils(apb_rand_seq)
    int num_loop = 0;
    bit [7:0] addr;
    bit [31:0] wdata, rdata;

    function new(string name = "apb_rand_seq");
        super.new(name);
    endfunction

    virtual task body();
        repeat(num_loop) begin
            apb_seq_item item = apb_seq_item::type_id::create("item");
        
            start_item(item);
                if(!item.randomize())
                    `uvm_fatal(get_type_name(), "Randomization Fail.");
            finish_item(item);
        end
    endtask
endclass

`endif 