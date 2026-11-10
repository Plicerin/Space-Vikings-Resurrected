#!/usr/bin/env python3
"""A small NMOS 6502 interpreter: the documented opcodes, binary mode only.

Written to run the game's own machine code (A2-3D1 at $6000) outside an
emulator, as an oracle for the readable ports in this directory. It is not
a system emulator: there is no ROM, no soft switches and no timing beyond a
cycle count. An undocumented opcode or a SED raises, so a run that leaves
the code this was written for stops instead of going wrong quietly.

    from sim6502 import CPU
    cpu = CPU()
    cpu.load(0x6000, data)
    cpu.call(0x6000)      # runs until the matching RTS
"""

IMP, ACC, IMM, ZP, ZPX, ZPY, ABS, ABX, ABY, IND, IZX, IZY, REL = range(13)

# opcode: (mnemonic, mode, cycles)
OPS = {}


def _op(name, *entries):
    for code, mode, cycles in entries:
        OPS[code] = (name, mode, cycles)


_op("ADC", (0x69, IMM, 2), (0x65, ZP, 3), (0x75, ZPX, 4), (0x6D, ABS, 4), (0x7D, ABX, 4), (0x79, ABY, 4),
    (0x61, IZX, 6), (0x71, IZY, 5))
_op("AND", (0x29, IMM, 2), (0x25, ZP, 3), (0x35, ZPX, 4), (0x2D, ABS, 4), (0x3D, ABX, 4), (0x39, ABY, 4),
    (0x21, IZX, 6), (0x31, IZY, 5))
_op("ASL", (0x0A, ACC, 2), (0x06, ZP, 5), (0x16, ZPX, 6), (0x0E, ABS, 6), (0x1E, ABX, 7))
_op("BCC", (0x90, REL, 2))
_op("BCS", (0xB0, REL, 2))
_op("BEQ", (0xF0, REL, 2))
_op("BIT", (0x24, ZP, 3), (0x2C, ABS, 4))
_op("BMI", (0x30, REL, 2))
_op("BNE", (0xD0, REL, 2))
_op("BPL", (0x10, REL, 2))
_op("BVC", (0x50, REL, 2))
_op("BVS", (0x70, REL, 2))
_op("CLC", (0x18, IMP, 2))
_op("CLD", (0xD8, IMP, 2))
_op("CLI", (0x58, IMP, 2))
_op("CLV", (0xB8, IMP, 2))
_op("CMP", (0xC9, IMM, 2), (0xC5, ZP, 3), (0xD5, ZPX, 4), (0xCD, ABS, 4), (0xDD, ABX, 4), (0xD9, ABY, 4),
    (0xC1, IZX, 6), (0xD1, IZY, 5))
_op("CPX", (0xE0, IMM, 2), (0xE4, ZP, 3), (0xEC, ABS, 4))
_op("CPY", (0xC0, IMM, 2), (0xC4, ZP, 3), (0xCC, ABS, 4))
_op("DEC", (0xC6, ZP, 5), (0xD6, ZPX, 6), (0xCE, ABS, 6), (0xDE, ABX, 7))
_op("DEX", (0xCA, IMP, 2))
_op("DEY", (0x88, IMP, 2))
_op("EOR", (0x49, IMM, 2), (0x45, ZP, 3), (0x55, ZPX, 4), (0x4D, ABS, 4), (0x5D, ABX, 4), (0x59, ABY, 4),
    (0x41, IZX, 6), (0x51, IZY, 5))
_op("INC", (0xE6, ZP, 5), (0xF6, ZPX, 6), (0xEE, ABS, 6), (0xFE, ABX, 7))
_op("INX", (0xE8, IMP, 2))
_op("INY", (0xC8, IMP, 2))
_op("JMP", (0x4C, ABS, 3), (0x6C, IND, 5))
_op("JSR", (0x20, ABS, 6))
_op("LDA", (0xA9, IMM, 2), (0xA5, ZP, 3), (0xB5, ZPX, 4), (0xAD, ABS, 4), (0xBD, ABX, 4), (0xB9, ABY, 4),
    (0xA1, IZX, 6), (0xB1, IZY, 5))
_op("LDX", (0xA2, IMM, 2), (0xA6, ZP, 3), (0xB6, ZPY, 4), (0xAE, ABS, 4), (0xBE, ABY, 4))
_op("LDY", (0xA0, IMM, 2), (0xA4, ZP, 3), (0xB4, ZPX, 4), (0xAC, ABS, 4), (0xBC, ABX, 4))
_op("LSR", (0x4A, ACC, 2), (0x46, ZP, 5), (0x56, ZPX, 6), (0x4E, ABS, 6), (0x5E, ABX, 7))
_op("NOP", (0xEA, IMP, 2))
_op("ORA", (0x09, IMM, 2), (0x05, ZP, 3), (0x15, ZPX, 4), (0x0D, ABS, 4), (0x1D, ABX, 4), (0x19, ABY, 4),
    (0x01, IZX, 6), (0x11, IZY, 5))
