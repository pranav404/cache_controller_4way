// ============================================================
// cache_sequences.sv
// All stimulus sequences for the 4-way cache controller TB
//
// Hierarchy:
//   cache_base_seq         — base class, all sequences extend this
//   ├── cache_read_seq     — N random read transactions
//   ├── cache_write_seq    — N random write transactions
//   ├── cache_rw_seq       — mixed random reads and writes
//   ├── cache_hit_seq      — guaranteed read hit (write then read same addr)
//   ├── cache_dirty_evict_seq — force a dirty line eviction (write-back path)
//   └── cache_plru_seq     — access ways in known order, verify PLRU victim
// ============================================================

// -------------------------------------------------------
// Base Sequence — shared utilities
// -------------------------------------------------------
class cache_base_seq extends uvm_sequence #(cache_seq_item);
  `uvm_object_utils(cache_base_seq)

  // Number of transactions to generate (override in tests)
  int unsigned num_txns = 10;

  function new(string name = "cache_base_seq");
    super.new(name);
  endfunction

  // Helper: send a single read transaction
  task do_read(input logic [31:0] addr);
    cache_seq_item txn;
    txn = cache_seq_item::type_id::create("txn");
    start_item(txn);
    if (!txn.randomize() with {
      re == 1'b1;
      we == 1'b0;
      cpu_addr_read == addr;
    }) `uvm_fatal("SEQ_RAND", "Randomization failed in do_read")
    finish_item(txn);
  endtask

  // Helper: send a single write transaction
  task do_write(input logic [31:0] addr, input logic [511:0] data,
                input logic [63:0] bsel = 64'hFFFF_FFFF_FFFF_FFFF);
    cache_seq_item txn;
    txn = cache_seq_item::type_id::create("txn");
    start_item(txn);
    if (!txn.randomize() with {
      re == 1'b0;
      we == 1'b1;
      cpu_addr_write  == addr;
      cpu_data_write  == data;
      write_byte_sel  == bsel;
    }) `uvm_fatal("SEQ_RAND", "Randomization failed in do_write")
    finish_item(txn);
  endtask

endclass


// -------------------------------------------------------
// Random Read Sequence
// Sends num_txns fully randomized read transactions
// -------------------------------------------------------
class cache_read_seq extends cache_base_seq;
  `uvm_object_utils(cache_read_seq)

  function new(string name = "cache_read_seq");
    super.new(name);
  endfunction

  task body();
    cache_seq_item txn;
    repeat (num_txns) begin
      txn = cache_seq_item::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize() with { re == 1'b1; we == 1'b0; })
        `uvm_fatal("SEQ_RAND", "Randomization failed in cache_read_seq")
      finish_item(txn);
    end
  endtask

endclass


// -------------------------------------------------------
// Random Write Sequence
// Sends num_txns fully randomized write transactions
// -------------------------------------------------------
class cache_write_seq extends cache_base_seq;
  `uvm_object_utils(cache_write_seq)

  function new(string name = "cache_write_seq");
    super.new(name);
  endfunction

  task body();
    cache_seq_item txn;
    repeat (num_txns) begin
      txn = cache_seq_item::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize() with { re == 1'b0; we == 1'b1; })
        `uvm_fatal("SEQ_RAND", "Randomization failed in cache_write_seq")
      finish_item(txn);
    end
  endtask

endclass


// -------------------------------------------------------
// Mixed Read/Write Sequence
// Randomly alternates reads and writes
// -------------------------------------------------------
class cache_rw_seq extends cache_base_seq;
  `uvm_object_utils(cache_rw_seq)

  function new(string name = "cache_rw_seq");
    super.new(name);
  endfunction

  task body();
    cache_seq_item txn;
    repeat (num_txns) begin
      txn = cache_seq_item::type_id::create("txn");
      start_item(txn);
      // re^we=1 constraint already in seq_item, just randomize freely
      if (!txn.randomize())
        `uvm_fatal("SEQ_RAND", "Randomization failed in cache_rw_seq")
      finish_item(txn);
    end
  endtask

endclass


// -------------------------------------------------------
// Read Hit Sequence
// Guarantees a read hit by writing a line first,
// then immediately reading the same address back
// -------------------------------------------------------
class cache_hit_seq extends cache_base_seq;
  `uvm_object_utils(cache_hit_seq)

  function new(string name = "cache_hit_seq");
    super.new(name);
  endfunction

  task body();
    logic [31:0]  addr;
    logic [511:0] wdata;

    repeat (num_txns) begin
      // Pick a random cache-line-aligned address
      addr  = {$urandom(), 6'b0};
      wdata = {$urandom(), $urandom(), $urandom(), $urandom(),
               $urandom(), $urandom(), $urandom(), $urandom(),
               $urandom(), $urandom(), $urandom(), $urandom(),
               $urandom(), $urandom(), $urandom(), $urandom()};

      // Step 1: Write the line into the cache
      do_write(addr, wdata);

      // Step 2: Read it back — must be a hit
      do_read(addr);

      `uvm_info("HIT_SEQ",
        $sformatf("Write then read @ addr=0x%08X", addr), UVM_MEDIUM)
    end
  endtask

endclass


// -------------------------------------------------------
// Dirty Eviction Sequence
// Forces a write-back by:
//   1. Writing to all 4 ways of the same index (fills set)
//   2. Writing to a 5th tag at the same index (forces eviction)
//      The evicted line must be dirty → triggers write-back
// -------------------------------------------------------
class cache_dirty_evict_seq extends cache_base_seq;
  `uvm_object_utils(cache_dirty_evict_seq)

  function new(string name = "cache_dirty_evict_seq");
    super.new(name);
  endfunction

  task body();
    logic [5:0]   index;
    logic [19:0]  tags [5];  // 5 distinct tags for same index
    logic [31:0]  addr;
    logic [511:0] wdata;

    repeat (num_txns) begin
      // Pick a random set index
      index = $urandom_range(0, 63);

      // Generate 5 distinct tags for this index
      foreach (tags[i])
        tags[i] = $urandom_range(1, 20'hFFFFF); // avoid tag=0

      // Ensure all 5 tags are unique
      tags[1] = tags[0] + 1;
      tags[2] = tags[0] + 2;
      tags[3] = tags[0] + 3;
      tags[4] = tags[0] + 4;

      // Step 1: Write to all 4 ways (fill the set with dirty lines)
      for (int i = 0; i < 4; i++) begin
        addr  = {tags[i], index, 6'b0};
        wdata = {$urandom(), $urandom(), $urandom(), $urandom(),
                 $urandom(), $urandom(), $urandom(), $urandom(),
                 $urandom(), $urandom(), $urandom(), $urandom(),
                 $urandom(), $urandom(), $urandom(), $urandom()};
        do_write(addr, wdata);
      end

      // Step 2: Write to a 5th tag at the same index
      // PLRU must evict one of the 4 dirty ways → write-back occurs
      addr  = {tags[4], index, 6'b0};
      wdata = {$urandom(), $urandom(), $urandom(), $urandom(),
               $urandom(), $urandom(), $urandom(), $urandom(),
               $urandom(), $urandom(), $urandom(), $urandom(),
               $urandom(), $urandom(), $urandom(), $urandom()};
      do_write(addr, wdata);

      `uvm_info("EVICT_SEQ",
        $sformatf("Dirty eviction @ index=%0d, evicting one of tags[0..3]", index),
        UVM_MEDIUM)
    end
  endtask

endclass


// -------------------------------------------------------
// PLRU Verification Sequence
// Accesses ways in a known order and verifies the
// PLRU selects the expected victim on the next miss
//
// Access order: way0 → way1 → way2 → way3
// After filling all 4, access way0 again
// Expected victim: way1 (LRU after way0 was just used)
// -------------------------------------------------------
class cache_plru_seq extends cache_base_seq;
  `uvm_object_utils(cache_plru_seq)

  function new(string name = "cache_plru_seq");
    super.new(name);
  endfunction

  task body();
    logic [5:0]  index;
    logic [19:0] tags [6]; // tags[0..3] fill set, tags[4] re-accesses way0, tags[5] is new miss
    logic [31:0] addr;
    logic [511:0] wdata;

    // Use a fixed index for determinism
    index = 6'd5;

    // 6 distinct tags
    tags[0] = 20'h00001;
    tags[1] = 20'h00002;
    tags[2] = 20'h00003;
    tags[3] = 20'h00004;
    tags[4] = 20'h00001; // re-access way0 (same as tags[0])
    tags[5] = 20'h00005; // new miss — should evict PLRU victim

    wdata = 512'hDEAD_BEEF;

    // Step 1: Read-miss fill all 4 ways
    // Order: way0(tags[0]), way1(tags[1]), way2(tags[2]), way3(tags[3])
    for (int i = 0; i < 4; i++) begin
      addr = {tags[i], index, 6'b0};
      do_read(addr); // miss → fills way i
    end

    // Step 2: Re-access way0 (makes way0 MRU, way1 becomes LRU candidate)
    addr = {tags[4], index, 6'b0};
    do_read(addr); // hit on way0, updates PLRU

    // Step 3: New miss — scoreboard will verify PLRU victim is correct
    addr = {tags[5], index, 6'b0};
    do_read(addr); // miss → evict PLRU victim

    `uvm_info("PLRU_SEQ",
      $sformatf("PLRU sequence complete @ index=%0d", index), UVM_MEDIUM)

  endtask

endclass

