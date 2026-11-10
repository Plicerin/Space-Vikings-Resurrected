extends Node2D
## The real aimable weapon against the orbital defender ship —
## `STARSHIP SIMULATOR.bas` lines 1000-1222.
##
## CORRECTION (2026-11-09): this file (and `missile_trail.gd`) used to be
## named `fighter_encounter.gd`/`fighter_slot.gd` under the theory that
## lines 1000-1222 were a "two-fighter approach minigame." That theory
## was never actually confirmed by the real manual, and it was wrong.
## The manual's own "Tactical Considerations" section (page 13) and
## "Missile/Laser" indicator-light description (page 8) spell this
## mechanic out directly: pressing **W** toggles which weapon the fire
## button fires (`$38202`, line 1501's `IF PEEK(38202)=1 THEN 1000`);
## "use your lasers on the ship until you come within missile range and
## then use your missiles to finish him off"; missiles "must be within
## half the range covered by your forward radar scan or your missiles
## will self-destruct before reaching their target... (The explosion is
## smaller than a direct hit.)" That's a direct description of exactly
## this routine: a real, aim-and-range-gated hit-check (line 1050's
## bounding box around a fixed target point) against the SAME orbital
## defender `space_flight.gd`'s `ShipBlip` now renders, dealing 120x the
## laser's own defender-damage per hit (`J2=120` at line 1085, vs the
## laser's `J2=1` at line 1505) -- paid for by requiring the player to
## actually aim, unlike the laser's unconditional "always counts"
## ambient-damage mechanic. `fighter_encounter.gd`'s own doc comment
## already flagged the missing piece precisely: "no player-relative 3D
## combat position is tracked yet" -- that's now untrue, since
## `space_flight.gd` tracks real 3D ship position/heading and has a
## real `ShipBlip` to aim at, so `flight_combat.gd`'s `fire_missile()`
## now drives this with the genuine hit-check instead of the old
## "firing during the approach always counts" placeholder.
##
## Each step: the shared "flip-book" shape index (M3) creeps up by .32,
## the gap between the symmetric pair (M2) shrinks by 2, and the shared
## screen Y (M) drops by 4 -- twin missile trails converging toward the
## crosshair over the animation, the same visual convention the laser's
## own twin-beam draw uses (`laser_beam.gd`, line 1505's two symmetric
## `HPLOT` lines) -- fake-perspective "receding toward the target" with
## none of the real 3D engine's math. `flight_combat.gd` resolves hit-
## or-miss *before* this plays (it already knows the real range/aim
## result, matching the original's own line 1085 branch decided before
## the draw loop even finishes) and calls `start_hit()`/`start_miss()`
## accordingly.
##
## CONFIRMED AUTHENTIC (2026-11-09, resolving the 2026-11-07 doubt
## below): checked directly against `detokenized/STARSHIP SIMULATOR.bas`
## line 1000 (`M3 = 3`) and line 1060 (`M3 = M3 + .32`) -- the real
## BASIC code uses this exact same start value and increment, and
## Applesoft's `XDRAW M3 AT ...` truncates to an integer shape index just
## like this port's `int(_m3)` does. The ENEMY table's own even indices
## (4, 6, 8...) genuinely are near-blank 2-4 point shapes in the decoded
## data (checked directly against `assets/shapes/ENEMY I.A24580.L68.payload.json`),
## so the flicker between "detailed ship art" and "almost invisible" is
## the real original's behavior, not a decoding or step-rate bug. A real
## player on a real Apple II would have seen the exact same flicker.
## Left exactly as-is -- this is matched, not a bug to fix.

const ShapeTable = preload("res://scripts/shapes/shape_table.gd")
const MissileTrail = preload("res://scripts/combat/missile_trail.gd")

signal strike_resolved(hit: bool)

@export var approach_steps: int = 16
@export var step_duration: float = 0.12 # feel-tuned; the original has no fixed real-time rate
@export var m1_center_x: float = 113.0 # matches the laser reticle's apex X, see laser_beam.gd
@export var m2_gap_start: float = 40.0
@export var m2_gap_step: float = 2.0
@export var m_y_start: float = 124.0
@export var m_y_step: float = 4.0
@export var m3_shape_start: float = 3.0
@export var m3_shape_increment: float = 0.32

var table: ShapeTable

@onready var _left: MissileTrail = $Left
@onready var _right: MissileTrail = $Right

var _step: int = 0
var _timer: float = 0.0
var _m: float
var _m2: float
var _m3: float
var _hit: bool = false
var _active: bool = false


func _ready() -> void:
	_left.miss_finished.connect(_on_resolved.bind(false))
	_right.miss_finished.connect(func() -> void: pass)
	_left.hit_finished.connect(_on_resolved.bind(true))
	_right.hit_finished.connect(func() -> void: pass)


## `hit`: the real result, already computed by `flight_combat.gd`'s own
## aim/range check (line 1050) -- not decided by anything that happens
## during this animation, matching the original's own control flow
## (line 1085 branches on `HIT` before the draw even finishes its loop).
func start_strike(hit: bool) -> void:
	AudioManager.play_hit_medium() # line 1010's bare CALL SG, once per strike start
	_left.table = table
	_right.table = table
	_step = 0
	_timer = 0.0
	_m = m_y_start
	_m2 = m2_gap_start
	_m3 = m3_shape_start
	_hit = hit
	_active = true
	_update_approach_visual()


func _process(delta: float) -> void:
	if not _active:
		return

	_timer += delta
	if _timer < step_duration:
		return
	_timer = 0.0
	_step += 1
	if _step >= approach_steps:
		_active = false
		if _hit:
			_left.start_hit()
			_right.start_hit()
		else:
			_left.start_miss()
			_right.start_miss()
		return

	_m -= m_y_step
	_m2 -= m2_gap_step
	_m3 += m3_shape_increment
	_update_approach_visual()


func _update_approach_visual() -> void:
	var shape_idx := table.clamp_index(int(_m3))
	_left.show_approach(Vector2(m1_center_x - _m2, _m), shape_idx)
	_right.show_approach(Vector2(m1_center_x + _m2, _m), shape_idx)


func _on_resolved(hit: bool) -> void:
	strike_resolved.emit(hit)
