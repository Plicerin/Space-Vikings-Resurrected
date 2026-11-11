# GALAXY MAP: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

69 lines: 15 logic, 20 presentation, 34 waived. 38 lines cited by a rule; 0 of them never run in a recording.
Machine-code calls: none.

## Problems

none

## Cited, and never run in a recording (the listing alone)

none

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  | 1 | `ONERR  GOTO 63999` |
| 1 | L | godot-remake/scripts/chart/star_chart.gd:133 | 1 | `IF  PEEK (38391) = 77 AND  PEEK (38388) = 7 THEN  POKE 38391,0: POKE 38388,0: GOSUB 5000: ` |
| 2 | W |  | 1 | `IF  PEEK (38391) = 77 THEN  POKE 38391,0: GOSUB 5000: POKE  - 16300,0: PRINT "RUN STARSHI` |
| 5 | W |  | 1 | `DIM V(24),H(24),S$(20),X(20),Y(20),Z(20): POKE 974,32: POKE  - 16300,0: GOSUB 15100` |
| 3000 | W | godot-remake/scripts/chart/star_chart.gd:141 | 1 | `POKE 32,0: POKE 33,39: POKE 34,19: POKE 35,23: PRINT "": HTAB 1: VTAB 20` |
| 3002 | W | godot-remake/scripts/chart/star_chart.gd:141 | 1 | `POKE 32,1` |
| 3010 | P | godot-remake/scripts/chart/star_chart.gd:141 | 1 | `HCOLOR= 1: HPLOT 1,1 TO 1,190 TO 279,190 TO 279,1 TO 1,1:M = 38366` |
| 3020 | P | godot-remake/scripts/chart/star_chart.gd:141<br>godot-remake/scripts/rules/chart_rules.gd:52 | 1 | `FOR P = 1 TO 20:X(P) =  PEEK (M + P):Y(P) =  PEEK ((M + P) - 21):Z(P) =  PEEK ((M + P) - 4` |
| 3025 | P | godot-remake/scripts/chart/star_chart.gd:141 | 1 | `FOR P = 1 TO 20: HCOLOR= 3` |
| 3030 | L | godot-remake/scripts/chart/star_chart.gd:141<br>godot-remake/scripts/rules/chart_rules.gd:52 | 1 | `IF Z(P) < 12 THEN PL = 6` |
| 3040 | L | godot-remake/scripts/chart/star_chart.gd:141<br>godot-remake/scripts/rules/chart_rules.gd:52 | 1 | `IF Z(P) > 11 AND Z(P) < 16 THEN PL = 5` |
| 3050 | L | godot-remake/scripts/chart/star_chart.gd:141<br>godot-remake/scripts/rules/chart_rules.gd:52 | 1 | `IF Z(P) > 15 THEN PL = 1` |
| 3060 | P | godot-remake/scripts/chart/star_chart.gd:141<br>godot-remake/scripts/rules/chart_rules.gd:63 | 1 | `X = X(P) * 10:Y = Y(P) * 5` |
| 3065 | P | godot-remake/scripts/chart/star_chart.gd:141<br>godot-remake/scripts/rules/chart_rules.gd:63 | 1 | `X = X - 35` |
| 3066 | L | godot-remake/scripts/chart/star_chart.gd:141<br>godot-remake/scripts/rules/chart_rules.gd:69 | 1 | `IF  PEEK (38219 + P) = 1 THEN  HCOLOR= 2` |
| 3070 | P | godot-remake/scripts/chart/star_chart.gd:141 | 1 | `DRAW PL AT X,Y` |
| 3075 | L | godot-remake/scripts/chart/star_chart.gd:141<br>godot-remake/scripts/rules/chart_rules.gd:75 | 1 | `IF P =  PEEK (38209) THEN  HCOLOR= 2: HPLOT X - 5,Y + 5 TO X + 5,Y + 5 TO X + 5,Y - 5 TO X` |
| 3080 | P | godot-remake/scripts/chart/star_chart.gd:141 | 1 | `NEXT P` |
| 3090 | P | godot-remake/scripts/chart/star_chart.gd:141 | 1 | `HCOLOR= 5: HPLOT 1,150 TO 279,150` |
| 3096 | W | godot-remake/scripts/chart/star_chart.gd:141 | 1 | `SCALE= 1` |
| 3100 | W | godot-remake/scripts/chart/star_chart.gd:141 | 1 | `HTAB 15: PRINT "GALAXY MAP": HTAB 8: PRINT "--PRESS SPACE TO RETURN--"` |
| 3110 | L | godot-remake/scripts/chart/star_chart.gd:81<br>godot-remake/scripts/rules/chart_rules.gd:81<br>godot-remake/scripts/rules/chart_rules.gd:90 | 1 | `PX =  PDL (0) * 1.19:PY =  PDL (1): IF PY > 145 THEN PY = 145` |
| 3115 | L | godot-remake/scripts/chart/star_chart.gd:81<br>godot-remake/scripts/rules/chart_rules.gd:81<br>godot-remake/scripts/rules/chart_rules.gd:90 | 1 | `IF PX < 10 THEN PX = 10` |
| 3116 | L | godot-remake/scripts/chart/star_chart.gd:81<br>godot-remake/scripts/rules/chart_rules.gd:81<br>godot-remake/scripts/rules/chart_rules.gd:90 | 1 | `IF PX > 270 THEN PX = 270` |
| 3117 | L | godot-remake/scripts/chart/star_chart.gd:81<br>godot-remake/scripts/rules/chart_rules.gd:81<br>godot-remake/scripts/rules/chart_rules.gd:90 | 1 | `IF PY < 10 THEN PY = 10` |
| 3120 | P | godot-remake/scripts/chart/star_chart.gd:81 | 1 | `XDRAW 12 AT PX,PY` |
| 3125 | L | godot-remake/scripts/chart/star_chart.gd:133<br>godot-remake/scripts/chart/star_chart.gd:81 | 1 | `IF  PEEK ( - 16384) > 127 THEN  POKE  - 16368,0: POKE 38391,77: POKE 38388,7: PRINT "RUN ` |
| 3130 | L | godot-remake/scripts/chart/star_chart.gd:81 | 1 | `IF  PEEK ( - 16287) > 127 THEN 3210` |
| 3200 | P |  | 1 | `XDRAW 12 AT PX,PY: GOTO 3110` |
| 3210 | P | godot-remake/scripts/chart/star_chart.gd:98 | 1 | `HCOLOR= 0: DRAW 12 AT PX,PY` |
| 3215 | P | godot-remake/scripts/chart/star_chart.gd:98<br>godot-remake/scripts/rules/chart_rules.gd:96 | 1 | `PX = PX + 35` |
| 3220 | P | godot-remake/scripts/chart/star_chart.gd:98<br>godot-remake/scripts/rules/chart_rules.gd:96 | 1 | `FOR P = 1 TO 20` |
| 3230 | L | godot-remake/scripts/chart/star_chart.gd:98<br>godot-remake/scripts/rules/chart_rules.gd:96 | 1 | `IF  INT (PX / 10) <  = X(P) + 1 AND  INT (PX / 10) >  = X(P) - 1 AND  INT (PY / 5) <  = Y(` |
| 3240 | P | godot-remake/scripts/chart/star_chart.gd:98<br>godot-remake/scripts/rules/chart_rules.gd:96 | 1 | `NEXT P: SPEED= 127: PRINT "THERE IS NO STAR SYSTEM THERE, SIR.": FOR J = 1 TO 500: NEXT : ` |
| 3245 | W | godot-remake/scripts/chart/star_chart.gd:98 |  | `VTAB 21: PRINT "                                      ":P VTAB 21` |
| 3250 | P | godot-remake/scripts/chart/star_chart.gd:98<br>godot-remake/scripts/rules/chart_rules.gd:107 | 1 | `VTAB 21: PRINT "                                       ": VTAB 21: PRINT "STAR SYSTEM : ";` |
| 3255 | P | godot-remake/scripts/chart/star_chart.gd:98 | 1 | `GOSUB 3300` |
| 3260 | L | godot-remake/scripts/chart/star_chart.gd:98<br>godot-remake/scripts/rules/chart_rules.gd:122 | 1 | `PRINT "DO YOU WISH FURTHER INFORMATION?";: GET AN$: IF AN$ = "Y" THEN  POKE 38388,P: POKE ` |
| 3270 | P | godot-remake/scripts/chart/star_chart.gd:98 | 1 | `VTAB 21: PRINT "                                                                          ` |
| 3300 | L | godot-remake/scripts/rules/chart_rules.gd:107 | 1 | `LOC =  PEEK (38209):X1 =  ABS (X(LOC) - X(P)):X2 =  ABS (Y(LOC) - Y(P)):X3 =  ABS (Z(LOC) ` |
| 3310 | P | godot-remake/scripts/rules/chart_rules.gd:107 | 1 | `D1 =  SQR (X1 ^ 2 + X2 ^ 2 + X3 ^ 2)` |
| 3320 | P | godot-remake/scripts/rules/chart_rules.gd:107 | 1 | `PRINT " : DISTANCE = "; INT (D1);" L/Y": RETURN` |
| 5000 | W |  | 1 | `IF  PEEK (38201) <  > 1 THEN CH = 3` |
| 5010 | W |  | 1 | `IF  PEEK (38201) = 1 THEN CH = 1` |
| 5020 | W |  | 1 | `LX = 262:LY = 161: GOSUB 5500` |
| 5030 | W |  | 1 | `IF  PEEK (38202) <  > 1 THEN CH = 3:LX = 7:LY = 161: GOSUB 5500:CH = 1:LX = 72:LY = 161: G` |
| 5040 | W |  | 1 | `IF  PEEK (38202) = 1 THEN CH = 3:LX = 72:LY = 161: GOSUB 5500:CH = 1:LX = 7:LY = 161: GOSU` |
| 5050 | W |  | 1 | `LX = 200:LY = 161` |
| 5060 | W |  | 1 | `IF  PEEK (38165) = 1 THEN CH = 1: GOSUB 5500` |
| 5065 | W |  | 1 | `IF  PEEK (38165) = 2 THEN CH = 6: GOSUB 5500` |
| 5070 | W |  | 1 | `IF  PEEK (38165) = 3 THEN CH = 5: GOSUB 5500` |
| 5080 | W |  | 1 | `IF  PEEK (38165) = 2 THEN CH = 6: GOSUB 5500` |
| 5090 | W |  | 1 | `IF  PEEK (38164) <  > 1 THEN CH = 3:LX = 72:LY = 153: GOSUB 5500:CH = 1:LX = 7:LY = 153: G` |
| 5100 | W |  | 1 | `IF  PEEK (38164) = 1 THEN CH = 3:LX = 7:LY = 153: GOSUB 5500:CH = 1:LX = 72:LY = 153: GOSU` |
| 5110 | W |  | 1 | `IF  PEEK (38210) = 0 THEN CH = 1` |
| 5120 | W |  | 1 | `IF  PEEK (38210) = 1 THEN CH = 3` |
| 5130 | W |  | 1 | `LX = 200:LY = 153: GOSUB 5500` |
| 5140 | W |  | 1 | `IF  PEEK (38393) = 0 THEN CH = 1` |
| 5150 | W |  | 1 | `IF  PEEK (38393) = 1 THEN CH = 5` |
| 5160 | W |  | 1 | `LX = 262:LY = 153: GOSUB 5500: RETURN` |
| 5500 | W |  | 1 | `HCOLOR= CH: FOR J = LY TO LY + 4: HPLOT LX,J TO LX + 9,J: NEXT : RETURN` |
| 10000 | W |  | 1 | `IF T > 200 THEN  POKE 973,255: RETURN` |
| 10010 | W |  | 1 | `POKE 973,0: RETURN` |
| 15100 | W |  | 1 | `S$(1) = "SOL":S$(2) = "ALPHA CENTAURI":S$(3) = "BARNARD'S STAR":S$(4) = "WOLF 359":S$(5) =` |
| 15110 | W |  | 1 | `S$(6) = "LALANDE 21185":S$(7) = "SIRIUS":S$(8) = "VARCAR":S$(9) = "XANADON":S$(10) = "EPSI` |
| 15120 | W |  | 1 | `S$(11) = "CYGNI":S$(12) = "PROCYON":S$(13) = "TAU CETI":S$(14) = "LACAILLE 9352":S$(15) = ` |
| 15130 | W |  | 1 | `S$(16) = "GROOMBRIDGE 168":S$(17) = "KRUGER 60":S$(18) = "EPSILON INDI":S$(19) = "ARGO":S$` |
| 15140 | W |  | 1 | `RETURN` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
