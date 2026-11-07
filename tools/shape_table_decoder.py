#!/usr/bin/env python3
"""
Standalone Apple II shape-table decoder, written fresh (not a copy of the
project's own apple2-shape-table-converter.py, which hardcodes its own
file list and a Windows path in main() and ignores CLI args entirely --
run it on a new file and it silently reports "File not found" for its
own hardcoded list and processes nothing). Implements the same documented
format that script's decode_shape_byte()/process_shape_table() logic
uses, verified against its already-successful output for the PLANET/SHIP
files, and used to decode ENEMY I.A24580.L68 and EXPL (not covered by
the original script's hardcoded list) -- see COMBAT_VFX_ANALYSIS.md.

  byte 0: number of shapes minus 1
  next N bytes: one offset per shape (single byte, relative to table start)
  shape data: each byte = 3-bit direction (bits 7-5), 4-bit steps (bits 4-1,
    0 means 16), 1-bit pen status (bit 0: 1=move, 0=draw); $00 terminates.

Usage: python3 shape_table_decoder.py <input.bin> <output.json>
"""
import sys, os, json

DIRECTIONS = [
    (1, 0), (1, -1), (0, -1), (-1, -1),
    (-1, 0), (-1, 1), (0, 1), (1, 1),
]

def decode_shape_byte(b):
    direction = (b >> 5) & 0b111
    steps = (b >> 1) & 0b1111
    pen_up = b & 0b1
    if steps == 0:
        steps = 16
    return direction, steps, pen_up

def process_shape_table(data):
    if len(data) < 2:
        return {"shapes": [], "error": "Data too short"}
    num_shapes = data[0] + 1
    offsets = [data[1 + i] for i in range(num_shapes) if 1 + i < len(data)]
    shapes = []
    for shape_idx in range(len(offsets)):
        offset = offsets[shape_idx]
        x, y = 0, 0
        points = [(0, 0)]
        pen_down = False
        path_commands = []
        i = offset
        while i < len(data):
            byte = data[i]
            i += 1
            if byte == 0x00:
                break
            direction, steps, pen_up = decode_shape_byte(byte)
            dx, dy = DIRECTIONS[direction]
            for _ in range(steps):
                if not pen_up:
                    if not pen_down:
                        pen_down = True
                        path_commands.append({"type": "move", "x": x, "y": -y})
                    x += dx; y += dy
                    points.append((x, -y))
                    path_commands.append({"type": "line", "x": x, "y": -y})
                else:
                    if pen_down:
                        pen_down = False
                        path_commands.append({"type": "move", "x": x, "y": -y})
                    x += dx; y += dy
                    points.append((x, -y))
        xs = [p[0] for p in points]; ys = [p[1] for p in points]
        shapes.append({
            "id": shape_idx,
            "offset": offset,
            "points": points,
            "path_commands": path_commands,
            "bounding_box": {
                "min_x": min(xs), "max_x": max(xs),
                "min_y": min(ys), "max_y": max(ys),
                "width": max(xs) - min(xs), "height": max(ys) - min(ys),
            },
            "raw_bytes": data[offset:i].hex(),
        })
    return {"shapes": shapes, "num_shapes": num_shapes, "offsets": offsets}

def main():
    in_path = sys.argv[1]
    out_path = sys.argv[2]
    with open(in_path, "rb") as f:
        data = f.read()
    result = process_shape_table(data)
    result["filename"] = os.path.basename(in_path)
    result["file_size"] = len(data)
    result["hex_preview"] = data[:50].hex()
    with open(out_path, "w") as f:
        json.dump(result, f, indent=2)
    print(f"{in_path}: {result['num_shapes']} shapes -> {out_path}")

if __name__ == "__main__":
    main()
