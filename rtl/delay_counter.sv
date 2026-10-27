module delay_counter #(
    parameter N = 8 // Default bit-width
)(
    input wire clk,              // Clock signal
    input wire rst_n,            // Active-low asynchronous reset
    input wire load,             // Synchronous parallel load enable
    input wire dec_en,           // Decrement enable
    input wire [N-1:0] data_in,  // Parallel data input
    output reg [N-1:0] count,
    output zero
);
// wait has not been implemented yet, so the counter will be used for delay only.
    assign  zero = (count == 1);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {N{1'b0}};  // Reset count to zero
        end else if (load) begin
            count <= data_in - 1;    // Load parallel data
        end else if (dec_en) begin
            count <= count - 1'b1; // Decrement counter
        end
    end

endmodule