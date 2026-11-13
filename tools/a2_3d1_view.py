#!/usr/bin/env python3
"""A2-3D1 in readable form: what CALL 24576 does, step by step, written out
from the disassembly of "LO-HI A2-3D1" ($6000) and checked against the
machine code itself (tools/a2_3d1_oracle.py runs the real routine).

    python3 -I tools/a2_3d1_view.py test [count]
        draw random views of every display database the game uses, with
        this code and with the machine code, and compare the hi-res pages
        byte for byte

    python3 -I tools/a2_3d1_view.py vectors <file.json> [count]
        write test views (database, eye, attitude, checksum of the page)
        for the GDScript port's own check

The engine is an interpreter. The "display database" at $7300 is a list
of records; the first byte of a record is its opcode:

     0  x y z        a point                                      7 bytes
     1  x y z        start of a line; the next record is its end  7 bytes
     2  x y z        line from the last end point to here         7 bytes
     3  x y z        line from here to the last end point         7 bytes
     4  n            n <> 0: do not clip, drop lines that leave   2 bytes
                     the view
     5  x y z p b h  eye position and attitude; builds the matrix 10 bytes
     7  n            soft switch $C000+n (graphics mode, page)    2 bytes
     8  n            clear page 1 (n=0) or page 2 (n=1)           2 bytes
     9  n            draw on page 1 (n=0) or page 2 (n<>0)        2 bytes
    14  w h cx cy    window: size and centre                      5 bytes
    15  sx sy sz     scale factors for the three view axes        7 bytes
    anything from $12 up ends the list

x, y, z are 16-bit, low byte first. Opcodes 6, 10, 11, 12, 13, 16 and 17
exist in the engine but no file of the game uses them; they are not
modelled here.

All arithmetic is 16-bit and wraps. Numbers are fractions of 32768
("Q15"): the multiply returns about a*b/32768 and the divide about
32768*n/d, each with its own rounding, copied here bit for bit because
the rounding decides which dot lights up.
"""
import json
import math
import random
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from flight_model import cos_raw, sin_raw  # noqa: E402  ($64FB and $64F8)

ROOT = Path(__file__).resolve().parent.parent
EXTRACTED = ROOT / "extracted"

DATABASE = 0x7300
SHIP = 0x7879  # where SHIP # n or DEBRIS is loaded, right after PLANET # 0
EYE = 0x731B

WORD = 0xFFFF

# outcode bits: which side of the view pyramid a point is beyond
LEFT, RIGHT, BELOW, ABOVE = 0x40, 0x20, 0x10, 0x08

# the dot at half-resolution column x is hi-res pixels 2x and 2x+1: byte
# column 2x/7 and this mask. Column 3 of every 7 straddles two bytes; its
# mask also has bit 7, the colour-shift bit of the byte, which the point
# and steep-line code sets and the shallow-line code does not.
MASKS = (0x03, 0x0C, 0x30, 0xC0, 0x06, 0x18, 0x60)


def word(value):
    return value & WORD


def signed(value):
    value &= WORD
    return value - 0x10000 if value & 0x8000 else value


def trig_word(pair):
    lo, hi = pair
    return hi << 8 | lo


def mul(a, b):
    """$635C: about a*b/32768. The first operand is taken bit by bit, the
    second is added; the low byte of the sum is dropped for the first six
    bits, so mul(a, b) and mul(b, a) are not always equal."""
    negative = (a ^ b) & 0x8000
    a = word(-a) if a & 0x8000 else a
    b = word(-b) if b & 0x8000 else b
    high = b >> 8
    total = high if a & 1 else 0
    for bit in range(1, 6):
        total >>= 1
        if a >> bit & 1:
            total += high
    total = (total >> 1) << 8
    for bit in range(6, 15):
        if a >> bit & 1:
            total = word(total + b)
        total >>= 1
    return word(-total) if negative else total


