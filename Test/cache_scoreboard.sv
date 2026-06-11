// ============================================================
// cache_scoreboard.sv
// Golden reference model + checker for the 4-way set-associative
// write-back cache controller
//
// Receives transactions from:
//   - cpu_export  : cache_seq_item     (CPU-side monitor)
//   - mem_export  : cache_mem_seq_item (Memory-side monitor)
//
// Maintains a software model of the cache and compares DUT
// outputs against expected values cycle by cycle.
// ============================================================
class cache_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(cache_scoreboard)

  // -------------------------------------------------------
  // TLM Analysis Imports — monitors write to these
  // -------------------------------------------------------
  uvm_analysis_imp_cpu #(cache_seq_item,     cache_scoreboard) cpu_export;
  uvm_analysis_imp_mem #(cache_mem_seq_item, cache_scoreboard) mem_export;

  // -------------------------------------------------------
  // Golden Cache Model
  // Mirrors the DUT's internal state in software
  // -------------------------------------------------------

  // Tag entry: holds tag, valid, dirty per way
  typedef struct {
    logic [19:0] tag;
    logic        valid;
    logic        dirty;
  } tag_entry_t;

  // Data entry: holds 512-bit cache line per way
  typedef logic [511:0] data_entry_t;

  // 64 sets x 4 ways
  tag_entry_t  golden_tags  [64][4];
  data_entry_t golden_data  [64][4];

  // PLRU tree: 3 bits per set, 64 sets
  logic [2:0]  golden_plru  [64];

  // Backing memory model (mirrors cache_mem_driver's mem_model)
  // Used to verify write-back data and read-fill data
  logic [511:0] golden_mem [logic [31:0]];

  // -------------------------------------------------------
  // Counters for reporting
  // -------------------------------------------------------
  int read_hits;
  int read_misses;
  int write_hits;
  int write_misses;
  int write_backs;
  int errors;

  // -------------------------------------------------------
  // Constructor
  // -------------------------------------------------------
  function new(string name = "cache_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------
  // Build Phase
  // -------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cpu_export = new("cpu_export", this);
    mem_export = new("mem_export", this);

    // Initialize golden model — all invalid, clean, zero
    for (int s = 0; s < 64; s++) begin
      for (int w = 0; w < 4; w++) begin
        golden_tags[s][w].tag   = 20'b0;
        golden_tags[s][w].valid = 1'b0;
        golden_tags[s][w].dirty = 1'b0;
        golden_data[s][w]       = 512'b0;
      end
      golden_plru[s] = 3'b0;
    end

    read_hits    = 0;
    read_misses  = 0;
    write_hits   = 0;
    write_misses = 0;
    write_backs  = 0;
    errors       = 0;
  endfunction

  // -------------------------------------------------------
  // CPU-side transaction handler
  // Called by cpu_export whenever the CPU monitor fires
  // -------------------------------------------------------
  function void write_cpu(cache_seq_item txn);

    if (txn.re) begin
      check_read(txn);
    end
    else if (txn.we) begin
      check_write(txn);
    end

  endfunction

  // -------------------------------------------------------
  // Memory-side transaction handler
  // Called by mem_export whenever the memory monitor fires
  // -------------------------------------------------------
  function void write_mem(cache_mem_seq_item txn);

    // Write-back observed: verify data matches what golden model evicted
    if (txn.mem_we) begin
      check_writeback(txn);
    end

    // Read fill observed: update golden memory model so future
    // write-back checks have the correct expected data
    if (txn.mem_re && txn.mem_ack) begin
      golden_mem[txn.mem_addr_read] = txn.mem_data_read;
    end

  endfunction

  // -------------------------------------------------------
  // READ CHECK
  // Determine if the read should be a hit or miss in the
  // golden model, then verify DUT response accordingly
  // -------------------------------------------------------
  function void check_read(cache_seq_item txn);
    logic [19:0] req_tag;
    logic [5:0]  req_index;
    int          hit_way;
    logic [511:0] expected_data;

    req_tag   = txn.cpu_addr_read[31:12];
    req_index = txn.cpu_addr_read[11:6];
    hit_way   = -1;

    // Search all 4 ways for a tag match
    for (int w = 0; w < 4; w++) begin
      if (golden_tags[req_index][w].valid &&
          golden_tags[req_index][w].tag == req_tag) begin
        hit_way = w;
        break;
      end
    end

    // --- READ HIT ---
    if (hit_way >= 0) begin
      read_hits++;
      expected_data = golden_data[req_index][hit_way];

      // Verify DUT returned the correct data
      if (txn.cpu_data_read !== expected_data) begin
        `uvm_error("SCB_READ_HIT",
          $sformatf("READ HIT DATA MISMATCH @ addr=0x%08X\n  Expected: 0x%0X\n  Got:      0x%0X",
          txn.cpu_addr_read, expected_data, txn.cpu_data_read))
        errors++;
      end else begin
        `uvm_info("SCB_READ_HIT",
          $sformatf("READ HIT OK @ addr=0x%08X way=%0d", txn.cpu_addr_read, hit_way),
          UVM_HIGH)
      end

      // Verify DUT did NOT stall on a hit
      if (txn.cache_stall_cpu) begin
        `uvm_error("SCB_READ_HIT_STALL",
          $sformatf("Unexpected stall on READ HIT @ addr=0x%08X", txn.cpu_addr_read))
        errors++;
      end

      // Update golden PLRU — this way was just used
      update_plru(req_index, hit_way[1:0]);

    // --- READ MISS ---
    end else begin
      read_misses++;
      `uvm_info("SCB_READ_MISS",
        $sformatf("READ MISS @ addr=0x%08X index=%0d tag=0x%05X",
        txn.cpu_addr_read, req_index, req_tag),
        UVM_MEDIUM)

      // On a miss, DUT should have stalled
      if (!txn.cache_stall_cpu) begin
        `uvm_error("SCB_READ_MISS_NO_STALL",
          $sformatf("Expected stall on READ MISS @ addr=0x%08X but none observed",
          txn.cpu_addr_read))
        errors++;
      end

      // Determine victim way from golden PLRU
      begin
        logic [1:0] victim;
        victim = get_plru_victim(req_index);

        // If victim is valid+dirty, a write-back should occur
        // (checked separately in check_writeback)
        // Update golden model: install new line at victim way
        golden_tags[req_index][victim].tag   = req_tag;
        golden_tags[req_index][victim].valid = 1'b1;
        golden_tags[req_index][victim].dirty = 1'b0;  // clean on read fill

        // Data comes from memory — use golden_mem if available
        if (golden_mem.exists(txn.cpu_addr_read))
          golden_data[req_index][victim] = golden_mem[txn.cpu_addr_read];
        else
          golden_data[req_index][victim] = {16{txn.cpu_addr_read}}; // matches mem driver fill

        update_plru(req_index, victim);
      end
    end

  endfunction

  // -------------------------------------------------------
  // WRITE CHECK
  // -------------------------------------------------------
  function void check_write(cache_seq_item txn);
    logic [19:0] req_tag;
    logic [5:0]  req_index;
    int          hit_way;

    req_tag   = txn.cpu_addr_write[31:12];
    req_index = txn.cpu_addr_write[11:6];
    hit_way   = -1;

    // Search all 4 ways for a tag match
    for (int w = 0; w < 4; w++) begin
      if (golden_tags[req_index][w].valid &&
          golden_tags[req_index][w].tag == req_tag) begin
        hit_way = w;
        break;
      end
    end

    // --- WRITE HIT ---
    if (hit_way >= 0) begin
      write_hits++;

      // Update golden data with byte masking
      for (int b = 0; b < 64; b++) begin
        if (txn.write_byte_sel[b])
          golden_data[req_index][hit_way][b*8 +: 8] = txn.cpu_data_write[b*8 +: 8];
      end

      // Mark dirty
      golden_tags[req_index][hit_way].dirty = 1'b1;

      `uvm_info("SCB_WRITE_HIT",
        $sformatf("WRITE HIT OK @ addr=0x%08X way=%0d", txn.cpu_addr_write, hit_way),
        UVM_HIGH)

      // Write hit should not stall
      if (txn.cache_stall_cpu) begin
        `uvm_error("SCB_WRITE_HIT_STALL",
          $sformatf("Unexpected stall on WRITE HIT @ addr=0x%08X", txn.cpu_addr_write))
        errors++;
      end

      update_plru(req_index, hit_way[1:0]);

    // --- WRITE MISS ---
    end else begin
      write_misses++;
      `uvm_info("SCB_WRITE_MISS",
        $sformatf("WRITE MISS @ addr=0x%08X index=%0d tag=0x%05X",
        txn.cpu_addr_write, req_index, req_tag),
        UVM_MEDIUM)

      // Write miss must stall
      if (!txn.cache_stall_cpu) begin
        `uvm_error("SCB_WRITE_MISS_NO_STALL",
          $sformatf("Expected stall on WRITE MISS @ addr=0x%08X but none observed",
          txn.cpu_addr_write))
        errors++;
      end

      // Allocate: get victim, install new line, apply write data
      begin
        logic [1:0] victim;
        victim = get_plru_victim(req_index);

        // Fetch from memory first (write-allocate policy)
        if (golden_mem.exists(txn.cpu_addr_write))
          golden_data[req_index][victim] = golden_mem[txn.cpu_addr_write];
        else
          golden_data[req_index][victim] = {16{txn.cpu_addr_write}};

        // Apply byte-masked CPU write data on top
        for (int b = 0; b < 64; b++) begin
          if (txn.write_byte_sel[b])
            golden_data[req_index][victim][b*8 +: 8] = txn.cpu_data_write[b*8 +: 8];
        end

        golden_tags[req_index][victim].tag   = req_tag;
        golden_tags[req_index][victim].valid = 1'b1;
        golden_tags[req_index][victim].dirty = 1'b1;  // dirty after write

        update_plru(req_index, victim);
      end
    end

  endfunction

  // -------------------------------------------------------
  // WRITE-BACK CHECK
  // Verify that when the cache evicts a dirty line, the data
  // written to memory matches what the golden model has
  // -------------------------------------------------------
  function void check_writeback(cache_mem_seq_item txn);
    logic [31:0]  wb_addr;
    logic [511:0] expected_data;
    logic [19:0]  wb_tag;
    logic [5:0]   wb_index;

    write_backs++;
    wb_addr  = txn.mem_addr_write;
    wb_tag   = wb_addr[31:12];
    wb_index = wb_addr[11:6];

    // Find the way in golden model with this tag
    begin
      int found_way = -1;
      for (int w = 0; w < 4; w++) begin
        if (golden_tags[wb_index][w].tag == wb_tag &&
            golden_tags[wb_index][w].valid &&
            golden_tags[wb_index][w].dirty) begin
          found_way = w;
          break;
        end
      end

      if (found_way < 0) begin
        `uvm_error("SCB_WB_NO_DIRTY",
          $sformatf("WRITE-BACK observed @ addr=0x%08X but golden model has no dirty line there",
          wb_addr))
        errors++;
        return;
      end

      expected_data = golden_data[wb_index][found_way];

      if (txn.mem_data_write !== expected_data) begin
        `uvm_error("SCB_WB_DATA",
          $sformatf("WRITE-BACK DATA MISMATCH @ addr=0x%08X\n  Expected: 0x%0X\n  Got:      0x%0X",
          wb_addr, expected_data, txn.mem_data_write))
        errors++;
      end else begin
        `uvm_info("SCB_WB_OK",
          $sformatf("WRITE-BACK OK @ addr=0x%08X way=%0d", wb_addr, found_way),
          UVM_MEDIUM)
      end

      // Store evicted data in golden_mem so future reads get correct data
      golden_mem[wb_addr] = expected_data;

      // Invalidate the evicted way in golden model
      golden_tags[wb_index][found_way].valid = 1'b0;
      golden_tags[wb_index][found_way].dirty = 1'b0;
    end

  endfunction

  // -------------------------------------------------------
  // GOLDEN PLRU HELPERS
  // Must mirror the DUT's plru_way_selector logic exactly
  //
  // Encoding (3 bits per set):
  //   [2] = root: 0 → left subtree (ways 0/1), 1 → right subtree (ways 2/3)
  //   [1] = left child:  0→way0 victim, 1→way1 victim
  //   [0] = right child: 0→way2 victim, 1→way3 victim
  // -------------------------------------------------------

  // Return the victim way for a given set index
  function logic [1:0] get_plru_victim(input logic [5:0] index);
    logic [2:0] tree;
    tree = golden_plru[index];

    if (tree[2]) begin           // root points right → victim in right subtree
      if (tree[0]) return 2'b11; // right child points right → way 3
      else         return 2'b10; // right child points left  → way 2
    end else begin               // root points left → victim in left subtree
      if (tree[1]) return 2'b01; // left child points right  → way 1
      else         return 2'b00; // left child points left   → way 0
    end
  endfunction

  // Update PLRU tree after accessing a given way
  function void update_plru(input logic [5:0] index, input logic [1:0] way);
    case (way)
      2'b00: golden_plru[index] = {1'b1, 1'b1, golden_plru[index][0]}; // used way0: point away
      2'b01: golden_plru[index] = {1'b1, 1'b0, golden_plru[index][0]}; // used way1
      2'b10: golden_plru[index] = {1'b0, golden_plru[index][1], 1'b1}; // used way2
      2'b11: golden_plru[index] = {1'b0, golden_plru[index][1], 1'b0}; // used way3
    endcase
  endfunction

  // -------------------------------------------------------
  // Final Phase — print summary report
  // -------------------------------------------------------

  function void report_phase(uvm_phase phase);
        `uvm_info("SCB_REPORT", $sformatf({
            "\n================ SCOREBOARD SUMMARY ================\n",
            "  Read Hits    : %0d\n",
            "  Read Misses  : %0d\n",
            "  Write Hits   : %0d\n",
            "  Write Misses : %0d\n",
            "  Write-Backs  : %0d\n",
            "  ERRORS       : %0d\n",
            "====================================================\n"},read_hits, read_misses, write_hits, write_misses, write_backs, errors), UVM_NONE)
    if (errors == 0)
      `uvm_info("SCB_REPORT",  "*** ALL CHECKS PASSED ***", UVM_NONE)
    else
      `uvm_error("SCB_REPORT", $sformatf("*** %0d ERRORS DETECTED ***", errors))
  endfunction

endclass
