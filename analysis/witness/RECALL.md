# RECALL: the code witness

Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under
`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.

12 lines: 5 logic, 5 presentation, 2 waived. 5 lines cited by a rule; 0 of them never run in a recording.
Machine-code calls: none.

## Problems

none

## Cited, and never run in a recording (the listing alone)

none

## Every line

| line | | cited by | runs | listing |
|---|---|---|---|---|
| 0 | W |  | 3 | `ONERR  GOTO 63999` |
| 10 | P |  | 3 | `D$ =  CHR$ (4)` |
| 11 | W |  | 3 | `PRINT D$;"OPEN MISC FILE": PRINT D$;"READ MISC FILE": INPUT SD: INPUT TR: INPUT CR: PRINT ` |
| 12 | P |  | 3 | `POKE 974,32` |
| 20 | P |  | 3 | `HCOLOR= 1: HPLOT 1,1 TO 139,1 TO 139,110 TO 1,110 TO 1,1` |
| 2000 | L | godot-remake/scripts/rules/ground_rules.gd:215 | 3 | `PRINT : IF  PEEK (38209) <  >  PEEK (38158) AND  PEEK (38166) > 0 AND  PEEK (38166) < 3 TH` |
| 2005 | L | godot-remake/scripts/rules/ground_rules.gd:215 | 3 | `IF TR = 0 THEN  PRINT "WE HAVE NO TROOPS": PRINT "LEFT, SIR!": POKE 38166,0: GOTO 2050` |
| 2010 | L | godot-remake/scripts/rules/ground_rules.gd:215 | 2 | `IF  PEEK (38166) = 1 OR  PEEK (38166) = 2 THEN  PRINT "TROOPS ARE BEING": PRINT "RECALLED,` |
| 2020 | L | godot-remake/scripts/rules/ground_rules.gd:215 | 2 | `IF  PEEK (38166) = 3 THEN  PRINT "TROOPS ARE IN": PRINT "CRYOGENIC SLEEP!": GOTO 2050` |
| 2030 | L | godot-remake/scripts/rules/ground_rules.gd:215 | 1 | `IF  PEEK (38166) = 0 THEN  PRINT "TROOPS ARE ALREADY": PRINT "ON BOARD, SIR!": GOTO 2050` |
| 2050 | P |  | 3 | `POKE 974,64: PRINT D$;"RUN GROUND FORCES"` |
| 63999 | P |  |  | `PRINT : PRINT "INT"` |
