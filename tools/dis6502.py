#!/usr/bin/env python3
"""Plain linear 6502 disassembler (documented NMOS opcodes only).

tools/disassemble_simple.py gets instruction lengths wrong (it prints
`LDA $00` for A9 00 and splits three-byte instructions), and
tools/disassemble.py needs py65.  This one has no dependencies and marks
anything that is not a documented opcode as a data byte.

Usage: tools/dis6502.py <payload file> <load address hex> [from hex] [to hex]
       tools/dis6502.py --calls <payload file> <load address hex>

--calls lists every JSR/JMP/branch target and every absolute operand
that lands inside the file, i.e. the routine entry points and the
self-modified operand bytes.
"""
import sys

# mode -> (operand bytes, format)
MODES = {
    "imp": (0, ""), "acc": (0, "A"), "imm": (1, "#$%02X"), "zp": (1, "$%02X"),
    "zpx": (1, "$%02X,X"), "zpy": (1, "$%02X,Y"), "abs": (2, "$%04X"),
    "abx": (2, "$%04X,X"), "aby": (2, "$%04X,Y"), "ind": (2, "($%04X)"),
    "izx": (1, "($%02X,X)"), "izy": (1, "($%02X),Y"), "rel": (1, "$%04X"),
}

OPS = {}


def _add(name, **codes):
    for mode, code in codes.items():
        OPS[code] = (name, mode)


_add("ADC", imm=0x69, zp=0x65, zpx=0x75, abs=0x6D, abx=0x7D, aby=0x79, izx=0x61, izy=0x71)
_add("AND", imm=0x29, zp=0x25, zpx=0x35, abs=0x2D, abx=0x3D, aby=0x39, izx=0x21, izy=0x31)
_add("ASL", acc=0x0A, zp=0x06, zpx=0x16, abs=0x0E, abx=0x1E)
_add("BIT", zp=0x24, abs=0x2C)
_add("CMP", imm=0xC9, zp=0xC5, zpx=0xD5, abs=0xCD, abx=0xDD, aby=0xD9, izx=0xC1, izy=0xD1)
_add("CPX", imm=0xE0, zp=0xE4, abs=0xEC)
_add("CPY", imm=0xC0, zp=0xC4, abs=0xCC)
_add("DEC", zp=0xC6, zpx=0xD6, abs=0xCE, abx=0xDE)
_add("EOR", imm=0x49, zp=0x45, zpx=0x55, abs=0x4D, abx=0x5D, aby=0x59, izx=0x41, izy=0x51)
_add("INC", zp=0xE6, zpx=0xF6, abs=0xEE, abx=0xFE)
_add("JMP", abs=0x4C, ind=0x6C)
_add("JSR", abs=0x20)
_add("LDA", imm=0xA9, zp=0xA5, zpx=0xB5, abs=0xAD, abx=0xBD, aby=0xB9, izx=0xA1, izy=0xB1)
_add("LDX", imm=0xA2, zp=0xA6, zpy=0xB6, abs=0xAE, aby=0xBE)
_add("LDY", imm=0xA0, zp=0xA4, zpx=0xB4, abs=0xAC, abx=0xBC)
_add("LSR", acc=0x4A, zp=0x46, zpx=0x56, abs=0x4E, abx=0x5E)
_add("ORA", imm=0x09, zp=0x05, zpx=0x15, abs=0x0D, abx=0x1D, aby=0x19, izx=0x01, izy=0x11)
_add("ROL", acc=0x2A, zp=0x26, zpx=0x36, abs=0x2E, abx=0x3E)
_add("ROR", acc=0x6A, zp=0x66, zpx=0x76, abs=0x6E, abx=0x7E)
_add("SBC", imm=0xE9, zp=0xE5, zpx=0xF5, abs=0xED, abx=0xFD, aby=0xF9, izx=0xE1, izy=0xF1)
_add("STA", zp=0x85, zpx=0x95, abs=0x8D, abx=0x9D, aby=0x99, izx=0x81, izy=0x91)
_add("STX", zp=0x86, zpy=0x96, abs=0x8E)
_add("STY", zp=0x84, zpx=0x94, abs=0x8C)
for _name, _code in [("BPL", 0x10), ("BMI", 0x30), ("BVC", 0x50), ("BVS", 0x70),
                     ("BCC", 0x90), ("BCS", 0xB0), ("BNE", 0xD0), ("BEQ", 0xF0)]:
    OPS[_code] = (_name, "rel")
