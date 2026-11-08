extends Node3D
## Mode-switch wrapper for the space-flight scene, standing in for
## STARSHIP SIMULATOR.bas's own mode-switch keys (RUNCOM/RUNRADAR/etc,
## line ~150/200-210) — remapped to modern keys via autoload/input_setup.gd
## rather than the original's raw PDL()/key-code checks.
##
## The `Planet` node used to be a plain placeholder SphereMesh. It's now
## built from PLANET # 0's real data — the same file ORBIT.bas actually
## loads for this exact "deep space, not yet landing" view. It's
## genuinely just 195 floating points with zero connecting edges — not
## a bug in this port, that's what the original data is. The slow
## constant spin on it is an idiomatic-Godot liberty, not in the
## original (which has no camera-relative planet rotation at all in
## this view) — purely so a static screenshot doesn't read as "nothing
## rendered."
##
## Getting close to the planet now triggers `scenes/planet_approach.tscn`
## (RE.bas's "REENTRY SEQUENCE", with the real per-world terrain map —
## PLANET # 1-20, genuinely modeled line-connected data, a different
## visual from this scene's own point-field `Planet`). Ported as a
## world-space distance check rather than the original's byte-exact
## `ABS(X)<900 AND ABS(Y)<900 AND ABS(Z)<900` box test (`STARSHIP
## SIMULATOR.bas` line 156) — this port's flight model doesn't track
## position in the original's units, and has no "weapon fired" flag
## yet to port that condition's other half (`AND PEEK(38210)=0`), so
## proximity alone is what gates it here.
##
## `[G] Ground Forces` is now actually gated on the same proximity check
## — the HUD text has said "(when in range)" since this scene was
## scaffolded, but nothing enforced it until now.

const A2_3D1_Model = preload("res://scripts/shapes/a2_3d1_model.gd")
const PLANET_VISUAL_RADIUS := 400.0 # matches the old placeholder's footprint
const PLANET_WORLD_POSITION := Vector3(0, 0, -3000) # must match the Planet node's transform below
const REENTRY_RANGE := 500.0

@onready var _debug_label: Label = $HUD/DebugLabel
@onready var _planet: MeshInstance3D = $Planet

var _reentering: bool = false


func _ready() -> void:
	var built: Dictionary = A2_3D1_Model.build_planet_mesh(0)
	_planet.mesh = built["mesh"]
	var radius: float = built["radius"]
	if radius > 0.0:
		_planet.scale = Vector3.ONE * (PLANET_VISUAL_RADIUS / radius)
	assert(_planet.position.is_equal_approx(PLANET_WORLD_POSITION), "Planet node moved — update PLANET_WORLD_POSITION to match")


func _process(delta: float) -> void:
	_planet.rotate_y(0.05 * delta)

	var in_range := _is_in_range()
	_debug_label.text = (
		"PITCH %d   BANK %d   HEADING %d   THROTTLE %.2f\nPOS %s\n\n[C] Command Console   [G] Ground Forces (%s)   [R] Radar"
		% [
			int(GameState.pitch_deg), int(GameState.bank_deg), int(GameState.heading_deg),
			GameState.throttle, GameState.ship_position,
			"in range" if in_range else "out of range",
		]
	)

	if in_range and not _reentering:
		_reentering = true
		GameState.goto_scene("res://scenes/planet_approach.tscn")


func _is_in_range() -> bool:
	return GameState.ship_position.distance_to(PLANET_WORLD_POSITION) < REENTRY_RANGE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_com"):
		GameState.goto_scene("res://scenes/com.tscn")
	elif event.is_action_pressed("open_ground_forces"):
		if _is_in_range():
			GameState.goto_scene("res://scenes/ground_forces.tscn")
	elif event.is_action_pressed("open_radar"):
		GameState.goto_scene("res://scenes/radar.tscn")
