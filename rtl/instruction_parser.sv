module instruction_parser(
    input [19:0] instruction, 
    output [5:0] opcode,
    output [1:0] gpio,
    output [1:0] tx_shift_select, tx_load_select,
    output tx_config_select,
    output gpio_direction,
    output gpio_open_drain,
    output gpio_timed_enable,
    output [1:0] branch_condition,
    output [1:0] branch_status_bit,
    output signed [7:0] branch_offset,
    output [7:0] loop_count, //verify length once
    output [3:0] loop_length,
    output [7:0] wait_delay_count,
    output evnt, //for wait
    output [11:0] delay_count,
    output [7:0] tx_load_value,
    output [11:0] tick_increment_value,
    output [5:0] write_reg_addr,
    output crc_enable_value,
    output [7:0] write_reg_data
    );

    assign crc_enable_value = instruction[0];
    assign opcode = instruction[19:14];
    assign gpio = instruction[1:0];
    assign tx_shift_select = instruction[3:2];
    assign tx_load_select = instruction[9:8];
    assign tx_config_select = instruction[2];
    // CONFIG_GPIO: [13:5] reserved/ignored; firmware writes zero.
    assign gpio_direction = instruction[2];
    assign gpio_open_drain = instruction[3];
    assign gpio_timed_enable = instruction[4];
    assign branch_condition = instruction[11:10];
    assign branch_status_bit = instruction[9:8];
    assign branch_offset = instruction[7:0];
    assign loop_count = instruction[11:4];
    assign loop_length = instruction[3:0];
    assign wait_delay_count = instruction[11:4];
    assign evnt = instruction[2];
    assign delay_count = instruction[11:0];
    assign tx_load_value = instruction[7:0];
    assign tick_increment_value = instruction[11:0];


    assign write_reg_addr = instruction[13:8];
    assign write_reg_data = instruction[7:0];



endmodule
