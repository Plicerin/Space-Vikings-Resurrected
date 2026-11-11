extends RefCounted
## The rules of RADAR.bas and the SHIP # n I.D. programs: when the radar
## works, which ship's I.D. a defender gets and what it says, and where
## "X" (or the end of the radar) goes. No screen in it
## (scripts/radar/radar_console.gd shows it). tests/check_radar_rules.gd
## holds the texts and the choice of I.D. to the real game's, from the
## recordings in analysis/live/radar/.
##
## The picture the radar draws is the flight's own 3D view from above; it
## is not a rule (the radar here is a map of the same world).

## What each I.D. says (line 1060 of each): the title and four lines. The
## programs are those of SHIP # 0, 1, 3 and 4; there is none for a type 2,
## which gets the light cruiser's (RADAR.bas line 5002).
const IDS := {
	0: ["-SHIP I.D.-", "THERE IS NO", "STARSHIP IN", "THIS SYSTEM."],
	1: ["-SHIP I.D.-", "SMALL SPACE LAB", "AND OBSERVATORY", "MINIMUM WEAPONS", "AND ARMOR."],
	3: ["-SHIP I.D.-", "LIGHT CRUISER", "WITH LASERS,", "MISSILES AND", "FIGHTER COVER."],
	4: ["-SHIP I.D.-", "HEAVY CRUISER", "WITH PHOTON", "MISSILES AND", "HEAVY LASERS.", "20-40 FIGHTERS"], # 1060-1061
}

## Where the radar goes back to.
enum Goes { FLIGHT, COM }


## @witness RADAR 10
## With the radar shot away it draws nothing and goes straight back.
static func works() -> bool:
	return int(GameState.ship_radar) != 0


## @witness RADAR 5000-5005
## Which I.D. program a defender of type `tier` is: its own, and a type 2
## the light cruiser's.
static func ship_id_program(tier: int) -> int:
	return 3 if tier == 2 else tier


## @witness SHIP no 0 I.D. 1060
## @witness SHIP no 1 I.D. 1060
## @witness SHIP no 3 I.D. 1060
## @witness SHIP no 4 I.D. 1060
## What I.D. program `program` says.
static func ship_id_text(program: int) -> Array:
	return IDS.get(program, IDS[0])


## @witness RADAR 2056-2059
## "X", or the end of a radar that is not working: back to the console if it
## ran the radar (COM leaves a 2 in 38388 for it), to the flight if not.
static func back() -> Goes:
	if GameState.handover > 0:
		GameState.handover = 0
		return Goes.COM
	return Goes.FLIGHT
