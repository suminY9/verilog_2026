# ===== UVM Testbench Makefile =====
#vcs -full64 -sverilog -debug_access+all -kdb -lca -ntb_opts uvm-1.2 -timescale=1ns/1ps -o simv ./rtl/adder.sv ./tb/tb_adder.sv

VCS       = vcs
TOP       = tb_top
TEST      = adder_test
VERBOSITY = UBM_MEDIUM
SEED      = random

COMP_OPTS = -full64 -sverilog -debug_access+all\
			-kdb -lca -ntb_opts uvm-1.2\
			-timescale=1ns/1ps\
			+incdir+./rtl +incdir+./tb\

RUN_OPTS  =  +UVM_TESTNAME=$(TEST)\
			 +UVM_VERBOSITY=$(VERBOSITY)\
			 +ntb_random_seed=$(SEED)

comp:
	$(VCS) $(COMP_OPTS) -f filelist.f -o simv

run: comp
	./simv $(RUN_OPTS)

clean:
	rm -rf simv* csrc *.log *.vpd *.fsdb *.key *.h DVE*

.PHONY: comp run clean