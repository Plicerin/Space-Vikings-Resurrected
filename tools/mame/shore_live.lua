-- Live record of SHORE LEAVE.bas, the program GROUND FORCES runs for
-- its commands 3 to 8: shore leave, enlisting and the weapons bought
-- with it, the sale of the loot, repairs, a new base and the cryogenic
-- sleep. For each: the keys, every RND(1) drawn, what was printed, and
-- at each stop the game's bytes and BASIC's variables. It is
-- ground_live.lua without the hi-res pages, which the port no longer
-- copies.
--
-- A stop is one of
--   get   the program is waiting in KEYIN (a GET); a key is then pressed
--   at    BASIC has come to the start of one of the lines in STOPS
--   ran   BASIC is at the first statement of a program just loaded
--
-- SV_ROUTE picks the keys and the pokes. Every poke is made at a GET of
-- GROUND FORCES' menu or of the command console, so no program has a
-- byte changed under it. shore_edges alone also sets BASIC's CR (the
-- credits) to a sum the price just drawn makes exact, which no poke
-- can: at the GET for a weapon, and for the base at line 2105, before
-- the program has looked at its credits.
--
--   shore_gates    a planet that has not surrendered (3 to 7 come
--                  straight back), and 8) CRYOGENICS from each place the
--                  troops can be
--   shore_pay      3) SHORE LEAVE: paid, refused, and not affordable
--   shore_loot     5) SELL LOOT: none, some, all there can be
--   shore_base     7) ESTABLISH BASE: every refusal, N, and Y
--   shore_enlist   4) ENLIST TROOPS and the weapons after it: too dear,
--                  too many, 255 MAX, one time per trip, nothing at all
--   shore_repair   6) REPAIR: not landed, paid, refused, nothing to
--                  mend, and a bill that cannot be met
--   shore_edges    the last number each rule lets through and the first
--                  it does not, where the other routes do not come to it
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_ROUTE=shore_pay SV_OUT=/tmp/sv_shore WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/shore_live.lua
--
-- <route>.log:
--   <ms> [frame] line <n>  x<statements>  "<characters printed>"
--       rnd <exponent>:<mantissa> ...        each RND(1) of the line, as
--                                            Applesoft left it in $C9-$CD
--   <ms> [frame] -- get <name> line=<n> <address>=<value> ...
--   <ms> [frame] -- at <line> n=<times come to> line=<n> ...
--   <ms> [frame] -- ran <program, _ for space> gap=<ms since the last
--        statement> line=<n> ...
--       vars <name>=<value> ...              BASIC's real variables
--   <ms> [frame] -- poke <address>=<value>
--   <ms> [frame] -- set CR=<value>           BASIC's variable, written
--   <ms> [frame] -- key '<character>'        a key for a GET of its own
--   <ms> [frame] -- enter '<digits>'         a number for line 5000, typed
--                                            a digit at a time and ended
--                                            with RETURN

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local ROUTE = os.getenv("SV_ROUTE") or "shore_pay"
local f = assert(io.open(DIR .. ROUTE .. ".log", "w"))
local function log(s) f:write(s .. "\n") end
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nat = manager.machine.natkeyboard
local function pc() return cpu.state["PC"].value end

local function now()
	return manager.machine.time:as_double() * 1000.0
end

local GLYPHS = 0x8800
local frame = 0
local passes = 0
local recording = false
local keyin_frame = -10
local boundaries = 0

shore_live_taps = {}
local taps = shore_live_taps

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

