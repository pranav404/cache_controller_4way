// ============================================================
// cache_mem_seq_item.sv
// Transaction item for the memory side (responses to cache)
// ============================================================
class cache_mem_seq_item extends uvm_sequence_item;

  // Driven by memory agent (responses into DUT)
  rand logic         mem_ack;         // acknowledge signal
  rand logic [511:0] mem_data_read;   // data returned to cache on a read fill
  rand logic         mem_stall_cache; // memory stalls the cache

  // Observed from DUT (captured by memory monitor)
  logic         mem_re;
  logic         mem_we;
  logic [31:0]  mem_addr_read;
  logic [31:0]  mem_addr_write;
  logic [511:0] mem_data_write;

  `uvm_object_utils_begin(cache_mem_seq_item)
    `uvm_field_int(mem_ack,        UVM_ALL_ON)
    `uvm_field_int(mem_data_read,  UVM_ALL_ON)
    `uvm_field_int(mem_stall_cache,UVM_ALL_ON)
    `uvm_field_int(mem_re,         UVM_ALL_ON)
    `uvm_field_int(mem_we,         UVM_ALL_ON)
    `uvm_field_int(mem_addr_read,  UVM_ALL_ON)
    `uvm_field_int(mem_addr_write, UVM_ALL_ON)
    `uvm_field_int(mem_data_write, UVM_ALL_ON)
  `uvm_object_utils_end

  
  // Latency in cycles before mem_ack is asserted (default 4 cycles)
  rand int unsigned ack_delay;
  constraint ack_delay_c { ack_delay inside {[2:8]}; }

  // Don't stall by default
  constraint no_stall_c { mem_stall_cache == 1'b0; }

  function new(string name = "cache_mem_seq_item");
    super.new(name);
  endfunction

endclass
