-- Live record of END.bas, the "4) END" of the command console: its menu,
-- every kind of key at its numeric GET, the save and its refusal in an
-- atmosphere, CONTINUE, and END GAME itself. The same clock as
-- com_live.lua: when each BASIC line started, every character the
-- generator drew, and both hi-res pages at each stop.
--
-- SV_ROUTE picks the keys:
--
--   menu        a new game at SOL: keys that are no choice, a save,
--               CONTINUE back into flight
--   atmosphere  38210 poked to 1 at the console: the save refused
--   key_<name>  one key at the GET that may be an error (GET C wants a
--               number), whatever the machine does watched for six
--               seconds, a space pressed and fourteen more: space,
--               return, dot, plus, minus, comma, colon, letter, e, escape
--   quit        3) END GAME, watched the same way
--   font        the Apple's text characters, in a snapshot
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_ROUTE=menu SV_OUT=/tmp/sv_end WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/end_live.lua \
--     -snapshot_directory /tmp/sv_end -snapname "snap_%i"
--
-- end_<route>.log:
--   <ms> [frame] line <n>  x<statements>  p1=<stores on page 1>
--        (<first ms>..<last ms>)  p2=<stores on page 2>  "<characters>"
--   <ms> [frame] -- get <name> line=<n> ...   the program is waiting in
--        KEYIN; <route>_<name>_p1.bin and _p2.bin written, then the key
--   <ms> [frame] -- shown <name> ...   a message is up; the pages written
--   <ms> [frame] -- watch ...   the machine once a second after a key
--        that may have ended the program: PC, stack, BASIC's line, the
--        display switches, and the text screen when it changes
--   <ms> [frame] -- w <address>=<value> pc=<PC>   a watched byte written
--   <ms> [frame] -- switch <text|graphics|...>   a display switch changed
-- end_<route>_glyphs.log, a line a character:
--   <ms> <line> <code> <column> <row> <973> <974>  <left> <width> <top> <bottom>
--   (column and row are the cursor before the character)

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local ROUTE = os.getenv("SV_ROUTE") or "menu"
local f = assert(io.open(DIR .. "end_" .. ROUTE .. ".log", "w"))
local g = assert(io.open(DIR .. "end_" .. ROUTE .. "_glyphs.log", "w"))
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

end_live_taps = {}
local taps = end_live_taps

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

taps[#taps + 1] = mem:install_write_tap(38391, 38392, "marker", function(offset, data, mask)
	if not recording then return end
	note(string.format("w %d=%d pc=%04X", offset, data, pc()))
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

local WATCHED = {38388, 38391, 38392, 38210, 38209, 38823, 38824, 38211, 38212, 38213, 38214, 38215, 38216, 38217, 38218, 38219}
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

-- into END from flight
local function to_end()
	boot()
	key("C")
	get("console", "4")
end

local routes = {}

function routes.menu()
	to_end()
	get("menu", "9")
	get("menu_9", "0")
	get("menu_0", "4")
	get("menu_4", "1")
	shown("saved", "GAME SAVED.")
	get("menu_saved", "2")
	fly("flying")
end

function routes.atmosphere()
	boot()
	key("C")
	-- at the console, so that the flight program never sees it
	local held = 0
	while held < 3 do
		coroutine.yield()
		if keyin_frame >= frame - 1 then held = held + 1 else held = 0 end
	end
	poke(38210, 1)
	get("console", "4")
	get("menu", "1")
	shown("refused", "ORBIT TO SAVE GAME")
	get("menu_refused", "9")
	poke(38210, 0)
	get("menu_again", "2")
	fly("flying")
end

local ODD = {
	space = " ", ["return"] = "\r", dot = ".", plus = "+", minus = "-", comma = ",", colon = ":",
	letter = "A", e = "E", escape = "\027",
}

local function odd_key(k)
	return function()
		to_end()
		get("menu", k)
		observe("after", 6)
		-- DOS as it is in memory, for the routine that put the message up
		local out = assert(io.open(DIR .. "dos_9d00.bin", "wb"))
		for a = 0x9D00, 0xBFFF do out:write(string.char(mem:read_u8(a))) end
		out:close()
		-- "PRESS ANY KEY TO REBOOT", if that is where it went
		key(" ")
		observe("rebooted", 14)
	end
end
for name, k in pairs(ODD) do routes["key_" .. name] = odd_key(k) end

-- The Apple's own text characters: with the error message up (the only
-- time the game shows the text screen after its title), the sixty-four
-- of them written into the top two rows and a snapshot taken.
function routes.font()
	to_end()
	get("menu", "A")
	wait(120)
	for i = 0, 63 do
		local row = i // 40
		mem:write_u8(0x400 + row * 0x80 + i % 40, 0xA0 + i)
	end
	wait(5)
	manager.machine.video:snapshot()
end

function routes.quit()
	to_end()
	get("menu", "3")
	observe("after", 20)
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
