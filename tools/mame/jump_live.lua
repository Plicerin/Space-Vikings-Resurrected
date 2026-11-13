-- Live record of the parts of flight that pass_live.lua does not reach:
-- a real hyperdrive jump (H_D.bas), a missile that hits and one that
-- misses, the laser, the defender's destruction (EX.bas), a surrender,
-- the first damage (DMG.bas) and the loss of the ship (S/X.bas).
--
-- It is a timing record first: the frame of every display switch, of
-- every write to the bytes those programs POKE, of every ray H_D draws
-- from the screen's centre, of the paddle-button read (line 185) and of
-- the keyboard read (line 200) of every pass. Both hi-res pages are
-- dumped at every line 147 as in pass_live.lua, and page 1 again at the
-- moments named in the log ("dump" lines).
--
-- The script is keyed by the count of line-147 events since boot, like
-- pass_live.lua's. A new game has no course set, so the script pokes the
-- course byte itself (38163 = 2, the planet the COM menu would have set)
-- and presses H. Planet 2 has a defender and has not surrendered. The
-- ship arrives at a random place at least 7000 from it; the script then
-- moves it into the missile's line: 800 short of the box around
-- (400, -100, -3500) that line 1050 tests, nose at heading 0, stopped.
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_OUT=/tmp/sv_jump WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/jump_live.lua \
--     -snapshot_directory /tmp/sv_jump -snapname "snap_%i"
--
-- jump_live.log: "ev" = a line-147 event (same fields as pass_live.log,
-- then the combat bytes), "act" = what the script did there, "w" = a
-- watched byte written (value, and the program counter's page: D0 and up
-- is BASIC's POKE, below that DOS or machine code), "sw" = a display
-- switch touched, "btn" / "kbd" = lines 185 and 200, "ray" = a write to
-- the page-1 byte under (140,63) (the first and every 25th; a ray
-- writes it once for each of its dots in that byte), "page" = frames on
-- which page 1 changed while the script was watching it (the jump, and
-- each pass in which it fires).

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "jump_live.log", "w"))
local function log(s) f:write(s .. "\n"); f:flush() end

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nat = manager.machine.natkeyboard
local ports = manager.machine.ioport.ports
local function field(tag, name)
	local p = ports[tag]
	return p and p.fields[name]
end
local btn = field(":gameio:paddles:paddle_buttons", "P1 Button 1")

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
local function pc() return cpu.state["PC"].value end

local P1, B1, H1 = 29473, 29474, 29475

