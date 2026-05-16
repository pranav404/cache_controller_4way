module cache_controller(
    //clk and reset signals
    input logic clk,
    input logic rst_n,
    //cpu I/O signals
    input logic re,
    input logic we,
    input logic [31:0] cpu_addr_write,
    input logic [31:0] cpu_addr_read,
    input logic [511:0] cpu_data_write,
    input logic cpu_stall_cache,
    output logic [511:0] cpu_data_read,
    output logic cache_stall_cpu,
    //memory I/O signals
    output logic [31:0] mem_addr_read,
    output logic [31:0] mem_addr_write,
    output logic mem_re,
    output logic mem_we,
    input logic mem_ack;
    input logic [511:0] mem_data_read,
    output logic [511:0] mem_data_write
    output logic cache_stall_mem,
    input logic mem_stall_cache,
);


//signals for tag array
logic [5:0] tag_w_index, tag_r_index;
logic tag_we, tag_re;
logic [1:0] tag_way_sel;
logic [19:0] tag_din;
logic tag_valid;
logic tag_dirty;
logic [19:0] tag_out[0:3];
logic tag_valid_out[0:3];
logic tag_dirty_out[0:3];

//module instantiation tag_array
tag_array u_tag_array (
    .clk        (clk),         
    .w_index    (tag_w_index),
    .r_index    (tag_r_index),
    .we         (tag_we),
    .re         (tag_re),
    .way_sel    (tag_way_sel),
    .din_tag    (tag_din),
    .din_valid  (tag_valid),
    .din_dirty  (tag_dirty),
    .dout_tag   (tag_out),
    .dout_valid (tag_valid_out),
    .dout_dirty (tag_dirty_out)  
);


//signals for data_array
logic [5:0] data_w_index, data_r_index;
logic data_we, data_re;
logic [1:0] data_way_sel;
logic [511:0] din_data;
logic [63:0] byte_sel;

logic [511:0] dout_data[0:3];

//data_array_module_instantiation
// Module instantiation for the 4-way data array
data_array u_data_array (
    .clk       (clk),          
    .w_index   (data_w_index),
    .r_index   (data_r_index),
    .we        (data_we),
    .re        (data_re),
    .way_sel   (data_way_sel),
    .din_data  (din_data),
    .byte_sel  (byte_sel),
    .dout_data (dout_data)
);


//signals for comparator
logic [19:0] comp_in_tag[0:3];
logic [19:0] comp_cmp_tag;
logic [511:0] comp_data_in[0:3];
logic comp_valid_in[0:3];
logic comp_dirty_in[0:3];
logic cache_hit;
logic [511:0] comp_hit_data;


// Module instantiation for the comparator selector
comparator_selector u_comparator_selector (
    .in_tags    (comp_in_tag),
    .in_cmp_tag (comp_cmp_tag),
    .in_data    (comp_data_in),
    .valid_in   (comp_valid_in),
    .dirty_in   (comp_dirty_in),
    .cache_hit  (cache_hit),
    .hit_data   (comp_hit_data)
);


//signals for plru_way_selector
logic [5:0] plru_v_index;
logic [5:0] plru_u_index;
logic [1:0] plru_u_way;
logic [1:0] plru_v_way;
logic plru_we;


// Module instantiation for the PLRU way selector
plru_way_selector u_plru_way_selector (
    .clk     (clk),
    .plru_we (plru_we),
    .v_index (plru_v_index),
    .u_index (plru_u_index),
    .u_way   (plru_u_way),
    .v_way   (plru_v_way)
);



//signals for read FSM
logic [2:0] read_state_FSM;
localparam IDLE_COMPARE - 3'b000;
localparam MISS1 = 3'b001;
localparam MISS2 = 3'b010;
localparam WRITE_BACK = 3'b011;
localparam MEM_ACC = 3'b100;
localparam ERROR = 3'b111;

logic internal_stall;
logic external_stall;

assign external_stall = cpu_stall_cache | mem_stall_cache;




logic [31:0] miss_address;
logic [1:0] victim_way;
logic miss_index_valids [0:3];
logic miss_index_dirty [0:3];
logic [19:0] miss_index_tags[0:3];
logic [511:0] miss_index_data [0:3];



always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        read_state_FSM <= IDLE_COMPARE;
    end
    else begin
        if(external_stall) begin
            read_state_FSM <= read_state_FSM;
        end
        else begin
            case(read_state_FSM)
            IDLE_COMPARE: begin
                if(!cache_hit) begin
                    read_state_FSM <= MISS1;
                    //setting signals for the plru selector
                    miss_address <= cpu_addr_read;
                    miss_index_dirty <= tag_dirty_out;
                    miss_index_valids <= tag_valid_out;
                    miss_index_tags <= tag_out;
                    miss_index_data <= dout_data;
                    
                end
                else begin
                    read_state_FSM <= IDLE_COMPARE;
                end
            end
            MISS1: begin
                victim_way <= v_way;
                read_state_FSM <= MISS2
            end
            MISS2: begin
                if(miss_index_dirty[victim_way] && miss_index_valids[victim_way]) begin
                    //victim block dirty, next state => WRITEBACK
                    read_state_FSM <= WRITE_BACK;
                end
                else begin
                    //read_state_FSM can move directly to mem access
                    read_state_FSM <= MEM_ACC;
                end
            end
            WRITE_BACK: begin
                if(!mem_we) begin
                    mem_we<= 1'b1;
                    mem_addr_write <= {miss_index_tags[victim_way],miss_address[11:6],6'b0};
                    mem_data_write <= miss_index_data[victim_way];
                    read_state_FSM <= WRITE_BACK;
                end
                else if(mem_ack) begin
                    read_state_FSM <= MEM_ACC;
                    mem_we <= 1'b0;
                end
                else begin
                    read_state_FSM <= WRITE_BACK;
                end
            end
            MEM_ACC: begin
                if(!mem_re && !mem_ack && !(data_we || tag_we || plru_we)) begin
                    mem_re <= 1'b1;
                    mem_addr_read <= miss_address;
                    read_state_FSM <= MEM_ACC;
                end
                else if(mem_ack) begin
                    mem_re <= 1'b0;
                    //updating data array
                    data_we <= 1'b1;
                    data_way_sel <= victim_way;
                    byte_sel <= 'b1;
                    din_data <= mem_data_read;
                    data_w_index <= miss_address[11:6];
                    //updating tag array
                    tag_we <= 1'b1;
                    tag_way_sel <= victim_way;
                    tag_din <= miss_address[31:12];
                    tag_valid <= 1'b1;
                    tag_dirty <= 1'b1;
                    tag_w_index <= miss_address[11:6];
                    //updating plru table
                    plru_we <= 1'b1;
                    plru_u_index <= miss_address[11:6];
                    plru_u_way <= victim_way;
                    read_state_FSM <= MEM_ACC;
                end
                else if(data_we || tag_we || plru_we) begin
                    data_we <= 1'b0;
                    tag_we <= 1'b0;
                    plru_we <= 1'b0;
                    read_state_FSM <= IDLE_COMPARE;
                end
            end
            default: begin
                read_state_FSM <= IDLE_COMPARE;
            end
            endcase
        end
    end
end


                    

                    
                











endmodule