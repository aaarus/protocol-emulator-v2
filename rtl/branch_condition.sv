module branch_condition (
    input wire branch_en,
    input wire [1:0] condition,
    input wire [1:0] status_bit,
    input wire [3:0] status,
    output reg taken
);
    always @* begin
        taken = 1'b0;
        if (branch_en) begin
            case (condition)
                2'b00: taken = 1'b1; // ALWAYS ignores status_bit.
                2'b01: taken = status[status_bit];
                2'b10: taken = ~status[status_bit];
                default: taken = 1'b0; // Reserved: no branch request.
            endcase
        end
    end
endmodule