def div(n, d):
    """$6468: about 32768*n/d (n smaller than d), non-restoring, 15 bits.
    A quotient of exactly 1.0 comes out as $7FFF."""
    negative = (n ^ d) & 0x8000
    n = word(-n) if n & 0x8000 else n
    d = word(-d) if d & 0x8000 else d
    quotient = 0
    rest = word(n - d)
    for step in range(15):
        below = rest & 0x8000
        quotient = word(quotient << 1 | (0 if below else 1))
        rest = word(rest << 1)
        if step < 14:
            rest = word(rest + d) if below else word(rest - d)
    quotient = word(quotient << 1)
    if quotient & 0x8000:
        quotient = ((quotient >> 8) - 1 & 0xFF) << 8 | ((quotient & 0xFF) - 1 & 0xFF)
    return word(-quotient) if negative else quotient


def scale(fraction, size):
    """$691E: size * fraction / 128, fraction a signed byte."""
    total = size if fraction & 1 else 0
    for bit in range(1, 7):
        total >>= 1
        if fraction >> bit & 1:
            total += size
    total >>= 1
    if fraction & 0x80:
        total = (total - size) & 0xFF
    return total


class Point:
    """A point in view space with its outcode."""

    def __init__(self, x=0, y=0, z=0, out=0):
        self.x, self.y, self.z, self.out = x, y, z, out

    def copy(self):
        return Point(self.x, self.y, self.z, self.out)

    def classify(self):
        """$67EF/$6848: the view pyramid is |x| <= z and |y| <= z."""
        x, y, z = signed(self.x), signed(self.y), signed(self.z)
        self.out = ((LEFT if x + z < 0 else 0) | (RIGHT if z - x < 0 else 0)
                    | (BELOW if y + z < 0 else 0) | (ABOVE if z - y < 0 else 0))


def clip(inside, outside):
    """$6979: move "outside" along the line towards "inside", onto one of
    the planes it is beyond. One plane per call; the caller repeats."""
    a, b = inside, outside
    dz = word(a.z - b.z)
    if b.out & ~LEFT == 0:
        t = div(word(b.z + b.x), word(b.x - a.x - dz))
        b.y = word(b.y + mul(t, word(a.y - b.y)))
        b.z = word(b.z + mul(t, dz))
        b.x = word(-b.z)
    elif b.out & ~(LEFT | RIGHT) == 0:
        t = div(word(b.z - b.x), word(a.x - b.x - dz))
        b.z = word(b.z + mul(t, dz))
        b.x = b.z
        b.y = word(b.y + mul(t, word(a.y - b.y)))
    elif b.out & ~(LEFT | RIGHT | BELOW) == 0:
        t = div(word(b.z + b.y), word(b.y - a.y - dz))
        b.x = word(b.x + mul(t, word(a.x - b.x)))
        b.z = word(b.z + mul(t, dz))
        b.y = word(-b.z)
    else:
        t = div(word(b.z - b.y), word(a.y - b.y - dz))
        b.x = word(b.x + mul(t, word(a.x - b.x)))
        b.z = word(b.z + mul(t, dz))
        b.y = b.z
    b.classify()


