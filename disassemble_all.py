#!/usr/bin/env python3
"""
Disassemble all assembly files in the Space Vikings game.

This script processes all .payload.bin files in the extracted directory
and attempts to disassemble them using known load addresses from BASIC files.
"""

import os
import subprocess
import glob

# Known load addresses for key files from BASIC BLOAD statements
# These come from analyzing START.bas and other files
LOAD_ADDRESSES = {
    # From START.bas: BLOAD PLANET FILE,A$954C,L$AF
    "PLANET FILE": 0x954C,
    "PLANET FILE-M": 0x954C,
    
    # From SPACE SIMULATOR ASSEMBLY analysis
    "SPACE SIMULATOR ASSEMBLY": 0x9023,
    
    # From MEM TRANSFER A analysis
    "MEM TRANSFER A": 0x9400,
    
    # From SOUND GEN analysis  
    "SOUND GEN": 0x9276,
    
    # From LASER analysis
    "LASER": 0x92D1,
    
    # From EXPL analysis
    "EXPL": 0x9100,
    
    # From TRANLIT.OBJ0 analysis
    "TRANLIT.OBJ0": 0x9600,
    
    # Other files (educated guesses)
    "MEM DATA": 0x8E00,
    "DEBRIS": 0x8000,
    "HI-RES CHARACTER GENERATOR": 0x1000,  # Graphics typically load low
    "CHARACTER TABLE": 0x1000,
    
    # PLANET files are likely graphics data
    "PLANET no 0": 0x8000,
    "PLANET no 1": 0x8000,
    "PLANET no 2": 0x8000,
    "PLANET no 3": 0x8000,
    "PLANET no 4": 0x8000,
    "PLANET no 5": 0x8000,
    "PLANET no 6": 0x8000,
    "PLANET no 7": 0x8000,
    "PLANET no 8": 0x8000,
    "PLANET no 9": 0x8000,
    "PLANET no 10": 0x8000,
    "PLANET no 11": 0x8000,
    "PLANET no 12": 0x8000,
    "PLANET no 13": 0x8000,
    "PLANET no 14": 0x8000,
    "PLANET no 15": 0x8000,
    "PLANET no 16": 0x8000,
    "PLANET no 17": 0x8000,
    "PLANET no 18": 0x8000,
    "PLANET no 19": 0x8000,
    "PLANET no 20": 0x8000,
    
    # SHIP files are likely graphics
    "SHIP no 0": 0x8000,
    "SHIP no 1": 0x8000,
    "SHIP no 3": 0x8000,
    "SHIP no 4": 0x8000,
    
    # Other files
    "LO-HI A2-3D1": 0x8000,
    "ENEMY I.A24580.L68": 0xA000,
    "P_F": 0x8000,
    "P_F-M": 0x8000,
    "SHIP'S DATA-M": 0x8000,
}

def disassemble_file(filename, address):
    """Run disassembler.py on a file."""
    cmd = ["python", "disassembler.py", filename, f"0x{address:X}"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error disassembling {filename}: {e}\n{e.stderr}"

def main():
    extracted_dir = "extracted"
    
    # Create disassembly directory
    disasm_dir = os.path.join(extracted_dir, "disassembly")
    os.makedirs(disasm_dir, exist_ok=True)
    
    # Get all payload files
    payload_files = glob.glob(os.path.join(extracted_dir, "*.payload.bin"))
    
    print(f"Found {len(payload_files)} payload files")
    
    # Process each file
    for payload_file in payload_files:
        basename = os.path.basename(payload_file)
        # Remove .payload.bin extension
        name_key = basename.replace(".payload.bin", "")
        
        # Get address from LOAD_ADDRESSES
        address = LOAD_ADDRESSES.get(name_key)
        
        if address is None:
            # Try to find similar names
            for key in LOAD_ADDRESSES:
                if key in name_key or name_key in key:
                    address = LOAD_ADDRESSES[key]
                    print(f"Using address for {key} for {name_key}")
                    break
        
        if address is None:
            print(f"No address found for {name_key}, skipping")
            continue
        
        print(f"Disassembling {name_key} at ${address:04X}")
        
        # Disassemble
        disassembly = disassemble_file(payload_file, address)
        
        # Save output
        output_file = os.path.join(disasm_dir, f"{name_key}.disasm.txt")
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(disassembly)
        
        print(f"  Saved to {output_file}")

if __name__ == "__main__":
    main()