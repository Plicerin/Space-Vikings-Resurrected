#!/usr/bin/env python3
"""
Test the SPACE SIMULATOR ASSEMBLY code with the 6502 emulator.
"""

import struct
from cpu6502 import CPU6502

def load_binary(cpu, filename, address):
    """Load binary file into emulator memory"""
    with open(filename, 'rb') as f:
        data = f.read()
        for i, byte in enumerate(data):
            cpu.memory[address + i] = byte
        print(f"Loaded {len(data)} bytes from {filename} at ${address:04X}")
        return len(data)

def disassemble_range(cpu, start, end):
    """Simple disassembler for debugging"""
    print(f"\nDisassembly from ${start:04X} to ${end:04X}:")
    print("-" * 50)
    
    pc = start
    while pc < end:
        opcode = cpu.memory[pc]
        
        # Basic opcode decoding
        if opcode == 0xAD:  # LDA absolute
            addr = cpu.memory[pc + 1] | (cpu.memory[pc + 2] << 8)
            print(f"${pc:04X}: LDA ${addr:04X}  ; A = ${cpu.memory[addr]:02X}")
            pc += 3
        elif opcode == 0xC9:  # CMP immediate
            value = cpu.memory[pc + 1]
            print(f"${pc:04X}: CMP #${value:02X}  ; Compare A with ${value:02X}")
            pc += 2
        elif opcode == 0xB0:  # BCS
            offset = cpu.memory[pc + 1]
            target = pc + 2 + (offset if offset < 128 else offset - 256)
            print(f"${pc:04X}: BCS ${target:04X}  ; Branch if carry set")
            pc += 2
        elif opcode == 0x90:  # BCC
            offset = cpu.memory[pc + 1]
            target = pc + 2 + (offset if offset < 128 else offset - 256)
            print(f"${pc:04X}: BCC ${target:04X}  ; Branch if carry clear")
            pc += 2
        elif opcode == 0x20:  # JSR
            addr = cpu.memory[pc + 1] | (cpu.memory[pc + 2] << 8)
            print(f"${pc:04X}: JSR ${addr:04X}  ; Call subroutine")
            pc += 3
        elif opcode == 0x60:  # RTS
            print(f"${pc:04X}: RTS  ; Return from subroutine")
            pc += 1
        elif opcode == 0x4C:  # JMP absolute
            addr = cpu.memory[pc + 1] | (cpu.memory[pc + 2] << 8)
            print(f"${pc:04X}: JMP ${addr:04X}  ; Jump")
            pc += 3
        elif opcode == 0x18:  # CLC
            print(f"${pc:04X}: CLC  ; Clear carry flag")
            pc += 1
        elif opcode == 0xEA:  # NOP
            print(f"${pc:04X}: NOP  ; No operation")
            pc += 1
        else:
            print(f"${pc:04X}: ${opcode:02X}  ; Unknown opcode")
            pc += 1

def analyze_space_simulator(cpu):
    """Analyze the SPACE SIMULATOR ASSEMBLY logic"""
    print("\nAnalyzing SPACE SIMULATOR ASSEMBLY logic:")
    print("=" * 50)
    
    # Start at $9023 (entry point)
    cpu.PC = 0x9023
    
    # Disassemble first 100 bytes to understand the flow
    disassemble_range(cpu, 0x9023, 0x9100)
    
    # Check key memory locations mentioned in START.bas
    print("\nKey memory locations from START.bas:")
    print(f"  $95FD: Game state 1 = ${cpu.memory[0x95FD]:02X}")
    print(f"  $95FE: Game state 2 = ${cpu.memory[0x95FE]:02X}")
    print(f"  $7321: Coordinate X = ${cpu.memory[0x7321]:02X}")
    print(f"  $7322: Coordinate Y = ${cpu.memory[0x7322]:02X}")
    print(f"  $7323: Coordinate Z = ${cpu.memory[0x7323]:02X}")
    print(f"  $95F7: Protection   = ${cpu.memory[0x95F7]:02X} ('{chr(cpu.memory[0x95F7])}')")
    
    # Check what values trigger different branches
    print("\nBranch analysis at $9023:")
    
    # The code checks $95FD and branches based on its value
    # $9028: LDA $95FD
    # $902B: CMP #$AA
    # $902D: BCS $9063  ; If >= $AA, branch
    
    value = cpu.memory[0x95FD]
    print(f"  Current $95FD = ${value:02X} ({value} decimal)")
    
    if value >= 0xAA:
        print("  Would branch to $9063 (>= $AA)")
    elif value >= 0x5A:
        print("  Would branch to $905F ($5A <= value < $AA)")
    elif value >= 0x46:
        print("  Would branch to $9088 ($46 <= value < $5A)")
    elif value >= 0x32:
        print("  Would branch to $9088 ($32 <= value < $46)")
    elif value >= 0x1F:
        print("  Would branch to $9088 ($1F <= value < $32)")
    else:
        print("  Would fall through to $9036 (value < $1F)")
    
    # Test different values
    test_values = [0x10, 0x20, 0x40, 0x50, 0x80, 0xA0, 0xB0, 0xD0, 0xF0]
    print("\nBranch behavior for different $95FD values:")
    for val in test_values:
        cpu.memory[0x95FD] = val
        cpu.PC = 0x9023
        
        # Run first few instructions
        for _ in range(5):
            cpu.step()
            
        print(f"  ${val:02X}: PC ended at ${cpu.PC:04X}")

