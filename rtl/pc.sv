module pc_reg(
    input clk, rst,
    output reg [15:0] pc_addr,
    input [15:0] pc_data_in
    );

    always @(posedge clk, negedge rst)
        if (!rst) begin 
            pc_addr <= 0;
        end
        else begin 
            pc_addr <= pc_data_in;
        end
endmodule 

module pc(input clk, rst, pc_stall,
    input pc_mux_sel,
    input branch_taken,
    input signed [7:0] branch_offset,
    input [3:0] loop_length,  //ip from loop_handler
    output [15:0] pc_addr_out,
    input evnt,
    input redirect_addr
    );

    wire [15:0] pc_data_in;
    always_comb begin
        if (evnt != 0) begin
            pc_data_in = redirect_addr;
        end
        //giving evnt higher probability than stall because pc is stalled while bw ticks.
        else if (pc_stall) begin
            pc_data_in = pc_addr_out;
        end
        else if (branch_taken) begin
            pc_data_in = pc_addr_out + 16'd1
                    + {{8{branch_offset[7]}}, branch_offset};
        end
        else if (pc_mux_sel == 1'b0) begin
            pc_data_in = pc_addr_out + 16'd1;
        end
        else begin
            pc_data_in = pc_addr_out
                    - {{12{1'b0}}, loop_length}
                    + 16'd1;
        end
    end
                    
    pc_reg pc_reg(
        .clk(clk),
        .rst(rst),
        .pc_addr(pc_addr_out),
        .pc_data_in(pc_data_in)
    );


    
endmodule
