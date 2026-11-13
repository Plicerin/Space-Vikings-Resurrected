# GALAXY MAP, live

- `chart_rules_live.log`: `tools/mame/chart_rules_live.lua`. A new game,
  C, 1, 3, then fifty probes: the paddles put to a place, the button
  pressed, `result` is BASIC's PX, PY and P a few seconds later, and the
  `ch` lines every character the chart printed (code, column, row).
  Probes: the cell of each of the twenty stars; for stars 1, 7, 13 and 20
  the cells one and two columns to each side and one and two rows
  above and one below; the four corners of the paddles' range. The `star`
  lines are the twenty stars' X, Y and Z as the game holds them.
- `chart_live.log`, `chart_loop_live.log`, `lines_live.log`: the earlier
  recording (tools/mame/chart_live.lua, chart_loop_live.lua), a click on
  SIRIUS and on empty space, the directory page and the way out, with
  every paddle read, glyph and BASIC line, used for the timings of the
  hi-res chart and now for the witness ledger. `chart_float_live.txt` is
  Applesoft's own `INT(PDL * 1.19)` and distances.
- `chart_clean_p1.bin` is hi-res page 1 as the chart was first drawn (the
  one page kept of the earlier recording's pages; git history has the
  rest). The rules' marks are checked against it: each isolated star's
  nine-by-nine neighbourhood holds the dots of its mark and is centred on
  the place the rules give.

The port keeps the rules and not the screen: `chart_rules.gd` is held
to the probes by `godot-remake/tests/check_chart_rules.gd`: where the
paddles put the cursor (to the dot), which star is under it (all 50, the
two that differ from a naive nearest-star guess among them), and what is
said, none different; 22 of 22 small changes to the rules fail it.
