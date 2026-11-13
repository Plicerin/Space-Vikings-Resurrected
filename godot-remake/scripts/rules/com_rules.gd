extends RefCounted
## The rules of COM.bas, the command console: what the damage-control
## lamps show, what each menu offers and where each choice goes, how a
## course is set, and what the galaxy directory says of a star. No
## screen in it (scripts/com/com_console.gd shows it).
## tests/check_com_rules.gd holds it to what the real game printed, from
## the recordings in analysis/live/com/. Line numbers are the original's.
##
## What the original does that is not kept (the machine, not the game):
## the painted views and the waits, a wrong key's scolding, and that the
## directory's "2) RETURN" lands in the command menu, not at the
## navigation computer that its GOTO names.
##
## The star names are COM's own: star 16 is GROOMBRIDGE 168 here and in
## the chart, GROOMBRIDGE 1618 in STATUS and COLLECT.

const STARS := 20
const NAMES := [
	"SOL", "ALPHA CENTAURI", "BARNARD'S STAR", "WOLF 359", "LUYTEN",
	"LALANDE 21185", "SIRIUS", "VARCAR", "XANADON", "EPSILON ERIDANA",
	"CYGNI", "PROCYON", "TAU CETI", "LACAILLE 9352", "LARSEN-C",
	"GROOMBRIDGE 168", "KRUGER 60", "EPSILON INDI", "ARGO", "SHIVANDA",
]

## 15000-15030, two lines to a lamp, in the order of ST() (15140).
const LAMPS := [
	["  1  ", " ENG "], ["  2  ", " ENG "], [" COMP", "NO/GO"], ["RADAR", "NO/GO"], [" ENV ", "NO/GO"],
	[" HULL", " DMG "], ["POWER", " LOW "], [" SHLD", "NO/GO"], ["HYPER", "DRIVE"], [" MSL ", "NO/GO"],
	["LASER", "NO/GO"], [" COM ", "NO/GO"],
]
const POWER := 6 # the lamp that goes by 16, not 0 (10000)
const POWER_LOW := 16

const COMMANDS := ["COMPUTER", "GROUND FORCES", "RADAR", "END", "RETURN"] # 110
const CENTRAL := ["NAVIGATION COMP.", "GALAXY DIRECTORY", "GALAXY MAP", "SHIP STATUS", "SUPPLIES REPORT", "RETURN"] # 220
const NAVIGATION := ["DIRECTORY", "SET COURSE", "RETURN"] # 810
const DIRECTORY := ["DISPLAY PLANETARY DATA", "RETURN"] # 940

const SAID_COMPUTER_OUT: Array[String] = ["COMPUTER NOT", "FUNCTIONING."]
const SAID_COURSE_ERROR: Array[String] = ["<ERROR>"]
const SAID_COURSE_HERE: Array[String] = ["THAT'S WHERE WE", "ARE NOW, SIR!"]

## Where a choice of the command menu goes.
enum Goes { CENTRAL, GROUND_FORCES, RADAR, END, FLIGHT }
## Where a choice of the central computer goes.
enum Central { NAVIGATION, DIRECTORY, GALAXY_MAP, STATUS, SUPPLY, BACK }


## 15140: the byte each lamp goes by.
static func _system(lamp: int) -> int:
	match lamp:
		0: return int(GameState.ship_engine1)
		1: return int(GameState.ship_engine2)
		2: return int(GameState.ship_computer)
		3: return int(GameState.ship_radar)
		4: return int(GameState.ship_env_control)
		5: return int(GameState.ship_hull)
		6: return int(GameState.ship_energy)
		7: return int(GameState.ship_shield)
		8: return int(GameState.ship_hyperdrive)
		9: return int(GameState.ship_missile_system)
		10: return int(GameState.ship_laser)
	return 1 # 38185, which nothing writes: it is never out


