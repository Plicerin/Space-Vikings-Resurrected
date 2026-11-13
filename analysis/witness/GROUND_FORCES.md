# GROUND FORCES: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

95 lines: 58 logic, 35 presentation, 2 waived. 76 lines cited by a rule; 0 of them never run in a recording.
Machine-code calls: none.

## Problems

none

## Cited, and never run in a recording (the listing alone)

none

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  | 21 | `ONERR  GOTO 63999` |
| 10 | P |  | 21 | `HTAB 1:D$ = ""` |
| 11 | L | godot-remake/scripts/rules/ground_rules.gd:60 | 21 | `PRINT D$;"OPEN MISC FILE": PRINT D$;"READ MISC FILE": INPUT SD: INPUT TR: INPUT CR: PRINT ` |
| 12 | L | godot-remake/scripts/rules/ground_rules.gd:60 | 21 | `POKE 974,64: PRINT : POKE 974,32: VTAB 1: HTAB 2: FOR C = 2 TO 13: VTAB C: PRINT "        ` |
| 13 | L | godot-remake/scripts/rules/ground_rules.gd:60 | 21 | `M =  PEEK (38153):P =  PEEK (38156):TP =  PEEK (38155):T =  PEEK (38154): HPLOT 1,1 TO 139` |
| 14 | L | godot-remake/scripts/rules/ground_rules.gd:60 | 21 | `IF  PEEK (29469) = 20 AND  PEEK (29470) = 0 AND  PEEK (38170) = 0 THEN  POKE 38170,17` |
| 30 | P |  | 21 | `PRINT "1) ATTACK PLANET": PRINT "2) RECALL TROOPS": PRINT "3) SHORE LEAVE"` |
| 40 | P |  | 21 | `PRINT "4) ENLIST TROOPS": PRINT "5) SELL LOOT": PRINT "6) REPAIR/RESTOCK"` |
| 50 | P |  | 21 | `PRINT "7) ESTABLISH BASE": PRINT "8) CRYOGENICS": PRINT "9) RETURN"` |
| 60 | L | godot-remake/scripts/flight/ground_forces_program.gd:69 | 21 | `HCOLOR= 1: GET COM$:COM =  VAL (COM$): IF COM < 1 THEN 60` |
| 62 | P | godot-remake/scripts/flight/ground_forces_program.gd:69 | 21 | `HPLOT 1,1 TO 139,1 TO 139,110 TO 1,110 TO 1,1` |
| 65 | L | godot-remake/scripts/flight/ground_forces_program.gd:69<br>godot-remake/scripts/rules/ground_rules.gd:74 | 21 | `R = 5: GOSUB 12: VTAB 2: IF COM > 2 AND COM < 7 AND  PEEK (38303 +  PEEK (38209)) = 0 THEN` |
| 66 | L | godot-remake/scripts/flight/ground_forces_program.gd:69<br>godot-remake/scripts/rules/ground_rules.gd:74 | 21 | `IF COM = 4 AND  PEEK (38158) <  >  PEEK (38209) THEN  PRINT : PRINT "DO YOU REALLY": PRINT` |
| 67 | L | godot-remake/scripts/flight/ground_forces_program.gd:69<br>godot-remake/scripts/rules/ground_rules.gd:74 | 21 | `IF COM = 1 AND  PEEK (38158) <  >  PEEK (38209) THEN  PRINT : PRINT "YOU CAN'T ATTACK!": P` |
| 70 | L | godot-remake/scripts/flight/ground_forces_program.gd:69 | 21 | `POKE 974,64: PRINT : ON COM GOTO 100,2000,2080,2150,2160,2170,2180,2190` |
| 75 | L | godot-remake/scripts/flight/ground_forces_program.gd:69 | 21 | `IF COM = 9 THEN  PRINT D$;"RUN COM"` |
| 80 | P |  |  | `GOTO 12` |
| 100 | P |  | 10 | `POKE 974,32: POKE 32,0: POKE 33,40: POKE 34,0: POKE 35,16: HOME : FOR C = 1 TO 16: VTAB C:` |
| 110 | P |  | 10 | `HCOLOR= 5: HPLOT 7,12 TO 271,12 TO 271,76 TO 7,76 TO 7,12` |
| 120 | L | godot-remake/scripts/rules/ground_rules.gd:87 | 10 | `VTAB 2: HTAB 13: PRINT " GROUND FORCES": VTAB 4: HTAB 8: PRINT "BATTLE IN": VTAB 5: HTAB 8` |
| 130 | P | godot-remake/scripts/rules/ground_rules.gd:87 | 10 | `VTAB 4: HTAB 24: PRINT "FIGHTERS:": HTAB 22: PRINT "TRANSPORTS:": HTAB 26: PRINT "TROOPS:"` |
| 140 | P | godot-remake/scripts/rules/ground_rules.gd:87 | 10 | `VTAB 10: HTAB 8: PRINT " COMPUTER ";: HTAB 25: PRINT "  STATUS  ": VTAB 11: HTAB 8: PRINT ` |
| 145 | P | godot-remake/scripts/rules/ground_rules.gd:87 | 10 | `VTAB 7: HTAB 5: PRINT "PROBABILITY": HTAB 6: PRINT "OF SUCCESS :"` |
| 150 | L | godot-remake/scripts/rules/ground_rules.gd:87 | 10 | `POKE 38158, PEEK (38209): POKE 973,255` |
| 160 | P | godot-remake/scripts/rules/ground_rules.gd:87 | 10 | `REM` |
| 170 | L | godot-remake/scripts/rules/ground_rules.gd:87 | 10 | `FOR C = 12 TO 15: VTAB C: PRINT "                                       ": NEXT : VTAB 12:` |
| 172 | L | godot-remake/scripts/rules/ground_rules.gd:87 | 10 | `IF  PEEK (38207) = 1 AND  PEEK (38208) = 1 THEN 310` |
| 175 | L | godot-remake/scripts/rules/ground_rules.gd:87 | 10 | `IF  PEEK (38155) = 0 THEN  PRINT "THERE ARE NO TRANSPORTS AVAILABLE!": GOTO 310` |
| 177 | L | godot-remake/scripts/rules/ground_rules.gd:87 | 9 | `POKE 38166,1` |
| 178 | L | godot-remake/scripts/rules/ground_rules.gd:87 | 9 | `T8 =  PEEK (38155) * 1000: IF TR < T8 THEN T9 = 0: GOTO 180` |
| 179 | L | godot-remake/scripts/rules/ground_rules.gd:87 | 1 | `IF TR >  = T8 THEN T9 = TR - T8:TR = T8` |
| 180 | L | godot-remake/scripts/rules/ground_rules.gd:105 | 9 | `PRINT "ALL TRANSPORTS AWAY, SIR!": FOR C = 1 TO 4000: NEXT : IF  PEEK (38210) = 0 THEN  PR` |
| 185 | L | godot-remake/scripts/rules/ground_rules.gd:105 | 9 | `FOR C = 1 TO 2000: NEXT : IF  PEEK (38156) > 0 THEN  PRINT "FIGHTERS LAUNCHING FROM TRANSP` |
| 190 | P |  | 9 | `FOR C = 1 TO 2000: NEXT C` |
| 195 | P |  | 9 | `R4 = 1: GOSUB 170` |
| 200 | L | godot-remake/scripts/rules/ground_rules.gd:117 | 9 | `C =  PEEK (38282 +  PEEK (38209))` |
| 210 | L | godot-remake/scripts/rules/ground_rules.gd:117 | 9 | `ON C + 1 GOTO 220,300,330,400,450` |
| 220 | P | godot-remake/scripts/rules/ground_rules.gd:117 | 1 | `PRINT "PLANET IS NON HABITABLE. THERE IS NO": PRINT "ENEMY TO RESIST LANDING FORCE."` |
| 230 | P | godot-remake/scripts/rules/ground_rules.gd:117 | 1 | `FOR C = 1 TO 3000: NEXT C:R4 = 1: GOSUB 160` |
| 240 | P | godot-remake/scripts/rules/ground_rules.gd:117 | 1 | `GOSUB 740: GOTO 310` |
| 300 | P | godot-remake/scripts/rules/ground_rules.gd:117 | 1 | `PRINT "PLANET IS VERY PRIMITIVE.": PRINT "THE LOCAL INHABITANTS ARE UNABLE TO": PRINT "RES` |
| 305 | L | godot-remake/scripts/rules/ground_rules.gd:117 | 1 | `POKE 38150,0: FOR J = 1 TO 4000: NEXT : GOTO 500` |
| 310 | L | godot-remake/scripts/rules/ground_rules.gd:117 | 3 | `POKE 974,64: POKE 38151,7: PRINT " ": PRINT "RUN COM"` |
| 330 | P | godot-remake/scripts/rules/ground_rules.gd:117 | 3 | `PRINT "PLANET IS IN THE LIMITED ATOMIC STAGE": PRINT "OF DEVELOPMENT!": FOR C = 1 TO 3000:` |
| 340 | L | godot-remake/scripts/rules/ground_rules.gd:117 | 3 | `IF  PEEK (38208) = 0 THEN  PRINT "ATTACK FORCE IS MEETING RESISTANCE!!"` |
| 350 | P | godot-remake/scripts/rules/ground_rules.gd:117 | 3 | `FOR J = 1 TO 4000: NEXT : GOTO 500` |
| 400 | P | godot-remake/scripts/rules/ground_rules.gd:117 | 3 | `PRINT "PLANET HAS COMPARABLE TECHNOLOGY TO US!": VTAB 13: FOR C = 1 TO 3000: NEXT : PRINT ` |
| 410 | P | godot-remake/scripts/rules/ground_rules.gd:117 | 3 | `FOR J = 1 TO 4000: NEXT : GOTO 500` |
| 450 | L | godot-remake/scripts/rules/ground_rules.gd:117 | 1 | `PRINT "PLANET HAS SUPERIOR TECHNOLOGY TO OURS!": VTAB 13: FOR C = 1 TO 3000: NEXT : IF  PE` |
| 480 | P | godot-remake/scripts/rules/ground_rules.gd:117 | 1 | `FOR J = 1 TO 4000: NEXT` |
| 500 | L | godot-remake/scripts/rules/ground_rules.gd:117 | 8 | `TECH =  PEEK (38209):TECH =  PEEK (38282 + TECH):ET =  PEEK (38206) * 500:M =  PEEK (38153` |
| 510 | L | godot-remake/scripts/rules/ground_rules.gd:117 | 8 | `SP =  PEEK (38150):VP =  PEEK (38160)` |
| 550 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `VIC =  RND (1) * (10 * TECH): IF VIC < 20 THEN T1 = TECH * 3:T2 = 500 + ( RND (1) * 20):T3` |
| 555 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 3 | `T1 = 1:T2 = 200 * ( RND (1) * 5):T3 = 500 + ( RND (1) * 5):X =  - ( RND (1) * (10 / (TECH ` |
| 560 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `T = T - ( RND (1) * ( RND (1) * 5)):P = P - ( RND (1) * ( RND (1) * 5)):M = M - ( RND (1) ` |
| 570 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `ET = ET - ( RND (1) * ( RND (1) * (3 * ( RND (1) * T3)))): IF  PEEK (38205) > 0 THEN X = X` |
| 572 | P | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `PS = 100 / (SP + .01):PS = PS * VP` |
| 575 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `X = X + ( PEEK (38203) - 3)` |
| 580 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `VP = VP + X: IF VP > 255 THEN VP = 255` |
| 585 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `IF VP < 0 THEN VP = 0` |
| 590 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `IF T < 0 THEN T = 0` |
| 592 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `IF P < 0 THEN P = 0` |
| 594 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `IF M < 0 THEN M = 0` |
| 596 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `IF TP < 0 THEN TP = 0` |
| 598 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `IF TR < 0 THEN TR = 0` |
| 600 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `POKE 38156,P: POKE 38155,TP: POKE 38154,T: POKE 38153,M` |
| 650 | P | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `GOSUB 4000:O =  PEEK ( - 16336) +  PEEK ( - 16336) +  PEEK ( - 16336) +  PEEK ( - 16336): ` |
| 660 | L | godot-remake/scripts/rules/ground_rules.gd:151<br>godot-remake/scripts/rules/ground_rules.gd:265 | 7 | `IF VP =  > SP THEN  POKE 38150,0:R4 = 1: GOSUB 170: VTAB 8: HTAB 18: PRINT "100%": VTAB 12` |
| 665 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 5 | `IF TR = 0 THEN  POKE 38166,0` |
| 670 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 5 | `IF TR = 0 THEN R4 = 1: GOSUB 160: HTAB 1: VTAB 12: PRINT "THE BATTLE IS LOST! ALL TROOPS":` |
| 675 | P |  | 5 | `FOR J = 1 TO 2000: NEXT` |
| 680 | P |  | 5 | `GOTO 550` |
| 690 | P |  | 5 | `FOR J = 1 TO 5000: NEXT :R4 = 1: GOSUB 160: VTAB 12: HTAB 1: PRINT "TROOPS ARE NOW COLLECT` |
| 740 | L | godot-remake/scripts/rules/ground_rules.gd:265 | 1 | `POKE 38208,1: POKE 38219 +  PEEK (38209),1: FOR J = 1 TO 4000: NEXT : RETURN` |
| 800 | W |  | 5 | `PRINT "OPEN MISC FILE": PRINT "WRITE MISC FILE": PRINT SD: PRINT TR + T9: PRINT CR: PRIN` |
| 805 | P |  | 5 | `PRINT "RUN COLLECT"` |
| 1100 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `K =  PEEK ( - 16384): IF K < 128 THEN  POKE  - 16368,0: RETURN` |
| 1110 | P | godot-remake/scripts/rules/ground_rules.gd:151 | 2 | `POKE  - 16368,0:K = K - 176` |
| 1115 | P | godot-remake/scripts/rules/ground_rules.gd:151 | 2 | `K = 82` |
| 1120 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 2 | `IF K = 82 THEN R4 = 1: GOSUB 160: VTAB 12: HTAB 1: PRINT "GROUND FORCES RETREATING, SIR!":` |
| 1121 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 2 | `IF M >  - 1 THEN  POKE 38203,M` |
| 1130 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 2 | `POKE 38151,7: PRINT D$;"RUN COM"` |
| 2000 | P |  | 3 | `PRINT "RUN RECALL"` |
| 2080 | P |  | 4 | `PRINT "RUN SHORE LEAVE"` |
| 2150 | L | godot-remake/scripts/flight/ground_forces_program.gd:88 | 4 | `POKE 38388,1: PRINT "RUNSHORE LEAVE"` |
| 2160 | L | godot-remake/scripts/flight/ground_forces_program.gd:88 | 5 | `POKE 38388,2: PRINT "RUNSHORE LEAVE"` |
| 2170 | L | godot-remake/scripts/flight/ground_forces_program.gd:88 | 4 | `POKE 38388,3: PRINT "RUNSHORE LEAVE"` |
| 2180 | L | godot-remake/scripts/flight/ground_forces_program.gd:88 | 5 | `POKE 38388,4: PRINT "RUNSHORE LEAVE"` |
| 2190 | L | godot-remake/scripts/flight/ground_forces_program.gd:88 | 2 | `POKE 38388,5: PRINT "RUNSHORE LEAVE"` |
| 4000 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `P =  INT (P):TP =  INT (TP):TR =  INT (TR):T =  INT (T):M =  INT (M):PS =  INT ((PS * 100)` |
| 4001 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `IF PS > 100 THEN PS = 100` |
| 4010 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `POKE 973,0: VTAB 4: HTAB 33: PRINT P;" ": HTAB 33: PRINT TP;" ": HTAB 33: PRINT TR;" ": HT` |
| 4020 | L | godot-remake/scripts/rules/ground_rules.gd:151 | 8 | `IF TR = 0 THEN  VTAB 6: HTAB 33: POKE 973,0: PRINT "    ": VTAB 6: HTAB 33: PRINT "0": POK` |
| 4030 | P |  | 8 | `RETURN` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