_op("PHA", (0x48, IMP, 3))
_op("PHP", (0x08, IMP, 3))
_op("PLA", (0x68, IMP, 4))
_op("PLP", (0x28, IMP, 4))
_op("ROL", (0x2A, ACC, 2), (0x26, ZP, 5), (0x36, ZPX, 6), (0x2E, ABS, 6), (0x3E, ABX, 7))
_op("ROR", (0x6A, ACC, 2), (0x66, ZP, 5), (0x76, ZPX, 6), (0x6E, ABS, 6), (0x7E, ABX, 7))
_op("RTS", (0x60, IMP, 6))
_op("SBC", (0xE9, IMM, 2), (0xE5, ZP, 3), (0xF5, ZPX, 4), (0xED, ABS, 4), (0xFD, ABX, 4), (0xF9, ABY, 4),
    (0xE1, IZX, 6), (0xF1, IZY, 5))
_op("SEC", (0x38, IMP, 2))
_op("SEI", (0x78, IMP, 2))
_op("STA", (0x85, ZP, 3), (0x95, ZPX, 4), (0x8D, ABS, 4), (0x9D, ABX, 5), (0x99, ABY, 5), (0x81, IZX, 6),
    (0x91, IZY, 6))
_op("STX", (0x86, ZP, 3), (0x96, ZPY, 4), (0x8E, ABS, 4))
_op("STY", (0x84, ZP, 3), (0x94, ZPX, 4), (0x8C, ABS, 4))
_op("TAX", (0xAA, IMP, 2))
_op("TAY", (0xA8, IMP, 2))
_op("TSX", (0xBA, IMP, 2))
_op("TXA", (0x8A, IMP, 2))
_op("TXS", (0x9A, IMP, 2))
_op("TYA", (0x98, IMP, 2))

BRANCH = {"BCC": ("c", 0), "BCS": ("c", 1), "BEQ": ("z", 1), "BNE": ("z", 0),
          "BMI": ("n", 1), "BPL": ("n", 0), "BVC": ("v", 0), "BVS": ("v", 1)}


