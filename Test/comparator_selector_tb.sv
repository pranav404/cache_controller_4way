`timescale 1ns / 1ps

module comparator_selector_tb;

    // ---------------------------------------------------------
    // 1. Testbench Signals (Matching Module Ports)
    // ---------------------------------------------------------
    logic [19:0]  in_tags[0:3];
    logic [19:0]  in_cmp_tag;
    logic [511:0] in_data[0:3];
    logic         valid_in[0:3];
    logic         dirty_in[0:3];
    
    logic         cache_hit;
    logic [1:0]   matched_way;
    logic [511:0] hit_data;

    // ---------------------------------------------------------
    // 2. Unit Under Test (UUT) Instantiation
    // ---------------------------------------------------------
    comparator_selector uut (
        .in_tags(in_tags),
        .in_cmp_tag(in_cmp_tag),
        .in_data(in_data),
        .valid_in(valid_in),
        .dirty_in(dirty_in),
        .cache_hit(cache_hit),
        .matched_way(matched_way),
        .hit_data(hit_data)
    );

    // ---------------------------------------------------------
    // 3. Testbench Stimulus Task
    // ---------------------------------------------------------
    // This task sets up a scenario and evaluates the combinational results
    task automatic drive_and_check(
        input string        test_name,
        input logic [19:0]  target_tag,
        input logic [19:0]  t0, t1, t2, t3,
        input logic         v0, v1, v2, v3,
        input logic [511:0] d0, d1, d2, d3
    );
        // Apply inputs to the UUT ports
        in_cmp_tag  = target_tag;
        in_tags[0]  = t0;   in_tags[1]  = t1;   in_tags[2]  = t2;   in_tags[3]  = t3;
        valid_in[0] = v0;   valid_in[1] = v1;   valid_in[2] = v2;   valid_in[3] = v3;
        in_data[0]  = d0;   in_data[1]  = d1;   in_data[2]  = d2;   in_data[3]  = d3;
        
        // Clear dirty bits for simplicity in this evaluation
        dirty_in[0] = 0;    dirty_in[1] = 0;    dirty_in[2] = 0;    dirty_in[3] = 0;

        // Combinational evaluation delay
        #1;

        // Display results cleanly
        $display("----------------------------------------------------------------------");
        $display("RUNNING TEST: %s", test_name);
        $display("Searching For Tag: 0x%5h", in_cmp_tag);
        $display(" [Way 0] Tag: 0x%5h | Valid: %b | Data: 0x%h", in_tags[0], valid_in[0], in_data[0][31:0]); // showing lowest 32-bits
        $display(" [Way 1] Tag: 0x%5h | Valid: %b | Data: 0x%h", in_tags[1], valid_in[1], in_data[1][31:0]);
        $display(" [Way 2] Tag: 0x%5h | Valid: %b | Data: 0x%h", in_tags[2], valid_in[2], in_data[2][31:0]);
        $display(" [Way 3] Tag: 0x%5h | Valid: %b | Data: 0x%h", in_tags[3], valid_in[3], in_data[3][31:0]);
        $display("OUTPUTS:");
        $display("  -> Cache Hit  = %b", cache_hit);
        if (cache_hit) begin
            $display("  -> Matched Way = %d (Binary: %b)", matched_way, matched_way);
            $display("  -> Hit Data    = 0x%h", hit_data[31:0]);
        end else begin
            $display("  -> No match found. Hit Data = 0x%h", hit_data[31:0]);
        end
        $display("----------------------------------------------------------------------\n");
    endtask

    // ---------------------------------------------------------
    // 4. Main Test Execution Sequence
    // ---------------------------------------------------------
    initial begin
        $display("=========================================================");
        $display("        STARTING COMPARATOR SELECTOR SIMULATION          ");
        $display("=========================================================\n");

        // --- Test 1: Clean Cache Miss (Tag doesn't exist anywhere) ---
        drive_and_check(
            .test_name  ("CACHE MISS - TAG NOT FOUND"),
            .target_tag (20'hABCDE),
            .t0(20'h11111), .t1(20'h22222), .t2(20'h33333), .t3(20'h44444),
            .v0(1'b1),      .v1(1'b1),      .v2(1'b1),      .v3(1'b1),
            .d0(512'hD0),   .d1(512'hD1),   .d2(512'hD2),   .d3(512'hD3)
        );

        // --- Test 2: Cache Hit on Way 0 ---
        drive_and_check(
            .test_name  ("CACHE HIT - MATCH ON WAY 0"),
            .target_tag (20'hA0A0A),
            .t0(20'hA0A0A), .t1(20'h22222), .t2(20'h33333), .t3(20'h44444),
            .v0(1'b1),      .v1(1'b1),      .v2(1'b1),      .v3(1'b1),
            .d0(512'hAAAA_0000), .d1(512'hD1), .d2(512'hD2), .d3(512'hD3)
        );

        // --- Test 3: Cache Hit on Way 2 ---
        drive_and_check(
            .test_name  ("CACHE HIT - MATCH ON WAY 2"),
            .target_tag (20'hC0C0C),
            .t0(20'h11111), .t1(20'h22222), .t2(20'hC0C0C), .t3(20'h44444),
            .v0(1'b1),      .v1(1'b1),      .v2(1'b1),      .v3(1'b1),
            .d0(512'hD0),   .d1(512'hD1),   .d2(512'hCCCC_2222), .d3(512'hD3)
        );

        // --- Test 4: Invalid Tag Match (Tag matches but valid bit is low -> Should Miss) ---
        drive_and_check(
            .test_name  ("CACHE MISS - TAG MATCHED BUT INVALID"),
            .target_tag (20'hFFFFF),
            .t0(20'h11111), .t1(20'hFFFFF), .t2(20'h33333), .t3(20'h44444),
            .v0(1'b1),      .v1(1'b0),      .v2(1'b1),      .v3(1'b1), // Way 1 is Invalid
            .d0(512'hD0),   .d1(512'hFA15_E111), .d2(512'hD2), .d3(512'hD3)
        );

        // --- Test 5: Cache Hit on Way 3 ---
        drive_and_check(
            .test_name  ("CACHE HIT - MATCH ON WAY 3"),
            .target_tag (20'hF0F0F),
            .t0(20'h11111), .t1(20'h22222), .t2(20'h33333), .t3(20'hF0F0F),
            .v0(1'b1),      .v1(1'b1),      .v2(1'b1),      .v3(1'b1),
            .d0(512'hD0),   .d1(512'hD1),   .d2(512'hD2),   .d3(512'hFFFF_3333)
        );

        $display("=========================================================");
        $display("            SIMULATION TESTING COMPLETED                 ");
        $display("=========================================================");
        $finish;
    end

endmodule