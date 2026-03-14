module cache_controller (
    input  logic         clk,   //clock
    input  logic         rst,   //reset
    // CPU Interface
    input  logic [31:0]  cpu_addr_rd, //memory address read from CPU
    input  logic [31:0]  cpu_addr_wr, //memory address write from CPU
    input  logic         cpu_re,      // Write Enable from CPU
    input  logic         cpu_we,      // Read Enable from CPU
    input  logic [31:0] din_data_CPU, // 4-byte data to write from CPU
    input  logic stall_cache //signal from cpu to cache to stall
    output logic [511:0] dout_data_cache_cpu, //cache out to CPU
    output logic stall_cpu //signal from cache to cpu to stall


    //memory interface
    input  logic mem_stall_cache //signal from memory to stall the cache
    input  logic [511:0] mem_in_data; //data from memory to cache
    output logic [31:0]  mem_out_addr; //addr from cache to memory




   
);

    // --- 1. Address Decoding ---
    // For 16KB 4-way cache with 64B lines:
    // [31:12] Tag (20 bits)
    // [11:6]  Index (6 bits)
    // [5:0]   Offset (6 bits)
    logic [19:0] addr_tag;
    logic [5:0]  addr_index;
    logic [511:0] cmp_out_data;
    logic [511:0] dout_data[0:3];
    logic [511:0] cmp_out_data;
    logic [19:0] dout_tag [0:3];
    logic dout_dirty [0:3];
    logic dout_valid [0:3];
    logic cmp_hit;

    assign addr_tag   = cpu_addr[31:12];
    assign addr_index = cpu_addr[11:6];

    // --- 2. Tag Array Instantiation ---
    tag_array tags (
        .clk        (clk),
        .w_index    (addr_index),    // [cite: 5]
        .r_index    (addr_index),    // [cite: 5]
        .we         (mem_we),        // [cite: 5]
        .re         (mem_re),        // [cite: 5]
        .way_sel    (way_sel),       // [cite: 5]
        .din_tag    (addr_tag),      // [cite: 5]
        .din_valid  (din_valid),     // [cite: 5]
        .din_dirty  (din_dirty),     // [cite: 5]
        .dout_tag   (dout_tag),      // [cite: 5]
        .dout_valid (dout_valid),    // [cite: 5]
        .dout_dirty (dout_dirty)     // [cite: 5]
    );

    // --- 3. Data Array Instantiation ---
    data_array data (
        .clk        (clk),
        .w_index    (addr_index),    // [cite: 1]
        .r_index    (addr_index),    // [cite: 1]
        .we         (mem_we),        // [cite: 1]
        .re         (mem_re),        // [cite: 1]
        .way_sel    (way_sel),       // [cite: 1]
        .din_data   (din_data),      // [cite: 1]
        .byte_sel   (byte_sel),      // [cite: 1]
        .dout_data  (dout_data)      // [cite: 1]
    );

    // --- 4. Comparator and selector instantiation

    comparator_selector(
        .in_tags    (dout_tag),
        .in_cmp_tag (addr_tag),
        .in_data    (dout_data),
        .valid_in   (dout_valid),
        .dirty_in   (dout_dirty),
        .cache_hit  (cmp_hit),
        .hit_data   (cmp_out_data)
        
    )

    assign stall_cpu = (cpu_re && !cmp_hit);
    assign dout_data_cache_cpu = hit_data;
    


endmodule