#!/usr/bin/env python3
"""
Memory Layout Analysis for Space Vikings Resurrected

This script analyzes memory addresses referenced in:
1. BASIC PEEK/POKE statements
2. Assembly LDA/STA/CMP instructions
3. Creates a comprehensive memory map
"""

import re
import os
import json
from collections import defaultdict

def extract_basic_memory_references(bas_file):
    """Extract memory addresses from BASIC files"""
    addresses = defaultdict(list)
    
    with open(bas_file, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    for line_num, line in enumerate(lines, 1):
        # Match PEEK/POKE statements with decimal addresses
        peek_pattern = r'PEEK\s*\(\s*([0-9\-]+)\s*\)'
        poke_pattern = r'POKE\s+([0-9\-]+)\s*,\s*([0-9\-]+|PEEK\s*\([^)]+\))'
        
        for match in re.finditer(peek_pattern, line):
            addr = int(match.group(1))
            if addr < 0:
                addr = 65536 + addr  # Handle negative addresses (Apple II memory mapping)
            addresses[addr].append({
                'file': os.path.basename(bas_file),
                'line': line_num,
                'type': 'peek',
                'context': line.strip()
            })
        
        for match in re.finditer(poke_pattern, line):
            addr = int(match.group(1))
            if addr < 0:
                addr = 65536 + addr  # Handle negative addresses
            value = match.group(2)
            addresses[addr].append({
                'file': os.path.basename(bas_file),
                'line': line_num,
                'type': 'poke',
                'value': value,
                'context': line.strip()
            })
    
    return addresses

def extract_assembly_memory_references(asm_file):
    """Extract memory addresses from assembly files"""
    addresses = defaultdict(list)
    
    with open(asm_file, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Match 6502 memory references in hex ($XXXX format)
    # Patterns: LDA $XXXX, STA $XXXX, CMP $XXXX, ADC $XXXX, SBC $XXXX
    hex_pattern = r'\$([0-9a-fA-F]{4})'
    hex_matches = re.findall(hex_pattern, content)
    
    for hex_addr in hex_matches:
        addr = int(hex_addr, 16)
        
        # Find the line containing this address
        lines = content.split('\n')
        for line_num, line in enumerate(lines, 1):
            if f'${hex_addr}' in line or f'${hex_addr.upper()}' in line or f'${hex_addr.lower()}' in line:
                addresses[addr].append({
                    'file': os.path.basename(asm_file),
                    'line': line_num,
                    'type': 'assembly',
                    'context': line.strip()
                })
                break
    
    return addresses

def categorize_addresses(all_addresses):
    """Categorize addresses by their range/purpose"""
    categories = {
        'game_state': [],        # $9400-$95FF range
        'graphics_memory': [],   # $8000-$8FFF range
        'sound_parameters': [],  # $9270-$927F range
        'protection': [],        # $95F7 (38391) protection check
        'joystick': [],          # $95FD-$95FE joystick values
        'file_loading': [],      # $954C, $97E1, $9506 file addresses
        'unknown': []
    }
    
    for addr in sorted(all_addresses.keys()):
        if 0x9400 <= addr <= 0x95FF:
            categories['game_state'].append(addr)
        elif 0x8000 <= addr <= 0x8FFF:
            categories['graphics_memory'].append(addr)
        elif 0x9270 <= addr <= 0x927F:
            categories['sound_parameters'].append(addr)
        elif addr == 0x95F7 or addr == 38391:  # Protection check
            categories['protection'].append(addr)
        elif addr == 0x95FD or addr == 38397 or addr == 0x95FE or addr == 38398:
            categories['joystick'].append(addr)
        elif addr in [0x954C, 0x97E1, 0x9506]:
            categories['file_loading'].append(addr)
        else:
            categories['unknown'].append(addr)
    
    return categories

def main():
    detokenized_dir = r"C:\Users\vrock\Documents\Space Vikings Resurrected\detokenized"
    disassembly_dir = r"C:\Users\vrock\Documents\Space Vikings Resurrected\disassembly"
    
    all_addresses = defaultdict(list)
    
    # Process BASIC files
    print("Processing BASIC files...")
    for bas_file in os.listdir(detokenized_dir):
        if bas_file.endswith('.bas'):
            bas_path = os.path.join(detokenized_dir, bas_file)
            addresses = extract_basic_memory_references(bas_path)
            for addr, refs in addresses.items():
                all_addresses[addr].extend(refs)
    
    # Process assembly files
    print("Processing assembly files...")
    for asm_file in os.listdir(disassembly_dir):
        if asm_file.endswith('.txt') or asm_file.endswith('.asm'):
            asm_path = os.path.join(disassembly_dir, asm_file)
            addresses = extract_assembly_memory_references(asm_path)
            for addr, refs in addresses.items():
                all_addresses[addr].extend(refs)
    
    # Sort addresses
    sorted_addresses = dict(sorted(all_addresses.items()))
    
    # Categorize addresses
    categories = categorize_addresses(sorted_addresses)
    
    # Create comprehensive report
    report = {
        'summary': {
            'total_addresses': len(sorted_addresses),
            'total_references': sum(len(refs) for refs in sorted_addresses.values()),
            'categories': {cat: len(addrs) for cat, addrs in categories.items()}
        },
        'memory_map': {},
        'categories': categories,
        'detailed_references': sorted_addresses
    }
    
    # Add descriptions for known addresses
    known_descriptions = {
        0x95F7: "Copy protection check location - value 77 (ASCII 'M') indicates original disk",
        0x95FD: "Joystick X position (PDL(1)) stored by STARSHIP SIMULATOR.bas",
        0x95FE: "Joystick Y position (PDL(0)) stored by STARSHIP SIMULATOR.bas",
        38391: "Decimal equivalent of $95F7 - copy protection",
        38397: "Decimal equivalent of $95FD - joystick X",
        38398: "Decimal equivalent of $95FE - joystick Y",
        0x954C: "PLANET FILE loading address (175 bytes)",
        0x97E1: "P_F file loading address (320 bytes)",
        0x9506: "SHIP'S DATA loading address",
        0x9532: "Counter index in MEM TRANSFER A routine (up to 128 iterations)",
        0x9275: "Sound parameter in SOUND GEN routine",
        0x9274: "Sound parameter in SOUND GEN routine",
        0x952F: "Game state variable in SPACE SIMULATOR ASSEMBLY",
        0x952D: "Game state variable in TRANLIT.OBJ0",
        0x9517: "Game state variable in TRANLIT.OBJ0",
        0x9539: "Game state variable in TRANLIT.OBJ0",
        0x953A: "Game state variable in TRANLIT.OBJ0",
        0x9515: "Game state variable in TRANLIT.OBJ0",
        0x9514: "Game state variable in TRANLIT.OBJ0",
        0x8BEC: "Source table in MEM TRANSFER A (216 bytes)",
        0x8D7C: "Destination table in MEM TRANSFER A (216 bytes)",
        0x9400: "MEM TRANSFER A routine entry point",
        0x9434: "MEM TRANSFER A alternative entry point",
        -16300: "Apple II HGR page switching",
        -16384: "Apple II keyboard strobe",
        -16368: "Apple II keyboard clear"
    }
    
    # Build memory map with descriptions
    for addr in sorted_addresses:
        hex_addr = f"${addr:04X}" if addr >= 0 else f"-{-addr}"
        dec_addr = str(addr)
        
        description = known_descriptions.get(addr, "Unknown purpose")
        
        # Try to infer purpose from references
        refs = sorted_addresses[addr]
        basic_refs = [r for r in refs if r['type'] in ['peek', 'poke']]
        asm_refs = [r for r in refs if r['type'] == 'assembly']
        
        inferred = []
        if basic_refs:
            inferred.append(f"Referenced in {len(basic_refs)} BASIC file(s)")
        if asm_refs:
            inferred.append(f"Referenced in {len(asm_refs)} assembly file(s)")
        
        report['memory_map'][addr] = {
            'hex': hex_addr,
            'decimal': dec_addr,
            'description': description,
            'inferred_purpose': '; '.join(inferred),
            'reference_count': len(refs),
            'references': refs[:5]  # Limit to first 5 references
        }
    
    # Save report
    output_file = r"C:\Users\vrock\Documents\Space Vikings Resurrected\analysis\memory_layout.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, default=str)
    
    print(f"\nAnalysis complete!")
    print(f"Total addresses found: {len(sorted_addresses)}")
    print(f"Total references: {sum(len(refs) for refs in sorted_addresses.values())}")
    print(f"\nCategories:")
    for cat, addrs in categories.items():
        print(f"  {cat}: {len(addrs)} addresses")
    
    print(f"\nReport saved to: {output_file}")
    
    # Also generate a markdown summary
    generate_markdown_summary(report)

def generate_markdown_summary(report):
    """Generate a markdown summary of the memory layout"""
    md_file = r"C:\Users\vrock\Documents\Space Vikings Resurrected\analysis\MEMORY_LAYOUT.md"
    
    with open(md_file, 'w', encoding='utf-8') as f:
        f.write("# Space Vikings Resurrected - Memory Layout Analysis\n\n")
        f.write("## Summary\n\n")
        f.write(f"- **Total memory addresses referenced**: {report['summary']['total_addresses']}\n")
        f.write(f"- **Total references**: {report['summary']['total_references']}\n")
        f.write("\n## Categories\n\n")
        for cat, count in report['summary']['categories'].items():
            f.write(f"- **{cat}**: {count} addresses\n")
        
        f.write("\n## Key Memory Addresses\n\n")
        f.write("| Hex | Decimal | Description | References |\n")
        f.write("|-----|---------|-------------|------------|\n")
        
        # Sort by address and show most important ones first
        important_addrs = [addr for addr in report['memory_map'] 
                          if report['memory_map'][addr]['reference_count'] > 2]
        important_addrs.sort()
        
        for addr in important_addrs:
            info = report['memory_map'][addr]
            ref_count = info['reference_count']
            f.write(f"| {info['hex']} | {info['decimal']} | {info['description']} | {ref_count} |\n")
        
        f.write("\n## Detailed Breakdown\n\n")
        
        # Game state addresses ($9400-$95FF)
        f.write("### Game State Area ($9400-$95FF)\n\n")
        f.write("This area contains most game state variables and control flags.\n\n")
        
        game_state_addrs = [addr for addr in report['memory_map'] 
                           if 0x9400 <= addr <= 0x95FF]
        game_state_addrs.sort()
        
        for addr in game_state_addrs:
            info = report['memory_map'][addr]
            f.write(f"#### {info['hex']} ({info['decimal']})\n")
            f.write(f"- **Description**: {info['description']}\n")
            f.write(f"- **References**: {info['reference_count']}\n")
            if info['references']:
                f.write("- **Sample references**:\n")
                for ref in info['references'][:3]:
                    f.write(f"  - {ref['file']}:{ref['line']} ({ref['type']})\n")
            f.write("\n")
        
        f.write("\n## Appendix: All Addresses\n\n")
        f.write("| Hex | Decimal | Description | Reference Count |\n")
        f.write("|-----|---------|-------------|-----------------|\n")
        
        for addr in sorted(report['memory_map'].keys()):
            info = report['memory_map'][addr]
            f.write(f"| {info['hex']} | {info['decimal']} | {info['description']} | {info['reference_count']} |\n")
    
    print(f"Markdown summary saved to: {md_file}")

if __name__ == "__main__":
    main()