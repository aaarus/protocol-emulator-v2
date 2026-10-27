// for tx register. piso
module tx_reg #(
    parameter DATA_WIDTH = 8  // Parameterizable width, defaults to 8-bit
)(
    input  wire                  clk,         // System clock
    input  wire                  rst_n,       // Active-low asynchronous reset
    input  wire                  load,        // 1: Load parallel data
    input  wire                  shift_en,    // 1: Shift data out
    input  wire [DATA_WIDTH-1:0] parallel_in, // Parallel data input bus
    output wire                  serial_out   // Serial data output
);

    // Internal register holding the shifting state
    reg [DATA_WIDTH-1:0] shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= {DATA_WIDTH{1'b0}};
        end
        else if (load) begin
            // Synchronous parallel load
            shift_reg <= parallel_in;
        end
        else if (shift_en) begin
            // Right shift operation for LSB-first serial streaming
            shift_reg <= {1'b0, shift_reg[DATA_WIDTH-1:1]};
        end
        else begin
            // Hold current value
            shift_reg <= shift_reg;
        end
    end

    // LSB is the current serial output
    assign serial_out = shift_reg[0];

endmodule

// Automatically snapshot and consume the first CRC bit on the first shift.
// After crc_width shifts the next shift starts another snapshot. Input changes
// cannot affect an in-progress snapshot. Width must be in 1..DATA_WIDTH.
module crc_tx_reg #(
    parameter integer DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,
    input wire shift_en,
    input wire clear,
    input wire [DATA_WIDTH-1:0] parallel_in,
    input wire [$clog2(DATA_WIDTH+1)-1:0] crc_width,
    output wire serial_out,
    output wire bit_valid
);
    reg [DATA_WIDTH-1:0] shift_reg;
    reg [$clog2(DATA_WIDTH+1)-1:0] bits_remaining;
    wire width_valid = (crc_width >= 1 && crc_width <= DATA_WIDTH);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= {DATA_WIDTH{1'b0}};
            bits_remaining <= 0;
        end else if (clear) begin
            shift_reg <= 0;
            bits_remaining <= 0;
        end else if (shift_en) begin
            if (bits_remaining != 0) begin
                shift_reg <= shift_reg << 1;
                bits_remaining <= bits_remaining - 1'b1;
            end else if (width_valid) begin
                // Align active bits, then consume the bit already sent to GPIO.
                shift_reg <= (parallel_in << (DATA_WIDTH - crc_width)) << 1;
                bits_remaining <= crc_width - 1'b1;
            end
        end
    end

    // First-bit bypass lets the instruction both snapshot and transmit, without
    // an extra LOAD_TX instruction or a cycle of latency.
    assign serial_out = (bits_remaining != 0) ? shift_reg[DATA_WIDTH-1] :
                        (width_valid ? parallel_in[crc_width-1] : 1'b0);
    assign bit_valid = (bits_remaining != 0) || width_valid;
endmodule




// for rx. sipo
module rx_reg #(
    parameter N = 8 // Configurable data width (default 8 bits)
)(
    input  wire         clk,       // Clock signal
    input  wire         rst_n,     // Active-low asynchronous reset
    input  wire         enable,    // Shift enable
    input  wire         dir,       // Direction: 0 = Shift Right, 1 = Shift Left
    input  wire         serial_in, // Serial data input
    output reg  [N-1:0] parallel_out // Parallel data output
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parallel_out <= {N{1'b0}}; // Clear register on reset
        end else if (enable) begin
            if (dir == 1'b1) begin
                // Shift Left: insert serial_in at LSB (index 0)
                parallel_out <= {parallel_out[N-2:0], serial_in};
            end else begin
                // Shift Right: insert serial_in at MSB (index N-1)
                parallel_out <= {serial_in, parallel_out[N-1:1]};
            end
        end
    end

endmodule
