#!/usr/bin/env python3
"""
Applesoft shape-table decoder (ENEMY I, the game's only shape table).

`ENEMY I.A24580.L68` is BLOADed at $7FFF (START.bas 180), selected with
`POKE 232,255: POKE 233,127` (STARSHIP SIMULATOR.bas 2) and drawn with
Applesoft's own DRAW / XDRAW, so it is a stock Applesoft shape table:

  +00       number of shapes (26)
  +01       unused
  +02..     one 16-bit little-endian offset per shape, from table start;
            shape N (1-based, the number BASIC passes to DRAW) is entry N-1

Each shape is a byte stream ended by a $00 byte.  A byte holds up to
three vectors, low bits first: bits 0-2, bits 3-5, bits 6-7.  In a
vector, bits 0-1 are the direction (0 up, 1 right, 2 down, 3 left) and
bit 2 says "plot the current point before moving".  The third vector
has no plot bit.  The ROM shifts the byte right three bits after each
vector and stops as soon as the rest is zero, so a trailing "move up
without plotting" is not executed.

`rasterise()` below is the ROM routine itself (DRAW1, $F601 in the
Apple II+ ROM, disassembled with tools/dis6502.py from a live MAME
memory dump), including ROT and SCALE:

  quadrant = rot >> 4
  dx = COS[rot & 15];  dy = COS[(rot & 15 ^ 15) + 1] + 1   (8 bit)
  for each vector:
      ex = ey = $80
      repeat SCALE times:
          ex += dx + 1;  on carry: plot-if-flag, step in (dir + quadrant)
          ey += dy;      on carry: plot-if-flag, step in (dir + quadrant + 1)

With ROT a multiple of 16 that is a plain 90-degree turn.  Anything in
between makes a vector step in two directions, so `ROT=25` (the missile
miss flash, STARSHIP SIMULATOR.bas 1100) turns every vector into a
diagonal step of the next quadrant.

Checked against the real screen 2026-11-10 (tools/mame/shapes_live.lua):
the gauge markers (13, 14), the star-chart stars (1, 5, 6) and cursor
(12) and the missile flip-book (3..8) all match this decode.

HISTORY: until 2026-11-10 this file decoded a made-up "custom subLOGIC
format" (1-byte offsets, plot flag in bit 0, diagonal moves).  It read
the high bytes of the 16-bit offsets as separate shapes, which is where
the documented "odd shapes detailed, even shapes blank" pattern came
from.  The earlier "confirmed live" note only showed that the bytes in
memory equal the file.  `EXPL` was run through it too; EXPL is 6502 code
(the sound routine), not shapes.  PLANET/SHIP files are A2-3D1 models
(tools/a2_3d1_model_decoder.py).

Usage: python3 shape_table_decoder.py <input.bin> <output.json>
       python3 shape_table_decoder.py --ascii <input.bin> [rot [scale]]
"""
import sys, os, json

COS = [0xFF, 0xFE, 0xFA, 0xF4, 0xEC, 0xE1, 0xD4, 0xC5,
       0xB4, 0xA1, 0x8D, 0x78, 0x61, 0x49, 0x31, 0x18, 0xFF]
DIRECTIONS = [(0, -1), (1, 0), (0, 1), (-1, 0)]  # up, right, down, left (screen y is down)


def shape_offsets(data):
    count = data[0]
    return [data[2 + 2 * i] | (data[3 + 2 * i] << 8) for i in range(count)]


def shape_bytes(data, offset):
    end = offset
    while end < len(data) and data[end] != 0:
        end += 1
    return data[offset:end]


def rasterise(stream, rot=0, scale=1):
    """Run the ROM's DRAW loop; return the plotted points in plot order
    (a point can repeat) relative to the DRAW ... AT position."""
    quadrant = (rot & 0xFF) >> 4
    frac = rot & 0x0F
    dx = COS[frac]
    dy = (COS[(frac ^ 0x0F) + 1] + 1) & 0xFF
    count = scale & 0xFF or 256  # SCALE 0 loops 256 times, like the ROM
    x = y = 0
    plotted = []
    for byte in stream:
        while True:
            plot = bool(byte & 4)
            ex = ey = 0x80
            for _ in range(count):
                ex += dx + 1
                if ex > 0xFF:
                    ex &= 0xFF
                    if plot:
                        plotted.append((x, y))
                    sx, sy = DIRECTIONS[(byte + quadrant) & 3]
                    x += sx; y += sy
                ey += dy
                if ey > 0xFF:
                    ey &= 0xFF
                    if plot:
                        plotted.append((x, y))
                    sx, sy = DIRECTIONS[(byte + quadrant + 1) & 3]
                    x += sx; y += sy
            byte >>= 3
            if byte == 0:
                break
    return plotted


def process_shape_table(data):
    if len(data) < 4:
        return {"shapes": [], "error": "Data too short"}
    offsets = shape_offsets(data)
    shapes = []
    for i, offset in enumerate(offsets):
        stream = shape_bytes(data, offset)
        pixels = sorted(set(rasterise(stream)))
        xs = [p[0] for p in pixels] or [0]
        ys = [p[1] for p in pixels] or [0]
        shapes.append({
            "id": i + 1,
            "offset": offset,
            "bytes": list(stream),
            "pixels": [list(p) for p in pixels],
            "bounding_box": {
                "min_x": min(xs), "max_x": max(xs),
                "min_y": min(ys), "max_y": max(ys),
            },
        })
    return {"format": "applesoft-shape-table", "num_shapes": len(offsets), "shapes": shapes}


def ascii_dump(data, rot, scale):
    for i, offset in enumerate(shape_offsets(data)):
        pts = set(rasterise(shape_bytes(data, offset), rot, scale))
        print(f"shape {i + 1}  offset ${offset:03X}  {len(pts)} points")
        if not pts:
            continue
        xs = [p[0] for p in pts] + [0]; ys = [p[1] for p in pts] + [0]
        for y in range(min(ys), max(ys) + 1):
            row = ""
            for x in range(min(xs), max(xs) + 1):
                row += "#" if (x, y) in pts else ("+" if (x, y) == (0, 0) else ".")
            print("  " + row)


def main():
    if sys.argv[1] == "--ascii":
        with open(sys.argv[2], "rb") as f:
            data = f.read()
        rot = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        scale = int(sys.argv[4]) if len(sys.argv) > 4 else 1
        ascii_dump(data, rot, scale)
        return
    in_path, out_path = sys.argv[1], sys.argv[2]
    with open(in_path, "rb") as f:
        data = f.read()
    result = process_shape_table(data)
    result["filename"] = os.path.basename(in_path)
    result["file_size"] = len(data)
    with open(out_path, "w") as f:
        json.dump(result, f, separators=(",", ":"))
        f.write("\n")
    if "error" in result:
        print(f"{in_path}: {result['error']} -> {out_path}")
    else:
        print(f"{in_path}: {result['num_shapes']} shapes -> {out_path}")


if __name__ == "__main__":
    main()
