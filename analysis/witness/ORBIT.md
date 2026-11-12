# ORBIT: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

20 lines: 3 logic, 16 presentation, 1 waived. 14 lines cited by a rule; 0 of them never run in a recording.
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
| 2 | P |  |  | `POKE 974,32: FOR X = 200 TO 260 STEP 5: DRAW 25 AT X,133: NEXT : FOR X = 13 TO 73 STEP 5: ` |
| 5 | P |  |  | `POKE  - 16300,0: POKE 974,32: POKE 973,255` |
| 10 | P |  |  | `HCOLOR= 6: FOR Y = 0 TO 125: HPLOT 0,Y TO 279,Y: NEXT` |
| 20 | P | godot-remake/scripts/flight/native_flight.gd:398 |  | `VTAB 7: HTAB 10: PRINT "                       ": HTAB 10: PRINT "ORBITAL INSERTION START"` |
| 21 | P | godot-remake/scripts/flight/native_flight.gd:398 |  | `HCOLOR= 1: POKE 974,64` |
| 22 | P | godot-remake/scripts/flight/native_flight.gd:398 |  | `FOR J = 153 TO 157: HPLOT 200,J TO 209,J: NEXT` |
| 25 | L | godot-remake/scripts/flight/native_flight.gd:398<br>godot-remake/scripts/rules/flight_rules.gd:136 |  | `POKE 38210,0` |
| 26 | P | godot-remake/scripts/flight/native_flight.gd:398<br>godot-remake/scripts/rules/flight_rules.gd:136 |  | `POKE 973,0` |
| 27 | P | godot-remake/scripts/flight/native_flight.gd:398<br>godot-remake/scripts/rules/flight_rules.gd:136 |  | `X1 = 188:X2 = 2:Y1 = 200:Y2 = 0:Z1 = 208:Z2 = 7` |
| 28 | P | godot-remake/scripts/flight/native_flight.gd:398<br>godot-remake/scripts/rules/flight_rules.gd:136 |  | `P =  PEEK (P1):B =  PEEK (B1):H =  PEEK (H1)` |
| 29 | P | godot-remake/scripts/flight/native_flight.gd:398<br>godot-remake/scripts/rules/flight_rules.gd:136 |  | `H = 190` |
| 30 | L | godot-remake/scripts/flight/native_flight.gd:398<br>godot-remake/scripts/rules/flight_rules.gd:136 |  | `PRINT " ": PRINT "BLOAD PLANET # 0,A29440": IF  PEEK (38205) = 0 THEN 35` |
| 31 | L | godot-remake/scripts/flight/native_flight.gd:398<br>godot-remake/scripts/rules/flight_rules.gd:136 |  | `J =  PEEK (38205): IF J = 2 THEN J = 3` |
| 32 | P | godot-remake/scripts/flight/native_flight.gd:398<br>godot-remake/scripts/rules/flight_rules.gd:136 |  | `PRINT "BLOAD SHIP # ";J;",A30841"` |
| 35 | P | godot-remake/scripts/flight/native_flight.gd:398<br>godot-remake/scripts/rules/flight_rules.gd:136 |  | `POKE XI,X1: POKE XI + 1,X2: POKE YI,Y1: POKE YI + 1,Y2: POKE ZI,Z1: POKE ZI + 1,Z2` |
| 37 | P | godot-remake/scripts/flight/native_flight.gd:398<br>godot-remake/scripts/rules/flight_rules.gd:136 |  | `POKE P1,P: POKE B1,B: POKE H1,H` |
| 40 | P | godot-remake/scripts/flight/native_flight.gd:398 |  | `PRINT " ": PRINT "RUN STARSHIP SIMULATOR"` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
