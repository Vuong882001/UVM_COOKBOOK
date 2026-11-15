:# Questa/ModelSim flow, patterned after /home/thanhvuong/UVM/sim/Makefile

TB_NAME   ?= spi_master_tb
TESTNAME  ?= spi_master_tb
VERBOSITY ?= UVM_HIGH

.PHONY: build compile run run_wave exec_wave clean

build compile:
	@if [ ! -d work ]; then vlib work; fi
	vmap work work
	vlog -sv -O0 +acc=rn -f compile.f | tee compile.log

run: compile
	vsim -l $(TESTNAME).log -assertdebug -c $(TB_NAME) \
	    -do "log -r /*; run -all;"

run_wave: compile
	vsim -debugDB -l $(TESTNAME).log -voptargs=+acc -assertdebug \
	    -wlf $(TESTNAME).wlf \
	    -c $(TB_NAME) -do "log -r /$(TB_NAME)/**; run -all;"

exec_wave:
	vsim -i

clean:
	rm -rf work
	rm -rf vsim.dbg
	rm -rf *.ini
	rm -rf *.log
	rm -rf *.wlf
	rm -rf transcript
