#!/usr/bin/env python3
"""The game's own character table as a smooth vector font.

HI-RES CHARACTER GENERATOR draws every character of the game from a
table of 7x8 bit glyphs (godot-remake/assets/hgr/character_table.json,
from the disk's CHARACTER TABLE). Each glyph there is a line drawn on a
seven by eight grid. This follows those lines: the lit dots are joined
into strokes (a dot to the dot beside it, or across a corner where the
two dots between are dark), each stroke is eased into a curve by cutting
its corners, and the curve is drawn with a round pen. The letters keep the
game's shapes, slant and unevenness, and come out smooth at any size.
The letters are drawn wide and set
monospaced, the way an early-80s display typeface is.

    python3 -m venv /tmp/fontenv && /tmp/fontenv/bin/pip install fonttools
    /tmp/fontenv/bin/python tools/make_font.py

Writes godot-remake/font_source/space_vikings.ttf (then tools_make_font_res.gd makes the .res the theme uses).
"""
import json
import math
import os

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLE = os.path.join(ROOT, "godot-remake", "assets", "hgr", "character_table.json")
OUT = os.path.join(ROOT, "godot-remake", "font_source", "space_vikings.ttf")

DOT = 100  # font units to a dot
COLUMNS, ROWS = 7, 8
BASELINE_ROW = 7  # the row under it is the descenders'
PEN = 0.80  # width of the pen, in dots
WIDE = 1.32  # how much wider than the grid the letters are drawn
CELL = 9.4  # dots to a letter: every letter, and the space, takes this much
SMOOTHING = 3  # rounds of corner cutting
STEP = 0.12  # dots between the points a curve is drawn at
ARC = 10  # sides to half a pen end


def lit_dots(data, code):
    dots = set()
    for row in range(ROWS):
        value = data[(code & 127) * 8 + row]
        for column in range(COLUMNS):
            if value >> column & 1:
                dots.add((column, row))
    return dots


def neighbours(dots):
    """The strokes: each dot joined to the dots beside and above and below
    it, and across a corner only where both dots between are dark."""
    edges = {d: set() for d in dots}
    for c, r in dots:
        for dc, dr in ((1, 0), (0, 1)):
            if (c + dc, r + dr) in dots:
                edges[(c, r)].add((c + dc, r + dr))
                edges[(c + dc, r + dr)].add((c, r))
        for dc, dr in ((1, 1), (1, -1)):
            there = (c + dc, r + dr)
            if there in dots and (c + dc, r) not in dots and (c, r + dr) not in dots:
                edges[(c, r)].add(there)
                edges[there].add((c, r))
    return edges


def chains(edges):
    """The strokes as paths: from a dot where lines meet or end, along dots
    that have two neighbours, to the next; and the loops that have no such
    dot (an O)."""
    seen = set()
    paths = []

    def key(a, b):
        return (a, b) if a < b else (b, a)

    nodes = sorted(edges)
    for start in nodes:
        if len(edges[start]) == 2:
            continue
        for first in sorted(edges[start]):
            if key(start, first) in seen:
                continue
            path = [start, first]
            seen.add(key(start, first))
            while len(edges[path[-1]]) == 2:
                nxt = [n for n in edges[path[-1]] if n != path[-2]][0]
                if key(path[-1], nxt) in seen:
                    break
                seen.add(key(path[-1], nxt))
                path.append(nxt)
            paths.append((path, False))
    for start in nodes:
        if len(edges[start]) == 2 and any(key(start, n) not in seen for n in edges[start]):
            path = [start]
            here, prev = start, None
            while True:
                nxt = [n for n in sorted(edges[here]) if n != prev and key(here, n) not in seen]
                if not nxt:
                    break
                seen.add(key(here, nxt[0]))
                prev, here = here, nxt[0]
                path.append(here)
                if here == start:
                    break
            if len(path) > 2:
                paths.append((path[:-1] if path[-1] == start else path, path[-1] == start or True))
    return paths


