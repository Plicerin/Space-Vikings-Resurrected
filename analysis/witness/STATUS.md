# STATUS: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

60 lines: 34 logic, 23 presentation, 3 waived. 41 lines cited by a rule; 0 of them never run in a recording.
Machine-code calls: none.

## Problems

none

## Cited, and never run in a recording (the listing alone)

none

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  | 3 | `ONERR  GOTO 63999` |
| 5 | P |  | 3 | `A = 38209` |
| 10 | P |  | 3 | `VTAB 1: HTAB 2` |
| 12 | P |  | 3 | `POKE 32,1: POKE 33,39` |
| 15 | P |  | 3 | `HCOLOR= 1` |
| 20 | P |  | 3 | `FOR Y = 0 TO 123: HPLOT 0,Y TO 279,Y: NEXT` |
| 30 | P |  | 3 | `POKE 973,255` |
| 40 | P |  | 3 | `POKE 974,64` |
| 50 | P |  | 3 | `GOSUB 5000` |
| 60 | P |  | 3 | `POKE 974,32` |
| 1230 | P |  | 3 | `FOR C = 1 TO 15: VTAB C: HTAB 2: PRINT "                                      ": NEXT : VT` |
| 1232 | L | godot-remake/scripts/flight/reports_program.gd:14 | 3 | `IF R = 4 THEN R = 0: RETURN` |
| 1235 | P | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `FOR C = 1 TO  PEEK (A): READ S$: NEXT` |
| 1240 | P | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `HTAB 9: PRINT "-SHIP STATUS REPORT-": PRINT` |
| 1250 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `PRINT "LOCATION :";S$: PRINT : PRINT "STARDATE :";SD: PRINT` |
| 1255 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `EN =  PEEK (38199):EN = EN / 62:EN =  INT (EN * 100)` |
| 1256 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `IF EN > 100 THEN EN = 100` |
| 1260 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `PRINT "ENERGY  :";EN;"%"; TAB( 22);"CREDITS  :"; INT (CR)` |
| 1270 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `PRINT "SHIELDS :"; PEEK (38200);"%"; TAB( 22);"CONDITION:";` |
| 1280 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `C =  PEEK (38165)` |
| 1290 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `IF C = 1 THEN  PRINT "GREEN"` |
| 1292 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `IF C = 2 THEN  PRINT "BLUE"` |
| 1294 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `IF C = 3 THEN  PRINT "RED"` |
| 1300 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `PRINT "HULL DMG:";100 -  PEEK (38193);"%"; TAB( 22);"MISSILES :"; PEEK (38187)` |
| 1305 | P | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `GOSUB 5100` |
| 1310 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `PRINT "ENGINE#1:"; PEEK (38198);"%"; TAB( 22);"ENGINE#2 :"; PEEK (38197);"%"` |
| 1315 | L | godot-remake/scripts/flight/reports_program.gd:14 | 3 | `GET I$:R = 4: GOSUB 1230` |
| 1320 | P | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `PRINT : PRINT  TAB( 12);"-TROOP STATUS-": PRINT` |
| 1330 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `PRINT "NO. OF TROOPS"; TAB( 18);"-"; TAB( 24);TR` |
| 1340 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `PRINT "TROOP MORALE"; TAB( 18);"-"; TAB( 24);:M =  PEEK (38203)` |
| 1350 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `IF M = 1 THEN  PRINT "AWFUL!!!"` |
| 1352 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `IF M = 2 THEN  PRINT "POOR"` |
| 1354 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `IF M = 3 THEN  PRINT "SO-SO"` |
| 1356 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `IF M = 4 THEN  PRINT "FAIR"` |
| 1358 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `IF M = 5 THEN  PRINT "GOOD"` |
| 1360 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `IF M = 6 THEN  PRINT "EXCELLENT!"` |
| 1370 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `PRINT "TROOP LOCATION"; TAB( 18);"-"; TAB( 24);:L =  PEEK (38166)` |
| 1380 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `IF L = 3 THEN  PRINT "CRYOGENIC SLEEP"` |
| 1381 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `IF L = 0 THEN  PRINT "ON BOARD"` |
| 1382 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `IF L = 1 THEN  PRINT "PLANETSIDE"` |
| 1384 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `IF L = 2 THEN  PRINT "SHORE LEAVE"` |
| 1385 | P | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `GOSUB 5200` |
| 1386 | L | godot-remake/scripts/rules/report_rules.gd:84 | 3 | `IF ( PEEK (38167) * 256) +  PEEK (38159) = 0 THEN  PRINT "THE TROOPS ARE ALL DEAD!";` |
| 1390 | L | godot-remake/scripts/flight/reports_program.gd:14 | 3 | `GET A$` |
| 1395 | P |  | 3 | `PRINT " "` |
| 1396 | P |  | 3 | `POKE 973,0` |
| 1400 | L | godot-remake/scripts/flight/reports_program.gd:14 | 3 | `PRINT "RUN COM` |
| 5000 | W |  | 3 | `PRINT "OPEN MISC FILE": PRINT "READ MISC FILE": INPUT SD: INPUT TR: INPUT CR: PRINT "CL` |
| 5010 | W |  |  | `INPUT SD: INPUT TR: INPUT CR` |
| 5020 | P |  |  | `PRINT "CLOSE MISC FILE"` |
| 5030 | P |  |  | `RETURN` |
| 5100 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `PRINT "COMPUTER:"; PEEK (38196);"%";: HTAB 22: PRINT "H-DRIVE  :"; PEEK (38190);"%"` |
| 5110 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `PRINT "RADAR   :"; PEEK (38195);"%";: HTAB 22: PRINT "ENV.     :100%"` |
| 5120 | L | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `PRINT "LASER   :"; PEEK (38186);"%";: HTAB 22: PRINT "NAV.COMP.:";100;"%"` |
| 5130 | P | godot-remake/scripts/rules/report_rules.gd:52 | 3 | `RETURN` |
| 5200 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `PRINT "FIGHTERS";: HTAB 18: PRINT "-";: HTAB 24: PRINT  PEEK (38156): PRINT "TRANSPORTS";:` |
| 5210 | L | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `PRINT "TANKS";: HTAB 18: PRINT "-";: HTAB 24: PRINT  PEEK (38154): PRINT "GROUND MISSILES"` |
| 5220 | P | godot-remake/scripts/rules/report_rules.gd:69 | 3 | `RETURN` |
| 10000 | P |  | 3 | `DATA   SOL,ALPHA CENTAURI,BARNARD'S STAR,WOLF 359,LUYTEN,LALANDE 21185,SIRIUS,VARCAR,XANAD` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
