extends Node2D
## `SHIP no N I.D..bas` — the plain-text ship identification screen,
## reached by pressing `X` on radar (`RADAR.bas` line 2056/5005's
## `RUN SHIP # J I.D.`). The *third* ship-rendering system in this
## game: an inline `DATA`-point 2D point-plotter, distinct from both
## the `ENEMY` Applesoft shape table (combat) and the real `A2-3D1`
## bytecode `SHIP # N` models (radar) — see
## scripts/shapes/a2_3d1_model.gd's doc comment.
##
## Draws its silhouette *twice*, at two different Y origins (the
## original's own behavior, not a bug introduced here — see
## tools/decode_ship_id.py's doc comment): a top-down view and a side
## profile of the same ship, confirmed by eye against the real decoded
## data for SHIP no 3/4 specifically.
##
## Layout liberty, not in the original: the original places the
## description text beside the drawing (`HTAB 25`, the right ~40% of
## the screen); this port puts it below instead, matching the layout
## this port's own other new screens (radar, re-entry) already use.
## `[any key] return` always goes back to radar (`RUN RADAR`, the
## original's own unconditional behavior on every one of the four real
## `SHIP no N I.D..bas` files).

@onready var _drawing: Node2D = $HgrCanvas/ShipIdDrawing
@onready var _label: Label = $HUD/InfoLabel


func _ready() -> void:
	var tier: int = GameState.planet_orbital_defender_tier[GameState.current_planet]
	_drawing.tier = tier
	var desc: String = GameState.DEFENDER_TIER_LABELS.get(tier, "UNIDENTIFIED CONTACT.")
	_label.text = "-SHIP I.D.-\n\n%s\n\n[any key] return" % desc


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		GameState.goto_scene("res://scenes/radar.tscn")
