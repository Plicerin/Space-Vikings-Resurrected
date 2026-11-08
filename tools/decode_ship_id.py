#!/usr/bin/env python3
"""
Decoder for the `SHIP no N I.D..bas` overlays' inline DATA-point 2D
silhouette art — the *third* ship-rendering system in this game,
distinct from both the ENEMY Applesoft shape table (combat) and the
real A2-3D1 bytecode SHIP # N models (radar) — see
A2-3D1_ENGINE_ANALYSIS.md and tools/a2_3d1_model_decoder.py.

Algorithm, read directly from each file's own lines 1000-1050:

  1000 READ C
  1003 IF C = 77 THEN Y1 = <override>: GOTO 1000
  1005 IF C = 127 THEN 1060   (done)
  1010 READ X,Y
  1020 X = X1 - (X * 2):Y = Y1 - (Y * 2)
  1030 IF C = 1 THEN HPLOT X,Y        (pen up / move)
  1040 IF C = 2 THEN HPLOT TO X,Y     (pen down / line)
  1050 GOTO 1000

X1 is a fixed 80 in every file. Y1 starts at 40 and is overridden by
the 77 marker partway through each file's DATA to a per-file value
(80 for SHIP no 1, 100 for SHIP no 3, 90 for SHIP no 4) -- so each
file actually draws its silhouette *twice*, once at each Y1, which
this decoder preserves as-is (two sets of segments) rather than
collapsing them, since the two passes aren't always identical (SHIP
no 1's second pass is a slightly simplified subset of the first;
SHIP no 3's second pass has *more* detail than the first) and the
original genuinely draws both.

SHIP no 0 has no DATA statements at all -- "THERE IS NO STARSHIP IN
THIS SYSTEM" -- so it decodes to zero segments, correctly.

Usage: python3 decode_ship_id.py <input.bas> <output.json> <y1_override>

<y1_override> is the per-file constant from that file's own line 1003
(80 for SHIP no 1, 100 for SHIP no 3, 90 for SHIP no 4).
"""
import sys
import json
import re

X1 = 80
Y1_DEFAULT = 40


def extract_data_values(bas_text: str) -> list:
    values = []
    for line in bas_text.splitlines():
        m = re.match(r"\s*\d+\s+DATA\s+(.*)", line)
        if not m:
            continue
        for tok in m.group(1).split(","):
            tok = tok.strip()
            if tok == "":
                continue
            values.append(float(tok))
    return values


def decode(values: list, y1_override: int) -> list:
    """y1_override is the per-file constant from each BASIC source's own
    line 1003 (`IF C=77 THEN Y1=<override>`) -- a literal in the code,
    not a DATA-supplied value, so it's a parameter here, not read from
    `values`."""
    segments = []
    y1 = Y1_DEFAULT
    i = 0
    while i < len(values):
        c = int(values[i])
        i += 1
        if c == 77:
            y1 = y1_override
            continue
        if c == 127:
            break
        x_raw, y_raw = values[i], values[i + 1]
        i += 2
        x = X1 - (x_raw * 2)
        y = y1 - (y_raw * 2)
        if c == 1:
            segments.append({"type": "move", "x": x, "y": y})
        elif c == 2:
            segments.append({"type": "line", "x": x, "y": y})
    return segments


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    in_path, out_path, y1_override = sys.argv[1], sys.argv[2], int(sys.argv[3])
    with open(in_path, "r") as f:
        text = f.read()
    values = extract_data_values(text)
    segments = decode(values, y1_override)
    with open(out_path, "w") as f:
        json.dump({"source_file": in_path, "segments": segments}, f, indent=1)
    print(f"{in_path}: {len(values)} DATA values -> {len(segments)} segments -> {out_path}")


if __name__ == "__main__":
    main()
