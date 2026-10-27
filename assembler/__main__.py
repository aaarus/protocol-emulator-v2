"""Run from v0.8: python -m assembler program.asm -o imem.bin."""

import argparse
from pathlib import Path
import sys

from .core import AssemblyError, ISA_VERSION, SUPPORTED_ISAS, assemble


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Protocol emulator v0.8 20-bit assembler")
    parser.add_argument("source", type=Path)
    parser.add_argument("-o", "--output", type=Path, help="default: source with .bin/.hex suffix")
    parser.add_argument("--isa", choices=SUPPORTED_ISAS, default=ISA_VERSION)
    parser.add_argument("--format", choices=["bin", "hex"], default="bin")
    parser.add_argument("--listing", type=Path, help="write address/word/source listing")
    parser.add_argument("--pad-to", type=int, metavar="WORDS", help="pad with self-branches, up to 256 words")
    parser.add_argument("--warnings-as-errors", action="store_true")
    args = parser.parse_args(argv)
    output = args.output or args.source.with_suffix("." + args.format)
    paths = [args.source.resolve(), output.resolve()]
    if args.listing:
        paths.append(args.listing.resolve())
    if len(paths) != len(set(paths)):
        parser.error("source, output and listing must have distinct paths")
    try:
        result = assemble(args.source.read_text(encoding="utf-8-sig"),
                          filename=str(args.source), isa=args.isa)
        memory = result.memory_text(args.format, args.pad_to)
        for warning in result.warnings:
            print(warning, file=sys.stderr)
        if args.warnings_as_errors and result.warnings:
            print("assembly failed: warnings treated as errors", file=sys.stderr)
            return 1
        output.write_text(memory, encoding="ascii")
        if args.listing:
            args.listing.write_text(result.listing(), encoding="utf-8")
    except (AssemblyError, OSError, UnicodeError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    print(f"Assembled {len(result.words)} words ({result.isa}) -> {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
