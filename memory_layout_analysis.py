#!/usr/bin/env python3
"""
Memory Layout Analysis for Space Vikings
Extracts all memory addresses from BASIC and assembly files
Creates comprehensive memory map for modern remake
"""

import re
import json
import os
from pathlib import Path

def extract_basic_addresses(file_path):
    """Extract all POKE, PEEK, and variable assignments from BASIC file"""
    addresses = []
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Extract POKE statements
    poke_pattern = r'POKE\s+(\d+)\s*,\s*(\d+)'
    for match in re.finditer(poke_pattern, content):
        address = int(match.group(1))
        value = int(match.group(2))
        addresses.append({
            'type': 'POKE',
            'address': address,
            'hex_address': f"${address:04X}",
            'value': value,
            'context': content[match.start()-50:match.end()+50]
        })
    
    # Extract PEEK statements
    peek_pattern = r'PEEK\s*\((\d+)\)'
    for match in re.finditer(peek_pattern, content):
        address = int(match.group(1))
        addresses.append({
            'type': 'PEEK',
            'address': address,
            'hex_address': f"${address:04X}",
            'context': content[match.start()-50:match.end()+50]
        })
    
    # Extract variable assignments with memory addresses
    var_pattern = r'(\w+)\s*=\s*(\d+)(?:\s*:\s*)'
    for match in re.finditer(var_pattern, content):
        var_name = match.group(1)
        value = int(match.group(2))
        # Only track if value looks like a memory address (between 0 and 65535)
        if 0 <= value <= 65535:
            addresses.append({
                'type': 'VAR_ASSIGN',
                'variable': var_name,
                'address': value,
                'hex_address': f"${value:04X}",
                'context': content[match.start()-50:match.end()+50]
            })
    
    return addresses

def extract_assembly_addresses(file_path):
    """Extract memory addresses from disassembled 6502 assembly"""
    addresses = []
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Look for LDA, STA, LDX, STX, LDY, STY instructions with absolute addressing
    # Patterns like LDA $9506, STA $95FD, etc.
    mem_pattern = r'\b(LDA|STA|LDX|STX|LDY|STY|CMP|BIT)\s+\$([0-9A-F]{2,4})\b'
    for match in re.finditer(mem_pattern, content, re.IGNORECASE):
        opcode = match.group(1)
        hex_addr = match.group(2)
        address = int(hex_addr, 16)
        addresses.append({
            'type': f'ASM_{opcode}',
            'address': address,
            'hex_address': f"${address:04X}",
            'context': content[match.start()-50:match.end()+50]
        })
    
    # Look for JSR and JMP to addresses
    jsr_pattern = r'\b(JSR|JMP)\s+\$([0-9A-F]{2,4})\b'
    for match in re.finditer(jsr_pattern, content, re.IGNORECASE):
        opcode = match.group(1)
        hex_addr = match.group(2)
        address = int(hex_addr, 16)
        addresses.append({
            'type': f'ASM_{opcode}',
            'address': address,
            'hex_address': f"${address:04X}",
            'context': content[match.start()-50:match.end()+50]
        })
    
    return addresses

def analyze_all_files():
    """Analyze all BASIC and assembly files in the project"""
    base_dir = Path("C:\\Users\\vrock\\Documents\\Space Vikings Resurrected")
    results = []
    
    # Analyze all BASIC files
    basic_dir = base_dir / "detokenized"
    if basic_dir.exists():
        for basic_file in basic_dir.glob("*.bas"):
            print(f"Analyzing {basic_file.name}...")
            addresses = extract_basic_addresses(str(basic_file))
            for addr in addresses:
                addr['source_file'] = basic_file.name
                results.append(addr)
    
    # Analyze all disassembly files
    asm_dir = base_dir / "disassembly"
    if asm_dir.exists():
        for asm_file in asm_dir.glob("*.asm"):
            print(f"Analyzing {asm_file.name}...")
            addresses = extract_assembly_addresses(str(asm_file))
            for addr in addresses:
                addr['source_file'] = asm_file.name
                results.append(addr)
    
    return results

