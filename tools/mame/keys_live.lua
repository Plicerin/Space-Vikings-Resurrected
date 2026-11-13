-- Live check of the flight-loop keys S/W/B/A/H and the per-planet record
-- copy ($97A9) against the static map in CALL_SITES.md.
-- Logs every change of the watched bytes with the frame it happened on.
--
-- The game writes MISC FILE on a hyperdrive jump, so run it on a copy of
-- the disk image, from the repo root:
--
--   cp "disk_image/Space Vikings (4am crack).dsk" /tmp/sv.dsk
--   SV_OUT=/tmp/sv_keys WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/keys_live.lua \
--     -snapshot_directory /tmp/sv_keys -snapname "snap_%i"
--
-- SV_OUT is the directory keys_live.log is written to (default: the
-- current directory). A reference log is in analysis/keys_live.log.

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "keys_live.log", "w"))
local function log(s) f:write(s .. "\n"); f:flush() end

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nat = manager.machine.natkeyboard

-- name, address (decimal)
local watch = {
	{"A_9514", 38164}, {"B_9515", 38165}, {"S_9539", 38201}, {"W_953A", 38202},
	{"mode_9517", 38167}, {"all_952D", 38189},
	{"target_38163", 38163}, {"planet_38209", 38209},
	{"rec0_38204", 38204}, {"defender_38205", 38205}, {"rec4_38208", 38208},
	{"byte17_954C", 38220}, {"rec2_byte0_97F1", 38897}, {"rec3_byte0_9801", 38913},
	{"energy_38199", 38199}, {"scouted2_38242", 38242},
}
local last = {}

local frame, state, sf = 0, "boot", 0
local function enter(s) state = s; sf = 0; log(string.format("[%d] == %s", frame, s)) end

local keys = {"S", "S", "W", "W", "B", "B", "B", "A", "A"}
local ki = 0
local GAP = 600

emu.register_frame_done(function()
	frame = frame + 1
	sf = sf + 1
	for _, w in ipairs(watch) do
		local v = mem:read_u8(w[2])
		if last[w[1]] ~= v then
			log(string.format("[%d] %s: %s -> %d", frame, w[1], tostring(last[w[1]]), v))
			last[w[1]] = v
		end
	end

	if state == "boot" then
		if sf >= 180 and sf % 300 == 0 and sf <= 6000 then nat:post("N") end
		if mem:read_u8(232) == 255 then enter("settle")
		elseif sf > 9000 then log("TIMEOUT boot"); enter("done") end

	elseif state == "settle" then
		if sf == 600 then manager.machine.video:snapshot(); enter("keys") end

	elseif state == "keys" then
		if sf % GAP == 1 then
			ki = ki + 1
			if ki > #keys then
				manager.machine.video:snapshot()
				enter("h_no_course")
			else
				log(string.format("[%d] post %s", frame, keys[ki]))
				nat:post(keys[ki])
			end
		end

	elseif state == "h_no_course" then
		-- no course set: H/D line 1 should bounce straight back
		if sf == 1 then log(string.format("[%d] post H (target=%d planet=%d)", frame, mem:read_u8(38163), mem:read_u8(38209))); nat:post("H") end
		if sf == 1800 then enter("h_course") end

	elseif state == "h_course" then
		if sf == 1 then
			mem:write_u8(38163, 2)
			log(string.format("[%d] wrote target 38163=2, post H", frame))
			nat:post("H")
		end
		if sf == 600 or sf == 1500 or sf == 3000 then manager.machine.video:snapshot() end
		if sf == 4500 then enter("done") end

	elseif state == "done" then
		if sf == 1 then
			manager.machine.video:snapshot()
			log("done")
			f:close()
			manager.machine:exit()
		end
	end
end)
