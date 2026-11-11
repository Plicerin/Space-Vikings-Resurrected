# RE: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

18 lines: 2 logic, 15 presentation, 1 waived. 12 lines cited by a rule; 0 of them never run in a recording.
Machine-code calls: none.
No recordings are listed for this program.

## Problems

none

## Cited, and never run in a recording (the listing alone)

none

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  |  | `ONERR  GOTO 63999` |
| 1 | P |  |  | `HIMEM: 8192:XI = 29467:YI = 29469:ZI = 29471:P1 = 29473:B1 = 29474:H1 = 29475:CSN = 24582:` |
| 2 | P |  |  | `HCOLOR= 0: FOR X = 200 TO 260 STEP 5: DRAW 25 AT X,133: NEXT : FOR X = 13 TO 73 STEP 5: DR` |
| 5 | P |  |  | `POKE  - 16300,0: POKE 974,32: POKE 973,255` |
| 10 | P |  |  | `HCOLOR= 5: FOR Y = 0 TO 125: HPLOT 0,Y TO 279,Y: NEXT` |
| 20 | P | godot-remake/scripts/flight/native_flight.gd:265 |  | `VTAB 7: HTAB 10: PRINT "                      ": HTAB 10: PRINT "REENTRY SEQUENCE START": ` |
| 21 | P | godot-remake/scripts/flight/native_flight.gd:265 |  | `HCOLOR= 3: POKE 974,64` |
| 22 | P | godot-remake/scripts/flight/native_flight.gd:265 |  | `FOR J = 153 TO 157: HPLOT 200,J TO 209,J: NEXT` |
| 25 | L | godot-remake/scripts/flight/native_flight.gd:265<br>godot-remake/scripts/rules/flight_rules.gd:123 |  | `POKE 38210,1` |
| 26 | P | godot-remake/scripts/flight/native_flight.gd:265<br>godot-remake/scripts/rules/flight_rules.gd:123 |  | `POKE 973,0` |
| 27 | P | godot-remake/scripts/flight/native_flight.gd:265<br>godot-remake/scripts/rules/flight_rules.gd:123 |  | `X1 =  PEEK (XI):X2 =  PEEK (XI + 1):Y1 = 208:Y2 = 7:Z1 =  PEEK (ZI):Z2 =  PEEK (ZI + 1)` |
| 28 | P | godot-remake/scripts/flight/native_flight.gd:265<br>godot-remake/scripts/rules/flight_rules.gd:123 |  | `P =  PEEK (P1):B =  PEEK (B1):H = 20` |
| 29 | P | godot-remake/scripts/flight/native_flight.gd:265<br>godot-remake/scripts/rules/flight_rules.gd:123 |  | `X1 = 188:Y1 = 0:Y2 = 4:Z1 = 168:Z2 = 228` |
| 30 | L | godot-remake/scripts/flight/native_flight.gd:265<br>godot-remake/scripts/rules/flight_rules.gd:123 |  | `PRINT " ": PRINT "BLOAD PLANET # "; PEEK (38209);",A29440"` |
| 35 | P | godot-remake/scripts/flight/native_flight.gd:265<br>godot-remake/scripts/rules/flight_rules.gd:123 |  | `POKE XI,X1: POKE XI + 1,X2: POKE YI,Y1: POKE YI + 1,Y2: POKE ZI,Z1: POKE ZI + 1,Z2` |
| 37 | P | godot-remake/scripts/flight/native_flight.gd:265<br>godot-remake/scripts/rules/flight_rules.gd:123 |  | `POKE P1,P: POKE B1,B: POKE H1,H` |
| 40 | P | godot-remake/scripts/flight/native_flight.gd:265 |  | `PRINT " ": PRINT "RUN STARSHIP SIMULATOR"` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
