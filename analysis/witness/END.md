# END: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

21 lines: 10 logic, 10 presentation, 1 waived. 13 lines cited by a rule; 0 of them never run in a recording.
Machine-code calls: line 210 -> 38825.

## Problems

none

## Cited, and never run in a recording (the listing alone)

none

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  | 3 | `ONERR  GOTO 63999` |
| 20 | P |  | 3 | `POKE 974,32` |
| 30 | P |  | 3 | `POKE 33,40: FOR J = 1 TO 16: VTAB J: PRINT "                                        ": NEX` |
| 31 | P |  | 3 | `SPEED= 255` |
| 40 | P |  | 3 | `PRINT " ": HTAB 16: PRINT "END GAME": PRINT : PRINT` |
| 50 | P |  | 3 | `PRINT  TAB( 7);"1) SAVE GAME"` |
| 60 | P |  | 3 | `PRINT  TAB( 7);"2) CONTINUE PRESENT GAME": PRINT  TAB( 7);"3) END GAME": PRINT : PRINT` |
| 70 | L | godot-remake/scripts/end/end_console.gd:48 | 3 | `PRINT "ENTER CHOICE.  ";: GET C: IF C < 1 OR C > 3 THEN 30` |
| 75 | P | godot-remake/scripts/end/end_console.gd:48 | 3 | `PRINT " "` |
| 80 | L | godot-remake/scripts/end/end_console.gd:48 | 3 | `IF C = 1 THEN  GOSUB 190: GOTO 30` |
| 90 | L | godot-remake/scripts/end/end_console.gd:48 | 3 | `IF C = 2 THEN  GOTO 110` |
| 100 | L | godot-remake/scripts/end/end_console.gd:48 | 1 | `IF C = 3 THEN  FOR J = 1 TO 5000: POKE J,0: NEXT : END` |
| 110 | P | godot-remake/scripts/rules/end_rules.gd:47 | 2 | `REM  RESTART` |
| 120 | L | godot-remake/scripts/rules/end_rules.gd:47 | 3 | `POKE 38391,77: PRINT "RUNGALAXY MAP"` |
| 190 | L | godot-remake/scripts/rules/end_rules.gd:27<br>godot-remake/scripts/rules/end_rules.gd:33 | 2 | `IF  PEEK (38210) = 1 THEN  SPEED= 128: PRINT : PRINT "YOU MUST BE IN ORBIT TO SAVE GAME": ` |
| 200 | L | godot-remake/scripts/rules/end_rules.gd:33 | 2 | `POKE 38211, PEEK (29467): POKE 38212, PEEK (29468): POKE 38213, PEEK (29469): POKE 38214, ` |
| 202 | L | godot-remake/scripts/rules/end_rules.gd:33 | 1 | `POKE 38219, PEEK (29475)` |
| 204 | L | godot-remake/scripts/rules/end_rules.gd:33 | 1 | `POKE 38391,77: POKE 38392, PEEK (38209)` |
| 210 | L | godot-remake/scripts/rules/end_rules.gd:33 | 1 | `POKE 38823, PEEK (38209): POKE 38824,1: CALL 38825: PRINT "BSAVE P/F,A$97E1,L$140": PRINT` |
| 220 | P | godot-remake/scripts/rules/end_rules.gd:33 | 1 | `RETURN` |
| 63999 | P |  | 1 | `PRINT : PRINT "INT"` |