def test_memory_transfer(cpu):
    """Test MEM TRANSFER A routine"""
    print("\n\nTesting MEM TRANSFER A ($9400):")
    print("=" * 50)
    
    # Load MEM TRANSFER A binary
    mem_transfer_len = load_binary(cpu, "../extracted/MEM TRANSFER A.bin", 0x9400)
    
    # Disassemble entry points
    print("\nDisassembly of MEM TRANSFER A:")
    disassemble_range(cpu, 0x9400, 0x9420)
    disassemble_range(cpu, 0x9434, 0x9450)
    
    # According to disassembly, it copies between $8BEC and $8D7C tables
    print("\nMemory transfer buffers:")
    print(f"  Source: $8BEC-$8CF3 (216 bytes)")
    print(f"  Dest:   $8D7C-$8F83 (216 bytes)")
    print(f"  Counter: $9532")
    
    # Initialize test data
    for i in range(216):
        cpu.memory[0x8BEC + i] = i & 0xFF
        cpu.memory[0x8D7C + i] = 0xFF
    
    # Set up counter
    cpu.memory[0x9532] = 128  # Maximum iterations
    
    # Run the transfer routine from $9400
    cpu.PC = 0x9400
    print("\nRunning MEM TRANSFER A from $9400:")
    
    for i in range(50):
        brk = cpu.step()
        if brk or cpu.PC == 0x9400:  # Stop if BRK or back to start
            break
    
    # Check results
    print(f"  PC ended at ${cpu.PC:04X}")
    print(f"  First 10 bytes at $8D7C: {[cpu.memory[0x8D7C + i] for i in range(10)]}")
    
    # Test reverse direction ($9434)
    for i in range(216):
        cpu.memory[0x8BEC + i] = 0xAA
        cpu.memory[0x8D7C + i] = i & 0xFF
    
    cpu.PC = 0x9434
    print("\nRunning MEM TRANSFER A from $9434 (reverse):")
    
    for i in range(50):
        brk = cpu.step()
        if brk or cpu.PC == 0x9434:
            break
    
    print(f"  PC ended at ${cpu.PC:04X}")
    print(f"  First 10 bytes at $8BEC: {[cpu.memory[0x8BEC + i] for i in range(10)]}")

