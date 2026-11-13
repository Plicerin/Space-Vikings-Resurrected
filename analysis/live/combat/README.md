# Combat recordings

`combat.log` is a MAME recording of STARSHIP SIMULATOR's fight pass
(lines 182–200) and of EX, DMG and S/X, made by `tools/mame/combat_live.lua`
(run it with the disk image; it puts a seeded series of states — ship
place and attitude, missile and shield bytes, edges of each box and
threshold — into the real program at line 182, and records the stop's
bytes and variables, every RND drawn, and which program ran next).

`godot-remake/tests/check_combat_rules.gd` replays each pass through
`scripts/rules/combat_rules.gd` and compares the bytes, DM/DP/L, the dice
count and the program that ended the pass. The series ends with the ship
lost (S/X), because S/X waits for a key and reboots the disk.

Mutation check (every comparison and constant in `combat_rules.gd` changed
in turn): 6 of 45 survive — the defender-damage byte cap, hull == 0 (a
destroyed hull is already the ship lost), the shield > 10 test, and four
numbers of the fighter pass's drawn path (its screen geometry, which the
native scene redraws anyway).
