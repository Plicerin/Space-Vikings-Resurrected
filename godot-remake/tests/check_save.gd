extends Node
## SAVE GAME and an old game loaded (END.bas 190-220, START.bas
## 3000-3020 and 220-250; GameState.save_to_disk(), load_from_disk()),
## the planet record's seventeenth byte (load_planet_record()), the
## boot that uses the saved game up (START.bas 25-26, boot()) and the
## way an old game comes to flight (flight_loop.gd, run()), which is
## held to the live run of tools/mame/save_live.lua: the four switches
## as they were saved, and the lamps painted by GALAXY MAP's line 2.
##
##   godot --headless --path godot-remake res://tests/check_save.tscn
##
## Saves to a file of its own, not the player's.

const PATH := "user://check_save.json"
const FlightLoop = preload("res://scripts/flight/flight_loop.gd")
const CombatFx = preload("res://scripts/combat/combat_fx.gd")
## Where the live run's ship was when it saved, three passes into a new
## game (the bytes END.bas put in SOL's record on that disk).
const LIVE_SAVED_Z := -6641

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

	# START.bas 25-26: the boot finds the game and takes the mark away
	GameState.boot(PATH)
	_check("the boot after a save finds an old game", GameState.old_game)
	GameState.boot(PATH)
	_check("the boot after that finds none", not GameState.old_game)

	GameState.start_new_game()
	GameState.instruments_due = false
	GameState.load_from_disk(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameState.boot(PATH)
	_check("nor does a boot with no file", not GameState.old_game)
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
	_check("and to leave the lamps to GALAXY MAP", GameState.saved_marker)

	await _old_game_to_flight()

	print("save and load: %d wrong" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


## A game saved as the live run saved it (a new game's first flight:
## manual, RED, shields down, missile), loaded, and the flight loop run
## to its first pass.
func _old_game_to_flight() -> void:
	GameState.start_new_game()
	var first := FlightLoop.new()
	first.program.instruments()
	var switches := [GameState.shields_up, GameState.missile_mode_active,
			GameState.condition, GameState.autopilot_active]
	_check("a new game's panel flips the switches (%s)" % str(switches),
			switches == [false, true, 3, false])
	GameState.ship_z = LIVE_SAVED_Z
	GameState.save_to_disk(PATH)
	GameState.start_new_game()
	GameState.load_from_disk(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

	var loop := FlightLoop.new()
	var fx := CombatFx.new()
	fx.instant = true
	fx.screen = GameState.view3d.pages[0]
	add_child(fx)
	loop.setup(fx)
	var waited := [0.0]
	loop.wait = func(frames: float) -> void: waited[0] += frames
	# the live page was taken at the third pass
	var passes := [0]
	loop.pass_started = func() -> void:
		passes[0] += 1
		loop.stop = passes[0] == 3
	await loop.run()
	switches = [GameState.shields_up, GameState.missile_mode_active,
			GameState.condition, GameState.autopilot_active]
	_check("an old game's leaves them as saved (%s)" % str(switches),
			switches == [false, true, 3, false])
	_check("the mark is taken off by GALAXY MAP", not GameState.saved_marker)
	var live := FileAccess.get_file_as_bytes("../analysis/live/save/old_flight_p1.bin")
	var page: PackedByteArray = GameState.view3d.pages[0].mem
	var different := 0
	var where: Array[String] = []
	for row in range(126, 192): # the panel
		for column in range(40):
			if page[row * 40 + column] != live[row * 40 + column]:
				different += 1
				where.append("row %d byte %d: %02X, live %02X" % [row, column,
						page[row * 40 + column], live[row * 40 + column]])
	_check("the panel and its lamps are the live run's (%d bytes different) %s" % [different, ", ".join(where.slice(0, 6))],
			live.size() == page.size() and different == 0)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok   " if ok else "WRONG", what])
	if not ok:
		_bad += 1
