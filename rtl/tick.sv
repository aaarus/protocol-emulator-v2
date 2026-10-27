// Programmable tick period in enabled clock cycles: 0 disables, 1 ticks every cycle.
module tick_counter (
    input wire clk,
    input wire rst_n,                 // Active-low asynchronous reset
    input wire enable,
    input wire period_wr_en,          // Load period and restart counting
    input wire [11:0] period_in,
    output reg tick
);
    reg [11:0] period;
    reg [11:0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            period <= 12'd0;
            count <= 12'd0;
            tick <= 1'b0;
        end else begin
            tick <= 1'b0;
            if (period_wr_en) begin
                period <= period_in;
                count <= 12'd0;
            end else if (enable && period != 12'd0) begin
                if (count == period - 12'd1) begin
                    count <= 12'd0;
                    tick <= 1'b1;
                end else begin
                    count <= count + 12'd1;
                end



            end
        end
    end
endmodule
