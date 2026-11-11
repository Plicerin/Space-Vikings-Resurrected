-- Live record of COM.bas, the command console: every menu, every wrong
-- key, the course entry with its backspace and its RETURN, the directory
-- and its pages, and the ways out. A line-by-line clock (as
-- lines_live.lua), every character the generator drew with its time and
-- place, and both hi-res pages each time the program stops for a key.
--
-- SV_ROUTE picks the keys:
--
--   menus    a new game at SOL: all of COM's own screens, then back to
--            flight
--   damaged  the same start with the computer, the radar and the power
--            poked low before C is pressed, for the inverse labels and
--            "COMPUTER NOT FUNCTIONING"
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_ROUTE=menus SV_OUT=/tmp/sv_com WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/com_live.lua \
--     -snapshot_directory /tmp/sv_com -snapname "snap_%i"
--
-- com_<route>.log:
--   <ms> [frame] line <n>  x<statements>  p1=<stores on page 1>
--        (<first ms>..<last ms>)  p2=<stores on page 2>  "<characters>"
--   <ms> [frame] -- get <name> line=<n> ...   the program is waiting in
--        KEYIN; <route>_<name>_p1.bin and _p2.bin written, then the key
--   <ms> [frame] -- poke <address>=<value>
-- com_<route>_glyphs.log, a line a character:
--   <ms> <line> <code> <column> <row> <973> <974>  <left> <width> <top> <bottom>
--   (column and row are the cursor before the character)

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local ROUTE = os.getenv("SV_ROUTE") or "menus"
local f = assert(io.open(DIR .. "com_" .. ROUTE .. ".log", "w"))
local g = assert(io.open(DIR .. "com_" .. ROUTE .. "_glyphs.log", "w"))
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

com_live_taps = {}
local taps = com_live_taps

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

local function flush()
	if line == nil then return end
	local span = ""
	if p1 > 0 then span = string.format(" (%.2f..%.2f)", p1_first, p1_last) end
	log(string.format("%.2f [%d] line %d  x%d  p1=%d%s p2=%d  \"%s\"", began, frame, line, statements,
		p1, span, p2, table.concat(text)))
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
	local at = mem:read_u8(0xB8) | (mem:read_u8(0xB9) << 8)
	local n = mem:read_u8(0x75) | (mem:read_u8(0x76) << 8)
	if mem:read_u8(at) == 0 then
		n = mem:read_u8(at + 3) | (mem:read_u8(at + 4) << 8)
	end
	if n ~= line then
		flush()
		line, began, statements, p1, p2, text = n, now(), 0, 0, 0, {}
	end
	statements = statements + 1
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

local last_glyph_frame, last_glyph, last_column, last_row = -1, -1, -1, -1
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
	if line ~= nil then
		text[#text + 1] = (glyph >= 32 and glyph < 127) and string.char(glyph) or "."
	end
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

local WATCHED = {38163, 38388, 38391, 38149, 38151, 38209, 38196, 38199, 38195}
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
			note("the key was not taken: " .. name)
			error("key")
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

local routes = {}

function routes.menus()
	boot()
	key("C")
	get("menu", "9")
	get("menu_wrong", "1")
	get("central", "9")
	get("central_wrong", "1")
	get("nav", "9")
	get("nav_wrong", "2")
	-- 25: <ERROR>
	get("course", "2")
	get("course_2", "5")
	-- 01: where we are
	get("course_error", "0")
	get("course_error_2", "1")
	-- 5, backspace, 05: LUYTEN
	get("course_here", "5")
	get("course_5", "LEFT")
	get("course_back", "0")
	get("course_0", "5")
	-- 7 and RETURN: SIRIUS
	get("nav_set", "2")
	get("course_again", "7")
	get("course_7", "\r")
	get("nav_set_cr", "1")
	-- the directory
	get("directory", "9")
	get("directory_wrong", "1")
	get("which", "3")
	get("which_3", "0")
	get("which_wrong", "0")
	get("which_0", "2")
	get("page_2", "X")
	get("directory_back", "1")
	get("which_b", "0")
	get("which_b0", "1")
	get("page_1", "X")
	get("directory_back_2", "2")
	-- wherever "2) RETURN" comes out
	get("after_directory", "1")
	get("central_2", "6")
	get("menu_back", "5")
	fly("flying")
end

function routes.damaged()
	boot()
	poke(38196, 0) -- COMP
	poke(38195, 0) -- RADAR
	poke(38199, 10) -- POWER
	key("C")
	get("menu", "1")
	-- COMPUTER NOT FUNCTIONING, and the menu again
	get("menu_again", "5")
	fly("flying")
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
