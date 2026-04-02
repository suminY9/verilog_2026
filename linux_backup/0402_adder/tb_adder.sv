module tb_adder();
	logic [7:0] a;
	logic [7:0] b;
	logic [8:0] y;

	adder dut(.*);

	initial begin
		$fsdbDumpfile("wave.fsdb");
		$fsdbDumpvars(0);
	end

	initial begin
		a = 0;
		b = 0;
		#10;
		$display("%0d + %0d = %0d", a, b, y);
		#10;
		
		a = 30;
		b = 20;
		#10;
		$display("%0d + %0d = %0d", a, b, y);
		#10;
		
		a = 8;
		b = 1;
		#10;
		$display("%0d + %0d = %0d", a, b, y);
		#10;

		a = 11;
		b = 9;
		#10;
		$display("%0d + %0d = %0d", a, b, y);
		#10;

		a = 99;
		b = 100;
		#10;
		$display("%0d + %0d = %0d", a, b, y);
		#10;

		#10;
		$finish;
	end
endmodule
