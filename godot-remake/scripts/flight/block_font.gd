extends RefCounted
## The game's own 7x8 character table (assets/fonts/character_table.json, from
## the disk's CHARACTER TABLE) drawn as the block letters it holds, for a CRT
## display: each glyph is cut from a small atlas and drawn at any scale (the
## texture is filtered, so the dots soften as a phosphor's do) with a glow.

const TABLE := "res://assets/fonts/character_table.json"
const ADVANCE := 7.0 ## dots from one letter to the next
const HEIGHT := 8.0

static var _atlas: ImageTexture


static func _build() -> ImageTexture:
	if _atlas != null:
		return _atlas
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	var bytes: Array = data["bytes"]
	var image := Image.create(16 * 8, 8 * 8, false, Image.FORMAT_RGBA8)
	for code in 128:
		var cell := Vector2i((code % 16) * 8, (code / 16) * 8)
		for row in 8:
			var bits := int(bytes[code * 8 + row])
			for column in 7:
				if bits & (1 << column):
					image.set_pixel(cell.x + column, cell.y + row, Color.WHITE)
	_atlas = ImageTexture.create_from_image(image)
	return _atlas


static func width(text: String, scale: float) -> float:
	return text.length() * ADVANCE * scale


## Draws `text` (upper case) with its top left at `at`, each dot `scale` pixels.
static func draw(canvas: CanvasItem, text: String, at: Vector2, scale: float, colour: Color) -> void:
	var atlas := _build()
	text = text.to_upper()
	for pass_ in 2: # a soft glow under, then the letters
		var glow := pass_ == 0
		var tint := Color(colour, 0.22) if glow else colour
		var grow := 0.9 if glow else 0.0
		for i in text.length():
			var code := text.unicode_at(i)
			if code < 33 or code > 126:
				continue
			var source := Rect2((code % 16) * 8, (code / 16) * 8, 8, 8)
			var target := Rect2(at + Vector2(i * ADVANCE * scale - grow, -grow), Vector2(8.0 * scale + grow * 2.0, 8.0 * scale + grow * 2.0))
			canvas.draw_texture_rect_region(atlas, target, source, tint)


## `text` broken into lines no wider than `limit` pixels at `scale`.
static func wrap(text: String, scale: float, limit: float) -> Array:
	var per_line := maxi(int(limit / (ADVANCE * scale)), 1)
	var lines := []
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" "):
			if line != "" and line.length() + 1 + word.length() > per_line:
				lines.append(line)
				line = word
			else:
				line = word if line == "" else line + " " + word
		lines.append(line)
	return lines
