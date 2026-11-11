extends Node3D
## RADAR.bas: press R during flight (STARSHIP SIMULATOR.bas lines
## 200-206's key-dispatch chain, confirmed live in MAME — see
## A2-3D1_ENGINE_ANALYSIS.md) or choose RADAR from the Command Console
## (COM.bas line 133) to see the current planet's orbital defender as a
## real 3D wireframe (ShipBlip, built from the actual A2-3D1 bytecode
## model — see scripts/shapes/a2_3d1_model.gd) inside the radar
## border/crosshair HUD (RadarHud, scripts/ui/radar_hud.gd).
##
## Original behavior (line 2050's blocking `GET A$`): any key returns
## to flight except X, which goes to the plain-text ship-identification
## screen (`SHIP no N I.D..bas` — line 2056/5005's `RUN SHIP # J I.D.`,
## see scripts/ui/ship_id_screen.gd).
##
## Idiomatic-Godot liberty, not in the original: a slow constant spin on
## the ship model. The original's view is static while GET A$ blocks;
## this is purely to make "it's a real rotating 3D model, not a static
## sprite" legible at a glance. Remove _process() below if that turns
## out to read as inauthentic rather than additive.

const A2_3D1_Model = preload("res://scripts/shapes/a2_3d1_model.gd")

const SPIN_SPEED := 0.3 # radians/sec — see doc comment above

@onready var _ship_blip: MeshInstance3D = $ShipBlip
@onready var _info_label: Label = $HUD/InfoLabel
@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	var tier: int = GameState.orbital_defender_tier
	var built: Dictionary = A2_3D1_Model.build_ship_mesh(tier)
	_ship_blip.mesh = built["mesh"]

	# Auto-frame the camera from the model's own bounding radius -- the
	# four real ship files span wildly different absolute sizes (see
	# a2_3d1_model.gd's doc comment), so a fixed distance either clips
	# big ones or leaves small ones a speck. 2.2x radius + a floor for
	# the empty tier-0 case keeps the crosshair itself nicely framed
	# even with no ship to show.
	var radius: float = built["radius"]
	var distance: float = max(radius * 9.0, 400.0) # see doc comment above
	_camera.position = Vector3(0.6, 0.45, 1.0).normalized() * distance
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	# Defensive: Camera3D's default far-clip (4000) would silently clip anything
	# auto-framed further out than that.
	_camera.far = distance * 3.0

	var desc: String = GameState.DEFENDER_TIER_LABELS.get(tier, "UNIDENTIFIED CONTACT.")
	_info_label.text = "%s\n\n[any key] return     [X] ship I.D." % desc


func _process(delta: float) -> void:
	_ship_blip.rotate_y(SPIN_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.physical_keycode == KEY_X:
		GameState.goto_scene("res://scenes/ship_id.tscn")
	else:
		GameState.goto_scene("res://scenes/flight/space_flight.tscn")
