`timescale 1ns / 1ps

module data_array_tb;

    // ---------------------------------------------------------
    // 1. Testbench Signals (Matching Module Ports)
    // ---------------------------------------------------------
    logic         clk;
    logic [5:0]   w_index;
    logic [5:0]   r_index;
    logic         we;
    logic         re;
    logic [1:0]   way_sel;
    logic [511:0] din_data;
    logic [63:0]  byte_sel;
    
    // Output array port
    logic [511:0] dout_data[0:3];

    // ---------------------------------------------------------
    // 2. Clock Generation (100 MHz / 10ns period)
    // ---------------------------------------------------------
    localparam CLK_PERIOD = 10;
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ---------------------------------------------------------
    // 3. Unit Under Test (UUT) Instantiation
    // ---------------------------------------------------------
    data_array uut (
        .clk(clk),
        .w_index(w_index),
        .r_index(r_index),
        .we(we),
        .re(re),
        .way_sel(way_sel),
        .din_data(din_data),
        .byte_sel(byte_sel),
        .dout_data(dout_data)
    );

    // ---------------------------------------------------------
    // 4. Testbench Stimulus Tasks
    // ---------------------------------------------------------
    
    // Task to initialize all driving signals to zero/inactive states
    task automatic initialize_signals(); // Declared automatic to follow safe execution norms
        w_index  = 6'b0;
        r_index  = 6'b0;
        we       = 1'b0;
        re       = 1'b0;
        way_sel  = 2'b0;
        din_data = 512'b0;
        byte_sel = 64'b0;
    endtask

    // Task to simulate a full 512-bit cache line block write (e.g., on a Memory Refill Miss)
    task automatic write_cache_line(
        input logic [5:0]   set_index,
        input logic [1:0]   target_way,
        input logic [511:0] write_block
    );
        @(posedge clk);
        we       = 1'b1;
        w_index  = set_index;
        way_sel  = target_way;
        din_data = write_block;
        byte_sel = {64{1'b1}}; // All ones enables byte-masking across the full 64 bytes
        
        @(posedge clk); // Allow sequential setup execution
        we       = 1'b0;
        byte_sel = 64'b0;
        $display("[WRITE LINE] Set: %0d | Way: %0d | Data LSB: 0x%h", set_index, target_way, write_block[31:0]);
    endtask

    // Task to simulate a CPU partial byte masked write (e.g., on a Write Hit)
    task automatic write_cache_bytes(
        input logic [5:0]   set_index,
        input logic [1:0]   target_way,
        input logic [511:0] write_block,
        input logic [63:0]  mask
    );
        @(posedge clk);
        we       = 1'b1;
        w_index  = set_index;
        way_sel  = target_way;
        din_data = write_block;
        byte_sel = mask; // Only active bits in this vector update cache bytes
        
        @(posedge clk);
        we       = 1'b0;
        byte_sel = 64'b0;
        $display("[WRITE BYTES] Set: %0d | Way: %0d | Mask: 0x%h | Data LSB: 0x%h", set_index, target_way, mask, write_block[31:0]);
    endtask

    // Task to execute a combinational read and print output ways
    task automatic read_cache_set(input logic [5:0] set_index);
        // Reads are combinational, but we align stimulus changes with the clock edge
        @(posedge clk);
        re      = 1'b1;
        r_index = set_index;
        
        #1; // Brief combinational delay settlement 
        $display("----------------------------------------------------------------------");
        $display("[READ SET] Querying Set Index: %0d", set_index);
        $display("  -> Way 0 Data (LSB): 0x%h", dout_data[0][31:0]);
        $display("  -> Way 1 Data (LSB): 0x%h", dout_data[1][31:0]);
        $display("  -> Way 2 Data (LSB): 0x%h", dout_data[2][31:0]);
        $display("  -> Way 3 Data (LSB): 0x%h", dout_data[3][31:0]);
        $display("----------------------------------------------------------------------");
        
        re      = 1'b0;
    endtask

    // ---------------------------------------------------------
    // 5. Main Test Execution Sequence
    // ---------------------------------------------------------
    initial begin
        $display("=========================================================");
        $display("          STARTING DATA ARRAY STORAGE TESTBENCH          ");
        $display("=========================================================\n");
        
        initialize_signals();
        #(CLK_PERIOD * 2);

        // --- Test Scenario 1: Fill multiple ways in Set 5 ---
        $display("### SCENARIO 1: Writing unique complete blocks to Set 5 across different ways ###");
        write_cache_line(.set_index(6'd5), .target_way(2'b00), .write_block(512'hAAAA_AAAA_0000_0000_1111_1111));
        write_cache_line(.set_index(6'd5), .target_way(2'b10), .write_block(512'hCCCC_CCCC_2222_2222_3333_3333));
        
        // Read back Set 5 to verify data settled into correct parallel slots
        read_cache_set(.set_index(6'd5));

        // --- Test Scenario 2: Partial Byte Write Masking (CPU Write Hit) ---
        $display("\n### SCENARIO 2: Modifying lower 4 bytes inside Way 0 of Set 5 (Byte Masking) ###");
        // We write 0xFFFFFFFF only into the first 4 bytes (bytes 0, 1, 2, 3), keeping others masked out
        write_cache_bytes(
            .set_index(6'd5), 
            .target_way(2'b00), 
            .write_block(512'h0000_0000_0000_0000_FFFF_FFFF), 
            .mask(64'h0000_0000_0000_0003) // 2'b0011 -> enables lowest 2 byte lanes or modify to 64'h000000000000000F for 4 bytes
        );
        
        // Read back to check if byte lanes updated successfully without wiping adjacent parallel data entries
        read_cache_set(.set_index(6'd5));

        // --- Test Scenario 3: Verify Empty Set Boundary ---
        $display("\n### SCENARIO 3: Reading an uninitialized/empty set (Set 24) ###");
        read_cache_set(.set_index(6'd24));

        #(CLK_PERIOD * 5);
        $display("=========================================================");
        $display("             DATA ARRAY TESTING COMPLETED                ");
        $display("=========================================================");
        $finish;
    end

endmodule