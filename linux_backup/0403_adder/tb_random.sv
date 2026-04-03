class rand_packet;
    rand bit  [7:0] addr;
    rand bit [31:0] data;
    rand bit        write;
    randc bit [1:0] pri;

    constraint addr_range_c { addr inside {[8'h00:8'h0f]}; }
    constraint data_align_c { data % 4 == 0; }
    constraint write_bias_c { write dist {1 :=7, 0 := 3};}

    function void print(int num);
        $display("   [%0d] addr=0x%02h, data=0x%08h, %s, priority=%0d", num, addr, data, write ? "WR" : "RD", pri);
    endfunction
endclass

module tb_random();
    initial begin
        rand_packet pkt = new();

        $display("==== 랜덤 패킷 10개 생성 ==== ");
        for(int i=1; i<10; i++) begin
            if(!pkt.randomize()) $display("ERROR: 랜덤화 실패");
            pkt.print(i);
        end
    end
endmodule
