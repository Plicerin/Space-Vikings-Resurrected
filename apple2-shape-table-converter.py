#!/usr/bin/env python3
"""
Apple II Shape Table Converter for Space Vikings
Converts Apple II binary shape tables to SVG/JSON format based on Apple II documentation.
Shape table format:
- First byte: Number of shapes (N-1)
- Next N bytes: Offsets to each shape's data
- Shape data: Bytes with bit layout:
  Bits 7-5: Direction (0-7)
  Bits 4-1: Step count (1-15)
  Bit 0: Pen status (1=move, 0=draw)
- Terminator: $00 byte
"""

import os
import json
import struct
import math
from pathlib import Path

# Apple II direction vectors (clockwise from 0=right)
DIRECTIONS = [
    (1, 0),    # 0: Right
    (1, -1),   # 1: Up-Right
    (0, -1),   # 2: Up
    (-1, -1),  # 3: Up-Left
    (-1, 0),   # 4: Left
    (-1, 1),   # 5: Down-Left
    (0, 1),    # 6: Down
    (1, 1),    # 7: Down-Right
]

def decode_shape_byte(byte):
    """Decode Apple II shape byte into direction, steps, and pen status."""
    direction = (byte >> 5) & 0b111  # Bits 7-5
    steps = (byte >> 1) & 0b1111     # Bits 4-1
    pen_up = byte & 0b1              # Bit 0
    
    # Step count is 1-15, with 0 meaning 16 steps (per Apple II docs)
    if steps == 0:
        steps = 16
    
    return direction, steps, pen_up

def process_shape_table(data, start_offset=0):
    """Process Apple II shape table from binary data."""
    if len(data) < 2:
        return {"shapes": [], "error": "Data too short"}
    
    # Read number of shapes (N-1)
    num_shapes_minus_one = data[0]
    num_shapes = num_shapes_minus_one + 1
    
    # Read shape offsets
    offsets = []
    for i in range(num_shapes):
        if 1 + i >= len(data):
            break
        offsets.append(data[1 + i])
    
    shapes = []
    
    for shape_idx in range(num_shapes):
        if shape_idx >= len(offsets):
            break
        
        offset = offsets[shape_idx]
        shape_start = offset
        
        # Process shape data
        shape_data = []
        x, y = 0, 0  # Relative coordinates
        points = [(0, 0)]  # Start at origin
        pen_down = False  # Track pen state
        path_commands = []
        
        i = shape_start
        while i < len(data):
            byte = data[i]
            i += 1
            
            if byte == 0x00:  # Terminator
                break
            
            direction, steps, pen_up = decode_shape_byte(byte)
            dx, dy = DIRECTIONS[direction]
            
            # Apple II coordinate system: y increases downward
            # We'll invert y for modern coordinate system (y increases upward)
            for step in range(steps):
                if not pen_up:  # pen_down (bit 0 = 0 means draw)
                    if not pen_down:
                        pen_down = True
                        path_commands.append({"type": "move", "x": x, "y": -y})
                    x += dx
                    y += dy
                    points.append((x, -y))
                    path_commands.append({"type": "line", "x": x, "y": -y})
                else:  # pen_up (bit 0 = 1 means move without drawing)
                    if pen_down:
                        pen_down = False
                        path_commands.append({"type": "move", "x": x, "y": -y})
                    x += dx
                    y += dy
                    points.append((x, -y))
        
        # Calculate bounding box
        if points:
            min_x = min(p[0] for p in points)
            max_x = max(p[0] for p in points)
            min_y = min(p[1] for p in points)
            max_y = max(p[1] for p in points)
            width = max_x - min_x
            height = max_y - min_y
        else:
            min_x = max_x = min_y = max_y = width = height = 0
        
        shapes.append({
            "id": shape_idx,
            "offset": shape_start,
            "points": points,
            "path_commands": path_commands,
            "bounding_box": {
                "min_x": min_x,
                "max_x": max_x,
                "min_y": min_y,
                "max_y": max_y,
                "width": width,
                "height": height
            },
            "raw_bytes": data[shape_start:i].hex()
        })
    
    return {
        "shapes": shapes,
        "num_shapes": num_shapes,
        "offsets": offsets
    }

def binary_to_shape_table(binary_path):
    """Convert binary file to shape table JSON."""
    with open(binary_path, 'rb') as f:
        data = f.read()
    
    # Try to detect if this is a valid shape table
    if len(data) < 2:
        return None
    
    result = process_shape_table(data)
    
    # Add metadata
    result["filename"] = os.path.basename(binary_path)
    result["file_size"] = len(data)
    result["hex_preview"] = data[:50].hex()
    
    return result

