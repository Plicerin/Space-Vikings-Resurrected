extends RefCounted
## The flight program on the clock. flight_program.gd and flight_combat.gd
## are the original's statements with no time in them; this is the order
## they run in and how long the real machine took over each, from the
## moment STARSHIP SIMULATOR is run until it hands over to another
## program that has its own scene.
##
## `run()` is a coroutine. Everything that takes time goes through
## `wait`, which the scene (space_flight.gd) points at a real clock and
## the tests (tests/check_flight_passes.gd) at nothing, so the very same
## sequence is what is played and what is held against the live run.
##
## The numbers are video frames (1/60 s) of an Apple II+ in MAME, read
## off tools/mame/pass_live.lua, fight_live.lua and jump_live.lua logs
## (analysis/live/pass/, analysis/live/jump/).
##
## One pass of the main loop, T being the moment line 150 switches the
## character generator's page:
##
##     line 147's POKEs    T - view_frames()
##     line 150            T
##     line 185, button    T + 26
##     line 200, keys      T + 33   (later by however long a fight took)
##     next line 147       T + 63
##
## and the first pass after a start goes from line 150 to the keys in 27.
##
## The one liberty in here is DISK_WAIT_SCALE. The original chains
## through a dozen small programs and every hand-over is a floppy load
## of two to eight seconds with the picture standing still. Those waits
## are kept in proportion but cut down; everything the machine computed
## or drew is at its real speed.
##
## No `class_name` (see shape_table.gd); preload into a local const.

const FlightProgram = preload("res://scripts/flight/flight_program.gd")
const FlightCombat = preload("res://scripts/flight/flight_combat.gd")

## How run() ended.
enum Left {
	STOPPED, ## `stop` was set
	COM, ## C: RUN COM
	RADAR, ## R: RUN RADAR
	DESTROYED, ## S/X has run; two key presses and the original reboots
}

## Every floppy wait below is multiplied by this (1.0 = the real thing).
const DISK_WAIT_SCALE := 0.15

# -- the main loop --
## Keys read (line 200) to line 147's POKEs of the next pass.
const KEYS_TO_VIEW := 30.0
## Line 150 to the button read of line 185.
const VIEW_TO_BUTTON := 26.0
## Button read to keys read with nothing fired.
const BUTTON_TO_KEYS := 7.0
## Line 150 to the keys on the first pass after a start (line 182).
const FIRST_PASS_TO_KEYS := 27.0
## A lamp key: TRANLIT and lines 1-9 again.
const RESTART := 23.0

# -- floppy loads (scaled) --
## RUN STARSHIP SIMULATOR up to line 9: 392 to 430 measured.
const LOAD_SIMULATOR := 400.0
const LOAD_RE := 140.0
const LOAD_ORBIT := 170.0
const LOAD_PLANET := 157.0 # BLOAD PLANET # n
const LOAD_SHIP := 150.0 # BLOAD SHIP # n, BLOAD DEBRIS
const LOAD_HD := 225.0
const LOAD_MISC_FILE := 221.0 # H_D line 6 reads and rewrites the star date
const LOAD_EXPL := 91.0 # BLOAD EXPL
const LOAD_SOUND_GEN := 145.0 # BLOAD SOUND GEN (95 when the drive is still spinning)
const LOAD_EX := 111.0
const LOAD_DMG := 105.0
const LOAD_SX := 217.0 # with its BLOAD EXPL

# -- RE.bas and ORBIT.bas --
const MARKERS_OFF := 30.0
const OVERLAY_ROW := 1.9 # one HPLOT across the screen
const OVERLAY_MESSAGE := 12.0

# -- H_D.bas --
const JUMP_DISTANCE := 17.0 # lines 10000-10020
const JUMP_MARKERS := 30.0 # line 8
const JUMP_BOOKKEEPING := 23.0 # lines 11-16
const JUMP_CLEAR_ROW := 1.3 # line 17, a row of 40 spaces
const JUMP_NOISE := 120.0 # line 18: 251 calls
const JUMP_RAY := 2.57 # line 20: a random line and a call of the noise
const JUMP_PLACE := 33.0 # lines 50-75
const JUMP_SLOW_TEXT := 3.8 # SPEED=100, a character
const JUMP_MESSAGE_HOLD := 144.0 # FOR I = 1 TO 2000: NEXT

