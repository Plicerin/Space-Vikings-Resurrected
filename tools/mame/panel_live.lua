-- Live capture of the instrument panel across passes: which hi-res page
-- BASIC's DRAW goes to (zero page $E6), and what the two pages hold after
-- every pass while the speed gauge is moving.
--
-- Each pass A2-3D1 clears the whole hidden page and draws the view on it;
-- line 150/153 then CALLs 37936 / 37888 (MEM TRANSFER A), which copies
-- rows 126-189 of the page on show to the hidden one. This run shows what
-- the gauge markers (DRAW 13/14, erased with 25/26) do on top of that.
--
-- Run on a copy of the disk image, from the repo root:
--
--   SV_OUT=/tmp/sv_panel WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/panel_live.lua \
--     -snapshot_directory /tmp/sv_panel -snapname "snap_%i"
--
-- panel_live.log: one "pass" line per pass. panel_<n>_p1.bin / _p2.bin:
-- the two hi-res pages at the moment pass n's line 147 runs, as 192 rows
-- of 40 bytes, top row first.

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "panel_live.log", "w"))
local function log(s) f:write(s .. "\n"); f:flush() end

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nat = manager.machine.natkeyboard

local function s16(addr)
	local v = mem:read_u8(addr) | (mem:read_u8(addr + 1) << 8)
	if v >= 32768 then v = v - 65536 end
	return v
end

-- key to press after pass n (speed: 1 -3, 2 +3, 3 -15, 4 +15)
local KEYS = {[2] = "4", [3] = "4", [5] = "3", [8] = "2", [9] = "4"}
local PASSES = 14

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

local frame, state, sf = 0, "boot", 0
local function enter(s) state = s; sf = 0; log(string.format("[%d] == %s", frame, s)) end
local last_iter, pass = nil, 0

emu.register_frame_done(function()
	frame = frame + 1
	sf = sf + 1

	if state == "boot" then
		if sf >= 180 and sf % 300 == 0 and sf <= 6000 then nat:post("N") end
		if mem:read_u8(232) == 255 then enter("settle")
		elseif sf > 9000 then log("TIMEOUT boot"); enter("done") end

	elseif state == "settle" then
		if sf == 1500 then
			mem:write_u8(38164, 1)
			mem:write_u8(38397, 128); mem:write_u8(38398, 128)
			last_iter = mem:read_u8(29461)
			enter("watch")
		end

	elseif state == "watch" then
		local it = mem:read_u8(29461)
		if it ~= last_iter then
			last_iter = it
			pass = pass + 1
			log(string.format("[%d] pass %d shown=%d E6=%d S=%d E=%d P=%d B=%d H=%d X=%d Y=%d Z=%d cg=%d", frame, pass,
				it, mem:read_u8(0xE6), mem:read_u8(38157), mem:read_u8(38199),
				mem:read_u8(29473), mem:read_u8(29474), mem:read_u8(29475),
				s16(29467), s16(29469), s16(29471), mem:read_u8(974)))
			dump_page(0x2000, string.format("panel_%d_p1.bin", pass))
			dump_page(0x4000, string.format("panel_%d_p2.bin", pass))
			if KEYS[pass] then nat:post(KEYS[pass]); log("key " .. KEYS[pass]) end
			if pass == 4 or pass == 7 then manager.machine.video:snapshot() end
			if pass >= PASSES then enter("done") end
		end
		if sf > 30000 then log("TIMEOUT watch"); enter("done") end

	elseif state == "done" then
		if sf == 1 then
			log("done")
			f:close()
			manager.machine:exit()
		end
	end
end)