-- BASIC's real variables (VARTAB to ARYTAB, seven bytes each), in the
-- order they were made.
local function each_var()
	local a = mem:read_u8(0x69) | (mem:read_u8(0x6A) << 8)
	local e = mem:read_u8(0x6B) | (mem:read_u8(0x6C) << 8)
	local out = {}
	while a < e and #out < 80 do
		local c1, c2 = mem:read_u8(a), mem:read_u8(a + 1)
		if c1 < 128 and c2 < 128 then
			out[#out + 1] = {string.char(c1) .. (c2 > 0 and string.char(c2) or ""), real(a + 2), a + 2}
		end
		a = a + 7
	end
	return out
end

local function vars()
	local out = {}
	for _, v in ipairs(each_var()) do out[#out + 1] = string.format("%s=%.17g", v[1], v[2]) end
	return table.concat(out, " ")
end

-- The value of the real variable `name`, 0 if there is none yet.
local function basic(name)
	for _, v in ipairs(each_var()) do
		if v[1] == name then return v[2] end
	end
	return 0
end

-- the entry being gathered
local line, began, statements, text = nil, 0, 0, {}
-- the RND(1)s of the line
local rnds = {}

local function flush()
	if line == nil then return end
	log(string.format("%.2f [%d] line %d  x%d  \"%s\"", began, frame, line, statements, table.concat(text)))
	if #rnds > 0 then log("    rnd " .. table.concat(rnds, " ")) end
	rnds = {}
	line = nil
end

local function note(what)
	flush()
	log(string.format("%.2f [%d] -- %s", now(), frame, what))
	f:flush()
end

local WATCHED = {38388, 38151, 38149, 38389, 38393, 38153, 38154, 38155, 38156, 38158, 38166, 38170, 38203,
	38208, 38209, 38210, 38220, 38283, 38304, 301, 29469, 29470,
	38171, 38172, 38173, 38174, 38175, 38176, 38177, 38178, 38179, 38180, 38181, 38182, 38183,
	38184, 38186, 38187, 38190, 38193, 38194, 38195, 38196, 38197, 38198, 38199, 38200}
local function watched()
	local out = {}
	for _, a in ipairs(WATCHED) do out[#out + 1] = string.format("%d=%d", a, mem:read_u8(a)) end
	return table.concat(out, " ")
end

-- A stop: the bytes and the variables under `what`.
local function stop(what, basic_line)
	note(string.format("%s line=%d %s", what, basic_line, watched()))
	log("    vars " .. vars())
end

taps[#taps + 1] = mem:install_write_tap(29461, 29461, "pass", function(offset, data, mask)
	if pc() < 0xD000 then return end
	passes = passes + 1
end)

-- The lines a program is stopped at, by the name DOS loaded it under.
-- None of them calls a subroutine, so each is come to once a pass.
local STOPS = {
	["SHORE LEAVE"] = {[2087] = true, [2096] = true, [2099] = true,
		[2105] = true, [2106] = true, [2107] = true, [2130] = true, [2159] = true,
		[2210] = true, [2240] = true, [2250] = true, [2280] = true, [2285] = true, [2289] = true, [2291] = true,
		[2408] = true,
		[2520] = true, [2540] = true, [2555] = true, [2590] = true, [2602] = true, [2605] = true, [2615] = true,
		[3072] = true, [3090] = true, [3100] = true,
		[4010] = true, [4020] = true},
}
local program = "?"
local came = {}
-- what the route wants done at the next coming to a line of STOPS
local at_stop = {}
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
		if at_stop[n] ~= nil then
			local wanted = at_stop[n]
			at_stop[n] = nil
			wanted()
		end
	end
	last_boundary = now()
	current = n
	if n ~= line then
		flush()
		line, began, statements, text = n, now(), 0, {}
	end
	statements = statements + 1
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
taps[#taps + 1] = mem:install_read_tap(GLYPHS, GLYPHS + 0x3FF, "glyph", function(offset, data, mask)
	if not recording then return end
	local p = pc()
	if p < 0x9300 or p > 0x93FF then return end
	local glyph = (offset - GLYPHS) >> 3
	local column = mem:read_u8(0x24)
	local row = mem:read_u8(0x25)
	-- eight reads a character: the same one in the same place is one
	if glyph == last_glyph and column == last_column and row == last_row and frame - last_glyph_frame < 2 then return end
	last_glyph, last_column, last_row, last_glyph_frame = glyph, column, row, frame
	if line ~= nil then text[#text + 1] = (glyph >= 32 and glyph < 127) and string.char(glyph) or "." end
end)

-- the script, a coroutine resumed once a frame

local function wait(n)
	for i = 1, n do coroutine.yield() end
end

local function poke(address, value)
	mem:write_u8(address, value)
	note(string.format("poke %d=%d", address, value))
end

-- Makes BASIC's real variable `name` the whole number `value` (none
-- below zero).
local function set(name, value)
	for _, v in ipairs(each_var()) do
		if v[1] == name then
			local e, m = 0, 0
			if value > 0 then
				local rest = value
				while rest >= 1 do
					rest = rest / 2
					e = e + 1
				end
				m = math.floor(rest * 4294967296.0)
				e = e + 128
			end
			mem:write_u8(v[3], e)
			mem:write_u8(v[3] + 1, (m >> 24) & 0x7F)
			mem:write_u8(v[3] + 2, (m >> 16) & 0xFF)
			mem:write_u8(v[3] + 3, (m >> 8) & 0xFF)
			mem:write_u8(v[3] + 4, m & 0xFF)
			note(string.format("set %s=%.17g", name, basic(name)))
			return
		end
	end
	note("NO VARIABLE " .. name)
	error("lost")
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

-- Presses `k` and waits for BASIC to get to its next statement.
local function press(k, what)
	local before = boundaries
	nat:post(k)
	local n = 0
	while boundaries == before do
		coroutine.yield()
		n = n + 1
		if n > 600 then
			note("no statement after the key: " .. what)
			return
		end
	end
end

local function here()
	return mem:read_u8(0x75) | (mem:read_u8(0x76) << 8)
end

-- Waits for the program to sit in KEYIN, makes `pokes`, writes the stop
-- under `name` and presses `k` if there is one.
local function get(name, k, pokes, most)
	at_get(name, most)
	for _, p in ipairs(pokes or {}) do poke(p[1], p[2]) end
	stop("get " .. name, here())
	if k == nil then return end
	note(string.format("key '%s'", k))
	press(k, name)
end

-- The same at GROUND FORCES' menu and nowhere else.
local function menu(k, pokes)
	at_get("menu")
	if program ~= "GROUND FORCES" then
		note("NOT AT THE MENU: " .. program .. " line " .. here())
		error("lost")
	end
	get("menu", k, pokes)
end

-- A number for line 5000's entry: the digits and RETURN. `first` is
-- done once the stop is written.
local function number(name, digits, first)
	at_get(name)
	stop("get " .. name, here())
	if first ~= nil then first() end
	note(string.format("enter '%s'", digits))
	for c in digits:gmatch(".") do
		press(c, name)
		at_get(name)
	end
	press("\r", name)
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
	note("key 'C'")
	nat:post("C")
	get("console", "2", pokes)
end

local function leave()
	menu("9")
	get("console_last")
end

-- The planet the ship is at, counted from 1.
local HERE = 1
local SECURED, TECH, BASE = 38219 + HERE, 38282 + HERE, 38303 + HERE
local LANDED = {{38210, 1}, {29469, 20}, {29470, 0}}

local routes = {}

function routes.shore_gates()
	to_ground({{38208, 0}})
	menu("3")
	menu("4")
	menu("5")
	menu("6")
	menu("7")
	-- 8 is let through: the troops are asleep in a new game
	menu("8")
	menu("8")
	menu("8", {{38166, 1}})
	menu("8", {{38166, 2}})
	menu("8", {{38166, 0}, {38208, 1}})
	leave()
end

function routes.shore_pay()
	to_ground()
	menu("3")
	get("pay", "X")
	get("pay", "Y")
	menu("3", {{38203, 3}})
	get("pay", "Y")
	menu("3")
	get("pay", "N")
	menu("3")
	get("pay", "N")
	menu("3")
	get("pay", "N")
	menu("3")
	get("pay", "Y")
	menu("3")
	get("pay", "Y")
	-- the pay is all the credits there are
	menu("3")
	get("pay", "Y")
	-- and now more than there are
	menu("3")
	get("pay", "Y")
	leave()
end

function routes.shore_loot()
	to_ground()
	menu("5")
	local some = {3, 7, 1, 2, 5, 4, 6, 20, 30, 9, 2, 1, 3}
	local pokes = {}
	for i, n in ipairs(some) do pokes[#pokes + 1] = {38170 + i, n} end
	menu("5", pokes)
	pokes = {}
	for i = 1, 13 do pokes[#pokes + 1] = {38170 + i, 255} end
	menu("5", pokes)
	menu("5", {{38171, 200}})
	leave()
end

function routes.shore_base()
	to_ground()
	menu("7")
	menu("7", {{BASE, 0}, {TECH, 1}})
	-- dearer than a new game's credits
	menu("7", {{TECH, 2}})
	menu("7")
	-- credits: the sale needs the base the planet is to be without
	menu("5", {{BASE, 1}, {38172, 255}, {38177, 255}})
	menu("7", {{BASE, 0}, {38149, 0}})
	get("build", "X")
	get("build", "N")
	menu("7")
	menu("7", {{38149, 0}})
	get("build", "Y")
	menu("7", {{38149, 0}})
	leave()
end

-- A number that the credits will and will not pay for at the price
-- asked, and no more of the weapon than a byte holds.
local function affordable(aboard)
	local most = math.floor(basic("CR") / basic("C"))
	return math.max(0, math.min(most, 255 - aboard))
end

function routes.shore_enlist()
	to_ground()
	menu("4")
	number("enlist", "20000")
	number("enlist", "500")
	-- fighters, 75 aboard
	number("buy", "300")
	number("buy", "200")
	at_get("buy")
	number("buy", tostring(affordable(0) + 1))
	number("buy", "10")
	-- a transport, no tanks, and missiles with what is left
	number("buy", "1")
	number("buy", "")
	at_get("buy")
	number("buy", tostring(affordable(mem:read_u8(38153))))
	menu("4")
	menu("5", {{38172, 255}})
	menu("4", {{38389, 0}})
	number("enlist", "18000")
	number("enlist", "17500")
	number("buy", tostring(255 - mem:read_u8(38156)))
	number("buy", "")
	at_get("buy")
	number("buy", tostring(affordable(mem:read_u8(38154))))
	number("buy", "0")
	-- nobody, and nothing
	menu("4", {{38389, 0}})
	number("enlist", "")
	number("buy", "")
	number("buy", "")
	number("buy", "")
	number("buy", "")
	leave()
end

-- 6, and the key for the bill if one is asked for.
local function repair(k, pokes)
	menu("6", pokes)
	at_get("bill")
	if program == "SHORE LEAVE" then get("bill", k) end
end

function routes.shore_repair()
	to_ground()
	menu("6")
	menu("6", {{38210, 1}, {29469, 30}, {29470, 0}})
	-- a new game's ship: the missiles are at 60
	repair("Y", LANDED)
	repair("N")
	repair("X", {{38198, 90}, {38199, 40}, {38187, 95}, {38393, 1}})
	repair("N", {{38197, 80}, {38199, 62}, {38184, 85}})
	local wreck = {{SECURED, 1}, {38208, 1}, {38393, 1}}
	local left = {50, 0, 99, 0, 37, 100, 64, 7, 81, 13, 63, 1}
	for i, a in ipairs({38200, 38199, 38198, 38197, 38196, 38195, 38194, 38193, 38190, 38187, 38186, 38184}) do
		wreck[#wreck + 1] = {a, left[i]}
	end
	repair("Y", wreck)
	repair("Y", {{SECURED, 1}, {38208, 1}, {38200, 0}})
	menu("9", {{38208, 1}})
	get("console_last")
end

function routes.shore_edges()
	to_ground()
	-- on the ground at a height of 22 and not at 23, nor at any outside
	-- the atmosphere
	repair("Y", {{38210, 1}, {29469, 22}, {29470, 0}})
	menu("6", {{29469, 23}})
	menu("6", {{38210, 0}, {29469, 20}})
	-- as many recruits as there are credits
	menu("4")
	at_get("enlist")
	number("enlist", tostring(math.floor(basic("CR"))))
	-- three fighters for exactly what they cost
	number("buy", "3", function() set("CR", 3 * basic("C")) end)
	number("buy", "")
	-- 255 tanks with nothing, then with exactly what they cost
	number("buy", "255")
	number("buy", "255", function() set("CR", 255 * basic("C")) end)
	number("buy", "")
	-- nothing to mend and nothing to pay it with
	repair("N", LANDED)
	-- 7 with a base here and one built this trip, then with a planet too
	-- backward and one built this trip
	menu("7", {{38149, 1}})
	menu("7", {{BASE, 0}, {TECH, 1}})
	-- a base for exactly the credits there are
	at_get("menu")
	at_stop[2105] = function() set("CR", math.floor(basic("C"))) end
	menu("7", {{TECH, 2}, {38149, 0}})
	get("build", "Y")
	-- leave, with the troops put down as being at another star
	menu("3", {{38158, 2}})
	get("pay", "N")
	leave()
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
