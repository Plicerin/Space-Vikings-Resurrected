# EX: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

16 lines: 2 logic, 7 presentation, 7 waived. 3 lines cited by a rule; 0 of them never run in a recording.
Machine-code calls: line 6 -> 37494, line 7 -> 37494.
No recordings are listed for this program.

## Problems

none

## Cited, and never run in a recording (the listing alone)

none

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  |  | `ONERR  GOTO 63999` |
| 2 | P |  |  | `POKE  - 16299,0` |
| 4 | P |  |  | `PRINT "BLOAD SOUND GEN,A$9276"` |
| 5 | P |  |  | `HCOLOR= 3:Y1 = 20:EN = 30841:EX = 37494` |
| 6 | W |  |  | `SCALE= 2: XDRAW 2 AT 140,65: XDRAW 15 AT 140,65: XDRAW 16 AT 140,65: XDRAW 17 AT 140,65: X` |
| 7 | W |  |  | `FOR J = 1 TO 25: CALL EX: NEXT : FOR X1 = 5 TO 130 STEP 8:Y1 = Y1 + 4.8: FOR J = 1 TO 15` |
| 20 | W |  |  | `X2 = X1 - ( RND (1) * (X1 + X1)):Y2 = Y1 - ( RND (1) * (Y1 + Y1))` |
| 21 | W |  |  | `IF Y2 > 65 THEN Y2 = 65` |
| 22 | W |  |  | `IF Y2 <  - 60 THEN Y2 =  - 60` |
| 25 | W |  |  | `HPLOT 140,60 TO 140 + X2,60 + Y2: NEXT` |
| 30 | L | godot-remake/scripts/rules/combat_rules.gd:100 |  | `NEXT : POKE 38205,0: POKE EN,127` |
| 40 | P | godot-remake/scripts/rules/combat_rules.gd:100 |  | `PRINT "BLOADDEBRIS,A30841"` |
| 56 | L | godot-remake/scripts/rules/combat_rules.gd:100 |  | `F =  PEEK (38207) / 2: POKE 38207,F` |
| 57 | P |  |  | `PRINT "BLOAD SOUND GEN,A$9276"` |
| 60 | P |  |  | `PRINT "RUN STARSHIP SIMULATOR"` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
