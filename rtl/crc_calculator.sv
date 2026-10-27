module crc_calculator #(
    parameter integer N = 32 // Maximum CRC width; supported range 1..32
) (
    input clk,
    input rst,
    input data_in,
    input cfg_write,
    input [5:0] cfg_address,
    input [7:0] cfg_write_data,
    input init_crc,
    input enable_crc_calculation,
    output [$clog2(N+1)-1:0] crc_width_out,
    output [N-1:0] crc_result
);
    // N = CRC LENGTH

    reg [N-1:0] generator;
    reg [$clog2(N+1)-1:0] crc_width;
    reg [N-1:0] init_value;
    reg [N-1:0] xor_out;

    reg [N-1:0] data_shift_reg;
    wire [N-1:0] width_mask;
    wire config_write;
    wire [3:0] wr_generator_byte_en;
    wire [3:0] wr_init_value_byte_en;
    wire [3:0] wr_xor_out_byte_en;
    wire wr_crc_width_en;
    integer config_bit;

    crc_address_decoder decoder (
        .cfg_write(cfg_write), .cfg_address(cfg_address),
        .wr_generator_byte_en(wr_generator_byte_en),
        .wr_init_value_byte_en(wr_init_value_byte_en),
        .wr_xor_out_byte_en(wr_xor_out_byte_en),
        .wr_crc_width_en(wr_crc_width_en)
    );
    assign crc_width_out = crc_width;
    assign width_mask = {N{1'b1}} >> (N - crc_width);
    assign config_write = (|wr_generator_byte_en) | wr_crc_width_en |
                          (|wr_init_value_byte_en) | (|wr_xor_out_byte_en);
    // Final XOR changes the output only, never the running state.
    assign crc_result = (data_shift_reg ^ xor_out) & width_mask;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            generator <= {N{1'b0}};
            crc_width <= N;
            init_value <= {N{1'b0}};
            xor_out <= {N{1'b0}};
            data_shift_reg <= {N{1'b0}};
        end else begin
            // Update only the addressed byte. Store all implemented bits so
            // bytes and width can be written in any order. The leading
            // x^crc_width polynomial coefficient is implicit; omit it on writes.
            for (config_bit = 0; config_bit < N; config_bit = config_bit + 1) begin
                if (wr_generator_byte_en[config_bit / 8])
                    generator[config_bit] <= cfg_write_data[config_bit % 8];
                if (wr_init_value_byte_en[config_bit / 8])
                    init_value[config_bit] <= cfg_write_data[config_bit % 8];
                if (wr_xor_out_byte_en[config_bit / 8])
                    xor_out[config_bit] <= cfg_write_data[config_bit % 8];
            end
            // Validate the entire byte before narrowing it to the width register.
            if (wr_crc_width_en && cfg_write_data >= 1 && cfg_write_data <= N)
                crc_width <= cfg_write_data;

            // Priority: configuration write (hold state), initialize, calculate.
            // Pulse init_crc after the last configuration write, or to restart
            // another packet using the stored configuration.
            if (!config_write) begin
                if (init_crc) begin
                    data_shift_reg <= init_value & width_mask;
                end else if (enable_crc_calculation) begin
                    // Feed bits in transmission order; use the selected MSB.
                    data_shift_reg <= ((data_shift_reg << 1)
                                      ^ ((data_in ^ data_shift_reg[crc_width-1])
                                         ? generator : {N{1'b0}})) & width_mask;
                end
            end
        end
    end


endmodule

