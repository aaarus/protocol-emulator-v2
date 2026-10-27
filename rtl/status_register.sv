module status_register (
    input wire clk, rst,
    input wire sample_en,
    input wire sampled_gpio,
    input wire tx_shift_en,
    input wire tx_bit,
    input wire tx1_shift_en, tx1_bit,
    output reg [3:0] status
);
    localparam SAMPLED_GPIO = 0;
    localparam LAST_TX0 = 1;
    localparam LAST_TX1 = 2;
    // Bit 3 (TIMEOUT) remains zero until supported.
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            status <= 4'b0000;
        end else begin
            if (sample_en) status[SAMPLED_GPIO] <= sampled_gpio;
            // Capture the pre-shift logical bit, independent of pad OE/mode.
            if (tx_shift_en) status[LAST_TX0] <= tx_bit;
            if (tx1_shift_en) status[LAST_TX1] <= tx1_bit;
        end
    end
endmodule