def test_sound_generation(cpu):
    """Test SOUND GEN routine"""
    print("\n\nTesting SOUND GEN ($9276):")
    print("=" * 50)
    
    # Load SOUND GEN binary
    load_binary(cpu, "../extracted/SOUND GEN.bin", 0x9276)
    
    # Disassemble
    print("\nDisassembly of SOUND GEN:")
    disassemble_range(cpu, 0x9276, 0x92A0)
    
    # Check speaker access
    speaker_access = []
    for addr in range(0x9276, 0x92D0):
        if cpu.memory[addr] == 0xAD and cpu.memory[addr + 1] == 0x30 and cpu.memory[addr + 2] == 0xC0:
            speaker_access.append(addr)
    
    print(f"\nSpeaker access at $C030 found at: {[f'${x:04X}' for x in speaker_access]}")
    
    # Check sound parameter memory ($9270-$9275)
    print("\nSound parameter memory ($9270-$9275):")
    for i in range(6):
        addr = 0x9270 + i
        print(f"  ${addr:04X}: ${cpu.memory[addr]:02X}")
    
    # The EXPL routine calls SOUND GEN
    print("\nEXPL ($9100) calls SOUND GEN:")
    load_binary(cpu, "../extracted/EXPL.bin", 0x9100)
    disassemble_range(cpu, 0x9100, 0x9120)
    
    # Look for JSR $9276
    for addr in range(0x9100, 0x9200):
        if cpu.memory[addr] == 0x20 and cpu.memory[addr + 1] == 0x76 and cpu.memory[addr + 2] == 0x92:
            print(f"  Found JSR $9276 at ${addr:04X}")

def test_coordinate_system(cpu):
    """Test coordinate manipulation"""
    print("\n\nTesting coordinate system:")
    print("=" * 50)
    
    # From START.bas line 190:
    # BV% = -7000: POKE ZI,LO%: POKE ZI+1,HI%
    # BV% = 700: POKE XI,LO%: POKE XI+1,HI%
    # BV% = 200: POKE YI,LO%: POKE YI+1,HI%
    
    # Where XI=29467, YI=29469, ZI=29471 (decimal)
    # Convert to hex: 29467 = $732B, 29469 = $732D, 29471 = $732F
    # But earlier analysis showed $7321-$7323 as coordinates
    
    print("Coordinate addresses from START.bas:")
    print("  Decimal -> Hex:")
    print(f"  29467 = ${29467:04X} (XI)")
    print(f"  29469 = ${29469:04X} (YI)")
    print(f"  29471 = ${29471:04X} (ZI)")
    
    # Check if $7321-$7323 are being used
    print("\nChecking $7321-$7323 usage in assembly:")
    
    # Search for LDA/STA operations on $7321-$7323
    search_range = range(0x9023, 0x9322)  # SPACE SIMULATOR ASSEMBLY range
    for addr in search_range:
        if cpu.memory[addr] in (0xAD, 0x8D):  # LDA/STA absolute
            target = cpu.memory[addr + 1] | (cpu.memory[addr + 2] << 8)
            if 0x7321 <= target <= 0x7323:
                op = "LDA" if cpu.memory[addr] == 0xAD else "STA"
                print(f"  ${addr:04X}: {op} ${target:04X}")

def main():
    """Main test function"""
    cpu = CPU6502()
    
    print("Space Vikings 6502 Emulator Tests")
    print("=" * 60)
    
    # Load key binaries
    print("\nLoading binaries:")
    load_binary(cpu, "../extracted/SPACE SIMULATOR ASSEMBLY.bin", 0x9023)
    load_binary(cpu, "../extracted/MEM TRANSFER A.bin", 0x9400)
    load_binary(cpu, "../extracted/SOUND GEN.bin", 0x9276)
    load_binary(cpu, "../extracted/EXPL.bin", 0x9100)
    load_binary(cpu, "../extracted/LASER.bin", 0x92D1)
    
    # Run analyses
    analyze_space_simulator(cpu)
    test_memory_transfer(cpu)
    test_sound_generation(cpu)
    test_coordinate_system(cpu)
    
    print("\n\nSummary:")
    print("=" * 60)
    print("1. SPACE SIMULATOR ASSEMBLY uses $95FD/$95FE for game state")
    print("2. Branches based on $95FD value: <$1F, $1F-$31, $32-$45, $46-$59, $5A-$A9, >=$AA")
    print("3. MEM TRANSFER A copies 216-byte blocks between $8BEC and $8D7C")
    print("4. Sound system: EXPL calls SOUND GEN which toggles speaker at $C030")
    print("5. Coordinates stored at $7321-$7323 (or $732B-$732F from BASIC)")
    print("6. Copy protection checks $95F7 for ASCII 'M' (77 decimal)")
    
    print("\nNext steps:")
    print("1. Trace through all state transitions")
    print("2. Map complete memory layout")
    print("3. Recreate game logic in Python")
    print("4. Build modern UI/interface")

if __name__ == "__main__":
    main()