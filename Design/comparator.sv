module comparator_selector(
    input logic [19:0] in_tags[0:3],  // Array containing 4 20-bit tags, one tag for each cache way
    input logic [19:0] in_cmp_tag,   //tag from CPU's requested address
    input logic [511:0] in_data[0:3], // data in cache line in current set
    input logic valid_in [0:3], //Valid bits that say if a cache line is valid or not
    //input logic dirty_in [0:3], // Indicate if a cache line has been modified or not
    output logic cache_hit, // 1 is requested block is in cache, 0 is requested block not in cache
    output logic [1:0] matched_way, // indictaes which of the 4 ways are a match for the requested address
    output logic [511:0] hit_data // outputs the 512 bit cache line cooresponsing to matching way
);



logic way_hit1; // way0 was a hit
logic way_hit2; // way1 was a hit
logic way_hit3; // way 2 was a hit
logic way_hit4; // way 3 was a hit


    assign way_hit1 = ((in_tags[0] == in_cmp_tag) && valid_in[0]) ? 1'b1 : 1'b0; //returns 1 if cpu's requested address tag and cache line's tag is a match
    
    assign way_hit2 = ((in_tags[1] == in_cmp_tag) && valid_in[1]) ? 1'b1 : 1'b0;//same logic
    assign way_hit3 = ((in_tags[2] == in_cmp_tag) && valid_in[2]) ? 1'b1 : 1'b0;//same logic
    assign way_hit4 = ((in_tags[3] == in_cmp_tag) && valid_in[3]) ? 1'b1 : 1'b0;//same logic

assign cache_hit = way_hit1 | way_hit2 | way_hit3 | way_hit4 ;// cache returns a hit when any of 1-4 ways are a match

always_comb begin
    if(way_hit1) begin
        hit_data = in_data[0]; // if way1 is a hit hit_data gets way 0 data
        matched_way = 2'b00;// if way 1 is hit matched way is 00
    end
    else if(way_hit2) begin
        hit_data = in_data[1]; // if way2 is a hit hit_data gets way 1 data
        matched_way = 2'b01; // if way2 is a hit matched way is 01
    end
    else if(way_hit3) begin
        hit_data = in_data[2];// if way3 is a hit hit_data gets way 2 data
        matched_way = 2'b10;//if way3 is a hit matched way is 10
    end
    else if(way_hit4) begin
        hit_data = in_data[3];// if way3 is a hit hit_data gets way 3 data
        matched_way = 2'b11;//if way4 is a hit matched way is 11
    end
    else begin
        hit_data = 'b0;// it no way has a hit data is clear
        matched_way = 2'b00;// if no match matched way is never high

    end
end



endmodule
