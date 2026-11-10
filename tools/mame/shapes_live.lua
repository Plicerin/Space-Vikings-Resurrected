-- Live screenshots that show the Applesoft shape table (ENEMY I, at $7FFF)
-- as the real ROM draws it: the flight panel (gauge markers = shapes 13/14,
-- panel lights), a missile launch (shapes 3..8 flip-book, then shape 2),
-- and the star chart (stars = shapes 1/5/6, cursor = shape 12).
-- Used to check tools/shape_table_decoder.py against the real screen.
--
-- Run on a copy of the disk image, from the repo root:
--
--   cp "disk_image/Space Vikings (4am crack).dsk" /tmp/sv.dsk
--   SV_OUT=/tmp/sv_shapes WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -flop1 /tmp/sv.dsk -gameio paddles -nothrottle \
--     -skip_gameinfo -autoboot_script tools/mame/shapes_live.lua \
--     -snapshot_directory /tmp/sv_shapes -snapname "snap_%i"
--
-- shapes_live.log lists which snapshot number is which.

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local f = assert(io.open(DIR .. "shapes_live.log", "w"))
local function log(s) f:write(s .. "\n"); f:flush() end

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nat = manager.machine.natkeyboard
local ports = manager.machine.ioport.ports

for tag, port in pairs(ports) do
	if tag:find("gameio") then
		for name, _ in pairs(port.fields) do log("port " .. tag .. " field " .. name) end
	end
end

local function field(tag, name)
	local p = ports[tag]
	return p and p.fields[name]
end
local pdl0 = field(":gameio:paddles:paddle_1", "Paddle")
local pdl1 = field(":gameio:paddles:paddle_2", "Paddle 2")
local btn = field(":gameio:paddles:paddle_buttons", "P1 Button 1")
log(string.format("pdl0=%s pdl1=%s btn=%s", tostring(pdl0), tostring(pdl1), tostring(btn)))

local snaps = 0
local frame, state, sf = 0, "boot", 0
local function snap(what)
	manager.machine.video:snapshot()
	log(string.format("[%d] snap_%d %s", frame, snaps, what))
	snaps = snaps + 1
end
local function enter(s) state = s; sf = 0; log(string.format("[%d] == %s", frame, s)) end

emu.register_frame_done(function()
	frame = frame + 1
	sf = sf + 1

	if state == "boot" then
		if sf >= 180 and sf % 300 == 0 and sf <= 6000 then nat:post("N") end
		if mem:read_u8(232) == 255 then enter("flight")
		elseif sf > 9000 then log("TIMEOUT boot"); enter("done") end

	elseif state == "flight" then
		if sf == 600 then snap("flight, new game") end
		if sf == 601 then nat:post("S") end
		if sf == 1200 then snap("flight, after S (shields up)"); enter("missile") end

	elseif state == "missile" then
		-- weapon is MISSILE at new game: hold the button, line 1000 runs
		if sf == 1 then
			log(string.format("[%d] weapon 38202=%d missiles 38187=%d", frame, mem:read_u8(38202), mem:read_u8(38187)))
			if btn then btn:set_value(1) end
		end
		if sf % 6 == 0 and sf <= 600 then snap("missile launch, button held") end
		if sf == 600 and btn then btn:set_value(0) end
		if sf == 1500 then
			log(string.format("[%d] missiles 38187=%d", frame, mem:read_u8(38187)))
			enter("com")
		end

	elseif state == "com" then
		if sf == 1 then nat:post("C") end
		if sf == 2400 then snap("COM"); nat:post("1") end
		if sf == 3000 then snap("central computer"); nat:post("3") end
		if sf == 3001 then
			-- SIRIUS: X=17 Y=23 -> screen 135,115
			if pdl0 then pdl0:set_value(113) end
			if pdl1 then pdl1:set_value(115) end
		end
		if sf == 5400 then snap("star chart, cursor near SIRIUS") end
		if sf == 5460 then snap("star chart, cursor near SIRIUS (2)") end
		if sf == 5520 then snap("star chart, cursor near SIRIUS (3)") end
		if sf == 5521 and btn then btn:set_value(1) end
		if sf == 5640 and btn then btn:set_value(0) end
		if sf == 6400 then snap("star chart, after button") end
		if sf == 7000 then enter("done") end

	elseif state == "done" then
		if sf == 1 then
			log("done")
			f:close()
			manager.machine:exit()
		end
	end
end)
