#!/usr/bin/env python3
"""
Disassemble all assembly binaries for Space Vikings
"""

import os
import sys

# Mapping of binary names to load addresses from START.bas
LOAD_ADDRESSES = {
    "LO-HI A2-3D1": 0x6000,
    "PLANET # 0": 0x7300,
    "DEBRIS": 0x7879,
    "ENEMY I.A24580.L68": 0x7FFF,
    "CHARACTER TABLE": 0x8800,
    "MEM DATA": 0x8BEC,
    "SPACE SIMULATOR ASSEMBLY": 0x9023,
    "SOUND GEN": 0x9276,
    "LASER": 0x92D1,
    "HI-RES CHARACTER GENERATOR": 0x9300,
    "MEM TRANSFER A": 0x9400,
    "SHIP'S DATA-M": 0x9506,
    "SHIP'S DATA": 0x9506,
    "PLANET FILE": 0x954C,
    "PLANET FILE-M": 0x954C,
    "TRANLIT.OBJ0": 0x9600,
    "P/F-M": 0x97E1,
    "P/F": 0x97E1,
}

def find_binary_files():
    """Find all binary files to disassemble"""
    extracted_dir = 'extracted'
    files_to_disassemble = []
    
    # Manual mapping for files that don't match exactly
    file_mapping = {
        "P_F.payload.bin": "P/F",
        "P_F-M.payload.bin": "P/F-M",
        "PLANET no 0.payload.bin": "PLANET # 0",
        "SHIP'S DATA-M.payload.bin": "SHIP'S DATA-M",
        "TRANLIT.OBJ0.payload.bin": "TRANLIT.OBJ0",
        "HI-RES CHARACTER GENERATOR.payload.bin": "HI-RES CHARACTER GENERATOR",
    }
    
    # Look for payload.bin files first
    for file in os.listdir(extracted_dir):
        if file.endswith('.payload.bin'):
            # Try to match with known names
            base_name = file.replace('.payload.bin', '')
            
            # Check manual mapping first
            if file in file_mapping:
                mapped_name = file_mapping[file]
                if mapped_name in LOAD_ADDRESSES:
                    files_to_disassemble.append((file, LOAD_ADDRESSES[mapped_name]))
                    continue
            
            # Try exact match first
            if base_name in LOAD_ADDRESSES:
                files_to_disassemble.append((file, LOAD_ADDRESSES[base_name]))
            else:
                # Try to find approximate match
                matched = False
                for key in LOAD_ADDRESSES:
                    # Normalize strings for comparison
                    normalized_key = key.lower().replace(' ', '').replace('.', '').replace('-', '').replace('#', '').replace('/', '')
                    normalized_base = base_name.lower().replace(' ', '').replace('.', '').replace('-', '').replace('#', '').replace('/', '')
                    
                    if normalized_key in normalized_base or normalized_base in normalized_key:
                        files_to_disassemble.append((file, LOAD_ADDRESSES[key]))
                        matched = True
                        break
                
                if not matched:
                    # Special handling for planet/ship files
                    if "PLANET no" in file:
                        files_to_disassemble.append((file, 0x7300))  # Same as PLANET # 0
                    elif "SHIP no" in file:
                        files_to_disassemble.append((file, 0x7879))  # DEBRIS address
                    elif file == "EXPL.payload.bin":
                        files_to_disassemble.append((file, 0x6000))  # Default
                    else:
                        files_to_disassemble.append((file, 0x6000))  # Default address
    
    return files_to_disassemble

def disassemble_file(filename, load_address):
    """Disassemble a single binary file"""
    print(f"\n=== Disassembling {filename} @ ${load_address:04X} ===")
    
    # Create safe path
    safe_path = os.path.join('extracted', filename)
    
    # Escape spaces in filename for command line
    if ' ' in safe_path:
        safe_path = f'"{safe_path}"'
    
    cmd = f'python tools\\disassemble_simple.py {safe_path} {load_address}'
    os.system(cmd)

def analyze_instruction_patterns(disassembly_text):
    """Analyze instruction patterns to guess function"""
    lines = disassembly_text.split('\n')
    
    # Count instruction types
    inst_counts = {}
    for line in lines:
        if ':' in line:
            # Extract instruction mnemonic
            parts = line.split(':')
            if len(parts) > 1:
                inst = parts[1].strip().split()[0] if parts[1].strip() else ''
                if inst:
                    inst_counts[inst] = inst_counts.get(inst, 0) + 1
    
    # Analyze patterns
    total_inst = sum(inst_counts.values())
    if total_inst == 0:
        return "Unknown"
    
    # Common patterns
    if 'RTS' in inst_counts and inst_counts['RTS'] > total_inst * 0.1:
        return "Subroutine(s)"
    
    if 'JSR' in inst_counts and inst_counts['JSR'] > 5:
        return "Main routine with subroutines"
    
    if 'LDA' in inst_counts and inst_counts['LDA'] > total_inst * 0.3:
        return "Data loading routine"
    
    if 'STA' in inst_counts and inst_counts['STA'] > total_inst * 0.3:
        return "Data storage routine"
    
    if 'CLC' in inst_counts and inst_counts['CLC'] > 0 and 'ADC' in inst_counts:
        return "Math/calculation routine"
    
    if 'BEQ' in inst_counts or 'BNE' in inst_counts or 'BCC' in inst_counts or 'BCS' in inst_counts:
        return "Control flow with branches"
    
    return "General code"

def main():
    print("Space Vikings Assembly Disassembler")
    print("===================================\n")
    
    files = find_binary_files()
    
    print(f"Found {len(files)} binary files to disassemble:")
    for filename, address in sorted(files, key=lambda x: x[1]):
        print(f"  {filename:30} @ ${address:04X}")
    
    print("\nDisassembling key files...")
    
    # Disassemble key components first
    key_files = [
        ("SPACE SIMULATOR ASSEMBLY.payload.bin", 0x9023),
        ("LO-HI A2-3D1.payload.bin", 0x6000),
        ("SOUND GEN.payload.bin", 0x9276),
        ("LASER.payload.bin", 0x92D1),
        ("MEM TRANSFER A.payload.bin", 0x9400),
        ("MEM DATA.payload.bin", 0x8BEC),
    ]
    
    for filename, address in key_files:
        disassemble_file(filename, address)
    
    print("\n=== Summary ===")
    print("Key assembly components disassembled:")
    print("1. SPACE SIMULATOR ASSEMBLY - Main game engine")
    print("2. LO-HI A2-3D1 - Large 5KB binary, likely core engine")
    print("3. SOUND GEN - Sound generation routines")
    print("4. LASER - Combat/sound effect")
    print("5. MEM TRANSFER A - Memory transfer routine")
    print("6. MEM DATA - Game data in memory")
    
    print("\n=== Next Steps ===")
    print("1. Look for CALL statements in BASIC files to see how assembly is invoked")
    print("2. Analyze the disassembled code for patterns")
    print("3. Map memory usage between BASIC and assembly")
    print("4. Understand the game's state machine")

if __name__ == "__main__":
    main()