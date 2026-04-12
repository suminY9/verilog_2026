`ifndef UART_SEQ_ITEM_SV
`define UART_SEQ_ITEM_SV

class uart_seq_item extends uvm_sequence_item;
    rand bit [7:0] data;
    rand int       baudrate;

    constraint c_data { data inside { [8'h41 : 8'h5A],  // 대문자
                                      [8'h61 : 8'h7A]   // 소문자
                                    }; }
    constraint c_baudrate { baudrate == 9600; }
    

    `uvm_object_utils_begin(uart_seq_item)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(baudrate, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "uart_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("SEND data=%s(0x%0h)", data, data);
    endfunction

endclass
`endif 