var program := FlightProgram.new()
var combat := FlightCombat.new()
## combat_fx.gd, set through setup().
var fx: Node

## `wait.call(frames)`: comes back that many video frames later.
var wait: Callable = func(_frames: float) -> void: pass
## Called where line 15 reads the paddles; sets program.input_pitch and
## program.input_bank.
var read_stick: Callable
## Called where line 185 reads the paddle button; returns whether it is
## down.
var read_button: Callable = func() -> bool: return false
## Called after line 147's POKEs, the point the live recordings were
## taken at.
var pass_started: Callable
## Set to make run() come back at the next pass.
var stop := false


func setup(combat_fx: Node) -> void:
	fx = combat_fx
	combat.setup(program, fx)


## The 3D view's share of a pass: line 147's POKEs to line 150. Fitted on
## the 50 passes of analysis/live/pass/ (the counts are a2_3d1_view.gd's;
## tests/check_flight_passes.tscn -- --counts prints them); within two
## frames on every one of them.
func view_frames() -> float:
	var view := program.view
	return 13.09 + 0.20575 * view.records_run + 0.00132 * view.dots_drawn \
		+ 0.11638 * view.projections + 0.14664 * view.clip_steps


func run() -> Left:
	if GameState.instruments_due:
		program.instruments()
	await _run(LOAD_SIMULATOR)
	_start(true)
	while true:
		if read_stick.is_valid():
			read_stick.call()
		await wait.call(KEYS_TO_VIEW)
		program.begin_pass()
		if pass_started.is_valid():
			pass_started.call()
		if stop:
			return Left.STOPPED
		program.fly()
		await wait.call(view_frames())
		match program.after_view():
			FlightProgram.After.REENTRY:
				await _reentry()
				continue
			FlightProgram.After.ORBIT:
				await _orbit()
				continue
			FlightProgram.After.FIRST_PASS:
				await wait.call(FIRST_PASS_TO_KEYS)
			FlightProgram.After.FIGHT:
				await wait.call(VIEW_TO_BUTTON)
				match await combat.fight(read_button.call()):
					FlightCombat.Outcome.DEFENDER_DESTROYED:
						await _defender_destroyed()
						continue
					FlightCombat.Outcome.DAMAGED:
						await _damaged()
						continue
					FlightCombat.Outcome.SHIP_DESTROYED:
						await _ship_destroyed()
						return Left.DESTROYED
				await wait.call(BUTTON_TO_KEYS)
		match program.keys():
			FlightProgram.Keyed.RESTART:
				await wait.call(RESTART)
				combat.start(false)
			FlightProgram.Keyed.HYPERDRIVE:
				if not await _hyperdrive():
					return Left.DESTROYED
			FlightProgram.Keyed.COM:
				return Left.COM
			FlightProgram.Keyed.RADAR:
				return Left.RADAR
	return Left.STOPPED


func _start(run_program: bool) -> void:
	program.start(run_program)
	combat.start(run_program)


func _disk(frames: float) -> void:
	await wait.call(frames * DISK_WAIT_SCALE)


## RUN <program>: the load, then DOS's carriage return.
func _run(frames: float) -> void:
	await _disk(frames)
	program.ran()


func _effect() -> void:
	if fx.is_busy():
		await fx.idle


func _type(message: String, frames_per_character: float) -> void:
	fx.type_text(message, program.text.put, frames_per_character)
	await _effect()


# -- RE.bas, ORBIT.bas ----------------------------------------------------


func _reentry() -> void:
	await _run(LOAD_RE)
	program.reentry_open()
	await _overlay("REENTRY SEQUENCE START")
	program.reentry_close()
	await _disk(LOAD_PLANET)
	program.reentry_load()
	await _run(LOAD_SIMULATOR)
	_start(true)


