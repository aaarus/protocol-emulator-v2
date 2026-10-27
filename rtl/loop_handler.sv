// to run the next m instructions n times


/* 
module loop_handler(
    input clk, rst, init_en,
    input [3:0] loop_length_in,
    input [7:0] loop_count_in,
    output reg [1:0] status,
    output reg [3:0] loop_length_latched
    );

    reg [3:0] loop_pos;
    reg [7:0] loop_counter;

    localparam LOOP = 2'b00; 
    localparam INC = 2'b01;
    localparam EXIT = 2'b10;


    always @(posedge clk) begin
        if (init_en) begin 
            loop_counter <= loop_count_in; //using instr, init as N-1
            loop_pos <= 1;
            loop_length_latched <= loop_length_in; //using instr
            status <= INC;
        end

        else if (loop_pos == loop_length_latched && loop_counter == 0) begin 
            status <= EXIT;
        end

        else if (loop_pos == loop_length_latched && loop_counter != 0) begin //2nd condition is redundant
            loop_pos <= 1;
            loop_counter <= loop_counter - 1;
            status <= LOOP;
        end
        else if (loop_pos != loop_length_latched) begin 
            loop_pos <= loop_pos + 1;
            status <= INC;
        end
    end
endmodule

*/

// Executes the next loop_length_in instructions
// loop_count_in = N-1
//
// status:
//   INC  -> execute/increment to the next instruction
//   LOOP -> jump back to the beginning of the loop
//   EXIT -> loop is finished

module loop_handler (
    input  logic       clk,
    input  logic       rst,
    input  logic       init_en,
    input  logic       en, //(instr_advance)
    input  logic       cancel,

    input  logic [3:0] loop_length_in,
    input  logic [7:0] loop_count_in,

    output logic [3:0] loop_length_latched,
    output logic loop_back
);

    logic [3:0] loop_pos;
    logic [7:0] loop_counter;

    always_comb begin
        loop_back = 1'b0;

        if ((loop_pos == loop_length_latched) &&
            (loop_counter != 0))
            loop_back = 1'b1;
    end

    always_ff @(posedge clk, negedge rst) begin
        if (!rst) begin
            loop_pos             <= 4'd0;
            loop_counter         <= 8'd0;
            loop_length_latched  <= 4'd0;
        end

        else if (cancel) begin
            loop_pos            <= 4'd0;
            loop_counter        <= 8'd0;
            loop_length_latched <= 4'd0;
        end

        else if (init_en) begin
            loop_counter        <= loop_count_in - 1;
            loop_pos            <= 4'd1;
            loop_length_latched <= loop_length_in;
        end

        else if (en) begin

            if (loop_pos == loop_length_latched) begin
                if (loop_counter != 0) begin
                    loop_pos     <= 4'd1;
                    loop_counter <= loop_counter - 8'd1;
                end
            end

            else begin
                loop_pos <= loop_pos + 4'd1;
            end
        end
    end

endmodule
