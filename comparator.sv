module comparator_selector(
    input logic [19:0] in_tags[0:3],
    input logic [19:0] in_cmp_tag,
    input logic [511:0] in_data[0:3],
    input logic valid_in [0:3],
    input logic dirty_in [0:3],
    output logic cache_hit,
    output logic [511:0] hit_data
);



logic way_hit1;
logic way_hit2;
logic way_hit3;
logic way_hit4;


assign way_hit1 = ((in_tags[0] == in_cmp_tag) && valid_in[0]) ? 1'b1 : 1'b0;
assign way_hit2 = ((in_tags[1] == in_cmp_tag) && valid_in[1]) ? 1'b1 : 1'b0;
assign way_hit3 = ((in_tags[2] == in_cmp_tag) && valid_in[2]) ? 1'b1 : 1'b0;
assign way_hit4 = ((in_tags[3] == in_cmp_tag) && valid_in[3]) ? 1'b1 : 1'b0;

assign cache_hit = way_hit1 | way_hit2 | way_hit3 | way_hit4 ;

always_comb begin
    if(way_hit1) begin
        hit_data <= in_data[0];
    end
    else if(way_hit2) begin
        hit_data <= in_data[1];
    end
    else if(way_hit3) begin
        hit_data <= in_data[2];
    end
    else if(way_hit4) begin
        hit_data <= in_data[3];
    end
    else begin
        hit_data <= 'b0;
    end
end



endmodule