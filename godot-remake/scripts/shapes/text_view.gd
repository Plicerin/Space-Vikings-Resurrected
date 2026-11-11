extends Node2D
## Shows a TextScreen (the Apple's text screen) as a 280x192 texture,
## white on black. Meant to sit under an HGRCanvas, like HgrView.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const TextScreen = preload("res://scripts/shapes/text_screen.gd")

var screen: TextScreen = TextScreen.new()
var _texture: ImageTexture
var _shown: TextScreen


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	if screen != _shown or screen.is_dirty():
		queue_redraw()


func _draw() -> void:
	_shown = screen
	var img := screen.image()
	if _texture == null:
		_texture = ImageTexture.create_from_image(img)
	else:
		_texture.update(img)
	draw_texture(_texture, Vector2.ZERO)
