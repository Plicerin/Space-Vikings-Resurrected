#!/usr/bin/env python3
"""Print the new-game galaxy data straight from the three master files
START.bas BLOADs at lines 2000-2020:

    PLANET FILE-M  -> $954C  per-planet byte arrays (tech, population, ...)
    P/F-M          -> $97E1  21 sixteen-byte per-planet records
    SHIP'S DATA-M  -> $9506  the ship's own registers

The files without the -M suffix on this disk are the saved-game slot,
not the new-game state; reading those is how an earlier pass came to
think the coordinates were filler.

A planet's record is what CALL 38825 ($97A9) copies in and out of the
working registers 38204-38219 on every hyperdrive jump, so the record
columns are named by the register they land in.

Usage: tools/newgame_data.py [--gdscript] [--saved]
  --gdscript  print the arrays as GDScript constants (planet 1 first)
  --saved     read the saved-game slot (PLANET FILE, P/F) instead
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTRACTED = os.path.join(ROOT, "extracted")

NAMES = ["SOL", "ALPHA CENTAURI", "BARNARD'S STAR", "WOLF 359", "LUYTEN",
         "LALANDE 21185", "SIRIUS", "VARCAR", "XANADON", "EPSILON ERIDANA",
         "CYGNI", "PROCYON", "TAU CETI", "LACAILLE 9352", "LARSEN-C",
         "GROOMBRIDGE 1618", "KRUGER 60", "EPSILON INDI", "ARGO", "SHIVANDA"]

PLANET_FILE_BASE = 0x954C
# name -> address of the entry *before* planet 1 (BASIC reads base+P)
ARRAYS = [("secured", 38219), ("scouted", 38240), ("population", 38261),
          ("tech", 38282), ("base", 38303), ("z", 38324), ("y", 38345), ("x", 38366)]
# record byte -> working register it is copied to
RECORD = [("threshold_38204", 0), ("defender_38205", 1), ("ground_38206", 2),
          ("fighters_38207", 3), ("surrendered_38208", 4), ("planet_38209", 5),
          ("atmosphere_38210", 6)]


def payload(name):
    with open(os.path.join(EXTRACTED, name + ".payload.bin"), "rb") as f:
        return f.read()


def load(saved=False):
    suffix = "" if saved else "-M"
    pf = payload("PLANET FILE" + suffix)
    rec = payload("P_F" + suffix)
    table = {}
    for name, base in ARRAYS:
        off = base - PLANET_FILE_BASE
        table[name] = [pf[off + p] for p in range(1, 21)]
    for name, i in RECORD:
        table[name] = [rec[(p - 1) * 16 + i] for p in range(1, 21)]
    return table


def main(argv):
    table = load("--saved" in argv)
    if "--gdscript" in argv:
        for name in table:
            print("const %s: Array[int] = %s" % (name.upper(), table[name]))
        return 0
    cols = ["tech", "population", "secured", "scouted", "base", "x", "y", "z",
            "defender_38205", "threshold_38204", "ground_38206", "fighters_38207",
            "surrendered_38208"]
    short = ["tech", "pop", "sec", "sct", "base", "x", "y", "z",
             "def", "thr", "gnd", "ftr", "surr"]
    print("%2s %-17s %s" % (" P", "name", " ".join("%4s" % s for s in short)))
    for p in range(20):
        print("%2d %-17s %s" % (p + 1, NAMES[p], " ".join("%4d" % table[c][p] for c in cols)))
    if "--saved" not in argv:
        ship = payload("SHIP'S DATA-M")
        print("\nSHIP'S DATA-M ($9506, %d bytes): %s" % (len(ship), " ".join(map(str, ship))))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
