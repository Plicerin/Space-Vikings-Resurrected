extends Node2D
## `STARSHIP SIMULATOR.bas` lines 1505-1530: the laser-fire visual. Two
## `HPLOT`-filled triangles from the cockpit's bottom corners converging
## on the target reticle, flickered 3 times (`FOR LX=1 TO 3`) — drawn then
## erased via `HCOLOR=0` in the original, ported here as a visibility
## toggle instead of redraw-to-erase. `CALL LA` (the laser sweep tone,
## confirmed decoupled from the visual — see COMBAT_VFX_ANALYSIS.md)
## now plays via AudioManager.play_laser() — see its own doc comment
## for the real routine this is synthesized from.

const APEX := Vector2(136, 60)
const BASE_OUTER := Vector2(90, 123)
const BASE_INNER := Vector2(94, 123)
const FLICKER_COUNT := 3
const FLICKER_INTERVAL := 0.05

## True (default) for combat_demo.tscn's standalone usage, where this
## node is the only thing listening for the fire-laser action. False for
## flight_combat.tscn's instance (2026-11-09 fix): there, flight_combat.gd
## already owns fire-button handling (damage math, ammo, etc.) and calls
## fire() on this node directly -- if this were also polling the same
## action itself, every real shot would double-fire (two AudioManager
## calls, the tween restarting mid-flicker).
@export var self_fire: bool = true

var _tween: Tween


func _ready() -> void:
	visible = false


func _draw() -> void:
	var left_tri := PackedVector2Array([BASE_OUTER, APEX, BASE_INNER])
	var right_tri := _mirror_triangle(left_tri)
	draw_colored_polygon(left_tri, Color.CYAN)
	draw_colored_polygon(right_tri, Color.CYAN)


# Mirrors only the base corners about the apex's X so both triangles
# converge on the same reticle point, matching "converging on the target
# reticle" rather than producing two separate aim points.
func _mirror_triangle(tri: PackedVector2Array) -> PackedVector2Array:
	var mirrored := PackedVector2Array()
	for p in tri:
		mirrored.append(Vector2(2.0 * APEX.x - p.x, p.y))
	return mirrored


func _process(_delta: float) -> void:
	# Polled rather than
	# _unhandled_input: Input.action_press() — used by the automated
	# combat-VFX test, see README — doesn't dispatch a real InputEvent, and
	# a focused UI Button would otherwise have first claim on a real
	# spacebar press anyway.
	if self_fire and Input.is_action_just_pressed("fire_laser"):
		fire()


func fire() -> void:
	AudioManager.play_laser()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	for i in range(FLICKER_COUNT):
		_tween.tween_callback(_show)
		_tween.tween_interval(FLICKER_INTERVAL)
		_tween.tween_callback(_hide)
		_tween.tween_interval(FLICKER_INTERVAL)


func _show() -> void:
	visible = true
	queue_redraw()


func _hide() -> void:
	visible = false
