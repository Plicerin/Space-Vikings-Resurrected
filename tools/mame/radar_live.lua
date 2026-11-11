-- Live record of RADAR.bas and the SHIP # N I.D. programs: the view
-- from above that A2-3D1 draws, the frame and the cross BASIC draws on
-- it, the identification sheets, and the ways out (flight, or COM when
-- COM ran it). The same clock as reports_live.lua: when each BASIC line
-- started, every character the generator drew, and both hi-res pages at
-- each stop.
--
-- SV_ROUTE picks the keys:
--
--   radar        a new game at SOL: R in flight, the radar, X back to
--                flight
--   radar_ids    R, then any key but X for the ship's I.D., a key back
--                to the radar; again with 38205 poked to each type
--   radar_com    from the command console (3), the I.D. and back, X to
--                the console, 5) RETURN into flight
--   radar_dead   the radar's byte (38195) poked to 0 at the console:
--                3 from the console, then R in flight
--   radar_ship_0, _1, _4
--                SV_ASSETS/ship_<n>.bin (the SHIP # n file as it is on
--                the disk) written at $7879 at the console as BLOAD
--                would, 38205 poked to n and the eye to SV_EYE ("x,z",
--                0,0 if not given), then the radar from the console
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_ROUTE=radar SV_OUT=/tmp/sv_radar WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/radar_live.lua \
--     -snapshot_directory /tmp/sv_radar -snapname "snap_%i"
--
-- radar_<route>.log:
--   <ms> [frame] line <n>  x<statements>  p1=<stores on page 1>
--        (<first ms>..<last ms>)  p2=<stores on page 2>
--        tx=<stores on the text screen> (<first ms>..<last ms>)  "<characters>"
--       at <ms after the line's start> ...   each statement of a line in TIMED
--       stores <frame>:<stores on page 1 in it> ...   line 2005, the view being drawn
--   <ms> [frame] -- get <name> line=<n> ...   the program is waiting in
--        KEYIN; <route>_<name>_p1.bin and _p2.bin written, then the key
--   <ms> [frame] -- poke <address>=<value>
--   <ms> [frame] -- switch <text|graphics|...>   a display switch changed
-- radar_<route>_glyphs.log, a line a character:
--   <ms> <line> <code> <column> <row> <973> <974>  <left> <width> <top> <bottom>
--   (column and row are the cursor before the character)

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local ROUTE = os.getenv("SV_ROUTE") or "radar"
local f = assert(io.open(DIR .. "radar_" .. ROUTE .. ".log", "w"))
local g = assert(io.open(DIR .. "radar_" .. ROUTE .. "_glyphs.log", "w"))
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

radar_live_taps = {}
local taps = radar_live_taps

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

