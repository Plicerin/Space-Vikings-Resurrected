#!/usr/bin/env python3
"""
Convert Apple II shape table format to modern JSON.
Apple II shape tables use a vector format with:
- Length byte
- Vectors where bit 7 = direction (0=draw, 1=move), bits 0-6 = distance
- Special $00 byte = end of shape
"""

import struct
import json
import os
from pathlib import Path

class AppleIIShapeConverter:
    def __init__(self):
        self.shapes = []
        self.raw_points = []
        
    def decode_shape_table(self, data):
        """Decode Apple II shape table format."""
        i = 0
        shape_id = 0
        
        while i < len(data):
            # Look for shape boundary indicators
            # Apple II shape tables often have $00 between shapes
            
            shape_start = i
            shape_points = []
            
            # Try to decode as Apple II vector format
            vectors = []
            while i < len(data):
                byte = data[i]
                
                if byte == 0x00:
                    # End of shape marker
                    i += 1
                    break
                    
                # Vector format: bit 7 = direction, bits 0-6 = distance
                direction = "draw" if (byte & 0x80) == 0 else "move"
                distance = byte & 0x7F
                
                vectors.append({
                    "byte": byte,
                    "hex": f"{byte:02X}",
                    "direction": direction,
                    "distance": distance,
                    "offset": i
                })
                i += 1
            
            if vectors:
                self.shapes.append({
                    "id": shape_id,
                    "start_offset": shape_start,
                    "vector_count": len(vectors),
                    "vectors": vectors,
                    "points": self._convert_vectors_to_points(vectors)
                })
                shape_id += 1
            else:
                i += 1
        
        return self.shapes
    
    def _convert_vectors_to_points(self, vectors):
        """Convert Apple II vectors to actual coordinates."""
        # Apple II hi-res screen: 140x192 pixels
        # Starting from center or origin
        
        points = []
        x, y = 70, 96  # Center of screen
        
        for vector in vectors:
            if vector["direction"] == "move":
                # Move without drawing - store as "move to" point
                points.append({
                    "x": x,
                    "y": y,
                    "type": "move",
                    "distance": vector["distance"]
                })
            else:
                # Draw line - for now just mark endpoint
                # In real Apple II, this would draw in one of 8 directions
                points.append({
                    "x": x,
                    "y": y,
                    "type": "draw",
                    "distance": vector["distance"]
                })
        
        return points
    
    def extract_raw_coordinates(self, data):
        """Extract all coordinate-like pairs."""
        points = []
        
        for i in range(0, len(data) - 1, 2):
            x = data[i]
            y = data[i + 1]
            
            # Only include plausible screen coordinates
            if x < 140 and y < 192:
                points.append({
                    "x": x,
                    "y": y,
                    "offset": i,
                    "hex_pair": f"{data[i]:02X}{data[i+1]:02X}"
                })
        
        self.raw_points = points
        return points
    
    def analyze_patterns(self, data):
        """Analyze patterns in the data."""
        patterns = {
            "zero_bytes": sum(1 for b in data if b == 0),
            "high_bytes": sum(1 for b in data if b >= 128),
            "low_bytes": sum(1 for b in data if b < 128),
            "coordinate_pairs": 0,
            "potential_vectors": 0
        }
        
        # Count coordinate-like pairs
        for i in range(0, len(data) - 1, 2):
            x = data[i]
            y = data[i + 1]
            if x < 140 and y < 192:
                patterns["coordinate_pairs"] += 1
        
        # Count potential Apple II vectors
        for byte in data:
            if byte != 0 and byte <= 0xFF:
                patterns["potential_vectors"] += 1
        
        return patterns

def convert_file_to_json(filepath, output_dir):
    """Convert a single graphics file to JSON."""
    with open(filepath, 'rb') as f:
        data = f.read()
    
    converter = AppleIIShapeConverter()
    
    # Analyze patterns
    patterns = converter.analyze_patterns(data)
    
    # Try both approaches
    apple_shapes = converter.decode_shape_table(data)
    raw_points = converter.extract_raw_coordinates(data)
    
    filename = os.path.basename(filepath)
    
    # Create modern representation
    modern_data = {
        "filename": filename,
        "original_size": len(data),
        "analysis": patterns,
        "interpretations": {
            "apple_shape_format": {
                "shape_count": len(apple_shapes),
                "shapes": apple_shapes[:5] if len(apple_shapes) > 5 else apple_shapes
            },
            "raw_coordinate_format": {
                "point_count": len(raw_points),
                "points": raw_points[:20] if len(raw_points) > 20 else raw_points
            }
        },
        "raw_hex": "".join(f"{b:02X}" for b in data[:100]) + ("..." if len(data) > 100 else "")
    }
    
    # Save to JSON
    json_filename = filename.replace('.payload.bin', '.json')
    output_path = output_dir / json_filename
    
    with open(output_path, 'w') as f:
        json.dump(modern_data, f, indent=2)
    
    return modern_data

def main():
    base_dir = Path(__file__).parent
    extracted_dir = base_dir / "extracted"
    modern_dir = base_dir / "modern" / "graphics_enhanced"
    
    modern_dir.mkdir(parents=True, exist_ok=True)
    
    # Process all PLANET and SHIP files
    graphics_files = []
    
    for pattern in ["PLANET no *.payload.bin", "SHIP no *.payload.bin"]:
        for filepath in extracted_dir.glob(pattern):
            graphics_files.append(filepath)
    
    print(f"Found {len(graphics_files)} graphics files")
    
    all_results = []
    
    for i, filepath in enumerate(graphics_files[:5]):  # Process first 5 for now
        print(f"Processing {i+1}/{len(graphics_files)}: {filepath.name}")
        
        try:
            result = convert_file_to_json(filepath, modern_dir)
            all_results.append({
                "file": filepath.name,
                "size": result["original_size"],
                "apple_shapes": result["interpretations"]["apple_shape_format"]["shape_count"],
                "raw_points": result["interpretations"]["raw_coordinate_format"]["point_count"],
                "zero_bytes": result["analysis"]["zero_bytes"]
            })
            
            print(f"  → Apple shapes: {result['interpretations']['apple_shape_format']['shape_count']}")
            print(f"  → Raw points: {result['interpretations']['raw_coordinate_format']['point_count']}")
            
        except Exception as e:
            print(f"  Error: {e}")
    
    print("\n" + "="*60)
    print("Conversion Summary:")
    print("-"*60)
    
    for result in all_results:
        print(f"{result['file']:25s} {result['size']:4d} bytes | "
              f"Shapes: {result['apple_shapes']:2d} | "
              f"Points: {result['raw_points']:3d} | "
              f"Zero bytes: {result['zero_bytes']:3d}")
    
    print(f"\nJSON files saved to: {modern_dir}")
    print("\nRecommendation for modern remake:")
    print("1. Use raw coordinate points for initial rendering")
    print("2. Manually trace/interpret shapes for better graphics")
    print("3. Consider recreating graphics from screenshots")

if __name__ == "__main__":
    main()