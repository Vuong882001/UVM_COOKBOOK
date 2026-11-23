:# Questa/ModelSim flow, patterned after /home/thanhvuong/UVM/sim/Makefile

TB_NAME       ?= tb_top
TESTNAME  ?= base_test
UVM_VERBOSITY ?= UVM_LOW
TESTNAME      ?= $(UVM_TESTNAME)

.PHONY: build compile run run_wave exec_wave clean

build compile:
	@if [ ! -d work ]; then vlib work; fi
	vmap work work
	vlog -sv -O0 +acc=rn -f compile.f | tee compile.log

run: compile
	vsim -l $(TESTNAME).log -assertdebug -c $(TB_NAME) \
	    +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=$(UVM_VERBOSITY) \
	    -do "log -r /*; run -all;"
all: build run

run_wave: compile
	vsim -debugDB -l $(TESTNAME).log -voptargs=+acc -assertdebug \
	    -wlf $(TESTNAME).wlf \
	    -c $(TB_NAME) +UVM_TESTNAME=$(UVM_TESTNAME) \
	    +UVM_VERBOSITY=$(UVM_VERBOSITY) -do "log -r /$(TB_NAME)/**; run -all;"

exec_wave:
	vsim -i

clean:
	rm -rf work
	rm -rf vsim.dbg
	rm -rf *.ini
	rm -rf *.log
	rm -rf *.wlf
	rm -rf transcript
