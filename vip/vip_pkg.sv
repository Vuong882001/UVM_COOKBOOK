package vip_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Config must precede components that use it.
  `include "spi_env_cfg.sv"
  `include "spi_env.sv"
endpackage : vip_pkg