class CPU:
    def __init__(self):
        self.mem = bytearray(0x10000)
        self.a = self.x = self.y = 0
        self.sp = 0xFF
        self.pc = 0
        self.c = self.z = self.n = self.v = 0
        self.cycles = 0
        self.writes = None  # set to a list to record (pc, address, value)

    def load(self, address, data):
        self.mem[address:address + len(data)] = data

    # ---- helpers
    def _nz(self, value):
        self.z = 1 if value == 0 else 0
        self.n = value >> 7
        return value

    def _push(self, value):
        self.mem[0x100 + self.sp] = value
        self.sp = (self.sp - 1) & 0xFF

    def _pull(self):
        self.sp = (self.sp + 1) & 0xFF
        return self.mem[0x100 + self.sp]

    def _status(self):
        return self.c | (self.z << 1) | (self.v << 6) | (self.n << 7) | 0x30

    def _adc(self, value):
        total = self.a + value + self.c
        self.v = 1 if (~(self.a ^ value) & (self.a ^ total) & 0x80) else 0
        self.c = 1 if total > 0xFF else 0
        self.a = self._nz(total & 0xFF)

    def _address(self, mode):
        mem = self.mem
        pc = self.pc
        if mode == ZP:
            self.pc = pc + 1
            return mem[pc]
        if mode == ZPX:
            self.pc = pc + 1
            return (mem[pc] + self.x) & 0xFF
        if mode == ZPY:
            self.pc = pc + 1
            return (mem[pc] + self.y) & 0xFF
        if mode == IZX:
            self.pc = pc + 1
            zp = (mem[pc] + self.x) & 0xFF
            return mem[zp] | (mem[(zp + 1) & 0xFF] << 8)
        if mode == IZY:
            self.pc = pc + 1
            zp = mem[pc]
            return ((mem[zp] | (mem[(zp + 1) & 0xFF] << 8)) + self.y) & 0xFFFF
        base = mem[pc] | (mem[pc + 1] << 8)
        self.pc = pc + 2
        if mode == ABS:
            return base
        if mode == ABX:
            return (base + self.x) & 0xFFFF
        if mode == ABY:
            return (base + self.y) & 0xFFFF
        raise ValueError(mode)

    def step(self):
        mem = self.mem
        at = self.pc
        code = mem[at]
        if code not in OPS:
            raise RuntimeError(f"opcode ${code:02X} at ${at:04X} is not a documented 6502 instruction")
        name, mode, cycles = OPS[code]
        self.pc = at + 1
        self.cycles += cycles

        if name in BRANCH:
            flag, want = BRANCH[name]
            offset = mem[self.pc]
            self.pc += 1
            if getattr(self, flag) == want:
                self.pc = (self.pc + (offset - 256 if offset >= 128 else offset)) & 0xFFFF
                self.cycles += 1
            return

        # operand
        address = None
        if mode == IMM:
            value = mem[self.pc]
            self.pc += 1
        elif mode == ACC:
            value = self.a
        elif mode == IMP:
            value = None
        elif mode == IND:
            pointer = mem[self.pc] | (mem[self.pc + 1] << 8)
            self.pc += 2
            address = mem[pointer] | (mem[(pointer & 0xFF00) | ((pointer + 1) & 0xFF)] << 8)
            value = None
        else:
            address = self._address(mode)
            value = mem[address] if name not in ("STA", "STX", "STY", "JMP", "JSR") else None

        def store(result):
            if mode == ACC:
                self.a = result
            else:
                mem[address] = result
                if self.writes is not None:
                    self.writes.append((at, address, result))

        if name == "LDA":
            self.a = self._nz(value)
        elif name == "LDX":
            self.x = self._nz(value)
        elif name == "LDY":
            self.y = self._nz(value)
        elif name == "STA":
            store(self.a)
        elif name == "STX":
            store(self.x)
        elif name == "STY":
            store(self.y)
        elif name == "ADC":
            self._adc(value)
        elif name == "SBC":
            self._adc(value ^ 0xFF)
        elif name == "AND":
            self.a = self._nz(self.a & value)
        elif name == "ORA":
            self.a = self._nz(self.a | value)
        elif name == "EOR":
            self.a = self._nz(self.a ^ value)
        elif name in ("CMP", "CPX", "CPY"):
            register = {"CMP": self.a, "CPX": self.x, "CPY": self.y}[name]
            self.c = 1 if register >= value else 0
            self._nz((register - value) & 0xFF)
        elif name == "BIT":
            self.z = 1 if (self.a & value) == 0 else 0
            self.n = value >> 7
            self.v = (value >> 6) & 1
        elif name == "ASL":
            self.c = value >> 7
            store(self._nz((value << 1) & 0xFF))
        elif name == "LSR":
            self.c = value & 1
            store(self._nz(value >> 1))
        elif name == "ROL":
            carry = self.c
            self.c = value >> 7
            store(self._nz(((value << 1) | carry) & 0xFF))
        elif name == "ROR":
            carry = self.c
            self.c = value & 1
            store(self._nz((value >> 1) | (carry << 7)))
        elif name == "INC":
            store(self._nz((value + 1) & 0xFF))
        elif name == "DEC":
            store(self._nz((value - 1) & 0xFF))
        elif name == "INX":
            self.x = self._nz((self.x + 1) & 0xFF)
        elif name == "INY":
            self.y = self._nz((self.y + 1) & 0xFF)
        elif name == "DEX":
            self.x = self._nz((self.x - 1) & 0xFF)
        elif name == "DEY":
            self.y = self._nz((self.y - 1) & 0xFF)
        elif name == "TAX":
            self.x = self._nz(self.a)
        elif name == "TAY":
            self.y = self._nz(self.a)
        elif name == "TXA":
            self.a = self._nz(self.x)
        elif name == "TYA":
            self.a = self._nz(self.y)
        elif name == "TSX":
            self.x = self._nz(self.sp)
        elif name == "TXS":
            self.sp = self.x
        elif name == "CLC":
            self.c = 0
        elif name == "SEC":
            self.c = 1
        elif name == "CLV":
            self.v = 0
        elif name in ("CLD", "CLI", "SEI", "NOP"):
            pass
        elif name == "PHA":
            self._push(self.a)
        elif name == "PLA":
            self.a = self._nz(self._pull())
        elif name == "PHP":
            self._push(self._status())
        elif name == "PLP":
            status = self._pull()
            self.c = status & 1
            self.z = (status >> 1) & 1
            self.v = (status >> 6) & 1
            self.n = status >> 7
        elif name == "JMP":
            self.pc = address
        elif name == "JSR":
            back = self.pc - 1
            self._push(back >> 8)
            self._push(back & 0xFF)
            self.pc = address
        elif name == "RTS":
            low = self._pull()
            self.pc = ((low | (self._pull() << 8)) + 1) & 0xFFFF
        else:
            raise RuntimeError(name)

    def call(self, address, a=None, x=None, y=None, limit=50_000_000):
        """JSR to address and run until it returns. Returns the cycles used."""
        if a is not None:
            self.a = a
        if x is not None:
            self.x = x
        if y is not None:
            self.y = y
        start = self.cycles
        depth = self.sp
        back = 0xFFFE  # a return address no code lives at
        self._push(back >> 8)
        self._push(back & 0xFF)
        self.pc = address
        steps = 0
        while not (self.pc == back + 1 and self.sp == depth):
            self.step()
            steps += 1
            if steps > limit:
                raise RuntimeError(f"no return from ${address:04X} after {limit} instructions (pc ${self.pc:04X})")
        return self.cycles - start
