#!/usr/bin/env python3
"""
Standalone Apple II shape-table decoder.

2026-11-07: rewritten twice in one session. The format isn't stock
Applesoft -- Space Vikings (subLOGIC, 1982, by Mitchell Robbins per the
manual's title page) uses its own custom shape-table encoding, close to
but not identical to Applesoft's.

Confirmed empirically, by decoding and rendering shapes until they
matched the real game's ship/planet art shown in the manual
(archive.org item Space_Vikings_manual_subLOGIC, page 7's cockpit-view
screenshot -- a swept wedge-shaped ship silhouette, and planets drawn as
a deliberately abstract scatter of short dash marks, not a circle):

  +00     number of shapes
  +01..   one 1-byte offset per shape (from table start) -- confirmed
          against all 25 PLANET/SHIP files: 1-byte offsets are 100%
          in-bounds; every 2-byte variant tried lands mostly past EOF.

Each shape is a byte stream ending at a $00 terminator (not three
"do nothing" vectors -- $00 is reserved as the terminator). Every other
byte packs three vectors:

  bits 0-2 (AAA): vector 1 -- bit 0 = plot flag, bits 1-2 = direction
  bits 3-5 (BBB): vector 2 -- same layout as AAA
  bits 6-7 (CC):  vector 3 -- only 2 bits, both direction: can never
                  plot, and a direction of 0 is a true no-op

Direction (2 bits), diagonal rather than cardinal: 0=NE, 1=SE, 2=SW,
3=NW (CC's 0 is a no-op instead of NE). The cursor advances one diagonal
step every vector regardless of the plot flag; when the flag is set, a
pixel is plotted at the position the cursor was at *before* that step.

This diverges from stock Applesoft (which uses 2-byte offsets, puts the
plot flag at bit 2, and moves in the 4 cardinal directions) on all three
points -- plausible for a commercial game's own hand-rolled, more
compact format rather than a direct use of Applesoft's shape tables.

Usage: python3 shape_table_decoder.py <input.bin> <output.json>
"""
import sys, os, json

DIRECTIONS = [(1, -1), (1, 1), (-1, 1), (-1, -1)]  # NE, SE, SW, NW

def _step(bits, is_c, x, y):
    d = (bits >> 1) & 0x03  # skip the plot-flag bit (bit 0) to get direction
    if is_c and d == 0:
        return x, y
    dx, dy = DIRECTIONS[d]
    return x + dx, y + dy

def process_shape_table(data):
    if len(data) < 2:
        return {"shapes": [], "error": "Data too short"}
    num_shapes = data[0] + 1
    offsets = [data[1 + i] for i in range(num_shapes) if 1 + i < len(data)]

    shapes = []
    for shape_idx, offset in enumerate(offsets):
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
            for bits, is_c in (
                (byte & 0x07, False),
                ((byte >> 3) & 0x07, False),
                ((byte >> 6) & 0x03, True),
            ):
                plots = bool(bits & 0x01) and not is_c
                if plots:
                    if not pen_down:
                        path_commands.append({"type": "move", "x": x, "y": -y})
                        pen_down = True
                    # Plots at the pre-step position -- append before _step.
                    path_commands.append({"type": "line", "x": x, "y": -y})
                else:
                    pen_down = False
                x, y = _step(bits, is_c, x, y)
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
    if "error" in result:
        print(f"{in_path}: {result['error']} -> {out_path}")
    else:
        print(f"{in_path}: {result['num_shapes']} shapes -> {out_path}")

if __name__ == "__main__":
    main()
