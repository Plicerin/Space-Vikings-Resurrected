# S_X: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

16 lines: 1 logic, 7 presentation, 8 waived. 3 lines cited by a rule; 0 of them never run in a recording.
Machine-code calls: line 6 -> 37494.
No recordings are listed for this program.

## Problems

none

## Cited, and never run in a recording (the listing alone)

none

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  |  | `ONERR  GOTO 63999` |
| 2 | P |  |  | `POKE  - 16300,0` |
| 3 | P |  |  | `PRINT "BLOAD EXPL"` |
| 4 | P |  |  | `EX = 37494: POKE 974,32` |
| 5 | P |  |  | `HCOLOR= 0:Y1 = 20: POKE 973,255: PRINT ""` |
| 6 | W |  |  | `FOR J = 1 TO 500: CALL EX: NEXT` |
| 7 | W |  |  | `FOR X1 = 5 TO 130 STEP 8:Y1 = Y1 + 4.8: FOR J = 1 TO 15` |
| 20 | W |  |  | `X2 = X1 - ( RND (1) * (X1 + X1)):Y2 = Y1 - ( RND (1) * (Y1 + Y1))` |
| 21 | W |  |  | `IF Y2 > 65 THEN Y2 = 65` |
| 22 | W |  |  | `IF Y2 <  - 60 THEN Y2 =  - 60` |
| 25 | W |  |  | `HPLOT 140,60 TO 140 + X2,60 + Y2: NEXT` |
| 30 | W |  |  | `NEXT` |
| 40 | P | godot-remake/scripts/flight/native_flight.gd:216 |  | `VTAB 22: HTAB 5: SPEED= 127: PRINT "YOUR SHIP HAS BEEN DESTROYED!!"` |
| 50 | L | godot-remake/scripts/flight/native_flight.gd:216 |  | `GET A$: GET A$: PRINT " ": PRINT "PR#6"` |
| 70 | P | godot-remake/scripts/flight/native_flight.gd:216 |  | `END` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
