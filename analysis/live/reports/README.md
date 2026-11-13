# STATUS and SUPPLY, live

Recordings of the real disk in MAME by `tools/mame/reports_live.lua`: a
new game flown three passes, `C` into COM, the central computer, and
one of the two reports, with bytes poked into the game before it.

- `reports_<route>.log`: the program's statements, the keys, the pokes
  (`-- poke <address>=<value>`) and the line a `-- in flight` record
  gives of the bytes as the flight left them.
- `reports_<route>_glyphs.log`: a line a character drawn on the
  screen, `<ms> <BASIC line> <code> <column> <row> ...`, where column and
  row are the cursor before the character.

Routes: `status` (a new game), `status_poked` (every number another
one, and the two bytes of line 1386 both 0), `status_odd` (a condition,
a morale and a place that have no word, the energy over 100%),
`status_morale` (five visits, morale 2 to 6, the troops in each place,
condition BLUE), `supply` (a new game), `supply_poked` (every byte of
loot filled).

The port keeps the rules and not the screen:
`godot-remake/scripts/rules/report_rules.gd` is held to these by
`godot-remake/tests/check_report_rules.gd`, which puts together each
page the real game printed from its characters, sets the game as the
recording had it when the page was drawn, and compares. 20 pages: 18
compared and 2 left out because the original runs a line into the next
(`status_odd`'s words that do not exist; the rules print none).
Nineteen of twenty small changes to the rules each make it fail. The
one that does not (NAV.COMP. read from its byte, not shown as 100%) is
a quirk no recording moved the byte for.

What the recordings showed that the listing leaves open: ENV. and
NAV.COMP. are the number 100 whatever the ship's bytes hold (the new
game's environment byte is 128); line 1386, which prints THE TROOPS ARE
ALL DEAD!, goes by two bytes nothing in the game sets; the supply
report writes its unit over the end of a number of four digits or more.

The recordings once also held the hi-res pages (`*_p1.bin`) a byte
comparison used; with the screen no longer copied they are not kept
(git history has them).
