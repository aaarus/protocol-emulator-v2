"""Assembler for the protocol emulator's evolving ISA."""

from .core import AssemblyError, AssemblyResult, assemble

__all__ = ["AssemblyError", "AssemblyResult", "assemble"]
