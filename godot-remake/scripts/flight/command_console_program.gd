extends RefCounted
## COM, the command console, on the CRT console: its menus, the navigation
## computer, the galaxy directory and the star pages; and on from it to the
## programs the original ran from it (GROUND FORCES, RADAR, the galaxy map, END)
## and its two reports (reports_program.gd). What each choice does and what
## the console says is scripts/rules/com_rules.gd, which is held to the real
## game (tests/check_com_rules.gd); this shows it, asks, and calls the other
## programs.
##
## The other programs are the flight scene's own, handed in as `host`:
##   ground_forces, radar, chart: coroutines that return when they are done;
##   end: a coroutine that returns true to go on with the game.
##
## Where it parts from the original, on purpose:
## - a wrong key is not scolded and waited out; only the keys that are offered
##   do anything;
## - "2) RETURN" in the directory comes out at the command menu, as the
##   original's does, and not the navigation computer it names;
## - the directory's list of stars is on every one of its pages, two columns.

const ComRules = preload("res://scripts/rules/com_rules.gd")
const ReportsProgram = preload("res://scripts/flight/reports_program.gd")

# Seconds.
const SAID := 2.0
const COURSE_SET := 1.5

var _console: Node
var _host: Dictionary


## Runs the console until it is left for the flight.
## @witness COM 1-12
func run(console: Node, host: Dictionary) -> void:
	_console = console
	_host = host
	if ComRules.ground_forces_due(): # RECALL's and SHORE LEAVE's bounce
		await _host.ground_forces.call()
	var star := ComRules.chart_star() # the chart's "Y"
	if star > 0:
		await _chart_pages(star)
	while await _command_menu():
		pass
	_console.close()


## One turn of the command menu. Returns false to leave for the flight.
## @witness COM 90-135
func _command_menu() -> bool:
	var choice: int = await _console.menu("COMMAND MODE", ComRules.COMMANDS, [], [], ComRules.COMMANDS.size())
	match ComRules.command(choice):
		ComRules.Goes.CENTRAL:
			await _central()
		ComRules.Goes.GROUND_FORCES:
			await _host.ground_forces.call()
		ComRules.Goes.RADAR:
			await _host.radar.call()
		ComRules.Goes.END:
			if await _host.end.call():
				return false
		_:
			return false
	return true


## @witness COM 200-280
func _central() -> void:
	if ComRules.computer_out():
		await _console.say(["-CENTRAL COMPUTER-"] + _console.flow(ComRules.SAID_COMPUTER_OUT), SAID)
		return
	var choice: int = await _console.menu("CENTRAL COMPUTER", ComRules.CENTRAL, [], [], ComRules.CENTRAL.size())
	match ComRules.central(choice):
		ComRules.Central.NAVIGATION:
			await _navigation()
		ComRules.Central.DIRECTORY:
			await _directory()
		ComRules.Central.GALAXY_MAP:
			await _chart_pages(0)
		ComRules.Central.STATUS:
			await ReportsProgram.new().status(_console)
		ComRules.Central.SUPPLY:
			await ReportsProgram.new().supply(_console)


## The galaxy map, and what its "Y" asks for: a star's page, and the map again.
func _chart_pages(star: int) -> void:
	while true:
		if star == 0:
			await _host.chart.call()
			star = ComRules.chart_star()
			if star == 0:
				return
		await _page(star)
		star = 0


## @witness COM 800-850
func _navigation() -> void:
	while true:
		var choice: int = await _console.menu("NAVIGATION COMPUTER", ComRules.NAVIGATION, [], [], ComRules.NAVIGATION.size())
		if choice == 1:
			await _directory()
			return # its RETURN is the command menu
		if choice != 2:
			return
		await _course()


## @witness COM 860-897
func _course() -> void:
	while true:
		_host.pick.call(true) # the galaxy map is up to click a star on, and the star's name is under what is typed
		var asked: float = await _console.ask_number(["-NAVIGATION COMPUTER-"], "ENTER DESIRED DESTINATION (1-20) ", true, _star_name)
		_host.pick.call(false)
		if asked < 0.0: # given up (Escape): back to the navigation menu
			return
		var c := int(asked)
		var course_set := c >= 1 and c <= ComRules.STARS and c != GameState.current_planet + 1
		var said := ComRules.course(c)
		await _console.say(["-NAVIGATION COMPUTER-"] + _console.flow(said), COURSE_SET if course_set else SAID)
		if course_set:
			return


## The name of the star a number is, for the foot of a prompt for one.
func _star_name(number: int) -> String:
	return ComRules.NAMES[number - 1] if ComRules.is_star(number) else ""


## The twenty stars, two columns.
func _star_rows() -> Array:
	var rows: Array = []
	for row in 10:
		rows.append(_console.columns("%d) %s" % [row + 1, ComRules.NAMES[row]], "%d) %s" % [row + 11, ComRules.NAMES[row + 10]]))
	return rows


## @witness COM 900-969
func _directory() -> void:
	var rows := _star_rows()
	while true:
		var choice: int = await _console.menu("GALAXY DIRECTORY", ComRules.DIRECTORY, [], rows, ComRules.DIRECTORY.size())
		if choice == 2:
			return
		while true:
			_host.pick.call(true)
			var c := int(await _console.ask_number(["-GALAXY DIRECTORY-"] + rows, "WHICH SYSTEM? (0 TO RETURN) ", true, _star_name))
			_host.pick.call(false)
			if c <= 0:
				break
			if ComRules.is_star(c):
				var from_chart := await _page(c)
				if from_chart:
					await _chart_pages(0)
					return
				break
			await _console.say(["-GALAXY DIRECTORY-"] + rows + ["TRY AGAIN PLEASE."], SAID)


## @witness COM 970-1180
## A star's page, to a key. Returns whether the chart's "Y" asked for it (so the
## map comes up again).
func _page(c: int) -> bool:
	var lines: Array = ["-%s STAR SYSTEM-" % ComRules.NAMES[c - 1]]
	var body := ComRules.star_page(c)
	lines.append_array(body.slice(0, body.size()))
	await _console.any_key(_trim(lines) + ["ANY KEY  RETURN"])
	return ComRules.page_closed()


## The page without its blank lines' runs and trailing blank.
func _trim(lines: Array) -> Array:
	var out: Array = []
	for line in lines:
		if str(line) == "" and (out.is_empty() or out.back() == ""):
			continue
		out.append(line)
	while not out.is_empty() and out.back() == "":
		out.pop_back()
	return out
