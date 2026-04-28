#!/usr/bin/env python3
"""
Apple II hi-res graphics converter for Space Vikings.
Converts binary graphics data to structured JSON format suitable for modern rendering.
"""

import json
import struct
import os
from pathlib import Path

def parse_shape_data(data, start_addr=0x8000):
    """
    Parse Apple II shape data from binary format.
    Apple II hi-res graphics use 140x192 resolution with 2 bits per pixel.
    However, based on the disassembly, these files contain shape data tables.
    """
    # Based on disassembly patterns, try to extract coordinates or shape definitions
    # The files have varying sizes (520-1500 bytes), suggesting variable-length shape data
    
    shapes = []
    current_offset = 0
    
    while current_offset < len(data):
        # Try to extract potential shape header
        if current_offset + 4 > len(data):
            break
            
        # Check for pattern: length byte followed by coordinate data
        length = data[current_offset]
        if length == 0:
            current_offset += 1
            continue
            
        if current_offset + length + 1 > len(data):
            break
            
        shape_data = data[current_offset:current_offset + length + 1]
        
        # Extract coordinates (assume pairs of bytes)
        points = []
        for i in range(1, len(shape_data), 2):
            if i + 1 < len(shape_data):
                x = shape_data[i]
                y = shape_data[i + 1]
                points.append({"x": x, "y": y})
        
        shapes.append({
            "id": len(shapes),
            "length": length,
            "points": points,
            "raw_data": shape_data.hex()
        })
        
        current_offset += length + 1
    
    return shapes

def convert_planet_file(input_path, output_path, start_addr=0x8000):
    """Convert a planet graphics file to JSON format."""
    with open(input_path, 'rb') as f:
        data = f.read()
    
    print(f"Converting {input_path} ({len(data)} bytes)")
    
    # Analyze the data structure
    shapes = parse_shape_data(data, start_addr)
    
    result = {
        "filename": os.path.basename(input_path),
        "size_bytes": len(data),
        "load_address": f"${start_addr:04X}",
        "analysis": {
            "first_bytes": data[:16].hex(),
            "shape_count": len(shapes),
            "estimated_format": "Apple II hi-res shape table"
        },
        "shapes": shapes,
        "raw_hex": data.hex()  # Keep for reference
    }
    
    with open(output_path, 'w') as f:
        json.dump(result, f, indent=2)
    
    return result

def convert_ship_file(input_path, output_path, start_addr=0x8000):
    """Convert a ship graphics file to JSON format."""
    return convert_planet_file(input_path, output_path, start_addr)

def process_all_graphics():
    """Process all planet and ship graphics files."""
    base_dir = Path(__file__).parent
    extracted_dir = base_dir / "extracted"
    modern_dir = base_dir / "modern" / "graphics"
    
    modern_dir.mkdir(parents=True, exist_ok=True)
    
    all_results = []
    
    # Process planet files
    planet_files = list(extracted_dir.glob("PLANET no *.payload.bin"))
    for planet_file in sorted(planet_files):
        import re
        filename_str = str(planet_file.name)
        match = re.match(r"PLANET no (\d+)\.payload\.bin", filename_str)
        planet_num = int(match.group(1)) if match else 0
        
        output_file = modern_dir / f"planet_{planet_num}.json"
        result = convert_planet_file(str(planet_file), str(output_file))
        result["planet_number"] = planet_num
        all_results.append(result)
        
        print(f"Planet {planet_num}: {result['analysis']['shape_count']} shapes")
    
    # Process ship files
    ship_files = list(extracted_dir.glob("SHIP *.payload.bin"))
    for ship_file in sorted(ship_files):
        import re
        filename_str = str(ship_file.name)
        match = re.match(r"SHIP (\d+)\.payload\.bin", filename_str)
        ship_num = int(match.group(1)) if match else 0
        
        output_file = modern_dir / f"ship_{ship_num}.json"
        result = convert_ship_file(str(ship_file), str(output_file))
        result["ship_number"] = ship_num
        all_results.append(result)
        
        print(f"Ship {ship_num}: {result['analysis']['shape_count']} shapes")
    
    # Create index file
    index_file = modern_dir / "index.json"
    with open(index_file, 'w') as f:
        json.dump({
            "total_files": len(all_results),
            "planet_count": len(planet_files),
            "ship_count": len(ship_files),
            "files": [
                {
                    "name": r["filename"],
                    "size": r["size_bytes"],
                    "type": "planet" if "planet_number" in r else "ship",
                    "shapes": r["analysis"]["shape_count"]
                }
                for r in all_results
            ]
        }, f, indent=2)
    
    print(f"\nProcessed {len(all_results)} graphics files")
    print(f"Output saved to {modern_dir}")
    
    return all_results

if __name__ == "__main__":
    print("Space Vikings Graphics Converter")
    print("=" * 40)
    
    results = process_all_graphics()