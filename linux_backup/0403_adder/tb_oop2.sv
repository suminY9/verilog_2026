class animal;
    string name;

    function new(string name);
        this.name = name;
    endfunction

    virtual function void speak();
        $display("   [%s] ... (소리 없음)", name);
    endfunction 
endclass

class dog extends animal;
    function new(string name);
        super.new(name);
    endfunction

    virtual function void speak();
        $display("   [%s] 멍멍!", name);
    endfunction
endclass

class cat extends animal;
    function new(string name);
        super.new(name);
    endfunction

    virtual function void speak();
        $display("   [%s] 야옹!", name);
    endfunction
endclass


module tb_oop();
    initial begin
        animal animals[3];
        dog d;
        cat c;

        animals[0] = new("동물");
        d = new("강아지");
        c = new("고양이");
        animals[1] = d;
        animals[2] = c;

        $display("==== 다형성 데모 ====");
        animals[0].speak();
        animals[1].speak();
        animals[2].speak();
    end
endmodule