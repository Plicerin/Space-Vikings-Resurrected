extends Node
## Writes the shape table's contact sheet (see shape_view.gd) to a PNG
## and quits. The hi-res page is rasterised in software, so this works
## headless:
##
##   godot --headless --path godot-remake res://scenes/contact_sheet.tscn \
##     -- --out=/tmp/shapes.png --rot=0 --scale=1
##
## All three arguments are optional (default: user://shape_sheet.png,
## ROT 0, SCALE 1). The image is the 280x192 page enlarged three times.

const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")
const ShapeView = preload("res://scripts/shape_view.gd")


func _ready() -> void:
	var out_path := "user://shape_sheet.png"
	var rot := 0
	var shape_scale := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.substr("--out=".length())
		elif arg.begins_with("--rot="):
			rot = int(arg.substr("--rot=".length()))
		elif arg.begins_with("--scale="):
			shape_scale = int(arg.substr("--scale=".length()))

	var table := ShapeTable.new()
	table.load_shapes(ShapeView.ENEMY_SHAPES)
	var screen := HgrScreen.new()
	ShapeView.draw_sheet(screen, table, rot, shape_scale)

	var page := screen.image()
	var sheet := Image.create(HgrScreen.WIDTH, HgrScreen.HEIGHT, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	sheet.blend_rect(page, Rect2i(0, 0, HgrScreen.WIDTH, HgrScreen.HEIGHT), Vector2i.ZERO)
	sheet.resize(HgrScreen.WIDTH * 3, HgrScreen.HEIGHT * 3, Image.INTERPOLATE_NEAREST)
	var err := sheet.save_png(out_path)
	if err != OK:
		push_error("contact_sheet: could not write %s (%d)" % [out_path, err])
		get_tree().quit(1)
		return
	print("contact_sheet: wrote %s" % out_path)
	get_tree().quit()
