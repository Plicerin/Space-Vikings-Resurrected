extends RefCounted
## The rules of GALAXY MAP.bas, the star chart: where each star is and
## how it is marked, what a paddle is pointing at, and what the chart
## says of the star it is asked about. No screen in it
## (scripts/chart/star_chart.gd shows it). tests/check_chart_rules.gd
## holds it to the real game, from the recording in
## analysis/live/chart/. Line numbers are the original's.
##
## Positions are in the original's dots: the chart is 280 across, and
## what a star's mark is drawn at and what the cursor is over are the same
## numbers (PX and PY below are the paddle's, before line 3215 adds 35).
##
## Two things the original does that are kept, as they decide what a
## click finds: a star's cell is three columns of ten dots and two rows of
## five (line 3230), and the first star in the list whose cell the cursor
## is in wins.
##
## Not kept (the machine, not the game): the flicker, the black DRAW that
## takes the star under the cross off until the chart is drawn again, the
## search taking longer the further down the list a star is, and that any
## key at all leaves, where the screen asks for the space bar.

const ComRules = preload("res://scripts/rules/com_rules.gd")

const STARS := 20
const NAMES := ComRules.NAMES
const NO_STAR := 21 ## what line 3220's FOR leaves in P when it found none

enum Mark { NEAR, MIDDLE, FAR }

const SAID_NO_STAR := "THERE IS NO STAR SYSTEM THERE, SIR."
const QUESTION := "DO YOU WISH FURTHER INFORMATION?"

## Applesoft's 1.19 is a little under 1.19, and its PDL(0) * 1.19 comes
## out a hair under the whole number where there is one, so that these
## two readings find the dot before (tools/mame/chart_float_live.lua).
const PADDLE_ONE_LESS: Array[int] = [100, 200]


static func _x(star: int) -> int:
	return GameState.PLANET_X[star - 1]


static func _y(star: int) -> int:
	return GameState.PLANET_Y[star - 1]


static func _z(star: int) -> int:
	return GameState.PLANET_Z[star - 1]


## @witness GALAXY MAP 3020, 3030-3050
## How far away a star is drawn: under 12 near, 12 to 15 middle, over 15 far.
static func mark(star: int) -> Mark:
	var z := _z(star)
	if z < 12:
		return Mark.NEAR
	if z < 16:
		return Mark.MIDDLE
	return Mark.FAR


## @witness GALAXY MAP 3060-3065
## Where a star's mark is, in dots.
static func place(star: int) -> Vector2:
	return Vector2(_x(star) * 10 - 35, _y(star) * 5)


## @witness GALAXY MAP 3066
## Violet: the star's planet is secured.
static func secured(star: int) -> bool:
	return GameState.planet_secured[star - 1] == 1


## @witness GALAXY MAP 3075
## The box round the star the ship is at.
static func here(star: int) -> bool:
	return star == GameState.current_planet + 1


## @witness GALAXY MAP 3110-3117
## Where paddle readings (0 to 255 each) put the cursor: PX, PY.
static func cursor(paddle_x: int, paddle_y: int) -> Vector2:
	var px := paddle_x * 1.19
	if PADDLE_ONE_LESS.has(paddle_x):
		px -= 0.0000001
	return clamp_cursor(Vector2(px, paddle_y))


## @witness GALAXY MAP 3110-3117
## A place in dots as the cursor can be: PX from 10 to 270, PY from 10 to 145.
static func clamp_cursor(at: Vector2) -> Vector2:
	return Vector2(clampf(at.x, 10.0, 270.0), clampf(at.y, 10.0, 145.0))


## @witness GALAXY MAP 3215-3240
## The star whose cell the cursor is in, or NO_STAR.
static func star_at(cursor_at: Vector2) -> int:
	var column := int((cursor_at.x + 35.0) / 10.0)
	var row := int(cursor_at.y / 5.0)
	for star in range(1, STARS + 1):
		if column <= _x(star) + 1 and column >= _x(star) - 1 and row <= _y(star) and row >= _y(star) - 1:
			return star
	return NO_STAR


## @witness GALAXY MAP 3250, 3300-3320
## What the chart says of `star`: its name, then its place and how far
## it is from the star the ship is at.
static func said(star: int) -> Array[String]:
	var here_star := GameState.current_planet + 1
	var dx := absi(_x(here_star) - _x(star))
	var dy := absi(_y(here_star) - _y(star))
	var dz := absi(_z(here_star) - _z(star))
	var light_years := int(sqrt(float(dx * dx + dy * dy + dz * dz)))
	return [
		"STAR SYSTEM : %s" % NAMES[star - 1],
		"LOC. : %d %d %d : DISTANCE = %d L/Y" % [_x(star), _y(star), _z(star), light_years],
	]


## @witness GALAXY MAP 3260
## "Y" to the question: the console is run with the star's number, and the
## once-a-trip base flag the chart pokes an 8 into is given back.
static func further(star: int) -> void:
	GameState.handover = star
	GameState.base_built_this_trip = false
