-- Live record of GROUND FORCES.bas and the programs it runs and is run
-- by: its menu, the messages it refuses with, the battle round by round
-- with every RND(1) it drew, RECALL, COLLECT, and the way back through
-- COM. The same clock as radar_live.lua: when each BASIC line started,
-- every character the generator drew, and the hi-res pages at each stop.
--
-- A stop is one of
--   get   the program is waiting in KEYIN (a GET); a key is then pressed
--   at    BASIC has come to the start of one of the lines in STOPS (a
--         message that a FOR loop holds, a round of the battle)
--   ran   BASIC is at the first statement of a program just loaded
-- and at each the pages, the cursor, the window, the bytes in WATCHED
-- and BASIC's own variables are written down. A page is written to a
-- file only when it is not the page last written: the stop's line names
-- the files to compare with.
--
-- SV_ROUTE picks the keys and the pokes (all made at the command
-- console's GET, before the 2 that runs GROUND FORCES):
--
--   ground_menu      keys that are no choice, 9) RETURN, RECALL with
--                    the troops asleep
--   ground_gates     NO BASE, the two "troops on another planet"
--                    refusals, and RECALL's other answers
--   ground_leave     an unsurrendered planet: 4 to 7, 3 and 8 each run
--                    SHORE LEAVE, which comes straight back for all but
--                    the 8
--   ground_stale     the same, 7 and then 9: what COM makes of the 4
--                    that is still in 38388
--   ground_sol       a new game as it is, 1) ATTACK PLANET at SOL
--   ground_tech_0 .. ground_tech_4
--                    the planet's technology poked to each level
--   ground_clamp     the planet all but taken (38160 = 254 of 255)
--   ground_early_key a key while the transports are on their way
--   ground_none      no transports; then 38207 = 1 on a surrendered
--                    planet
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_ROUTE=ground_menu SV_OUT=/tmp/sv_ground WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/ground_live.lua \
--     -snapshot_directory /tmp/sv_ground -snapname "snap_%i"
--
-- <route>.log (the route's name starts with "ground_"):
--   <ms> [frame] line <n>  x<statements>  p1=<stores on page 1>
--        (<first ms>..<last ms>)  p2=<stores on page 2>  "<characters>"
--       at <ms after the line's start> ...   its first statements
--       rnd <exponent>:<mantissa> ...        each RND(1) of the line, as
--                                            Applesoft left it in $C9-$CD
--   <ms> [frame] -- get <name> line=<n> p1=<file> p2=<file> ...
--   <ms> [frame] -- at <line> n=<times come to> line=<n> p1= p2= ...
--   <ms> [frame] -- ran <program, _ for space> gap=<ms since the last
--        statement> line=<n> p1= p2= ...
--       vars <name>=<value> ...              BASIC's real variables
--   <ms> [frame] -- poke <address>=<value>
--   <ms> [frame] -- key '<character>'
-- <route>_glyphs.log, a line a character:
--   <ms> <line> <code> <column> <row> <973> <974>  <left> <width> <top> <bottom>
--   (column and row are the cursor before the character)

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local ROUTE = os.getenv("SV_ROUTE") or "ground_menu"
local f = assert(io.open(DIR .. ROUTE .. ".log", "w"))
local g = assert(io.open(DIR .. ROUTE .. "_glyphs.log", "w"))
local function log(s) f:write(s .. "\n") end
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nat = manager.machine.natkeyboard
local function pc() return cpu.state["PC"].value end
-- the Apple's backspace; the natural keyboard has no name for it
local left_arrow = manager.machine.ioport.ports[":kbd:nkbd:X2"].fields["Cursor Left"]

local function now()
	return manager.machine.time:as_double() * 1000.0
end

local CH, CV = 0x24, 0x25
local GLYPHS = 0x8800
local frame = 0
local passes = 0
local recording = false
local keyin_frame = -10
local boundaries = 0

ground_live_taps = {}
local taps = ground_live_taps

local rowbase = {}
for y = 0, 191 do
	rowbase[y] = (y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 0x28
end
local function read_page(base)
	local rows = {}
	for y = 0, 191 do
		local a = base + rowbase[y]
		local row = {}
		for c = 0, 39 do row[#row + 1] = string.char(mem:read_u8(a + c)) end
		rows[#rows + 1] = table.concat(row)
	end
	return table.concat(rows)
end

-- the pages as last written, and the files they are in
local written = {"", ""}
local written_file = {"-", "-"}
local stops = 0
-- Writes the pages that are not as last written, and says which files
-- hold the two as they are now.
local function snap()
	stops = stops + 1
	for i = 1, 2 do
		local bytes = read_page(0x2000 * i)
		if bytes ~= written[i] then
			written[i] = bytes
			written_file[i] = string.format("%s_%03d_p%d.bin", ROUTE, stops, i)
			local out = assert(io.open(DIR .. written_file[i], "wb"))
			out:write(bytes)
			out:close()
		end
	end
	return string.format("p1=%s p2=%s", written_file[1], written_file[2])
end

-- A real number of Applesoft's, five bytes at `a`.
local function real(a)
	local e = mem:read_u8(a)
	if e == 0 then return 0 end
	local b1 = mem:read_u8(a + 1)
	local m = ((b1 | 0x80) << 24) | (mem:read_u8(a + 2) << 16) | (mem:read_u8(a + 3) << 8) | mem:read_u8(a + 4)
	local v = m / 4294967296.0 * 2.0 ^ (e - 128)
	if b1 >= 128 then v = -v end
	return v
end

-- BASIC's real variables (VARTAB to ARYTAB, seven bytes each).
local function vars()
	local a = mem:read_u8(0x69) | (mem:read_u8(0x6A) << 8)
	local e = mem:read_u8(0x6B) | (mem:read_u8(0x6C) << 8)
	local out = {}
	while a < e and #out < 80 do
		local c1, c2 = mem:read_u8(a), mem:read_u8(a + 1)
		if c1 < 128 and c2 < 128 then
			local name = string.char(c1) .. (c2 > 0 and string.char(c2) or "")
			out[#out + 1] = string.format("%s=%.17g", name, real(a + 2))
		end
		a = a + 7
	end
	return table.concat(out, " ")
end

-- the entry being gathered
local line, began, statements, p1, p2, text = nil, 0, 0, 0, 0, {}
local p1_first, p1_last = 0, 0
-- when the line's first statements started (ms after the line did)
local at = {}
local AT_MOST = 40
-- the RND(1)s of the line
local rnds = {}

local function flush()
	if line == nil then return end
	local span = ""
	if p1 > 0 then span = string.format(" (%.2f..%.2f)", p1_first, p1_last) end
	log(string.format("%.2f [%d] line %d  x%d  p1=%d%s p2=%d  \"%s\"", began, frame, line, statements,
		p1, span, p2, table.concat(text)))
	if #at > 1 then log("    at " .. table.concat(at, " ")) end
	if #rnds > 0 then log("    rnd " .. table.concat(rnds, " ")) end
	rnds = {}
	line = nil
end

local function note(what)
	flush()
	log(string.format("%.2f [%d] -- %s", now(), frame, what))
	f:flush()
end

local WATCHED = {38388, 38151, 38150, 38153, 38154, 38155, 38156, 38158, 38160, 38166, 38170, 38203, 38205,
	38206, 38207, 38208, 38209, 38210, 38220, 38283, 38304, 38149, 38389, 301, 38171, 38172, 38173, 38174,
	38175, 38176, 38177, 38178, 38179, 38180, 38181, 38182, 38183, 31180, 29469, 29470}
local function watched()
	local out = {}
	for _, a in ipairs(WATCHED) do out[#out + 1] = string.format("%d=%d", a, mem:read_u8(a)) end
	return table.concat(out, " ")
end

local function state()
	return string.format("ch=%d cv=%d window=%d,%d,%d,%d c973=%d c974=%d %s", mem:read_u8(CH), mem:read_u8(CV),
		mem:read_u8(32), mem:read_u8(33), mem:read_u8(34), mem:read_u8(35), mem:read_u8(973), mem:read_u8(974),
		watched())
end

-- A stop: the pages, the state and the variables under `what`.
local function stop(what, basic_line)
	note(string.format("%s line=%d %s %s", what, basic_line, snap(), state()))
	log("    vars " .. vars())
end

taps[#taps + 1] = mem:install_write_tap(29461, 29461, "pass", function(offset, data, mask)
	if pc() < 0xD000 then return end
	passes = passes + 1
end)

-- The lines a program is stopped at, by the name DOS loaded it under.
local STOPS = {
	["GROUND FORCES"] = {[75] = true, [172] = true, [185] = true, [190] = true, [195] = true, [200] = true,
		[230] = true, [240] = true, [305] = true, [310] = true, [340] = true, [350] = true, [410] = true,
		[480] = true, [500] = true, [660] = true, [675] = true, [690] = true, [800] = true, [805] = true,
		[1121] = true, [1130] = true, [2000] = true, [2080] = true, [2150] = true, [2160] = true,
		[2170] = true, [2180] = true, [2190] = true},
	["RECALL"] = {[2050] = true},
	["COLLECT"] = {[13] = true, [810] = true, [15] = true, [17] = true},
}
local program = "?"
local came = {}
local last_boundary = 0
-- the line of the last statement (`line` is forgotten at every note)
local current = -1

-- The name DOS has in its file name buffer.
local function loaded()
	local s = {}
	for i = 0, 29 do s[#s + 1] = string.char(mem:read_u8(0xAA75 + i) & 0x7F) end
	return (table.concat(s):gsub("%s+$", ""))
end

taps[#taps + 1] = mem:install_read_tap(0xC000, 0xC000, "kbd", function(offset, data, mask)
	local p = pc()
	if p >= 0xFD1B and p <= 0xFD30 then
		keyin_frame = frame
		return
	end
	if not recording then return end
	if p < 0xD850 or p > 0xD870 then return end
	boundaries = boundaries + 1
	-- the statement about to run: on the same line after a colon, on
	-- the next line after the end-of-line zero
	local txt = mem:read_u8(0xB8) | (mem:read_u8(0xB9) << 8)
	local n = mem:read_u8(0x75) | (mem:read_u8(0x76) << 8)
	if mem:read_u8(txt) == 0 then
		n = mem:read_u8(txt + 3) | (mem:read_u8(txt + 4) << 8)
	end
	if txt == 0x800 then
		-- RUN: the first statement of a program
		program = loaded()
		came = {}
		stop(string.format("ran %s gap=%.1f", program:gsub(" ", "_"), now() - last_boundary), n)
	elseif n ~= current and STOPS[program] ~= nil and STOPS[program][n] then
		came[n] = (came[n] or 0) + 1
		stop(string.format("at %d n=%d", n, came[n]), n)
	end
	last_boundary = now()
	current = n
	if n ~= line then
		flush()
		line, began, statements, p1, p2, text = n, now(), 0, 0, 0, {}
		at = {}
	end
	statements = statements + 1
	if #at < AT_MOST then at[#at + 1] = string.format("%.1f", now() - began) end
end)

taps[#taps + 1] = mem:install_write_tap(0x2000, 0x5FFF, "pages", function(offset, data, mask)
	if line == nil then return end
	if offset < 0x4000 then
		if p1 == 0 then p1_first = now() end
		p1_last = now()
		p1 = p1 + 1
	else
		p2 = p2 + 1
	end
end)

-- RND ends by storing its result as the new seed ($C9-$CD, MOVMF), the
-- exponent last.
taps[#taps + 1] = mem:install_write_tap(0xC9, 0xC9, "rnd", function(offset, data, mask)
	if not recording then return end
	local p = pc()
	if p < 0xEB2B or p > 0xEB52 then return end
	rnds[#rnds + 1] = string.format("%02X:%02X%02X%02X%02X", data & 0xFF, mem:read_u8(0xCA) | 0x80, mem:read_u8(0xCB),
		mem:read_u8(0xCC), mem:read_u8(0xCD))
end)

local last_glyph_frame, last_glyph, last_column, last_row = -1, -1, -1, -1
-- the last characters drawn
local recent = ""
taps[#taps + 1] = mem:install_read_tap(GLYPHS, GLYPHS + 0x3FF, "glyph", function(offset, data, mask)
	if not recording then return end
	local p = pc()
	if p < 0x9300 or p > 0x93FF then return end
	local glyph = (offset - GLYPHS) >> 3
	local column = mem:read_u8(CH)
	local row = mem:read_u8(CV)
	-- eight reads a character: the same one in the same place is one
	if glyph == last_glyph and column == last_column and row == last_row and frame - last_glyph_frame < 2 then return end
	last_glyph, last_column, last_row, last_glyph_frame = glyph, column, row, frame
	local character = (glyph >= 32 and glyph < 127) and string.char(glyph) or "."
	if line ~= nil then text[#text + 1] = character end
	recent = (recent .. character):sub(-60)
	g:write(string.format("%.2f %d %d %d %d %d %d  %d %d %d %d\n", now(), line or -1, glyph, column,
		row, mem:read_u8(973), mem:read_u8(974),
		mem:read_u8(32), mem:read_u8(33), mem:read_u8(34), mem:read_u8(35)))
end)

-- the script, a coroutine resumed once a frame

local function wait(n)
	for i = 1, n do coroutine.yield() end
end

local function key(k)
	note(string.format("key '%s'", k))
	nat:post(k)
end

local function poke(address, value)
	mem:write_u8(address, value)
	note(string.format("poke %d=%d", address, value))
end

-- Waits for the program to sit in KEYIN.
local function at_get(what, most)
	local held = 0
	local n = 0
	while held < 3 do
		coroutine.yield()
		n = n + 1
		if keyin_frame >= frame - 1 then held = held + 1 else held = 0 end
		if n > (most or 40000) then
			note("TIMEOUT waiting for the GET of " .. (what or "?"))
			error("timeout")
		end
	end
end

-- Waits for the program to sit in KEYIN, makes `pokes`, writes the stop
-- under `name` and presses `k` if there is one.
local function get(name, k, pokes, most)
	at_get(name, most)
	for _, p in ipairs(pokes or {}) do poke(p[1], p[2]) end
	stop("get " .. name, mem:read_u8(0x75) | (mem:read_u8(0x76) << 8))
	if k == nil then return end
	-- taken when BASIC gets to its next statement
	local before = boundaries
	key(k)
	local n = 0
	while boundaries == before do
		coroutine.yield()
		n = n + 1
		if n > 600 then
			note("no statement after the key: " .. name)
			return
		end
	end
end

-- Waits until the program has come to `basic_line` `times` times since
-- it was run.
local function came_to(basic_line, times, most)
	local n = 0
	while (came[basic_line] or 0) < times do
		coroutine.yield()
		n = n + 1
		if n > (most or 20000) then
			note("TIMEOUT waiting for line " .. basic_line)
			error("timeout")
		end
	end
end

local function boot()
	local n = 0
	while passes < 3 do
		coroutine.yield()
		n = n + 1
		if n >= 180 and n % 300 == 0 and n <= 6000 and passes == 0 then nat:post("N") end
		if n > 14000 then log("TIMEOUT boot"); error("timeout") end
	end
	recording = true
	note("in flight " .. watched())
	wait(30)
end

-- From flight to the command console's GET, where `pokes` are made (so
-- that the flight program never sees them), and its 2.
local function to_ground(pokes)
	boot()
	key("C")
	get("console", "2", pokes)
end

-- The planet the ship is at, counted from 1.
local HERE = 1
local TECH, BASE = 38282 + HERE, 38303 + HERE

local routes = {}

function routes.ground_menu()
	to_ground()
	get("menu", "Q")
	get("menu_q", "0")
	get("menu_0", "9")
	get("console_again", "2")
	get("menu_again", "2")
	get("menu_recalled", "9")
	get("console_last")
end

function routes.ground_gates()
	to_ground({{BASE, 0}})
	get("menu", "3")
	get("menu_2", "6")
	get("menu_3", "4", {{BASE, 1}, {38158, 5}})
	get("menu_4", "1")
	get("menu_5", "2", {{38166, 1}})
	get("menu_6", "2", {{38158, 1}})
	get("menu_7", "2")
	get("menu_8", "9")
	get("console_last")
end

function routes.ground_leave()
	to_ground({{38208, 0}})
	get("menu", "4")
	get("menu_2", "5")
	get("menu_3", "6")
	get("menu_4", "7")
	get("menu_5", "3")
	get("menu_6", "8")
	get("menu_7", "9")
	get("console_last")
end

function routes.ground_stale()
	to_ground({{38208, 0}})
	get("menu", "7")
	get("menu_2", "9")
	get("page", " ")
	-- the chart, which asks for no key: one after ten seconds of it
	wait(1500)
	key(" ")
	get("console_last")
end

-- 1) ATTACK PLANET, and whatever comes of it up to the next menu.
local function attack(pokes)
	to_ground(pokes)
	get("menu", "1")
	get("menu_after", "9")
	get("console_last")
end

function routes.ground_sol()
	attack()
end

function routes.ground_tech_0()
	attack({{TECH, 0}, {38210, 1}, {38156, 0}})
end

function routes.ground_tech_1()
	attack({{TECH, 1}, {38208, 0}})
end

function routes.ground_tech_2()
	attack({{TECH, 2}, {38208, 0}, {38150, 12}, {38160, 0}, {29469, 20}, {29470, 0}})
end

-- a retreat after two rounds, with half the troops left on the ship;
-- then the attack again
function routes.ground_tech_3()
	to_ground({{TECH, 3}, {38208, 0}, {38150, 30}, {38160, 0}, {38155, 1}})
	get("menu", "1")
	came_to(675, 2)
	key("R")
	get("menu_retreated", "1", {{38155, 6}})
	get("menu_after", "9")
	get("console_last")
end

-- a battle that cannot be won; then RECALL and the attack with no troops
function routes.ground_tech_4()
	to_ground({{TECH, 4}, {38208, 0}, {38150, 255}, {38160, 0}, {38203, 1}, {38205, 0}})
	get("menu", "1")
	get("menu_lost", "2")
	get("menu_recalled", "1", {{38155, 6}})
	get("menu_after", "9")
	get("console_last")
end

-- a planet taken twice in one visit: COLLECT's second helping
function routes.ground_twice()
	to_ground({{TECH, 2}, {38208, 0}, {38150, 5}, {38160, 0}})
	get("menu", "1")
	get("menu_taken", "1")
	get("menu_after", "9")
	get("console_last")
end

function routes.ground_clamp()
	attack({{TECH, 2}, {38208, 0}, {38150, 255}, {38160, 254}})
end

function routes.ground_early_key()
	to_ground()
	get("menu", "1")
	came_to(185, 1)
	key("X")
	get("menu_after", "9")
	get("console_last")
end

function routes.ground_none()
	to_ground({{38155, 0}})
	get("menu", "1")
	get("menu_2", "1", {{38155, 6}, {38207, 1}})
	get("menu_after", "9")
	get("console_last")
end

local script = coroutine.create(function()
	routes[ROUTE]()
	wait(30)
	flush()
end)

local closed = false
local function close(why)
	if closed then return end
	closed = true
	flush()
	log(why)
	f:close()
	g:close()
	manager.machine:exit()
end

emu.register_frame_done(function()
	frame = frame + 1
	if closed then return end
	if coroutine.status(script) == "dead" then
		close("done")
		return
	end
	local ok, err = coroutine.resume(script)
	if not ok then
		close("stopped: " .. tostring(err))
	elseif frame > 400000 then
		close("TIMEOUT")
	end
end)
