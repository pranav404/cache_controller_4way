// ============================================================
// cache_base_test.sv
// Base test — all directed tests extend this
// Builds the environment, configures virtual interfaces,
// and provides common reset + run infrastructure
// ============================================================
class cache_base_test extends uvm_test;
  `uvm_component_utils(cache_base_test)

  cache_env env;

  function new(string name = "cache_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = cache_env::type_id::create("env", this);
  endfunction

  // All tests share the same 10-cycle reset sequence
  task apply_reset(virtual cache_if vif);
    vif.rst_n = 1'b0;
    repeat(10) @(posedge vif.clk);
    vif.rst_n = 1'b1;
    `uvm_info("BASE_TEST", "Reset deasserted", UVM_LOW)
  endtask

  // Default run_phase: subclasses override this
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("BASE_TEST", "run_phase: no sequence launched (use a directed test)", UVM_LOW)
    #100ns;
    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server svr = uvm_report_server::get_server();
    if (svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("BASE_TEST", "*** TEST PASSED ***", UVM_NONE)
    else
      `uvm_error("BASE_TEST", $sformatf("*** TEST FAILED — %0d error(s) ***",
                 svr.get_severity_count(UVM_ERROR)))
  endfunction

endclass


// ============================================================
// cache_directed_tests.sv (combined in same file for clarity)
// Each test runs one specific sequence
// Launch with: +UVM_TESTNAME=cache_read_hit_test  etc.
// ============================================================

// -------------------------------------------------------
// Read Hit Test
// Writes lines then reads them back — verifies hit path
// -------------------------------------------------------
class cache_read_hit_test extends cache_base_test;
  `uvm_component_utils(cache_read_hit_test)

  function new(string name = "cache_read_hit_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cache_hit_seq seq;
    phase.raise_objection(this);

    seq = cache_hit_seq::type_id::create("seq");
    seq.num_txns = 20;
    seq.start(env.cpu_agent.sqr);

    phase.drop_objection(this);
  endtask

endclass


// -------------------------------------------------------
// Random Read Test
// Purely random reads — mix of hits and misses
// -------------------------------------------------------
class cache_random_read_test extends cache_base_test;
  `uvm_component_utils(cache_random_read_test)

  function new(string name = "cache_random_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cache_read_seq seq;
    phase.raise_objection(this);

    seq = cache_read_seq::type_id::create("seq");
    seq.num_txns = 50;
    seq.start(env.cpu_agent.sqr);

    phase.drop_objection(this);
  endtask

endclass


// -------------------------------------------------------
// Random Write Test
// Purely random writes — exercises write hit and miss paths
// -------------------------------------------------------
class cache_random_write_test extends cache_base_test;
  `uvm_component_utils(cache_random_write_test)

  function new(string name = "cache_random_write_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cache_write_seq seq;
    phase.raise_objection(this);

    seq = cache_write_seq::type_id::create("seq");
    seq.num_txns = 50;
    seq.start(env.cpu_agent.sqr);

    phase.drop_objection(this);
  endtask

endclass


// -------------------------------------------------------
// Mixed R/W Test
// Random mix of reads and writes
// -------------------------------------------------------
class cache_rw_test extends cache_base_test;
  `uvm_component_utils(cache_rw_test)

  function new(string name = "cache_rw_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cache_rw_seq seq;
    phase.raise_objection(this);

    seq = cache_rw_seq::type_id::create("seq");
    seq.num_txns = 100;
    seq.start(env.cpu_agent.sqr);

    phase.drop_objection(this);
  endtask

endclass


// -------------------------------------------------------
// Dirty Eviction Test
// Forces dirty line evictions — exercises write-back path
// -------------------------------------------------------
class cache_dirty_evict_test extends cache_base_test;
  `uvm_component_utils(cache_dirty_evict_test)

  function new(string name = "cache_dirty_evict_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cache_dirty_evict_seq seq;
    phase.raise_objection(this);

    seq = cache_dirty_evict_seq::type_id::create("seq");
    seq.num_txns = 10;
    seq.start(env.cpu_agent.sqr);

    phase.drop_objection(this);
  endtask

endclass


// -------------------------------------------------------
// PLRU Verification Test
// Deterministic access order to verify PLRU victim selection
// -------------------------------------------------------
class cache_plru_test extends cache_base_test;
  `uvm_component_utils(cache_plru_test)

  function new(string name = "cache_plru_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    cache_plru_seq seq;
    phase.raise_objection(this);

    seq = cache_plru_seq::type_id::create("seq");
    seq.start(env.cpu_agent.sqr);

    phase.drop_objection(this);
  endtask

endclass
