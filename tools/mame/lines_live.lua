-- A line-by-line clock of the BASIC programs round the star chart: COM,
-- GALAXY MAP, INSTRUMENTS and back. Applesoft looks at the keyboard
-- before every statement (ISCNTC, $D858); each look is a statement
-- boundary, and the text pointer there says which line comes next. One
-- log entry per run of statements on the same line:
--
--   <ms> [frame] line <n>  x<statements>  p1=<bytes stored on page 1>
--        p2=<... page 2>  "<characters through the generator>"
--
-- "ms" is the emulated time the first of those statements began. A gap
-- with no statements (the disk, a GET waiting) shows as the time between
-- two entries. Run as chart_live.lua; the log is lines_live.log.

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "lines_live.log", "w"))
local function log(s) f:write(s .. "\n") end

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

local function now()
	return manager.machine.time:as_double() * 1000.0
end

local CH, CV = 0x24, 0x25
local GLYPHS = 0x8800
local frame = 0
local passes = 0
local triggers = 0
local recording = false

lines_live_taps = {}
local taps = lines_live_taps

-- the entry being gathered
local line, began, statements, p1, p2, text = nil, 0, 0, 0, 0, {}

local function flush()
	if line == nil then return end
	log(string.format("%.2f [%d] line %d  x%d  p1=%d p2=%d  \"%s\"", began, frame, line, statements, p1, p2, table.concat(text)))
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

taps[#taps + 1] = mem:install_read_tap(0xC070, 0xC070, "pdl", function(offset, data, mask)
	triggers = triggers + 1
end)

taps[#taps + 1] = mem:install_read_tap(0xC000, 0xC000, "kbd", function(offset, data, mask)
	if not recording then return end
	local p = pc()
	if p < 0xD850 or p > 0xD870 then return end
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
	if offset < 0x4000 then p1 = p1 + 1 else p2 = p2 + 1 end
end)

local last_glyph_frame, last_glyph, last_column = -1, -1, -1
taps[#taps + 1] = mem:install_read_tap(GLYPHS, GLYPHS + 0x3FF, "glyph", function(offset, data, mask)
	if line == nil then return end
	local p = pc()
	if p < 0x9300 or p > 0x93FF then return end
	local glyph = (offset - GLYPHS) >> 3
	local column = mem:read_u8(CH)
	if glyph == last_glyph and column == last_column and frame - last_glyph_frame < 2 then return end
	last_glyph, last_column, last_glyph_frame = glyph, column, frame
	text[#text + 1] = (glyph >= 32 and glyph < 127) and string.char(glyph) or "."
end)

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

local function paddles(x, y)
	pdl0:set_value(x)
	pdl1:set_value(y)
	note(string.format("paddles %d %d", x, y))
end

local function button(frames)
	btn:set_value(1)
	note("button down")
	wait(frames)
	btn:set_value(0)
	note("button up")
end

local function chart(what)
	local n = triggers
	wait_until(what, function() return triggers > n end)
end

local script = coroutine.create(function()
	local boot = 0
	while passes < 3 do
		coroutine.yield()
		boot = boot + 1
		if boot >= 180 and boot % 300 == 0 and boot <= 6000 and passes == 0 then nat:post("N") end
		if boot > 14000 then log("TIMEOUT boot"); error("timeout") end
	end
	recording = true
	note("in flight")
	wait(30)
	key("C")
	wait(2400)
	key("1")
	wait(600)
	paddles(113, 115)
	key("3")
	chart("chart drawn, first paddle read")
	wait(60)
	button(30)
	wait(700)
	key("N")
	wait(30)
	chart("chart redrawn")
	paddles(20, 20)
	wait(60)
	button(70)
	wait(1200)
	paddles(113, 115)
	wait(60)
	button(30)
	wait(700)
	key("Y")
	wait(2500)
	key("X")
	wait(60)
	chart("chart drawn again after the directory page")
	wait(60)
	key(" ")
	wait(4500)
	key("5")
	local n = passes
	wait_until("flying again", function() return passes > n + 2 end, 6000)
	wait(30)
	flush()
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
