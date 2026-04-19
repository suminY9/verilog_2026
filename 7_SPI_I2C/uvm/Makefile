# TC ?= uart_rand_test
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

compile_spiM:
	vcs $(VCS_OPTS) -f filelist_spi_master.f -o simv_spi_master
compile_spiS:
	vcs $(VCS_OPTS) -f filelist_spi_slave.f -o simv_spi_slave
compile_i2cM:
	vcs $(VCS_OPTS) -f filelist_i2c_master.f -o simv_i2c_master
compile_i2cS:
	vcs $(VCS_OPTS) -f filelist_i2c_slave.f -o simv_i2c_slave

# sim: compile
# 	./simv $(SIM_OPTS) 

# simv
simv_spiM: compile_spiM
	./simv_spi_master $(SIM_OPTS) > simv_spi_master.log
simv_spiS: compile_spiS
	./simv_spi_slave $(SIM_OPTS) > simv_spi_slave.log
simv_i2cM: compile_i2cM
	./simv_i2c_master $(SIM_OPTS) > simv_i2c_master.log
simv_i2cS: compile_i2cS
	./simv_i2c_slave $(SIM_OPTS) > simv_i2c_slave.log

verdi: 
	verdi $(VERDI_OPTS)

verdi_sim:
	verdi -dbdir simv.daidir -ssf novas.fsdb

verdi_cov:
	verdi -cov -covdir coverage.vdb

clean:
	@rm -rf simv* csrc *.key *.h *.log *.fsdb novas* *.conf *Log coverage.*
	@echo "결과물 정리 중..."
