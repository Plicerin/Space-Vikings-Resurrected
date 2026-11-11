extends RefCounted
## The game's "display databases" (assets/a2_3d1/*.bin, the files A2-3D1
## drew) read as data: the points and the lines of the models, in the
## original's world. The engine that drew them is not in the game any
## more; what these files hold is positions.
##
## A database is a list of records, the first byte of each its opcode:
## 0 is a point, 1 the start of a line and 2 and 3 its continuations (x, y,
## z each a signed 16-bit word, low byte first), 4 a flag, 5 the eye, 7, 8,
## 9 the display's switches, 14 the window, 15 the scale factors; from $12
## up the list ends.

const ASSETS := "res://assets/a2_3d1/"
const LENGTHS := {0: 7, 1: 7, 2: 7, 3: 7, 4: 2, 5: 10, 7: 2, 8: 2, 9: 2, 14: 5, 15: 7}

## The points (opcode 0), as the original has them.
var points := PackedVector3Array()
## The lines, two ends a line, in order (opcodes 1, 2 and 3: a line from
## a start to its end, one on from the last end, one back to it).
var lines := PackedVector3Array()


static func load_file(name: String) -> RefCounted:
	var list: RefCounted = (load("res://scripts/world/display_list.gd") as GDScript).new()
	var data := FileAccess.get_file_as_bytes(ASSETS + name)
	var at := 0
	var last_end := Vector3.ZERO
	while at < data.size():
		var op := data[at]
		if op >= 0x12 or not LENGTHS.has(op):
			break
		var here := Vector3(_word(data, at + 1), _word(data, at + 3), _word(data, at + 5)) if op <= 3 else Vector3.ZERO
		match op:
			0:
				list.points.append(here)
			1: # the next record is the end of the line
				var end := Vector3(_word(data, at + 8), _word(data, at + 10), _word(data, at + 12))
				list.lines.append(here)
				list.lines.append(end)
				last_end = end
				at += 7 # and the end's seven bytes
			2:
				list.lines.append(last_end)
				list.lines.append(here)
				last_end = here
			3:
				list.lines.append(here)
				list.lines.append(last_end)
		at += LENGTHS[op]
	return list


static func _word(data: PackedByteArray, at: int) -> int:
	var v := data[at] | (data[at + 1] << 8)
	return v - 0x10000 if v & 0x8000 else v
