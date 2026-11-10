-- Live capture of what A2-3D1 draws for a known eye position and attitude,
-- to measure the projection (where a point at X/Y/Z lands on the hi-res
-- page) and the sense of pitch, bank and heading.
--
-- Space: the ship is parked (speed 0, autopilot byte set, stick centred)
-- at (0, 0, -12000), outside the re-entry and combat boxes, and the
-- attitude bytes $7321-$7323 are poked through SPACE_VIEWS. Atmosphere:
-- the ship is then moved inside the re-entry box and restarted, RE.bas
-- runs, and ATMOS_VIEWS are captured over the planet's terrain map.
--
-- A picture drawn in pass n is complete and displayed when pass n+1
-- flips byte 29461 (line 147). BASIC prints on page 1 when OO=1 (POKE
-- 974,32) and on page 2 when OO=0, which is the page the pass just drew,
-- so the finished picture is on page 2 when 29461 has just become 85 and
-- on page 1 when it has just become 84. Each view is held for three
-- passes and both pages are dumped, so the rule can be checked.
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_OUT=/tmp/sv_view WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/view_live.lua \
--     -snapshot_directory /tmp/sv_view -snapname "snap_%i"
--
-- view_live.log: one "pass" line per pass, one "view" line per capture (eye position and attitude
-- of the picture, and which page holds it). view_<n>_p1.bin / _p2.bin:
-- the two hi-res pages as 192 rows of 40 bytes, top row first.
-- tools/a2_3d1_oracle.py check <directory> compares them with what the
-- engine's own code draws for the same eye and attitude.

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "view_live.log", "w"))
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

-- {pitch, bank, heading}
local SPACE_VIEWS = {
	{0, 0, 0}, {0, 0, 16}, {0, 0, 240}, {16, 0, 0}, {240, 0, 0}, {0, 4, 0}, {0, 252, 0},
	{0, 0, 64}, {0, 0, 128}, {0, 0, 192}, {20, 4, 40},
}
local ATMOS_VIEWS = {
	{-1, -1, -1}, -- as RE.bas leaves it
	{0, 0, 0}, {0, 0, 64}, {20, 0, 20}, {40, 0, 20}, {240, 0, 20}, {10, 4, 20},
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

local snaps = 0
local frame, state, sf = 0, "boot", 0
local function snap(what)
	manager.machine.video:snapshot()
	log(string.format("[%d] snap_%d %s", frame, snaps, what))
	snaps = snaps + 1
end
local function enter(s) state = s; sf = 0; log(string.format("[%d] == %s", frame, s)) end

local last_iter = nil
local views, view_i, held = nil, 0, 0
local captures = 0
local pos = {0, 0, 0}

local function poke_view()
	local v = views[view_i]
	if v[1] >= 0 then
		mem:write_u8(P1, v[1]); mem:write_u8(B1, v[2]); mem:write_u8(H1, v[3])
	end
end

-- returns true when the list of views is finished
local function on_pass(tag)
	local it = mem:read_u8(29461)
	log(string.format("[%d] pass %s X=%d Y=%d Z=%d P=%d B=%d H=%d S=%d", frame, tag,
		s16(29467), s16(29469), s16(29471), mem:read_u8(P1), mem:read_u8(B1), mem:read_u8(H1),
		mem:read_u8(38157)))
	if view_i > 0 then
		held = held + 1
		if held == 3 then
			-- the picture drawn in the pass that just ended: eye at the position
			-- that pass stored (logged one pass ago), attitude as it is now
			local page = (it == 85) and 2 or 1
			log(string.format("view %d %s X=%d Y=%d Z=%d P=%d B=%d H=%d page=%d atmos=%d planet=%d defender=%d",
				captures, tag, pos[1], pos[2], pos[3], mem:read_u8(P1), mem:read_u8(B1), mem:read_u8(H1),
				page, mem:read_u8(38210), mem:read_u8(38209), mem:read_u8(38205)))
			dump_page(0x2000, string.format("view_%d_p1.bin", captures))
			dump_page(0x4000, string.format("view_%d_p2.bin", captures))
			snap(string.format("view %d", captures))
			captures = captures + 1
			held = 0
			view_i = view_i + 1
			if view_i > #views then return true end
		end
	else
		view_i = 1
		held = 0
	end
	poke_view()
	pos = {s16(29467), s16(29469), s16(29471)}
	return false
end

local function start_views(list)
	views, view_i, held = list, 0, 0
	last_iter = mem:read_u8(29461)
end

emu.register_frame_done(function()
	frame = frame + 1
	sf = sf + 1

	if state == "boot" then
		if sf >= 180 and sf % 300 == 0 and sf <= 6000 then nat:post("N") end
		if mem:read_u8(232) == 255 then enter("park")
		elseif sf > 9000 then log("TIMEOUT boot"); enter("done") end

	elseif state == "park" then
		if sf == 600 then
			w16(29467, 0); w16(29469, 0); w16(29471, -12000)
			mem:write_u8(38157, 0)
			mem:write_u8(P1, 0); mem:write_u8(B1, 0); mem:write_u8(H1, 0)
			nat:post("S") -- restart: line 8 re-reads position and speed
		end
		if sf == 1500 then
			mem:write_u8(38164, 1)
			mem:write_u8(38397, 128); mem:write_u8(38398, 128)
			start_views(SPACE_VIEWS)
			enter("space")
		end

	elseif state == "space" then
		local it = mem:read_u8(29461)
		if it ~= last_iter then
			last_iter = it
			if on_pass("space") then enter("descend") end
		end
		if sf > 30000 then log("TIMEOUT space"); enter("done") end

	elseif state == "descend" then
		if sf == 1 then
			mem:write_u8(P1, 0); mem:write_u8(B1, 0); mem:write_u8(H1, 0)
			w16(29467, 300); w16(29469, 200); w16(29471, -500)
			log(string.format("before RE: X=%d Y=%d Z=%d P=%d B=%d H=%d",
				s16(29467), s16(29469), s16(29471), mem:read_u8(P1), mem:read_u8(B1), mem:read_u8(H1)))
			nat:post("S")
		end
		if sf > 300 and mem:read_u8(38210) == 1 then
			log(string.format("[%d] atmosphere byte set", frame))
			mem:write_u8(38164, 1)
			mem:write_u8(38397, 128); mem:write_u8(38398, 128)
			start_views(ATMOS_VIEWS)
			enter("atmos")
		elseif sf > 9000 then log("TIMEOUT descend"); enter("done") end

	elseif state == "atmos" then
		local it = mem:read_u8(29461)
		if it ~= last_iter then
			last_iter = it
			if on_pass("atmos") then enter("done") end
		end
		if sf > 30000 then log("TIMEOUT atmos"); enter("done") end

	elseif state == "done" then
		if sf == 1 then
			log("done")
			f:close()
			manager.machine:exit()
		end
	end
end)
