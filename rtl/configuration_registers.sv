module configuration_registers(input clk, rst, wr_tx_en, wr_rx_en,
    input tx_select,
    input cfg_write,
    input [5:0] cfg_address,
    input [7:0] cfg_write_data,
    output reg crc_source_select,
    input [1:0] rx, tx, 
    output reg [1:0] tx_reg, tx1_reg, rx_reg,
    output reg [1:0] crc_tx_gpio);


    always @(posedge clk, negedge rst) begin 
        if (!rst) begin 
            crc_source_select <= 0;
            tx_reg <= 0;
            tx1_reg <= 0;
            rx_reg <= 0;
            // Four GPIOs require two selection bits. The software write/decode
            // path is deferred; until added this register retains reset GPIO0.
            crc_tx_gpio <= 0;
        end
        else begin 
            if (cfg_write && cfg_address == 6'h0D) crc_source_select <= cfg_write_data[0];
            if (cfg_write && cfg_address == smth) tx1_reg <= tx;
            if (cfg_write && cfg_address == smth) tx_reg <= tx;
            if (cfg_write && cfg_address == smth) rx_reg <= rx;
        end
    end

    

endmodule