func _orbit() -> void:
	await _run(LOAD_ORBIT)
	program.orbit_open()
	await _overlay("ORBITAL INSERTION START")
	program.orbit_close()
	await _disk(LOAD_PLANET)
	var ship_loaded := program.orbit_load()
	if ship_loaded:
		await _disk(LOAD_SHIP)
	await _run(LOAD_SIMULATOR)
	_start(true)


## Lines 2-20 of both: the gauges go, the window fills a row at a time,
## the words appear.
func _overlay(message: String) -> void:
	await wait.call(MARKERS_OFF)
	for y in range(FlightProgram.OVERLAY_ROWS):
		program.overlay_row(y)
		await wait.call(OVERLAY_ROW)
	program.overlay_message(message)
	await wait.call(OVERLAY_MESSAGE)


# -- H_D.bas --------------------------------------------------------------


## False when the ship was lost for want of energy.
func _hyperdrive() -> bool:
	await _run(LOAD_HD)
	if program.hyperdrive_refused(): # 1
		await _run(LOAD_SIMULATOR)
		_start(true)
		return true
	if not program.jump_has_energy(): # 2-4
		for message: String in ["OUT OF ENERGY", "ORBIT DECAYING"]:
			program.jump_no_energy_message()
			await _type(message, JUMP_SLOW_TEXT)
			await wait.call(JUMP_MESSAGE_HOLD)
		await _ship_destroyed()
		return false
	var distance := program.jump_distance() # 5
	await wait.call(JUMP_DISTANCE)
	program.jump_log(distance) # 5-6
	await _disk(LOAD_MISC_FILE)
	await _disk(LOAD_EXPL) # 8
	await wait.call(JUMP_MARKERS)
	program.jump_ready(distance) # 7-16
	await wait.call(JUMP_BOOKKEEPING)
	for l in range(1, FlightProgram.JUMP_CLEAR_ROWS + 1): # 17
		program.jump_clear_row(l)
		await wait.call(JUMP_CLEAR_ROW)
	AudioManager.play_jump() # 18
	await wait.call(JUMP_NOISE)
	await _rays() # 20, in white
	var file_loaded := program.jump_arrive() # 25-76
	if file_loaded:
		await _disk(LOAD_SHIP)
	await wait.call(JUMP_PLACE)
	await _rays() # 80: line 20 again, in black
	program.jump_finish() # 90-105
	await _disk(LOAD_SOUND_GEN) # 100
	await _run(LOAD_SIMULATOR)
	_start(true)
	return true


func _rays() -> void:
	for h in range(FlightProgram.JUMP_RAYS):
		program.jump_ray()
		AudioManager.play_tick()
		await wait.call(JUMP_RAY)


# -- EX.bas, DMG.bas, S_X.bas ---------------------------------------------


func _defender_destroyed() -> void:
	await _run(LOAD_EX)
	program.view.shown = 1 # 2  POKE -16299,0
	await _disk(LOAD_SOUND_GEN) # 4
	fx.ex_blast() # 5-6, on page 1 behind page 2
	await _effect()
	program.view.shown = 0 # 6  POKE -16300,0
	fx.ex_fan() # 6-25
	await _effect()
	program.ex_finish() # 30-56
	await _disk(LOAD_SHIP) # 40
	await _disk(LOAD_SOUND_GEN) # 57
	await _run(LOAD_SIMULATOR)
	_start(true)


func _damaged() -> void:
	await _run(LOAD_DMG)
	program.dmg_show()
	await _run(LOAD_SIMULATOR)
	_start(true)


func _ship_destroyed() -> void:
	await _run(LOAD_SX)
	program.sx_open() # 2-5
	fx.destroy_ship() # 6-30
	await _effect()
	program.sx_message() # 40
	await _type("YOUR SHIP HAS BEEN DESTROYED!!", fx.TEXT_FRAMES)
