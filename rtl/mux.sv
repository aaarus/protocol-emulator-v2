//mux for gpio to rx

module parameterized_1bit_mux #(
    parameter CHANNELS = 4   // Number of input channels (e.g., 4-to-1, 8-to-1)
)(
    input  wire [CHANNELS - 1 : 0] in_bus, // Array of 1-bit inputs
    input  wire [$clog2(CHANNELS) - 1 : 0] sel,    // Binary select line
    output wire                            out
);

    // Directly index the specific bit from the bus array using the select signal
    assign out = in_bus[sel];

endmodule