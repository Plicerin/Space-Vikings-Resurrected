extends SceneTree
## Turns font_source/space_vikings.ttf into assets/fonts/space_vikings.res, a
## font with its data inside, which loads without the editor's import cache
## (a fresh clone has no .godot/):
##   godot --headless --path godot-remake -s tools_make_font_res.gd

func _init() -> void:
	var font := FontFile.new()
	font.load_dynamic_font("res://font_source/space_vikings.ttf")
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.generate_mipmaps = false
	font.allow_system_fallback = true
	font.disable_embedded_bitmaps = true
	var err := ResourceSaver.save(font, "res://assets/fonts/space_vikings.res")
	print("saved: ", err)
	quit(err)
