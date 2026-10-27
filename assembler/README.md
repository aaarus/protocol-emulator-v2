# Assembler

From the repository root:

```sh
python -m assembler examples/crc_tx.asm -o examples/crc_tx.bin --pad-to 256
python -m assembler examples/tick.asm -o examples/tick.hex --format hex
```

Python 3.10+, standard library only. Emits 20-bit binary or five-digit hex words, with optional `--listing PATH`. Supports labels, constants, hardware loops and GPIO macros. Padding uses `STOP`; memory capacity is 256 words.

The inherited ISA name remains `v0.8`; it is also used by this v0.9 snapshot. See the [instruction set](../docs/ISA.md) and [CRC configuration](../docs/CRC.md).
