module event_handler(
    input clk,
    input rst,
    input tick,
    input gpio_in, //which gpio to sample
    input last_tx, 
    output reg [n:0] evnt,
    output arbitration_redirect_addr_out
)


    localparam 4'b0000 = normal;
    localparam 4'b0001 = arbitration_lost;


    assign arbitration_redirect_addr_out = redirect_addr;

    reg [n:0] enable_status;
    //arbitration configuration registers
    reg [n:0] sample_point;
    reg [n:0] curr_point;
    reg [n:0] redirect_addr;

    always @(posedge clk, negedge rst) begin 
        evnt <= normal;


        if (!rst) begin
            sample_point <= 0;
            curr_point <= 0;
            redirect_addr <= 0;
            evnt <= normal;
        end



        else if (enable_status[0]) begin 
            if (curr_point == sample_point) begin 
                if (gpio_in != last_tx) begin //need more detailed arbitration handling later
                    evnt <= arbitration_lost;
                end 
            end
            else if (tick) begin 
                curr_point <= curr_point + 1;
            end
        end

        //how to calculate sample point? 1: after every tick. 2: after every transmit
        //calculate using ticks.

        always @(posedge clk, negedge rst) begin 
            if (!rst) begin 
                sample_point <= 0;
            end
            else if () begin 
                sample_point <= smth
                end
            end
        end

        

    end