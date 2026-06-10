`timescale 1ns / 1ps

module cache_controller_tb;

    // ---------------------------------------------------------
    // 1. Clock and Reset Signals
    // ---------------------------------------------------------
    logic clk;
    logic rst_n;

    // ---------------------------------------------------------
    // 2. CPU I/O Signals
    // ---------------------------------------------------------
    logic         re;
    logic         we;
    logic [31:0]  cpu_addr_write;
    logic [63:0]  write_byte_sel;
    logic [31:0]  cpu_addr_read;
    logic [511:0] cpu_data_write;
    logic         cpu_stall_cache;
    logic [511:0] cpu_data_read;
    logic         cache_stall_cpu;

    // ---------------------------------------------------------
    // 3. Memory I/O Signals
    // ---------------------------------------------------------
    logic [31:0]  mem_addr_read;
    logic [31:0]  mem_addr_write;
    logic         mem_re;
    logic         mem_we;
    logic         mem_ack;
    logic [511:0] mem_data_read;
    logic [511:0] mem_data_write;
    logic         cache_stall_mem;
    logic         mem_stall_cache;

    // ---------------------------------------------------------
    // 4. Clock Generation (100 MHz / 10ns period)
    // ---------------------------------------------------------
    localparam CLK_PERIOD = 10;
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ---------------------------------------------------------
    // 5. Unit Under Test (UUT) Instantiation
    // ---------------------------------------------------------
    cache_controller uut (
        .clk(clk),
        .rst_n(rst_n),
        
        // CPU Interfaces
        .re(re),
        .we(we),
        .cpu_addr_write(cpu_addr_write),
        .write_byte_sel(write_byte_sel),
        .cpu_addr_read(cpu_addr_read),
        .cpu_data_write(cpu_data_write),
        .cpu_stall_cache(cpu_stall_cache),
        .cpu_data_read(cpu_data_read),
        .cache_stall_cpu(cache_stall_cpu),
        
        // Memory Interfaces
        .mem_addr_read(mem_addr_read),
        .mem_addr_write(mem_addr_write),
        .mem_re(mem_re),
        .mem_we(mem_we),
        .mem_ack(mem_ack),
        .mem_data_read(mem_data_read),
        .mem_data_write(mem_data_write),
        .cache_stall_mem(cache_stall_mem),
        .mem_stall_cache(mem_stall_cache)
    );

    // ---------------------------------------------------------
    // 6. Memory Slave Behavioral Model (Simulate Main Memory)
    // ---------------------------------------------------------
    // Automatically loops back a simple acknowledgment and dummy read data
    // to keep the FSM from getting stuck during Miss / Writeback states.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ack       <= 1'b0;
            mem_data_read <= 512'b0;
        end else begin
            // Simulating a 2-cycle fixed latency response from main memory
            if ((mem_re || mem_we) && !mem_ack) begin
                repeat (2) @(posedge clk);
                mem_ack <= 1'b1;
                if (mem_re) begin
                    // Provide predictable dummy data based on the requested address
                    //$display(mem_addr_read);
                    mem_data_read <= {16{mem_addr_read}}; 
                end
            end else begin
                mem_ack <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------
    // 7. Testbench Stimulus Tasks
    // ---------------------------------------------------------
    
    // Task to initialize all driving signals to zero/inactive states
    task initialize_signals();
        re              = 0;
        we              = 0;
        cpu_addr_write  = 0;
        write_byte_sel  = 0;
        cpu_addr_read   = 0;
        cpu_data_write  = 0;
        cpu_stall_cache = 0;
        mem_stall_cache = 0;
    endtask
    initial begin
        // Name of the output waveform file
        $dumpfile("cache_controller_sim.vcd");
        
        // 0 means dump ALL signals in the testbench and every sub-module below it.
        // cache_controller_tb is the top-level module name.
        $dumpvars(0, cache_controller_tb);
    end
    // Task to perform a CPU Read transaction
    task cpu_read(input [31:0] addr);
        @(posedge clk);
        re = 1'b1;
        cpu_addr_read = addr;
        
        // If it's a miss, wait for the cache to finish refilling from memory
        do begin
            @(posedge clk);
        end while (cache_stall_cpu === 1'b1);
        $display("[READ] Address: 0x%0h | Data Received: %0h", addr, cpu_data_read);
        re = 1'b0;
        
        // @(negedge clk);
        // re = 1'b1;
        // cpu_addr_read = addr;
        // while (cache_stall_cpu == 1'b1) begin
        //     @(posedge clk);
        // end
        // $display("[READ] Address: 0x%0h | Data Received: %0h", addr, cpu_data_read);
        // @(negedge clk);
        // re = 1'b0;

    endtask

    // Task to perform a CPU Write transaction
    task cpu_write(input [31:0] addr, input [511:0] data, input [63:0] byte_sel);
        @(posedge clk);
        we = 1'b1;
        cpu_addr_write = addr;
        cpu_data_write = data;
        write_byte_sel = byte_sel;
        
        do begin
            @(posedge clk);
        end while (cache_stall_cpu === 1'b1);
        
        we = 1'b0;
        $display("[WRITE] Address: 0x%0h | Data Written: %0h", addr, data);
    endtask

    // ---------------------------------------------------------
    // 8. Main Test Execution Sequence
    // ---------------------------------------------------------
    initial begin
        // Step 1: Initialize signals and apply Reset
        initialize_signals();
        rst_n = 1'b0;
        #(CLK_PERIOD * 3);
        rst_n = 1'b1;
        #(CLK_PERIOD * 2);
        
        $display("===== Starting Cache Controller Testbench =====");

        // Test Scenario 1: Read Miss (Triggers IDLE -> MISS1 -> MISS2 -> MEM_ACC -> WRITE_CACHE)
        // Address uses: Index = 6'b000001 (Bits [11:6]), Tag = 20'hA0A0A (Bits [31:12])
        cpu_read(32'hA0A0A040); 
        
        // Test Scenario 2: Read Hit (Should stay in IDLE_COMPARE, cache_stall_cpu should remain low)
        cpu_read(32'hA0A0A040);

        // Test Scenario 3: Write Hit (Triggers TAG_MATCH -> WRITE_CACHE)
        cpu_write(32'hA0A0A040, 512'hDEADBEEF_CAFEF00D, 64'hFF);
        
        // Test Scenario 4: Read Hit after Write to verify dirty data is preserved
        cpu_read(32'hA0A0A040);

        

        // Test Scenario 5: Conflict Miss forcing Eviction / Writeback
        // Accessing the same index (6'b000001) but with a different Tag to conflict (if way array fills up or matches replacement policy)
        cpu_read(32'hB0B0B040);


        //Test scenario 6: Triggering a write miss
        cpu_write(32'hA1A1A1A1,512'hAAAABBBB_CCCCDDDD,64'hFF);

        cpu_read(32'hA1A1A1A1);

        // Wrap up simulation
        #(CLK_PERIOD * 10);
        $display("===== Testbench Execution Completed =====");
        $finish;
    end

endmodule