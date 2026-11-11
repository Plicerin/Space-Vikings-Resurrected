-- Live record of what goes through the hi-res character generator: every
-- glyph it draws (which, where, on which page, in which mode) and every
-- move of the cursor row, from one line-147 event of the flight program
-- to another. Made to see what a chained program really prints, DOS
-- commands and file reads included, where the listing does not say.
--
-- A new game is started and left alone until event SV_FROM (default 3).
-- There the course byte is poked if SV_TARGET is set, and SV_KEY (default
-- H) is typed. The record ends at event SV_TO (default 5).
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_OUT=/tmp/sv_print SV_TARGET=2 WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/print_live.lua \
--     -snapshot_directory /tmp/sv_print -snapname "snap_%i"
--
-- print_live.log:
--   "ev"   a line-147 event (the pass byte and the cursor)
--   "ch"   a glyph: its code, the cursor column and row (0-based) it was
--          drawn at, the page byte (974) and the mode byte (973), and
--          the program counter's page of whoever is printing
--   "cv"   the cursor row written from outside the character generator
--          (VTAB, the monitor)
--   "w"    974 or 973 written

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local FROM = tonumber(os.getenv("SV_FROM") or "3")
local TO = tonumber(os.getenv("SV_TO") or "5")
local KEY = os.getenv("SV_KEY") or "H"
local TARGET = tonumber(os.getenv("SV_TARGET") or "0")

local f = assert(io.open(DIR .. "print_live.log", "w"))
local function log(s) f:write(s .. "\n"); f:flush() end

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nat = manager.machine.natkeyboard
local function pc() return cpu.state["PC"].value end

local CH, CV = 0x24, 0x25
local GLYPHS = 0x8800 -- CHARACTER TABLE, 128 glyphs of 8 bytes
local GENERATOR_FIRST, GENERATOR_LAST = 0x9300, 0x93FF

local frame = 0
local events = 0
local last_event_frame = 0
local finished = false
local recording = false
local pending_keys = {}

-- keep the handles (a global, so they are never collected): a tap is
-- removed when its handle is
print_live_taps = {}
local taps = print_live_taps

-- Byte 29461 is inside the planet file ($7300 up): only BASIC's POKE
-- (program counter in the Applesoft ROM) is line 147.
taps[#taps + 1] = mem:install_write_tap(29461, 29461, "pass", function(offset, data, mask)
	if finished or pc() < 0xD000 then return end
	events = events + 1
	log(string.format("[%d] ev %d (+%d) it=%d CH=%d CV=%d c974=%d c973=%d", frame, events,
		frame - last_event_frame, data, mem:read_u8(CH), mem:read_u8(CV), mem:read_u8(974), mem:read_u8(973)))
	last_event_frame = frame
	if events == FROM then
		recording = true
		if TARGET > 0 then
			mem:write_u8(38163, TARGET)
			log(string.format("act poke 38163 %d", TARGET))
		end
		pending_keys[#pending_keys + 1] = KEY
		log("act key " .. KEY)
	elseif events >= TO then
		finished = true
	end
end)

-- The generator reads a glyph's 8 bytes one after another; the first of
-- them names the glyph.
local last_glyph_frame, last_glyph, last_column = -1, -1, -1
taps[#taps + 1] = mem:install_read_tap(GLYPHS, GLYPHS + 0x3FF, "glyph", function(offset, data, mask)
	if not recording then return end
	local p = pc()
	if p < GENERATOR_FIRST or p > GENERATOR_LAST then return end
	local glyph = (offset - GLYPHS) >> 3
	local column = mem:read_u8(CH)
	if glyph == last_glyph and column == last_column and frame - last_glyph_frame < 2 then return end
	last_glyph, last_column, last_glyph_frame = glyph, column, frame
	local shown = (glyph >= 32 and glyph < 127) and string.char(glyph) or "."
	log(string.format("[%d] ch %3d '%s' col=%d row=%d c974=%d c973=%d (+%d)", frame, glyph, shown, column,
		mem:read_u8(CV), mem:read_u8(974), mem:read_u8(973), frame - last_event_frame))
end)

taps[#taps + 1] = mem:install_write_tap(CV, CV, "cv", function(offset, data, mask)
	if not recording then return end
	local p = pc()
	local who = (p >= GENERATOR_FIRST and p <= GENERATOR_LAST) and "generator" or string.format("pc=%04X", p)
	log(string.format("[%d] cv %d %s (+%d)", frame, data, who, frame - last_event_frame))
end)

for _, addr in ipairs({973, 974}) do
	taps[#taps + 1] = mem:install_write_tap(addr, addr, "w" .. addr, function(offset, data, mask)
		if not recording then return end
		log(string.format("[%d] w %d=%d (+%d)", frame, addr, data, frame - last_event_frame))
	end)
end

local boot_frames = 0
emu.register_frame_done(function()
	frame = frame + 1
	if events == 0 then
		boot_frames = boot_frames + 1
		if boot_frames >= 180 and boot_frames % 300 == 0 and boot_frames <= 6000 then
			nat:post("N")
		end
		if boot_frames > 12000 then
			log("TIMEOUT boot")
			finished = true
		end
	end
	if #pending_keys > 0 then
		nat:post(table.remove(pending_keys, 1))
	end
	if finished then
		log("done")
		f:close()
		manager.machine:exit()
	end
	if frame > 100000 then
		log("TIMEOUT")
		f:close()
		manager.machine:exit()
	end
end)
