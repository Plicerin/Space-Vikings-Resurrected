# COM: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

124 lines: 50 logic, 57 presentation, 17 waived. 109 lines cited by a rule; 3 of them never run in a recording.
Machine-code calls: none.

## Problems

none

## Cited, and never run in a recording (the listing alone)

1200, 3000, 20000

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  | 5 | `ONERR  GOTO 63999` |
| 5 | W | godot-remake/scripts/flight/command_console_program.gd:33<br>godot-remake/scripts/flight/native_flight.gd:287 | 5 | `CR$ =  CHR$ (13)` |
| 8 | W | godot-remake/scripts/flight/command_console_program.gd:33<br>godot-remake/scripts/flight/native_flight.gd:287 | 5 | `POKE 974,32: POKE 973,0: POKE  - 16300,0: HCOLOR= 0: FOR X = 200 TO 260 STEP 5: DRAW 25 AT` |
| 10 | W | godot-remake/scripts/flight/command_console_program.gd:33<br>godot-remake/scripts/flight/native_flight.gd:287 | 5 | `DIM V(12),H(12),S$(20),ST(12)` |
| 12 | L | godot-remake/scripts/flight/command_console_program.gd:33<br>godot-remake/scripts/flight/native_flight.gd:287<br>godot-remake/scripts/rules/com_rules.gd:87 | 5 | `GOSUB 15100: IF  PEEK (38388) > 0 THEN C =  PEEK (38388): GOTO 978` |
| 20 | W |  | 5 | `HCOLOR= 6: FOR Y = 0 TO 123: HPLOT 0,Y TO 279,Y: NEXT : POKE 32,0: HOME : FOR J = 1 TO 14:` |
| 21 | W |  | 5 | `POKE 32,0: POKE 33,40: POKE 34,0: POKE 35,23: PRINT` |
| 25 | W |  | 5 | `POKE 32,0: POKE 33,40: POKE 34,0: POKE 35,23: PRINT` |
| 29 | W |  | 5 | `HOME : PRINT "                    ": HOME : VTAB 2: FOR X = 1 TO 12: PRINT "              ` |
| 35 | W |  | 5 | `IF R = 1 THEN R = 0: RETURN` |
| 40 | P | godot-remake/scripts/rules/com_rules.gd:66 | 5 | `LOC = 38198:V(1) = 2:H(1) = 23:V(2) = 2:H(2) = 29:V(3) = 2:H(3) = 35:V(4) = 5:H(4) = 23:V(` |
| 50 | P | godot-remake/scripts/rules/com_rules.gd:66 | 5 | `V(7) = 8:H(7) = 23:V(8) = 8:H(8) = 29:V(9) = 8:H(9) = 35:V(10) = 11:H(10) = 23:V(11) = 11:` |
| 60 | P | godot-remake/scripts/rules/com_rules.gd:66 | 5 | `I = 1: FOR J1 = 1 TO 12:X = ST(J1)` |
| 65 | P | godot-remake/scripts/rules/com_rules.gd:66 | 5 | `FOR J = 1 TO 2` |
| 70 | P | godot-remake/scripts/rules/com_rules.gd:66 | 5 | `T =  PEEK (X): GOSUB 10000: VTAB V(I): HTAB H(I): READ T$: PRINT T$:V(I) = V(I) + 1: NEXT ` |
| 72 | P | godot-remake/scripts/rules/com_rules.gd:66 | 5 | `RESTORE : POKE 973,0` |
| 80 | P | godot-remake/scripts/rules/com_rules.gd:66 | 5 | `VTAB 15: HTAB 1: PRINT "  COMPUTER DISPLAY      DAMAGE CONTROL  ";: POKE 33,21: POKE 32,1:` |
| 90 | P | godot-remake/scripts/flight/command_console_program.gd:48 | 5 | `HCOLOR= 1: HPLOT 1,1 TO 139,1 TO 139,110 TO 1,110 TO 1,1` |
| 95 | P | godot-remake/scripts/flight/command_console_program.gd:48 | 5 | `PRINT` |
| 98 | L | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:78 | 5 | `IF  PEEK (38151) = 7 THEN  POKE 38151,0: POKE 974,64: PRINT "RUN GROUND FORCES"` |
| 100 | P | godot-remake/scripts/flight/command_console_program.gd:48 | 5 | `PRINT  TAB( 3);"COMMAND MODE": PRINT` |
| 110 | P | godot-remake/scripts/flight/command_console_program.gd:48 | 5 | `PRINT "1) COMPUTER": PRINT "2) GROUND FORCES": PRINT "3) RADAR": PRINT "4) END": PRINT "5)` |
| 115 | L | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:78 | 5 | `IF  PEEK (38151) = 7 THEN  POKE 974,64: POKE 38151,0: PRINT "RUN GROUND FORCES"` |
| 120 | L | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:93 | 5 | `PRINT "COMMAND?";: GET COM$:COM =  VAL (COM$): IF COM < 1 OR COM > 5 THEN  SPEED= 127: PRI` |
| 121 | P | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:93 | 5 | `POKE 974,64` |
| 127 | L | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:93 | 5 | `IF COM = 2 THEN  PRINT " ": PRINT "RUN GROUND FORCES"` |
| 128 | P | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:93 | 5 | `POKE 974,32: POKE 32,0: POKE 33,40: POKE 34,0: POKE 35,24` |
| 129 | L | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:93 | 5 | `PRINT " ": IF COM = 5 THEN J = 16: FOR X = 1 TO J: VTAB X: HTAB 1: PRINT "                ` |
| 130 | L | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:93 | 5 | `VTAB 1: IF COM = 5 THEN  POKE 974,64: PRINT "RUNSTARSHIP SIMULATOR"` |
| 131 | P | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:93 | 5 | `POKE 974,64` |
| 132 | L | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:93 | 5 | `IF COM = 4 THEN  PRINT "RUNEND"` |
| 133 | L | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:93 | 5 | `IF COM = 3 THEN  POKE 38388,2: PRINT "RUN RADAR"` |
| 135 | L | godot-remake/scripts/flight/command_console_program.gd:48<br>godot-remake/scripts/rules/com_rules.gd:93 | 5 | `POKE 974,32: IF COM = 1 THEN 200` |
| 140 | P |  |  | `GOTO 30` |
| 200 | P | godot-remake/scripts/flight/command_console_program.gd:66 | 5 | `POKE 974,32:R = 1: GOSUB 21: HOME` |
| 210 | P | godot-remake/scripts/flight/command_console_program.gd:66 | 5 | `PRINT  TAB( 1);"CENTRAL COMPUTER": PRINT` |
| 215 | L | godot-remake/scripts/flight/command_console_program.gd:66<br>godot-remake/scripts/rules/com_rules.gd:107 | 5 | `IF  PEEK (38196) = 0 THEN  PRINT "COMPUTER NOT": PRINT "FUNCTIONING.": FOR J = 1 TO 4000: ` |
| 220 | P | godot-remake/scripts/flight/command_console_program.gd:66 | 4 | `PRINT "1) NAVIGATION COMP.": PRINT "2) GALAXY DIRECTORY": PRINT "3) GALAXY MAP": PRINT "4)` |
| 260 | L | godot-remake/scripts/flight/command_console_program.gd:66<br>godot-remake/scripts/rules/com_rules.gd:113 | 4 | `PRINT "READY ";: GET C$:C =  VAL (C$): IF C < 1 OR C > 6 THEN  SPEED= 127: PRINT : PRINT "` |
| 265 | L | godot-remake/scripts/flight/command_console_program.gd:66<br>godot-remake/scripts/rules/com_rules.gd:113 | 4 | `IF C = 3 THEN  GOSUB 3000: GOTO 20` |
| 270 | L | godot-remake/scripts/flight/command_console_program.gd:66<br>godot-remake/scripts/rules/com_rules.gd:113 | 4 | `ON C GOTO 800,900,30,1200,20000` |
| 280 | L | godot-remake/scripts/flight/command_console_program.gd:66<br>godot-remake/scripts/rules/com_rules.gd:113 | 4 | `IF C = 6 THEN 12` |
| 390 | W |  | 2 | `RETURN` |
| 600 | P |  |  | `PRINT D$;"RUN STARSHIP SIMULATOR"` |
| 800 | P | godot-remake/scripts/flight/command_console_program.gd:97 | 2 | `R = 1: GOSUB 21: HOME` |
| 810 | P | godot-remake/scripts/flight/command_console_program.gd:97 | 2 | `PRINT "NAVIGATION COMPUTER": PRINT : PRINT : PRINT "1) DIRECTORY": PRINT "2) SET COURSE": ` |
| 830 | L | godot-remake/scripts/flight/command_console_program.gd:97 | 2 | `PRINT "READY ";: GET C$:C =  VAL (C$): IF C < 1 OR C > 3 THEN  SPEED= 127: PRINT : PRINT "` |
| 840 | L | godot-remake/scripts/flight/command_console_program.gd:97 | 2 | `IF C = 1 THEN 900` |
| 850 | L | godot-remake/scripts/flight/command_console_program.gd:97 | 2 | `IF C = 3 THEN 20` |
| 860 | P | godot-remake/scripts/flight/command_console_program.gd:109 | 2 | `R = 1: GOSUB 21: PRINT "NAVIGATION COMPUTER": PRINT : PRINT` |
| 870 | P | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `PRINT "ENTER DESIRED": PRINT "DESTINATION ";: VTAB 6: FOR J = 1 TO 2` |
| 871 | L | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `HTAB 1 + J: GET C$: IF C$ =  CHR$ (8) THEN J = J - 1: IF J <  = 0 THEN J = 1` |
| 872 | L | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `IF C$ =  CHR$ (8) THEN  VTAB 6: HTAB 1 + J: PRINT " ";: IF  LEN (C1$) = 1 THEN C1$ = "": V` |
| 873 | L | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `IF C$ =  CHR$ (8) AND  LEN (C1$) > 1 THEN C1$ =  LEFT$ (C1$,1): VTAB 6: GOTO 871` |
| 874 | L | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `IF C$ = CR$ THEN 876` |
| 875 | L | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `IF  ASC (C$) < 48 OR  ASC (C$) > 57 THEN  VTAB 6: GOTO 871` |
| 876 | P | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `VTAB 6: HTAB 1 + J: PRINT C$;:C1$ = C1$ + C$: NEXT :C =  VAL (C1$):C1$ = ""` |
| 877 | P | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `PRINT` |
| 878 | L | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `IF C > 20 OR C = 0 THEN  SPEED= 127: PRINT "<ERROR>": SPEED= 255: FOR C = 1 TO 5000: NEXT ` |
| 879 | L | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `IF C =  PEEK (38209) THEN  GOTO 895` |
| 880 | L | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `POKE 38163,C` |
| 890 | P | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 2 | `PRINT S$(C): PRINT "COURSE SET.": FOR C = 1 TO 3000: NEXT : GOTO 800` |
| 895 | P | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 | 1 | `SPEED= 127: PRINT "THAT'S WHERE WE": PRINT "ARE NOW, SIR!": FOR C = 1 TO 3000: NEXT : SPEE` |
| 897 | W | godot-remake/scripts/flight/command_console_program.gd:109<br>godot-remake/scripts/rules/com_rules.gd:118 |  | `SPEED= 127: PRINT "PLEASE ENTER YOUR": PRINT "DESTINATION AGAIN.": SPEED= 255: FOR C = 1 T` |
| 900 | P | godot-remake/scripts/flight/command_console_program.gd:131 | 3 | `HOME : POKE 32,0: POKE 33,40: POKE 34,0: POKE 35,15: HOME` |
| 910 | P | godot-remake/scripts/flight/command_console_program.gd:131 | 3 | `HCOLOR= 5: FOR C = 0 TO 123: HPLOT 0,C TO 279,C: NEXT : POKE 973,255` |
| 915 | P | godot-remake/scripts/flight/command_console_program.gd:131 | 3 | `VTAB 1` |
| 920 | P | godot-remake/scripts/flight/command_console_program.gd:131 | 3 | `HTAB 10: PRINT "** GALAXY DIRECTORY **": PRINT` |
| 930 | P | godot-remake/scripts/flight/command_console_program.gd:131 | 3 | `FOR C = 1 TO 13: HTAB 2: PRINT "                                      ": NEXT : VTAB 3` |
| 940 | P | godot-remake/scripts/flight/command_console_program.gd:131 | 3 | `FOR C = 1 TO 10: HTAB 2: PRINT C;")";S$(C);: HTAB 21: PRINT C + 10;")";S$(C + 10): NEXT : ` |
| 950 | L | godot-remake/scripts/flight/command_console_program.gd:131 | 3 | `HTAB 10: PRINT "READY ";: GET C$:C =  VAL (C$): IF C < 1 OR C > 2 THEN  GOTO 910` |
| 960 | P | godot-remake/scripts/flight/command_console_program.gd:131 | 3 | `POKE 973,0` |
| 969 | L | godot-remake/scripts/flight/command_console_program.gd:131 | 3 | `IF C = 2 THEN R = 2: GOSUB 20: GOTO 810` |
| 970 | P | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `POKE 973,255: VTAB 15: HTAB 10: PRINT "WHICH SYSTEM ";: FOR J = 1 TO 2` |
| 971 | L | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `HTAB 24 + J: VTAB 15: GET C$: IF C$ =  CHR$ (8) THEN J = J - 1: IF J =  < 0 THEN J = 1` |
| 972 | L | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `IF C$ =  CHR$ (8) THEN  VTAB 15: HTAB 24 + J: PRINT " ";: IF  LEN (C1$) = 1 THEN C1$ = "":` |
| 973 | L | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `IF C$ =  CHR$ (8) AND  LEN (C1$) > 1 THEN C1$ =  LEFT$ (C1$,1): VTAB 15: GOTO 971` |
| 974 | L | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `IF C$ = CR$ THEN 976` |
| 975 | L | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `IF  ASC (C$) < 48 OR  ASC (C$) > 57 THEN  VTAB 15: GOTO 971` |
| 976 | P | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `VTAB 15: HTAB 24 + J: PRINT C$;:C1$ = C1$ + C$: NEXT :C =  VAL (C1$):C1$ = ""` |
| 977 | P | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `VTAB 15: HTAB 10` |
| 978 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:130 | 3 | `IF C < 1 OR C > 20 THEN  SPEED= 127: PRINT "TRY AGAIN PLEASE.": SPEED= 255: FOR C = 1 TO 3` |
| 979 | P | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `POKE 32,1: POKE 33,39` |
| 980 | P | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `FOR C1 = 2 TO 15: VTAB C1: HTAB 2: PRINT "                                      ": NEXT : ` |
| 990 | P | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 3 | `PRINT  TAB( 5);S$(C);" STAR SYSTEM": PRINT` |
| 1005 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 3 | `IF  PEEK (38240 + C) = 0 THEN  PRINT "NO INFORMATION AVAILABLE AT THIS TIME.": PRINT : GOT` |
| 1007 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `IF  PEEK (38149) = 8 THEN  POKE 38149,0` |
| 1010 | P | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `PRINT "TECHNOLOGICAL DEVELOPMENT:"` |
| 1020 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `T =  PEEK (38282 + C)` |
| 1030 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `IF T = 0 THEN  PRINT "NO INTELLIGENT LIFEFORMS INDICATED."` |
| 1040 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `IF T = 1 THEN  PRINT "PRIMITIVE PSEUDO SOCIETY ONLY."` |
| 1050 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `IF T = 2 THEN  PRINT "LIMITED ATOMIC DEVELOPMENT"` |
| 1060 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `IF T = 3 THEN  PRINT "SOPHISTICATED TECHNOLOGY WITH": PRINT "STARSHIP CAPABILITY."` |
| 1070 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `IF T = 4 THEN  PRINT "ADVANCED CAPABILITY-SUPERIOR TO  OURS!"` |
| 1080 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `PRINT : IF  PEEK (38282 + C) < 2 THEN  GOTO 1110` |
| 1090 | P | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `PRINT "ORBITING DEFENSE CAPABILITY --": PRINT "FIGHTER PROTECTION PROBABLE."` |
| 1100 | P | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `REM` |
| 1110 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `PRINT "POPULATION = APPROX. "; PEEK (38261 + C) * 35294` |
| 1120 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `IF  PEEK (38219 + C) = 0 THEN 1140` |
| 1130 | P | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `PRINT S$(C);" HAS BEEN SECURED": GOTO 1150` |
| 1140 | P | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 1 | `PRINT S$(C);" IS INDEPENDENT."` |
| 1150 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `PRINT : IF  PEEK (38303 + C) = 0 THEN 1170` |
| 1160 | P | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:136 | 2 | `PRINT "THERE IS AN OPERATIONAL REPAIR BASE": PRINT "ON THE PLANET."` |
| 1170 | L | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `VTAB 15: PRINT "READY ";: GET C$` |
| 1172 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:174 | 3 | `POKE 973,0: IF  PEEK (38388) > 0 THEN  POKE 38388,0: PRINT " ": PRINT "RUN GALAXY MAP"` |
| 1175 | L | godot-remake/scripts/flight/command_console_program.gd:151<br>godot-remake/scripts/rules/com_rules.gd:174 | 3 | `IF R = 2 THEN R = 0: GOTO 3000` |
| 1180 | P | godot-remake/scripts/flight/command_console_program.gd:151 | 3 | `GOTO 900` |
| 1200 | P | godot-remake/scripts/rules/com_rules.gd:113 |  | `PRINT " ": PRINT "RUN STATUS"` |
| 3000 | P | godot-remake/scripts/rules/com_rules.gd:113 |  | `PRINT " ": PRINT "RUN GALAXY MAP"` |
| 3010 | P |  |  | `RETURN` |
| 10000 | W | godot-remake/scripts/rules/com_rules.gd:66 | 5 | `IF J1 = 7 AND  PEEK (ST(J1)) < 16 THEN  POKE 973,255: RETURN` |
| 10005 | L | godot-remake/scripts/rules/com_rules.gd:66 | 5 | `IF T = 0 THEN  POKE 973,255: RETURN` |
| 10010 | P | godot-remake/scripts/rules/com_rules.gd:66 | 5 | `POKE 973,0: RETURN` |
| 15000 | W | godot-remake/scripts/rules/com_rules.gd:66 |  | `DATA    "  1  "," ENG ","  2  "," ENG "," COMP","NO/GO"` |
| 15010 | W | godot-remake/scripts/rules/com_rules.gd:66 |  | `DATA  "RADAR","NO/GO"," ENV ","NO/GO"," HULL"," DMG "` |
| 15020 | W | godot-remake/scripts/rules/com_rules.gd:66 |  | `DATA  "POWER"," LOW "," SHLD","NO/GO","HYPER","DRIVE"` |
| 15030 | W | godot-remake/scripts/rules/com_rules.gd:66 |  | `DATA  " MSL ","NO/GO","LASER","NO/GO"," COM ","NO/GO"` |
| 15100 | W |  | 5 | `S$(1) = "SOL":S$(2) = "ALPHA CENTAURI":S$(3) = "BARNARD'S STAR":S$(4) = "WOLF 359":S$(5) =` |
| 15110 | P |  | 5 | `S$(6) = "LALANDE 21185":S$(7) = "SIRIUS":S$(8) = "VARCAR":S$(9) = "XANADON":S$(10) = "EPSI` |
| 15120 | P |  | 5 | `S$(11) = "CYGNI":S$(12) = "PROCYON":S$(13) = "TAU CETI":S$(14) = "LACAILLE 9352":S$(15) = ` |
| 15130 | P |  | 5 | `S$(16) = "GROOMBRIDGE 168":S$(17) = "KRUGER 60":S$(18) = "EPSILON INDI":S$(19) = "ARGO":S$` |
| 15140 | P | godot-remake/scripts/rules/com_rules.gd:66 | 5 | `ST(1) = 38198:ST(2) = 38197:ST(3) = 38196:ST(4) = 38195:ST(5) = 38194:ST(6) = 38193:ST(7) ` |
| 20000 | P | godot-remake/scripts/rules/com_rules.gd:113 |  | `PRINT " ": PRINT "RUN SUPPLY"` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
