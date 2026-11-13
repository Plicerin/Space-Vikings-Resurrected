# SHORE LEAVE: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

105 lines: 66 logic, 36 presentation, 3 waived. 89 lines cited by a rule; 0 of them never run in a recording.
Machine-code calls: none.

## Problems

none

## Cited, and never run in a recording (the listing alone)

none

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  | 7 | `ONERR  GOTO 63999` |
| 2 | P |  | 7 | `POKE 974,32` |
| 3 | P |  | 7 | `POKE 32,1` |
| 4 | L | godot-remake/scripts/rules/shore_rules.gd:63 | 7 | `IF  PEEK (38388) = 5 THEN 10` |
| 5 | L | godot-remake/scripts/rules/shore_rules.gd:63 | 7 | `IF  PEEK (38208) = 0 THEN  PRINT "SIR! THE PLANET": PRINT "HASN'T SURRENDERED!": PRINT "R` |
| 10 | P |  | 7 | `D$ =  CHR$ (4): POKE 974,64` |
| 11 | W |  | 7 | `PRINT D$;"OPEN MISC FILE": PRINT D$;"READ MISC FILE": INPUT SD: INPUT TR: INPUT CR: PRINT ` |
| 12 | P |  | 7 | `POKE 974,32` |
| 14 | P |  | 7 | `HCOLOR= 1: HPLOT 1,1 TO 139,1 TO 139,110 TO 1,110 TO 1,1` |
| 15 | P |  | 7 | `SPEED= 125` |
| 20 | L | godot-remake/scripts/rules/shore_rules.gd:63 | 7 | `J =  PEEK (38388): POKE 38388,0: ON J GOTO 2200,2400,2500,2100,4000` |
| 2080 | P | godot-remake/scripts/rules/shore_rules.gd:73 | 7 | `SPEED= 255: VTAB 2: HTAB 2: FOR C = 2 TO 13: VTAB C: PRINT "                  ": NEXT : SP` |
| 2081 | L | godot-remake/scripts/rules/shore_rules.gd:73 | 7 | `VTAB 2: IF R = 7 THEN R = 0: RETURN` |
| 2082 | L | godot-remake/scripts/rules/shore_rules.gd:73 | 2 | `PRINT "TROOPS READY FOR": PRINT "SHORE LEAVE, SIR.": PRINT "BACK PAY COMES TO": PRINT TR;"` |
| 2085 | L | godot-remake/scripts/flight/shore_leave_program.gd:60<br>godot-remake/scripts/rules/shore_rules.gd:73 | 2 | `PRINT "PAY THEM (Y/N)?";: GET P$: IF P$ <  > "Y" AND P$ <  > "N" THEN 2085` |
| 2087 | L | godot-remake/scripts/rules/shore_rules.gd:83 | 2 | `POKE 38170,70` |
| 2088 | L | godot-remake/scripts/rules/shore_rules.gd:83 | 2 | `IF P$ = "N" THEN M =  PEEK (38203):M = M - 2: IF M < 1 THEN M = 1` |
| 2089 | L | godot-remake/scripts/rules/shore_rules.gd:83 | 2 | `IF P$ = "N" THEN  POKE 38203,M` |
| 2090 | L | godot-remake/scripts/rules/shore_rules.gd:83 | 2 | `IF P$ = "Y" AND TR > CR THEN  PRINT " ": PRINT "YOU DON'T HAVE": PRINT "ENOUGH CREDITS, SI` |
| 2093 | L | godot-remake/scripts/rules/shore_rules.gd:83 | 2 | `IF P$ = "Y" THEN M =  PEEK (38203):M = M + 1: IF M > 6 THEN M = 6` |
| 2095 | L | godot-remake/scripts/rules/shore_rules.gd:83 | 2 | `IF P$ = "Y" THEN  POKE 38203,M:CR =  INT (CR - TR)` |
| 2096 | L | godot-remake/scripts/rules/shore_rules.gd:83 | 2 | `POKE 974,64: PRINT " ": PRINT "OPEN MISC FILE": PRINT "WRITEMISC FILE": PRINT SD: PRINT ` |
| 2097 | P | godot-remake/scripts/rules/shore_rules.gd:83 | 2 | `POKE 974,32` |
| 2098 | L | godot-remake/scripts/rules/shore_rules.gd:83 | 2 | `POKE 38158, PEEK (38209): POKE 38166,2` |
| 2099 | P | godot-remake/scripts/rules/shore_rules.gd:83 | 7 | `POKE 974,64: SPEED= 255: FOR J = 1 TO 4000: NEXT : PRINT " ": PRINT "RUN GROUND FORCES"` |
| 2100 | L | godot-remake/scripts/rules/shore_rules.gd:104 | 2 | `R = 7: GOSUB 2080: GOSUB 2170: IF  PEEK (38303 +  PEEK (38209)) > 0 THEN  PRINT "THERE IS ` |
| 2105 | L | godot-remake/scripts/rules/shore_rules.gd:104 | 2 | `IF  PEEK (38282 +  PEEK (38209)) < 2 THEN  PRINT "THIS PLANET IS TOO": PRINT "BACKWARD TO ` |
| 2106 | L | godot-remake/scripts/rules/shore_rules.gd:104 | 2 | `IF  PEEK (38149) = 1 THEN  PRINT "ONLY ONE TIME PER": PRINT "TRIP, SIR.": GOTO 2099` |
| 2107 | L | godot-remake/scripts/rules/shore_rules.gd:104 | 2 | `POKE 38149,1` |
| 2110 | L | godot-remake/scripts/rules/shore_rules.gd:104 | 2 | `PRINT "SIR! IT WILL COST": PRINT  INT (C);" TO BUILD A": PRINT "BASE HERE.": PRINT : PRINT` |
| 2130 | L | godot-remake/scripts/rules/shore_rules.gd:104 | 2 | `IF CR < C THEN  PRINT "YOU DON'T HAVE": PRINT "ENOUGH CREDITS TO": PRINT "BUILD A BASE HER` |
| 2140 | L | godot-remake/scripts/flight/shore_leave_program.gd:71 | 2 | `VTAB 8: PRINT "BUILD A BASE?": PRINT "(Y/N)";: GET A$: IF A$ = "N" THEN  GOTO 2099` |
| 2150 | L | godot-remake/scripts/rules/shore_rules.gd:129 | 2 | `IF A$ <  > "Y" THEN 2140` |
| 2155 | P | godot-remake/scripts/rules/shore_rules.gd:129 | 2 | `PRINT " "` |
| 2159 | L | godot-remake/scripts/rules/shore_rules.gd:129 | 2 | `CR =  INT (CR - C)` |
| 2160 | L | godot-remake/scripts/rules/shore_rules.gd:129 | 2 | `PRINT "CONSTRUCTION IS": PRINT "UNDER WAY, SIR.": POKE 974,64: POKE 38303 +  PEEK (38209),` |
| 2170 | L | godot-remake/scripts/rules/shore_rules.gd:104 | 2 | `C = 20000 + (( RND (1) * 5000) * ( RND (1) * 10)): RETURN` |
| 2200 | P | godot-remake/scripts/rules/shore_rules.gd:139 | 2 | `R = 7: GOSUB 2080: PRINT "ENLIST TROOPS": PRINT` |
| 2210 | L | godot-remake/scripts/rules/shore_rules.gd:139 | 2 | `IF  PEEK (38389) = 1 THEN  PRINT "ONE TIME PER TRIP.": GOTO 2099` |
| 2220 | L | godot-remake/scripts/rules/shore_rules.gd:139 | 2 | `POKE 38389,1` |
| 2240 | L | godot-remake/scripts/rules/shore_rules.gd:139 | 2 | `IF  PEEK (38208) = 0 THEN  PRINT "THE PLANET HAS NOT": PRINT "SURRENDERED YET!!": GOTO 209` |
| 2250 | P | godot-remake/scripts/rules/shore_rules.gd:139<br>godot-remake/scripts/rules/shore_rules.gd:150 | 2 | `PRINT "EACH NEW TROOP": PRINT "MUST BE PAID ONE": PRINT "CREDIT IN ADVANCE."` |
| 2260 | L | godot-remake/scripts/rules/shore_rules.gd:150 | 2 | `PRINT "YOU HAVE ";CR: PRINT "CREDITS, SIR."` |
| 2270 | L | godot-remake/scripts/rules/shore_rules.gd:150 | 2 | `PRINT "TROOPS= ";TR: VTAB 10: PRINT "HOW MANY TROOPS": PRINT "DO YOU WANT TO": PRINT "ENLI` |
| 2275 | P |  | 2 | `J = 0:V = 13:H = 2: GOSUB 5000:EN = CC: VTAB 13: HTAB 2: PRINT "       "` |
| 2280 | L | godot-remake/scripts/rules/shore_rules.gd:161 | 2 | `IF EN > CR THEN  VTAB 10: PRINT "                  ": PRINT "                  ": PRINT " ` |
| 2281 | L | godot-remake/scripts/rules/shore_rules.gd:161 | 2 | `IF EN > CR THEN  VTAB 10: PRINT "                  ": PRINT "                  ": PRINT " ` |
| 2285 | L | godot-remake/scripts/rules/shore_rules.gd:161 | 2 | `IF TR + EN > 20000 THEN  VTAB 12: HTAB 2: PRINT "TOO MANY TROOPS.  ": FOR O = 1 TO 2000: N` |
| 2289 | P | godot-remake/scripts/rules/shore_rules.gd:161 | 2 | `POKE 974,64` |
| 2290 | L | godot-remake/scripts/rules/shore_rules.gd:161 | 2 | `TR = TR + EN:CR = CR - EN: GOSUB 3000: PRINT "OPEN MISC FILE": PRINT "WRITE MISC FILE": ` |
| 2291 | P |  | 2 | `POKE 974,32` |
| 2300 | P |  | 2 | `GOTO 2099` |
| 2400 | L | godot-remake/scripts/rules/shore_rules.gd:202 | 3 | `L =  PEEK (38171) * (300 *  RND (1)):L = L + ( PEEK (38172) * 150):L = L + ( PEEK (38173) ` |
| 2405 | L | godot-remake/scripts/rules/shore_rules.gd:202 | 3 | `L = L + ( PEEK (38177) * 300):L = L + ( PEEK (38178) * 15):L = L + ( PEEK (38179) * 5):L =` |
| 2406 | P | godot-remake/scripts/rules/shore_rules.gd:202 | 3 | `L = L * 2` |
| 2408 | L | godot-remake/scripts/rules/shore_rules.gd:202 | 3 | `R = 7:CR =  INT (CR):L =  INT (L)` |
| 2410 | P | godot-remake/scripts/rules/shore_rules.gd:202 | 3 | `GOSUB 2080: PRINT "   SELL LOOT": PRINT` |
| 2430 | L | godot-remake/scripts/rules/shore_rules.gd:202 | 3 | `PRINT "YOU HAD ";CR: PRINT "CREDITS.": PRINT "YOUR LOOT IS WORTH": PRINT L;" CREDITS.": PR` |
| 2460 | L | godot-remake/scripts/rules/shore_rules.gd:202 | 3 | `PRINT "THAT GIVES YOU A": PRINT "TOTAL OF ";CR + L: PRINT "CREDITS!":CR = CR + L: FOR C = ` |
| 2500 | P | godot-remake/scripts/rules/shore_rules.gd:220 | 2 | `DATA  SHIELD,38200,ENERGY,38199,# 1 ENGINE,38198,# 2 ENGINE,38197,COMPUTER,38196,RADAR,381` |
| 2502 | P | godot-remake/scripts/rules/shore_rules.gd:220 | 2 | `HCOLOR= 0: FOR J = 200 TO 260 STEP 5: DRAW 25 AT J,133: NEXT` |
| 2505 | L | godot-remake/scripts/rules/shore_rules.gd:220 | 2 | `R = 7: GOSUB 2080: IF  PEEK (38210) = 0 OR  PEEK (29469) > 22 THEN  VTAB 3: HTAB 3: PRINT ` |
| 2510 | P | godot-remake/scripts/rules/shore_rules.gd:228 | 2 | `PRINT "  REPAIR SHIP": FOR J = 1 TO 12: READ A$: READ LO` |
| 2520 | L | godot-remake/scripts/rules/shore_rules.gd:228 | 2 | `D =  PEEK (LO): IF D < 100 AND J <  > 10 AND J <  > 2 THEN  PRINT A$;":";: HTAB 13:CD =  I` |
| 2524 | L | godot-remake/scripts/rules/shore_rules.gd:228 | 2 | `IF D < 63 AND J = 2 THEN D2 = 63 - D:D2 = D2 * (100 / 63)` |
| 2525 | L | godot-remake/scripts/rules/shore_rules.gd:228 | 2 | `IF D < 63 AND J = 2 THEN D1 =  INT ((D2 / 100) * 100): PRINT A$;: HTAB 13:CD =  INT (( RND` |
| 2530 | L | godot-remake/scripts/rules/shore_rules.gd:228 | 2 | `IF D < 100 AND J = 10 THEN  PRINT A$;: HTAB 13:CD =  INT (( RND (1) * 100) * (100 -  PEEK ` |
| 2540 | P | godot-remake/scripts/rules/shore_rules.gd:228 | 2 | `NEXT : FOR J = 1 TO 4000: NEXT` |
| 2545 | P | godot-remake/scripts/rules/shore_rules.gd:228 | 2 | `HCOLOR= 1: FOR J = 153 TO 157: HPLOT 262,J TO 271,J: NEXT` |
| 2550 | P | godot-remake/scripts/rules/shore_rules.gd:228<br>godot-remake/scripts/rules/shore_rules.gd:256 | 2 | `R = 7: GOSUB 2080: PRINT "  REPAIR SHIP": PRINT : PRINT "ALL REPAIRS ARE": PRINT "COMPLETE` |
| 2555 | L | godot-remake/scripts/rules/shore_rules.gd:228<br>godot-remake/scripts/rules/shore_rules.gd:256 | 2 | `CR =  INT (CR): POKE 38393,0` |
| 2560 | L | godot-remake/scripts/rules/shore_rules.gd:256 | 2 | `PRINT "THE TOTAL REPAIR": PRINT "BILL COMES TO": PRINT P;" CREDITS.": PRINT "YOU HAVE ";CR` |
| 2580 | L | godot-remake/scripts/rules/shore_rules.gd:267 | 2 | `PRINT "ARE YOU GOING TO": PRINT "PAY, SIR? (Y/N) ";: GET N$: IF N$ = "N" AND P > 0 THEN  P` |
| 2590 | L | godot-remake/scripts/rules/shore_rules.gd:267 | 2 | `CR =  INT (CR - P): GOTO 2615` |
| 2600 | L | godot-remake/scripts/rules/shore_rules.gd:267 | 1 | `R = 7: GOSUB 2080: IF N$ = "N" THEN 2605` |
| 2602 | L | godot-remake/scripts/rules/shore_rules.gd:267 | 1 | `PRINT "YOU DON'T HAVE": PRINT "ENOUGH CREDITS!": PRINT "YOU HAVE 0 CREDITS": PRINT "LEFT!"` |
| 2605 | P | godot-remake/scripts/rules/shore_rules.gd:267 | 1 | `PRINT "I'M AFRAID YOU'VE": PRINT "MADE THE LOCAL": PRINT "GOVERNMENT ANGRY!": FOR J = 1 TO` |
| 2610 | L | godot-remake/scripts/rules/shore_rules.gd:267 | 1 | `POKE 38208,0: POKE 38219 +  PEEK (38209),0` |
| 2615 | P |  | 2 | `POKE 974,64` |
| 2620 | W |  | 2 | `VTAB 2: PRINT " ": SPEED= 255: PRINT "OPEN MISC FILE": PRINT "WRITE MISC FILE": PRINT SD` |
| 3000 | P | godot-remake/scripts/rules/shore_rules.gd:173 | 2 | `A$(1) = "FIGHTERS":A$(2) = "TRANSPORTS":A$(3) = "TANKS":A$(4) = "MISSILES":MU(1) = 50:MU(2` |
| 3010 | P | godot-remake/scripts/rules/shore_rules.gd:173 | 2 | `FOR J1 = 0 TO 3: SPEED= 255` |
| 3012 | P | godot-remake/scripts/rules/shore_rules.gd:173 | 2 | `POKE 974,32` |
| 3020 | L | godot-remake/scripts/rules/shore_rules.gd:173 | 2 | `R = 7: GOSUB 2080: PRINT " BUY WEAPONS": PRINT : PRINT "CREDITS:";: HTAB 13: PRINT CR: FOR` |
| 3050 | P | godot-remake/scripts/rules/shore_rules.gd:173 | 2 | `PRINT A$(J + 1);":";: HTAB 16: PRINT A` |
| 3055 | L | godot-remake/scripts/rules/shore_rules.gd:173 | 2 | `IF PL = 7 THEN PL = 7: NEXT :PL = 0: RETURN` |
| 3060 | L | godot-remake/scripts/rules/shore_rules.gd:173 | 2 | `NEXT : PRINT "..................":C =  INT (( RND (1) + .2) * 4 * MU(J1 + 1)): VTAB 10: PR` |
| 3070 | L | godot-remake/scripts/rules/shore_rules.gd:185 | 2 | `JJ = J:J = 0: VTAB 11: PRINT "BUY HOW MANY? ":V = 12:H = 2: GOSUB 5000:B = CC: IF B < 0 OR` |
| 3072 | L | godot-remake/scripts/rules/shore_rules.gd:185 | 2 | `IF B +  PEEK (LO - J1) > 255 THEN  VTAB 11: PRINT "                  ": VTAB 11: SPEED= 12` |
| 3090 | L | godot-remake/scripts/rules/shore_rules.gd:185 | 2 | `IF B * C > CR THEN  VTAB 11: PRINT "                 ": VTAB 11: PRINT "NOT ENOUGH CREDITS` |
| 3100 | L | godot-remake/scripts/rules/shore_rules.gd:185 | 2 | `CR =  INT (CR - (B * C)):C =  PEEK (LO - J1) + B: IF C > 255 THEN C = 255` |
| 3110 | P | godot-remake/scripts/rules/shore_rules.gd:185 | 2 | `POKE LO - J1,C: NEXT :PL = 7: SPEED= 255: GOSUB 3020: RETURN` |
| 4000 | L | godot-remake/scripts/rules/shore_rules.gd:292 | 1 | `R = 7: GOSUB 2080: VTAB 4: IF  PEEK (38166) = 1 OR  PEEK (38166) = 2 THEN  PRINT "TROOPS N` |
| 4010 | L | godot-remake/scripts/rules/shore_rules.gd:292 | 1 | `IF  PEEK (38166) = 3 THEN  PRINT "TROOPS ARE BEING": PRINT "REVIVED, SIR.": POKE 38166,0: ` |
| 4020 | L | godot-remake/scripts/rules/shore_rules.gd:292 | 1 | `PRINT "TROOPS ARE BEING": PRINT "PUT IN CRYOGENICS": POKE 38166,3: GOTO 2099` |
| 5000 | L | godot-remake/scripts/flight/shore_leave_program.gd:91 | 2 | `HTAB H + J: VTAB V: GET C$: IF C$ <  >  CHR$ (8) THEN J = J + 1` |
| 5001 | L | godot-remake/scripts/flight/shore_leave_program.gd:91 | 2 | `IF C$ =  CHR$ (8) THEN J = J - 1: IF J < 0 THEN J = 0` |
| 5002 | L | godot-remake/scripts/flight/shore_leave_program.gd:91 | 2 | `IF C$ =  CHR$ (8) THEN  VTAB V: HTAB H + J: PRINT "  ";: IF J = 0 THEN C1$ = "": VTAB V: G` |
| 5003 | L | godot-remake/scripts/flight/shore_leave_program.gd:91 | 2 | `IF C$ =  CHR$ (8) AND J > 0 THEN C1$ =  LEFT$ (C1$,J): VTAB V: GOTO 5000` |
| 5004 | L | godot-remake/scripts/flight/shore_leave_program.gd:91 | 2 | `IF C$ =  CHR$ (13) THEN 5010` |
| 5006 | P | godot-remake/scripts/flight/shore_leave_program.gd:91 | 2 | `VTAB V: HTAB H + J - 1: PRINT C$;:C1$ = C1$ + C$: GOTO 5000` |
| 5010 | P | godot-remake/scripts/flight/shore_leave_program.gd:91 | 2 | `CC =  VAL (C1$):C1$ = ""` |
| 5015 | P |  | 2 | `J = JJ` |
| 5020 | P |  | 2 | `PRINT : RETURN` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
