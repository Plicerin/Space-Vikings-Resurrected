-- Live record of saving a game and of what the next boots do with it
-- (END.bas, START.bas 25-73 and 3000-3030, INSTRUMENTS.bas 210-220,
-- GALAXY MAP.bas line 2).
--
-- SV_PHASE picks the run; each is one boot of the same disk copy, which
-- MAME writes back when it exits:
--
--   save   a new game, C (command console), 4 (END), 1 (save game), then
--          2 (continue present game) back into flight
--   old    boot and answer O: the saved game, or "THERE IS NO GAME SAVED"
--   new    boot and answer N
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_PHASE=save SV_OUT=/tmp/sv_save WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/save_live.lua \
--     -snapshot_directory /tmp/sv_save -snapname "snap_%i"
--
-- save_<phase>.log:
--   "text"     the 40-column text screen, each time it changed during boot
--   "w"        a write to one of the watched bytes, with the PC
--   "tranlit"  CALL 38402 entered, with the redraw-all byte and the mode
--   "ch"       a glyph of the hi-res character generator
--   "dump"     <name>_p1.bin and <name>_p2.bin written, with the flags

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local PHASE = os.getenv("SV_PHASE") or "save"
local f = assert(io.open(DIR .. "save_" .. PHASE .. ".log", "w"))
local function log(s) f:write(s .. "\n"); f:flush() end

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nat = manager.machine.natkeyboard
local function pc() return cpu.state["PC"].value end

local CH, CV = 0x24, 0x25
local GLYPHS = 0x8800
local GENERATOR_FIRST, GENERATOR_LAST = 0x9300, 0x93FF
local TRANLIT = 0x9602

local frame = 0
local passes = 0
local glyphs = 0
local recording = false

save_live_taps = {}
local taps = save_live_taps

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

-- shields, weapon, condition, autopilot, atmosphere, damage; the saved
-- marker and planet; the current planet; the redraw-all byte
local FLAGS = {38201, 38202, 38165, 38164, 38210, 38393, 38391, 38392, 38209, 38189}
local function flags()
	local out = {}
	for _, a in ipairs(FLAGS) do out[#out + 1] = string.format("%d=%d", a, mem:read_u8(a)) end
	return table.concat(out, " ")
end

local function dump(name)
	dump_page(0x2000, PHASE .. "_" .. name .. "_p1.bin")
	dump_page(0x4000, PHASE .. "_" .. name .. "_p2.bin")
	log(string.format("[%d] dump %s %s c974=%d c973=%d", frame, name, flags(),
		mem:read_u8(974), mem:read_u8(973)))
end

local function text_screen()
	local rows = {}
	for r = 0, 23 do
		local a = 0x400 + (r & 7) * 0x80 + (r >> 3) * 0x28
		local row = {}
		for c = 0, 39 do
			local b = mem:read_u8(a + c) & 0x7F
			if b < 32 then b = b + 64 end
			row[#row + 1] = (b >= 32 and b < 127) and string.char(b) or "."
		end
		local line = table.concat(row):gsub("%s+$", "")
		if line ~= "" then rows[#rows + 1] = string.format("%2d|%s", r, line) end
	end
	return table.concat(rows, "\n")
end

taps[#taps + 1] = mem:install_write_tap(29461, 29461, "pass", function(offset, data, mask)
	if pc() < 0xD000 then return end
	passes = passes + 1
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

for _, addr in ipairs({38391, 38392, 38189, 38201, 38202, 38165, 38164, 973, 974}) do
	taps[#taps + 1] = mem:install_write_tap(addr, addr, "w" .. addr, function(offset, data, mask)
		log(string.format("[%d] w %d=%d pc=%04X", frame, addr, data, pc()))
	end)
end

taps[#taps + 1] = mem:install_read_tap(TRANLIT, TRANLIT, "tranlit", function(offset, data, mask)
	if pc() ~= TRANLIT then return end
	log(string.format("[%d] tranlit 38189=%d 38167=%d", frame, mem:read_u8(38189), mem:read_u8(38167)))
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

-- Boots to the first flight passes, answering the title's question with
-- `answer` whenever the text screen shows it. Returns false if flight
-- never came.
local function boot(answer, most)
	local n = 0
	local last_text = ""
	local shown = 0
	local asked_at = -1000
	while passes < 3 do
		coroutine.yield()
		n = n + 1
		if n % 20 == 0 then
			local text = text_screen()
			if text ~= last_text and shown < 30 then
				last_text = text
				shown = shown + 1
				log(string.format("[%d] text 38391=%d\n%s", frame, mem:read_u8(38391), text))
			end
			if text:find("LD GAME?", 1, true) and frame - asked_at > 300 then
				asked_at = frame
				key(answer)
			end
		end
		if n > most then return false end
	end
	log(string.format("[%d] in flight", frame))
	return true
end

local function flight_again(what)
	local n = passes
	wait_until(what, function() return passes > n + 2 end, 20000)
end

local script = coroutine.create(function()
	if PHASE == "save" then
		if not boot("N", 14000) then error("no flight") end
		dump("flight")
		recording = true
		key("C")
		wait(2400)
		dump("com_menu")
		key("4")
		wait(1500)
		dump("end_menu")
		key("1")
		wait(4000)
		dump("end_saved")
		key("2")
		flight_again("flight again after CONTINUE")
		dump("continued")
		wait(300)
		dump("continued_300")
	elseif PHASE == "old" then
		recording = true
		if boot("O", 9000) then
			dump("flight")
			wait(300)
			dump("flight_300")
		else
			log(string.format("[%d] no flight: %s", frame, flags()))
		end
	else
		if not boot("N", 14000) then error("no flight") end
		dump("flight")
	end
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
