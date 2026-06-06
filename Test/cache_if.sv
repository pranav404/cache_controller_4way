// ============================================================
// cache_if.sv
// Virtual interface for the 4-way cache controller
// Clocking blocks enforce proper setup/hold relative to clk
// ============================================================
interface cache_if (input logic clk);

  // ----------- CPU-side signals -----------
  logic        rst_n;
  logic        re;
  logic        we;
  logic [31:0] cpu_addr_read;
  logic [31:0] cpu_addr_write;
  logic [511:0] cpu_data_write;
  logic [63:0]  write_byte_sel;
  logic        cpu_stall_cache;   // CPU stalls the cache externally

  logic [511:0] cpu_data_read;    // output from DUT
  logic         cache_stall_cpu;  // output from DUT

  // ----------- Memory-side signals -----------
  logic [31:0]  mem_addr_read;    // output from DUT
  logic [31:0]  mem_addr_write;   // output from DUT
  logic         mem_re;           // output from DUT
  logic         mem_we;           // output from DUT
  logic [511:0] mem_data_write;   // output from DUT
  logic         cache_stall_mem;  // output from DUT

  logic         mem_ack;          // input to DUT (driven by mem agent)
  logic [511:0] mem_data_read;    // input to DUT (driven by mem agent)
  logic         mem_stall_cache;  // input to DUT (driven by mem agent)

  // -------------------------------------------------------
  // CPU Driver Clocking Block
  // Drives inputs to DUT 1ns before rising edge (setup time)
  // Samples DUT outputs 1ns after rising edge
  // -------------------------------------------------------
  clocking cpu_drv_cb @(posedge clk);
    default input #1ns output #1ns;
    output re, we;
    output cpu_addr_read, cpu_addr_write;
    output cpu_data_write, write_byte_sel;
    output cpu_stall_cache;
    input  cpu_data_read;
    input  cache_stall_cpu;
  endclocking

  // -------------------------------------------------------
  // CPU Monitor Clocking Block (input only, samples outputs)
  // -------------------------------------------------------
  clocking cpu_mon_cb @(posedge clk);
    default input #1ns;
    input re, we;
    input cpu_addr_read, cpu_addr_write;
    input cpu_data_write, write_byte_sel;
    input cpu_data_read;
    input cache_stall_cpu;
  endclocking

  // -------------------------------------------------------
  // Memory Driver Clocking Block
  // Memory agent drives mem_ack and mem_data_read
  // -------------------------------------------------------
  clocking mem_drv_cb @(posedge clk);
    default input #1ns output #1ns;
    output mem_ack;
    output mem_data_read;
    output mem_stall_cache;
    input  mem_re, mem_we;
    input  mem_addr_read, mem_addr_write;
    input  mem_data_write;
  endclocking

  // -------------------------------------------------------
  // Memory Monitor Clocking Block
  // -------------------------------------------------------
  clocking mem_mon_cb @(posedge clk);
    default input #1ns;
    input mem_re, mem_we;
    input mem_addr_read, mem_addr_write;
    input mem_data_write;
    input mem_ack, mem_data_read, mem_stall_cache;
  endclocking

  // -------------------------------------------------------
  // Modports (optional but good practice)
  // -------------------------------------------------------
  modport cpu_drv_mp  (clocking cpu_drv_cb, input clk, output rst_n);
  modport cpu_mon_mp  (clocking cpu_mon_cb, input clk);
  modport mem_drv_mp  (clocking mem_drv_cb, input clk);
  modport mem_mon_mp  (clocking mem_mon_cb, input clk);

endinterface
