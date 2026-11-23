class spi_test_base extends uvm_test;
// UVM factory registration macro for the test class.
`uvm_component_utils(spi_test_base);

//Component nembers for the test class.

//Method to build the test class.
function void build_phase(uvm_phase phase);
    super.build_phase(phase);
endfunction : build_phase   

extern virtual function void configure_apb_agent();
extern function new(string name = "spi_test_base", uvm_component parent = null);

endclass : spi_test_base

function spi_test_base::new(string name = "spi_test_base", uvm_component parent = null);
 super.new(name, parent);
endfunction

// This can be overloaded by extensions to this base class
function void spi_test_base::configure_apb_agent();
 //cfg.active = UVM_ACTIVE;
 //cfg.has_functional_coverage = 0;
 //cfg.has_scoreboard = 0;
 //// SPI is on select line 0 for address range 0-18h
 //cfg.no_select_lines = 1;
 //cfg.start_address[0] = 32'h0;
 //cfg.range[0] = 32'h18;
endfunction: 



