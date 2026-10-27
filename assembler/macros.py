"""Built-in, fixed-size source macros for v0.8; no new hardware opcodes.

Templates substitute whole operands. Ordinary instruction validation remains
authoritative, and expansion happens before address and loop-length resolution.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Macro:
    operands: int
    body: tuple[str, ...]
    outside_loop: bool = False


MACROS = {
    "JMP": Macro(1, ("BRANCH ALWAYS, {0}",)),
    "JSET": Macro(2, ("BRANCH BIT_SET, {0}, {1}",)),
    "JCLR": Macro(2, ("BRANCH BIT_CLEAR, {0}, {1}",)),
    "STOP": Macro(0, ("BRANCH ALWAYS, -1",)),
    "TX_SETUP": Macro(4, ("CONFIG_GPIO {1}, OUTPUT, {2}, {3}",
                          "SET_GPIO_TX {0}, {1}")),
    "RX_SETUP": Macro(1, ("CONFIG_GPIO {0}, INPUT, PUSH_PULL, IMMEDIATE",
                          "SET_GPIO_RX {0}")),
    "SEND_BYTE": Macro(3, ("LOAD_TX {0}, {1}", "LOOP 8",
                           "SHIFT_OUT {0}", "DELAY {2}", "LOOP_END"), True),
    "RECV_BYTE": Macro(1, ("LOOP 8", "SHIFT_IN", "DELAY {0}", "LOOP_END"), True),
    "WAIT_HIGH": Macro(1, ("SAMPLE {0}", "BRANCH BIT_CLEAR, SAMPLED_GPIO, -2"), True),
    "WAIT_LOW": Macro(1, ("SAMPLE {0}", "BRANCH BIT_SET, SAMPLED_GPIO, -2"), True),
    "PULSE_HIGH": Macro(2, ("SET_GPIO {0}", "DELAY {1}", "CLR_GPIO {0}")),
    "PULSE_LOW": Macro(2, ("CLR_GPIO {0}", "DELAY {1}", "SET_GPIO {0}")),
}
