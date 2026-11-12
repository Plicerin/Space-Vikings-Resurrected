# SUPPLY: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

27 lines: 11 logic, 14 presentation, 2 waived. 17 lines cited by a rule; 0 of them never run in a recording.
Machine-code calls: none.

## Problems

none

## Cited, and never run in a recording (the listing alone)

none

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  | 2 | `ONERR  GOTO 63999` |
| 2 | P |  | 2 | `HIMEM: 8192` |
| 5 | P |  | 2 | `HTAB 2` |
| 10 | P |  | 2 | `POKE 32,1: POKE 33,39: POKE 34,0: POKE 35,15` |
| 18 | P |  | 2 | `HCOLOR= 1: POKE 974,64` |
| 19 | P |  | 2 | `GOSUB 5000: POKE 974,32` |
| 20 | P |  | 2 | `FOR Y = 0 TO 123: HPLOT 0,Y TO 279,Y: NEXT` |
| 1400 | L | godot-remake/scripts/flight/reports_program.gd:41 | 2 | `VTAB 1: POKE 973,255: FOR C = 1 TO 15: HTAB 2: VTAB C: PRINT "                            ` |
| 1405 | P |  | 2 | `VTAB 3` |
| 1410 | L | godot-remake/scripts/rules/report_rules.gd:90 | 2 | `PRINT "* PLATINUM ";: HTAB 19: PRINT "= "; PEEK (38181) * 10;: HTAB 24: PRINT "POUNDS": PR` |
| 1420 | L | godot-remake/scripts/rules/report_rules.gd:90 | 2 | `PRINT "* SILVER ";: HTAB 19: PRINT "= "; PEEK (38182) * 20;: HTAB 24: PRINT "POUNDS": PRIN` |
| 1430 | L | godot-remake/scripts/rules/report_rules.gd:90 | 2 | `PRINT "* COLLAPSIUM ";: HTAB 19: PRINT "= "; PEEK (38179);: HTAB 24: PRINT "TONS": PRINT "` |
| 1440 | L | godot-remake/scripts/rules/report_rules.gd:90 | 2 | `PRINT "* FISSIONABLES ";: HTAB 19: PRINT "= "; PEEK (38177);: HTAB 24: PRINT "POUNDS"` |
| 1450 | L | godot-remake/scripts/flight/reports_program.gd:41<br>godot-remake/scripts/rules/report_rules.gd:90 | 2 | `PRINT : PRINT "HIT SPACE BAR TO CONTINUE.";: GET C$` |
| 1460 | P | godot-remake/scripts/rules/report_rules.gd:90 | 2 | `R1 = 1: GOSUB 1400` |
| 1465 | P | godot-remake/scripts/rules/report_rules.gd:90 | 2 | `VTAB 3` |
| 1470 | L | godot-remake/scripts/rules/report_rules.gd:90 | 2 | `PRINT "* ELECTRONIC PARTS";: HTAB 19: PRINT "= "; PEEK (38176);: HTAB 24: PRINT "CRATES": ` |
| 1480 | L | godot-remake/scripts/rules/report_rules.gd:90 | 2 | `PRINT "* FIGHTER PARTS";: HTAB 19: PRINT "= "; PEEK (38174);: HTAB 24: PRINT "CRATES": PRI` |
| 1485 | L | godot-remake/scripts/rules/report_rules.gd:90 | 2 | `PRINT "* WINE/LIQUOR";: HTAB 19: PRINT "= "; PEEK (38172) * 100;: HTAB 24: PRINT "CASES"` |
| 1490 | L | godot-remake/scripts/rules/report_rules.gd:90<br>godot-remake/scripts/rules/report_rules.gd:99 | 2 | `PRINT "* ART WORKS";: HTAB 19: PRINT "= "; PEEK (38171) * 10;: HTAB 24: PRINT "UNITS": PRI` |
| 1500 | P | godot-remake/scripts/flight/reports_program.gd:41 | 2 | `PRINT : HTAB 9: PRINT "HIT SPACE BAR TO RETURN": HTAB 8: PRINT "(1 TO RETURN TO 1ST PAGE)"` |
| 1510 | L | godot-remake/scripts/flight/reports_program.gd:41 | 2 | `GET A$: IF A$ = "1" THEN 1400` |
| 1515 | P | godot-remake/scripts/flight/reports_program.gd:41 | 2 | `POKE 973,0` |
| 1516 | P | godot-remake/scripts/flight/reports_program.gd:41 | 2 | `POKE 974,64` |
| 1520 | P | godot-remake/scripts/flight/reports_program.gd:41 | 2 | `PRINT " ": PRINT "RUN COM"` |
| 5000 | W |  | 2 | `PRINT "OPEN MISC FILE": PRINT "READ MISC FILE": INPUT SD: INPUT TR: INPUT CR: PRINT "CL` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
