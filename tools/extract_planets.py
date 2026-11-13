#!/usr/bin/env python3
"""
Extracts and decodes all 21 real `PLANET # N` files directly from the
disk image, using tools/dos33_catalog.py (ground-truth DOS 3.3 catalog
reader) + tools/a2_3d1_model_decoder.py (the real A2-3D1 bytecode
format these files use -- confirmed live in MAME, not the Applesoft
shape-table format; see A2-3D1_ENGINE_ANALYSIS.md's "Resolved
2026-11-07" sections).

`PLANET # 0` (loaded by ORBIT.bas for the deep-space orbital-insertion
view) decodes as a 195-point field with no connecting edges.
`PLANET # 1`-`# 20` (loaded by RE.bas, selected by PEEK(38209), for the
re-entry-toward-a-specific-world view) decode as real line-connected
terrain maps instead -- a genuinely different visual, not just a
same-format variant. Both use skip_header=22 (the live-confirmed start
offset for this family of files, found by catching the A2-3D1 VM's own
program-counter walking through PLANET # 0 live).

Usage: python3 extract_planets.py <disk.dsk> <output_dir>
"""
import sys
import os
import struct

sys.path.insert(0, os.path.dirname(__file__))
import dos33_catalog as cat
import a2_3d1_model_decoder as dec

SKIP_HEADER = 22


def extract_file_payload(data: bytes, entry: dict) -> bytes:
    raw = cat.file_bytes(data, entry)
    if len(raw) < 4:
        return b""
    length = struct.unpack("<H", raw[2:4])[0]
    return raw[4:4 + length]


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    disk_path, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    with open(disk_path, "rb") as f:
        data = f.read()
    vtoc = cat.parse_vtoc(cat.read_sector(data, 17, 0))
    entries = cat.walk_catalog(data, vtoc["catalog_track"], vtoc["catalog_sector"])
    by_name = {e["name"]: e for e in entries if not e["deleted"]}

    for n in range(21):
        name = f"PLANET # {n}"
        entry = by_name.get(name)
        if entry is None:
            print(f"{name}: NOT FOUND in catalog")
            continue
        payload = extract_file_payload(data, entry)
        result = dec.decode(payload, SKIP_HEADER)
        segments = dec.to_line_segments(result["vertices"])
        n_points = sum(1 for s in segments if s["type"] == "point")
        n_lines = sum(1 for s in segments if s["type"] == "line")
        out_path = os.path.join(out_dir, f"PLANET no {n}.json")
        import json
        with open(out_path, "w") as f:
            json.dump({
                "source_file": name,
                "skip_header": SKIP_HEADER,
                "status": result["status"],
                "clean_decode": result["clean"],
                "num_points": n_points,
                "num_lines": n_lines,
                "segments": segments,
            }, f, indent=1)
        tag = "OK" if result["clean"] else "WARNING: not a clean decode"
        print(f"{name}: {n_points} points, {n_lines} lines -> {out_path} [{tag}]")


if __name__ == "__main__":
    main()
