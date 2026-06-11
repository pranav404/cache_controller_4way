// ============================================================
// cache_tb_top.sv
// Top-level non-UVM module — the only 'module' in the testbench
//
// Responsibilities:
//   1. Generate clock
//   2. Instantiate the virtual interface
//   3. Instantiate the DUT (cache_controller)
//   4. Apply reset
//   5. Pass virtual interface to UVM via uvm_config_db
//   6. Call run_test() to hand control to UVM
// ============================================================
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import cache_uvm_pkg::*;

module cache_tb_top;

  // -------------------------------------------------------
  // Clock Generation — 10ns period (100 MHz)
  // -------------------------------------------------------
  logic clk;
  initial clk = 1'b0;
  always #5ns clk = ~clk;

  // -------------------------------------------------------
  // Interface Instantiation
  // -------------------------------------------------------
  cache_if dut_if (.clk(clk));

  // -------------------------------------------------------
  // DUT Instantiation
  // All ports wired through the interface
  // -------------------------------------------------------
  cache_controller dut (
    .clk             (clk),
    .rst_n           (dut_if.rst_n),

    // CPU-side
    .re              (dut_if.re),
    .we              (dut_if.we),
    .cpu_addr_read   (dut_if.cpu_addr_read),
    .cpu_addr_write  (dut_if.cpu_addr_write),
    .cpu_data_write  (dut_if.cpu_data_write),
    .write_byte_sel  (dut_if.write_byte_sel),
    .cpu_stall_cache (dut_if.cpu_stall_cache),
    .cpu_data_read   (dut_if.cpu_data_read),
    .cache_stall_cpu (dut_if.cache_stall_cpu),

    // Memory-side
    .mem_addr_read   (dut_if.mem_addr_read),
    .mem_addr_write  (dut_if.mem_addr_write),
    .mem_re          (dut_if.mem_re),
    .mem_we          (dut_if.mem_we),
    .mem_data_write  (dut_if.mem_data_write),
    .cache_stall_mem (dut_if.cache_stall_mem),
    .mem_ack         (dut_if.mem_ack),
    .mem_data_read   (dut_if.mem_data_read),
    .mem_stall_cache (dut_if.mem_stall_cache)
  );

  // -------------------------------------------------------
  // Initial Block — Reset + UVM Kickoff
  // -------------------------------------------------------
  initial begin

    // Drive initial safe values before reset
    dut_if.rst_n          = 1'b0;
    dut_if.re             = 1'b0;
    dut_if.we             = 1'b0;
    dut_if.cpu_addr_read  = 32'b0;
    dut_if.cpu_addr_write = 32'b0;
    dut_if.cpu_data_write = 512'b0;
    dut_if.write_byte_sel = 64'b0;
    dut_if.cpu_stall_cache = 1'b0;
    dut_if.mem_ack        = 1'b0;
    dut_if.mem_data_read  = 512'b0;
    dut_if.mem_stall_cache = 1'b0;

    // Hold reset for 10 clock cycles
    //repeat(10) @(posedge clk);
    dut_if.rst_n = 1'b1;
    `uvm_info("TB_TOP", "Reset deasserted — starting UVM test", UVM_LOW)

    // -------------------------------------------------------
    // Pass virtual interface into UVM config_db
    // All agents retrieve it from here in their build_phase
    // -------------------------------------------------------

    // CPU driver gets the cpu_drv_mp modport
    uvm_config_db #(virtual cache_if.cpu_drv_mp)::set(
      null, "uvm_test_top.env.cpu_agent.drv", "vif", dut_if.cpu_drv_mp);

    // CPU monitor gets the cpu_mon_mp modport
    uvm_config_db #(virtual cache_if.cpu_mon_mp)::set(
      null, "uvm_test_top.env.cpu_agent.mon", "vif", dut_if.cpu_mon_mp);

    // Memory driver gets the mem_drv_mp modport
    uvm_config_db #(virtual cache_if.mem_drv_mp)::set(
      null, "uvm_test_top.env.mem_agent.drv", "vif", dut_if.mem_drv_mp);

    // Memory monitor gets the mem_mon_mp modport
    uvm_config_db #(virtual cache_if.mem_mon_mp)::set(
      null, "uvm_test_top.env.mem_agent.mon", "vif", dut_if.mem_mon_mp);

    // Hand control to UVM — test name supplied via +UVM_TESTNAME=
    run_test();
  end

  // -------------------------------------------------------
  // Timeout Watchdog — kill simulation if it hangs
  // -------------------------------------------------------
  initial begin
    #500_000ns;
    `uvm_fatal("TIMEOUT", "Simulation timeout — possible deadlock in FSM or driver")
  end

endmodule
