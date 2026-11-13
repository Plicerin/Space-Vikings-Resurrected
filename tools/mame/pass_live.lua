-- Live record of a scripted flight, pass by pass, for two things:
--
--  1. Timing. Where in a pass the time goes: the frame of every write to
--     byte 29461 (line 147, just before CALL CA), of every write to byte
--     974 (lines 150/153, just after CALL CA returns) and of every touch
--     of the display-page switches $C054/$C055.
--
--  2. A reference for the port. Both hi-res pages are dumped at every
--     line 147, when they hold everything the pass before it drew: the
--     3D window, the instrument panel, the read-outs, the gauge markers
--     and the lamps. godot-remake/tests/check_flight_passes.gd replays
--     the same script through the port and compares the pages.
--
-- The script (SCRIPT below, keyed by the count of line-147 events since
-- boot) covers a new game left alone, stick input, the speed keys, the
-- four lamp keys (each restarts the BASIC program), H with no course
-- set, a re-entry, flight in the atmosphere and the climb back to orbit.
-- SOL has surrendered before the game starts, so nothing here rolls a
-- random number.
--
-- Stick: BASIC reads the paddles only when the autopilot byte (38164) is
-- 0 and hands them to the machine code in 38397/38398. The script sets
-- the autopilot byte itself (which does not touch the lamp) and writes
-- those two bytes, so the routine sees exact values.
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_OUT=/tmp/sv_pass WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/pass_live.lua \
--     -snapshot_directory /tmp/sv_pass -snapname "snap_%i"
--
-- pass_live.log: "ev" = a line-147 event with the machine state at that
-- moment, "act" = what the script did there, "t974" / "show" = timing.
-- ev_<n>_p1.bin / _p2.bin: the two pages, 192 rows of 40 bytes.
-- The port's test reads the directory as it is (analysis/live/pass/).

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "pass_live.log", "w"))
local function log(s) f:write(s .. "\n"); f:flush() end

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nat = manager.machine.natkeyboard

local function s16(addr)
	local v = mem:read_u8(addr) | (mem:read_u8(addr + 1) << 8)
	if v >= 32768 then v = v - 65536 end
	return v
end
local function w16(addr, v)
	if v < 0 then v = v + 65536 end
	mem:write_u8(addr, v & 255)
	mem:write_u8(addr + 1, v >> 8)
end

local P1, B1, H1 = 29473, 29474, 29475
local PDL_PITCH, PDL_BANK = 38397, 38398

-- event number -> list of actions. {"key", "S"}, {"pdl", pitch, bank},
-- {"auto", 0/1}, {"pos", x, y, z}, {"att", p, b, h}, {"speed", s}, {"end"}
local SCRIPT = {
	[6] = {{"auto", 1}, {"pdl", 128, 0}},
	[10] = {{"pdl", 0, 128}},
	[13] = {{"pdl", 128, 128}, {"key", "1"}},
	[14] = {{"key", "3"}},
	[15] = {{"key", "W"}},
	[18] = {{"key", "B"}},
	[20] = {{"key", "S"}},
	[23] = {{"key", "A"}},
	[26] = {{"key", "A"}},
	[28] = {{"key", "H"}},
	[31] = {{"pos", 300, 200, -500}, {"att", 0, 0, 0}, {"speed", 40}, {"pdl", 128, 128}, {"key", "S"}},
	[37] = {{"pdl", 255, 128}},
	[40] = {{"pdl", 128, 128}, {"key", "4"}},
	[44] = {{"pos", 300, 4100, -500}, {"key", "S"}},
	[50] = {{"end"}},
}

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

local frame = 0
local events = 0
local last_event_frame = 0
local finished = false
local pending_keys = {}
local shown = -1

