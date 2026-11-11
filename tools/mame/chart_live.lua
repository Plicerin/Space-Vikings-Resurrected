-- Live record of the star chart (GALAXY MAP.bas lines 3000-3320) and of
-- the ways into and out of it: both hi-res pages at each step, BASIC's
-- own PX, PY and P at that moment, every glyph the character generator
-- draws, and the frames at which the chart's loop reads the paddles.
--
-- The route: a new game, C (command console), 1 (computer), 3 (galaxy
-- map); the cursor on SIRIUS and the button, N; the cursor on empty
-- space and the button; SIRIUS again, Y (the directory page in COM), a
-- key (back to the chart), a key (INSTRUMENTS, GALAXY MAP, COM).
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_OUT=/tmp/sv_chart WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/chart_live.lua \
--     -snapshot_directory /tmp/sv_chart -snapname "snap_%i"
--
-- chart_live.log:
--   "dump"  <name>_p1.bin and <name>_p2.bin written (192 rows of 40
--           bytes, top row first), with PX, PY, P and the cursor
--   "pdl"   the paddle trigger ($C070) was read: twice a turn of the
--           chart's loop (PDL(0), PDL(1))
--   "ch"    a glyph: code, column and row (0-based), page and mode bytes
--   "key"/"btn"/"paddles"  what the script did

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "chart_live.log", "w"))
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
	dump_page(0x2000, name .. "_p1.bin")
	dump_page(0x4000, name .. "_p2.bin")
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

local SIRIUS_X, SIRIUS_Y = 113, 115

local script = coroutine.create(function()
	local boot = 0
	while passes < 3 do
		coroutine.yield()
		boot = boot + 1
		if boot >= 180 and boot % 300 == 0 and boot <= 6000 and passes == 0 then nat:post("N") end
		if boot > 14000 then log("TIMEOUT boot"); error("timeout") end
	end
	log(string.format("[%d] in flight", frame))
	dump("flight")
	recording = true
	key("C")
	wait(2400)
	dump("com_menu")
	key("1")
	wait(600)
	dump("central_computer")
	paddles(SIRIUS_X, SIRIUS_Y)
	key("3")
	next_chart("chart drawn, first paddle read")
	dump("chart_clean")
	wait(200)
	at_button_read("button read, cursor on")
	dump("chart_cursor")
	press_button()
	wait(700)
	dump("chart_info")
	key("N")
	wait(30)
	next_chart("chart redrawn")
	dump("chart_redrawn")
	paddles(20, 20)
	wait(200)
	at_button_read("button read, cursor in the corner")
	dump("chart_corner")
	press_button()
	wait(150)
	dump("chart_nostar_150")
	wait(450)
	dump("chart_nostar_600")
	wait(600)
	dump("chart_nostar_1200")
	paddles(SIRIUS_X, SIRIUS_Y)
	wait(300)
	press_button()
	wait(700)
	key("Y")
	wait(2500)
	dump("com_detail")
	key("X")
	wait(60)
	next_chart("chart drawn again after the directory page")
	dump("chart_back")
	wait(300)
	key(" ")
	wait(1500)
	dump("leaving_1500")
	wait(2500)
	dump("leaving_4000")
	wait(2000)
	dump("leaving_6000")
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
	elseif frame > 120000 then
		close("TIMEOUT")
	end
end)
