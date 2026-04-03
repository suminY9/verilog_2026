class base_packet;
    bit  [7:0] addr;
    bit [31:0] data;
    function new(bit [7:0] addr, bit [31:0] data);
        this.addr = addr;
        this.data = data;
    endfunction

    virtual function void print();
        $display("  [Base] addr = 0x%02h, data = 0x%08h", addr, data);
    endfunction

    virtual function int get_size();
        return 5;
    endfunction 
endclass


class ext_packet extends base_packet;
    bit [15:0] checksum;

    function new(bit [7:0] addr, bit [31:0] data, bit [15:0] checksum);
        super.new(addr, data);
        this.checksum = checksum;
    endfunction

    virtual function void print();
        $display("   [Extended] addr = 0x%02h, data = 0x%08h, checksum = 0x%04h", addr, data, checksum);
    endfunction

    virtual function int get_size();
        return super.get_size() + 2;
    endfunction 
endclass


module tb_oop();
    initial begin
        base_packet bp;
        ext_packet ep;

        bp = new(8'haa, 32'h1111_2222);
        ep = new(8'hbb, 32'h3333_4444, 16'hff00);

        $display("===== 기본 패킷 =====");
        bp.print();
        $display("   크기: %0d byte", bp.get_size());

        $display("==== 확장 패킷 ====");
        ep.print();
        $display("   크기: %0d byte", ep.get_size());
    end
endmodule