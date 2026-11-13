-- Live timing and behaviour of flight combat: how long one flight-loop
-- iteration takes, what a fighter pass (STARSHIP SIMULATOR.bas 5000-5251)
-- and the laser (1505-1530) do to the hi-res page frame by frame, how the
-- ship-system bytes move when damage lands (POKE truncation), and what the
-- "POKE -16298,0" lo-res flash actually shows.
--
-- SOL is surrendered from the start and the ship begins outside the combat
-- box, so the script forces the planet hostile (38208=0, nine fighters,
-- tech 3 if it was lower) and moves the ship to Z=-5500, then presses S:
-- any panel key restarts the loop at line 1, which re-reads the position
-- from memory (line 8). SV_SHIELDS=down presses S a second time, so the
-- shields are down again as on a new game; the ship then dies within about
-- 45 loop iterations and the laser phase never runs (that run is the
-- reference for the damage cascade: analysis/fight_live_shields_down.log;
-- it was made before the "iter" lines carried atmos=, and after eleven
-- iterations the ship drifts into the re-entry box, RE runs, and the rest
-- is flown in atmosphere, where lines 190 and 192 both roll for damage).
-- The run with the shields left up, which reaches the laser phase, is
-- analysis/fight_live_shields_up_laser.log.
--
-- It also plants a marker byte in the 3D window of both hi-res pages to
-- see whether the flight renderer ever clears the window ("marker" lines).
--
-- Run on a copy of the disk image, from the repo root:
--
--   cp "disk_image/Space Vikings (4am crack).dsk" /tmp/sv.dsk
--   SV_OUT=/tmp/sv_fight WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/fight_live.lua \
--     -snapshot_directory /tmp/sv_fight -snapname "snap_%i"
--
-- fight_live.log: "iter" lines are loop iterations (byte $7315 flips
-- 84/85, line 147), "page" lines are frames on which the drawing page
-- changed (bytes changed, row range, byte-column range), "byte" lines are
-- watched game bytes changing.

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "fight_live.log", "w"))
local function log(s) f:write(s .. "\n"); f:flush() end

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nat = manager.machine.natkeyboard
local ports = manager.machine.ioport.ports
local function field(tag, name)
	local p = ports[tag]
	return p and p.fields[name]
end
local btn = field(":gameio:paddles:paddle_buttons", "P1 Button 1")
local SHIELDS_DOWN = os.getenv("SV_SHIELDS") == "down"
local START_Z = tonumber(os.getenv("SV_Z") or "-5500")

local watch = {
	{"shield_38200", 38200}, {"radar_38195", 38195}, {"eng1_38198", 38198},
	{"eng2_38197", 38197}, {"computer_38196", 38196}, {"laser_38186", 38186},
	{"hull_38193", 38193}, {"missiles_38187", 38187}, {"fighters_38207", 38207},
	{"surrendered_38208", 38208}, {"defender_38205", 38205}, {"vp_38160", 38160},
	{"dp_38152", 38152}, {"shields_38201", 38201}, {"condition_38165", 38165},
	{"weapon_38202", 38202}, {"dmgflag_38393", 38393}, {"speed_38157", 38157},
	{"hpag_E6", 0xE6}, {"pitch_7321", 29473}, {"bank_7322", 29474}, {"head_7323", 29475},
}
local last = {}
local function poll_bytes(frame)
	for _, w in ipairs(watch) do
		local v = mem:read_u8(w[2])
		if last[w[1]] ~= v then
			log(string.format("[%d] byte %s %s -> %d", frame, w[1], tostring(last[w[1]]), v))
			last[w[1]] = v
		end
	end
end

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

