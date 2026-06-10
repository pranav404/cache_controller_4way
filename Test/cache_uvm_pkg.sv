// ============================================================
// cache_uvm_pkg.sv
// UVM package — include all TB classes in dependency order
// ============================================================
package cache_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_cpu)
  `uvm_analysis_imp_decl(_mem)

  // Transaction items (no dependencies)
  `include "cache_seq_item.sv"
  `include "cache_mem_seq_item.sv"

  // CPU agent components
  `include "cache_cpu_sequencer.sv"
  `include "cache_cpu_driver.sv"
  `include "cache_cpu_monitor.sv"
  `include "cache_cpu_agent.sv"

  // Memory agent components
  `include "cache_mem_driver.sv"
  `include "cache_mem_monitor.sv"
  `include "cache_mem_agent.sv"

  // Scoreboard (needs seq_items)
  `include "cache_scoreboard.sv"

  // Coverage (needs seq_items)
  `include "cache_coverage.sv"

  // Sequences (needs seq_item + base classes)
  `include "cache_sequences.sv"

  // Environment (needs agents + scoreboard + coverage)
  `include "cache_env.sv"

  // Tests (needs env + sequences — always last)
  `include "cache_base_test.sv"

endpackage