def categorize_addresses(addresses):
    """Categorize addresses by memory range and purpose"""
    categories = {
        'game_state': [],        # Game state variables
        'graphics': [],          # Graphics memory
        'sound': [],             # Sound system
        'io': [],                # Input/Output
        'system': [],            # System addresses
        'unknown': []            # Uncategorized
    }
    
    for addr in addresses:
        hex_addr = addr.get('hex_address', '')
        dec_addr = addr.get('address', 0)
        
        # Game state addresses (based on known patterns)
        if 0x9500 <= dec_addr <= 0x97FF:  # $9500-$97FF range
            categories['game_state'].append(addr)
        elif 0x8B00 <= dec_addr <= 0x8DFF:  # $8B00-$8DFF range (MEM TRANSFER)
            categories['game_state'].append(addr)
        elif 0x38100 <= dec_addr <= 0x38200:  # $38100-$38200 range
            categories['game_state'].append(addr)
        
        # Graphics addresses
        elif 0x7300 <= dec_addr <= 0x8000:  # Graphics loading range
            categories['graphics'].append(addr)
        elif dec_addr in [0x8800, 0x9300]:  # Character tables
            categories['graphics'].append(addr)
        
        # Sound addresses
        elif 0x9270 <= dec_addr <= 0x9280:  # SOUND GEN range
            categories['sound'].append(addr)
        elif 0x9100 <= dec_addr <= 0x9110:  # EXPL sound
            categories['sound'].append(addr)
        elif dec_addr == 0xC030:  # Apple II speaker
            categories['sound'].append(addr)
        
        # I/O addresses
        elif dec_addr in [0x95FD, 0x95FE]:  # Joystick
            categories['io'].append(addr)
        elif 0x9600 <= dec_addr <= 0x9700:  # I/O related
            categories['io'].append(addr)
        
        # System addresses
        elif dec_addr < 0x1000:  # Low memory
            categories['system'].append(addr)
        elif dec_addr in [0x54, 0x55, 0x972, 0x974]:  # BASIC system
            categories['system'].append(addr)
        
        else:
            categories['unknown'].append(addr)
    
    return categories

def generate_memory_map(addresses, categories):
    """Generate comprehensive memory map"""
    memory_map = {}
    
    # Group by address
    for addr in addresses:
        dec_addr = addr.get('address')
        if dec_addr not in memory_map:
            memory_map[dec_addr] = {
                'decimal': dec_addr,
                'hex': f"${dec_addr:04X}",
                'references': [],
                'operations': [],
                'sources': set()
            }
        
        # Add reference
        ref = {
            'type': addr.get('type'),
            'source_file': addr.get('source_file'),
            'context': addr.get('context', '')[:100]
        }
        memory_map[dec_addr]['references'].append(ref)
        memory_map[dec_addr]['operations'].append(addr.get('type'))
        memory_map[dec_addr]['sources'].add(addr.get('source_file'))
    
    # Convert sets to lists for JSON serialization
    for addr in memory_map.values():
        addr['sources'] = list(addr['sources'])
    
    return memory_map

def main():
    print("Starting comprehensive memory layout analysis...")
    
    # Analyze all files
    addresses = analyze_all_files()
    print(f"Found {len(addresses)} memory references")
    
    # Categorize addresses
    categories = categorize_addresses(addresses)
    
    # Generate memory map
    memory_map = generate_memory_map(addresses, categories)
    
    # Save results
    output_dir = Path("C:\\Users\\vrock\\Documents\\Space Vikings Resurrected\\analysis")
    output_dir.mkdir(exist_ok=True)
    
    # Save raw addresses
    with open(output_dir / 'memory_addresses_raw.json', 'w') as f:
        json.dump(addresses, f, indent=2)
    
    # Save categorized addresses
    with open(output_dir / 'memory_addresses_categorized.json', 'w') as f:
        # Convert for JSON serialization
        cat_json = {}
        for cat_name, addrs in categories.items():
            cat_json[cat_name] = addrs
        json.dump(cat_json, f, indent=2)
    
    # Save memory map
    with open(output_dir / 'memory_map.json', 'w') as f:
        json.dump(memory_map, f, indent=2)
    
    # Generate summary report
    with open(output_dir / 'memory_layout_summary.md', 'w') as f:
        f.write("# Space Vikings Memory Layout Summary\n\n")
        f.write(f"Total memory references found: {len(addresses)}\n\n")
        
        f.write("## Categories\n")
        for cat_name, addrs in categories.items():
            f.write(f"- **{cat_name}**: {len(addrs)} addresses\n")
        
        f.write("\n## Key Memory Regions\n")
        
        # Top referenced addresses
        sorted_addrs = sorted(memory_map.items(), key=lambda x: len(x[1]['references']), reverse=True)
        f.write("\n### Most Referenced Addresses\n")
        for addr, info in sorted_addrs[:20]:
            f.write(f"- **{info['hex']}** (decimal {addr}): {len(info['references'])} references\n")
            f.write(f"  Sources: {', '.join(info['sources'])}\n")
            f.write(f"  Operations: {', '.join(set(info['operations']))}\n")
        
        # Known game state addresses
        f.write("\n### Known Game State Addresses\n")
        game_state_addrs = [a for a in addresses if 0x9500 <= a.get('address', 0) <= 0x97FF]
        for addr in sorted(set([a['address'] for a in game_state_addrs]))[:30]:
            refs = [a for a in game_state_addrs if a['address'] == addr]
            hex_addr = f"${addr:04X}"
            f.write(f"- **{hex_addr}** (decimal {addr}): {len(refs)} references\n")
    
    print(f"Analysis complete. Results saved to {output_dir}")
    print(f"Key addresses found: {len(memory_map)} unique addresses")

if __name__ == "__main__":
    main()