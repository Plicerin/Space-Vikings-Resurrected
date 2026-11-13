# In appreciation of Mitchell Robbins, and of the code he left

*Space Vikings* was published by SubLOGIC in September 1982. It is © 1982 Mitchell Robbins; its
3D graphics package, A2-3D1, is © 1979 SubLOGIC Company. Nearly everything in this repository
exists because we wanted to understand how it was made, and the more we read, the more the
answer turned into admiration. This page is for that.

It is written from what the investigation found. Where a claim rests on a file, the file is
named, so it can be checked.

## What he had

An Apple II Plus with 48 KB of memory. A 1 MHz 6502 with no multiply instruction and no divide
instruction. A 140 KB floppy under DOS 3.3. A hi-res screen of 280 × 192 dots, six colours, and
an address layout so awkward that no two neighbouring lines are neighbours in memory. Joystick
or paddles. No debugger worth the name, no profiler, no version control, and a manual to be
printed and mailed from Champaign, Illinois.

## What he made

On that machine, a game that is at once a space war, a trading run and a conquest, across a
galaxy of twenty star systems:

- **A first-person space-combat simulator**, with a stick that banks, pitches and holds speed,
  a radar, and a cockpit of instruments that tell the truth (`STARSHIP SIMULATOR.bas`,
  `INSTRUMENTS`, `FLIGHT_CONTROL_AND_PROGRESSION_ANALYSIS.md`).
- **A real 3D engine at the centre of it.** A2-3D1 is a 4.75 KB library with a four-entry jump
  table and a small bytecode interpreter that separates *describing* a scene from *drawing*
  it. It builds a genuine 3×3 rotation matrix from a sine and cosine table, translates and
  rotates every vertex, clips against six planes with real parametric line-plane intersection,
  divides by depth for perspective, and draws with a Bresenham line plotter that rewrites its
  own instructions as it goes. All of its arithmetic is built from two hand-written
  primitives, one shift-and-add multiply and one shift-and-subtract divide, that everything
  else reuses (`A2-3D1_ENGINE_ANALYSIS.md`). It does this roughly a decade before the games
  usually credited with bringing real-time 3D to the desktop.
  (A2-3D1 is SubLOGIC's package; Robbins's game is what makes it a world.)
- **Judgment about where not to use it.** The same engine is too slow for a fight, so fighters
  are a hand-drawn flip-book with fake perspective, the laser is plain triangles, and an
  explosion is a scale-flash and a stamped shape (`COMBAT_VFX_ANALYSIS.md`). Knowing which
  corners can be cut, and cutting exactly those, is most of what real-time programming is.
- **A 597-byte combat loop** in assembly (`SPACE SIMULATOR ASSEMBLY`), with the sound routines
  and the hi-res character generator beside it, about 7 to 8 KB of machine code in all, and
  about 20 KB of Applesoft BASIC holding every rule of the game: nineteen overlays, one per
  screen, swapped in from disk as the player moves.
- **A persistent universe.** Twenty-one planets and four ship models loaded on demand; a
  ship's state, a planet file and a galaxy that survive being saved to a floppy. A saved game
  is marked by a single byte holding 77, which is ASCII `M`. We like to think it is his
  initial; that is a guess, not a finding.
- **Care at the edges.** A patched DOS error screen, so a stray keystroke in the wrong place
  ends in a tidy SYSTEM ERROR and a reboot rather than a crash. A supply report that shows
  ten pounds of platinum to the byte while the books keep the raw count. A flicker on the
  approaching fighters that we first took for an emulator artifact and then confirmed, in a
  live capture, as the real thing, because that is how the game looked.

## What it was like to read

We did not have the source. We had a cracked disk image, a photocopy of the A2-3D1 manual,
the game's own manual, and patience. From these we took the game apart: detokenised the BASIC;
disassembled and decompiled every machine-code binary; booted the real disk in an emulator and
recorded it; and traced, in the engine, a fixed-point sine table, a clipper and a perspective
divide, one routine at a time, until each claim could be pointed at.

The work humbled us in a particular way. Again and again an oddity that looked like a bug
turned out to be a decision: a quirk of the hi-res screen used as a feature, a value left
negative on purpose after a hard stop, a leftover mark from erasing a shape by drawing it
again. Three times our own confident hand-traces of the control flow were wrong and the code
was right. The lesson we kept is the one that gave this remake its method: *trust the machine,
and cite the line.*

## What this remake owes

- **The rules are his.** Every rule class in `godot-remake/scripts/rules/` reproduces his
  arithmetic and is held to recordings of the real game, and `tools/witness.py` makes sure
  that no line of his code is passed over without being cited or explicitly waived.
- **The look is ours.** The Apple's colours, its resolution and its disk habits stayed in 1982
  with the machine; Godot gives a modern picture and sound of the same game. We wanted the
  experience, not the limitations, and we say where we departed (`godot-remake/README.md`,
  "Liberties").
- **The credit is his.** The title screen names him and SubLOGIC. This is an unofficial fan
  remake, made out of respect for the original, and it is not a substitute for it. The real
  game is on the real disk, and the way to meet it is to boot it.

## And those who kept it

Software from this era survives only because people kept it: someone made the disk image and
removed its copy protection in 2017, someone scanned and shared the manuals and the A2-3D1
photocopy (see `README.md`, "Resources"), someone wrote the emulators that let a 1982 floppy
run on a laptop, and someone, many years ago, wrote the game and shipped it in the mail.
Thank you to all of them.

## What remains unknown

Honesty belongs in an appreciation too. A few lines of the original never ran in any
recording we made, and a handful of its overlays have not been fully traced; the ledgers in
`analysis/witness/` list exactly which. There may be more cleverness in there than we found.
If you find it, please add it here.
