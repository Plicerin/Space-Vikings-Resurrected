#!/usr/bin/env python3
"""
Decoder for Space Vikings' real A2-3D1 3D-engine bytecode format, used
by SHIP # N (ship wireframe models, shown on the radar screen) and
PLANET # N (orbit/re-entry planet visuals). This is NOT the Applesoft-
style shape-table format that ENEMY/EXPL use -- see
tools/shape_table_decoder.py's docstring for that one, and
A2-3D1_ENGINE_ANALYSIS.md's "Resolved 2026-11-07" sections for the full
derivation of both formats, including the live MAME verification.

Confirmed 2026-11-07 by live memory tracing in MAME: the A2-3D1 bytecode
VM's own program-counter zero page ($9B/$9C) walks cleanly through
these exact files at runtime with zero decode errors, landing precisely
on the $7F terminator -- a far stronger structural match than the
shape-table format ever produced for these specific files (which also
parsed without erroring, which is why it went unquestioned at first).

Per-opcode instruction lengths, read directly from FUN_6140's actual
switch statement in the REA/Ghidra decompile
(rea-disassembly/LO-HI A2-3D1 (0x6000)/functions/0x6140.c), not just
the general summary in A2-3D1_ENGINE_ANALYSIS.md (which doesn't give
exact lengths for every opcode):

  0/1/2/3   7 bytes (opcode + signed 16-bit X,Y,Z vertex). 0 = plot-only
            (no line); 1/2/3 = also draw a line from the *previous*
            vertex to this one.
  4         2 bytes -- sets an internal flag (DAT_007c); appears once,
            right at the start, in every file this project has decoded.
  5         10 bytes -- rebuild the rotation matrix (3 angle bytes).
  6         5 bytes
  7,8,9     2 bytes each (self-modifying color/pattern selectors)
  10        3 bytes
  11        3 bytes -- explicit jump (reads a 16-bit address, sets PC)
  12        2 bytes
  13        3 bytes -- set output-vertex-list pointer
  14        5 bytes
  15        7 bytes -- load a secondary 6-byte rotation
  16, 17    1 byte each (no params)

Any opcode byte outside 0-17 is not a valid instruction -- the VM
treats it as a hard stop. Every real file this project has decoded
ends on exactly one such byte: $7F (127), always as the very last byte
of the file, with zero bytes left over.

Usage: python3 a2_3d1_model_decoder.py <input.bin> <output.json> [--skip-header N]

--skip-header defaults to 22, which is the live-confirmed start offset
for PLANET # 0 (the VM pointer was caught at exactly file-offset 22
live). SHIP # N files structurally only need the first 2 bytes skipped
(opcode 4's "set flag" instruction) -- pass --skip-header 2 for those.
Either way the right value is whichever makes the walk below reach EOF
with zero decode errors; this script reports clearly if it doesn't.
"""
import sys
import os
import json
import struct

OPLEN = {
    0: 7, 1: 7, 2: 7, 3: 7,
    4: 2, 5: 10, 6: 5, 7: 2, 8: 2, 9: 2,
    10: 3, 11: 3, 12: 2, 13: 3, 14: 5, 15: 7, 16: 1, 17: 1,
}


def decode(data: bytes, skip_header: int) -> dict:
    i = skip_header
    vertices = []  # list of {"op": int, "x": int, "y": int, "z": int}
    while i < len(data):
        op = data[i]
        if op > 17:
            return {
                "vertices": vertices,
                "status": "terminated",
                "terminator_offset": i,
                "terminator_byte": op,
                "clean": (op == 0x7F and i == len(data) - 1),
            }
        length = OPLEN[op]
        if i + length > len(data):
            return {
                "vertices": vertices,
                "status": "truncated",
                "offset": i,
                "clean": False,
            }
        if op in (0, 1, 2, 3):
            x, y, z = struct.unpack("<hhh", data[i + 1:i + 7])
            vertices.append({"op": op, "x": x, "y": y, "z": z})
        i += length
    return {"vertices": vertices, "status": "eof", "clean": True}


def to_line_segments(vertices: list) -> list:
    """Collapse the op stream into renderable segments: each entry is
    either a single point (op 0) or a line [x1,y1,z1,x2,y2,z2] (op 1/2/3
    connecting to the previous vertex)."""
    segments = []
    prev = None
    for v in vertices:
        if v["op"] == 0:
            segments.append({"type": "point", "x": v["x"], "y": v["y"], "z": v["z"]})
            prev = (v["x"], v["y"], v["z"])
        else:
            if prev is not None:
                segments.append({
                    "type": "line",
                    "x1": prev[0], "y1": prev[1], "z1": prev[2],
                    "x2": v["x"], "y2": v["y"], "z2": v["z"],
                })
            prev = (v["x"], v["y"], v["z"])
    return segments


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    in_path, out_path = sys.argv[1], sys.argv[2]
    skip_header = 22
    if "--skip-header" in sys.argv:
        skip_header = int(sys.argv[sys.argv.index("--skip-header") + 1])

    data = open(in_path, "rb").read()
    result = decode(data, skip_header)
    segments = to_line_segments(result["vertices"])
    n_points = sum(1 for s in segments if s["type"] == "point")
    n_lines = sum(1 for s in segments if s["type"] == "line")

    out = {
        "source_file": os.path.basename(in_path),
        "skip_header": skip_header,
        "status": result["status"],
        "clean_decode": result["clean"],
        "num_points": n_points,
        "num_lines": n_lines,
        "segments": segments,
    }
    with open(out_path, "w") as f:
        json.dump(out, f, indent=1)

    tag = "OK" if result["clean"] else "WARNING: not a clean decode"
    print(f"{in_path}: {n_points} points, {n_lines} lines -> {out_path} [{tag}]")


if __name__ == "__main__":
    main()
