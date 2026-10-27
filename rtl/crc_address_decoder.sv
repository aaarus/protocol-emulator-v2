// Local 6-bit byte address map; writes take effect on the CRC clock edge.
// 0x0-0x3: polynomial, 0x4-0x7: initial value, 0x8-0xB: final XOR.
// In each range the lowest address selects bits [7:0].
// 0xC: width (1..32); 0x0D-0x3F: not selected by CRC.
module crc_address_decoder (
    input cfg_write,
    input [5:0] cfg_address,
    output reg [3:0] wr_generator_byte_en,
    output reg [3:0] wr_init_value_byte_en,
    output reg [3:0] wr_xor_out_byte_en,
    output reg wr_crc_width_en
);
    always @* begin
        wr_generator_byte_en = 4'b0000;
        wr_init_value_byte_en = 4'b0000;
        wr_xor_out_byte_en = 4'b0000;
        wr_crc_width_en = 1'b0;
        if (cfg_write) begin
            case (cfg_address)
                6'h00, 6'h01, 6'h02, 6'h03:
                    wr_generator_byte_en = 4'b0001 << cfg_address[1:0];
                6'h04, 6'h05, 6'h06, 6'h07:
                    wr_init_value_byte_en = 4'b0001 << cfg_address[1:0];
                6'h08, 6'h09, 6'h0A, 6'h0B:
                    wr_xor_out_byte_en = 4'b0001 << cfg_address[1:0];
                6'h0C: wr_crc_width_en = 1'b1;
                default: begin end
            endcase
        end
    end
endmodule
