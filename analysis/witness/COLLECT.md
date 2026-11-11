# COLLECT: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

47 lines: 25 logic, 20 presentation, 2 waived. 36 lines cited by a rule; 2 of them never run in a recording.
Machine-code calls: none.

## Problems

none

## Cited, and never run in a recording (the listing alone)

820, 1090

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  | 5 | `ONERR  GOTO 63999` |
| 5 | P |  | 5 | `POKE 974,32` |
| 10 | P |  | 5 | `HTAB 1:D$ = ""` |
| 11 | L | godot-remake/scripts/rules/ground_rules.gd:235 | 5 | `TECH =  PEEK (38282 +  PEEK (38209))` |
| 13 | P |  | 5 | `GOSUB 800` |
| 15 | L | godot-remake/scripts/rules/ground_rules.gd:235 | 5 | `FOR J = 1 TO  PEEK (38209): READ S$: NEXT : RESTORE : SPEED= 255` |
| 16 | P | godot-remake/scripts/rules/ground_rules.gd:235 | 5 | `R4 = 1: GOSUB 160: VTAB 12: HTAB 1: PRINT "OPERATION ";S$;" IS A": PRINT "SUCCESS, SIR!"` |
| 17 | L | godot-remake/scripts/ui/ground_forces.gd:164 | 5 | `POKE 974,64: POKE 38151,7: PRINT "RUN COM"` |
| 160 | P |  | 5 | `POKE 973,255` |
| 170 | W |  | 5 | `FOR C = 12 TO 15: VTAB C: PRINT "                                       ": NEXT : VTAB 12:` |
| 800 | P | godot-remake/scripts/rules/ground_rules.gd:235 | 5 | `D$ = ""` |
| 802 | P | godot-remake/scripts/rules/ground_rules.gd:235 | 5 | `VTAB 12: HTAB 1` |
| 805 | P | godot-remake/scripts/rules/ground_rules.gd:235 | 5 | `ON TECH + 1 GOSUB 820,840,910,1070,1090` |
| 810 | P |  | 5 | `FOR J = 1 TO 7000: NEXT : RETURN` |
| 820 | P | godot-remake/scripts/rules/ground_rules.gd:235 |  | `PRINT "PLANET IS NON-HABITABLE.": PRINT "THERE IS NO LOOT TO GATHER, SIR."` |
| 830 | P |  |  | `RETURN` |
| 840 | P | godot-remake/scripts/rules/ground_rules.gd:235 | 1 | `PRINT "PLANET IS PRIMITIVE. THE ONLY LOOT": PRINT "IS A LITTLE GOLD AND SILVER AND SOME": ` |
| 850 | L | godot-remake/scripts/rules/ground_rules.gd:235 | 1 | `J =  PEEK (38183) + ( RND (1) * 5): IF J > 255 THEN J = 255` |
| 860 | L | godot-remake/scripts/rules/ground_rules.gd:235 | 1 | `POKE 38183,J` |
| 870 | L | godot-remake/scripts/rules/ground_rules.gd:235 | 1 | `F =  PEEK (38182) + ( RND (1) * 5): IF J > 255 THEN J = 255` |
| 880 | L | godot-remake/scripts/rules/ground_rules.gd:235 | 1 | `POKE 38182,J` |
| 890 | L | godot-remake/scripts/rules/ground_rules.gd:235 | 1 | `J =  PEEK (38173) + ( RND (1) * 10): IF J > 255 THEN J = 255` |
| 900 | L | godot-remake/scripts/rules/ground_rules.gd:235 | 1 | `POKE 38173,J: RETURN` |
| 910 | P | godot-remake/scripts/rules/ground_rules.gd:235 | 3 | `FOR J = 1 TO 4000: NEXT :R4 = 1: GOSUB 160: VTAB 12: HTAB 1: PRINT "PLANET IS IN THE LIMIT` |
| 915 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `IF J > 255 THEN J = 255` |
| 916 | P |  | 4 | `RETURN` |
| 920 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `IF  PEEK (301) = 1 THEN J1 = J1 * .6:J2 = J2 * .6` |
| 921 | P | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `POKE 301,1` |
| 925 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38183) + ( RND (1) * J2): GOSUB 915` |
| 930 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `POKE 38183,J` |
| 940 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38182) + ( RND (1) * J2): GOSUB 915: POKE 38182,J` |
| 950 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38181) + ( RND (1) * J2): GOSUB 915: POKE 38181,J` |
| 960 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38180) + ( RND (1) * J2): GOSUB 915: POKE 31180,J` |
| 970 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38179) + ( RND (1) * J1): GOSUB 915: POKE 38179,J` |
| 980 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38178) + ( RND (1) * J2): GOSUB 915: POKE 38178,J` |
| 990 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38177) + ( RND (1) * J2): GOSUB 915: POKE 38177,J` |
| 1000 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38176) + ( RND (1) * J1): GOSUB 915: POKE 38176,J` |
| 1010 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38175) + ( RND (1) * J1): GOSUB 915: POKE 38175,J` |
| 1020 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38174) + ( RND (1) * J2): GOSUB 915: POKE 38174,J` |
| 1030 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38173) + ( RND (1) * 20): GOSUB 915: POKE 38173,J` |
| 1040 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38172) + ( RND (1) * J2): GOSUB 915: POKE 38172,J` |
| 1050 | L | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `J =  PEEK (38171) + ( RND (1) * J1): GOSUB 915: POKE 38171,J` |
| 1060 | P | godot-remake/scripts/rules/ground_rules.gd:281 | 4 | `RETURN` |
| 1070 | P | godot-remake/scripts/rules/ground_rules.gd:235 | 1 | `PRINT "PLANET HAS A SOPHISTICATED TECHNOLOGY.": PRINT "WE'LL GET PLENTY OF LOOT HERE, SIR.` |
| 1090 | P | godot-remake/scripts/rules/ground_rules.gd:235 |  | `PRINT "PLANET HAS A SUPERIOR TECHNOLOGY.": PRINT "WE'VE HIT IT BIG THIS TIME, SIR!!!":J2 =` |
| 10000 | P |  |  | `DATA SOL,ALPHA CENTAURI,BARNARD'S STAR,WOLF 359,LUYTEN,LALANDE 21185,SIRIUS,VARCAR,XANADON` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
