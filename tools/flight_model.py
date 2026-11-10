#!/usr/bin/env python3
"""Model of the flight step in STARSHIP SIMULATOR.bas (lines 20-140) and of
the stick routine CALL CA ($9023), for checking against a live run.

    python3 -I tools/flight_model.py table
        the 65-entry cosine table at $609A of LO-HI A2-3D1, and the four
        factors BASIC derives for every angle 0..255

    python3 -I tools/flight_model.py check <flight_live.log>
        replay a log written by tools/mame/flight_live.lua: predict every
        pass's position step and attitude from the previous pass and report
        the passes that differ

The trig routines are A2-3D1's ($64F8 sine, $64FB cosine). BASIC calls the
sine "CSN" and the cosine "SN". Two things in them are not what a clean
implementation would do, and both are copied here:

  * a negative result is built as hi = -hi, lo = -hi - lo - borrow, so it
    is not the two's complement of the table entry;
  * BASIC does not look at the sign bit. It decides from the angle whether
    to read the result as unsigned or as "minus 256" (lines 114-128), and
    for the cosine it skips angles 63 and 190 altogether. The variable then
    still holds the previous pass's factor, and line 129 divides it by
    32768 a second time, so the factor is as good as zero.
"""
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
A2_3D1 = ROOT / "extracted" / "LO-HI A2-3D1.payload.bin"
TABLE_OFFSET = 0x9A  # $609A, the file loads at $6000


def load_table():
    data = A2_3D1.read_bytes()
    return [data[TABLE_OFFSET + 2 * i] | (data[TABLE_OFFSET + 2 * i + 1] << 8) for i in range(65)]


TABLE = load_table()


def cos_raw(angle):
    """$64FB: returns (lo, hi) as left in $600C/$600D."""
    a = angle & 0xFF
    if a >= 0x80:
        a = (-a) & 0xFF
        if a == 0x80:
            return _negative(0)  # ASL of $80 gives index 0
    if a < 0x40:
        v = TABLE[a]
        return v & 0xFF, v >> 8
    return _negative(0x80 - a)


def _negative(index):
    v = TABLE[index]
    lo, hi = v & 0xFF, v >> 8
    x = (0 - hi) & 0xFF
    borrow = 0 if hi == 0 else 1
    return (x - lo - borrow) & 0xFF, x


def sin_raw(angle):
    """$64F8: the cosine of angle - $40."""
    return cos_raw((angle - 0x40) & 0xFF)


def basic_sin(angle):
    """Lines 123-128: CALL CSN, minus-256 form when the angle is over 127."""
    lo, hi = sin_raw(angle)
    if angle > 127:
        hi -= 256
    return (hi * 256 + lo) / 32768.0


def basic_cos(angle, stale):
    """Lines 114-122 and the division of line 129: CALL SN; 63 and 190
    match neither IF, and the previous factor is divided again."""
    lo, hi = cos_raw(angle)
    if angle < 63 or angle > 190:
        return (hi * 256 + lo) / 32768.0
    if 63 < angle < 190:
        return ((hi - 256) * 256 + lo) / 32768.0
    return stale / 32768.0


class Flight:
    """X, Y, Z as BASIC holds them between passes (floats)."""

    def __init__(self, x, y, z):
        self.x, self.y, self.z = float(x), float(y), float(z)
        self.zp = 0.0
        self.zh = 0.0

    def step(self, pitch, heading, speed):
        self.zp = basic_cos(pitch, self.zp)
        self.zh = basic_cos(heading, self.zh)
        xh = basic_sin(heading)
        yp = basic_sin(pitch)
        self.x += speed * (self.zp * xh)
        self.z += speed * self.zp * self.zh
        y1 = speed * yp
        self.y += y1
        if pitch > 190 or pitch < 64:
            self.y -= 2 * y1
        for name in ("x", "y", "z"):
            v = getattr(self, name)
            if v < -20000:
                v = 20000.0
            if v > 20000:
                v = -20000.0
            setattr(self, name, v)

    def stored(self):
        return tuple(math.floor(v) for v in (self.x, self.y, self.z))


def stick(pitch, bank, heading, flip, pdl_pitch, pdl_bank):
    """CALL CA ($9023) up to its JSR $6000: returns pitch, bank, heading, flip."""
    j, k = pdl_pitch, pdl_bank
    if j < 0x5A:
        for limit in (0x5A, 0x46, 0x32, 0x1F):
            if j < limit:
                pitch = (pitch + 1) & 0xFF
    elif j >= 0xAA:
        for limit in (0xAA, 0xBE, 0xD2, 0xE6):
            if j >= limit:
                pitch = (pitch - 1) & 0xFF

    def bank_inc(b):
        if b == 0xFF:
            return 0
        b += 1
        if 0x30 <= b < 0xD0:
            b -= 1
        return b

    def bank_dec(b):
        if b == 0:
            return 0xFF
        b -= 1
        if 0x30 <= b < 0xD0:
            b += 1
        return b

    if k < 0x5A:
        for limit in (0x5A, 0x46, 0x32, 0x1E):
            if k < limit:
                bank = bank_inc(bank)
    elif k >= 0xAA:
        for limit in (0xAA, 0xBE, 0xD2, 0xE6):
            if k >= limit:
                bank = bank_dec(bank)

    inverted = 1 if 0x40 <= pitch < 0xC0 else 0
    if inverted != flip:
        flip = inverted
        heading = heading + 0x7E if heading < 0x7F else heading - 0x7F

    b = bank
    if b < 5:
        pass
    elif b < 0x31:
        heading = (heading - 1) & 0xFF
        for limit in (0x11, 0x21, 0x30):
            if b >= limit:
                heading = (heading - 1) & 0xFF
    elif b < 0xFB:
        heading = (heading + 1) & 0xFF
        for limit in (0xF0, 0xE0, 0xD0):
            if b < limit:
                heading = (heading + 1) & 0xFF
    return pitch, bank, heading, flip