-- the entry being gathered
local line, began, statements, p1, p2, text = nil, 0, 0, 0, 0, {}
local p1_first, p1_last = 0, 0
-- stores on the text screen (line 2059's HLINs, which nobody sees)
local tx, tx_first, tx_last = 0, 0, 0
-- the lines whose statements are timed one by one, and when each of the
-- line in hand started (ms after the line did)
local TIMED = {[320] = true, [2005] = true, [2057] = true, [2058] = true, [2059] = true, [5000] = true,
	[5002] = true, [5005] = true, [11] = true, [12] = true, [1060] = true, [1070] = true}
local at = {}
-- line 2005's stores on page 1, frame by frame (the view being drawn)
local paint, paint_frames = {}, {}

local function flush()
	if line == nil then return end
	local span = ""
	if p1 > 0 then span = string.format(" (%.2f..%.2f)", p1_first, p1_last) end
	local screen = ""
	if tx > 0 then screen = string.format(" tx=%d (%.2f..%.2f)", tx, tx_first, tx_last) end
	log(string.format("%.2f [%d] line %d  x%d  p1=%d%s p2=%d%s  \"%s\"", began, frame, line, statements,
		p1, span, p2, screen, table.concat(text)))
	if #at > 1 then log("    at " .. table.concat(at, " ")) end
	if #paint_frames > 0 then
		local out = {}
		for _, fr in ipairs(paint_frames) do out[#out + 1] = string.format("%d:%d", fr, paint[fr]) end
		log("    stores " .. table.concat(out, " "))
	end
	line = nil
end

local function note(what)
	flush()
	log(string.format("%.2f [%d] -- %s", now(), frame, what))
	f:flush()
end

taps[#taps + 1] = mem:install_write_tap(29461, 29461, "pass", function(offset, data, mask)
	if pc() < 0xD000 then return end
	passes = passes + 1
end)

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
	if n ~= line then
		flush()
		line, began, statements, p1, p2, text = n, now(), 0, 0, 0, {}
		tx = 0
		at = {}
		paint, paint_frames = {}, {}
	end
	statements = statements + 1
	if TIMED[n] then at[#at + 1] = string.format("%.1f", now() - began) end
end)

taps[#taps + 1] = mem:install_write_tap(0x2000, 0x5FFF, "pages", function(offset, data, mask)
	if line == nil then return end
	if offset < 0x4000 then
		if line == 2005 then
			if paint[frame] == nil then
				paint[frame] = 0
				paint_frames[#paint_frames + 1] = frame
			end
			paint[frame] = paint[frame] + 1
		end
		if p1 == 0 then p1_first = now() end
		p1_last = now()
		p1 = p1 + 1
	else
		p2 = p2 + 1
	end
end)

taps[#taps + 1] = mem:install_write_tap(0x400, 0x7FF, "text", function(offset, data, mask)
	if line == nil then return end
	if tx == 0 then tx_first = now() end
	tx_last = now()
	tx = tx + 1
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

local function wait_until(what, test, most)
	local n = 0
	while not test() do
		coroutine.yield()
		n = n + 1
		if n > (most or 12000) then
			note("TIMEOUT waiting for " .. what)
			error("timeout")
		end
	end
	note(string.format("%s (after %d)", what, n))
end

local function key(k)
	note(string.format("key '%s'", k))
	nat:post(k)
end

local function poke(address, value)
	mem:write_u8(address, value)
	note(string.format("poke %d=%d", address, value))
end

local WATCHED = {38388, 38391, 38151, 38195, 38205, 29461, 29463, 29465, 29467, 29468, 29469, 29470, 29471, 29472, 29473, 29474, 29475, 38209, 0xE6}
local function watched()
	local out = {}
	for _, a in ipairs(WATCHED) do out[#out + 1] = string.format("%d=%d", a, mem:read_u8(a)) end
	return table.concat(out, " ")
end

-- Waits for the program to sit in KEYIN, writes the two pages under
-- `name`, and presses `k` ("LEFT" is the left arrow, the Apple's
-- backspace).
local function get(name, k, most)
	local held = 0
	local n = 0
	while held < 3 do
		coroutine.yield()
		n = n + 1
		if keyin_frame >= frame - 1 then held = held + 1 else held = 0 end
		if n > (most or 9000) then
			note("TIMEOUT waiting for the GET of " .. name)
			error("timeout")
		end
	end
	local basic_line = mem:read_u8(0x75) | (mem:read_u8(0x76) << 8)
	note(string.format("get %s line=%d ch=%d cv=%d window=%d,%d,%d,%d c973=%d c974=%d %s", name, basic_line,
		mem:read_u8(CH), mem:read_u8(CV), mem:read_u8(32), mem:read_u8(33), mem:read_u8(34), mem:read_u8(35),
		mem:read_u8(973), mem:read_u8(974), watched()))
	dump_page(0x2000, ROUTE .. "_" .. name .. "_p1.bin")
	dump_page(0x4000, ROUTE .. "_" .. name .. "_p2.bin")
	-- taken when BASIC gets to its next statement
	local before = boundaries
	if k == "LEFT" then
		note("key LEFT")
		left_arrow:set_value(1)
		wait(3)
		left_arrow:set_value(0)
	else
		key(k)
	end
	n = 0
	while boundaries == before do
		coroutine.yield()
		n = n + 1
		if n > 600 then
			note("no statement after the key: " .. name)
			return
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

local function fly(what)
	local n = passes
	wait_until(what, function() return passes > n + 2 end, 9000)
	dump_page(0x2000, ROUTE .. "_" .. what .. "_p1.bin")
	dump_page(0x4000, ROUTE .. "_" .. what .. "_p2.bin")
end

-- Waits until the generator's last characters are `tail` and four
-- frames more, and writes the pages: a message held by a FOR loop.
local function shown(name, tail, most)
	local n = 0
	while recent:sub(-#tail) ~= tail do
		coroutine.yield()
		n = n + 1
		if n > (most or 3000) then
			note("TIMEOUT waiting for " .. name)
			error("timeout")
		end
	end
	wait(4)
	note(string.format("shown %s line=%d ch=%d cv=%d window=%d,%d,%d,%d c973=%d c974=%d %s", name,
		mem:read_u8(0x75) | (mem:read_u8(0x76) << 8),
		mem:read_u8(CH), mem:read_u8(CV), mem:read_u8(32), mem:read_u8(33), mem:read_u8(34), mem:read_u8(35),
		mem:read_u8(973), mem:read_u8(974), watched()))
	dump_page(0x2000, ROUTE .. "_" .. name .. "_p1.bin")
	dump_page(0x4000, ROUTE .. "_" .. name .. "_p2.bin")
end

-- the display switches, as last touched
local switches = {[0] = "graphics", "full", "page1", "lores"}
local SWITCH = {[0] = "graphics", "text", "full", "mixed", "page1", "page2", "lores", "hires"}
local function touched(offset, data, mask)
	local n = offset - 0xC050
	if switches[n >> 1] == SWITCH[n] then return end
	switches[n >> 1] = SWITCH[n]
	if recording then note("switch " .. SWITCH[n]) end
end
taps[#taps + 1] = mem:install_read_tap(0xC050, 0xC057, "switch_r", touched)
taps[#taps + 1] = mem:install_write_tap(0xC050, 0xC057, "switch_w", touched)

local function text_screen()
	local rows = {}
	for row = 0, 23 do
		local a = 0x400 + (row & 7) * 0x80 + (row >> 3) * 0x28
		local s = {}
		for c = 0, 39 do
			local ch = mem:read_u8(a + c) & 0x7F
			if ch < 32 then ch = ch + 64 end
			s[#s + 1] = string.char(ch)
		end
		local line_ = table.concat(s):gsub("%s+$", "")
		if line_ ~= "" then rows[#rows + 1] = string.format("%2d|%s", row, line_) end
	end
	return table.concat(rows, "\n")
end

-- The machine left to itself for `seconds`, looked at once a second.
local function observe(name, seconds)
	local last_text = nil
	for second = 1, seconds do
		wait(60)
		local s = cpu.state
		note(string.format("watch %d pc=%04X sp=%02X line=%d %s %s %s %s ch=%d cv=%d passes=%d %s", second, pc(),
			s["SP"].value & 0xFF, mem:read_u8(0x75) | (mem:read_u8(0x76) << 8),
			switches[0], switches[1], switches[2], switches[3], mem:read_u8(CH), mem:read_u8(CV), passes, watched()))
		local t = text_screen()
		if t ~= last_text then
			last_text = t
			log(t)
		end
		if second == 3 or second == seconds then
			dump_page(0x2000, string.format("%s_%s_%d_p1.bin", ROUTE, name, second))
			dump_page(0x4000, string.format("%s_%s_%d_p2.bin", ROUTE, name, second))
			manager.machine.video:snapshot()
		end
	end
end

-- Waits for the program to sit in KEYIN, with no page written.
local function at_get()
	local held = 0
	local n = 0
	while held < 3 do
		coroutine.yield()
		n = n + 1
		if keyin_frame >= frame - 1 then held = held + 1 else held = 0 end
		if n > 9000 then note("TIMEOUT waiting for a GET"); error("timeout") end
	end
end

-- From flight to the command console's GET, where `pokes` are made (so
-- that the flight program never sees them).
local function to_console(pokes)
	boot()
	key("C")
	at_get()
	for _, p in ipairs(pokes or {}) do poke(p[1], p[2]) end
end

local routes = {}

function routes.radar()
	boot()
	key("R")
	get("radar", "X")
	fly("flying")
end

function routes.radar_ids()
	boot()
	key("R")
	get("radar", "A")
	get("id", " ")
	local own = mem:read_u8(38205)
	for _, n in ipairs({1, 2, 3, 4, 0}) do
		at_get()
		poke(38205, n)
		get("radar_" .. n, "\r")
		get("id_" .. n, "X")
	end
	at_get()
	poke(38205, own)
	get("radar_last", "X")
	fly("flying")
end

function routes.radar_com()
	to_console()
	get("console", "3")
	get("radar", "Q")
	get("id", " ")
	get("radar_again", "X")
	get("console_again", "5")
	fly("flying")
end

function routes.radar_dead()
	to_console({{38195, 0}})
	get("console", "3")
	get("console_again", "5")
	fly("flying")
	key("R")
	wait(60)
	fly("flying_again")
end

-- SHIP # n as it is on the disk (SV_ASSETS/ship_<n>.bin) written at
-- $7879 as BLOAD would, its type in 38205, and the eye over SV_EYE.
local function ship_route(n)
	local file = assert(io.open(os.getenv("SV_ASSETS") .. "/ship_" .. n .. ".bin", "rb"))
	local bytes = file:read("a")
	file:close()
	to_console()
	for i = 1, #bytes do mem:write_u8(0x7879 + i - 1, bytes:byte(i)) end
	note(string.format("ship %d written at $7879, %d bytes", n, #bytes))
	poke(38205, n)
	local x, z = (os.getenv("SV_EYE") or "0,0"):match("(-?%d+),(-?%d+)")
	x, z = tonumber(x) & 0xFFFF, tonumber(z) & 0xFFFF
	poke(29467, x & 255)
	poke(29468, x >> 8)
	poke(29471, z & 255)
	poke(29472, z >> 8)
	get("console", "3")
	get("radar", "X")
	get("console_again", "5")
	fly("flying")
end
for _, n in ipairs({0, 1, 4}) do
	routes["radar_ship_" .. n] = function() ship_route(n) end
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
	elseif frame > 160000 then
		close("TIMEOUT")
	end
end)
