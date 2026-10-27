// Run from reset. GPIO0 sends data 11010010 followed by CRC 0101110.
// One bit every 16 CPU clocks; CRC_TX currently routes to GPIO0.
.equ BIT_PERIOD, 16
CONFIG_GPIO 0, OUTPUT, PUSH_PULL, TIMED
SET_GPIO_TX TX0, 0

// CRC-7: x^7+x^3+1, seed 0, final XOR 0.
WRITE_REG 0x00, 0x09
WRITE_REG 0x01, 0
WRITE_REG 0x02, 0
WRITE_REG 0x03, 0
WRITE_REG 0x04, 0
WRITE_REG 0x05, 0
WRITE_REG 0x06, 0
WRITE_REG 0x07, 0
WRITE_REG 0x08, 0
WRITE_REG 0x09, 0
WRITE_REG 0x0A, 0
WRITE_REG 0x0B, 0
WRITE_REG 0x0C, 7
WRITE_REG 0x0D, 0       // Calculate from TX0.
WRITE_REG 0x0E, 1       // Load seed and clear any CRC_TX snapshot.
LOAD_TX TX0, 0x4B      // TX0 is LSB-first: emits 11010010.
CRC ENABLE
LOAD_TICK_INC BIT_PERIOD // Restart periodic tick after configuration.

LOOP 8
    SHIFT_OUT TX0       // Queue one bit and update CRC once.
    WAIT_TICK          // Wait for that bit to commit before queuing another.
LOOP_END
CRC DISABLE
LOOP 7
    SHIFT_OUT CRC_TX    // Auto-snapshot 0x2E; queue next CRC bit.
    WAIT_TICK          // Includes the last bit: drain it before STOP.
LOOP_END
STOP
