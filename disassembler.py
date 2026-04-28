#!/usr/bin/env python3
"""
Simple 6502 disassembler for Space Vikings Apple II binaries.
Reads binary files and disassembles starting at specified addresses.
"""

import sys
import struct
import os

# 6502 opcode definitions
OPCODES = {
    0x00: ("BRK", "imp"),
    0x01: ("ORA", "izx"),
    0x05: ("ORA", "zpg"),
    0x06: ("ASL", "zpg"),
    0x08: ("PHP", "imp"),
    0x09: ("ORA", "imm"),
    0x0A: ("ASL", "acc"),
    0x0D: ("ORA", "abs"),
    0x0E: ("ASL", "abs"),
    0x10: ("BPL", "rel"),
    0x11: ("ORA", "izy"),
    0x15: ("ORA", "zpx"),
    0x16: ("ASL", "zpx"),
    0x18: ("CLC", "imp"),
    0x19: ("ORA", "aby"),
    0x1D: ("ORA", "abx"),
    0x1E: ("ASL", "abx"),
    0x20: ("JSR", "abs"),
    0x21: ("AND", "izx"),
    0x24: ("BIT", "zpg"),
    0x25: ("AND", "zpg"),
    0x26: ("ROL", "zpg"),
    0x28: ("PLP", "imp"),
    0x29: ("AND", "imm"),
    0x2A: ("ROL", "acc"),
    0x2C: ("BIT", "abs"),
    0x2D: ("AND", "abs"),
    0x2E: ("ROL", "abs"),
    0x30: ("BMI", "rel"),
    0x31: ("AND", "izy"),
    0x35: ("AND", "zpx"),
    0x36: ("ROL", "zpx"),
    0x38: ("SEC", "imp"),
    0x39: ("AND", "aby"),
    0x3D: ("AND", "abx"),
    0x3E: ("ROL", "abx"),
    0x40: ("RTI", "imp"),
    0x41: ("EOR", "izx"),
    0x45: ("EOR", "zpg"),
    0x46: ("LSR", "zpg"),
    0x48: ("PHA", "imp"),
    0x49: ("EOR", "imm"),
    0x4A: ("LSR", "acc"),
    0x4C: ("JMP", "abs"),
    0x4D: ("EOR", "abs"),
    0x4E: ("LSR", "abs"),
    0x50: ("BVC", "rel"),
    0x51: ("EOR", "izy"),
    0x55: ("EOR", "zpx"),
    0x56: ("LSR", "zpx"),
    0x58: ("CLI", "imp"),
    0x59: ("EOR", "aby"),
    0x5D: ("EOR", "abx"),
    0x5E: ("LSR", "abx"),
    0x60: ("RTS", "imp"),
    0x61: ("ADC", "izx"),
    0x65: ("ADC", "zpg"),
    0x66: ("ROR", "zpg"),
    0x68: ("PLA", "imp"),
    0x69: ("ADC", "imm"),
    0x6A: ("ROR", "acc"),
    0x6C: ("JMP", "ind"),
    0x6D: ("ADC", "abs"),
    0x6E: ("ROR", "abs"),
    0x70: ("BVS", "rel"),
    0x71: ("ADC", "izy"),
    0x75: ("ADC", "zpx"),
    0x76: ("ROR", "zpx"),
    0x78: ("SEI", "imp"),
    0x79: ("ADC", "aby"),
    0x7D: ("ADC", "abx"),
    0x7E: ("ROR", "abx"),
    0x81: ("STA", "izx"),
    0x84: ("STY", "zpg"),
    0x85: ("STA", "zpg"),
    0x86: ("STX", "zpg"),
    0x88: ("DEY", "imp"),
    0x8A: ("TXA", "imp"),
    0x8C: ("STY", "abs"),
    0x8D: ("STA", "abs"),
    0x8E: ("STX", "abs"),
    0x90: ("BCC", "rel"),
    0x91: ("STA", "izy"),
    0x94: ("STY", "zpx"),
    0x95: ("STA", "zpx"),
    0x96: ("STX", "zpy"),
    0x98: ("TYA", "imp"),
    0x99: ("STA", "aby"),
    0x9A: ("TXS", "imp"),
    0x9D: ("STA", "abx"),
    0xA0: ("LDY", "imm"),
    0xA1: ("LDA", "izx"),
    0xA2: ("LDX", "imm"),
    0xA4: ("LDY", "zpg"),
    0xA5: ("LDA", "zpg"),
    0xA6: ("LDX", "zpg"),
    0xA8: ("TAY", "imp"),
    0xA9: ("LDA", "imm"),
    0xAA: ("TAX", "imp"),
    0xAC: ("LDY", "abs"),
    0xAD: ("LDA", "abs"),
    0xAE: ("LDX", "abs"),
    0xB0: ("BCS", "rel"),
    0xB1: ("LDA", "izy"),
    0xB4: ("LDY", "zpx"),
    0xB5: ("LDA", "zpx"),
    0xB6: ("LDX", "zpy"),
    0xB8: ("CLV", "imp"),
    0xB9: ("LDA", "aby"),
    0xBA: ("TSX", "imp"),
    0xBC: ("LDY", "abx"),
    0xBD: ("LDA", "abx"),
    0xBE: ("LDX", "aby"),
    0xC0: ("CPY", "imm"),
    0xC1: ("CMP", "izx"),
    0xC4: ("CPY", "zpg"),
    0xC5: ("CMP", "zpg"),
    0xC6: ("DEC", "zpg"),
    0xC8: ("INY", "imp"),
    0xC9: ("CMP", "imm"),
    0xCA: ("DEX", "imp"),
    0xCC: ("CPY", "abs"),
    0xCD: ("CMP", "abs"),
    0xCE: ("DEC", "abs"),
    0xD0: ("BNE", "rel"),
    0xD1: ("CMP", "izy"),
    0xD5: ("CMP", "zpx"),
    0xD6: ("DEC", "zpx"),
    0xD8: ("CLD", "imp"),
    0xD9: ("CMP", "aby"),
    0xDD: ("CMP", "abx"),
    0xDE: ("DEC", "abx"),
    0xE0: ("CPX", "imm"),
    0xE1: ("SBC", "izx"),
    0xE4: ("CPX", "zpg"),
    0xE5: ("SBC", "zpg"),
    0xE6: ("INC", "zpg"),
    0xE8: ("INX", "imp"),
    0xE9: ("SBC", "imm"),
    0xEA: ("NOP", "imp"),
    0xEC: ("CPX", "abs"),
    0xED: ("SBC", "abs"),
    0xEE: ("INC", "abs"),
    0xF0: ("BEQ", "rel"),
    0xF1: ("SBC", "izy"),
    0xF5: ("SBC", "zpx"),
    0xF6: ("INC", "zpx"),
    0xF8: ("SED", "imp"),
    0xF9: ("SBC", "aby"),
    0xFD: ("SBC", "abx"),
    0xFE: ("INC", "abx"),
}

