# STARSHIP SIMULATOR: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

134 lines: 98 logic, 31 presentation, 5 waived. 101 lines cited by a rule; 12 of them never run in a recording.
Machine-code calls: line 73 -> 24582, line 74 -> 24582, line 114 -> 24585, line 116 -> 24585, line 120 -> 24585, line 122 -> 24585, line 124 -> 24582, line 125 -> 24582, line 127 -> 24582, line 128 -> 24582, line 150 -> 36899, line 150 -> 37936, line 153 -> 37888, line 500 -> 38402, line 1010 -> 37494, line 1100 -> 37494, line 1100 -> 37494, line 1205 -> 37494, line 1505 -> 37585, line 3019 -> 37494, line 3032 -> 37494, line 3032 -> 37494, line 5098 -> 37494, line 5230 -> 37494.

## Problems

none

## Cited, and never run in a recording (the listing alone)

74, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 500

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  | 1 | `ONERR  GOTO 63999` |
| 1 | P |  | 1 | `XI = 29467:YI = 29469:ZI = 29471:P1 = 29473:B1 = 29474:H1 = 29475:CSN = 24582:SN = 24585:M` |
| 2 | P |  | 1 | `EE = 199:SS = 13:EX = EE:VV = 160:Q = 1.41:X9 = 400:Y9 =  - 100:Z9 =  - 3500: POKE 232,HL:` |
| 8 | L | godot-remake/scripts/rules/combat_rules.gd:90 | 1 | `L =  PEEK (XI):H =  PEEK (XI + 1): GOSUB 6600:X = H:L =  PEEK (YI):H =  PEEK (YI + 1): GOS` |
| 9 | L | godot-remake/scripts/rules/combat_rules.gd:90 | 1 | `POKE 38149,7` |
| 15 | L | godot-remake/scripts/rules/flight_rules.gd:82 | 1 | `FOR OO = 0 TO 1: IF  PEEK (38164) = 1 THEN 20` |
| 19 | L | godot-remake/scripts/rules/flight_rules.gd:82 | 1 | `J =  PDL (1):K =  PDL (0): POKE 38397,J: POKE 38398,K` |
| 20 | P |  | 1 | `P =  PEEK (P1):B =  PEEK (B1):H =  PEEK (H1)` |
| 21 | L | godot-remake/scripts/rules/flight_rules.gd:146<br>godot-remake/scripts/rules/flight_rules.gd:82 | 1 | `POKE M1,B: IF B > 127 THEN 74` |
| 73 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `CALL CSN:BH = ( PEEK (M2) * HH) +  PEEK (M1): GOTO 112` |
| 74 | L | godot-remake/scripts/rules/flight_rules.gd:146 |  | `CALL CSN:A1 =  PEEK (M1):A2 =  PEEK (M2):A2 = A2 - HH:BH = (A2 * HH) + A1` |
| 112 | P | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `POKE M1,P` |
| 114 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `IF P < 63 OR P > 190 THEN  CALL SN:A1 =  PEEK (M1):A2 =  PEEK (M2):ZP = (A2 * HH) + A1` |
| 116 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `IF P > 63 AND P < 190 THEN  CALL SN:A1 =  PEEK (M1):A2 =  PEEK (M2):A2 = A2 - HH:ZP = (A2 ` |
| 119 | P | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `POKE M1,H` |
| 120 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `IF H < 63 OR H > 190 THEN  CALL SN:A1 =  PEEK (M1):A2 =  PEEK (M2):ZH = (A2 * HH) + A1` |
| 122 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `IF H > 63 AND H < 190 THEN  CALL SN:A1 =  PEEK (M1):A2 =  PEEK (M2):A2 = A2 - HH:ZH = (A2 ` |
| 123 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `POKE M1,H: IF H > 127 THEN 125` |
| 124 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `CALL CSN:XH = ( PEEK (M2) * HH) +  PEEK (M1): GOTO 126` |
| 125 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `CALL CSN:A1 =  PEEK (M1):A2 =  PEEK (M2):A2 = A2 - HH:XH = (A2 * HH) + A1` |
| 126 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `POKE M1,P: IF P > 127 THEN 128` |
| 127 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `CALL CSN:YP = ( PEEK (M2) * HH) +  PEEK (M1): GOTO 129` |
| 128 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `CALL CSN:A1 =  PEEK (M1):A2 =  PEEK (M2):A2 = A2 - HH:YP = (A2 * HH) + A1` |
| 129 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `YP = YP / DI:ZH = ZH / DI:XH = XH / DI:ZP = ZP / DI:X1 = S * (ZP * XH):Z1 = S * ZP * ZH:X ` |
| 133 | L | godot-remake/scripts/rules/flight_rules.gd:82 | 1 | `IF X < W2 THEN X = W1` |
| 134 | L | godot-remake/scripts/rules/flight_rules.gd:82 | 1 | `IF X > W1 THEN X = W2` |
| 135 | L | godot-remake/scripts/rules/flight_rules.gd:82 | 1 | `IF Y < W2 THEN Y = W1` |
| 136 | L | godot-remake/scripts/rules/flight_rules.gd:82 | 1 | `IF Y > W1 THEN Y = W2` |
| 137 | L | godot-remake/scripts/rules/flight_rules.gd:82 | 1 | `IF Z < W2 THEN Z = W1` |
| 138 | L | godot-remake/scripts/rules/flight_rules.gd:82 | 1 | `IF Z > W1 THEN Z = W2` |
| 140 | P | godot-remake/scripts/rules/flight_rules.gd:254 | 1 | `BV% = X: GOSUB 6000: POKE XI,LO%: POKE XI + 1,HI%:BV% = Y: GOSUB 6000: POKE YI,LO%: POKE Y` |
| 147 | L | godot-remake/scripts/rules/flight_rules.gd:254 | 1 | `POKE 29461,84 + OO:OP =  ABS (OO - 1): POKE 29463,OP: POKE 29465,OP: IF  PEEK (38210) = 1 ` |
| 150 | L | godot-remake/scripts/rules/flight_rules.gd:254 | 1 | `CALL CA: IF OO = 1 THEN  POKE 974,32: CALL 37936` |
| 153 | L | godot-remake/scripts/flight/native_flight.gd:677 | 1 | `IF OO = 0 THEN  POKE 974,64: CALL 37888` |
| 155 | P |  | 1 | `VTAB 24: HTAB 1: PRINT  INT (X / 2);" ";: HTAB 7: PRINT  INT (Y / 2);" ";: HTAB 13: PRINT ` |
| 156 | L | godot-remake/scripts/rules/flight_rules.gd:109 | 1 | `POKE 973,1: VTAB 8: HTAB 18: PRINT "-"; CHR$ (91);"  "; CHR$ (93);"-": POKE 973,0: IF  ABS` |
| 158 | L | godot-remake/scripts/rules/flight_rules.gd:109<br>godot-remake/scripts/rules/flight_rules.gd:116 | 1 | `IF  PEEK (38210) = 1 AND Y > 4000 THEN  PRINT "RUNORBIT"` |
| 159 | L | godot-remake/scripts/flight/hud_overlay.gd:256 | 1 | `HCOLOR= 0: DRAW 25 AT TT,133: DRAW 26 AT 136,VV: DRAW 25 AT EE,133: DRAW 25 AT SS,133:TX =` |
| 170 | L | godot-remake/scripts/rules/flight_rules.gd:101 | 1 | `VY =  INT (167 - ((HL - P) / 4)): IF P < 127 THEN VY =  INT (167 + (P / 4))` |
| 173 | P |  | 1 | `SX = 13 + (S / 2):EX = 199 + E` |
| 175 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `HCOLOR= 3: IF  PEEK (P1) > 59 AND  PEEK (P1) < 127 THEN  POKE P1,59` |
| 177 | L | godot-remake/scripts/rules/flight_rules.gd:146 | 1 | `IF  PEEK (P1) < 195 AND  PEEK (P1) > 127 THEN  POKE P1,195` |
| 180 | L | godot-remake/scripts/flight/hud_overlay.gd:256 | 1 | `DRAW 13 AT TX,133: DRAW 14 AT 136,VY: DRAW 13 AT SX,133: DRAW 13 AT EX,133: IF OO = 1 THEN` |
| 182 | L | godot-remake/scripts/rules/combat_rules.gd:90 | 1 | `IF  PEEK (38149) = 7 THEN  POKE 38149,0: GOTO 200` |
| 185 | L | godot-remake/scripts/flight/native_flight.gd:247<br>godot-remake/scripts/rules/combat_rules.gd:110 | 1 | `IF  PEEK ( - 16287) > 127 THEN  GOSUB 1500` |
| 189 | L | godot-remake/scripts/flight/native_flight.gd:247<br>godot-remake/scripts/rules/combat_rules.gd:110 | 1 | `IF  PEEK (38282 +  PEEK (38209)) < 2 THEN 200` |
| 190 | L | godot-remake/scripts/flight/native_flight.gd:247<br>godot-remake/scripts/rules/combat_rules.gd:110 | 1 | `IF  PEEK (38208) = 0 AND  PEEK (38210) = 1 THEN  GOSUB 3000: IF  RND (1) < .5 AND  PEEK (3` |
| 192 | L | godot-remake/scripts/flight/native_flight.gd:247<br>godot-remake/scripts/rules/combat_rules.gd:110 | 1 | `IF  PEEK (38208) = 0 AND X >  - 3500 AND X < 4500 AND Y >  - 3000 AND Y < 3000 AND Z >  - ` |
| 200 | L | godot-remake/scripts/flight/native_flight.gd:184 | 1 | `K =  PEEK ( - 16384): IF K < 128 THEN  NEXT : GOTO 15` |
| 201 | L | godot-remake/scripts/rules/flight_rules.gd:95 |  | `IF K - 176 > 0 THEN K = K - 176: POKE  - 16368,0: ON K GOSUB 311,312,313,314` |
| 202 | L | godot-remake/scripts/rules/flight_rules.gd:95 |  | `IF K < 17 THEN 207` |
| 203 | L | godot-remake/scripts/rules/flight_rules.gd:95 |  | `ON K - 16 GOTO 317,318,319` |
| 204 | L | godot-remake/scripts/rules/flight_rules.gd:95 |  | `IF K < 34 THEN 207` |
| 205 | L | godot-remake/scripts/rules/flight_rules.gd:95 |  | `IF K = 39 THEN  POKE LT,2: GOTO 500` |
| 206 | L | godot-remake/scripts/rules/flight_rules.gd:95 |  | `ON K - 33 GOTO 320,321` |
| 207 | L | godot-remake/scripts/rules/flight_rules.gd:95 |  | `IF S < 0 THEN S = 0` |
| 208 | L | godot-remake/scripts/rules/flight_rules.gd:95 |  | `IF S > 120 THEN S = 120` |
| 209 | L | godot-remake/scripts/flight/native_flight.gd:394 |  | `IF K = 24 THEN  PRINT "RUNH/D"` |
| 210 | L | godot-remake/scripts/flight/native_flight.gd:184 |  | `POKE 38157,S:K = 0: NEXT : GOTO 15` |
| 311 | P |  |  | `S = S - 3: RETURN` |
| 312 | P |  |  | `S = S + 3: RETURN` |
| 313 | P |  |  | `S = S - 15: RETURN` |
| 314 | P |  |  | `S = S + 15: RETURN` |
| 317 | P |  |  | `POKE LT,4: GOTO 500` |
| 318 | P |  |  | `POKE LT,3: GOTO 500` |
| 319 | P |  |  | `PRINT "RUNCOM"` |
| 320 | P |  |  | `PRINT "RUNRADAR"` |
| 321 | P |  |  | `POKE LT,1` |
| 500 | L | godot-remake/scripts/flight/native_flight.gd:184 |  | `CALL 38402: GOTO 1` |
| 1000 | L | godot-remake/scripts/rules/combat_rules.gd:170 | 1 | `M8 = M1:M9 = M2:M3 = 3:M1 = 140:M2 = 40:X0 = X:Y0 = Y:Z0 = Z:S2 = 160:X2 = S2 * (ZP * XH):` |
| 1010 | L | godot-remake/scripts/rules/combat_rules.gd:170 | 1 | `CALL SG: FOR M = 124 TO 62 STEP  - 4: XDRAW M3 AT M1 + M2,M: XDRAW M3 AT M1 - M2,M: IF  PE` |
| 1050 | L | godot-remake/scripts/rules/combat_rules.gd:170 | 1 | `IF X0 < X9 + 150 AND X0 > X9 - 150 AND Y0 < Y9 + 60 AND Y0 > Y9 - 20 AND Z0 < Z9 + 100 AND` |
| 1060 | L | godot-remake/scripts/rules/combat_rules.gd:170 | 1 | `XDRAW M3 AT M1 + M2,M: XDRAW M3 AT M1 - M2,M:M3 = M3 + .32:M2 = M2 - 2:X0 = X0 + X2:Z0 = Z` |
| 1085 | L | godot-remake/scripts/rules/combat_rules.gd:170 | 1 | `IF HIT = 1 THEN  GOSUB 1200:J1 = 10:J2 = 120: GOSUB 1535: GOTO 1090` |
| 1088 | P |  | 1 | `GOSUB 1100` |
| 1090 | L | godot-remake/scripts/rules/combat_rules.gd:206 | 1 | `HIT = 0:M1 = M8:M2 = M9:J =  PEEK (38187) - 2: GOSUB 3380: POKE 38187,J: RETURN` |
| 1100 | L | godot-remake/scripts/rules/combat_rules.gd:170 | 1 | `GOSUB 4100: POKE  - 16298,0: POKE  - 16297,0: HCOLOR= 3: FOR X0 = 1 TO 2: FOR LY = 0 TO 1:` |
| 1200 | P |  | 1 | `FOR X0 = 1 TO 2: FOR LY = 1 TO 2: SCALE= LY: XDRAW 2 AT M1 - M2,M: NEXT : SCALE= 1: POKE  ` |
| 1205 | L | godot-remake/autoload/audio_manager.gd:66 | 1 | `CALL SG` |
| 1220 | P |  | 1 | `FOR LY = 1 TO 2: SCALE= LY: XDRAW 2 AT M1 + M2,M: NEXT` |
| 1222 | P |  | 1 | `SCALE= 1: POKE  - 16298,0: XDRAW 15 AT M1 + M2,M: XDRAW 16 AT M1 + M2,M: XDRAW 17 AT M1 + ` |
| 1500 | L | godot-remake/scripts/rules/combat_rules.gd:151 | 1 | `IF  PEEK (38208) = 1 THEN  POKE 38208,0: POKE 38150,100` |
| 1501 | L | godot-remake/scripts/rules/combat_rules.gd:151 | 1 | `POKE  - 16300,0: IF  PEEK (38202) = 1 THEN 1000` |
| 1502 | L | godot-remake/scripts/rules/combat_rules.gd:151 | 1 | `IF  PEEK (38186) = 0 THEN  RETURN` |
| 1505 | L | godot-remake/scripts/rules/combat_rules.gd:151 | 1 | `J1 = 10:J2 = 1:X1 = 90:X2 = 190:Y1 = 123:Y2 = 60:X3 = 136:X4 = 144: FOR LX = 1 TO 3: HCOLO` |
| 1530 | P |  | 1 | `HCOLOR= 0: HPLOT X1,Y1 TO X3,Y2 TO X1 + 4,Y1: HPLOT X2,Y1 TO X4,Y2 TO X2 - 4,Y1: FOR J = 1` |
| 1535 | L | godot-remake/scripts/rules/combat_rules.gd:215 | 1 | `VP =  PEEK (38160) + (J1 / (TE + 1)): IF VP < HL THEN  POKE 38160,VP` |
| 1540 | L | godot-remake/scripts/rules/combat_rules.gd:215 | 1 | `IF  PEEK (38210) = 0 THEN DP =  PEEK (38152) + (J2 / (TE + 1)): IF DP < HL THEN  POKE 3815` |
| 1550 | L | godot-remake/scripts/rules/combat_rules.gd:215 | 1 | `IF VP =  >  PEEK (38150) THEN  POKE 974,32: POKE  - 16300,0: SPEED= 127: VTAB 13: HTAB 8: ` |
| 1560 | L | godot-remake/scripts/rules/combat_rules.gd:215 | 1 | `IF DP >  PEEK (38204) AND  PEEK (38205) <  > 0 THEN  PRINT "RUNEX"` |
| 1570 | P |  | 1 | `RETURN` |
| 3000 | L | godot-remake/scripts/rules/combat_rules.gd:238 | 1 | `IF  PEEK (38205) = 0 AND  PEEK (38210) = 0 THEN  RETURN` |
| 3001 | L | godot-remake/scripts/rules/combat_rules.gd:238 | 1 | `POKE  - 16300,0: IF  RND (1) > .4 THEN 3030` |
| 3010 | L | godot-remake/scripts/rules/combat_rules.gd:238 | 1 | `IF  RND (1) > .4 THEN 3030` |
| 3019 | L | godot-remake/scripts/rules/combat_rules.gd:238 | 1 | `GOSUB 4110:HC =  RND (1) * 5: FOR LY = 1 TO HC: POKE  - 16298,0: FOR J = 1 TO 10: NEXT : P` |
| 3030 | L | godot-remake/scripts/rules/combat_rules.gd:238 | 1 | `IF  RND (1) > .3 THEN 3200` |
| 3032 | L | godot-remake/scripts/rules/combat_rules.gd:238 | 1 | `GOSUB 4120: POKE  - 16298,0: CALL SG: POKE  - 16297,0:DMG = 1: CALL SG` |
| 3200 | L | godot-remake/scripts/rules/combat_rules.gd:238 | 1 | `IF DMG = 0 THEN  RETURN` |
| 3205 | L | godot-remake/scripts/rules/combat_rules.gd:260 | 1 | `J =  PEEK (38200) - ( RND (1) * 1.1): GOSUB 3380: POKE 38200,J: IF  PEEK (38200) > 10 AND ` |
| 3207 | L | godot-remake/scripts/rules/combat_rules.gd:260 | 1 | `IF L = 7 THEN  RETURN` |
| 3230 | L | godot-remake/scripts/rules/combat_rules.gd:260 | 1 | `J =  PEEK (38195) - ( RND (1) * 5): GOSUB 3380: POKE 38195,J` |
| 3260 | L | godot-remake/scripts/rules/combat_rules.gd:260 | 1 | `J =  PEEK (38198) - ( RND (1) * 5): GOSUB 3380` |
| 3270 | L | godot-remake/scripts/rules/combat_rules.gd:260 | 1 | `POKE 38198,J:J =  PEEK (38197) - ( RND (1) * 5): GOSUB 3380: POKE 38197,J:J =  PEEK (38196` |
| 3350 | L | godot-remake/scripts/rules/combat_rules.gd:260 | 1 | `POKE 38193,J:DMG = 0: IF J = 0 THEN  PRINT "RUNS/X"` |
| 3360 | L | godot-remake/scripts/rules/combat_rules.gd:260 | 1 | `IF  PEEK (38393) = 0 THEN  POKE 38393,1: PRINT "RUNDMG"` |
| 3380 | L | godot-remake/scripts/rules/combat_rules.gd:206<br>godot-remake/scripts/rules/combat_rules.gd:260 | 1 | `IF J < 0 THEN J = 0` |
| 3381 | P |  | 1 | `RETURN` |
| 4100 | L | godot-remake/autoload/audio_manager.gd:63 | 1 | `POKE 37491,10: POKE 37490,10: POKE 37492,0: POKE 37493,129: RETURN` |
| 4110 | L | godot-remake/autoload/audio_manager.gd:56 | 1 | `POKE 37491,5: POKE 37490,5: POKE 37492,0: POKE 37493,0: RETURN` |
| 4120 | L | godot-remake/autoload/audio_manager.gd:60 | 1 | `POKE 37491,7: POKE 37490,7: POKE 37492,0: POKE 37493,129: RETURN` |
| 5000 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `POKE  - 16300,0:X1 = ( RND (5) * 260) + 10:Y1 =  RND (1): IF Y1 >  = .4 THEN Y1 = 10:Y2 = ` |
| 5045 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `IF Y1 < .4 THEN Y1 = 120:Y2 =  RND (5) * 7:Y2 = Y2 - (Y2 * 2)` |
| 5050 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `IF X1 > 190 THEN X2 =  - 7:M = 9: GOTO 5090` |
| 5060 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `IF X1 < 91 THEN X2 = 7:M = 10: GOTO 5090` |
| 5080 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `X2 =  - 2:M = 8: IF  ABS (Y2) < 4 THEN Y2 = Y2 * 2` |
| 5090 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `XDRAW M AT X1,Y1: IF  RND (1) < .3 THEN  GOSUB 5098: GOSUB 5200` |
| 5095 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `XDRAW M AT X1,Y1:X1 = X1 + X2:Y1 = Y1 + Y2: IF Y1 < 10 OR Y1 > 120 OR X1 < 10 OR X1 > 270 ` |
| 5096 | P |  | 1 | `GOTO 5090` |
| 5098 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `GOSUB 4110: POKE  - 16298,0: CALL SG: POKE  - 16297,0:L = 7: GOSUB 3205:L = 0: RETURN` |
| 5200 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `IF  PEEK (38165) <  > 3 THEN  RETURN` |
| 5210 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `LX = 240:J =  RND (1): IF J < .6 THEN LX = 40` |
| 5230 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `FOR J = 1 TO 0 STEP  - 1: HCOLOR= J * 5: POKE  - 16298,0: FOR J1 = 1 TO 5: NEXT : POKE  - ` |
| 5240 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `IF  RND (5) < .3 THEN  GOSUB 5250: POP` |
| 5245 | P |  | 1 | `RETURN` |
| 5250 | L | godot-remake/scripts/rules/combat_rules.gd:298 | 1 | `XDRAW M AT X1,Y1:M8 = M1:M9 = M2:M1 = X1:M2 = 4:M = Y1: GOSUB 1100:J =  PEEK (38207) - 1: ` |
| 5251 | P |  | 1 | `GOTO 1090` |
| 6000 | W |  | 1 | `HI% = BV% / HH: IF BV% < 0 THEN HI% = HI% + 1` |
| 6010 | W |  | 1 | `LO% = BV% - HI% * HH: IF BV% >  - 1 THEN  RETURN` |
| 6030 | W |  | 1 | `HI% = HL + HI%:LO% = HH + LO%: IF LO% < HH THEN  RETURN` |
| 6060 | P |  |  | `HI% = HI% + 1:LO% = 0: RETURN` |
| 6600 | W |  | 1 | `IF H < 129 THEN 6640` |
| 6610 | P |  | 1 | `H = H - HL:H = H * HH:H = H + (L - HH): RETURN` |
| 6640 | P |  | 1 | `H = (H * HH) + L: RETURN` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
