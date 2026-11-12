# H_D: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

57 lines: 24 logic, 22 presentation, 11 waived. 40 lines cited by a rule; 0 of them never run in a recording.
Machine-code calls: line 12 -> 38825, line 18 -> 37494, line 18 -> 37494, line 20 -> 37494, line 25 -> 38825.
No recordings are listed for this program.

## Problems

none

## Cited, and never run in a recording (the listing alone)

none

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  |  | `ONERR  GOTO 63999` |
| 1 | L | godot-remake/scripts/flight/native_flight.gd:358<br>godot-remake/scripts/rules/hyperdrive_rules.gd:19 |  | `POKE  - 16300,0: POKE 38392,0: IF  PEEK (38210) = 1 OR  PEEK (38209) =  PEEK (38163) OR  P` |
| 2 | L | godot-remake/scripts/flight/native_flight.gd:358<br>godot-remake/scripts/rules/hyperdrive_rules.gd:27 |  | `IF  PEEK (38199) <  > 0 THEN 5` |
| 3 | P | godot-remake/scripts/flight/native_flight.gd:358<br>godot-remake/scripts/rules/hyperdrive_rules.gd:27 |  | `POKE  - 16300,0: POKE 974,32: SPEED= 100: HTAB 15: VTAB 15: PRINT "OUT OF ENERGY": FOR I =` |
| 4 | P | godot-remake/scripts/flight/native_flight.gd:358<br>godot-remake/scripts/rules/hyperdrive_rules.gd:27 |  | `PRINT "RUN S/X"` |
| 5 | P | godot-remake/scripts/flight/native_flight.gd:358<br>godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `GOSUB 10000: POKE 974,64: POKE 301,0` |
| 6 | L | godot-remake/scripts/flight/native_flight.gd:358<br>godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `PRINT "OPEN MISC FILE": PRINT "READ MISC FILE": INPUT SD: INPUT TR: INPUT CR: PRINT "CL` |
| 7 | P | godot-remake/scripts/flight/native_flight.gd:358<br>godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `HCOLOR= 0: POKE 974,32` |
| 8 | P | godot-remake/scripts/flight/native_flight.gd:358<br>godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `NOISE = 37494: PRINT "BLOADEXPL": FOR X = 200 TO 260 STEP 5: DRAW 25 AT X,133: NEXT : FOR` |
| 11 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `IF  PEEK (38166) = 0 OR  PEEK (38166) = 3 THEN  POKE 38158, PEEK (38163)` |
| 12 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `POKE 38823, PEEK (38209): POKE 38824,1: CALL 38825: IF  PEEK (38170) = 17 THEN PL =  PEEK ` |
| 13 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `IF LP = 7 THEN  POKE 38203,PL: POKE 38170,0` |
| 14 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `D$ =  CHR$ (4):C1 = 140:C2 = 63: HCOLOR= 3:X1 = 29467:Y1 = 29469:Z1 = 29471:A1 = 974:A2 = ` |
| 15 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `POKE 38199,P: POKE 973,0` |
| 16 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `POKE 974,32: POKE 38152,0: POKE 38240 +  PEEK (38163),1` |
| 17 | P | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `FOR L = 1 TO 16: VTAB L: PRINT "                                        ": NEXT : VTAB 1` |
| 18 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `CALL NOISE: FOR J = 1 TO 250: CALL NOISE: NEXT` |
| 20 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `FOR H = 1 TO 175:C3 =  RND (1) * 279:C4 =  RND (1) * 125: CALL NOISE: HPLOT C1,C2 TO C3,C4` |
| 25 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `POKE 38823, PEEK (38163): POKE 38824,0: CALL 38825` |
| 26 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `POKE 38209, PEEK (38163)` |
| 30 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `IF  PEEK (38282 +  PEEK (38209)) > 1 AND  PEEK (38205) = 0 THEN  PRINT "BLOADDEBRIS,A3084` |
| 37 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `ET =  PEEK (38205): IF ET = 0 THEN  POKE 30841,127: GOTO 50` |
| 38 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `IF ET = 2 THEN  PRINT "BLOAD SHIP # 3,A30841": GOTO 50` |
| 40 | P | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `PRINT "BLOAD SHIP # ";ET;",A30841"` |
| 50 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `BV% = (10000 - ( RND (1) * 20000)): GOSUB 6000: POKE X1,LO%: POKE X1 + 1,HI%` |
| 60 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `BV% = (5000 - ( RND (1) * 10000)): GOSUB 6000: POKE Y1,LO%: POKE Y1 + 1,HI%` |
| 70 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `BV% = (10000 - ( RND (1) * 20000)): IF  ABS (BV%) < 7000 THEN 70` |
| 71 | P | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `GOSUB 6000` |
| 72 | P | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `POKE Z1,LO%: POKE Z1 + 1,HI%` |
| 73 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `A =  RND (1) * 255` |
| 75 | P | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `POKE P1,0: POKE H1,A: POKE B1,0` |
| 76 | P | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `HCOLOR= 0` |
| 80 | P |  |  | `R = 2: GOTO 20` |
| 90 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `TECH =  PEEK (38282 +  PEEK (38209)): IF TECH < 2 THEN  POKE 38150,0` |
| 92 | P | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `REM` |
| 93 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `IF TECH > 1 THEN  POKE 38150,TECH * 60: POKE 38204,TECH * 60: POKE 38160,0: POKE 38161,0` |
| 95 | P | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `REM` |
| 100 | P | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `PRINT "BLOAD SOUND GEN,A$9276"` |
| 105 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:41 |  | `POKE 38206,0: POKE 38389,0: POKE 38149,0` |
| 110 | P |  |  | `COLOR= 15: FOR J = 0 TO 47: HLIN 0,39 AT J: NEXT` |
| 1100 | P |  |  | `PRINT D$;"RUN STARSHIP SIMULATOR"` |
| 1200 | P |  |  | `END` |
| 6000 | W |  |  | `HI% = BV% / 256` |
| 6005 | W |  |  | `IF BV% < 0 THEN HI% = HI% + 1` |
| 6010 | W |  |  | `LO% = BV% - HI% * 256` |
| 6020 | W |  |  | `IF BV% >  - 1 THEN  RETURN` |
| 6030 | W |  |  | `HI% = 255 + HI%` |
| 6040 | W |  |  | `LO% = 256 + LO%` |
| 6050 | W |  |  | `IF LO% < 256 THEN  RETURN` |
| 6060 | W |  |  | `HI% = HI% + 1` |
| 6070 | W |  |  | `LO% = 0` |
| 6080 | W |  |  | `RETURN` |
| 10000 | P | godot-remake/scripts/rules/hyperdrive_rules.gd:33 |  | `REM  DISTANCE` |
| 10010 | L | godot-remake/scripts/rules/hyperdrive_rules.gd:33 |  | `X1 =  ABS ( PEEK (38366 +  PEEK (38209))) -  ABS ( PEEK (38366 +  PEEK (38163))):Y1 =  ABS` |
| 10020 | P | godot-remake/scripts/rules/hyperdrive_rules.gd:33 |  | `D1 =  INT ( SQR (X1 ^ 2 + Y1 ^ 2 + Z1 ^ 2) + .6): RETURN` |
| 10030 | P |  |  | `POKE  - 16299,0: PRINT "DIST";D1: FOR I = 1 TO 5000: NEXT : RETURN` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
