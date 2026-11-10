extends RefCounted
## The game's Applesoft shape table (`ENEMY I`, 26 shapes), loaded from
## the JSON written by tools/shape_table_decoder.py, plus the Apple II+
## ROM's own DRAW loop so any shape can be rasterised at any ROT and
## SCALE exactly as the original drew it.
##
## Shape numbers are 1-based, the same numbers the BASIC source passes
## to DRAW / XDRAW (`XDRAW 12 AT PX,PY` is `plots(12)` here). What the
## 26 shapes are:
##    1  3x3 block (star chart: star with Z > 15)
##    2  explosion burst            3  sparkle
##    4, 5  diamonds (5 = star chart: Z 12..15)
##    6  small blob (star chart: Z < 12)      7  plus
##    8  fighter head-on    9, 10  fighter diagonals (mirror images)
##   11  large reticle     12  crosshair cursor (star chart)
##   13  up-pointing gauge marker   14  right-pointing gauge marker
##   15-18  the four quarters of a disc (ship destruction debris)
##   19-22  solid blocks   23-26  bars (25/26 erase the gauge markers)
##
## `plots()` is a port of DRAW1 ($F601), disassembled from a live MAME
## memory dump with tools/dis6502.py; see the tool's docstring for the
## algorithm and for how the decode was checked against the real screen.
## The earlier version of this file read a different, wrong JSON layout
## (a "custom format" decode that turned the offset table's high bytes
## into shapes); nothing of that is left.
##
## Deliberately no `class_name` — that requires Godot's global script-
## class cache, which only exists after the project has been opened once
## in the full editor (not guaranteed on a fresh clone run straight from
## the command line). Callers `preload()` this script into a local
## `ShapeTable` const instead.

## The ROM's cosine table at $F5BA.
const COS: PackedByteArray = [
	0xFF, 0xFE, 0xFA, 0xF4, 0xEC, 0xE1, 0xD4, 0xC5,
	0xB4, 0xA1, 0x8D, 0x78, 0x61, 0x49, 0x31, 0x18, 0xFF,
]
## Shape-vector directions 0..3: up, right, down, left (screen y is down).
const DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var shape_count: int = 0
var _bytes_by_shape: Dictionary = {} # int -> PackedByteArray
var _plot_cache: Dictionary = {} # Vector3i(shape, rot, scale) -> Array[Vector2i]

## Instance method, not a static factory — a static factory would need to
## self-reference this script's own type, which needs either class_name
## or a self-preload, both more trouble than they're worth here.
func load_shapes(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ShapeTable: could not open %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("shapes"):
		push_error("ShapeTable: %s has no 'shapes' array" % path)
		return

	var shapes: Array = parsed["shapes"]
	shape_count = shapes.size()
	_bytes_by_shape.clear()
	_plot_cache.clear()
	for shape in shapes:
		var stream := PackedByteArray()
		for b in shape.get("bytes", []):
			stream.append(int(b))
		_bytes_by_shape[int(shape.get("id", -1))] = stream

## Clamps to a real shape number (1..count), so a flip-book creep such as
## the missile's `M3 = M3 + .32` never reads past the table.
func clamp_index(index: int) -> int:
	return clampi(index, 1, max(shape_count, 1))

## Every point the ROM plots for `DRAW index` at ROT `rot`, SCALE
## `scale`, in plot order and relative to the DRAW position. A point can
## appear more than once: DRAW does not care, XDRAW toggles it each
## time, so use `xor_pixels()` for what an XDRAW leaves lit.
func plots(index: int, rot: int = 0, scale: int = 1) -> Array[Vector2i]:
	var key := Vector3i(index, rot, scale)
	if _plot_cache.has(key):
		return _plot_cache[key]
	var out: Array[Vector2i] = []
	var stream: PackedByteArray = _bytes_by_shape.get(index, PackedByteArray())
	var quadrant := (rot & 0xFF) >> 4
	var frac := rot & 0x0F
	var dx: int = COS[frac]
	var dy: int = (COS[(frac ^ 0x0F) + 1] + 1) & 0xFF
	var count := scale & 0xFF
	if count == 0:
		count = 256 # SCALE=0 loops 256 times in the ROM
	var pos := Vector2i.ZERO
	for raw in stream:
		var v: int = raw
		while true:
			var plot := (v & 4) != 0
			var ex := 0x80
			var ey := 0x80
			for _i in range(count):
				ex += dx + 1
				if ex > 0xFF:
					ex &= 0xFF
					if plot:
						out.append(pos)
					pos += DIRECTIONS[(v + quadrant) & 3]
				ey += dy
				if ey > 0xFF:
					ey &= 0xFF
					if plot:
						out.append(pos)
					pos += DIRECTIONS[(v + quadrant + 1) & 3]
			v >>= 3
			if v == 0:
				break
	_plot_cache[key] = out
	return out

## The distinct points a DRAW lights.
func pixels(index: int, rot: int = 0, scale: int = 1) -> Array[Vector2i]:
	var seen: Dictionary = {}
	for p in plots(index, rot, scale):
		seen[p] = true
	var out: Array[Vector2i] = []
	out.assign(seen.keys())
	return out

## The points an XDRAW onto a blank screen leaves lit: those plotted an
## odd number of times.
func xor_pixels(index: int, rot: int = 0, scale: int = 1) -> Array[Vector2i]:
	var lit: Dictionary = {}
	for p in plots(index, rot, scale):
		if lit.has(p):
			lit.erase(p)
		else:
			lit[p] = true
	var out: Array[Vector2i] = []
	out.assign(lit.keys())
	return out
