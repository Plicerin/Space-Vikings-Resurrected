-- The star chart's loop (GALAXY MAP.bas lines 3110-3200) timed inside the
-- frame: when the two paddles are read, when the cursor goes on (XDRAW,
-- line 3120), when the keyboard and the button are looked at, and when
-- the cursor comes off again (line 3200). Then the button: how long
-- line 3210's black DRAW and the search for a star take.
--
-- Run as chart_live.lua. chart_loop_live.log has one line per event with
-- the emulated time in milliseconds and the frame:
--   "pdl"  $C070 read (PDL(0), then PDL(1))
--   "kbd"  $C000 read from BASIC      "btn"  $C061 read
--   "w"    a byte stored on hi-res page 1: row, column, value

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "chart_loop_live.log", "w"))
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

local function now()
	local ok, t = pcall(function() return manager.machine.time:as_double() end)
	if ok and t then return t * 1000.0 end
	return emu.time() * 1000.0
end

local frame = 0
local passes = 0
local triggers = 0
local timing = false

chart_loop_taps = {}
local taps = chart_loop_taps

local row_of = {}
for y = 0, 191 do
	row_of[(y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 0x28] = y
end

taps[#taps + 1] = mem:install_write_tap(29461, 29461, "pass", function(offset, data, mask)
	if pc() < 0xD000 then return end
	passes = passes + 1
end)

taps[#taps + 1] = mem:install_read_tap(0xC070, 0xC070, "pdl", function(offset, data, mask)
	triggers = triggers + 1
	if timing then log(string.format("%.3f [%d] pdl", now(), frame)) end
end)

taps[#taps + 1] = mem:install_read_tap(0xC061, 0xC061, "button", function(offset, data, mask)
	if timing then log(string.format("%.3f [%d] btn", now(), frame)) end
end)

taps[#taps + 1] = mem:install_read_tap(0xC000, 0xC000, "kbd", function(offset, data, mask)
	if timing then log(string.format("%.3f [%d] kbd", now(), frame)) end
end)

taps[#taps + 1] = mem:install_write_tap(0x2000, 0x3FFF, "page", function(offset, data, mask)
	if not timing then return end
	local a = offset - 0x2000
	local column = (a & 0x7F) % 0x28
	local y = row_of[a - column]
	log(string.format("%.3f [%d] w row=%s col=%d %02X", now(), frame, tostring(y), column, data))
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
			log(string.format("[%d] TIMEOUT waiting for %s", frame, what))
			error("timeout")
		end
	end
	log(string.format("%.3f [%d] %s (after %d)", now(), frame, what, n))
end

local function key(k)
	log(string.format("%.3f [%d] key '%s'", now(), frame, k))
	nat:post(k)
end

local function paddles(x, y)
	pdl0:set_value(x)
	pdl1:set_value(y)
	log(string.format("%.3f [%d] paddles %d %d", now(), frame, x, y))
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
	key("C")
	wait(2400)
	key("1")
	wait(600)
	paddles(113, 115)
	key("3")
	local n = triggers
	wait_until("chart drawn, first paddle read", function() return triggers > n end)
	wait(100)
	timing = true
	wait(60)
	btn:set_value(1)
	log(string.format("%.3f [%d] button down", now(), frame))
	wait(45)
	btn:set_value(0)
	timing = false
	wait(700)
	key("N")
	wait(300)
	-- the same with the paddles at both ends: PDL takes longer the
	-- further the paddle is turned
	paddles(250, 140)
	wait(100)
	timing = true
	wait(60)
	timing = false
	paddles(5, 5)
	wait(100)
	timing = true
	wait(60)
	timing = false
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
