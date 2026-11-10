extends Node2D
## Shows an HgrScreen (the software hi-res page) as a 280x192 texture.
## Meant to sit under an HGRCanvas, which supplies the pixel scale.
## Unlit pixels are transparent, so over a 3D view only what the
## original plotted is visible; `opaque_from_row` paints the rows from
## there down black first (the instrument panel below the 3D window).
##
## `flash()` is the game's screen flash. STARSHIP SIMULATOR.bas brackets
## its hits and shots with `POKE -16298,0` ... `POKE -16297,0`: the first
## switches the display to lo-res graphics, the second back to hi-res.
## Lo-res shows the text page, which the game never prints to (its text
## goes through the hi-res character generator) and which holds $FF in
## every cell during flight, so for as long as the switch is thrown the
## whole screen is white. Seen live: tools/mame/fight_live.lua, a
## snapshot taken while the laser lines were being drawn is a plain white
## frame, and the text page dump is 960 x $FF.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const HgrScreen = preload("res://scripts/shapes/hgr_screen.gd")

const FRAME := 1.0 / 60.0

## First row to back with black; 192 = none.
@export var opaque_from_row: int = HgrScreen.HEIGHT
## Off = `flash()` does nothing (the flashes are full-screen and fast).
@export var flashes_enabled: bool = true

var screen: HgrScreen = HgrScreen.new()
var _texture: ImageTexture
var _flash_left := 0.0
var _flash_rows := Vector2i(0, HgrScreen.HEIGHT) # first row, row count
var _flash_drawn := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## White screen for `seconds`. A flash shorter than one video frame only
## caught part of one scan on the real machine, so it is drawn as a band
## of that many rows for a single frame.
func flash(seconds: float) -> void:
	if not flashes_enabled or seconds <= 0.0:
		return
	_flash_left = maxf(_flash_left, seconds)
	if seconds < FRAME:
		var rows := maxi(int(HgrScreen.HEIGHT * seconds / FRAME), 1)
		_flash_rows = Vector2i(randi() % (HgrScreen.HEIGHT - rows + 1), rows)
	else:
		_flash_rows = Vector2i(0, HgrScreen.HEIGHT)
	_flash_drawn = false
	queue_redraw()


func is_flashing() -> bool:
	return _flash_left > 0.0


func _process(delta: float) -> void:
	if _flash_left > 0.0 and _flash_drawn:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash_left = 0.0
			queue_redraw()
	if screen.is_dirty():
		queue_redraw()


func _draw() -> void:
	if opaque_from_row < HgrScreen.HEIGHT:
		draw_rect(Rect2(0, opaque_from_row, HgrScreen.WIDTH, HgrScreen.HEIGHT - opaque_from_row), Color.BLACK)
	var img := screen.image()
	if _texture == null:
		_texture = ImageTexture.create_from_image(img)
	else:
		_texture.update(img)
	draw_texture(_texture, Vector2.ZERO)
	if _flash_left > 0.0:
		draw_rect(Rect2(0, _flash_rows.x, HgrScreen.WIDTH, _flash_rows.y), Color.WHITE)
		_flash_drawn = true
