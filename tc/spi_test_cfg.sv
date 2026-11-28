// Per-test scenario controls. The test configures these values, then passes
// the object to the environment/sequences that program and check the DUT.
import uvm_pkg::*;
`include "uvm_macros.svh"

class spi_test_cfg extends uvm_object;
  bit         dut_master_mode = 1'b1;
  logic [15:0] spi_divider = 16'd2;
  bit         completion_irq_enable = 1'b1;

  `uvm_object_utils_begin(spi_test_cfg)
    `uvm_field_int(dut_master_mode, UVM_DEFAULT)
    `uvm_field_int(spi_divider, UVM_DEFAULT)
    `uvm_field_int(completion_irq_enable, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "spi_test_cfg");
    super.new(name);
  endfunction : new
endclass : spi_test_cfg
