"""20-bit v0.8 assembler: six-bit opcodes and byte configuration writes."""

from dataclasses import dataclass
from collections import deque
import re

from .macros import MACROS


ISA_VERSION = "v0.8"
SUPPORTED_ISAS = ("v0.8",)
MEMORY_WORDS = 256
INSTRUCTION_BITS = 20
OPCODE_SHIFT = 14
MAX_WORD = (1 << INSTRUCTION_BITS) - 1
OPCODES = {
    "SHIFT_OUT": 0x0, "SHIFT_IN": 0x1, "LOOP": 0x2, "DELAY": 0x4,
    "SET_GPIO": 0x5, "CLR_GPIO": 0x6, "SET_GPIO_RX": 0x7,
    "SET_GPIO_TX": 0x8, "LOAD_TX": 0x9, "CONFIG_GPIO": 0xA,
    "SAMPLE": 0xB, "BRANCH": 0xC, "LOAD_TICK_INC": 0xD, "WAIT_TICK": 0xE,
    "WRITE_REG": 0xF, "CRC": 0x10,
}
TX = {"TX0": 0, "TX1": 1, "BOTH": 2}
STATUS = {"SAMPLED_GPIO": 0, "LAST_TX0": 1, "LAST_TX1": 2, "TIMEOUT": 3}
CONDITIONS = {"ALWAYS": 0, "BIT_SET": 1, "BIT_CLEAR": 2}
CRC_ACTIONS = {"ENABLE": 1, "DISABLE": 0}
IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z_0-9]*\Z")
INTEGER = re.compile(r"[+-]?(?:0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+|[0-9]+)\Z")


class AssemblyError(ValueError):
    """A source error, including its filename and line when available."""


@dataclass(frozen=True)
class Instruction:
    address: int
    line: int
    source: str
    mnemonic: str
    operands: tuple[str, ...]


@dataclass(frozen=True)
class AssemblyResult:
    words: tuple[int, ...]
    symbols: dict[str, int]
    instructions: tuple[Instruction, ...]
    warnings: tuple[str, ...]
    isa: str = ISA_VERSION

    def memory_text(self, format: str = "bin", pad_to: int | None = None) -> str:
        """Return readmemb/readmemh text; padding uses BRANCH ALWAYS, -1."""
        if format not in ("bin", "hex"):
            raise ValueError("format must be bin or hex")
        size = len(self.words) if pad_to is None else pad_to
        if not len(self.words) <= size <= MEMORY_WORDS:
            raise ValueError("pad size must be between program length and 256")
        spec = "020b" if format == "bin" else "05X"
        return "".join(f"{word:{spec}}\n" for word in
                       self.words + ((OPCODES["BRANCH"] << OPCODE_SHIFT) | 0xFF,) * (size - len(self.words)))

    def listing(self) -> str:
        return "".join(f"{i.address:04X}  {word:05X}  {i.line:4d}  {i.source}\n"
                       for i, word in zip(self.instructions, self.words))


