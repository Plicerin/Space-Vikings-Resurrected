# SHORE LEAVE, live

Recordings of the real disk in MAME by `tools/mame/shore_live.lua`, one
route a log: `shore_<route>.log`. No hi-res pages are kept; the port
does not copy the screen any more.

A stop is `ran <PROGRAM>` (the program's first statement), `at <line>`
(a statement begins on a listed line) or `get <name>` (a GET waiting).
Each has the watched bytes; `vars` under it is the BASIC variables,
`rnd` the values RND gave, in order, and the `line N "text"` records
between stops are what was printed. `key` and `enter` are what the
recorder typed, `poke a=b` a byte it changed (only ever at a GET of
GROUND FORCES' menu or of the console), and `set CR=n` the credits it
wrote into BASIC's own variable, which only `shore_edges` does: a price
is drawn afresh every time, so "exactly enough" can only be arranged
after the draw.

| route | what it goes through |
|---|---|
| `shore_gates` | a planet that has not surrendered (3 to 7 come straight back); 8) CRYOGENICS from each place the troops can be |
| `shore_pay` | 3) SHORE LEAVE: paid, refused, a key that is neither, pay of exactly the credits and of more; morale at both ends |
| `shore_loot` | 5) SELL LOOT: none, some, all there can be |
| `shore_base` | 7) ESTABLISH BASE: every refusal, N, Y |
| `shore_enlist` | 4) ENLIST TROOPS and the weapons after it: too dear, too many, 255 MAX, one time per trip, nothing at all |
| `shore_repair` | 6) REPAIR: not landed, paid, refused, nothing to mend, a bill that cannot be met |
| `shore_edges` | the last number each rule lets through and the first it does not: height 22 and 23, credits exactly the recruits, the weapons or the base, 255 of a weapon, troops left at another star |

The port keeps the rules and not the screen:
`godot-remake/scripts/rules/shore_rules.gd` is played through every
route here by `godot-remake/tests/check_shore_rules.gd` (the keys, the
numbers typed, the values RND gave, and at each stop the bytes, the
credits and troops, the price or bill, what was printed and how many
numbers RND had been asked for): 10588 comparisons, none different.
Each of 44 one-token changes to the rules (a `<` for a `<=`, a 255 for
a 256, an order of two tests) makes it fail; `shore_edges` was recorded
for the eight that at first did not.

What the recordings settled that the listing leaves open to a slip:

- the base's price is drawn (two numbers) before any refusal is looked
  at, and the one try a trip (38149) is spent by being told the price,
  whatever is answered;
- a weapon's price is drawn once and stays through every refusal;
- everything below its best is mended before the bill is put, and stays
  mended if it is not paid;
- GROUND FORCES' own line 14 sets the landing mark (38170 = 17) as the
  menu comes up when the ship is at height 20 in the atmosphere.

`shore_float_live.txt` is `tools/mame/shore_float_live.lua`'s answer
from Applesoft itself, on a bare Apple II+, to the two sums in the
repairs that need not come out whole. Its first line is line 2524-2525's
`INT((D2 / 100) * 100)` for every ENERGY from 0 to 62: the same 63
numbers as `floor((63 - D) * (100.0 / 63))` in the port's doubles. Its
second says whether line 2520's `100 - ((D / 100) * 100)` is exactly
`100 - D`; for D = 59 to 67, 69 to 71 and 80 to 99 it is not, by about
one part in 10^8 of a number that is then multiplied by at most 150 and
cut to a whole one. The port uses `100 - D`; a cost could differ by one
credit only where the product lands within 0.00001 of a whole number,
and every bill in the recordings comes out the same.

Times, in emulated ms: RUN SHORE LEAVE from the menu 7184; line 2099's
`FOR J = 1 TO 4000` before the menu is run again about 3800. The scene
(`godot-remake/scripts/ui/shore_leave.gd`) takes only its pauses from
these.
