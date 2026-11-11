-- Live record of what the star chart (GALAXY MAP.bas lines 3000-3320) says
-- of a paddle position: a new game, C, 1, 3, then one probe after another,
-- the paddles set to a place, the button pressed, and BASIC's PX, PY and P
-- (the star found, or 21) and the characters the chart printed noted; "N"
-- to the question when there was one. No hi-res pages are written.
-- Probes: the cell of each of the twenty stars, the cells round the edge of
-- a star's three columns and two rows, and the ends of both paddles.
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_OUT=/tmp/sv_chart WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/chart_rules_live.lua
--
-- chart_rules_live.log:
--   "probe"  the paddle values set, then "result" BASIC's PX PY P after
--   "ch"     a glyph: code, column and row (0-based) of what was printed

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "chart_rules_live.log", "w"))
local function log(s) f:write(s .. "\n"); f:flush() end

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nat = manager.machine.natkeyboard
local ports = manager.machine.ioport.ports
local function pc() return cpu.state["PC"].value end

local function field(tag, name)
	local p = ports[tag]
	return p and p.fields[name]
end
local pdl0 = field(":gameio:paddles:paddle_1", "Paddle")
local pdl1 = field(":gameio:paddles:paddle_2", "Paddle 2")
local btn = field(":gameio:paddles:paddle_buttons", "P1 Button 1")
log(string.format("pdl0=%s pdl1=%s btn=%s", tostring(pdl0), tostring(pdl1), tostring(btn)))

local CH, CV = 0x24, 0x25
local GLYPHS = 0x8800
local GENERATOR_FIRST, GENERATOR_LAST = 0x9300, 0x93FF

local frame = 0
local passes = 0
local triggers = 0
local glyphs = 0
local button_reads = 0
local recording = false

chart_live_taps = {}
local taps = chart_live_taps

