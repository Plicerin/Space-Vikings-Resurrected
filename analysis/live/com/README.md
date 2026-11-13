# COM, live

Recordings of the real disk in MAME by `tools/mame/com_live.lua`: a new
game flown three passes, `C` into the console, and a route through its
screens.

- `com_<route>.log`: the program's statements, the keys, the pokes
  (`-- poke <address>=<value>`) and a `-- get <name>` at each stop for a key,
  with the bytes the console reads (38163 is the course).
- `com_<route>_glyphs.log`: a line a character drawn on the screen,
  `<ms> <BASIC line> <code> <column> <row> <973> <974> ...`, where column
  and row are the cursor before the character and 973 is 255 when it is
  drawn inverse (a lamp that is out).

Routes: `menus` (a wrong key at every menu, courses 25, 01, 05 and 7 with
RETURN, the directory, stars 30, 0, 2 and 1, its RETURN), `damaged`
(computer, radar and power poked low), `lamps` (each system's byte 0 in
turn, the power 15, 16 and 0, the console redrawn after each), `stars`
(every star scouted, some secured and with a base, the directory's page
of all twenty), `edges` (the computer at 1, a course to 20 and to 21,
the directory asked for 21 and then 20). `lamps`, `stars` and `edges`
write no hi-res pages.

The port keeps the rules and not the screen:
`godot-remake/scripts/rules/com_rules.gd` is held to these by
`godot-remake/tests/check_com_rules.gd`, which puts together each screen
the real game printed from its characters (the lamps with which were
inverse, the menus' words, what a course answered, the page of each star)
with the game set as the recording had it, and compares: 201 screens,
none different. 27 of 28 small changes to the rules make it fail; the
twenty-eighth is a double space the test does not compare.

The recordings once also held the hi-res pages (`*_p1.bin`, `_p2.bin`)
a byte comparison used; with the screen no longer copied they are not
kept (git history has them). Not run in any recording: the central
computer's 3, 4 and 5 (lines 3000, 1200, 20000), which run GALAXY MAP,
STATUS and SUPPLY; those programs' own recordings begin there.
