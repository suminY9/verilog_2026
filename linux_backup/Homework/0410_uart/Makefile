TC ?= uart_rand_test
SEED ?= 1234

VCS_OPTS := -full64 -sverilog
VCS_OPTS += -ntb_opts uvm-1.2
VCS_OPTS += -timescale=1ns/1ps
VCS_OPTS += -debug_access+all -kdb -lca
VCS_OPTS += +incdir+tb
VCS_OPTS += -cm line+cond+fsm+tgl+branch+assert

# SIM_OPTS := +UVM_TESTNAME=$(TC)
SIM_OPTS += +UVM_VERBOSITY=UVM_HIGH
SIM_OPTS += +ntb_random_seed=$(SEED)
SIM_OPTS += -cm line+cond+fsm+tgl+branch+assert
SIM_OPTS += -cm_dir coverage.vdb
SIM_OPTS += -cm_name sim1

VERDI_OPTS := -covdir coverage.vdb -dbdir simv.daidir -ssf novas.fsdb &

.PHONY: compile sim clear

compile:
	vcs $(VCS_OPTS) -f filelist.f -o simv

sim: compile
	./simv $(SIM_OPTS) 

# simv
random: compile
	./simv $(SIM_OPTS) +UVM_TESTNAME=uart_rand_test

# make simv.log
random_log: compile
	./simv $(SIM_OPTS) +UVM_TESTNAME=uart_rand_test > simv_random.log

verdi: 
	verdi $(VERDI_OPTS)

verdi_sim:
	verdi -dbdir simv.daidir -ssf novas.fsdb

verdi_cov:
	verdi -cov -covdir coverage.vdb

clean:
	@rm -rf simv* csrc *.key *.h *.log *.fsdb novas* *.conf *Log coverage.*
	@echo "결과물 정리 중..."