class View:
    """The interpreter. memory: 64K with the database at $7300. pages: two
    hi-res pages as 192 rows of 40 bytes each, top row first."""

    def __init__(self, memory):
        self.memory = memory
        self.pages = [bytearray(40 * 192), bytearray(40 * 192)]
        self.shown = 0  # the page the last soft switch put on show
        # these outlive a call: the engine keeps them in its own code
        self.window = (69, 94, 0, 0)  # as the file is on disk
        self.axis_scale = [0x7FFF, 0x7FFF, 0x7FFF]
        self.target = 0

    # -- the interpreter ($6140) -------------------------------------

    def run(self):
        m = self.memory
        self.no_clip = 0
        self.eye = [0, 0, 0]
        self.matrix = [0x7FFD, 0, 0, 0, 0x7FFD, 0, 0, 0, 0x7FFD]
        self.last_end = Point()  # the end point of the last line, unclipped
        self.screen_a = (0, 0)  # where the last line's ends were drawn
        self.screen_b = (0, 0)
        at = DATABASE
        while True:
            op = m[at]
            if op >= 0x12:
                return
            if op == 0:
                p = self.transform(at)
                at += 7
                if p.out == 0:
                    self.screen_a = self.project(p)
                    self.plot(*self.screen_a)
            elif op == 1:
                a = self.transform(at)
                b = self.transform(at + 7)
                self.last_end = b.copy()
                at += 14
                self.line(a, b)
            elif op == 2:
                a = self.last_end.copy()
                b = self.transform(at)
                self.last_end = b.copy()
                at += 7
                self.line(a, b, reuse="first")
            elif op == 3:
                b = self.last_end.copy()
                a = self.transform(at)
                at += 7
                self.line(a, b, reuse="second")
            elif op == 4:
                self.no_clip = m[at + 1]
                at += 2
            elif op == 5:
                self.eye = [m[at + 1 + 2 * i] | m[at + 2 + 2 * i] << 8 for i in range(3)]
                self.build_matrix(m[at + 7], m[at + 8], m[at + 9])
                at += 10
            elif op == 7:
                if m[at + 1] in (0x54, 0x55):
                    self.shown = m[at + 1] - 0x54
                at += 2
            elif op == 8:
                page = self.pages[1 if m[at + 1] == 1 else 0]
                page[:] = bytes(len(page))  # the whole page, all 192 rows
                at += 2
            elif op == 9:
                self.target = 1 if m[at + 1] else 0
                at += 2
            elif op == 14:
                self.window = ((m[at + 1] >> 1) - 1 & 0xFF, (m[at + 2] >> 1) - 1 & 0xFF, m[at + 3], m[at + 4])
                at += 5
            elif op == 15:
                self.axis_scale = [m[at + 1 + 2 * i] | m[at + 2 + 2 * i] << 8 for i in range(3)]
                at += 7
            else:
                raise ValueError(f"opcode {op} at ${at:04X} is not modelled")

    def line(self, a, b, reuse=None):
        """$61B7-$62A0: clip the line a-b to the view pyramid and draw it.
        A line gets at most ten clipping steps, then it is dropped.

        Opcodes 2 and 3 save a projection. Opcode 2 (reuse="first"): when
        the first end is in view it is not projected again. Opcode 3
        (reuse="second"): when both ends are in view the second is not
        projected again. In both cases the code takes whatever screen
        position the previous line's second end had, also when that line
        was dropped and never got one."""
        if a.out & b.out:
            return
        budget = 10
        project_first = True
        project_second = True
        if a.out:
            if self.no_clip:
                return
            while True:
                clip(b, a)
                if a.out == 0:
                    break
                if a.out & b.out:
                    return
                budget -= 1
                if budget == 0:
                    return
        elif reuse == "first":
            project_first = False
        elif reuse == "second" and b.out == 0:
            project_second = False
        while b.out:
            if self.no_clip:
                return
            clip(a, b)
            budget -= 1
            if budget == 0:
                return
        if project_first:
            self.screen_a = self.project(a)
        else:
            self.screen_a = self.screen_b
        if project_second:
            self.screen_b = self.project(b)
        self.draw_line(self.screen_a, self.screen_b)

    # -- matrix and transform ----------------------------------------

    def build_matrix(self, pitch, bank, heading):
        """$654E. Angles are bytes, 256 to the circle. The view looks
        along +Z at heading 0; positive pitch is nose down.

        matrix[0..2] are the X, Y, Z view axes' weights of the world X
        difference, [3..5] of the Y difference, [6..8] of the Z difference."""
        sp, sb, sh = (trig_word(sin_raw(angle)) for angle in (pitch, bank, heading))
        cp, cb, ch = (trig_word(cos_raw(angle)) for angle in (pitch, bank, heading))
        ch_cb = mul(ch, cb)
        sh_sb = mul(sh, sb)
        ch_sb = mul(ch, sb)
        sh_cb = mul(sh, cb)
        m = [
            word(ch_cb + mul(sp, sh_sb)), word(mul(sp, sh_cb) - ch_sb), mul(sh, cp),
            mul(sb, cp), mul(cp, cb), word(-sp),
            None, None, None,
        ]
        m[6] = word(mul(ch_sb, sp) - sh_cb)
        m[7] = word(sh_sb + mul(sp, ch_cb))
        m[8] = mul(ch, cp)
        # opcode 15's scale factors, one per view axis; $7FFF means 1.
        # A slip in the code: it loads the factor's low byte only when the
        # high byte is $7F (to test for $7FFF). Otherwise the first of the
        # three products uses the factor's high byte with whatever is in
        # the A register: the low byte of the last product, or of the
        # previous axis's factor if that one was tested and skipped.
        register_a = m[8] & 0xFF
        for axis in range(3):
            factor = self.axis_scale[axis]
            if factor >> 8 == 0x7F:
                register_a = factor & 0xFF
                if register_a == 0xFF:
                    continue
            m[axis] = mul(factor & 0xFF00 | register_a, m[axis])
            if axis == 0:
                m[3] = mul(m[3], factor)
                m[6] = mul(m[6], factor)
            else:
                m[3 + axis] = mul(factor, m[3 + axis])
                m[6 + axis] = mul(factor, m[6 + axis])
            register_a = m[6 + axis] & 0xFF
        self.matrix = m

    def transform(self, at):
        """$672B: the record's x, y, z, relative to the eye, in view space."""
        mem, m = self.memory, self.matrix
        d = [word((mem[at + 1 + 2 * i] | mem[at + 2 + 2 * i] << 8) - self.eye[i]) for i in range(3)]
        p = Point(*(word(mul(d[0], m[axis]) + mul(d[1], m[3 + axis]) + mul(d[2], m[6 + axis]))
                    for axis in range(3)))
        p.classify()
        return p

    def project(self, p):
        """$68A1: perspective divide, then the window. Returns the two
        bytes the plot routines take: x from the window centre to the
        right, y from it upwards."""
        half_width, half_height, centre_x, centre_y = self.window
        x = scale(div(p.x, p.z) >> 8, half_width) + centre_x & 0xFF
        y = scale(div(p.y, p.z) >> 8, half_height) + centre_y & 0xFF
        return x, y

    # -- dots ($6D8F) and lines ($6DD5) --------------------------------

    def dot(self, x, row, mask_bit7=True):
        """x: half-resolution column (0-139), two hi-res pixels wide."""
        page = self.pages[self.target]
        at = row * 40 + 2 * x // 7
        mask = MASKS[x % 7]
        page[at] |= mask if mask_bit7 else mask & 0x7F
        if x % 7 == 3:
            page[at + 1] |= 0x01

    def plot(self, x, y):
        self.dot(x + 70 & 0xFF, 95 - y & 0xFF)

    def draw_line(self, a, b):
        x1, y1 = a[0] + 70 & 0xFF, 95 - a[1] & 0xFF
        x2, y2 = b[0] + 70 & 0xFF, 95 - b[1] & 0xFF
        if x2 < x1:
            x1, y1, x2, y2 = x2, y2, x1, y1
        dx = x2 - x1
        dy = abs(y2 - y1)
        step = 1 if y2 >= y1 else -1
        x, y = x1, y1
        if dy < dx:
            # shallow: one dot per column
            error = -((dx + 1) // 2)
            for i in range(dx + 1):
                self.dot(x, y, mask_bit7=False)
                error += dy
                if error >= 0:
                    error -= dx
                    y += step
                x += 1
        else:
            # steep: one dot per row
            error = dy >> 1
            for i in range(dy + 1):
                self.dot(x, y)
                y += step
                error -= dx
                if error < 0:
                    error += dy
                    x += 1


# -- the game's display databases ------------------------------------------


def load(planet, ship):
    """Memory as the game has it: PLANET # n at $7300 and, in space,
    SHIP # n or DEBRIS behind PLANET # 0. ship: a number, "debris" or None."""
    memory = bytearray(0x10000)
    data = (EXTRACTED / f"PLANET no {planet}.payload.bin").read_bytes()
    memory[DATABASE:DATABASE + len(data)] = data
    if ship is not None:
        name = "DEBRIS.payload.bin" if ship == "debris" else f"SHIP no {ship}.payload.bin"
        data = (EXTRACTED / name).read_bytes()
        memory[SHIP:SHIP + len(data)] = data
    return memory


def set_view(memory, eye, attitude, page=2):
    """What BASIC pokes before CALL CA: the eye, the attitude and the
    three page bytes of the header (lines 140 and 147)."""
    for i, value in enumerate(eye):
        memory[EYE + 2 * i] = value & 0xFF
        memory[EYE + 2 * i + 1] = value >> 8 & 0xFF
    for i, value in enumerate(attitude):
        memory[EYE + 6 + i] = value & 0xFF
    memory[DATABASE + 0x15] = 0x54 if page == 2 else 0x55
    memory[DATABASE + 0x17] = 1 if page == 2 else 0
    memory[DATABASE + 0x19] = 1 if page == 2 else 0


def render(memory, eye, attitude, page=2):
    set_view(memory, eye, attitude, page)
    view = View(memory)
    view.run()
    return view.pages[page - 1]


DATABASES = [(0, 0), (0, 1), (0, 3), (0, 4), (0, "debris")] + [(n, None) for n in range(1, 21)]


def random_view(rng, planet):
    """Eye positions where there is something to see: near the defender
    in space, low over the terrain in the atmosphere."""
    if planet == 0:
        spread = rng.choice([600, 3000, 9000, 20000])
        eye = [rng.randint(-spread, spread) for _ in range(3)]
        attitude = [rng.randrange(256) for _ in range(3)]
        if rng.random() < 0.5:
            attitude[1] = rng.choice([0, 0, 4, 252, 20, 236, 47, 208])
        if rng.random() < 0.6:
            # look at the defender (near the origin), give or take
            length = math.sqrt(sum(v * v for v in eye)) or 1.0
            toward = [-v / length for v in eye]
            heading = math.atan2(toward[0], toward[2]) * 128 / math.pi
            pitch = -math.asin(toward[1]) * 128 / math.pi
            attitude[0] = round(pitch + rng.randint(-10, 10)) & 0xFF
            attitude[2] = round(heading + rng.randint(-14, 14)) & 0xFF
    else:
        eye = [rng.randint(-9000, 9000), rng.choice([20, 100, 500, 1024, 2500, 4000]), rng.randint(-9000, 9000)]
        attitude = [rng.choice([0, 5, 20, 40, 59, 195, 230, 250]), rng.choice([0, 0, 4, 252, 30, 226]),
                    rng.randrange(256)]
    return eye, attitude


def test(count):
    from a2_3d1_oracle import machine, render as oracle_render
    rng = random.Random(1982)
    bad = 0
    done = 0
    for planet, ship in DATABASES:
        cpu = machine(planet, ship)
        memory = load(planet, ship)
        lit = 0
        for n in range(count):
            eye, attitude = random_view(rng, planet)
            page = 1 + n % 2
            rows, _ = oracle_render(cpu, eye, attitude, page)
            theirs = b"".join(rows)
            mine = bytes(render(memory, eye, attitude, page))
            done += 1
            lit += sum(1 for value in theirs if value)
            if mine != theirs:
                bad += 1
                wrong = [i for i in range(len(mine)) if mine[i] != theirs[i]]
                print(f"  DIFFERENT planet {planet} ship {ship} eye {eye} attitude {attitude}: {len(wrong)} bytes,"
                      f" first at row {wrong[0] // 40} column {wrong[0] % 40}:"
                      f" ${mine[wrong[0]]:02X} here, ${theirs[wrong[0]]:02X} from the machine code")
        print(f"PLANET # {planet}{'' if ship is None else f' + {ship}'}: {count} views,"
              f" {lit // count} bytes lit on average")
    print(f"{done} views, {bad} different")
    return bad


def vectors(path, count):
    rng = random.Random(24576)
    out = []
    for planet, ship in DATABASES:
        memory = load(planet, ship)
        for n in range(count):
            eye, attitude = random_view(rng, planet)
            page = 1 + n % 2
            picture = bytes(render(memory, eye, attitude, page))
            out.append({"planet": planet, "ship": ship, "eye": eye, "attitude": attitude, "page": page,
                        "lit": sum(1 for value in picture if value), "crc": zlib.crc32(picture)})
    Path(path).write_text(json.dumps(out, indent=0))
    print(f"{len(out)} views written to {path}")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "test":
        sys.exit(1 if test(int(sys.argv[2]) if len(sys.argv) > 2 else 40) else 0)
    elif len(sys.argv) >= 3 and sys.argv[1] == "vectors":
        vectors(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 6)
    else:
        print(__doc__)
        sys.exit(2)
