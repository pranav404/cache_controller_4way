// ============================================================
// cache_coverage.sv
// Functional coverage collector for the 4-way cache controller
//
// Subscribes to both CPU and memory monitor analysis ports.
// Covergroups track whether all important scenarios were hit
// during simulation — things the scoreboard cannot auto-check.
// ============================================================
class cache_coverage extends uvm_subscriber #(cache_seq_item);
  `uvm_component_utils(cache_coverage)

  // Second import for memory-side transactions
  uvm_analysis_imp_mem #(cache_mem_seq_item, cache_coverage) mem_export;

  // Current transaction being sampled
  cache_seq_item     cpu_txn;
  cache_mem_seq_item mem_txn;

  // -------------------------------------------------------
  // Covergroup 1: CPU Operation Types
  // Did we cover reads, writes, hits, misses, and stalls?
  // -------------------------------------------------------
  covergroup cg_cpu_ops;

    cp_op_type: coverpoint cpu_txn.re {
      bins read  = {1'b1};
      bins write = {1'b0};  // we=1 when re=0 (enforced by seq_item constraint)
    }

    cp_stall: coverpoint cpu_txn.cache_stall_cpu {
      bins stalled    = {1'b1};
      bins not_stalled = {1'b0};
    }

    // Cross: read/write x stall — ensures we see hits (no stall) and misses (stall)
    cx_op_stall: cross cp_op_type, cp_stall;

  endgroup

  // -------------------------------------------------------
  // Covergroup 2: Address Space Coverage
  // Did we access all 64 sets? Did we vary tags?
  // -------------------------------------------------------
  covergroup cg_address;

    // All 64 cache sets covered on reads
    cp_read_index: coverpoint cpu_txn.cpu_addr_read[11:6] {
      bins all_sets[] = {[0:63]};
    }

    // All 64 cache sets covered on writes
    cp_write_index: coverpoint cpu_txn.cpu_addr_write[11:6] {
      bins all_sets[] = {[0:63]};
    }

    // Tag range — coarse bins to ensure tag space is explored
    cp_read_tag: coverpoint cpu_txn.cpu_addr_read[31:12] {
      bins low_tags  = {[20'h00000 : 20'h3FFFF]};
      bins mid_tags  = {[20'h40000 : 20'h7FFFF]};
      bins high_tags = {[20'h80000 : 20'hFFFFF]};
    }

  endgroup

  // -------------------------------------------------------
  // Covergroup 3: Write Byte Select Patterns
  // Did we test partial writes as well as full-line writes?
  // -------------------------------------------------------
  covergroup cg_byte_sel;

    cp_byte_sel: coverpoint cpu_txn.write_byte_sel {
      bins full_write  = {64'hFFFF_FFFF_FFFF_FFFF};  // all bytes
      bins low_half    = {64'h0000_0000_FFFF_FFFF};  // lower 32 bytes
      bins high_half   = {64'hFFFF_FFFF_0000_0000};  // upper 32 bytes
      bins single_byte = {64'h0000_0000_0000_0001};  // byte 0 only
      bins other       = default;
    }

  endgroup

  // -------------------------------------------------------
  // Covergroup 4: Memory Interface Events
  // Did the cache issue reads and writes to memory?
  // Did write-backs occur?
  // -------------------------------------------------------
  covergroup cg_mem_ops;

    cp_mem_re: coverpoint mem_txn.mem_re {
      bins mem_read  = {1'b1};
      bins no_read   = {1'b0};
    }

    cp_mem_we: coverpoint mem_txn.mem_we {
      bins mem_write  = {1'b1};  // write-back
      bins no_write   = {1'b0};
    }

    cp_mem_ack: coverpoint mem_txn.mem_ack {
      bins acked     = {1'b1};
      bins not_acked = {1'b0};
    }

    // Cross: ensure we saw both read-fills and write-backs acknowledged
    cx_mem_rw_ack: cross cp_mem_re, cp_mem_we, cp_mem_ack;

  endgroup

  // -------------------------------------------------------
  // Covergroup 5: PLRU Victim Selection
  // Did PLRU select all 4 ways as victims at least once?
  // -------------------------------------------------------

  // Track which way was the PLRU victim — driven externally
  // by the scoreboard or a dedicated tracker
  logic [1:0] plru_victim_way;
  logic       plru_victim_valid;

  covergroup cg_plru;

    cp_victim_way: coverpoint plru_victim_way {
      bins way0 = {2'b00};
      bins way1 = {2'b01};
      bins way2 = {2'b10};
      bins way3 = {2'b11};
    }

  endgroup

  // -------------------------------------------------------
  // Covergroup 6: Cache State Transitions
  // Coarse FSM state coverage — did we exercise all major paths?
  // Tracked via observed signal patterns, not direct FSM access
  // -------------------------------------------------------
  covergroup cg_scenarios;

    // Read hit  = re=1, no stall
    // Read miss = re=1, stall
    // Write hit  = we=1, no stall
    // Write miss = we=1, stall
    cp_scenario: coverpoint {cpu_txn.re, cpu_txn.we, cpu_txn.cache_stall_cpu} {
      bins read_hit   = {3'b100};  // re=1, we=0, stall=0
      bins read_miss  = {3'b101};  // re=1, we=0, stall=1
      bins write_hit  = {3'b010};  // re=0, we=1, stall=0
      bins write_miss = {3'b011};  // re=0, we=1, stall=1
    }

  endgroup

  // -------------------------------------------------------
  // Constructor — instantiate all covergroups
  // -------------------------------------------------------
  function new(string name = "cache_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_cpu_ops  = new();
    cg_address  = new();
    cg_byte_sel = new();
    cg_mem_ops  = new();
    cg_plru     = new();
    cg_scenarios = new();
    plru_victim_valid = 1'b0;
    plru_victim_way   = 2'b0;
  endfunction

  // -------------------------------------------------------
  // Build Phase
  // -------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mem_export = new("mem_export", this);
  endfunction

  // -------------------------------------------------------
  // write() — called by CPU monitor analysis port
  // uvm_subscriber base class provides the cpu analysis imp
  // -------------------------------------------------------
  function void write(cache_seq_item t);
    cpu_txn = t;
    cg_cpu_ops.sample();
    cg_address.sample();
    cg_scenarios.sample();

    // Only sample byte_sel on writes
    if (t.we)
      cg_byte_sel.sample();
  endfunction

  // -------------------------------------------------------
  // write_mem() — called by memory monitor analysis port
  // -------------------------------------------------------
  function void write_mem(cache_mem_seq_item t);
    mem_txn = t;
    cg_mem_ops.sample();
  endfunction

  // -------------------------------------------------------
  // sample_plru_victim() — called externally by scoreboard
  // when it determines a PLRU victim during a miss
  // -------------------------------------------------------
  function void sample_plru_victim(input logic [1:0] way);
    plru_victim_way   = way;
    plru_victim_valid = 1'b1;
    cg_plru.sample();
  endfunction

  // -------------------------------------------------------
  // Report Phase — print coverage summary
  // -------------------------------------------------------
  function void report_phase(uvm_phase phase);
    `uvm_info("COV_REPORT", $sformatf(
      "\n============ COVERAGE SUMMARY ============\n"|
      "  CPU Ops Coverage     : %0.1f%%\n" |
      "  Address Coverage     : %0.1f%%\n" |
      "  Byte Sel Coverage    : %0.1f%%\n" |
      "  Memory Ops Coverage  : %0.1f%%\n" |
      "  PLRU Victim Coverage : %0.1f%%\n" |
      "  Scenario Coverage    : %0.1f%%\n" |
      "==========================================",
      cg_cpu_ops.get_coverage(),
      cg_address.get_coverage(),
      cg_byte_sel.get_coverage(),
      cg_mem_ops.get_coverage(),
      cg_plru.get_coverage(),
      cg_scenarios.get_coverage()),UVM_NONE)
  endfunction

endclass
