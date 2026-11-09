extends Control
## Standalone combat-VFX demo: the missile strike against the orbital
## defender (hit/miss), the laser-fire visual, the EX.bas
## ship-destruction sequence, and the separate incoming-fire pattern —
## see COMBAT_VFX_ANALYSIS.md for the source trace each one ports.
## Reachable from the Start screen like the shape-table viewer. The
## missile strike is now also wired into real flight (see
## `flight_combat.gd`'s `fire_missile()`) — this demo lets you preview
## both outcomes directly instead of having to actually aim/range a
## live encounter.

const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const ENEMY_SHAPES := "res://assets/shapes/ENEMY I.A24580.L68.payload.json"

@onready var _spawn_missile_hit_btn: Button = $VBox/Buttons/SpawnMissileHitButton
@onready var _spawn_missile_miss_btn: Button = $VBox/Buttons/SpawnMissileMissButton
@onready var _spawn_incoming_btn: Button = $VBox/Buttons/SpawnIncomingButton
@onready var _destroy_ship_btn: Button = $VBox/Buttons/DestroyShipButton
@onready var _back_btn: Button = $VBox/Buttons/BackButton
@onready var _status: Label = $VBox/Status

@onready var _missile_strike = $HGRCanvas/MissileStrike
@onready var _incoming_fire = $HGRCanvas/IncomingFire
@onready var _ship_destruction = $HGRCanvas/ShipDestruction


func _ready() -> void:
	var table := ShapeTable.new()
	table.load_shapes(ENEMY_SHAPES)
	_missile_strike.table = table
	_incoming_fire.table = table
	_ship_destruction.table = table

	_spawn_missile_hit_btn.pressed.connect(func() -> void:
		_status.text = "Missile strike incoming — in range and aimed."
		_missile_strike.start_strike(true)
	)
	_spawn_missile_miss_btn.pressed.connect(func() -> void:
		_status.text = "Missile strike incoming — out of range or off-aim."
		_missile_strike.start_strike(false)
	)
	_spawn_incoming_btn.pressed.connect(func() -> void:
		_status.text = "Incoming-fire pattern running."
		_incoming_fire.start()
	)
	_destroy_ship_btn.pressed.connect(func() -> void:
		_status.text = "EX.bas ship-destruction sequence."
		_ship_destruction.play()
	)
	_back_btn.pressed.connect(func() -> void: GameState.goto_scene("res://scenes/start.tscn"))

	_missile_strike.strike_resolved.connect(func(hit: bool) -> void:
		_status.text = "Direct hit on the orbital defender." if hit else "Missile missed/self-destructed — no hit."
	)
	_incoming_fire.finished.connect(func() -> void:
		_status.text = "Incoming-fire pattern finished."
	)
	_ship_destruction.finished.connect(func() -> void:
		_status.text = "EX.bas sequence finished — wreckage left behind."
	)