-- hi-res row base offsets
local rowbase = {}
for y = 0, 191 do
	rowbase[y] = (y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 0x28
end
local prev = {}
local function page_diff()
	local base = mem:read_u8(0xE6) << 8
	local n, y0, y1, c0, c1 = 0, 999, -1, 999, -1
	for y = 0, 191 do
		local a = base + rowbase[y]
		for c = 0, 39 do
			local v = mem:read_u8(a + c)
			local k = y * 40 + c
			if prev[k] ~= v then
				if prev[k] ~= nil then
					n = n + 1
					if y < y0 then y0 = y end
					if y > y1 then y1 = y end
					if c < c0 then c0 = c end
					if c > c1 then c1 = c end
				end
				prev[k] = v
			end
		end
	end
	return n, y0, y1, c0, c1
end

local snaps = 0
local frame, state, sf = 0, "boot", 0
local function snap(what)
	manager.machine.video:snapshot()
	log(string.format("[%d] snap_%d %s", frame, snaps, what))
	snaps = snaps + 1
end
local function enter(s) state = s; sf = 0; log(string.format("[%d] == %s", frame, s)) end

-- row 20, byte column 5 of each page: inside the 3D window, away from the gunsight
local MARK1, MARK2 = 0x2000 + rowbase[20] + 5, 0x4000 + rowbase[20] + 5

local last_iter, last_iter_frame = nil, 0
local small_snaps = 0
local function watch_frame(snap_budget)
	poll_bytes(frame)
	local it = mem:read_u8(29461)
	if it ~= last_iter then
		log(string.format("[%d] iter %d (+%d frames) X=%d Y=%d Z=%d atmos=%d marker=%02X/%02X", frame, it,
			frame - last_iter_frame, s16(29467), s16(29469), s16(29471), mem:read_u8(38210),
			mem:read_u8(MARK1), mem:read_u8(MARK2)))
		last_iter = it
		last_iter_frame = frame
	end
	local n, y0, y1, c0, c1 = page_diff()
	if n > 0 then
		log(string.format("[%d] page %d bytes rows %d-%d cols %d-%d", frame, n, y0, y1, c0, c1))
		if n <= 60 and y1 < 124 and small_snaps < snap_budget then
			small_snaps = small_snaps + 1
			snap("small page change")
		end
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
			local planet = mem:read_u8(38209)
			log(string.format("planet=%d tech=%d defender=%d fighters=%d surrendered=%d X=%d Y=%d Z=%d",
				planet, mem:read_u8(38282 + planet), mem:read_u8(38205), mem:read_u8(38207),
				mem:read_u8(38208), s16(29467), s16(29469), s16(29471)))
			mem:write_u8(38208, 0)
			mem:write_u8(38207, 9)
			if mem:read_u8(38282 + planet) < 2 then mem:write_u8(38282 + planet, 3) end
			w16(29467, 700); w16(29469, 200); w16(29471, START_Z)
			nat:post("S")
		end
		if sf == 1500 and SHIELDS_DOWN then nat:post("S") end
		if sf == 2400 then
			mem:write_u8(MARK1, 0x7F); mem:write_u8(MARK2, 0x7F)
			enter("watch")
		end

	elseif state == "watch" then
		watch_frame(80)
		if sf == (SHIELDS_DOWN and 15000 or 4000) then enter("laser") end

	elseif state == "laser" then
		-- W: missile -> laser (restarts the loop), then hold the button
		if sf == 1 then nat:post("W") end
		if sf == 900 and btn then btn:set_value(1) end
		if sf >= 900 and sf <= 2400 then
			watch_frame(0)
			if sf <= 1500 and sf % 2 == 0 then snap("laser, button held") end
		end
		if sf == 2400 and btn then btn:set_value(0) end
		if sf == 3000 then enter("lores") end

	elseif state == "lores" then
		if sf == 1 then
			local out = assert(io.open(DIR .. "text_page.bin", "wb"))
			for a = 0x400, 0x7FF do out:write(string.char(mem:read_u8(a))) end
			out:close()
			mem:write_u8(0xC056, 0)
		end
		if sf == 4 then snap("lo-res flash (forced $C056)") end
		if sf == 5 then mem:write_u8(0xC057, 0) end
		if sf == 10 then enter("done") end

	elseif state == "done" then
		if sf == 1 then
			log("done")
			f:close()
			manager.machine:exit()
		end
	end
end)
