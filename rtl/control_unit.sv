module control_unit(
    input clk, 
    input rst,
    input [5:0] opcode,
    input crc_enable_value,
    input delay_zero,
    input loop_back,
    input tick,
    

    output reg load_counter_en,
    output reg tx_shift_en,
    output reg rx_shift_en,
    output reg init_loop_en,
    output reg wr_tx_config, wr_rx_config,
    output reg config_gpio,
    output reg sample_en, branch_en,
    output reg set_gpio, clr_gpio,
    output reg tx_enable,
    output reg dec_counter_en,
    output reg tx_load_en,
    output reg pc_mux_sel,
    output reg pc_stall,
    output reg load_tick_en,
    output reg tick_enable,
    output reg reg_write_en,
    output reg crc_active // Persistent clocked enable
    );

    reg [1:0] state, next_state;
    localparam NORMAL = 2'b00;
    localparam STALL = 2'b10;
    localparam TICKING = 2'b01;










    //opcodes
    localparam SHIFT_OUT = 6'b000000;
    localparam SHIFT_IN = 6'b000001;
    localparam LOOP = 6'b000010;
    localparam WAIT = 6'b000011; //not really needed. remove later. or is it.
    localparam DELAY = 6'b000100;
    localparam SET_GPIO = 6'b000101;
    localparam CLR_GPIO = 6'b000110; //set and clr can be merged, remove later
    localparam SET_GPIO_RX = 6'b000111; //merge with config write reg
    localparam SET_GPIO_TX = 6'b001000; //merge with config write reg
    localparam LOAD_TX = 6'b001001;//merge with config write reg. or maybe not. not for now.
    localparam CONFIG_GPIO = 6'b001010; //merge with config write reg
    localparam SAMPLE = 6'b001011;
    localparam BRANCH = 6'b001100;
    localparam LOAD_TICK_INC = 6'b001101; //merge with config write reg. or maybe not. not for now.
    localparam WAIT_TICK = 6'b001110;
    localparam WRITE_REG = 6'b001111;
    localparam CRC_ENABLE = 6'b010000;





    assign pc_mux_sel = loop_back;


    always @(posedge clk, negedge rst) begin 
        if (!rst) begin 
            state <= NORMAL;
            crc_active <= 0;
        end
        else begin 
            state <= next_state;
            if (state == NORMAL && opcode == CRC_ENABLE)
                crc_active <= crc_enable_value;
        end
    end



    //for normal combinational logic(in normal state)
    always_comb begin

        // Defaults
        load_counter_en = 0;
        tx_shift_en     = 0;
        rx_shift_en     = 0;
        init_loop_en    = 0;
        wr_tx_config    = 0;
        wr_rx_config    = 0;
        config_gpio     = 0;
        sample_en       = 0;
        branch_en       = 0;
        set_gpio        = 0;
        clr_gpio        = 0;
        tx_enable       = 0;
        dec_counter_en  = 0;
        tx_load_en      = 0;
        pc_stall        = 0;
        load_tick_en    = 0;
        reg_write_en    = 0;

        // Hold current state unless explicitly changed
        next_state = state;


        if (state != STALL) begin

            case(opcode)

                SHIFT_OUT: begin 
                    tx_enable = 1;
                    tx_shift_en = 1;
                end

                SHIFT_IN: begin
                    //shifts in data
                    rx_shift_en = 1;
                end

                LOOP: begin 
                    // loop_handler tracks repetition; the control unit stays NORMAL.
                    init_loop_en = 1;
                end

                WAIT: begin 
                    load_counter_en = 1; 
                end
                
                DELAY: begin 
                    pc_stall = 1;
                    load_counter_en = 1;
                end

                SET_GPIO: begin 
                    set_gpio = 1;

                end

                CLR_GPIO: begin 
                    clr_gpio = 1;
                end

                SET_GPIO_RX: begin 
                    wr_rx_config = 1;
                end

                SET_GPIO_TX: begin 
                    wr_tx_config = 1;
                end

                LOAD_TX: begin 
                    tx_load_en = 1;
                end

                CONFIG_GPIO: begin
                    config_gpio = 1;
                end

                SAMPLE: begin
                    sample_en = 1;
                end

                BRANCH: begin
                    branch_en = 1;
                end

                LOAD_TICK_INC: begin
                    load_tick_en = 1;
                    tick_enable = 1;
                end

                WAIT_TICK: begin 
                    pc_stall = 1;
                end

                WRITE_REG: begin 
                    reg_write_en = 1;
                end

                CRC_ENABLE: begin
                    // The persistent enable is updated in the clocked block.
                end

                //config isa: 6 bit opcode, 6 bit config_reg_addr, 8 bit config_reg_data



                default: begin 
                    load_counter_en = 0;
                    tx_shift_en     = 0;
                    rx_shift_en     = 0;
                    init_loop_en    = 0;
                    wr_tx_config    = 0;
                    wr_rx_config    = 0;
                    config_gpio    =  0;
                    set_gpio        = 0;
                    clr_gpio        = 0;
                    tx_enable       = 0;
                    dec_counter_en  = 0;
                    tx_load_en      = 0;
                    pc_stall        = 0;
                end
            endcase
        end
        //aargh
        
        

        if (state == STALL) begin
            dec_counter_en = 1;
            if (!delay_zero) pc_stall = 1;
            // introduce bug (if tick) pc_stal = 1 
        end

        case(state) //just next state comb logic, not output logic
            NORMAL: begin 
                if (opcode == DELAY) begin 
                    next_state = STALL;
                end
                if (opcode == WAIT_TICK) begin 
                    next_state = TICKING;
                end
            end

            STALL: begin 
                if (delay_zero) begin 
                    next_state = NORMAL;
                end
            end
            TICKING:begin 
                if (tick) begin 
                    next_state = NORMAL;
                    pc_stall = 0;
                end
            end

            default: begin 
                next_state = NORMAL;
            end
        endcase




    end

endmodule