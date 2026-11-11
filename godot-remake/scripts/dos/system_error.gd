extends Control
## SYSTEM ERROR! PRESS ANY KEY TO REBOOT
##
## The disk's DOS 3.3 has had its error handler replaced. Where DOS
## would print "FILE NOT FOUND" or "I/O ERROR" and go back to BASIC
## ($A6D2), this one clears the text screen, writes two lines on it,
## shows it, waits for a key and jumps through the reset vector:
##
##   A6D2  STA $AA5C        the error number, which nothing reads again
##   A6D5  JSR $FC58        HOME
##   A6D8  LDY #0
##   A6DA  LDA $A971,Y      the table below
##         BPL A6E5
##         JSR $FDF0        COUT1: on the text screen, past the game's
##   A6E2  INY              hi-res character generator
##         BNE A6DA
##   A6E5  BEQ A6F2         0 ends it
##         TAX              1-127: that many spaces
##         LDA #$A0
##   A6EA  JSR $FDF0
##         DEX
##         BNE A6EA
##         BEQ A6E2
##   A6F2  LDA $C054        page 1
##         LDA $C051        text
##         LDA $C010        the key strobe cleared
##         JSR $FD1B        KEYIN: a key, with no cursor shown
##         JMP ($FFFC)      the reset vector, which boots the disk
##
## The table sits where DOS keeps its error messages. The message is
## placed with runs of spaces, not with the cursor: 413 of them wrap
## round to row 10, column 13.
##
## DOS's INT command has been pointed at the same place ($A59E: JMP
## $A6D5), and every BASIC program of the game starts `ONERR GOTO 63999`
## and ends `63999 PRINT : PRINT CHR$(4)"INT"`. So an error of any kind,
## BASIC's or DOS's, in any program, ends here. The player can get to it
## from the keyboard: END.bas reads its menu choice with a numeric GET,
## and a letter is a ?SYNTAX ERROR.
##
## Watched live (tools/mame/end_live.lua, the routes key_letter,
## key_return and key_escape; analysis/live/end/system_error.png is the
## screen, dos_9d00.bin the DOS it was disassembled from): the display
## goes to text 4.2 frames after line 63999 starts, the screen stays as
## it is for as long as no key is pressed, and a key brings "APPLE ]["
## and, eight seconds on, START.bas.
##
## HOME and COUT1 work inside the monitor's text window, which the
## game's programs narrow and leave narrowed. Only END's has been seen
## live, and END's is the whole screen; from a program with a narrower
## one the message would be wrapped differently, and whatever the text
## screen held outside the window (not kept in this port) would be
## left showing round it.

const TextScreen = preload("res://scripts/shapes/text_screen.gd")
const TextView = preload("res://scripts/shapes/text_view.gd")

## $A971-$A99B.
const TABLE: PackedByteArray = [
	0x78, 0x78, 0x78, 0x35,
	0xD3, 0xD9, 0xD3, 0xD4, 0xC5, 0xCD, 0xA0, 0xC5, 0xD2, 0xD2, 0xCF, 0xD2, 0xA1, 0x8D,
	0x30,
	0xD0, 0xD2, 0xC5, 0xD3, 0xD3, 0xA0, 0xC1, 0xCE, 0xD9, 0xA0, 0xCB, 0xC5, 0xD9, 0xA0,
	0xD4, 0xCF, 0xA0, 0xD2, 0xC5, 0xC2, 0xCF, 0xCF, 0xD4,
	0x00,
]

@onready var _view: TextView = $HGRCanvas/TextView


## $A6D5-$A6F0 on `screen`.
static func write(screen: TextScreen) -> void:
	screen.home()
	for code in TABLE:
		if code == 0:
			break
		if code >= 0x80:
			screen.cout(code)
		else:
			for i in range(code):
				screen.cout(TextScreen.SPACE)


func _ready() -> void:
	var screen := TextScreen.new()
	var text: RefCounted = GameState.chargen
	screen.set_window(text.window_left, text.window_width, text.window_top, text.window_bottom)
	write(screen)
	_view.screen = screen


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo:
		GameState.reboot()
