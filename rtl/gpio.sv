module gpio #(
    parameter int NUM_GPIO = 4
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // SET / CLR GPIO control
    //
    // set_gpio / clr_gpio are write strobes.
    // gpio_select selects which GPIO is modified.
    input  logic [$clog2(NUM_GPIO)-1:0] gpio_select,
    input  logic                  set_gpio,
    input  logic                  clr_gpio,

    // TX
    //
    // tx_enable is the write strobe.
    // tx_config selects the GPIO to write.
    // tx_bit is the value to write.
    //
    // TX uses the SAME configured write path as SET / CLR.
    input  logic                  tx_bit,
    input  logic [$clog2(NUM_GPIO)-1:0] tx_config,
    input  logic                  tx_enable,
    input  logic                  tx1_bit,
    input  logic [$clog2(NUM_GPIO)-1:0] tx1_config,
    input  logic                  tx1_enable,

    // Persistent per-GPIO configuration
    input  logic                  config_gpio,
    input  logic                  gpio_direction,
    input  logic                  gpio_open_drain,
    input  logic                  gpio_timed_enable,

    // Synchronous clock enable: commit previously staged output values.
    input  logic                  bit_tick,

    // GPIO pads
    inout wire [NUM_GPIO-1:0]     gpio_pad,

    // GPIO input
    //
    // Reads the physical GPIO pad.
    output logic [NUM_GPIO-1:0]   gpio_in
);


    // GPIO output latch
    //
    // This is the SINGLE source of truth for GPIO output values.
    //
    // Immediate writes and tick commits update this register.
    logic [NUM_GPIO-1:0] gpio_out_reg;
    logic [NUM_GPIO-1:0] gpio_dir_reg;
    logic [NUM_GPIO-1:0] open_drain_reg;
    logic [NUM_GPIO-1:0] timed_enable_reg;
    logic [NUM_GPIO-1:0] pending_out;
    logic [NUM_GPIO-1:0] pending_mask;
    logic [NUM_GPIO-1:0] write_mask, write_data;
    logic [NUM_GPIO-1:0] cancel_pending;

    // Configuration is independent of SET/CLR/TX output data writes.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_dir_reg   <= '0;
            open_drain_reg <= '0;
            timed_enable_reg <= '0;
        end else if (config_gpio) begin
            gpio_dir_reg[gpio_select]   <= gpio_direction;
            open_drain_reg[gpio_select] <= gpio_open_drain;
            timed_enable_reg[gpio_select] <= gpio_timed_enable;
        end
    end


    // GPIO output enable
    //
    // Input: always release. Output modes:
    // Push-pull:
    //     always drive
    //
    // Open-drain:
    //     value = 0 -> drive 0
    //     value = 1 -> release (Z)
    logic [NUM_GPIO-1:0] gpio_oe;


    // GPIO output latch
    // Normalize sources before choosing immediate versus timed routing.
    // Preserve SET > CLR > TX priority. Simultaneous TX must target
    // distinct GPIOs; same-pin TX collisions remain unsupported.
    always_comb begin
        write_mask = '0;
        write_data = '0;
        cancel_pending = '0;

        if (config_gpio &&
            (timed_enable_reg[gpio_select] != gpio_timed_enable))
            cancel_pending[gpio_select] = 1'b1;

        if (set_gpio) begin
            write_mask[gpio_select] = 1'b1;
            write_data[gpio_select] = 1'b1;
        end else if (clr_gpio) begin
            write_mask[gpio_select] = 1'b1;
            write_data[gpio_select] = 1'b0;
        end else begin
            if (tx_enable) begin
                write_mask[tx_config] = 1'b1;
                write_data[tx_config] = tx_bit;
            end
            if (tx1_enable) begin
                write_mask[tx1_config] = 1'b1;
                write_data[tx1_config] = tx1_bit;
            end
        end
    end

    // One owner for committed and pending output state. All pins commit
    // together on a tick, independently of instruction execution/stalls.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_out_reg <= '0;
            pending_out <= '0;
            pending_mask <= '0;
        end else begin
            for (int i = 0; i < NUM_GPIO; i++) begin
                if (cancel_pending[i]) begin
                    // A timing-mode change cancels queued data and suppresses
                    // this pin's commit/write on this edge; output holds.
                    pending_mask[i] <= 1'b0;
                end else begin
                    if (bit_tick && pending_mask[i]) begin
                        gpio_out_reg[i] <= pending_out[i];
                        pending_mask[i] <= 1'b0;
                    end

                    if (write_mask[i]) begin
                        if (timed_enable_reg[i]) begin
                            // On a coincident tick, the OLD value commits and
                            // this new value stays valid for the NEXT tick.
                            pending_out[i] <= write_data[i];
                            pending_mask[i] <= 1'b1;
                        end else begin
                            // Immediate write wins over any same-pin commit.
                            gpio_out_reg[i] <= write_data[i];
                            pending_mask[i] <= 1'b0;
                        end
                    end
                end
            end
        end
    end


    // Open-drain conversion
    always_comb begin

        for (int i = 0; i < NUM_GPIO; i++) begin

            if (!gpio_dir_reg[i])
                gpio_oe[i] = 1'b0;
            else if (open_drain_reg[i])
                gpio_oe[i] = ~gpio_out_reg[i];
            else
                gpio_oe[i] = 1'b1;

        end

    end


    // GPIO pads
    generate

        for (genvar i = 0; i < NUM_GPIO; i++) begin

            assign gpio_pad[i] =
                gpio_oe[i]
                    ? (open_drain_reg[i] ? 1'b0 : gpio_out_reg[i])
                    : 1'bz;

        end

    endgenerate


    // GPIO input
    // Always reflects the physical pad state.
    always_comb begin
        gpio_in = gpio_pad;
    end


endmodule
