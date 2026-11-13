#!/usr/bin/env python3
"""Run the game's own A2-3D1 machine code on a display database and get
the hi-res page it draws, without an emulator session.

A2-3D1 ("LO-HI A2-3D1", loaded at $6000) is self-contained: CALL 24576
interprets the display database at $7300 and plots into hi-res memory.
This loads the same files the game loads (PLANET # n at $7300, SHIP # n or
DEBRIS at $7879), pokes the eye position and attitude where BASIC pokes
them ($731B-$7323), and runs $6000 on tools/sim6502.py.

    python3 -I tools/a2_3d1_oracle.py check <directory>
        compare with the pages a live MAME run dumped
        (tools/mame/view_live.lua: view_live.log and view_<n>_p<page>.bin)

    python3 -I tools/a2_3d1_oracle.py render --planet 0 --ship 3 \\
            --eye 0 0 -12000 --attitude 0 0 0 [--pgm out.pgm]
        draw one view and print it (or write it as a PGM picture)

The 3D window is rows 0-124 of the page; the rows below it (instrument
panel, text) are drawn by BASIC and are not compared. BASIC also XDRAWs
the gunsight into the window; "check" expects exactly that difference.
"""
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sim6502 import CPU  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
EXTRACTED = ROOT / "extracted"

DATABASE = 0x7300
SHIP = 0x7879
EYE = 0x731B  # 29467: X, Y, Z (16-bit), then pitch, bank, heading
WINDOW_ROWS = 125


def row_address(page, y):
    return page + (y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 0x28


def machine(planet, ship):
    """A CPU with A2-3D1 and the display database in memory. ship: a number,
    "debris" or None."""
    cpu = CPU()
    cpu.load(0x6000, (EXTRACTED / "LO-HI A2-3D1.payload.bin").read_bytes())
    cpu.load(DATABASE, (EXTRACTED / f"PLANET no {planet}.payload.bin").read_bytes())
    if ship == "debris":
        cpu.load(SHIP, (EXTRACTED / "DEBRIS.payload.bin").read_bytes())
    elif ship is not None:
        cpu.load(SHIP, (EXTRACTED / f"SHIP no {ship}.payload.bin").read_bytes())
    return cpu


def set_eye(cpu, eye, attitude):
    for i, value in enumerate(eye):
        value &= 0xFFFF
        cpu.mem[EYE + 2 * i] = value & 0xFF
        cpu.mem[EYE + 2 * i + 1] = value >> 8
    for i, value in enumerate(attitude):
        cpu.mem[EYE + 6 + i] = value & 0xFF


def render(cpu, eye, attitude, page=2):
    """Draw one picture on hi-res page 1 or 2 and return it as 192 rows of
    40 bytes. The database's own page bytes (what line 147 of the flight
    program flips) are set so that the picture goes to the page asked for."""
    set_eye(cpu, eye, attitude)
    cpu.mem[DATABASE + 0x15] = 0x54 if page == 2 else 0x55  # shown: the other page
    cpu.mem[DATABASE + 0x17] = 1 if page == 2 else 0  # cleared
    cpu.mem[DATABASE + 0x19] = 1 if page == 2 else 0  # plotted
    cycles = cpu.call(0x6000)
    base = 0x4000 if page == 2 else 0x2000
    rows = [bytes(cpu.mem[row_address(base, y):row_address(base, y) + 40]) for y in range(192)]
    return rows, cycles


def pixels(rows, y_from=0, y_to=WINDOW_ROWS):
    lit = set()
    for y in range(y_from, y_to):
        row = rows[y]
        for column in range(40):
            value = row[column]
            for bit in range(7):
                if value >> bit & 1:
                    lit.add((column * 7 + bit, y))
    return lit


def show(rows, y_to=WINDOW_ROWS):
    for y in range(y_to):
        line = []
        for column in range(40):
            value = rows[y][column]
            line.append("".join("#" if value >> bit & 1 else "." for bit in range(7)))
        print("".join(line))


VIEW = re.compile(r"^view (\d+) (\w+) X=(-?\d+) Y=(-?\d+) Z=(-?\d+) P=(\d+) B=(\d+) H=(\d+) page=(\d)"
                  r" atmos=(\d+) planet=(\d+) defender=(\d+)")

def check(directory):
    """BASIC XDRAWs the gunsight onto the finished picture (line 156), so a
    live page is the oracle's picture exclusive-or the gunsight. The check
    is that this difference is the same set of pixels in every view."""
    directory = Path(directory)
    gunsight = None
    bad = 0
    views = 0
    for line in (directory / "view_live.log").read_text().splitlines():
        m = VIEW.match(line)
        if not m:
            continue
        n, kind, x, y, z, p, b, h, page, atmos, planet, defender = m.groups()
        n, page = int(n), int(page)
        # in space the database is PLANET # 0 with the defender's model after
        # it; in the atmosphere it is the planet's own terrain map
        if int(atmos):
            cpu = machine(int(planet), None)
        else:
            ship = int(defender)
            cpu = machine(0, 3 if ship == 2 else ship)
        rows, cycles = render(cpu, (int(x), int(y), int(z)), (int(p), int(b), int(h)), page)
        live = (directory / f"view_{n}_p{page}.bin").read_bytes()
        live_rows = [live[i * 40:i * 40 + 40] for i in range(192)]
        mine, theirs = pixels(rows), pixels(live_rows)
        difference = mine ^ theirs
        if gunsight is None:
            gunsight = difference
            xs = [q[0] for q in gunsight]
            ys = [q[1] for q in gunsight]
            print(f"difference in the first view: {len(gunsight)} pixels, x {min(xs)}-{max(xs)},"
                  f" y {min(ys)}-{max(ys)} (the gunsight)")
        views += 1
        verdict = "same" if difference == gunsight else "DIFFERENT"
        if verdict != "same":
            bad += 1
        print(f"view {n:2d} {kind:5s} eye {x},{y},{z} P/B/H {p}/{b}/{h}: {len(theirs)} lit pixels live,"
              f" {len(mine)} from the oracle, {cycles} cycles: {verdict}")
        if verdict != "same":
            extra = sorted(difference ^ gunsight)
            print(f"    {extra[:16]}{' ...' if len(extra) > 16 else ''}")
    print(f"{views} views, {bad} different")
    return bad


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    c = sub.add_parser("check")
    c.add_argument("directory")
    r = sub.add_parser("render")
    r.add_argument("--planet", type=int, default=0)
    r.add_argument("--ship", default=None, help='a SHIP number or "debris"')
    r.add_argument("--eye", type=int, nargs=3, default=[0, 0, -12000])
    r.add_argument("--attitude", type=int, nargs=3, default=[0, 0, 0], metavar=("PITCH", "BANK", "HEADING"))
    r.add_argument("--pgm")
    args = parser.parse_args()
    if args.command == "check":
        sys.exit(1 if check(args.directory) else 0)
    ship = args.ship if args.ship in (None, "debris") else int(args.ship)
    rows, cycles = render(machine(args.planet, ship), args.eye, args.attitude)
    print(f"{cycles} cycles ({cycles / 1020484:.2f} s at 1.02 MHz)", file=sys.stderr)
    if args.pgm:
        with open(args.pgm, "wb") as out:
            out.write(b"P5 280 192 255\n")
            for row in rows:
                out.write(bytes(255 if row[x // 7] >> (x % 7) & 1 else 0 for x in range(280)))
    else:
        show(rows)


if __name__ == "__main__":
    main()
