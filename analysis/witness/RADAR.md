# RADAR: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

27 lines: 7 logic, 15 presentation, 5 waived. 18 lines cited by a rule; 1 of them never run in a recording.
Machine-code calls: line 2005 -> 24576, line 2005 -> 37936.

## Problems

none

## Cited, and never run in a recording (the listing alone)

2059

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  | 3 | `ONERR  GOTO 63999` |
| 1 | P |  | 3 | `HIMEM: 8192:XI = 29467:YI = 29469:ZI = 29471:P1 = 29473:B1 = 29474:H1 = 29475:CSN = 24582:` |
| 10 | L | godot-remake/scripts/flight/vector_radar.gd:42<br>godot-remake/scripts/rules/radar_rules.gd:26 | 3 | `IF  PEEK (38195) = 0 THEN 2058` |
| 1500 | P |  | 3 | `L(1) =  PEEK (YI):H(1) =  PEEK (YI + 1)` |
| 2000 | P | godot-remake/scripts/flight/vector_radar.gd:174 | 3 | `P(1) =  PEEK (P1): POKE P1,63:BV% = 20000: GOSUB 6000: POKE YI,LO%: POKE YI + 1,HI%:B(1) =` |
| 2005 | L | godot-remake/scripts/flight/vector_radar.gd:174 | 3 | `POKE 29463,0: POKE 29465,0: POKE 974,32: CALL 24576: CALL 37936: POKE  - 16300,0: HCOLOR= ` |
| 2010 | P | godot-remake/scripts/flight/vector_radar.gd:174 | 3 | `VTAB 24: HTAB 1: PRINT "                  ";: HTAB 26: PRINT "             ";` |
| 2032 | P | godot-remake/scripts/flight/vector_radar.gd:174 | 3 | `HPLOT 277,0 TO 277,123` |
| 2033 | P | godot-remake/scripts/flight/vector_radar.gd:174 | 3 | `HPLOT 1,0 TO 131,59: HPLOT 279,0 TO 151,59: HPLOT 151,67 TO 279,123: HPLOT 1,123 TO 131,67` |
| 2040 | P | godot-remake/scripts/flight/vector_radar.gd:174 | 3 | `HPLOT 140,1 TO 140,55: HPLOT 140,71 TO 140,123: HPLOT 1,63 TO 131,63: HPLOT 151,63 TO 279,` |
| 2042 | P | godot-remake/scripts/flight/vector_radar.gd:174 | 3 | `HCOLOR= 1: HPLOT 137,60 TO 137,66 TO 145,66 TO 145,60 TO 137,60: HPLOT 141,63` |
| 2045 | P |  | 3 | `P = P(1): POKE P1,P:B = B(1): POKE B1,B` |
| 2050 | L | godot-remake/scripts/flight/vector_radar.gd:59 | 3 | `GET A$` |
| 2052 | P | godot-remake/scripts/flight/vector_radar.gd:59 | 2 | `VTAB 1: HTAB 1` |
| 2055 | P | godot-remake/scripts/flight/vector_radar.gd:59 | 2 | `POKE YI,L(1): POKE YI + 1,H(1)` |
| 2056 | L | godot-remake/scripts/flight/vector_radar.gd:59<br>godot-remake/scripts/flight/vector_radar.gd:60<br>godot-remake/scripts/rules/radar_rules.gd:48 | 2 | `IF A$ <  > "X" THEN 5000` |
| 2057 | P | godot-remake/scripts/flight/vector_radar.gd:60<br>godot-remake/scripts/rules/radar_rules.gd:48 | 1 | `HCOLOR= 0: FOR X = 200 TO 260 STEP 5: DRAW 25 AT X,133: NEXT : FOR X = 13 TO 73 STEP 5: DR` |
| 2058 | L | godot-remake/scripts/flight/vector_radar.gd:60<br>godot-remake/scripts/rules/radar_rules.gd:48 | 1 | `POKE 974,64: IF  PEEK (38388) > 0 THEN  POKE 38388,0: PRINT " ": PRINT "RUN COM"` |
| 2059 | P | godot-remake/scripts/flight/vector_radar.gd:60<br>godot-remake/scripts/rules/radar_rules.gd:48 |  | `FOR J = 1 TO 16: VTAB J: HTAB 1: PRINT "                                        ": NEXT : ` |
| 5000 | P | godot-remake/scripts/flight/vector_radar.gd:61<br>godot-remake/scripts/rules/radar_rules.gd:32 | 2 | `POKE 974,64: PRINT " "` |
| 5002 | L | godot-remake/scripts/flight/vector_radar.gd:61<br>godot-remake/scripts/rules/radar_rules.gd:32 | 2 | `IF  PEEK (38205) = 2 THEN  PRINT "RUN SHIP # 3 I.D."` |
| 5005 | L | godot-remake/scripts/flight/vector_radar.gd:61<br>godot-remake/scripts/rules/radar_rules.gd:32 | 2 | `J =  PEEK (38205): POKE 38151,5: PRINT "RUN SHIP # ";J;" I.D."` |
| 6000 | W |  | 3 | `HI% = BV% / 256: IF BV% < 0 THEN HI% = HI% + 1` |
| 6010 | W |  | 3 | `LO% = BV% - HI% * 256: IF BV% >  - 1 THEN  RETURN` |
| 6030 | W |  |  | `HI% = 255 + HI%:LO% = 256 + LO%: IF LO% < 256 THEN  RETURN` |
| 6060 | W |  |  | `HI% = HI% + 1:LO% = 0: RETURN` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
