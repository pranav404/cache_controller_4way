module plru_way_selector(
    input logic clk,
    input logic plru_we,
    input logic [5:0] v_index,
    input logic [5:0] u_index,
    input logic [1:0] u_way,
    output logic [1:0] v_way

);

logic [2:0] plru_tree [0:63];


//combinational logic to find the victim way
always_comb begin
    if(plru_tree[v_index][0]) begin
        if(plru_tree[v_index][2])begin
            v_way = 2'b11;
        end
        else begin
            v_way = 2'b10;
        end
    end
    else begin
        if(plru_tree[v_index][1]) begin
            v_way = 2'b01;
        end
        else begin
            v_way = 2'b00;
        end
    end
end



always@(posedge clk) begin

    if(plru_we) begin
    case(u_way)
        2'b00: begin
            plru_tree[u_index] <= {1'b1,1'b1,plru_tree[u_index][0]};
        end
        2'b01: begin
            plru_tree[u_index] <= {1'b1,1'b0,plru_tree[u_index][0]};
        end
        2'b10: begin
            plru_tree[u_index] <= {1'b0,plru_tree[u_index][1],1'b1};
        end
        2'b11: begin
            plru_tree[u_index] <= {1'b0,plru_tree[u_index][1],1'b0};
        end
        default: begin
            plru_tree[u_index] <= {1'b1,1'b1,plru_tree[u_index][0]};
        end
    endcase
    end
end



endmodule