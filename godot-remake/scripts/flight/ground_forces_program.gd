extends RefCounted
## GROUND FORCES, with RECALL and COLLECT: the menu and the battle, on the CRT
## console, with the planet as a vector globe over the front window (the enemy's
## lights going from red to ours as the landing takes them). What a command
## does and what the crew says of it is scripts/rules/ground_rules.gd, which is
## held to the real game (tests/check_ground_rules.gd); this shows it and
## keeps the time. Commands 3 to 8 are shore_leave_program.gd's.
##
## Where it parts from the original, on purpose:
## - a refusal or a recall is said under the menu, which stays up; the original
##   cleared its window and ran the program again;
## - the battle is called off with R. The original took any key for it. As
##   there, the order is obeyed after the round in hand, which is fought and
##   paid for;
## - the pauses between reports are about the original's
##   (analysis/live/ground/README.md), but a key moves on. The rounds keep
##   their beat.

const GroundRules = preload("res://scripts/rules/ground_rules.gd")
const ShoreRules = preload("res://scripts/rules/shore_rules.gd")
const ShoreProgram = preload("res://scripts/flight/shore_leave_program.gd")

# Seconds.
const REPORT := 3.0    ## a report from the landing
const ROUND := 2.3
const SURRENDER := 5.0
const LOOT := 6.0      ## each of COLLECT's two reports
const ENDED := 4.0     ## a battle lost or broken off
const BRIEF := 1.0     ## the battle screen put up and taken down with nothing said

const COMMANDS := ["ATTACK PLANET", "RECALL TROOPS", "SHORE LEAVE", "ENLIST TROOPS", "SELL LOOT", "REPAIR/RESTOCK",
		"ESTABLISH BASE", "CRYOGENICS", "RETURN"]

var _rules: GroundRules
var _console: Node
var _globe: Control
var _retreat := false
var _fighting := false
var _shown: Array = [] ## what the battle screen is saying, and the success on it
var _shown_success := -1.0
## What the battle screen has said, in order (a test reads it).
var heard: Array = []


## Runs the program until RETURN (9).
func run(console: Node, globe: Control) -> void:
	_console = console
	_globe = globe
	_console.key_pressed.connect(_key)
	globe.visible = true
	var said: Array = []
	while true:
		_rules = GroundRules.new()
		_rules.open_menu()
		_globe.capture = 1.0 if GameState.gf_planet_surrendered else (clampf(GameState.gf_victory_progress / GameState.gf_enemy_strength, 0.0, 1.0) if GameState.gf_enemy_strength > 0.0 else 0.0)
		var number: int = await _console.menu("GROUND FORCES", COMMANDS, said)
		said = await _command(number)
		if number == 9 and said.is_empty():
			break
	_console.key_pressed.disconnect(_key)
	globe.visible = false
	_console.close()


## @witness GROUND FORCES 60-75
## Returns what to say under the menu next.
func _command(number: int) -> Array:
	var why := _rules.refusal(number)
	if not why.is_empty():
		return why
	match number:
		1:
			await _attack()
		2:
			return _rules.recall()
		9:
			return []
		_:
			return await _shore(number)
	return []


## Commands 3 to 8, SHORE LEAVE.bas's six.
## @witness GROUND FORCES 2150-2190
func _shore(number: int) -> Array:
	var why := ShoreRules.refusal(number)
	if not why.is_empty():
		return why
	await ShoreProgram.new().run(_console, number)
	return []


func _key(keycode: int) -> void:
	if _fighting and keycode == KEY_R and not _retreat:
		_retreat = true
		_console.show(_battle_lines(_shown, _shown_success)) # RETREAT ORDERED, at once


## The battle screen: the five counts, the projection and what has been said.
func _battle_lines(said: Array, success: float = -1.0) -> Array:
	var lines: Array = ["-GROUND FORCES-",
			_console.columns("FIGHTERS %d" % _rules.fighters, "TRANSPORTS %d" % _rules.transports),
			_console.columns("TROOPS %d" % _rules.troops, "TANKS %d" % _rules.tanks),
			_console.columns("MISSILES %d" % _rules.missiles, "SUCCESS %d%%" % success if success >= 0.0 else "")]
	lines.append_array(_console.flow(said))
	if _fighting:
		lines.append("R  RETREAT" if not _retreat else "RETREAT ORDERED")
	return lines


func _tell(said: Array, seconds: float, success: float = -1.0, skippable := true) -> void:
	heard.append("\n".join(said))
	await _console.say(_battle_lines(said, success), seconds, skippable)


func _attack() -> void:
	var landing := _rules.begin_attack()
	_retreat = false
	match landing:
		GroundRules.Landing.NOTHING:
			await _console.say(_battle_lines([]), BRIEF)
		GroundRules.Landing.NO_TRANSPORTS:
			await _tell(GroundRules.SAID_NO_TRANSPORTS, REPORT)
		_:
			for line in _rules.departure():
				await _tell([line], REPORT)
			for report: Array in _rules.land():
				await _tell(report, REPORT)
			if landing == GroundRules.Landing.BATTLE:
				await _fight()


## @witness COLLECT 17
func _fight() -> void:
	_fighting = true
	_shown = []
	while true:
		var outcome := _rules.fight(_retreat)
		AudioManager.play_tick()
		var success := 100.0 if outcome == GroundRules.Outcome.SURRENDERED else _rules.success
		_globe.capture = clampf(_rules.progress / maxf(_rules.enemy, 0.01), 0.0, 1.0) if outcome != GroundRules.Outcome.SURRENDERED else 1.0
		if outcome == GroundRules.Outcome.FIGHTING:
			_shown_success = success
			await _console.say(_battle_lines(_shown, success), ROUND, false)
			continue
		_fighting = false
		match outcome:
			GroundRules.Outcome.SURRENDERED:
				AudioManager.play_capture()
				await _tell(GroundRules.SAID_SURRENDERED, SURRENDER, success)
				await _tell(GroundRules.SAID_COLLECTING, REPORT, success)
				for report: Array in _rules.collect():
					await _tell(report, LOOT, success)
			GroundRules.Outcome.LOST:
				await _tell(GroundRules.SAID_LOST, ENDED, success)
			GroundRules.Outcome.RETREATED:
				await _tell(GroundRules.SAID_RETREATING, ENDED, success)
		return
