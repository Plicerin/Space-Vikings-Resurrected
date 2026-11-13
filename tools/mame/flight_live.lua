-- Live check of the flight model: what one pass of STARSHIP SIMULATOR.bas
-- lines 20-147 does to the position for a given heading and pitch, and
-- what CALL CA ($9023) does to pitch, bank and heading for a given stick.
--
-- BASIC only reads the paddles when the autopilot byte (38164) is 0
-- (line 15), and passes them to the machine code in 38397/38398. The
-- script sets the autopilot byte and writes those two bytes itself, so
-- the routine sees exact, known stick values. It pokes the attitude
-- bytes ($7321-$7323) at the moment line 147 flips byte 29461, which is
-- after that pass's position has been stored and before CALL CA runs.
--
-- Phase 1 (trig): pitch 0, bank 0, stick centred, heading poked to each
-- value in HEADINGS for two passes. The position step of a pass belongs
-- to the heading poked at the pass before it.
-- Phase 2 (stick): a schedule of stick values; the log shows pitch, bank
-- and heading after every pass.
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_OUT=/tmp/sv_flight WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/flight_live.lua \
--     -snapshot_directory /tmp/sv_flight -snapname "snap_%i"
--
-- flight_live.log: one "iter" line per pass. tools/flight_model.py replays
-- the log against a model of the BASIC and the machine code:
--
--   python3 -I tools/flight_model.py check /tmp/sv_flight/flight_live.log

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "flight_live.log", "w"))
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

local HEADINGS = {0, 1, 32, 62, 63, 64, 65, 96, 127, 128, 129, 160, 189, 190, 191, 192, 193, 224, 255}

-- {passes, pitch stick, bank stick, note}
local STICK = {
	{6, 128, 0, "bank stick 0"},
	{6, 128, 128, "stick centred: does the bank hold?"},
	{14, 128, 255, "bank stick 255"},
	{4, 128, 128, "stick centred"},
	{2, 128, 0x50, "bank stick $50"},
	{2, 128, 0x40, "bank stick $40"},
	{2, 128, 0x30, "bank stick $30"},
	{2, 128, 0xB0, "bank stick $B0"},
	{2, 128, 0xC0, "bank stick $C0"},
	{2, 128, 0xD8, "bank stick $D8"},
	{1, 128, 128, "level"},
	{18, 0, 128, "pitch stick 0"},
	{4, 128, 128, "stick centred: does the pitch hold?"},
	{36, 255, 128, "pitch stick 255"},
	{2, 0x50, 128, "pitch stick $50"},
	{2, 0x40, 128, "pitch stick $40"},
	{2, 0x30, 128, "pitch stick $30"},
}

local snaps = 0
local frame, state, sf = 0, "boot", 0
local function snap(what)
	manager.machine.video:snapshot()
	log(string.format("[%d] snap_%d %s", frame, snaps, what))
	snaps = snaps + 1
end
local function enter(s) state = s; sf = 0; log(string.format("[%d] == %s", frame, s)) end

local last_iter, last_iter_frame = nil, 0
local pass = 0
local step, step_left = 0, 0

local function on_pass()
	pass = pass + 1
	log(string.format("[%d] iter %d (+%d) X=%d Y=%d Z=%d P=%d B=%d H=%d S=%d pdl=%d/%d flip=%d",
		frame, pass, frame - last_iter_frame, s16(29467), s16(29469), s16(29471),
		mem:read_u8(P1), mem:read_u8(B1), mem:read_u8(H1), mem:read_u8(38157),
		mem:read_u8(PDL_PITCH), mem:read_u8(PDL_BANK), mem:read_u8(0x952F)))
	if state == "trig" then
		local i = (pass - 1) // 2 + 1
		if i > #HEADINGS then
			mem:write_u8(H1, 0)
			log("poke H=0")
			enter("stick")
			return
		end
		mem:write_u8(P1, 0); mem:write_u8(B1, 0); mem:write_u8(H1, HEADINGS[i])
		log(string.format("poke H=%d", HEADINGS[i]))
	end
	if state == "stick" then
		if step_left == 0 then
			step = step + 1
			local s = STICK[step]
			if not s then enter("done"); return end
			step_left = s[1]
			if s[4] == "level" then
				mem:write_u8(P1, 0); mem:write_u8(B1, 0); mem:write_u8(H1, 0)
			end
			mem:write_u8(PDL_PITCH, s[2]); mem:write_u8(PDL_BANK, s[3])
			log(string.format("-- %s (pitch stick %d, bank stick %d)", s[4], s[2], s[3]))
			if step == 2 or step == 13 then snap(s[4]) end
		end
		step_left = step_left - 1
	end
end

emu.register_frame_done(function()
	frame = frame + 1
	sf = sf + 1

	if state == "boot" then
		if sf >= 180 and sf % 300 == 0 and sf <= 6000 then nat:post("N") end
		if mem:read_u8(232) == 255 then enter("flight")
		elseif sf > 9000 then log("TIMEOUT boot"); enter("done") end

	elseif state == "flight" then
		if sf == 600 then
			log(string.format("start X=%d Y=%d Z=%d P=%d B=%d H=%d S=%d auto=%d",
				s16(29467), s16(29469), s16(29471), mem:read_u8(P1), mem:read_u8(B1),
				mem:read_u8(H1), mem:read_u8(38157), mem:read_u8(38164)))
			-- away from the re-entry and combat boxes, full speed; S (shields)
			-- restarts the program, which re-reads position and speed (line 8)
			w16(29467, 8000); w16(29469, 0); w16(29471, -12000)
			mem:write_u8(38157, 120)
			mem:write_u8(P1, 0); mem:write_u8(B1, 0); mem:write_u8(H1, 0)
			log(string.format("restart X=%d Y=%d Z=%d", s16(29467), s16(29469), s16(29471)))
			nat:post("S")
		end
		if sf == 1500 then
			mem:write_u8(38164, 1)
			mem:write_u8(PDL_PITCH, 128); mem:write_u8(PDL_BANK, 128)
			last_iter = mem:read_u8(29461)
			last_iter_frame = frame
			enter("trig")
		end

	elseif state == "trig" or state == "stick" then
		local it = mem:read_u8(29461)
		if it ~= last_iter then
			on_pass()
			last_iter = it
			last_iter_frame = frame
		end
		if sf > 40000 then log("TIMEOUT " .. state); enter("done") end

	elseif state == "done" then
		if sf == 1 then
			log("done")
			f:close()
			manager.machine:exit()
		end
	end
end)