def format_address(addr):
    """Format address as hex with $ prefix for 6502 convention."""
    return f"${addr:04X}"

def disassemble_opcode(pc, opcode, byte1, byte2):
    """Disassemble one opcode and return instruction string and bytes consumed."""
    if opcode not in OPCODES:
        # Unknown opcode - output as data byte
        return f"???", 1, f".byte ${opcode:02X}"
    
    mnemonic, mode = OPCODES[opcode]
    
    if mode == "imp":      # implied
        return mnemonic, 1, mnemonic
    elif mode == "acc":    # accumulator
        return f"{mnemonic} A", 1, f"{mnemonic} A"
    elif mode == "imm":    # immediate
        return f"{mnemonic} #${byte1:02X}", 2, f"{mnemonic} #${byte1:02X}"
    elif mode == "zpg":    # zero page
        return f"{mnemonic} ${byte1:02X}", 2, f"{mnemonic} ${byte1:02X}"
    elif mode == "zpx":    # zero page,X
        return f"{mnemonic} ${byte1:02X},X", 2, f"{mnemonic} ${byte1:02X},X"
    elif mode == "zpy":    # zero page,Y
        return f"{mnemonic} ${byte1:02X},Y", 2, f"{mnemonic} ${byte1:02X},Y"
    elif mode == "abs":    # absolute
        addr = (byte2 << 8) | byte1
        return f"{mnemonic} ${addr:04X}", 3, f"{mnemonic} {format_address(addr)}"
    elif mode == "abx":    # absolute,X
        addr = (byte2 << 8) | byte1
        return f"{mnemonic} ${addr:04X},X", 3, f"{mnemonic} {format_address(addr)},X"
    elif mode == "aby":    # absolute,Y
        addr = (byte2 << 8) | byte1
        return f"{mnemonic} ${addr:04X},Y", 3, f"{mnemonic} {format_address(addr)},Y"
    elif mode == "ind":    # indirect
        addr = (byte2 << 8) | byte1
        return f"{mnemonic} (${addr:04X})", 3, f"{mnemonic} ({format_address(addr)})"
    elif mode == "izx":    # (indirect,X)
        return f"{mnemonic} (${byte1:02X},X)", 2, f"{mnemonic} (${byte1:02X},X)"
    elif mode == "izy":    # (indirect),Y
        return f"{mnemonic} (${byte1:02X}),Y", 2, f"{mnemonic} (${byte1:02X}),Y"
    elif mode == "rel":    # relative
        offset = byte1 if byte1 < 128 else byte1 - 256
        target = pc + 2 + offset
        return f"{mnemonic} ${target:04X}", 2, f"{mnemonic} {format_address(target)}"
    else:
        return mnemonic, 1, mnemonic

def disassemble_file(filename, start_addr=0x1000):
    """Disassemble binary file starting at specified address."""
    with open(filename, 'rb') as f:
        data = f.read()
    
    print(f"Disassembling {filename} ({len(data)} bytes) starting at {format_address(start_addr)}")
    print("=" * 60)
    
    pc = start_addr
    i = 0
    
    while i < len(data):
        # Get current instruction bytes
        opcode = data[i]
        byte1 = data[i+1] if i+1 < len(data) else 0
        byte2 = data[i+2] if i+2 < len(data) else 0
        
        # Disassemble
        mnemonic, length, full_inst = disassemble_opcode(pc, opcode, byte1, byte2)
        
        # Format bytes
        bytes_str = f"{opcode:02X}"
        if length >= 2:
            bytes_str += f" {byte1:02X}"
        if length >= 3:
            bytes_str += f" {byte2:02X}"
        
        # Pad bytes string
        bytes_str = bytes_str.ljust(8)
        
        print(f"{format_address(pc)}: {bytes_str}  {full_inst}")
        
        # Advance
        i += length
        pc += length
        
        # Limit output for testing
        if i > 256:
            print(f"... (truncated at 256 bytes)")
            break

def main():
    if len(sys.argv) < 2:
        print("Usage: python disassembler.py <filename> [start_address]")
        print("Example: python disassembler.py \"SPACE SIMULATOR ASSEMBLY.bin\" 0x9023")
        sys.exit(1)
    
    filename = sys.argv[1]
    start_addr = 0x1000  # default
    
    if len(sys.argv) > 2:
        start_addr = int(sys.argv[2], 16)
    
    if not os.path.exists(filename):
        print(f"File not found: {filename}")
        sys.exit(1)
    
    disassemble_file(filename, start_addr)

if __name__ == "__main__":
    main()