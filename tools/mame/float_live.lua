-- What Applesoft's own arithmetic makes of the flight program's two
-- formulas that do not come out the same in every floating point:
--
--   line 155   INT (H * Q), Q = 1.41      the heading and pitch read-outs
--   line 159   TX = 140 + ((HL - B) / 5.7), or 140 - (B / 5.7) below 127
--              (DRAW 13 AT TX,133 cuts it to a whole number)
--
-- Runs a four-line BASIC program on a bare Apple II+ (no disk card, so
-- it comes up at the ] prompt) that POKEs both tables into memory, and
-- writes them to float_live.txt: 256 values of INT(H*1.41) and 256 of TX.
--
--   SV_OUT=/tmp/sv_float WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
--     cage -- mame apple2p -sl6 "" -nothrottle -skip_gameinfo \
--     -autoboot_script tools/mame/float_live.lua

local DIR = (os.getenv("SV_OUT") or ".") .. "/"
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nat = manager.machine.natkeyboard

local LINES = {
	"NEW",
	"10 Q=1.41:HL=255:FOR H=0 TO 255:POKE 24576+H,INT(H*Q)-H:NEXT",
	"20 FOR B=0 TO 255:TX=140+((HL-B)/5.7):IF B<127 THEN TX=140-(B/5.7)",
	"30 POKE 24832+B,TX:NEXT",
	"40 POKE 25100,77",
	"RUN",
}

local frame = 0
local typed = 0
emu.register_frame_done(function()
	frame = frame + 1
	if frame == 240 then mem:write_u8(25100, 0) end
	if frame >= 300 and typed < #LINES and not nat.is_posting and frame % 30 == 0 then
		typed = typed + 1
		nat:post(LINES[typed] .. "\n")
	end
	if typed == #LINES and mem:read_u8(25100) == 77 then
		local f = assert(io.open(DIR .. "float_live.txt", "w"))
		local a, b = {}, {}
		for i = 0, 255 do
			a[#a + 1] = tostring(mem:read_u8(24576 + i) + i)
			b[#b + 1] = tostring(mem:read_u8(24832 + i))
		end
		f:write(table.concat(a, " ") .. "\n" .. table.concat(b, " ") .. "\n")
		f:close()
		manager.machine:exit()
	end
	if frame > 60000 then manager.machine:exit() end
end)
