extends SceneTree
## Holds scripts/shapes/a2_3d1_view.gd to the pictures of the reference
## port (tools/a2_3d1_view.py, itself byte-identical to the machine code):
## every view in a2_3d1_vectors.json must give the same hi-res page.
##
##   godot --headless --path godot-remake -s res://tests/check_a2_3d1.gd
##
## New vectors: python3 -I tools/a2_3d1_view.py vectors godot-remake/tests/a2_3d1_vectors.json 8

const A2View = preload("res://scripts/shapes/a2_3d1_view.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")

var _crc_table := PackedInt64Array()


func _init() -> void:
	for n in range(256):
		var c := n
		for k in range(8):
			c = (0xEDB88320 ^ (c >> 1)) if c & 1 else (c >> 1)
		_crc_table.append(c)
	var text := FileAccess.get_file_as_string("res://tests/a2_3d1_vectors.json")
	var vectors: Array = JSON.parse_string(text)
	var page_1 := HgrScreen.new()
	var page_2 := HgrScreen.new()
	var bad := 0
	var started := Time.get_ticks_msec()
	for v in vectors:
		var view := A2View.new(page_1, page_2)
		view.load_planet(int(v["planet"]))
		var ship = v["ship"]
		if ship is String:
			view.load_debris()
		elif ship != null:
			view.load_ship(int(ship))
		for i in range(3):
			view.poke_word(A2View.EYE + 2 * i, int(v["eye"][i]))
			view.poke(A2View.EYE + 6 + i, int(v["attitude"][i]))
		var page := int(v["page"])
		view.poke(A2View.SHOWN_BYTE, 0x54 if page == 2 else 0x55)
		view.poke(A2View.CLEAR_BYTE, 1 if page == 2 else 0)
		view.poke(A2View.TARGET_BYTE, 1 if page == 2 else 0)
		view.run()
		var picture: PackedByteArray = view.pages[page - 1].mem
		var lit := 0
		for value in picture:
			if value != 0:
				lit += 1
		var crc := _crc32(picture)
		if crc != int(v["crc"]) or lit != int(v["lit"]):
			bad += 1
			print("DIFFERENT planet %s ship %s eye %s attitude %s: %d bytes lit, expected %d" % [
				v["planet"], v["ship"], v["eye"], v["attitude"], lit, int(v["lit"])])
	print("%d views, %d different (%d ms)" % [vectors.size(), bad, Time.get_ticks_msec() - started])
	quit(1 if bad > 0 else 0)


func _crc32(data: PackedByteArray) -> int:
	var c := 0xFFFFFFFF
	for value in data:
		c = _crc_table[(c ^ value) & 0xFF] ^ (c >> 8)
	return c ^ 0xFFFFFFFF
