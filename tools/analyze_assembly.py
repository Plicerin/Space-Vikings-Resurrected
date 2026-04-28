#!/usr/bin/env python3
"""
Analyze all assembly binaries in the Space Vikings project
Maps BLOAD addresses from BASIC files to corresponding .bin files
"""

import os
import sys
import re

def extract_bload_addresses(basic_file):
    """Extract BLOAD addresses from a BASIC file"""
    addresses = {}
    
    with open(basic_file, 'r') as f:
        content = f.read()
    
    # Find all BLOAD statements with addresses
    pattern = r'BLOAD\s+([^,]+),A\$([0-9A-F]{4})'
    matches = re.findall(pattern, content, re.IGNORECASE)
    
    for filename, address in matches:
        # Clean up filename
        filename = filename.strip()
        # Remove quotes if present
        if filename.startswith('"') and filename.endswith('"'):
            filename = filename[1:-1]
        addresses[filename] = int(address, 16)
    
    return addresses

def find_binary_file(filename):
    """Find the corresponding .bin or .payload.bin file"""
    # Try exact match first
    base_filename = filename.replace(' ', '_').replace('#', '').replace('.', '')
    
    possible_names = [
        f"{filename}.bin",
        f"{filename}.payload.bin",
        f"{base_filename}.bin",
        f"{base_filename}.payload.bin",
    ]
    
    # Also try variations with spaces replaced
    possible_names.append(filename.replace(' ', '_') + '.bin')
    possible_names.append(filename.replace(' ', '_') + '.payload.bin')
    
    # Check extracted directory
    extracted_dir = 'extracted'
    
    for name in possible_names:
        path = os.path.join(extracted_dir, name)
        if os.path.exists(path):
            return path
    
    # Try to find by partial match
    for file in os.listdir(extracted_dir):
        file_lower = file.lower()
        search_lower = filename.lower().replace(' ', '')
        
        if search_lower in file_lower:
            return os.path.join(extracted_dir, file)
    
    return None

def analyze_all_binaries():
    """Analyze all binary files mentioned in BASIC files"""
    print("=== Space Vikings Assembly Analysis ===\n")
    
    # Load addresses from all BASIC files
    detokenized_dir = 'detokenized'
    all_addresses = {}
    
    for bas_file in os.listdir(detokenized_dir):
        if bas_file.endswith('.bas'):
            path = os.path.join(detokenized_dir, bas_file)
            addresses = extract_bload_addresses(path)
            all_addresses.update(addresses)
    
    print(f"Found {len(all_addresses)} BLOAD references:")
    
    # Organize by load address
    by_address = {}
    for filename, address in all_addresses.items():
        if address not in by_address:
            by_address[address] = []
        by_address[address].append(filename)
    
    # Sort by address
    sorted_addresses = sorted(by_address.items())
    
    for address, filenames in sorted_addresses:
        print(f"\n${address:04X}:")
        for filename in filenames:
            print(f"  - {filename}")
            
            # Try to find binary file
            bin_path = find_binary_file(filename)
            if bin_path:
                print(f"    -> Found: {bin_path}")
                
                # Get file size
                size = os.path.getsize(bin_path)
                print(f"    Size: {size} bytes ({size/1024:.2f} KB)")
                
                # Check if it's a payload.bin (header stripped)
                if bin_path.endswith('.payload.bin'):
                    print(f"    Type: Payload (header stripped)")
                else:
                    print(f"    Type: Regular .bin (has 4-byte header)")
            else:
                print(f"    -> NOT FOUND in extracted/")
    
    # Also list all binary files we have
    print("\n=== All Binary Files in extracted/ ===")
    extracted_dir = 'extracted'
    bin_files = []
    payload_files = []
    
    for file in os.listdir(extracted_dir):
        if file.endswith('.bin'):
            bin_files.append(file)
        if file.endswith('.payload.bin'):
            payload_files.append(file)
    
    print(f"\nRegular .bin files ({len(bin_files)}):")
    for file in sorted(bin_files):
        size = os.path.getsize(os.path.join(extracted_dir, file))
        print(f"  {file:30} ({size:5} bytes)")
    
    print(f"\n.payload.bin files ({len(payload_files)}):")
    for file in sorted(payload_files):
        size = os.path.getsize(os.path.join(extracted_dir, file))
        print(f"  {file:30} ({size:5} bytes)")
    
    return all_addresses

def main():
    print("Space Vikings Assembly Code Analysis")
    print("====================================\n")
    
    addresses = analyze_all_binaries()
    
    # Generate a summary
    print("\n=== Summary ===")
    print("Key assembly components:")
    
    # Group by function
    key_components = {
        'Graphics': ['HI-RES CHARACTER GENERATOR', 'CHARACTER TABLE', 'PLANET FILE', 'PLANET # 0'],
        'Game Engine': ['SPACE SIMULATOR ASSEMBLY', 'LO-HI A2-3D1'],
        'Memory Management': ['MEM TRANSFER A', 'MEM DATA'],
        'Sound': ['SOUND GEN'],
        'Combat': ['LASER', 'ENEMY I.A24580.L68'],
        'Graphics Effects': ['TRANLIT.OBJ0'],
        'Ships': ['DEBRIS', 'SHIP #'],
        'Game Data': ['PLANET FILE-M', 'P/F-M', "SHIP'S DATA-M", 'PLANET FILE', 'P/F', "SHIP'S DATA"],
    }
    
    for category, names in key_components.items():
        found = []
        for name in names:
            if any(name.lower() in key.lower() for key in addresses.keys()):
                found.append(name)
        
        if found:
            print(f"\n{category}:")
            for name in found:
                for key, addr in addresses.items():
                    if name.lower() in key.lower():
                        bin_path = find_binary_file(key)
                        if bin_path:
                            size = os.path.getsize(bin_path)
                            print(f"  - {key:30} @ ${addr:04X} ({size:4} bytes)")
                        else:
                            print(f"  - {key:30} @ ${addr:04X} (file not found)")
    
    print("\n=== Next Steps ===")
    print("1. Disassemble each binary at its correct load address")
    print("2. Analyze what each routine does")
    print("3. Map calls between BASIC and assembly (using CALL statements)")
    print("4. Understand the game's architecture")

if __name__ == "__main__":
    main()