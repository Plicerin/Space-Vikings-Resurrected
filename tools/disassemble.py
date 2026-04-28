#!/usr/bin/env python3
"""
Simple 6502 disassembler for Space Vikings .bin files
Uses py65 6502 module for disassembly
"""

import sys
import os
from py65.devices.mpu6502 import MPU

def disassemble_file(filename, load_address=None):
    """Disassemble a .bin file"""
    print(f"Disassembling: {filename}")
    
    # Read the file
    with open(filename, 'rb') as f:
        data = f.read()
    
    print(f"File size: {len(data)} bytes")
    
    # If load_address not provided, try to extract from BIN header
    if load_address is None and len(data) >= 4:
        # Apple II .bin format: 2-byte load address, 2-byte length
        load_lo = data[0]
        load_hi = data[1]
        load_addr = (load_hi << 8) | load_lo
        length_lo = data[2]
        length_hi = data[3]
        length = (length_hi << 8) | length_lo
        
        print(f"BIN header: load_addr=${load_addr:04X}, length={length}")
        
        # Skip header if present
        if len(data) == length + 4:
            data = data[4:]
            print(f"Skipping 4-byte header, payload size: {len(data)} bytes")
        else:
            print("Warning: File size doesn't match header length + 4")
    
    # Create 6502 MPU
    mpu = MPU()
    
    # Set PC to load address if provided
    if load_address is not None:
        mpu.pc = load_address
    
    # Disassemble
    pc = mpu.pc
    max_bytes = len(data)
    byte_index = 0
    lines = []
    
    while byte_index < max_bytes:
        # Get opcode
        opcode = data[byte_index]
        byte_index += 1
        
        # Look up instruction length
        inst_length = mpu.disassemble_length(opcode)
        
        # Get instruction bytes
        inst_bytes = [opcode]
        for i in range(1, inst_length):
            if byte_index < max_bytes:
                inst_bytes.append(data[byte_index])
                byte_index += 1
            else:
                # Pad with zeros if we run out of data
                inst_bytes.append(0)
        
        # Disassemble
        if inst_length == 1:
            disasm = mpu.disassemble(pc, (opcode,))
        elif inst_length == 2:
            disasm = mpu.disassemble(pc, (opcode, inst_bytes[1]))
        else:  # inst_length == 3
            disasm = mpu.disassemble(pc, (opcode, inst_bytes[1], inst_bytes[2]))
        
        # Format the line
        hex_bytes = ' '.join(f'{b:02X}' for b in inst_bytes)
        lines.append(f"{pc:04X}: {hex_bytes:<9} {disasm}")
        
        pc += inst_length
    
    return lines

def main():
    if len(sys.argv) < 2:
        print("Usage: python disassemble.py <file.bin> [load_address_hex]")
        print("Example: python disassemble.py extracted/SPACE SIMULATOR ASSEMBLY.payload.bin 6000")
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

if __name__ == "__main__":
    main()