local function on_147(data)
	events = events + 1
	log(string.format(
		"[%d] ev %d (+%d) it=%d X=%d Y=%d Z=%d P=%d B=%d H=%d S=%d E=%d pdl=%d/%d auto=%d cond=%d"
		.. " shields=%d weapon=%d atmos=%d dmg=%d flip=%d b149=%d planet=%d target=%d defender=%d"
		.. " c974=%d shown=%d",
		frame, events, frame - last_event_frame, data, s16(29467), s16(29469), s16(29471),
		mem:read_u8(P1), mem:read_u8(B1), mem:read_u8(H1), mem:read_u8(38157), mem:read_u8(38199),
		mem:read_u8(PDL_PITCH), mem:read_u8(PDL_BANK), mem:read_u8(38164), mem:read_u8(38165),
		mem:read_u8(38201), mem:read_u8(38202), mem:read_u8(38210), mem:read_u8(38393),
		mem:read_u8(0x952F), mem:read_u8(38149), mem:read_u8(38209), mem:read_u8(38163),
		mem:read_u8(38205), mem:read_u8(974), shown))
	last_event_frame = frame
	dump_page(0x2000, string.format("ev_%d_p1.bin", events))
	dump_page(0x4000, string.format("ev_%d_p2.bin", events))
	local acts = SCRIPT[events]
	if not acts then return end
	for _, a in ipairs(acts) do
		if a[1] == "key" then
			pending_keys[#pending_keys + 1] = a[2]
			log("act key " .. a[2])
		elseif a[1] == "pdl" then
			mem:write_u8(PDL_PITCH, a[2]); mem:write_u8(PDL_BANK, a[3])
			log(string.format("act pdl %d %d", a[2], a[3]))
		elseif a[1] == "auto" then
			mem:write_u8(38164, a[2])
			log(string.format("act auto %d", a[2]))
		elseif a[1] == "pos" then
			w16(29467, a[2]); w16(29469, a[3]); w16(29471, a[4])
			log(string.format("act pos %d %d %d", a[2], a[3], a[4]))
		elseif a[1] == "att" then
			mem:write_u8(P1, a[2]); mem:write_u8(B1, a[3]); mem:write_u8(H1, a[4])
			log(string.format("act att %d %d %d", a[2], a[3], a[4]))
		elseif a[1] == "speed" then
			mem:write_u8(38157, a[2])
			log(string.format("act speed %d", a[2]))
		elseif a[1] == "end" then
			finished = true
		end
	end
end

-- keep the handles (a global, so they are never collected): a tap is
-- removed when its handle is
pass_live_taps = {}
local taps = pass_live_taps
-- Byte 29461 is inside the planet file ($7300 up), so every BLOAD of one
-- writes it too. Those writes come from DOS (in RAM below $C000); BASIC's
-- POKE comes from the Applesoft ROM.
local cpu = manager.machine.devices[":maincpu"]
taps[1] = mem:install_write_tap(29461, 29461, "pass", function(offset, data, mask)
	if finished then return end
	if cpu.state["PC"].value >= 0xD000 then
		on_147(data)
	else
		log(string.format("[%d] planet file loaded over byte 29461 (+%d)", frame, frame - last_event_frame))
	end
end)
taps[2] = mem:install_write_tap(974, 974, "chargen page", function(offset, data, mask)
	log(string.format("[%d] t974 %d (+%d)", frame, data, frame - last_event_frame))
end)
local function page_touched(offset)
	local page = (offset & 1) + 1
	if page ~= shown then
		shown = page
		log(string.format("[%d] show %d (+%d)", frame, page, frame - last_event_frame))
	end
end
taps[3] = mem:install_write_tap(0xC054, 0xC055, "page switch w", function(offset, data, mask)
	page_touched(offset)
end)
taps[4] = mem:install_read_tap(0xC054, 0xC055, "page switch r", function(offset, data, mask)
	page_touched(offset)
end)

local boot_frames = 0
local in_flight = false
emu.register_frame_done(function()
	frame = frame + 1
	if not in_flight then
		boot_frames = boot_frames + 1
		if boot_frames >= 180 and boot_frames % 300 == 0 and boot_frames <= 6000 and events == 0 then
			nat:post("N")
		end
		if events > 0 then
			in_flight = true
			log(string.format("[%d] == flight", frame))
		elseif boot_frames > 12000 then
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
	if frame > 200000 then
		log("TIMEOUT")
		f:close()
		manager.machine:exit()
	end
end)
