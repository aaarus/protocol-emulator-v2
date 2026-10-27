module top(
    input clk, rst,
    inout  wire [3:0] gpio_pad

);



    //config bus start
    parameter CONFIG_ADDR_WIDTH = 6;
    parameter CONFIG_DATA_WIDTH = 8;
    wire [CONFIG_ADDR_WIDTH-1:0] config_addr;
    wire [CONFIG_DATA_WIDTH-1:0] config_data_in;
    wire config_wr_en;
    wire crc_active, crc_enable_value, crc_source_select;
    wire [31:0] crc_tx_value;
    wire [5:0] crc_tx_width;
    // Write-one command; no stored initialization bit.
    wire init_crc = config_wr_en && config_addr == 6'h0E && config_data_in[0];
    //config bus end

    
    wire [19:0] instruction;

    wire [1:0] tx_config, tx1_config, rx_config, crc_tx_gpio;
    wire [1:0] tx_shift_select, tx_load_select;
    wire tx_config_select;

    // INSTRUCTION PARSING !!!

    // Wire declarations to connect to the module outputs

    wire [5:0]  opcode;
    wire [1:0]  gpio;
    wire gpio_direction, gpio_open_drain, gpio_timed_enable;
    wire [1:0] branch_cond, branch_status_bit;
    wire signed [7:0] branch_offset;
    wire [7:0]  loop_count;
    wire [3:0]  loop_length;
    wire [7:0]  wait_delay_count;
    wire        evnt;
    wire [11:0] delay_count;
    wire [7:0]  tx_load_value;
    wire [11:0] tick_increment_value;



    // Module Instantiation (Named Port Connection)
    instruction_parser u_instruction_parser (
        .instruction      (instruction),
        .opcode           (opcode),
        .gpio             (gpio),
        .tx_shift_select(tx_shift_select),
        .tx_load_select(tx_load_select),
        .tx_config_select(tx_config_select),
        .gpio_direction   (gpio_direction),
        .gpio_open_drain  (gpio_open_drain),
        .gpio_timed_enable(gpio_timed_enable),
        .branch_condition (branch_cond),
        .branch_status_bit(branch_status_bit),
        .branch_offset    (branch_offset),
        .loop_count       (loop_count),
        .loop_length      (loop_length),
        .wait_delay_count (wait_delay_count),
        .evnt             (evnt),
        .delay_count      (delay_count),
        .tx_load_value     (tx_load_value),
        .tick_increment_value(tick_increment_value),
        .crc_enable_value(crc_enable_value),
        .write_reg_addr(config_addr),
        .write_reg_data(config_data_in)
    );


    wire loop_back;
    wire delay_zero;

    wire load_delay_counter;
    wire tx_shift_en;
    wire rx_shift_en;
    wire init_loop_en;
    wire wr_tx_config, wr_rx_config;
    wire config_gpio;
    wire set_gpio, clr_gpio;
    wire tx_enable;
    wire dec_counter_en;
    wire tx_load_en;
    wire pc_mux_sel;
    wire pc_stall;
    wire sample_en, branch_en, branch_taken;
    wire [3:0] status;
    wire tick_enable;
    wire load_tick_en;
    wire bit_tick;

    control_unit cu(
        .clk(clk),
        .rst(rst),
        .opcode(opcode),
        .crc_enable_value(crc_enable_value),
        .crc_active(crc_active),
        .loop_back(loop_back),
        .load_counter_en(load_delay_counter),
        .tx_shift_en(tx_shift_en),
        .rx_shift_en(rx_shift_en),
        .init_loop_en(init_loop_en),
        .wr_tx_config(wr_tx_config),
        .wr_rx_config(wr_rx_config),
        .config_gpio(config_gpio),
        .sample_en(sample_en),
        .branch_en(branch_en),
        .set_gpio(set_gpio),
        .clr_gpio(clr_gpio),
        .tx_enable(tx_enable),
        .dec_counter_en(dec_counter_en),
        .tx_load_en(tx_load_en),
        .pc_mux_sel(pc_mux_sel),
        .pc_stall(pc_stall),
        .delay_zero(delay_zero),
        .tick_enable(tick_enable),
        .load_tick_en(load_tick_en),
        .tick(bit_tick),
        .reg_write_en(config_wr_en)

    );

    wire [3:0] loop_length_latched;
    loop_handler loop_handler(
        .clk(clk),
        .rst(rst),
        .init_en(init_loop_en),
        .cancel(branch_taken),
        .loop_back(loop_back),
        .loop_length_in(loop_length),
        .loop_count_in(loop_count),
        .loop_length_latched(loop_length_latched),
        .en(!pc_stall)
    );

    delay_counter #(
        .N(12) 
    ) u_delay_counter (
        .clk(clk),     // connect to clock signal
        .rst_n(rst),   // connect to active-low reset signal
        .load    (load_delay_counter),    // connect to load enable signal
        .dec_en  (dec_counter_en),  // connect to decrement enable signal
        .data_in (delay_count), // connect to input data bus [N-1:0] //choose bw wait_delay_count and delay_count
        .count   (),    // connect to output count bus [N-1:0]
        .zero(delay_zero)
        );



    // SHIFT_OUT: 00 = TX0, 01 = TX1, 10 = both, 11 = CRC_TX.
    // LOAD_TX selector 11 remains reserved: CRC_TX snapshots automatically.
    wire tx0_selected = (tx_shift_select == 2'b00 || tx_shift_select == 2'b10);
    wire tx1_selected = (tx_shift_select == 2'b01 || tx_shift_select == 2'b10);
    wire crc_tx_selected = (tx_shift_select == 2'b11);
    wire tx0_shift_en = tx_shift_en && tx0_selected;
    wire tx1_shift_en = tx_shift_en && tx1_selected;
    wire tx0_load_en = tx_load_en && (tx_load_select == 2'b00 || tx_load_select == 2'b10);
    wire tx1_load_en = tx_load_en && (tx_load_select == 2'b01 || tx_load_select == 2'b10);
    wire tx_serial_out, tx1_serial_out;
    // These pulses consume pre-shift source bits, once per instruction.
    // BOTH still contributes exactly one bit from the selected source.
    wire data_bit_accepted = crc_source_select ? tx1_shift_en : tx0_shift_en;
    wire crc_data_in = crc_source_select ? tx1_serial_out : tx_serial_out;
    wire enable_crc_calculation = crc_active && data_bit_accepted;
    crc_calculator #(.N(32)) u_crc_calculator (
        .clk(clk), .rst(rst), .data_in(crc_data_in),
        .cfg_write(config_wr_en), .cfg_address(config_addr),
        .cfg_write_data(config_data_in), .init_crc(init_crc),
        .enable_crc_calculation(enable_crc_calculation),
        .crc_result(crc_tx_value), .crc_width_out(crc_tx_width)
    );
    wire crc_tx_serial_out, crc_tx_bit_valid;
    wire crc_tx_shift_en = tx_shift_en && crc_tx_selected && crc_tx_bit_valid;
    crc_tx_reg #(.DATA_WIDTH(32)) u_crc_tx_reg (
        .clk(clk), .rst_n(rst), .shift_en(crc_tx_shift_en), .clear(init_crc),
        .parallel_in(crc_tx_value), .crc_width(crc_tx_width),
        .serial_out(crc_tx_serial_out), .bit_valid(crc_tx_bit_valid)
    );
    tx_reg #(.DATA_WIDTH(8)) u_tx1_reg (
        .clk(clk), .rst_n(rst), .load(tx1_load_en),
        .parallel_in(tx_load_value), .serial_out(tx1_serial_out),
        .shift_en(tx1_shift_en)
    );
    tx_reg #(
        .DATA_WIDTH(8) // Set width (change 8 to your desired width)
    ) u_tx_reg (
        .clk         (clk),         // Connect to clock signal
        .rst_n       (rst),       // Connect to active-low reset signal
        .load        (tx0_load_en),        // Connect to load/shift control signal ??
        .parallel_in (tx_load_value), // Connect to parallel input bus [DATA_WIDTH-1:0]
        .serial_out  (tx_serial_out),   // Connect to serial output wire
        .shift_en   (tx0_shift_en) // Connect to tx_enable signal
    );

    wire [3:0] gpio_values;

    status_register u_status_register (
        .clk(clk), .rst(rst),
        .sample_en(sample_en),
        .sampled_gpio(gpio_values[gpio]),
        .tx_shift_en(tx0_shift_en && !tx0_load_en),
        .tx1_shift_en(tx1_shift_en && !tx1_load_en),
        .tx1_bit(tx1_serial_out),
        .tx_bit(tx_serial_out),
        .status(status)
    );

    branch_condition u_branch_condition (
        .branch_en(branch_en),
        .condition(branch_cond),
        .status_bit(branch_status_bit),
        .status(status),
        .taken(branch_taken)
    );


    // Registered tick is consumed on the next clock edge as an enable.
    // It runs independently of PC stalls and instruction strobes.
    tick_counter u_tick_counter (
        .clk(clk), .rst_n(rst), .enable(tick_enable),
        .period_wr_en(load_tick_en),
        .period_in(tick_increment_value), .tick(bit_tick)
    );

        gpio #(
        .NUM_GPIO(4)
    ) u_gpio (
        .clk        (clk),
        .rst_n      (rst),

        .set_gpio   (set_gpio),
        .clr_gpio   (clr_gpio),

        // Reuse TX0's GPIO write port; TX0 itself remains unselected for CRC_TX.
        .tx_bit     (crc_tx_selected ? crc_tx_serial_out : tx_serial_out),
        .tx_config  (crc_tx_selected ? crc_tx_gpio : tx_config),
        .tx_enable  (tx_enable && (tx0_selected ||
                     (crc_tx_selected && crc_tx_bit_valid))),
        .tx1_enable (tx_enable && tx1_selected),
        .tx1_config (tx1_config),
        .tx1_bit    (tx1_serial_out),

        .config_gpio (config_gpio),
        .gpio_direction (gpio_direction),
        .gpio_open_drain (gpio_open_drain),
        .gpio_timed_enable (gpio_timed_enable),
        .bit_tick (bit_tick),

        .gpio_pad   (gpio_pad),
        .gpio_in    (gpio_values), //confirm once
        .gpio_select(gpio)
    );

    wire rx_serial_in;


    // Instantiation template for the parameterized 1-bit MUX
    parameterized_1bit_mux #(
        .CHANNELS(4) // Set the number of input channels here (e.g., 4, 8, 16)
    ) u_mux_inst (
        .in_bus(gpio_values), 
        .sel(rx_config), 
        .out(rx_serial_in)  
    );



    rx_reg #(
        .N(8) // Set width
    ) u_rx_reg (
        .clk          (clk),          // Connect to clock signal
        .rst_n        (rst),        // Connect to active-low reset signal
        .enable       (rx_shift_en),       // Connect to shift enable signal
        .dir          (1'b1),          // Connect to direction control (0: Right, 1: Left)
        .serial_in    (rx_serial_in),    // Connect to serial input wire
        .parallel_out (/*empty for now*/)  // Connect to parallel output bus [N-1:0]
    );




    configuration_registers u_configuration_registers(
        .clk(clk),
        .rst(rst),
        .wr_tx_en(wr_tx_config),
        .tx_select(tx_config_select),
        .tx1_reg(tx1_config),
        .wr_rx_en(wr_rx_config),
        .rx(gpio),
        .tx(gpio),
        .tx_reg(tx_config), //verify once
        .rx_reg(rx_config), //verify once
        .crc_tx_gpio(crc_tx_gpio),
        .cfg_write(config_wr_en),
        .cfg_address(config_addr),
        .cfg_write_data(config_data_in), 
        .crc_source_select(crc_source_select)
    );


    wire [15:0] pc_addr_out;
    pc u_pc(
        .clk(clk),
        .rst(rst),
        .pc_mux_sel(pc_mux_sel),
        .pc_stall(pc_stall),
        .loop_length(loop_length_latched),
        .branch_taken(branch_taken),
        .branch_offset(branch_offset),
        .pc_addr_out(pc_addr_out)
    );

    imem u_imem(
        .addr(pc_addr_out[7:0]),
        .data_out(instruction)
    );


    wire evnt;
    event_handler u_event_handler(
        .clk(clk),
        .rst(rst),
        .tick(bit_tick),
        .gpio_in(gpio_values),
        .last_tx(),
        .evnt(evnt)
    );






endmodule