-- event number -> list of actions:
--   {"key", "S"}  {"poke", addr, value}  {"pos", x, y, z}  {"att", p, b, h}
--   {"speed", s}  {"fire"} (hold the paddle button until line 185 has
--   read it, watching page 1)  {"end"}
-- Events 1-3 are the new game at SOL; the jump follows event 3.
local SCRIPT = {
	[3] = {{"poke", 38163, 2}, {"key", "H"}},
	-- 4, 5, 6: the first passes after arrival, left alone
	[7] = {{"pos", 400, -80, -4300}, {"att", 0, 0, 0}, {"speed", 0}, {"poke", 38207, 0}, {"key", "S"}},
	[10] = {{"fire"}},                                  -- missile, direct hit
	[13] = {{"att", 0, 0, 64}},
	[14] = {{"fire"}},                                  -- missile, miss
	[16] = {{"att", 0, 0, 0}, {"key", "W"}},
	[19] = {{"fire"}},                                  -- laser
	[22] = {{"key", "W"}},
	[25] = {{"poke", 38152, 170}, {"fire"}},            -- missile, the defender goes (EX)
	[29] = {{"key", "W"}},
	[32] = {{"poke", 38150, 1}, {"fire"}},              -- laser, the planet surrenders
	[36] = {{"poke", 38208, 0}, {"poke", 38205, 2}, {"key", "S"}}, -- shields down, defender back
	-- the first damage runs DMG; the hull is then set to 1 (see on_147)
	-- and the next damage runs S/X, which ends the record
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
local firing = false
local watching = false   -- log the frames on which page 1 changes
local dumps = 0
local hull_due = false
local release_due = false
local sx_frame = nil

local function named_dump(what)
	dumps = dumps + 1
	dump_page(0x2000, string.format("dump_%d_p1.bin", dumps))
	dump_page(0x4000, string.format("dump_%d_p2.bin", dumps))
	log(string.format("[%d] dump %d %s (+%d)", frame, dumps, what, frame - last_event_frame))
end

local prev = {}
local function page_diff(reset)
	local n, y0, y1, c0, c1 = 0, 999, -1, 999, -1
	for y = 0, 191 do
		local a = 0x2000 + rowbase[y]
		for c = 0, 39 do
			local v = mem:read_u8(a + c)
			local k = y * 40 + c
			if prev[k] ~= v then
				if not reset then
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

-- what the display switches were last set to, by pair: [2] is 4 for
-- page 1 and 5 for page 2. (An Apple II+ cannot be asked: $C01C, the
-- IIe's RDPAGE2, is the keyboard strobe here. The recording in
-- analysis/live/jump/ was made asking, so its "shown" is always 1; the
-- "sw" lines are right.)
local last_switch = {}

local function on_147(data)
	events = events + 1
	local planet = mem:read_u8(38209)
	log(string.format(
		"[%d] ev %d (+%d) it=%d X=%d Y=%d Z=%d P=%d B=%d H=%d S=%d E=%d pdl=%d/%d auto=%d cond=%d"
		.. " shields=%d weapon=%d atmos=%d dmg=%d flip=%d b149=%d planet=%d target=%d defender=%d"
		.. " c974=%d shown=%d"
		.. " tech=%d surrendered=%d fighters=%d strength=%d vp=%d dp=%d threshold=%d shield=%d"
		.. " hull=%d missiles=%d laser=%d radar=%d eng1=%d eng2=%d computer=%d secured=%d scouted=%d"
		.. " stationed=%d morale=%d loot=%d c973=%d",
		frame, events, frame - last_event_frame, data, s16(29467), s16(29469), s16(29471),
		mem:read_u8(P1), mem:read_u8(B1), mem:read_u8(H1), mem:read_u8(38157), mem:read_u8(38199),
		mem:read_u8(38397), mem:read_u8(38398), mem:read_u8(38164), mem:read_u8(38165),
		mem:read_u8(38201), mem:read_u8(38202), mem:read_u8(38210), mem:read_u8(38393),
		mem:read_u8(0x952F), mem:read_u8(38149), planet, mem:read_u8(38163),
		mem:read_u8(38205), mem:read_u8(974), (last_switch[2] or 4) - 3,
		mem:read_u8(38282 + planet), mem:read_u8(38208), mem:read_u8(38207), mem:read_u8(38150),
		mem:read_u8(38160), mem:read_u8(38152), mem:read_u8(38204), mem:read_u8(38200),
		mem:read_u8(38193), mem:read_u8(38187), mem:read_u8(38186), mem:read_u8(38195),
		mem:read_u8(38198), mem:read_u8(38197), mem:read_u8(38196), mem:read_u8(38219 + planet),
		mem:read_u8(38240 + planet), mem:read_u8(38158), mem:read_u8(38203), mem:read_u8(301),
		mem:read_u8(973)))
	last_event_frame = frame
	watching = false
	dump_page(0x2000, string.format("ev_%d_p1.bin", events))
	dump_page(0x4000, string.format("ev_%d_p2.bin", events))
	if hull_due then
		hull_due = false
		mem:write_u8(38193, 1)
		log("act poke 38193 1")
	end
	local acts = SCRIPT[events]
	if not acts then return end
	for _, a in ipairs(acts) do
		if a[1] == "key" then
			pending_keys[#pending_keys + 1] = a[2]
			log("act key " .. a[2])
			if a[2] == "H" then
				page_diff(true)
				watching = true
			end
		elseif a[1] == "poke" then
			mem:write_u8(a[2], a[3])
			log(string.format("act poke %d %d", a[2], a[3]))
		elseif a[1] == "pos" then
			w16(29467, a[2]); w16(29469, a[3]); w16(29471, a[4])
			log(string.format("act pos %d %d %d", a[2], a[3], a[4]))
		elseif a[1] == "att" then
			mem:write_u8(P1, a[2]); mem:write_u8(B1, a[3]); mem:write_u8(H1, a[4])
			log(string.format("act att %d %d %d", a[2], a[3], a[4]))
		elseif a[1] == "speed" then
			mem:write_u8(38157, a[2])
			log(string.format("act speed %d", a[2]))
		elseif a[1] == "fire" then
			firing = true
			if btn then btn:set_value(1) end
			page_diff(true)
			watching = true
			log("act fire")
		elseif a[1] == "end" then
			finished = true
		end
	end
end

-- keep the handles (a global, so they are never collected): a tap is
-- removed when its handle is
jump_live_taps = {}
local taps = jump_live_taps
local function tap_w(first, last, name, fn)
	taps[#taps + 1] = mem:install_write_tap(first, last, name, fn)
end
local function tap_r(first, last, name, fn)
	taps[#taps + 1] = mem:install_read_tap(first, last, name, fn)
end

-- Byte 29461 is inside the planet file ($7300 up): only BASIC's POKE
-- (program counter in the Applesoft ROM) is line 147.
tap_w(29461, 29461, "pass", function(offset, data, mask)
	if finished then return end
	if pc() >= 0xD000 then
		on_147(data)
	else
		log(string.format("[%d] planet file loaded over byte 29461 (+%d)", frame, frame - last_event_frame))
	end
end)

local WATCHED = {
	[974] = "chargen_page", [973] = "text_mode", [301] = "loot",
	[38149] = "first_pass", [38150] = "strength", [38152] = "dp", [38158] = "stationed",
	[38160] = "vp", [38161] = "b38161", [38163] = "target", [38170] = "b38170",
	[38186] = "laser", [38187] = "missiles", [38193] = "hull", [38195] = "radar",
	[38196] = "computer", [38197] = "eng2", [38198] = "eng1", [38199] = "energy",
	[38200] = "shield", [38203] = "morale", [38204] = "threshold", [38205] = "defender",
	[38206] = "b38206", [38207] = "fighters", [38208] = "surrendered", [38209] = "planet",
	[38219 + 2] = "secured_2", [38240 + 2] = "scouted_2", [38389] = "enlisted",
	[38392] = "b38392", [38393] = "dmgflag", [38823] = "record_planet", [38824] = "record_dir",
	[29473] = "pitch", [29474] = "bank", [29475] = "heading", [30841] = "ship_slot",
	[37490] = "sg_a", [37491] = "sg_b", [37492] = "sg_c", [37493] = "sg_d",
}
for addr, name in pairs(WATCHED) do
	tap_w(addr, addr, name, function(offset, data, mask)
		local p = pc()
		-- the stick routine rewrites the attitude bytes every pass
		if (addr == 29473 or addr == 29474 or addr == 29475) and p < 0xD000 then return end
		log(string.format("[%d] w %s=%d pc=%04X (+%d)", frame, name, data, p, frame - last_event_frame))
		if addr == 38393 and data == 1 and p >= 0xD000 then hull_due = true end
		if addr == 973 and data == 255 and sx_frame == nil and events > 30 then
			sx_frame = frame
			named_dump("S/X starts")
		end
	end)
end

-- display switches: $C050 graphics, $C051 text, $C054/5 page 1/2,
-- $C056/7 lo-res/hi-res
local SWITCH = {[0] = "graphics", "text", "full", "mixed", "page1", "page2", "lores", "hires"}
local function switch_touched(offset)
	local n = offset & 7
	local group = n >> 1
	if last_switch[group] ~= n then
		last_switch[group] = n
		log(string.format("[%d] sw %s (+%d)", frame, SWITCH[n], frame - last_event_frame))
	end
end
tap_w(0xC050, 0xC057, "switch w", function(offset, data, mask) switch_touched(offset) end)
tap_r(0xC050, 0xC057, "switch r", function(offset, data, mask) switch_touched(offset) end)

-- line 185 reads the paddle button, line 200 the keyboard, both with PEEK
local function in_peek(p) return (p & 0xFF00) == 0xE700 end
tap_r(0xC061, 0xC061, "button", function(offset, data, mask)
	if in_peek(pc()) then
		log(string.format("[%d] btn (+%d)", frame, frame - last_event_frame))
		if firing then
			firing = false
			release_due = true
		end
	end
end)
-- Applesoft also looks at $C000 after every statement (for ctrl-C, from
-- $D858); line 200's is the one PEEK makes.
tap_r(0xC000, 0xC000, "keyboard", function(offset, data, mask)
	if in_peek(pc()) and events > 0 then
		log(string.format("[%d] kbd %02X (+%d)", frame, data, frame - last_event_frame))
	end
end)

-- H_D's rays all start at (140,63): row 63, byte 20 of page 1
local RAY = 0x2000 + rowbase[63] + 20
local rays = 0
tap_w(RAY, RAY, "ray", function(offset, data, mask)
	if pc() < 0xD000 or events < 3 then return end
	rays = rays + 1
	if rays == 1 or rays % 25 == 0 then
		log(string.format("[%d] ray %d data=%02X (+%d)", frame, rays, data, frame - last_event_frame))
	end
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
	if release_due then
		release_due = false
		if btn then btn:set_value(0) end
	end
	if watching then
		local n, y0, y1, c0, c1 = page_diff(false)
		if n > 0 then
			log(string.format("[%d] page %d bytes rows %d-%d cols %d-%d (+%d)", frame, n, y0, y1, c0, c1,
				frame - last_event_frame))
		end
	end
	if sx_frame then
		local t = frame - sx_frame
		if t == 400 or t == 1200 or t == 2400 then named_dump("S/X +" .. t) end
		if t == 2400 then nat:post("X") end
		if t == 2460 then nat:post("X") end
		if t > 2700 then finished = true end
	end
	if finished then
		log("done")
		f:close()
		manager.machine:exit()
	end
	if frame > 400000 then
		log("TIMEOUT")
		f:close()
		manager.machine:exit()
	end
end)