for _name, _code in [("BRK", 0x00), ("PHP", 0x08), ("CLC", 0x18), ("PLP", 0x28), ("SEC", 0x38),
                     ("RTI", 0x40), ("PHA", 0x48), ("CLI", 0x58), ("RTS", 0x60), ("PLA", 0x68),
                     ("SEI", 0x78), ("DEY", 0x88), ("TXA", 0x8A), ("TYA", 0x98), ("TXS", 0x9A),
                     ("TAY", 0xA8), ("TAX", 0xAA), ("CLV", 0xB8), ("TSX", 0xBA), ("INY", 0xC8),
                     ("DEX", 0xCA), ("CLD", 0xD8), ("INX", 0xE8), ("NOP", 0xEA), ("SED", 0xF8)]:
    OPS[_code] = (_name, "imp")
assert len(OPS) == 151


def decode(data, base, start=None, end=None):
    """Yield (addr, raw bytes, mnemonic, mode, operand value or None)."""
    pc = base if start is None else start
    end = base + len(data) if end is None else min(end, base + len(data))
    while pc < end:
        i = pc - base
        op = OPS.get(data[i])
        if op is None or i + MODES[op[1]][0] >= len(data) + (MODES[op[1]][0] == 0):
            yield pc, data[i:i + 1], ".byte", None, data[i]
            pc += 1
            continue
        name, mode = op
        n = MODES[mode][0]
        raw = data[i:i + 1 + n]
        if n == 0:
            val = None
        elif n == 1:
            val = raw[1]
            if mode == "rel":
                val = (pc + 2 + (val - 256 if val > 127 else val)) & 0xFFFF
        else:
            val = raw[1] | raw[2] << 8
        yield pc, raw, name, mode, val
        pc += 1 + n


def text(insn):
    pc, raw, name, mode, val = insn
    if mode is None:
        operand = "$%02X" % val
    elif val is None:
        operand = MODES[mode][1]
    else:
        operand = MODES[mode][1] % val
    return "%04X: %-9s %s %s" % (pc, " ".join("%02X" % b for b in raw), name, operand)


def calls(data, base):
    top = base + len(data)
    flow, operands = {}, {}
    for insn in decode(data, base):
        pc, raw, name, mode, val = insn
        if mode in ("abs", "abx", "aby", "ind", "rel") and base <= val < top:
            bucket = flow if name in ("JSR", "JMP") or mode == "rel" else operands
            bucket.setdefault(val, []).append("%04X %s" % (pc, name))
    return flow, operands


def main(argv):
    if len(argv) >= 3 and argv[0] == "--calls":
        with open(argv[1], "rb") as f:
            data = f.read()
        flow, operands = calls(data, int(argv[2], 16))
        print("Flow targets inside the file:")
        for t in sorted(flow):
            print("  $%04X  <- %s" % (t, ", ".join(flow[t])))
        print("Data operands inside the file (variables, tables, self-modified bytes):")
        for t in sorted(operands):
            print("  $%04X  <- %s" % (t, ", ".join(operands[t])))
        return 0
    if len(argv) < 2:
        print(__doc__)
        return 2
    with open(argv[0], "rb") as f:
        data = f.read()
    base = int(argv[1], 16)
    start = int(argv[2], 16) if len(argv) > 2 else None
    end = int(argv[3], 16) if len(argv) > 3 else None
    for insn in decode(data, base, start, end):
        print(text(insn))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
