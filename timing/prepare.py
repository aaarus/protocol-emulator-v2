"""Create isolated synthesis inputs; never edit the source RTL."""
from pathlib import Path
import hashlib, json, re, os

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / 'rtl'
OUT = HERE / 'compat'
OUT.mkdir(exist_ok=True)
names = ['top', 'instruction_parser', 'control_unit', 'loop_handler',
         'delay_counter', 'shift_regs', 'status_register', 'branch_condition',
         'tick', 'gpio', 'mux', 'configuration_registers', 'pc',
         'crc_calculator', 'crc_address_decoder']
hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in SRC.glob('*.sv')}
(HERE / 'source_hashes.json').write_text(json.dumps(hashes, indent=2))
for name in names:
    s = (SRC / (name + '.sv')).read_text()
    s = re.sub(r'\bparameter int\b', 'parameter integer', s)
    if name == 'top':
        s = s.replace('inout  wire [3:0] gpio_pad', '''input wire [3:0] gpio_pad_in,
    output wire [3:0] gpio_pad_out, gpio_pad_oe,
    input wire imem_wr_en, estimate_smth,
    input wire [7:0] imem_wr_addr,
    input wire [19:0] imem_wr_data''')
        s = s.replace('.gpio_pad   (gpio_pad),', '.gpio_pad_in(gpio_pad_in), .gpio_pad_out(gpio_pad_out), .gpio_pad_oe(gpio_pad_oe),')
        s = s.replace('.pc_addr_out(pc_addr_out)', ".evnt(1'b0), .redirect_addr(1'b0), .pc_addr_out(pc_addr_out)")
        s = s.replace('configuration_registers u_configuration_registers(', 'configuration_registers u_configuration_registers(\n        .smth(estimate_smth),')
        s = s.replace('.addr(pc_addr_out[7:0]),', '.clk(clk), .wr_en(imem_wr_en), .wr_addr(imem_wr_addr), .wr_data(imem_wr_data), .addr(pc_addr_out[7:0]),')
        s, n = re.subn(r'\n\s*wire evnt;\s*event_handler u_event_handler\(.*?\);', '', s, flags=re.S)
        assert n == 1
    if name == 'pc':
        s = s.replace('wire [15:0] pc_data_in;', 'logic [15:0] pc_data_in;')
    if name == 'configuration_registers':
        s = s.replace('input tx_select,', 'input tx_select, input smth,')
    if name == 'gpio':
        s = s.replace('inout wire [NUM_GPIO-1:0]     gpio_pad,', '''input wire [NUM_GPIO-1:0] gpio_pad_in,
    output wire [NUM_GPIO-1:0] gpio_pad_out, gpio_pad_oe,''')
        s, n = re.subn(r'assign gpio_pad\[i\] =\s*gpio_oe\[i\]\s*\? \(open_drain_reg\[i\] \? 1\x27b0 : gpio_out_reg\[i\]\)\s*: 1\x27bz;', "assign gpio_pad_out[i] = open_drain_reg[i] ? 1'b0 : gpio_out_reg[i];\n            assign gpio_pad_oe[i] = gpio_oe[i];", s)
        assert n == 1
        s = s.replace('gpio_in = gpio_pad;', 'gpio_in = gpio_pad_in;')
        s = s.replace('for (int i = 0;', 'for (i = 0;').replace('i++)', 'i = i + 1)')
        s = s.replace('for (genvar i = 0;', 'genvar i; for (i = 0;')
        idx = [0]
        def block(m):
            idx[0] += 1
            return m[0] + f' : compat_block_{idx[0]}\n integer i;'
        s = re.sub(r'always_(?:comb|ff)\b[^\r\n]*?\bbegin', block, s)
    (OUT / (name + '.sv')).write_text(s)
(OUT / 'imem.sv').write_text('''// Area model: 256 x 20, synchronous word write, asynchronous read.
// No reset or initialization of memory bits; program must be loaded first.
module imem(input clk, wr_en, input [7:0] wr_addr, addr,
            input [19:0] wr_data, output [19:0] data_out);
    reg [19:0] mem [0:255];
    always @(posedge clk) if (wr_en) mem[wr_addr] <= wr_data;
    assign data_out = mem[addr];
endmodule
''')
lib = os.environ['LIBERTY']
(HERE / 'latch_map.v').write_text('''// Preserve the existing positive-level tick_enable latch.
module \\$_DLATCH_P_ (input E, D, output Q);
sg13cmos5l_dlhq_1 _TECHMAP_REPLACE_ (.GATE(E), .D(D), .Q(Q));
endmodule
''')
script = f'read_liberty -lib {lib}\n'
script += 'read_verilog -sv ' + ' '.join('compat/' + n + '.sv' for n in names + ['imem']) + '\n'
script += f'''hierarchy -check -top top
synth -top top
dfflibmap -liberty {lib}
abc -liberty {lib}
techmap -map latch_map.v
clean
check -assert
stat -liberty {lib}
write_json mapped.json
write_verilog -noattr mapped.v
'''
(HERE / 'synth.ys').write_text(script)
print('Prepared isolated area inputs in', HERE)