## @witness COM 40-80, 10000-10010, 15000-15030, 15140
## The twelve lamps: [first line, second line, out]. A lamp is out at
## 0, and the POWER one below 16.
static func lamps() -> Array:
	var out := []
	for lamp in LAMPS.size():
		var value := _system(lamp)
		var gone := value < POWER_LOW if lamp == POWER else value == 0
		out.append([LAMPS[lamp][0], LAMPS[lamp][1], gone])
	return out


## @witness COM 98, 115
## True once if GROUND FORCES' bounce is waiting: RECALL and SHORE LEAVE
## run COM with a mark that sends it straight back.
static func ground_forces_due() -> bool:
	var due := GameState.ground_forces_due
	GameState.ground_forces_due = false
	return due


## @witness COM 12
## The star the chart asked about, 1 to 20, or 0 for the console.
static func chart_star() -> int:
	return GameState.handover


## @witness COM 120-135
## Where choice `command` (1 to 5) of the command menu goes. RADAR is run
## with a 2 in the byte it reads (38388).
static func command(choice: int) -> Goes:
	match choice:
		2: return Goes.GROUND_FORCES
		3:
			GameState.handover = 2
			return Goes.RADAR
		4: return Goes.END
		5: return Goes.FLIGHT
	return Goes.CENTRAL


## @witness COM 215
## The central computer will not run with the computer out.
static func computer_out() -> bool:
	return _system(2) == 0


## @witness COM 260-280, 1200, 3000, 20000
static func central(choice: int) -> Central:
	return (choice - 1) as Central


## @witness COM 870-897
## Sets a course for star `c`, whatever was typed: what is said, and
## nothing is changed unless the course is set.
static func course(c: int) -> Array[String]:
	if c > STARS or c == 0:
		return SAID_COURSE_ERROR
	if c == GameState.current_planet + 1:
		return SAID_COURSE_HERE
	GameState.target_planet = c - 1 # POKE 38163,C
	return [NAMES[c - 1], "COURSE SET."]


## @witness COM 978
## Whether `c` is one of the stars.
static func is_star(c: int) -> bool:
	return c >= 1 and c <= STARS


## @witness COM 990-1160
## What the directory says of star `c`, 1 to 20: the lines in order, ""
## a blank one. A page of the chart's question also clears the once-a-trip
## base flag (1007), which the chart's own "Y" has already done.
static func star_page(c: int) -> Array[String]:
	var star := c - 1
	if not GameState.planet_scouted[star]: # 1005
		return ["NO INFORMATION AVAILABLE AT THIS TIME.", ""]
	var tech: int = GameState.planet_tech[star]
	var lines: Array[String] = ["TECHNOLOGICAL DEVELOPMENT:"] # 1010
	match tech: # 1030-1070
		0:
			lines.append("NO INTELLIGENT LIFEFORMS INDICATED.")
		1:
			lines.append("PRIMITIVE PSEUDO SOCIETY ONLY.")
		2:
			lines.append("LIMITED ATOMIC DEVELOPMENT")
		3:
			lines.append("SOPHISTICATED TECHNOLOGY WITH")
			lines.append("STARSHIP CAPABILITY.")
		4:
			lines.append("ADVANCED CAPABILITY-SUPERIOR TO  OURS!")
	lines.append("") # 1080
	if tech >= 2: # 1090
		lines.append("ORBITING DEFENSE CAPABILITY --")
		lines.append("FIGHTER PROTECTION PROBABLE.")
	lines.append("POPULATION = APPROX. %d" % (GameState.planet_population_scale[star] * 35294)) # 1110
	if GameState.planet_secured[star] != 0: # 1120-1140
		lines.append(NAMES[star] + " HAS BEEN SECURED")
	else:
		lines.append(NAMES[star] + " IS INDEPENDENT.")
	lines.append("") # 1150
	if GameState.planet_has_base[star]: # 1160
		lines.append("THERE IS AN OPERATIONAL REPAIR BASE")
		lines.append("ON THE PLANET.")
	return lines


## @witness COM 1172, 1175
## True when the chart asked for the page, and is to be run again.
static func page_closed() -> bool:
	if GameState.handover == 0:
		return false
	GameState.handover = 0
	return true
