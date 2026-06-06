// ============================================================
// cache_seq_item.sv
// Transaction item for the 4-way set-associative cache UVM TB
// ============================================================
class cache_seq_item extends uvm_sequence_item;
  `uvm_object_utils_begin(cache_seq_item)
    `uvm_field_int(re,              UVM_ALL_ON)
    `uvm_field_int(we,              UVM_ALL_ON)
    `uvm_field_int(cpu_addr_read,   UVM_ALL_ON)
    `uvm_field_int(cpu_addr_write,  UVM_ALL_ON)
    `uvm_field_int(cpu_data_write,  UVM_ALL_ON)
    `uvm_field_int(write_byte_sel,  UVM_ALL_ON)
    // Response fields (populated by monitor)
    `uvm_field_int(cpu_data_read,   UVM_ALL_ON)
    `uvm_field_int(cache_stall_cpu, UVM_ALL_ON)
  `uvm_object_utils_end

  // --------------- Stimulus Fields ---------------
  rand logic        re;               // read enable
  rand logic        we;               // write enable
  rand logic [31:0] cpu_addr_read;    // read address  [31:12]=tag [11:6]=index [5:0]=offset
  rand logic [31:0] cpu_addr_write;   // write address
  rand logic [511:0] cpu_data_write;  // data to write (full 64-byte cache line)
  rand logic [63:0] write_byte_sel;   // byte-granular write mask

  // --------------- Response Fields ---------------
  logic [511:0] cpu_data_read;        // data returned on a read hit
  logic         cache_stall_cpu;      // stall signal back to CPU

  // --------------- Constraints ---------------

  // Only one of re/we active at a time (no simultaneous R+W for now)
  constraint one_op_c {
    re ^ we == 1'b1;  // exactly one active
  }

  // Aligned addresses: lower 6 bits = 0 (cache-line aligned)
  constraint addr_aligned_c {
    cpu_addr_read[5:0]  == 6'b0;
    cpu_addr_write[5:0] == 6'b0;
  }

  // Full-line writes by default (all bytes enabled)
  // Override in directed tests for partial writes
  constraint byte_sel_full_c {
    write_byte_sel == 64'hFFFF_FFFF_FFFF_FFFF;
  }

  // --------------- Constructor ---------------
  function new(string name = "cache_seq_item");
    super.new(name);
  endfunction

endclass
