-- Live record of the fighting in STARSHIP SIMULATOR.bas (lines 185-192 and
-- the subroutines they call): a pass at a time, the state the fight is
-- begun in, every RND(1) it throws, and the state it leaves.
--
-- The flight program is flown with the ship held still and, each pass, the
-- game's bytes and BASIC's own variables put to a state a script gives (a
-- seeded series of them: the ship in the firing box and out of it, a
-- missile flown at the defender and past it, in the atmosphere and in
-- space, shields up and down, every technology, a planet that has
-- surrendered, and a few for the ends: the defender destroyed, the ship
-- lost). The fire button is held or not as the script says.
--
-- combat_<route>.log, as shore_live.lua's:
--   <ms> [frame] -- at 182 n=<k> line=182 <address>=<value> ... btn=<0|1>
--       the state as the fight begins (the button is read at line 185)
--   <ms> [frame] -- at 200 n=<k> ...                      and as it ends
--       vars <name>=<value> ...        BASIC's real variables
--       drawn <EE:MMMMMMMM> ...        every RND(1) since the last stop
--   <ms> [frame] -- ran <program> ...  a program BASIC ran (EX, DMG, S/X)
--
--   SV_OUT=/tmp/sv_combat WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/combat_live.lua

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local ROUTE = os.getenv("SV_ROUTE") or "combat"
local f = assert(io.open(DIR .. ROUTE .. ".log", "w"))
local function log(s) f:write(s .. "\n") end
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nat = manager.machine.natkeyboard
local ports = manager.machine.ioport.ports
local function field(tag, name)
	local p = ports[tag]
	return p and p.fields[name]
end
local btn = field(":gameio:paddles:paddle_buttons", "P1 Button 1")
local button_down = false
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

combat_live_taps = {}
local taps = combat_live_taps

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
	while a < e and #out < 300 do
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

local WATCHED = {38150, 38152, 38157, 38160, 38165, 38186, 38187, 38193, 38195, 38196, 38197, 38198, 38200, 38201,
	38202, 38204, 38205, 38207, 38208, 38209, 38210, 38220, 38283, 38393, 29473, 29474, 29475}
