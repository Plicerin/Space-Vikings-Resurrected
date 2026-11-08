extends Node3D
## `RE.bas` ("REENTRY SEQUENCE START", confirmed from its own on-screen
## text): reached automatically when flying close enough to the current
## planet without having fired (`STARSHIP SIMULATOR.bas` line 156's
## `IF ABS(X)<900 AND ABS(Y)<900 AND ABS(Z)<900 AND PEEK(38210)=0 THEN
## PRINT "RUNRE"` — ported as a world-space distance check in
## `space_flight.gd` rather than byte-exact box bounds, since this
## port's flight model doesn't track position in the original's exact
## units). `BLOAD PLANET # `;`PEEK(38209)` (line 30) loads the *real*
## per-world terrain map for whichever planet this is — genuinely
## modeled, line-connected data, a different visual from the generic
## point-field planet seen during ordinary flight (see
## `space_flight.gd`'s own doc comment and
## `A2-3D1_ENGINE_ANALYSIS.md`'s "Planet point-field" section).
##
## Liberty, not in the original: after the sequence, this port nudges
## the ship back away from the planet before returning to flight. The
## original's `RE.bas` hands back to `STARSHIP SIMULATOR.bas` without
## resetting position at all — fine there, since its world-position
## variables keep evolving every frame regardless, so normal flight
## drifts back out of the trigger box on its own. This port's distance
## check would otherwise refire every frame the instant control
## returns, since nothing else moves the ship meanwhile.

const A2_3D1_Model = preload("res://scripts/shapes/a2_3d1_model.gd")
const DISPLAY_SECONDS := 3.0
const RETURN_PUSHBACK := 1500.0 # world units, away from the planet

@onready var _terrain: MeshInstance3D = $Terrain
@onready var _camera: Camera3D = $Camera3D
@onready var _label: Label = $HUD/Label

var _returned: bool = false


func _ready() -> void:
	var built: Dictionary = A2_3D1_Model.build_planet_mesh(GameState.current_planet)
	_terrain.mesh = built["mesh"]
	var radius: float = built["radius"]
	var distance: float = max(radius * 2.5, 300.0)
	_camera.position = Vector3(0.5, 0.8, 1.0).normalized() * distance
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	# Camera3D's default far-clip (4000) clips anything at this
	# distance once a model's real radius pushes it out far enough —
	# PLANET # 0's own ~15000-unit radius (far bigger than any real
	# per-world terrain map, but reachable if this scene is ever asked
	# to show it) silently rendered nothing before this fix.
	_camera.far = distance * 3.0

	_label.text = "REENTRY SEQUENCE START\n\nPLANET %d" % GameState.current_planet
	await get_tree().create_timer(DISPLAY_SECONDS).timeout
	_return_to_flight()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_return_to_flight()


func _return_to_flight() -> void:
	if _returned:
		return
	_returned = true
	# Push back along the ship's approach direction (toward the origin,
	# away from the planet at Z=-3000 — see space_flight.gd) so flight
	# doesn't immediately re-trigger this same sequence — see doc
	# comment above.
	GameState.ship_position = GameState.ship_position.move_toward(Vector3.ZERO, RETURN_PUSHBACK)
	GameState.goto_scene("res://scenes/flight/space_flight.tscn")
