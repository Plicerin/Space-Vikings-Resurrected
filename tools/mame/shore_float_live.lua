-- What Applesoft's own arithmetic makes of the two sums in SHORE
-- LEAVE.bas's repairs that need not come out whole (lines 2520-2525):
--
--   line 2524-2525  D2 = (63 - D) * (100 / 63): D1 = INT((D2 / 100) * 100)
--                   the share of the ENERGY that is gone, for D = 0 to 62
--   line 2520       100 - ((D / 100) * 100), for D = 0 to 99: is it the
--                   whole number 100 - D?
--
-- Runs a short BASIC program on a bare Apple II+ (no disk card, so it
-- comes up at the ] prompt) and writes shore_float_live.txt: the 63
-- values of D1, then 100 of 1 (the same as 100 - D) or 0.
--
--   SV_OUT=/tmp/sv_float WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -sl6 "" -nothrottle -skip_gameinfo \
--     -autoboot_script tools/mame/shore_float_live.lua

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nat = manager.machine.natkeyboard

local LINES = {
	"NEW",
	"10 FOR D=0 TO 62:D2=63-D:D2=D2*(100/63):D1=INT((D2/100)*100):POKE 24576+D,D1:NEXT",
	"20 FOR D=0 TO 99:X=100-((D/100)*100):POKE 24832+D,(X=100-D):NEXT",
	"30 POKE 25600,77",
	"RUN",
}

local frame = 0
local typed = 0
emu.register_frame_done(function()
	frame = frame + 1
	if frame == 240 then mem:write_u8(25600, 0) end
	if frame >= 300 and typed < #LINES and not nat.is_posting and frame % 30 == 0 then
		typed = typed + 1
		nat:post(LINES[typed] .. "\n")
	end
	if typed == #LINES and mem:read_u8(25600) == 77 then
		local f = assert(io.open(DIR .. "shore_float_live.txt", "w"))
		local a = {}
		for d = 0, 62 do a[#a + 1] = tostring(mem:read_u8(24576 + d)) end
		f:write(table.concat(a, " ") .. "\n")
		a = {}
		for d = 0, 99 do a[#a + 1] = tostring(mem:read_u8(24832 + d)) end
		f:write(table.concat(a, " ") .. "\n")
		f:close()
		manager.machine:exit()
	end
	if frame > 200000 then manager.machine:exit() end
end)
