extends Node3D
## Mode-switch wrapper for the space-flight scene, standing in for
## STARSHIP SIMULATOR.bas's own mode-switch keys (RUNCOM/RUNRADAR/etc,
## line ~150/200-210) — remapped to modern keys via autoload/input_setup.gd
## rather than the original's raw PDL()/key-code checks.
##
## The `Planet` node used to be a plain placeholder SphereMesh. It's now
## built from PLANET # 0's real data — the same file ORBIT.bas actually
## loads for this exact "deep space, not yet landing" view (RE.bas's
## real per-world terrain maps, PLANET # 1-20, are a separate thing —
## see A2-3D1_ENGINE_ANALYSIS.md's "Planet point-field" section; not
## wired into flight yet since there's no re-entry scene/trigger here).
## It's genuinely just 195 floating points with zero connecting edges —
## not a bug in this port, that's what the original data is. The slow
## constant spin on it is an idiomatic-Godot liberty, not in the
## original (which has no camera-relative planet rotation at all in
## this view) — purely so a static screenshot doesn't read as "nothing
## rendered."

const A2_3D1_Model = preload("res://scripts/shapes/a2_3d1_model.gd")
const PLANET_VISUAL_RADIUS := 400.0 # matches the old placeholder's footprint

@onready var _debug_label: Label = $HUD/DebugLabel
@onready var _planet: MeshInstance3D = $Planet


func _ready() -> void:
	var built: Dictionary = A2_3D1_Model.build_planet_mesh(0)
	_planet.mesh = built["mesh"]
	var radius: float = built["radius"]
	if radius > 0.0:
		_planet.scale = Vector3.ONE * (PLANET_VISUAL_RADIUS / radius)


func _process(delta: float) -> void:
	_planet.rotate_y(0.05 * delta)
	_debug_label.text = (
		"PITCH %d   BANK %d   HEADING %d   THROTTLE %.2f\nPOS %s\n\n[C] Command Console   [G] Ground Forces (when in range)   [R] Radar"
		% [
			int(GameState.pitch_deg), int(GameState.bank_deg), int(GameState.heading_deg),
			GameState.throttle, GameState.ship_position,
		]
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_com"):
		GameState.goto_scene("res://scenes/com.tscn")
	elif event.is_action_pressed("open_ground_forces"):
		GameState.goto_scene("res://scenes/ground_forces.tscn")
	elif event.is_action_pressed("open_radar"):
		GameState.goto_scene("res://scenes/radar.tscn")