local function watched()
	local out = {}
	for _, a in ipairs(WATCHED) do out[#out + 1] = string.format("%d=%d", a, mem:read_u8(a)) end
	return table.concat(out, " ")
end

-- A stop: the bytes and the variables under `what`.
local drawn = {}
local function stop(what, basic_line)
	note(string.format("%s line=%d %s btn=%d", what, basic_line, watched(), button_down and 1 or 0))
	log("    vars " .. vars())
	log("    drawn " .. table.concat(drawn, " "))
	drawn = {}
end

taps[#taps + 1] = mem:install_write_tap(29461, 29461, "pass", function(offset, data, mask)
	if pc() < 0xD000 then return end
	passes = passes + 1
end)

-- The lines a program is stopped at, by the name DOS loaded it under.
-- None of them calls a subroutine, so each is come to once a pass.
local STOPS = {
	["STARSHIP SIMULATOR"] = {[182] = true, [200] = true},
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
		if at_stop[n] ~= nil then
			at_stop[n](n)
		end
		stop(string.format("at %d n=%d", n, came[n]), n)
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
	local text = string.format("%02X:%02X%02X%02X%02X", data & 0xFF, mem:read_u8(0xCA) | 0x80, mem:read_u8(0xCB),
		mem:read_u8(0xCC), mem:read_u8(0xCD))
	rnds[#rnds + 1] = text
	drawn[#drawn + 1] = text
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
local function set(name, value, quiet)
	for _, v in ipairs(each_var()) do
		if v[1] == name then
			local e, m, negative = 0, 0, value < 0
			local magnitude = math.abs(value)
			if magnitude > 0 then
				local rest = magnitude
				while rest >= 1 do
					rest = rest / 2
					e = e + 1
				end
				while rest < 0.5 do
					rest = rest * 2
					e = e - 1
				end
				m = math.floor(rest * 4294967296.0)
				e = e + 128
			end
			mem:write_u8(v[3], e)
			mem:write_u8(v[3] + 1, ((m >> 24) & 0x7F) | (negative and 0x80 or 0))
			mem:write_u8(v[3] + 2, (m >> 16) & 0xFF)
			mem:write_u8(v[3] + 3, (m >> 8) & 0xFF)
			mem:write_u8(v[3] + 4, m & 0xFF)
			if not quiet then note(string.format("set %s=%.17g", name, basic(name))) end
			return
		end
	end
	if quiet then return end -- not made yet: BASIC takes it to be 0
	note("NO VARIABLE " .. name)
	error("lost")
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
	program = "STARSHIP SIMULATOR"
	note("in flight " .. watched())
	wait(30)
end

-- --- the series of states ---------------------------------------------

local seed = 1982
local function dice()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local function between(a, b) return a + dice() * (b - a) end
local function whole(a, b) return math.floor(between(a, b + 0.999999)) end
local function chance(p) return dice() < p end

local DEFENDER = {400, -100, -3500}
local HERE = 1
local STEPS = {}

-- a state that is likely to do something, in the way of `kind`
local function state(kind)
	local s = {kind = kind, bytes = {}, vars = {}}
	local b, v = s.bytes, s.vars
	local atmosphere = kind == "atmosphere"
	b[38210] = atmosphere and 1 or 0
	local x, y, z
	local pitch, heading = 0, 0
	if kind == "box" then
		x, y, z = whole(-3400, 4400), whole(-2900, 2900), whole(-5900, -1200)
		pitch, heading = whole(0, 40), whole(0, 255)
	elseif kind == "out" then
		x, y, z = whole(-9000, 9000), whole(-9000, 9000), whole(2500, 9000)
		pitch, heading = whole(0, 40), whole(0, 255)
	elseif kind == "missile" then
		x, y, z = DEFENDER[1] + whole(-260, 260), DEFENDER[2] + whole(-90, 70), DEFENDER[3] - whole(2300, 2700)
		pitch, heading = 0, whole(0, 1) * 255
		if chance(0.3) then heading = 0 end
	elseif kind == "atmosphere" then
		x, y, z = whole(-9000, 9000), whole(120, 3500), whole(-9000, 9000)
		pitch, heading = whole(0, 40), whole(0, 255)
	end
	if chance(0.15) and pitch < 40 then pitch = 256 - whole(1, 60) end
	s.pos = {x, y, z}
	s.attitude = {pitch, 0, heading}
	b[38200] = whole(15, 100)
	b[38201] = chance(0.6) and 1 or 0
	b[38202] = (kind == "missile" or chance(0.4)) and 1 or 0
	b[38165] = whole(1, 3)
	b[38193] = whole(25, 100)
	b[38195] = whole(5, 100)
	b[38198] = whole(5, 100)
	b[38197] = whole(5, 100)
	b[38196] = whole(5, 100)
	b[38186] = chance(0.1) and 0 or whole(5, 100)
	b[38187] = chance(0.1) and 0 or whole(1, 60)
	b[38207] = chance(0.15) and 0 or whole(1, 9)
	b[38208] = chance(0.2) and 1 or 0
	b[38205] = whole(0, 3)
	b[38204] = whole(100, 250)
	b[38150] = whole(20, 250)
	b[38160] = whole(0, 250)
	b[38152] = whole(0, 150)
	b[38393] = 1 -- the damage lamp: a RUN DMG is for the steps that ask
	local tech = whole(0, 4)
	if chance(0.7) then tech = whole(2, 4) end
	b[38282 + HERE] = tech
	b[38219 + HERE] = 0
	v.TE = tech
	v.DM = chance(0.35) and 1 or 0
	v.DP = whole(0, 120)
	v.L = chance(0.2) and 7 or whole(0, 255)
	s.button = chance(0.7)
	return s
end

for i = 1, 70 do STEPS[#STEPS + 1] = state("box") end
for i = 1, 30 do STEPS[#STEPS + 1] = state("out") end
for i = 1, 60 do STEPS[#STEPS + 1] = state("missile") end
for i = 1, 50 do STEPS[#STEPS + 1] = state("atmosphere") end
-- states for the edges of the rules: a base to start from with the parts
-- of it that matter put by hand
local function edge(pos, pitch, heading, extra)
	local s = state("box")
	s.pos = pos
	s.attitude = {pitch, 0, heading}
	s.button = true
	s.bytes[38202] = 1 -- a missile
	s.bytes[38187] = 40
	s.bytes[38205] = 3
	s.bytes[38208] = 0
	s.bytes[38282 + HERE] = 3
	s.vars.TE = 3
	s.bytes[38207] = 0 -- no fighters: only the missile
	s.bytes[38210] = 0
	s.bytes[38204] = 250
	s.bytes[38150] = 250
	s.bytes[38160] = 0
	s.vars.DP = 0
	s.vars.DM = 0
	for k, v in pairs(extra or {}) do s.bytes[k] = v end
	return s
end
-- the box a missile hits in, one dot in and one out on each side: x 250 to
-- 550 on a path along z, y -120 to -40 along z, z -3600 to -3400 with the nose
-- up so that only the first step is near
for _, x in ipairs({250, 251, 549, 550}) do STEPS[#STEPS + 1] = edge({x, -100, -3800}, 0, 0) end
for _, y in ipairs({-120, -119, -41, -40}) do STEPS[#STEPS + 1] = edge({400, y, -3800}, 0, 0) end
for _, z in ipairs({-3600, -3599, -3595, -3590, -3400, -3401, -3405, -3410}) do
	STEPS[#STEPS + 1] = edge({400, -100, z}, 40, 0)
end
-- a shot that fills a byte, and the one that comes to the planet's strength
for _, vp in ipairs({250, 251, 252, 253}) do
	local s = edge({400, -100, -4500}, 0, 0, {[38160] = vp, [38202] = 0, [38186] = 60, [38150] = 250})
	s.vars.TE = 4
	s.bytes[38282 + HERE] = 4
	STEPS[#STEPS + 1] = s
end
for _, strength in ipairs({91, 92, 93}) do
	local s = edge({400, -100, -4500}, 0, 0, {[38160] = 90, [38202] = 0, [38186] = 60, [38150] = strength})
	s.vars.TE = 4
	s.bytes[38282 + HERE] = 4
	STEPS[#STEPS + 1] = s
end
-- the laser at 1 and at 0
for _, laser in ipairs({0, 1, 2}) do
	STEPS[#STEPS + 1] = edge({400, -100, -4500}, 0, 0, {[38202] = 0, [38186] = laser})
end
-- the damage that comes to exactly what the defender can stand (a missile in is 30 at tech 3)
for _, dp in ipairs({69, 70, 71}) do
	local s = edge({400, -100, -3800}, 0, 0, {[38152] = dp, [38204] = 100})
	s.vars.DP = dp
	STEPS[#STEPS + 1] = s
end
-- fighters at condition RED, in the box and in the atmosphere, hostile
for i = 1, 70 do
	local s = state((i % 2 == 0) and "box" or "atmosphere")
	s.bytes[38205] = 3
	s.bytes[38208] = 0
	s.bytes[38282 + HERE] = 3
	s.vars.TE = 3
	s.bytes[38207] = whole(1, 9)
	s.bytes[38165] = (i % 3 == 0) and 2 or 3
	s.bytes[38200] = whole(30, 100)
	s.bytes[38193] = whole(60, 100)
	s.bytes[38187] = whole(10, 60)
	s.button = false
	STEPS[#STEPS + 1] = s
end
-- a missile in the atmosphere at the gauge's own row
for _, below in ipairs({1, 0, -1}) do
	local s = state("atmosphere")
	s.bytes[38202] = 1
	s.bytes[38187] = 40
	s.bytes[38282 + HERE] = 3
	s.vars.TE = 3
	s.bytes[38208] = 0
	s.bytes[38207] = 0
	s.button = true
	s.attitude = {0, 0, whole(0, 60)}
	s.pos_marker = below -- y is put at VV less this when the step is made
	STEPS[#STEPS + 1] = s
end

-- the lamp that goes with the first damage: RUN DMG
for i = 1, 3 do
	local s = state("box")
	s.bytes[38393] = 0
	s.bytes[38205] = 3
	s.bytes[38208] = 0
	s.bytes[38282 + HERE] = 3
	s.vars.TE = 3
	s.button = false
	s.vars.DM = 1
	s.bytes[38201] = 0
	s.bytes[38200] = 5
	s.vars.L = 0
	STEPS[#STEPS + 1] = s
end
-- the defender destroyed: RUN EX
for i = 1, 2 do
	local s = state("box")
	s.bytes[38205] = 3
	s.bytes[38208] = 0
	s.bytes[38204] = 5
	s.vars.DP = 100
	s.bytes[38152] = 100
	s.bytes[38282 + HERE] = 2
	s.vars.TE = 2
	s.bytes[38202] = 0
	s.bytes[38186] = 60
	s.button = true
	STEPS[#STEPS + 1] = s
end
-- a low hull hit with the shields down: the ship may be lost, which ends the
-- series (S/X waits for a key and reboots), so these come last
for i = 1, 6 do
	local s = state("box")
	s.bytes[38205] = 3
	s.bytes[38208] = 0
	s.bytes[38282 + HERE] = 3
	s.vars.TE = 3
	s.bytes[38193] = (i % 2 == 0) and 1 or 2
	s.bytes[38200] = 0
	s.bytes[38201] = 0
	s.vars.DM = 1
	s.vars.L = 0
	s.button = false
	STEPS[#STEPS + 1] = s
end
-- the ship lost: RUN S/X, the end of the recording
do
	local s = state("box")
	s.bytes[38205] = 3
	s.bytes[38208] = 0
	s.bytes[38282 + HERE] = 3
	s.vars.TE = 3
	s.bytes[38193] = 1
	s.bytes[38200] = 0
	s.bytes[38201] = 0
	s.vars.DM = 1
	s.vars.L = 0
	s.button = false
	s.bytes[38393] = 1
	STEPS[#STEPS + 1] = s
end

local step = 0
local last_pass_step = nil

local function apply(s)
	for address, value in pairs(s.bytes) do mem:write_u8(address, value) end
	-- the ship: held still, at the place the step gives
	if s.pos_marker ~= nil then s.pos[2] = math.floor(basic("VV")) - s.pos_marker end
	for i, name in ipairs({"X", "Y", "Z"}) do set(name, s.pos[i], true) end
	for name, value in pairs(s.vars) do set(name, value, true) end
	set("S", 0, true)
	mem:write_u8(38157, 0)
	mem:write_u8(38149, 0) -- line 182: the first pass after a start does no fighting
end

-- The button is put a pass early: MAME takes an input in at a frame's
-- edge, so what is set at line 182 is not what line 185 reads.
local function press_for_next(s)
	button_down = s.button
	if btn ~= nil then btn:set_value(s.button and 1 or 0) end
end

-- At line 182 (the statement before the button is read, which is not
-- itself seen) the next state is put; at line 200 the attitude of the pass
-- after it (the program reads it at line 20 of the pass).
at_stop[182] = function()
	step = step + 1
	if STEPS[step] == nil then return end
	apply(STEPS[step])
end
at_stop[200] = function()
	local s = STEPS[step + 1]
	if s ~= nil then
		for i, a in ipairs({29473, 29474, 29475}) do mem:write_u8(a, s.attitude[i]) end
		press_for_next(s)
	end
end

local routes = {}

function routes.combat()
	boot()
	-- the first pass's attitude, then wait for the whole series
	for i, a in ipairs({29473, 29474, 29475}) do mem:write_u8(a, STEPS[1].attitude[i]) end
	press_for_next(STEPS[1])
	local waited = 0
	while step < #STEPS and waited < 300000 do
		coroutine.yield()
		waited = waited + 1
	end
	wait(900)
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
