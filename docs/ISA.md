# Instruction set (20 bits)

Every instruction is one 20-bit word. The opcode is always the six most
significant bits. Opcode numbers retain their prior values (0 through 15);
Opcode 16 (`0x10`) is assigned to CRC enable/disable; 17 through 63 remain
available for future instructions.

```text
19                  14 13                                  0
+---------------------+-------------------------------------+
| opcode (6 bits)     | operands (14 bits)                  |
+---------------------+-------------------------------------+

WRITE_REG:
19                  14 13                8 7                0
+---------------------+-------------------+------------------+
| 001111 (0x0F)       | address (6 bits)  | data (8 bits)    |
+---------------------+-------------------+------------------+
```

For existing instructions other than WRITE_REG, operand fields keep their
previous bit positions in `[11:0]`. Bits `[13:12]` are reserved and ignored.
Unused operand bits must be written as zero by firmware. This revision does
not widen counters, branch offsets, loop counts, GPIO selectors, or data bytes.

## Opcode and operand map

| Opcode | Mnemonic | Operands / low-bit layout |
| --- | --- | --- |
| `0x00` | `SHIFT_OUT source` | `[3:2]`: 0=TX0, 1=TX1, 2=BOTH, 3=CRC_TX |
| `0x01` | `SHIFT_IN` | No operands |
| `0x02` | `LOOP count` | Count `[11:4]` (1..255), body length `[3:0]` (1..15, calculated by assembler from LOOP_END) |
| `0x03` | legacy WAIT | Hardware retains its old load-counter/advance behavior; assembler does not expose it |
| `0x04` | `DELAY count` | Count `[11:0]`, 1..4095 |
| `0x05` | `SET_GPIO pin` | Pin `[1:0]` |
| `0x06` | `CLR_GPIO pin` | Pin `[1:0]` |
| `0x07` | `SET_GPIO_RX pin` | Pin `[1:0]` |
| `0x08` | `SET_GPIO_TX source, pin` | Source `[2]`: 0=TX0, 1=TX1; pin `[1:0]` |
| `0x09` | `LOAD_TX source, byte` | Source `[9:8]`: 0=TX0, 1=TX1, 2=BOTH, 3=reserved; byte `[7:0]` |
| `0x0A` | `CONFIG_GPIO pin, direction, drive, timing` | Timing `[4]`, open-drain `[3]`, direction `[2]`, pin `[1:0]` |
| `0x0B` | `SAMPLE pin` | Pin `[1:0]` |
| `0x0C` | `BRANCH condition, [status,] target` | Condition `[11:10]`, status index `[9:8]`, signed relative offset `[7:0]` |
| `0x0D` | `LOAD_TICK_INC period` | Existing name retained; integer period `[11:0]`, 0..4095 |
| `0x0E` | `WAIT_TICK` | No operands |
| `0x0F` | `WRITE_REG address, byte` | Address `[13:8]` (0..63), byte `[7:0]` (0..255) |
| `0x10` | `CRC ENABLE` / `CRC DISABLE` | `[0]`: 1=enable, 0=disable; `[13:1]` reserved, assembled as zero |
| `0x11..0x3F` | Reserved | No instruction side effects; PC advances during normal execution |

GPIO pins are 0..3. Direction is INPUT/OUTPUT; drive is PUSH_PULL/OPEN_DRAIN;
timing is IMMEDIATE/TIMED. Branch conditions are ALWAYS=0, BIT_SET=1 and
BIT_CLEAR=2; condition 3 makes no branch request. Status indices remain
SAMPLED_GPIO=0, LAST_TX0=1, LAST_TX1=2, TIMEOUT=3.

The PC remains 16 bits and counts **instruction words**, not bytes. The
instruction memory remains 256 words, now each 20 bits (5120 bits total).
The existing low-eight-bit IMEM address selection remains. Branch targets
remain `PC + 1 + sign_extend(offset)`, with offsets from -128 to +127.

The existing DELAY 1 counter-wrap behavior is unchanged; the assembler warns
about it. Wider instructions do not alter instruction execution timing.

## Encoding examples

| Assembly | 20-bit word |
| --- | --- |
| `SHIFT_OUT CRC_TX` | `0x0000C` |
| `LOAD_TX TX1, 0xA5` | `0x241A5` |
| `CONFIG_GPIO 0, OUTPUT, PUSH_PULL, IMMEDIATE` | `0x28004` |
| `DELAY 3` | `0x10003` |
| `WRITE_REG 0x0C, 32` | `0x3CC20` |
| `WRITE_REG 0x3F, 0xA5` | `0x3FFA5` |
| `STOP` (BRANCH ALWAYS, -1) | `0x300FF` |
| `CRC ENABLE` | `0x40001` |
| `CRC DISABLE` | `0x40000` |

Ordinary encoding is `(opcode << 14) | operands`. WRITE_REG is
`(0x0F << 14) | (address << 8) | byte`.

CRC control assembles as `(0x10 << 14) | enabled`. Both forms are single
instructions and share the same opcode; keywords are case-insensitive.
The clocked RTL enable gates calculation on selected TX shifts; enabling does not initialize the CRC.
The current control-unit sketch references `instruction[0]` without an
instruction input; that connection still needs to be implemented.

## Configuration address space

The integrated configuration bus uses six-bit addresses. CRC uses `0x00..0x0E`:

| Address | Register byte |
| --- | --- |
| `0x00..0x03` | Polynomial, least-significant byte first |
| `0x04..0x07` | Initial value, least-significant byte first |
| `0x08..0x0B` | Final XOR, least-significant byte first |
| `0x0C` | Active CRC width |
| `0x0D` | Source: bit 0 = 0 for TX0, 1 for TX1; other bits ignored |
| `0x0E` | Initialize command: writing bit 0 = 1 loads seed and clears CRC_TX snapshot |
| `0x0F..0x3F` | Available for other register decoders |

There are 49 addresses outside the CRC range. The decoder compares all six
address bits: `0x10`, `0x20`, and `0x30` do not alias `0x00`, and similarly
for other addresses with the same low nibble. No bank selector is needed to
access these 64 bytes. Other decoders must use non-overlapping addresses.

The calculator is connected to WRITE_REG and selected TX shifts. The CRC_TX
GPIO configuration write path remains deferred and selects GPIO0 after reset.
See [CRC.md](CRC.md) for cycle and initialization semantics.