local rowbase = {}
for y = 0, 191 do
	rowbase[y] = (y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 0x28
end
local function dump_page(base, name)
	local out = assert(io.open(DIR .. name, "wb"))
	for y = 0, 191 do
		local a = base + rowbase[y]
		local row = {}
		for c = 0, 39 do row[#row + 1] = string.char(mem:read_u8(a + c)) end
		out:write(table.concat(row))
	end
	out:close()
end

-- An Applesoft real variable by its two-letter name, from the simple
-- variable table (VARTAB $69, ARYTAB $6B; 7 bytes a variable).
local function variable(name)
	local c1 = name:byte(1)
	local c2 = #name > 1 and name:byte(2) or 0
	local a = mem:read_u8(0x69) | (mem:read_u8(0x6A) << 8)
	local last = mem:read_u8(0x6B) | (mem:read_u8(0x6C) << 8)
	while a < last do
		if mem:read_u8(a) == c1 and mem:read_u8(a + 1) == c2 then
			local e = mem:read_u8(a + 2)
			if e == 0 then return 0 end
			local b1 = mem:read_u8(a + 3)
			local m = ((b1 | 0x80) << 24) | (mem:read_u8(a + 4) << 16) | (mem:read_u8(a + 5) << 8) | mem:read_u8(a + 6)
			local v = m / 4294967296 * 2 ^ (e - 128)
			if b1 >= 128 then v = -v end
			return v
		end
		a = a + 7
	end
	return nil
end

local function dump(name)
	log(string.format("[%d] dump %s PX=%s PY=%s P=%s CH=%d CV=%d c974=%d c973=%d 38388=%d 38391=%d 38149=%d", frame, name,
		tostring(variable("PX")), tostring(variable("PY")), tostring(variable("P")),
		mem:read_u8(CH), mem:read_u8(CV), mem:read_u8(974), mem:read_u8(973),
		mem:read_u8(38388), mem:read_u8(38391), mem:read_u8(38149)))
end

taps[#taps + 1] = mem:install_write_tap(29461, 29461, "pass", function(offset, data, mask)
	if pc() < 0xD000 then return end
	passes = passes + 1
end)

taps[#taps + 1] = mem:install_read_tap(0xC070, 0xC070, "pdl", function(offset, data, mask)
	triggers = triggers + 1
	if recording then log(string.format("[%d] pdl", frame)) end
end)

taps[#taps + 1] = mem:install_read_tap(0xC061, 0xC061, "button", function(offset, data, mask)
	button_reads = button_reads + 1
end)

local last_glyph_frame, last_glyph, last_column = -1, -1, -1
taps[#taps + 1] = mem:install_read_tap(GLYPHS, GLYPHS + 0x3FF, "glyph", function(offset, data, mask)
	if not recording then return end
	local p = pc()
	if p < GENERATOR_FIRST or p > GENERATOR_LAST then return end
	local glyph = (offset - GLYPHS) >> 3
	local column = mem:read_u8(CH)
	if glyph == last_glyph and column == last_column and frame - last_glyph_frame < 2 then return end
	last_glyph, last_column, last_glyph_frame = glyph, column, frame
	glyphs = glyphs + 1
	local shown = (glyph >= 32 and glyph < 127) and string.char(glyph) or "."
	log(string.format("[%d] ch %3d '%s' col=%d row=%d c974=%d c973=%d", frame, glyph, shown, column,
		mem:read_u8(CV), mem:read_u8(974), mem:read_u8(973)))
end)

for _, addr in ipairs({973, 974, 38388, 38391, 38149}) do
	taps[#taps + 1] = mem:install_write_tap(addr, addr, "w" .. addr, function(offset, data, mask)
		if not recording then return end
		log(string.format("[%d] w %d=%d pc=%04X", frame, addr, data, pc()))
	end)
end

-- the script, a coroutine resumed once a frame

local function wait(n)
	for i = 1, n do coroutine.yield() end
end

local function wait_until(what, test, most)
	local n = 0
	while not test() do
		coroutine.yield()
		n = n + 1
		if n > (most or 12000) then
			log(string.format("[%d] TIMEOUT waiting for %s", frame, what))
			error("timeout")
		end
	end
	log(string.format("[%d] %s (after %d)", frame, what, n))
end

local function key(k)
	log(string.format("[%d] key '%s'", frame, k))
	nat:post(k)
end

local function paddles(x, y)
	pdl0:set_value(x)
	pdl1:set_value(y)
	log(string.format("[%d] paddles %d %d", frame, x, y))
end

-- the next turn of the chart's loop, at its button read: the cursor is
-- on the screen there (drawn by line 3120, taken off by line 3200)
local function at_button_read(what)
	local n = button_reads
	wait_until(what, function() return button_reads > n end)
end

-- hold the button until the program prints something
local function press_button()
	local n = glyphs
	btn:set_value(1)
	log(string.format("[%d] btn down", frame))
	wait_until("first glyph after the button", function() return glyphs > n end)
	btn:set_value(0)
	log(string.format("[%d] btn up", frame))
end

local function next_chart(what)
	local n = triggers
	wait_until(what, function() return triggers > n end)
end


-- the stars' places (PLANET_X, PLANET_Y of the port; the bytes at 38366 + P,
-- 38345 + P)
local function star(p) return mem:read_u8(38366 + p), mem:read_u8(38345 + p) end

local function probe(n, x, y)
	paddles(x, y)
	log(string.format("[%d] probe %d pdl=%d,%d", frame, n, x, y))
	wait(120)
	press_button()
	wait(420)
	log(string.format("[%d] result %d PX=%s PY=%s P=%s", frame, n, tostring(variable("PX")), tostring(variable("PY")),
		tostring(variable("P"))))
	local p = variable("P")
	if p ~= nil and p >= 1 and p <= 20 then
		local t = triggers
		key("N")
		wait_until("chart drawn again", function() return triggers > t + 4 end, 6000)
	else
		local t = triggers
		wait_until("the loop again", function() return triggers > t + 2 end, 3000)
	end
end

local script = coroutine.create(function()
	local boot = 0
	while passes < 3 do
		coroutine.yield()
		boot = boot + 1
		if boot >= 180 and boot % 300 == 0 and boot <= 6000 and passes == 0 then nat:post("N") end
		if boot > 14000 then log("TIMEOUT boot"); error("timeout") end
	end
	log(string.format("[%d] in flight", frame))
	recording = true
	key("C")
	wait(2400)
	key("1")
	wait(600)
	paddles(128, 96)
	key("3")
	next_chart("chart drawn, first paddle read")
	wait(200)
	local n = 0
	-- the cell of each star: PX = X * 10 - 35, PY = Y * 5 (PDL(0) * 1.19 = PX)
	local probes = {}
	for p = 1, 20 do
		local x, y = star(p)
		log(string.format("star %d %d %d %d", p, x, y, mem:read_u8(38366 + p - 42)))
		probes[#probes + 1] = {math.floor((x * 10 - 35) / 1.19 + 0.5), y * 5}
	end
	-- the edges of the cells of stars 1, 7, 13 and 20: a column and a row in,
	-- one out, on each side
	for _, p in ipairs({1, 7, 13, 20}) do
		local x, y = star(p)
		for _, dc in ipairs({-2, -1, 1, 2}) do
			probes[#probes + 1] = {math.floor(((x + dc) * 10 - 35) / 1.19 + 0.5), y * 5}
		end
		for _, dr in ipairs({-2, -1, 1}) do
			probes[#probes + 1] = {math.floor((x * 10 - 35) / 1.19 + 0.5), (y + dr) * 5}
		end
	end
	-- the ends of the paddles
	probes[#probes + 1] = {0, 0}
	probes[#probes + 1] = {255, 255}
	probes[#probes + 1] = {0, 255}
	probes[#probes + 1] = {255, 0}
	for _, pr in ipairs(probes) do
		n = n + 1
		probe(n, pr[1], pr[2])
	end
	wait(30)
end)

local closed = false
local function close(why)
	if closed then return end
	closed = true
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