def basic_pitch_clamp(pitch):
    """Lines 175/177, after CALL CA."""
    if 59 < pitch < 127:
        return 59
    if 127 < pitch < 195:
        return 195
    return pitch


ITER = re.compile(
    r"iter (\d+) .*X=(-?\d+) Y=(-?\d+) Z=(-?\d+) P=(\d+) B=(\d+) H=(\d+) S=(\d+) pdl=(\d+)/(\d+) flip=(\d+)")
RESTART = re.compile(r"^restart X=(-?\d+) Y=(-?\d+) Z=(-?\d+)")
POKE_H = re.compile(r"^poke H=(\d+)")
STICK = re.compile(r"^-- (.*) \(pitch stick (\d+), bank stick (\d+)\)")


def check(path):
    """Each "iter" line is written when line 147 runs: the position is that
    pass's result, the attitude is what the pass before it left. The script's
    pokes land after the line, before that pass's CALL CA.

    BASIC keeps the position as floats and stores the floor, so the replay
    starts from the "restart" position (whole numbers, read back by line 8)
    and runs the passes made before the log's first "iter" line."""
    flight = None
    origin = None
    att = None  # pitch, bank, heading, flip as expected at the next iter line
    pending = None  # (pitch, bank, heading, flip, pdl_pitch, pdl_bank) going into CALL CA
    bad = 0
    passes = 0
    for line in Path(path).read_text().splitlines():
        m = RESTART.match(line)
        if m:
            origin = tuple(int(g) for g in m.groups())
            continue
        m = ITER.search(line)
        if m:
            n, x, y, z, p, b, h, s, pj, pk, flip = (int(g) for g in m.groups())
            if flight is None and origin is not None:
                flight = Flight(*origin)
                for early in range(200):
                    if flight.stored() == (x, y, z):
                        print(f"{early} passes between the restart and the first logged one")
                        break
                    flight.step(p, h, s)
                else:
                    print("the first logged position is not reachable from the restart position")
                    flight = Flight(x, y, z)
            if pending is not None:
                p2, b2, h2, f2 = stick(*pending)
                p2 = basic_pitch_clamp(p2)
                att = (p2, b2, h2, f2)
                if (p, b, h, flip) != att:
                    bad += 1
                    print(f"iter {n}: attitude P/B/H/flip {(p, b, h, flip)} expected {att}")
                if flight is None:
                    flight = Flight(*prev_pos)
                flight.step(p, h, s)
                passes += 1
                want = flight.stored()
                if (x, y, z) != want:
                    bad += 1
                    print(f"iter {n}: P={p} H={h} S={s} position {(x, y, z)} expected {want}"
                          f" (step {x - prev_pos[0]}, {y - prev_pos[1]}, {z - prev_pos[2]})")
                    zp, zh = flight.zp, flight.zh
                    flight = Flight(x, y, z)
                    flight.zp, flight.zh = zp, zh
            prev_pos = (x, y, z)
            pending = [p, b, h, flip, pj, pk]
            continue
        m = POKE_H.match(line)
        if m and pending is not None:
            pending[0], pending[1], pending[2] = 0, 0, int(m.group(1))
            continue
        m = STICK.match(line)
        if m and pending is not None:
            if m.group(1) == "level":
                pending[0], pending[1], pending[2] = 0, 0, 0
            pending[4], pending[5] = int(m.group(2)), int(m.group(3))
    print(f"{passes} passes replayed, {bad} differences")
    return bad


def table():
    print("cosine table at $609A (index: value, expected 32767*cos(i*90/64 deg)):")
    for i, v in enumerate(TABLE):
        ideal = round(32767 * math.cos(math.radians(i * 90 / 64)))
        note = "" if abs(v - ideal) <= 1 else f"   <-- differs by {v - ideal}"
        print(f"  {i:2d}: ${v:04X} {v:6d}  {ideal:6d}{note}")
    print()
    print("angle: BASIC cos (ZP/ZH), BASIC sin (XH/YP), ideal cos, ideal sin")
    for a in range(256):
        c = basic_cos(a, float("nan"))
        s = basic_sin(a)
        ic = math.cos(a * 2 * math.pi / 256)
        isn = math.sin(a * 2 * math.pi / 256)
        note = ""
        if math.isnan(c):
            note = "   <-- cosine left at its previous value"
        elif abs(c - ic) > 0.02 or abs(s - isn) > 0.02:
            note = "   <-- off"
        print(f"  {a:3d}: {c:+.5f} {s:+.5f}   {ic:+.5f} {isn:+.5f}{note}")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "table":
        table()
    elif len(sys.argv) >= 3 and sys.argv[1] == "check":
        sys.exit(1 if check(sys.argv[2]) else 0)
    else:
        print(__doc__)
        sys.exit(2)
