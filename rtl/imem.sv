module imem #(
    parameter int DEPTH = 256
) (
    input  logic [$clog2(DEPTH)-1:0] addr,
    output logic [19:0] data_out
);

    logic [19:0] mem [0:DEPTH-1];

    integer i;

    initial begin
        // Initialize entire memory to zero
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 20'h00000;

        // Load program
        $readmemb("i2c.bin", mem);
    end

    assign data_out = mem[addr];

endmodule