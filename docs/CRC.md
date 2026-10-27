# CRC configuration

`WRITE_REG address, value` writes one byte. Multi-byte registers use little-endian byte addresses.

| Address | Register |
| --- | --- |
| 0x00–0x03 | Polynomial |
| 0x04–0x07 | Initial value |
| 0x08–0x0B | Final XOR |
| 0x0C | Width: 1–32 bits |
| 0x0D | Source: 0 = TX0, 1 = TX1 |
| 0x0E | Write bit 0 = 1 to initialize and clear the transmit snapshot |

`CRC ENABLE` accumulates bits consumed from the selected TX channel; `CRC DISABLE` stops accumulation. `SHIFT_OUT CRC_TX` snapshots the result on the first shift, then emits one bit per instruction, most-significant active bit first. TX0/TX1 transmit least-significant bit first. CRC output is fixed to GPIO0 pending a configuration write path.

[crc_tx.asm](../examples/crc_tx.asm) sends eight data bits followed by a seven-bit CRC. [crc_timed.asm](../examples/crc_timed.asm) adds tick-paced output. Timed writes have a single pending value per pin: firmware must wait between bits to avoid overwriting it. Stuffing and line encoding are not implemented.
