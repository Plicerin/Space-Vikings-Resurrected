extends Control
## Standalone combat-VFX demo: fighter approach/retreat/explosion, the
## laser-fire visual, the EX.bas ship-destruction sequence, and the
## separate incoming-fire pattern — see COMBAT_VFX_ANALYSIS.md for the
## source trace each one ports. Reachable from the Start screen like the
## shape-table viewer; not yet wired into an actual encounter-spawn
## trigger inside space_flight.tscn, since no "when does a fighter
## encounter start" condition has been traced in the analysis docs.

const ENEMY_SHAPES := "res://assets/shapes/ENEMY I.A24580.L68.payload.json"

@onready var _spawn_fighters_btn: Button = $VBox/Buttons/SpawnFightersButton
@onready var _spawn_incoming_btn: Button = $VBox/Buttons/SpawnIncomingButton
@onready var _destroy_ship_btn: Button = $VBox/Buttons/DestroyShipButton
@onready var _back_btn: Button = $VBox/Buttons/BackButton
@onready var _status: Label = $VBox/Status

@onready var _fighter_encounter = $HGRCanvas/FighterEncounter
@onready var _incoming_fire = $HGRCanvas/IncomingFire
@onready var _ship_destruction = $HGRCanvas/ShipDestruction


func _ready() -> void:
	var table := ShapeTable.load_file(ENEMY_SHAPES)
	_fighter_encounter.table = table
	_incoming_fire.table = table
	_ship_destruction.table = table

	_spawn_fighters_btn.pressed.connect(func() -> void:
		_status.text = "Fighter encounter incoming — fire (SPACE/CTRL) before they close in, or let them retreat."
		_fighter_encounter.start_encounter()
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

	_fighter_encounter.encounter_resolved.connect(func(destroyed: bool) -> void:
		_status.text = "Fighters destroyed." if destroyed else "Fighters retreated — no hit."
	)
	_incoming_fire.finished.connect(func() -> void:
		_status.text = "Incoming-fire pattern finished."
	)
	_ship_destruction.finished.connect(func() -> void:
		_status.text = "EX.bas sequence finished — wreckage left behind."
	)
