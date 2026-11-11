# END, live

Recordings of the real disk in MAME by `tools/mame/end_live.lua`: a new
game flown three passes, `C` into the console, `4` for END.

- `end_<route>.log`: statements, keys, pokes and a `-- get <name>` at each
  stop for a key, with the saved-game mark (38391) as it stood.
- `end_<route>_glyphs.log`: a line a character drawn on the screen,
  `<ms> <BASIC line> <code> <column> <row> ...` (column and row are the
  cursor before the character).

Routes: `menu` (keys 9, 0 and 4, which are no choice, a save with GAME SAVED.
up, "2" to continue), `atmosphere` (38210 poked to 1: the save refused, a
wrong digit, the poke taken off, "2"), `quit` ("3"), and ten `key_*`:
every other kind of key at the menu (space, RETURN, `.`, `+`, `-`, `,`,
`:`, a letter, `E`, ESC), which are the original's SYSTEM ERROR screen
and reboot, or a 0 for the ones Applesoft reads as a number.

The port keeps the rules and not the screen: `godot-remake/scripts/rules/
end_rules.gd` is held to `menu` and `atmosphere` by `godot-remake/tests/
check_end_rules.gd` (the menu's words each time it was drawn, the refusal,
GAME SAVED., and the mark after a "1": 12 comparisons, none different; 9 of
10 small changes to the rules fail it, the tenth being the port's own
"could not be saved"). The `key_*` and `quit` routes document what the
port does not keep (see the README's END section). The recordings once
held the hi-res pages and DOS's memory (`*_p1.bin`, `dos_9d00.bin`) and
the pictures of the error screen and the Apple's text characters; with
the screen no longer copied they are not kept (git history has them).

END's one machine-code call, line 210's `CALL 38825` (the per-planet record
copy), is accounted for by `@witness-asm 38825` in
`autoload/game_state.gd`: the first one the code witness has met.
