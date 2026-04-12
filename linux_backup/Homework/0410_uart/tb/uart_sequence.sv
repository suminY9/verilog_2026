`ifndef UART_SEQUENCE_SV
`define UART_SEQUENCE_SV

class uart_base_seq extends uvm_sequence#(uart_seq_item);
    `uvm_object_utils(uart_base_seq)

    function new(string name = "uart_base_seq");
        super.new(name);
    endfunction

    task send(bit [7:0] data);
        uart_seq_item item;
        item = uart_seq_item::type_id::create("item");

        start_item(item);
            item.data = data;
        finish_item(item);
        `uvm_info(get_type_name(), $sformatf("send() 전송 완료: data=%s(0x%h)", data, data), UVM_MEDIUM)
    endtask 

endclass

class uart_rand_seq extends uart_base_seq;
    `uvm_object_utils(uart_rand_seq)
    int num_loop = 0;
    bit [7:0] data;

    function new(string name = "uart_rand_seq");
        super.new(name);
    endfunction

    virtual task body();
    `uvm_info(get_type_name(), $sformatf("Loop count is: %0d", num_loop), UVM_LOW)
        for(int i = 0; i < num_loop; i++) begin
            uart_seq_item item;
            item = uart_seq_item::type_id::create("item");
            
            start_item(item);
                if(!item.randomize())
                    `uvm_fatal(get_type_name(), "Randomization Fail.");
            finish_item(item);
        end
    endtask
endclass

`endif 