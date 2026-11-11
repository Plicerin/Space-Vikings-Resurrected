extends Node
## SAVE GAME and an old game loaded (END.bas 190-220, START.bas
## 3000-3020 and 220-250; GameState.save_to_disk(), load_from_disk()),
## and the planet record's seventeenth byte (load_planet_record()).
##
##   godot --headless --path godot-remake res://tests/check_save.tscn
##
## Saves to a file of its own, not the player's.

const PATH := "user://check_save.json"

var _bad := 0


func _ready() -> void:
	GameState.start_new_game()
	# 38220 at SOL in a new game is ALPHA CENTAURI's threshold (seen
	# live: analysis/live/jump/jump_live.log has secured=100).
	_check("a new game has 100 for SOL's secured byte", GameState.planet_secured[0] == 100)

	# Securing SOL while there writes 1 over that byte, and leaving
	# stores it as the next planet's threshold.
	GameState.planet_secured[0] = 1
	GameState.store_planet_record(0)
	_check("stored at SOL, the byte is ALPHA CENTAURI's threshold",
			GameState.planet_defender_threshold[1] == 1.0)
	GameState.load_planet_record(19)
	_check("at SHIVANDA it is the byte after the table, 255", GameState.planet_secured[0] == 255)

	GameState.start_new_game()
	GameState.current_planet = 6
	GameState.load_planet_record(6)
	GameState.ship_x = -1234
	GameState.ship_y = 567
	GameState.ship_z = 8910
	GameState.ship_pitch = 11
	GameState.ship_bank = 222
	GameState.ship_heading = 133
	GameState.ship_speed = 42
	GameState.credits = 4321.0
	GameState.planet_scouted[6] = true
	var secured: Array = GameState.planet_secured.duplicate()
	var thresholds: Array = GameState.planet_defender_threshold.duplicate()
	GameState.save_to_disk(PATH)

	GameState.start_new_game()
	GameState.instruments_due = false
	GameState.load_from_disk(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_check("the planet", GameState.current_planet == 6)
	_check("the ship's place", [GameState.ship_x, GameState.ship_y, GameState.ship_z]
			== [-1234, 567, 8910])
	_check("its attitude", [GameState.ship_pitch, GameState.ship_bank, GameState.ship_heading]
			== [11, 222, 133])
	_check("its speed", GameState.ship_speed == 42)
	_check("the credits", GameState.credits == 4321.0)
	_check("the scouted flags", GameState.planet_scouted[6] and not GameState.planet_scouted[5])
	_check("the secured bytes", GameState.planet_secured == secured)
	_check("the thresholds", GameState.planet_defender_threshold == thresholds)
	_check("INSTRUMENTS is to draw the panel", GameState.instruments_due)

	print("save and load: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1
