# Pre-route timing — 28 October 2026

OpenSTA 2.7.0; IHP SG13CMOS5L typical library, **1.20 V / 25°C**. The [full report](pre_route.rpt) uses the saved v0.9 area model, flattened with Yosys 0.9 for STA.

| Measurement | Result |
| --- | --- |
| Assumed clock | 100 ns / 10 MHz |
| Worst setup slack | +31.895 ns |
| Worst hold slack | +0.167 ns |
| Critical path | PC → instruction-memory read mux → control → CRC_TX |
| Mapped cell area | 448,910 µm² / 0.449 mm² |
| Cells / flip-flops | 15,561 / 5,415 |

**This is not timing closure.** The report has slew/capacitance violations and one unclocked tick-enable latch. The critical PC output drives 1,265 loads, with 53.87 ns slew; these unbuffered loads limit the usefulness of the positive slack. Reset release, physical wiring, clock-tree effects and other corners are not covered.

## Assumptions

- Ideal clock; no wire parasitics. Input delays: 2–20 ns; output delays: 0–20 ns. Input/clock transition: 0.1 ns; output load: 10 fF. Setup/hold uncertainty: 0.5/0.1 ns. Reset held inactive.
- The original ROM is replaced **only in the synthesis model** by a writable 256 × 20 flop memory (5,120 flops). This is a planning model, not a finished programming interface.
- Unfinished arbitration is excluded; PC event/redirect inputs are tied low. The unresolved `smth` configuration address is exposed as a one-bit input. GPIO pads are split into input/output/enable signals.
- The existing tick-enable latch is retained; unobserved RX data is optimized away. Syntax adaptations include the procedural PC signal declaration. No functional repair or equivalence proof is claimed.

Original RTL remains in [../rtl](../rtl). [prepare.py](prepare.py) documents every synthesis-only adaptation. [area.json](area.json) is the saved 26 October area result; [provenance.json](provenance.json) and [source_hashes.json](source_hashes.json) identify the inputs.

## Reproduce

From this folder on Linux/WSL, with Yosys 0.9, OpenSTA and the named IHP library installed (library not bundled):

```sh
export LIBERTY=/path/to/sg13cmos5l_stdcell_typ_1p20V_25C.lib
yosys -Q -p 'read_verilog mapped.v; hierarchy -top top; flatten; clean; write_verilog -noattr flat.v'
sta -no_init -exit pre_route.tcl > pre_route.rpt 2>&1
```

Optional: rebuild the scoped mapped model from the published RTL before running STA:

```sh
python3 prepare.py
yosys -Q -l synthesis.log synth.ys
```

Rebuilding with a different tool/library may change the result. Flattening avoids a hierarchical linking stall in the installed timing tools; it does not remap cells.
