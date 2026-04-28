#!/usr/bin/env python3
"""
Simple 6502 disassembler for Space Vikings .bin files
Doesn't rely on py65 API that may not exist
"""

import sys
import os

def disassemble_6502(data, start_address=0):
    """Simple 6502 disassembler"""
    
    # 6502 instruction length lookup table
    # 0 = unknown/illegal, 1-3 = valid instruction length
    lengths = [1] * 256  # Start with all 1-byte
    # Initialize known lengths
    for i in range(256):
        opcode = i
        
        # Determine addressing mode based on opcode pattern
        # This is simplified but covers common instructions
        if opcode in [0x00, 0x18, 0x38, 0x58, 0x78, 0x88, 0x8A, 0x98, 
                      0x9A, 0xA8, 0xAA, 0xB8, 0xBA, 0xC8, 0xCA, 
                      0xD8, 0xE8, 0xEA, 0xF8, 0x40, 0x60]:
            lengths[i] = 1  # Implied/Accumulator
            
        elif opcode in [0x08, 0x28, 0x48, 0x68]:
            lengths[i] = 1  # Stack
            
        elif (opcode & 0x1F) == 0x10:  # Branch instructions
            lengths[i] = 2  # Relative
            
        elif (opcode & 0x03) == 0x01:  # (indirect,x) or (indirect),y
            lengths[i] = 2  # Zero page indexed indirect
            
        elif (opcode & 0x1F) == 0x00:  # Immediate
            lengths[i] = 2  # Immediate
            
        elif (opcode & 0x03) == 0x00 and (opcode & 0x1C) != 0x1C:  # Zero page
            lengths[i] = 2  # Zero page
            
        elif (opcode & 0x03) == 0x02:  # Absolute
            lengths[i] = 3  # Absolute
            
        elif (opcode & 0x1F) == 0x1C:  # Absolute indexed
            lengths[i] = 3  # Absolute indexed
            
        else:
            # Default to 1 byte for unknown
            lengths[i] = 1
    
    # Mnemonic table for common 6502 instructions
    mnemonics = {
        0x00: "BRK", 0x01: "ORA", 0x05: "ORA", 0x06: "ASL", 0x08: "PHP",
        0x09: "ORA", 0x0A: "ASL", 0x0D: "ORA", 0x0E: "ASL", 0x10: "BPL",
        0x11: "ORA", 0x15: "ORA", 0x16: "ASL", 0x18: "CLC", 0x19: "ORA",
        0x1D: "ORA", 0x1E: "ASL", 0x20: "JSR", 0x21: "AND", 0x24: "BIT",
        0x25: "AND", 0x26: "ROL", 0x28: "PLP", 0x29: "AND", 0x2A: "ROL",
        0x2C: "BIT", 0x2D: "AND", 0x2E: "ROL", 0x30: "BMI", 0x31: "AND",
        0x35: "AND", 0x36: "ROL", 0x38: "SEC", 0x39: "AND", 0x3D: "AND",
        0x3E: "ROL", 0x40: "RTI", 0x41: "EOR", 0x45: "EOR", 0x46: "LSR",
        0x48: "PHA", 0x49: "EOR", 0x4A: "LSR", 0x4C: "JMP", 0x4D: "EOR",
        0x4E: "LSR", 0x50: "BVC", 0x51: "EOR", 0x55: "EOR", 0x56: "LSR",
        0x58: "CLI", 0x59: "EOR", 0x5D: "EOR", 0x5E: "LSR", 0x60: "RTS",
        0x61: "ADC", 0x65: "ADC", 0x66: "ROR", 0x68: "PLA", 0x69: "ADC",
        0x6A: "ROR", 0x6C: "JMP", 0x6D: "ADC", 0x6E: "ROR", 0x70: "BVS",
        0x71: "ADC", 0x75: "ADC", 0x76: "ROR", 0x78: "SEI", 0x79: "ADC",
        0x7D: "ADC", 0x7E: "ROR", 0x81: "STA", 0x84: "STY", 0x85: "STA",
        0x86: "STX", 0x88: "DEY", 0x8A: "TXA", 0x8C: "STY", 0x8D: "STA",
        0x8E: "STX", 0x90: "BCC", 0x91: "STA", 0x94: "STY", 0x95: "STA",
        0x96: "STX", 0x98: "TYA", 0x99: "STA", 0x9A: "TXS", 0x9D: "STA",
        0xA0: "LDY", 0xA1: "LDA", 0xA2: "LDX", 0xA4: "LDY", 0xA5: "LDA",
        0xA6: "LDX", 0xA8: "TAY", 0xA9: "LDA", 0xAA: "TAX", 0xAC: "LDY",
        0xAD: "LDA", 0xAE: "LDX", 0xB0: "BCS", 0xB1: "LDA", 0xB4: "LDY",
        0xB5: "LDA", 0xB6: "LDX", 0xB8: "CLV", 0xB9: "LDA", 0xBA: "TSX",
        0xBC: "LDY", 0xBD: "LDA", 0xBE: "LDX", 0xC0: "CPY", 0xC1: "CMP",
        0xC4: "CPY", 0xC5: "CMP", 0xC6: "DEC", 0xC8: "INY", 0xC9: "CMP",
        0xCA: "DEX", 0xCC: "CPY", 0xCD: "CMP", 0xCE: "DEC", 0xD0: "BNE",
        0xD1: "CMP", 0xD5: "CMP", 0xD6: "DEC", 0xD8: "CLD", 0xD9: "CMP",
        0xDD: "CMP", 0xDE: "DEC", 0xE0: "CPX", 0xE1: "SBC", 0xE4: "CPX",
        0xE5: "SBC", 0xE6: "INC", 0xE8: "INX", 0xE9: "SBC", 0xEA: "NOP",
        0xEC: "CPX", 0xED: "SBC", 0xEE: "INC", 0xF0: "BEQ", 0xF1: "SBC",
        0xF5: "SBC", 0xF6: "INC", 0xF8: "SED", 0xF9: "SBC", 0xFD: "SBC",
        0xFE: "INC"
    }
    
    lines = []
    pc = start_address
    i = 0
    
    while i < len(data):
        opcode = data[i]
        length = lengths[opcode]
        
        # Get instruction bytes
        inst_bytes = [opcode]
        for j in range(1, min(length, len(data) - i)):
            inst_bytes.append(data[i + j])
        
        # Pad if needed
        while len(inst_bytes) < length:
            inst_bytes.append(0)
        
        # Get mnemonic
        mnemonic = mnemonics.get(opcode, f"${opcode:02X}")
        
        # Format operand
        if length == 1:
            operand = ""
        elif length == 2:
            operand = f" ${inst_bytes[1]:02X}"
        else:  # length == 3
            lo = inst_bytes[1]
            hi = inst_bytes[2]
            operand = f" ${hi:02X}{lo:02X}"
        
        # Format line
        hex_str = ' '.join(f'{b:02X}' for b in inst_bytes)
        lines.append(f"{pc:04X}: {hex_str:<9} {mnemonic}{operand}")
        
        pc += length
        i += length
    
    return lines

