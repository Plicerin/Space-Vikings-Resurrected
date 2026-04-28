#!/usr/bin/env python3
"""
Analyze Space Vikings graphics files to understand the format.
These appear to be coordinate-based shape data for Apple II hi-res graphics.
"""

import struct
import json
import os
from pathlib import Path

def analyze_coordinate_patterns(data):
    """Analyze patterns in the data to understand coordinate system."""
    # Check if data consists primarily of coordinate pairs
    pairs = []
    for i in range(0, len(data) - 1, 2):
        x = data[i]
        y = data[i + 1]
        pairs.append((x, y))
    
    # Analyze typical coordinate ranges
    x_values = [x for x, _ in pairs]
    y_values = [y for _, y in pairs]
    
    x_range = (min(x_values) if x_values else 0, max(x_values) if x_values else 0)
    y_range = (min(y_values) if y_values else 0, max(y_values) if y_values else 0)
    
    # Check for common Apple II hi-res screen bounds (140x192)
    print(f"X range: {x_range[0]:3d} - {x_range[1]:3d} (Apple II hi-res: 0-139)")
    print(f"Y range: {y_range[0]:3d} - {y_range[1]:3d} (Apple II hi-res: 0-191)")
    
    # Count likely coordinate pairs (within screen bounds)
    valid_pairs = [(x, y) for x, y in pairs if x < 140 and y < 192]
    print(f"Likely coordinate pairs: {len(valid_pairs)}/{len(pairs)}")
    
    return pairs, x_range, y_range

def detect_shape_format(data):
    """Try to detect the shape table format."""
    # Apple II shape tables often have length byte followed by vectors
    # Each vector: bits 0-6 = length, bit 7 = direction (0=plot, 1=move)
    
    shapes = []
    i = 0
    
    while i < len(data):
        # Try to find shape boundaries
        # Look for patterns that might indicate shape headers
        
        # Option 1: Length byte followed by coordinate data
        if i < len(data):
            length = data[i]
            
            # Check if this looks like a reasonable shape length
            # (not too long, leaves room for remaining data)
            if 4 <= length < 100 and i + length < len(data):
                shape_data = data[i:i+length+1]
                
                # Analyze the data for coordinate-like patterns
                coord_pairs = []
                for j in range(1, len(shape_data), 2):
                    if j + 1 < len(shape_data):
                        x = shape_data[j]
                        y = shape_data[j + 1]
                        coord_pairs.append((x, y))
                
                shapes.append({
                    "start_offset": i,
                    "length": length,
                    "coord_count": len(coord_pairs),
                    "first_coords": coord_pairs[:5] if coord_pairs else []
                })
                
                i += length + 1
                continue
        
        i += 1
    
    return shapes

def convert_to_modern_format(data, filename):
    """Convert binary graphics data to modern JSON format."""
    # For now, extract all coordinate-like pairs
    points = []
    
    for i in range(0, len(data) - 1, 2):
        x = data[i]
        y = data[i + 1]
        
        # Only include points that look like screen coordinates
        if x < 150 and y < 200:  # Slightly generous bounds
            points.append({
                "x": x,
                "y": y,
                "raw_hex": f"{data[i]:02X}{data[i+1]:02X}",
                "offset": i
            })
    
    # Group points into potential shapes using proximity
    shapes = []
    current_shape = []
    
    for point in points:
        if not current_shape:
            current_shape.append(point)
        else:
            # Check distance from last point in current shape
            last_point = current_shape[-1]
            dx = abs(point["x"] - last_point["x"])
            dy = abs(point["y"] - last_point["y"])
            
            # If points are close, likely same shape
            if dx < 30 and dy < 30:
                current_shape.append(point)
            else:
                # Start new shape
                if len(current_shape) >= 3:  # Need at least 3 points for a shape
                    shapes.append({
                        "point_count": len(current_shape),
                        "bounds": {
                            "min_x": min(p["x"] for p in current_shape),
                            "max_x": max(p["x"] for p in current_shape),
                            "min_y": min(p["y"] for p in current_shape),
                            "max_y": max(p["y"] for p in current_shape)
                        },
                        "points": current_shape
                    })
                current_shape = [point]
    
    # Add last shape
    if len(current_shape) >= 3:
        shapes.append({
            "point_count": len(current_shape),
            "bounds": {
                "min_x": min(p["x"] for p in current_shape),
                "max_x": max(p["x"] for p in current_shape),
                "min_y": min(p["y"] for p in current_shape),
                "max_y": max(p["y"] for p in current_shape)
            },
            "points": current_shape
        })
    
    return {
        "filename": filename,
        "size_bytes": len(data),
        "analysis": {
            "total_points": len(points),
            "shape_count": len(shapes),
            "point_density": len(points) / len(data) if data else 0
        },
        "shapes": shapes,
        "all_points": points  # Keep for reference
    }

def process_file(filepath):
    """Process a single graphics file."""
    with open(filepath, 'rb') as f:
        data = f.read()
    
    filename = os.path.basename(filepath)
    print(f"\nAnalyzing {filename} ({len(data)} bytes)")
    
    # Try different analysis methods
    pairs, x_range, y_range = analyze_coordinate_patterns(data)
    
    # Try shape detection
    shapes = detect_shape_format(data)
    print(f"Detected {len(shapes)} potential shapes")
    
    # Convert to modern format
    modern_format = convert_to_modern_format(data, filename)
    
    return modern_format, x_range, y_range

def main():
    base_dir = Path(__file__).parent
    extracted_dir = base_dir / "extracted"
    
    # Look at a few sample files
    sample_files = [
        "PLANET no 0.payload.bin",
        "PLANET no 1.payload.bin", 
        "SHIP no 1.payload.bin",
        "SHIP no 4.payload.bin"
    ]
    
    all_results = []
    
    for filename in sample_files:
        filepath = extracted_dir / filename
        if filepath.exists():
            result, x_range, y_range = process_file(filepath)
            all_results.append({
                "filename": filename,
                "size": result["size_bytes"],
                "x_range": x_range,
                "y_range": y_range,
                "shapes": len(result["shapes"])
            })
    
    print("\n" + "="*60)
    print("Summary of graphics format:")
    print("-"*60)
    
    for result in all_results:
        print(f"{result['filename']:25s} {result['size']:4d} bytes | "
              f"X:{result['x_range'][0]:3d}-{result['x_range'][1]:3d} | "
              f"Y:{result['y_range'][0]:3d}-{result['y_range'][1]:3d} | "
              f"{result['shapes']:2d} shapes")
    
    print("\nBased on analysis:")
    print("• Files contain coordinate pairs (X,Y bytes)")
    print("• X values typically 0-139 (Apple II hi-res width)")
    print("• Y values typically 0-191 (Apple II hi-res height)")
    print("• Likely shape table format with length bytes")
    print("• Coordinates may represent polygon vertices")

if __name__ == "__main__":
    main()