def cut_corners(points, closed):
    """Chaikin's corner cutting: each corner replaced by two points a
    quarter of the way along each side; the ends of an open line stay."""
    for _ in range(SMOOTHING):
        out = []
        n = len(points)
        if closed:
            for i in range(n):
                a, b = points[i], points[(i + 1) % n]
                out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
                out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        else:
            out.append(points[0])
            for i in range(n - 1):
                a, b = points[i], points[i + 1]
                if i > 0:
                    out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
                if i < n - 2:
                    out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
            out.append(points[-1])
        points = out
    return points


def resample(points, closed):
    out = []
    n = len(points)
    last = n if closed else n - 1
    for i in range(last):
        a, b = points[i], points[(i + 1) % n]
        length = math.dist(a, b)
        steps = max(1, int(length / STEP))
        for s in range(steps):
            t = s / steps
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    if not closed:
        out.append(points[-1])
    return out


def capsule(a, b, radius):
    """A pen's mark from a to b as a polygon, clockwise."""
    angle = math.atan2(b[1] - a[1], b[0] - a[0])
    points = []
    for i in range(ARC + 1):  # round the end at b
        t = angle - math.pi / 2 + math.pi * i / ARC
        points.append((b[0] + radius * math.cos(t), b[1] + radius * math.sin(t)))
    for i in range(ARC + 1):  # and the end at a
        t = angle + math.pi / 2 + math.pi * i / ARC
        points.append((a[0] + radius * math.cos(t), a[1] + radius * math.sin(t)))
    area = sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(points, points[1:] + points[:1]))
    return points if area < 0 else points[::-1]  # y is down here: the flip below turns it


def glyph_marks(dots):
    """The polygons of a glyph, in dots, y down, and its ink's left and right."""
    marks = []
    edges = neighbours(dots)
    for path, closed in chains(edges):
        points = [((c + 0.5) * WIDE, r + 0.5) for c, r in path]
        if len(points) > 2 or closed:
            points = cut_corners(points, closed)
        points = resample(points, closed)
        for a, b in zip(points, points[1:] + (points[:1] if closed else [])):
            marks.append(capsule(a, b, PEN / 2))
    for dot in dots:
        if not edges[dot]:  # a dot of its own: a little fuller than the pen
            c, r = dot
            marks.append(capsule(((c + 0.5) * WIDE, r + 0.5), ((c + 0.5) * WIDE, r + 0.5), PEN / 2 * 1.2))
    xs = [x for m in marks for x, _ in m]
    return marks, (min(xs), max(xs)) if xs else (0.0, 0.0)


def build():
    data = json.load(open(TABLE))["bytes"]
    glyph_set = {}
    advance = {".notdef": round(CELL * DOT)}
    cmap = {}
    order = [".notdef"]
    pen = TTGlyphPen(None)
    pen.moveTo((0, 0))
    pen.lineTo((0, 7 * DOT))
    pen.lineTo((round(CELL * DOT) - 100, 7 * DOT))
    pen.lineTo((round(CELL * DOT) - 100, 0))
    pen.closePath()
    glyph_set[".notdef"] = pen.glyph()
    for code in range(32, 127):
        name = "space" if code == 32 else "uni%04X" % code
        order.append(name)
        cmap[code] = name
        pen = TTGlyphPen(None)
        marks, (left, right) = glyph_marks(lit_dots(data, code))
        advance[name] = round(CELL * DOT)
        shift = CELL / 2 - (left + right) / 2  # the letter's ink in the middle of its cell
        for mark in marks:
            pts = [(round((x + shift) * DOT), round((BASELINE_ROW + 1 - y) * DOT)) for x, y in mark]
            pts.reverse()  # y up: the winding turns again; every mark the same way
            pen.moveTo(pts[0])
            for p in pts[1:]:
                pen.lineTo(p)
            pen.closePath()
        glyph_set[name] = pen.glyph()
    fb = FontBuilder(8 * DOT, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyph_set)
    fb.setupHorizontalMetrics({name: (advance[name], 0) for name in order})
    fb.setupHorizontalHeader(ascent=BASELINE_ROW * DOT, descent=-DOT)
    fb.setupNameTable({"familyName": "Space Vikings", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=BASELINE_ROW * DOT, sTypoDescender=-DOT, sTypoLineGap=DOT,
                usWinAscent=BASELINE_ROW * DOT, usWinDescent=DOT)
    fb.setupPost()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    fb.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    build()