def assemble(source: str, *, filename: str = "<string>", isa: str = ISA_VERSION) -> AssemblyResult:
    """Assemble a zero-origin program; numeric branch operands are offsets.

    Labels and constants are case-sensitive. Keywords are case-insensitive.
    LOOP_END has no encoding: pass one computes its preceding LOOP's length.
    """
    if isa not in SUPPORTED_ISAS:
        raise AssemblyError(f"unsupported ISA {isa!r}; supported: {', '.join(SUPPORTED_ISAS)}")
    symbols: dict[str, int] = {}
    labels: set[str] = set()
    instructions: list[Instruction] = []
    loop_lengths: dict[int, int] = {}
    loop_regions: list[tuple[int, int]] = []
    active_loop: Instruction | None = None
    warnings: list[str] = []

    def fail(line: int, message: str):
        raise AssemblyError(f"{filename}:{line}: {message}")

    def warn(line: int, message: str):
        warnings.append(f"{filename}:{line}: warning: {message}")

    def literal(token: str, line: int) -> int:
        if not INTEGER.fullmatch(token):
            fail(line, f"expected integer literal, got {token!r}")
        unsigned = token.lstrip("+-")
        return int(token, 0 if unsigned.lower().startswith(("0x", "0b", "0o")) else 10)

    def define(name: str, value: int, line: int):
        if not IDENTIFIER.fullmatch(name):
            fail(line, f"invalid symbol name {name!r}")
        if name in symbols:
            fail(line, f"duplicate symbol {name!r}")
        # Keep symbolic enum operands unambiguous.
        reserved = set(TX) | set(STATUS) | set(CONDITIONS) | set(CRC_ACTIONS) | {
            "INPUT", "OUTPUT", "PUSH_PULL", "OPEN_DRAIN", "IMMEDIATE", "TIMED", "CRC_TX"}
        if name.upper() in reserved:
            fail(line, f"reserved operand name {name!r}")
        symbols[name] = value

    def operands(text: str, line: int) -> tuple[str, ...]:
        if not text:
            return ()
        if any(not part.strip() for part in text.split(",")):
            fail(line, "empty operand or trailing comma")
        return tuple(re.split(r"[\s,]+", text))

    pending = deque((line, raw, None) for line, raw in enumerate(source.splitlines(), 1))
    while pending:
        line, raw, origin = pending.popleft()
        text = raw.split("//", 1)[0].strip()
        if ";" in text:
            fail(line, "semicolon comments are unsupported; use // for comments")
        directive = re.match(r"#define(?:\s+|$)", text, re.IGNORECASE)
        if directive:
            definition = text[directive.end():].strip()
            args = operands(definition, line)
            if len(args) != 2:
                fail(line, "expected #define name integer_literal")
            define(args[0], literal(args[1], line), line)
            continue
        if not text:
            continue
        if ":" in text:
            name, text = text.split(":", 1)
            name, text = name.strip(), text.strip()
            if name.upper() == "LOOP":
                fail(line, "use LOOP count followed by LOOP_END; LOOP: has no count")
            define(name, len(instructions), line)
            labels.add(name)
            if not text:
                continue
        parts = text.split(None, 1)
        mnemonic = parts[0].upper()
        args = operands(parts[1].strip() if len(parts) == 2 else "", line)
        if mnemonic in MACROS:
            macro = MACROS[mnemonic]
            if len(args) != macro.operands:
                fail(line, f"{mnemonic} expects {macro.operands} operands, got {len(args)}")
            if macro.outside_loop and active_loop is not None:
                fail(line, f"{mnemonic} cannot be used inside a hardware loop (uses or cancels loop state)")
            expanded = [template.format(*args) for template in macro.body]
            pending.extendleft((line, text, raw.strip()) for text in reversed(expanded))
            continue
        if mnemonic == ".EQU":
            if len(args) != 2:
                fail(line, "expected .equ name, integer_literal")
            define(args[0], literal(args[1], line), line)
            continue
        if mnemonic == "LOOP_END":
            if args:
                fail(line, "LOOP_END takes no operands")
            if active_loop is None:
                fail(line, "LOOP_END without LOOP")
            length = len(instructions) - active_loop.address - 1
            if not 1 <= length <= 15:
                fail(line, f"loop body must contain 1..15 words, got {length}")
            loop_lengths[active_loop.address] = length
            loop_regions.append((active_loop.address, len(instructions)))
            active_loop = None
            continue
        if mnemonic == "WAIT":
            fail(line, "WAIT is not exposed by the v0.8 assembler; use DELAY or a SAMPLE/BRANCH polling loop")
        if mnemonic not in OPCODES and mnemonic != ".WORD":
            fail(line, f"unknown instruction {mnemonic!r}")
        display_source = f"{origin} => {raw.strip()}" if origin else raw.strip()
        instruction = Instruction(len(instructions), line, display_source, mnemonic, args)
        if mnemonic == "LOOP":
            if active_loop is not None:
                fail(line, "nested hardware loops are unsupported")
            active_loop = instruction
        instructions.append(instruction)
        if len(instructions) > MEMORY_WORDS:
            fail(line, "program exceeds the v0.8 256-word instruction memory")

    if active_loop:
        fail(active_loop.line, "LOOP missing LOOP_END")
    if not instructions:
        fail(1, "program contains no instructions")

    def value(token: str, line: int) -> int:
        if token in symbols:
            return symbols[token]
        if IDENTIFIER.fullmatch(token):
            fail(line, f"undefined symbol {token!r}")
        return literal(token, line)

    def bounded(token: str, line: int, low: int, high: int, field: str) -> int:
        number = value(token, line)
        if not low <= number <= high:
            fail(line, f"{field} must be {low}..{high}, got {number}")
        return number

    def choice(token: str, line: int, choices: dict[str, int], field: str) -> int:
        if token.upper() in choices:
            return choices[token.upper()]
        return bounded(token, line, min(choices.values()), max(choices.values()), field)

    words = []
    for i in instructions:
        op, args, line = i.mnemonic, i.operands, i.line
        arities = {"SHIFT_OUT": 1, "SHIFT_IN": 0, "LOOP": 1, "DELAY": 1,
                   "SET_GPIO": 1, "CLR_GPIO": 1, "SET_GPIO_RX": 1,
                   "SET_GPIO_TX": 2, "LOAD_TX": 2, "CONFIG_GPIO": 4,
                   "SAMPLE": 1, ".WORD": 1, "LOAD_TICK_INC": 1, "WAIT_TICK": 0,
                   "WRITE_REG": 2, "CRC": 1}
        if op == "BRANCH":
            if not args or args[0].upper() not in CONDITIONS:
                fail(line, "BRANCH expects ALWAYS, BIT_SET, or BIT_CLEAR")
            expected = 2 if args[0].upper() == "ALWAYS" else 3
        else:
            expected = arities[op]
        if len(args) != expected:
            fail(line, f"{op} expects {expected} operands, got {len(args)}")
        word = OPCODES.get(op, 0) << OPCODE_SHIFT
        if op == ".WORD":
            word = bounded(args[0], line, 0, MAX_WORD, "raw word")
            warn(line, ".word bypasses instruction and reserved-bit validation")
        elif op == "SHIFT_OUT":
            word |= choice(args[0], line, {**TX, "CRC_TX": 3}, "TX selector") << 2
        elif op in ("SET_GPIO", "CLR_GPIO", "SET_GPIO_RX", "SAMPLE"):
            word |= bounded(args[0], line, 0, 3, "GPIO")
        elif op == "SET_GPIO_TX":
            word |= choice(args[0], line, {"TX0": 0, "TX1": 1}, "TX selector") << 2
            word |= bounded(args[1], line, 0, 3, "GPIO")
        elif op == "LOAD_TX":
            word |= choice(args[0], line, TX, "TX selector") << 8
            word |= bounded(args[1], line, 0, 255, "TX byte")
        elif op == "CONFIG_GPIO":
            word |= bounded(args[0], line, 0, 3, "GPIO")
            word |= choice(args[1], line, {"INPUT": 0, "OUTPUT": 1}, "direction") << 2
            word |= choice(args[2], line, {"PUSH_PULL": 0, "OPEN_DRAIN": 1}, "drive mode") << 3
            word |= choice(args[3], line, {"IMMEDIATE": 0, "TIMED": 1}, "timing mode") << 4
        elif op == "LOAD_TICK_INC":
            word |= bounded(args[0], line, 0, 4095, "tick increment")
        elif op == "WRITE_REG":
            word |= bounded(args[0], line, 0, 63, "register address") << 8
            word |= bounded(args[1], line, 0, 255, "register byte")
        elif op == "CRC":
            action = args[0].upper()
            if action not in CRC_ACTIONS:
                fail(line, "CRC expects ENABLE or DISABLE")
            word |= CRC_ACTIONS[action]
        elif op == "DELAY":
            count = bounded(args[0], line, 1, 4095, "delay")
            word |= count
            if count == 1:
                warn(line, "DELAY 1 encodes 0x10001, but current RTL takes 4097 cycles (counter wraparound)")
        elif op == "LOOP":
            word |= bounded(args[0], line, 1, 255, "loop count") << 4
            word |= loop_lengths[i.address]
        elif op == "BRANCH":
            condition = CONDITIONS[args[0].upper()]
            status = choice(args[1], line, STATUS, "status bit") if condition else 0
            target = args[-1]
            offset = value(target, line)
            if target in labels:
                if not 0 <= offset < len(instructions):
                    fail(line, f"branch label {target!r} does not point to an emitted instruction")
                offset -= i.address + 1
            if not -128 <= offset <= 127:
                fail(line, f"branch offset must be -128..127, got {offset}")
            destination = i.address + 1 + offset
            if not 0 <= destination < len(instructions):
                warn(line, "numeric branch target is outside the emitted program; PC/memory aliasing may occur")
            if any(start < i.address < end for start, end in loop_regions):
                warn(line, "a taken branch cancels the active hardware loop, even with offset zero")
            if any(start < destination < end for start, end in loop_regions):
                warn(line, "branch targets a loop body without initializing its hardware loop state")
            word |= condition << 10 | status << 8 | (offset & 255)
        words.append(word)
    return AssemblyResult(tuple(words), symbols, tuple(instructions), tuple(warnings), isa)
