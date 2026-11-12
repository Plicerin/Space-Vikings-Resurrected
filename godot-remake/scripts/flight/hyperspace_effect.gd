extends Control
## The hyperspace jump: lines thrown out from the middle of the screen, one
## burst in white as the drive takes hold and a second in black over it as
## the ship comes out (H_D.bas's two goes at line 20, 175 lines each).
## Calls `done` when it is over.

signal done

const LINES := 175
const SECONDS := 1.7

var _time := 0.0
var _ends: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 1982
	for i in LINES:
		_ends.append(Vector2(_rng.randf(), _rng.randf()))


func _process(delta: float) -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size # a canvas layer has no layout to fill
	_time += delta
	queue_redraw()
	if _time >= SECONDS:
		done.emit()
		queue_free()


func _draw() -> void:
	var middle := size * Vector2(0.5, 0.5)
	var grow := clampf(_time / (SECONDS * 0.6), 0.0, 1.0)
	var fade := clampf((_time - SECONDS * 0.6) / (SECONDS * 0.4), 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55 * grow * (1.0 - fade * 0.4)))
	for end in _ends:
		var to := end * size
		var from := middle + (to - middle) * clampf(grow * 0.25 + fade * 0.7, 0.0, 1.0)
		var tip := middle + (to - middle) * grow
		draw_line(from, tip, Color(0.45, 0.7, 1.0, 0.18 * (1.0 - fade)), 5.0, true) # the glow under the streak
		draw_line(from, tip, Color(0.92, 0.97, 1.0, 1.0 - fade * 0.8), 1.5, true)
