-- What Applesoft's own arithmetic makes of the star chart's two formulas
-- that do not come out the same in every floating point (GALAXY MAP.bas):
--
--   line 3110        PX = PDL(0) * 1.19   (XDRAW 12 AT PX,PY cuts it to
--                    a whole number)
--   lines 3300-3320  INT(SQR(X1 ^ 2 + X2 ^ 2 + X3 ^ 2)), the distance
--                    between two stars; Applesoft's ^ and SQR go through
--                    LOG and EXP and are not exact on whole numbers
--
-- Runs a short BASIC program on a bare Apple II+ (no disk card, so it
-- comes up at the ] prompt) that works both out with the new game's
-- star positions and writes them to chart_float_live.txt: 256 values of
-- INT(H*1.19), then 20 lines of 20 distances (from star L to star P).
--
--   SV_OUT=/tmp/sv_float WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -sl6 "" -nothrottle -skip_gameinfo \
--     -autoboot_script tools/mame/chart_float_live.lua

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nat = manager.machine.natkeyboard

local LINES = {
	"NEW",
	"10 DIM X(20),Y(20),Z(20)",
	"20 FOR P=1 TO 20:READ X(P):NEXT:FOR P=1 TO 20:READ Y(P):NEXT:FOR P=1 TO 20:READ Z(P):NEXT",
	"30 N=24576:FOR L=1 TO 20:FOR P=1 TO 20",
	"40 X1=ABS(X(L)-X(P)):X2=ABS(Y(L)-Y(P)):X3=ABS(Z(L)-Z(P))",
	"50 D1=SQR(X1^2+X2^2+X3^2):POKE N,INT(D1):N=N+1:NEXT:NEXT",
	"60 FOR H=0 TO 255:POKE 25088+H,INT(H*1.19)-H:NEXT",
	"70 POKE 25600,77",
	"80 DATA 15,13,14,8,22,13,17,14,19,20,9,7,25,25,9,25,24,11,18,11",
	"81 DATA 15,13,9,16,14,22,23,8,13,22,23,23,21,15,21,5,10,18,27,11",
	"82 DATA 15,12,15,12,19,19,12,9,25,10,20,14,13,21,19,11,10,27,11,25",
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
		local f = assert(io.open(DIR .. "chart_float_live.txt", "w"))
		local a = {}
		for i = 0, 255 do a[#a + 1] = tostring(mem:read_u8(25088 + i) + i) end
		f:write(table.concat(a, " ") .. "\n")
		for l = 0, 19 do
			local row = {}
			for p = 0, 19 do row[#row + 1] = tostring(mem:read_u8(24576 + l * 20 + p)) end
			f:write(table.concat(row, " ") .. "\n")
		end
		f:close()
		manager.machine:exit()
	end
	if frame > 200000 then manager.machine:exit() end
end)
