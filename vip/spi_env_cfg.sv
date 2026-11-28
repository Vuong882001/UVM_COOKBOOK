// Configuration shared by the SPI UVM environment and its test.
// The top-level testbench supplies the virtual interface handles through
// uvm_config_db before the test is created.
import uvm_pkg::*;
`include "uvm_macros.svh"

class spi_env_cfg extends uvm_object;
  // Virtual interfaces supplied by tb_top through uvm_config_db.
  virtual apb_if apb_vif;
  virtual spi_if spi_vif;
  virtual irq_if irq_vif;

  // Environment topology and agent operation.
  uvm_active_passive_enum apb_agent_active = UVM_ACTIVE;
  uvm_active_passive_enum spi_agent_active = UVM_ACTIVE;
  bit has_apb_agent = 1'b1;
  bit has_spi_agent = 1'b1;
  bit has_irq_monitor = 1'b1;
  bit has_scoreboard = 1'b1;
  bit has_coverage = 1'b1;

  // Default DUT setup for tests; tests may override these before run_phase.
  bit         dut_master_mode = 1'b1;
  logic [15:0] spi_divider = 16'd2;
  bit         completion_irq_enable = 1'b1;

  `uvm_object_utils_begin(spi_env_cfg)
    `uvm_field_enum(uvm_active_passive_enum, apb_agent_active, UVM_DEFAULT)
    `uvm_field_enum(uvm_active_passive_enum, spi_agent_active, UVM_DEFAULT)
    `uvm_field_int(has_apb_agent, UVM_DEFAULT)
    `uvm_field_int(has_spi_agent, UVM_DEFAULT)
    `uvm_field_int(has_irq_monitor, UVM_DEFAULT)
    `uvm_field_int(has_scoreboard, UVM_DEFAULT)
    `uvm_field_int(has_coverage, UVM_DEFAULT)
    `uvm_field_int(dut_master_mode, UVM_DEFAULT)
    `uvm_field_int(spi_divider, UVM_DEFAULT)
    `uvm_field_int(completion_irq_enable, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "spi_env_cfg");
    super.new(name);
  endfunction : new

  // Call from spi_env::build_phase after retrieving this object.
  function bit validate();
    bit valid = 1'b1;

    if (has_apb_agent && apb_vif == null) begin
      `uvm_error("SPI_CFG", "apb_vif was not provided")
      valid = 1'b0;
    end
    if (has_spi_agent && spi_vif == null) begin
      `uvm_error("SPI_CFG", "spi_vif was not provided")
      valid = 1'b0;
    end
    if (has_irq_monitor && irq_vif == null) begin
      `uvm_error("SPI_CFG", "irq_vif was not provided")
      valid = 1'b0;
    end

    return valid;
  endfunction : validate

endclass : spi_env_cfg