def disassemble_file(filename, load_address=None):
    """Disassemble a .bin file"""
    print(f"Disassembling: {filename}")
    
    with open(filename, 'rb') as f:
        data = f.read()
    
    print(f"File size: {len(data)} bytes")
    
    # If it's a .bin file with Apple II header
    if filename.endswith('.bin') and len(data) >= 4:
        load_lo = data[0]
        load_hi = data[1]
        load_addr = (load_hi << 8) | load_lo
        length_lo = data[2]
        length_hi = data[3]
        length = (length_hi << 8) | length_lo
        
        print(f"BIN header: load_addr=${load_addr:04X}, length={length}")
        
        if len(data) == length + 4:
            data = data[4:]
            print(f"Skipping 4-byte header, payload size: {len(data)} bytes")
            if load_address is None:
                load_address = load_addr
    
    if load_address is None:
        load_address = 0x6000  # Default for Space Vikings
    
    print(f"Load address: ${load_address:04X}")
    
    return disassemble_6502(data, load_address)

def main():
    if len(sys.argv) < 2:
        print("Usage: python disassemble_simple.py <file.bin> [load_address_hex]")
        print("Example: python disassemble_simple.py extracted/SPACE SIMULATOR ASSEMBLY.payload.bin 6000")
        return
    
    filename = sys.argv[1]
    load_address = None
    
    if len(sys.argv) >= 3:
        try:
            load_address = int(sys.argv[2], 16)
        except ValueError:
            print(f"Invalid load address: {sys.argv[2]}")
            return
    
    if not os.path.exists(filename):
        print(f"File not found: {filename}")
        return
    
    lines = disassemble_file(filename, load_address)
    
    # Print first 50 lines
    print("\nFirst 50 instructions:")
    for line in lines[:50]:
        print(line)
    
    # Print last 20 lines
    print("\nLast 20 instructions:")
    for line in lines[-20:]:
        print(line)
    
    # Count instructions
    print(f"\nTotal instructions disassembled: {len(lines)}")

if __name__ == "__main__":
    main()