def create_svg_from_shape(shape, shape_id=None):
    """Create SVG path from shape data."""
    if not shape.get("points"):
        return ""
    
    # Scale factor for better visualization
    scale = 5
    offset_x = 50
    offset_y = 50
    
    svg_lines = []
    svg_lines.append(f'<g id="shape-{shape_id if shape_id else shape["id"]}">')
    
    # Draw path
    path_data = []
    for i, point in enumerate(shape["points"]):
        x = point[0] * scale + offset_x
        y = point[1] * scale + offset_y
        
        if i == 0:
            path_data.append(f"M {x} {y}")
        else:
            path_data.append(f"L {x} {y}")
    
    if path_data:
        svg_lines.append(f'<path d="{" ".join(path_data)}" stroke="black" fill="none" stroke-width="2"/>')
    
    # Draw origin marker
    origin_x = offset_x
    origin_y = offset_y
    svg_lines.append(f'<circle cx="{origin_x}" cy="{origin_y}" r="3" fill="red"/>')
    
    svg_lines.append('</g>')
    
    return "\n".join(svg_lines)

def convert_planet_file(planet_path, output_dir):
    """Convert a planet binary file to JSON and SVG."""
    print(f"Converting {planet_path}...")
    
    result = binary_to_shape_table(planet_path)
    if not result:
        print(f"  Failed to process {planet_path}")
        return None
    
    base_name = os.path.splitext(os.path.basename(planet_path))[0]
    
    # Save JSON
    json_path = os.path.join(output_dir, f"{base_name}.json")
    with open(json_path, 'w') as f:
        json.dump(result, f, indent=2)
    
    # Create SVG if we have shapes
    if result.get("shapes"):
        svg_path = os.path.join(output_dir, f"{base_name}.svg")
        svg_content = [
            '<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
            f'<svg width="400" height="400" viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg">',
            f'<title>{base_name} Shape Table</title>'
        ]
        
        for shape in result["shapes"]:
            svg_content.append(create_svg_from_shape(shape))
        
        svg_content.append('</svg>')
        
        with open(svg_path, 'w') as f:
            f.write("\n".join(svg_content))
        
        print(f"  Created {json_path} and {svg_path}")
        print(f"  Found {len(result['shapes'])} shapes")
    else:
        print(f"  Created {json_path} (no shapes found)")
    
    return result

def main():
    """Main conversion function."""
    base_dir = Path("C:/Users/vrock/Documents/Space Vikings Resurrected")
    extracted_dir = base_dir / "extracted"
    modern_dir = base_dir / "modern"
    
    # Create output directories
    shapes_json_dir = modern_dir / "shapes_json"
    shapes_svg_dir = modern_dir / "shapes_svg"
    shapes_json_dir.mkdir(parents=True, exist_ok=True)
    shapes_svg_dir.mkdir(parents=True, exist_ok=True)
    
    # Process PLANET files
    planet_files = [
        "PLANET no 0.payload.bin",
        "PLANET no 1.payload.bin",
        "PLANET no 2.payload.bin",
        "PLANET no 3.payload.bin",
        "PLANET no 4.payload.bin",
        "PLANET no 5.payload.bin",
        "PLANET no 6.payload.bin",
        "PLANET no 7.payload.bin",
        "PLANET no 8.payload.bin",
        "PLANET no 9.payload.bin",
        "PLANET no 10.payload.bin",
        "PLANET no 11.payload.bin",
        "PLANET no 12.payload.bin",
        "PLANET no 13.payload.bin",
        "PLANET no 14.payload.bin",
        "PLANET no 15.payload.bin",
        "PLANET no 16.payload.bin",
        "PLANET no 17.payload.bin",
        "PLANET no 18.payload.bin",
        "PLANET no 19.payload.bin",
        "PLANET no 20.payload.bin",
        "PLANET FILE.payload.bin",
        "PLANET FILE-M.payload.bin"
    ]
    
    # Process SHIP files
    ship_files = [
        "SHIP no 0.payload.bin",
        "SHIP no 1.payload.bin",
        "SHIP no 3.payload.bin",
        "SHIP no 4.payload.bin"
    ]
    
    all_files = planet_files + ship_files
    
    results = []
    
    for filename in all_files:
        file_path = extracted_dir / filename
        if file_path.exists():
            result = convert_planet_file(str(file_path), str(shapes_json_dir))
            if result:
                results.append({
                    "file": filename,
                    "num_shapes": result.get("num_shapes", 0),
                    "file_size": result.get("file_size", 0)
                })
        else:
            print(f"File not found: {file_path}")
    
    # Create summary report
    summary = {
        "total_files_processed": len(results),
        "files": results,
        "shape_table_format": {
            "description": "Apple II Shape Table Format",
            "first_byte": "Number of shapes (N-1)",
            "offset_bytes": "N bytes of offsets to shape data",
            "shape_byte_format": "Bits 7-5: Direction (0-7), Bits 4-1: Steps (1-15), Bit 0: Pen (1=move, 0=draw)",
            "terminator": "$00 byte",
            "directions": {
                "0": "Right",
                "1": "Up-Right",
                "2": "Up",
                "3": "Up-Left",
                "4": "Left",
                "5": "Down-Left",
                "6": "Down",
                "7": "Down-Right"
            }
        }
    }
    
    summary_path = modern_dir / "shapes_summary.json"
    with open(summary_path, 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"\nSummary saved to {summary_path}")
    print(f"Total files processed: {len(results)}")

if __name__ == "__main__":
    main()