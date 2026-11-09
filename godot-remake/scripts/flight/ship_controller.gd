extends Node3D
## Space-flight ship controller — ports the coordinated-turn attitude
## model traced in FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md (the
## original's compiled 6502 "CALL CA" routine in SPACE SIMULATOR
## ASSEMBLY, not anything in the BASIC source). The *relationships* are
## kept faithful:
##   - Pitch is direct-rate with no self-centering (paddle 1, $7321) —
##     it holds trim wherever you release it.
##   - Bank is rate-controlled but actively springs back toward level
##     when released (paddle 0, $7322).
##   - Heading turns continuously at a rate driven by the *current* bank
##     angle ($7323) — a real coordinated turn, not stick-to-axis
##     steering; there is no separate rudder input.
##   - Looping through vertical (pitch crossing +/-90 from level) flips
##     heading by ~180 degrees once, matching the original's one-shot
##     correction.
## The original's exact paddle-threshold/byte-wrap constants don't
## translate 1:1 to a modern keyboard or analog stick, so the rates/
## limits below are tuned for feel rather than byte-matched. (FUN_91ec
## is now individually confirmed, not just presumed symmetric to
## FUN_91b3 — see the doc's "coordinated turn" section.) Treat these
## export values as a starting point, not a verified constant.

@export var pitch_rate_deg: float = 60.0        # deg/sec at full deflection, no spring-back
@export var bank_rate_deg: float = 90.0         # deg/sec at full deflection
@export var bank_max_deg: float = 50.0          # how far bank can be held
@export var bank_spring_deg: float = 40.0       # deg/sec pull back toward level when released
@export var turn_rate_per_bank_deg: float = 1.2 # heading deg/sec per deg of current bank
@export var throttle_rate: float = 0.6          # throttle change per second, held key
@export var max_speed: float = 1500.0           # world units/sec at full throttle

var _inverted_flip_armed: bool = false


func _physics_process(delta: float) -> void:
	var pitch_input := Input.get_axis("pitch_down", "pitch_up")
	var bank_input := Input.get_axis("bank_left", "bank_right")
	var throttle_input := Input.get_axis("throttle_down", "throttle_up")

	GameState.pitch_deg = wrapf(GameState.pitch_deg + pitch_input * pitch_rate_deg * delta, 0.0, 360.0)

	if absf(bank_input) > 0.01:
		GameState.bank_deg = clampf(GameState.bank_deg + bank_input * bank_rate_deg * delta, -bank_max_deg, bank_max_deg)
	else:
		GameState.bank_deg = move_toward(GameState.bank_deg, 0.0, bank_spring_deg * delta)

	GameState.heading_deg = wrapf(GameState.heading_deg + GameState.bank_deg * turn_rate_per_bank_deg * delta, 0.0, 360.0)

	var inverted := GameState.pitch_deg > 90.0 and GameState.pitch_deg < 270.0
	if inverted and not _inverted_flip_armed:
		GameState.heading_deg = wrapf(GameState.heading_deg + 180.0, 0.0, 360.0)
		_inverted_flip_armed = true
	elif not inverted:
		_inverted_flip_armed = false

	GameState.throttle = clampf(GameState.throttle + throttle_input * throttle_rate * delta, -1.0, 1.0)

	# Godot's rotation order and sign conventions don't match the
	# original's byte-angle math, so this is a from-scratch mapping of
	# the same three angles onto a Node3D, not a port of any specific
	# formula.
	rotation_degrees = Vector3(-GameState.pitch_deg, GameState.heading_deg, -GameState.bank_deg)
	var forward := -global_transform.basis.z
	GameState.ship_position += forward * GameState.throttle * max_speed * delta
	global_position = GameState.ship_position
