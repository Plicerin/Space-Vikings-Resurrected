# GROUND FORCES, RECALL and COLLECT, live

Recordings of the real disk in MAME by `tools/mame/ground_live.lua`, one
route a log: `ground_<route>.log`, with the two hi-res pages at each stop
(`ground_<route>_<nnn>_p1.bin`, `_p2.bin`; a stop's line names its files,
and a page that has not changed is not written again).

A stop is `ran <PROGRAM>` (the program's first statement), `at <line>`
(a statement begins on a listed line after one on another line, so a
GOSUB's return counts again) or `get <name>` (a GET waiting). Each has
the cursor, the window, 973, 974 and the watched bytes; `vars` under it
is the BASIC variables, `rnd` the values RND gave, in order.

Routes: menu (every key), gates (NO BASE, the two "troops on another
planet" refusals, RECALL's messages), leave and stale (38388 left set by
SHORE LEAVE's bounce), sol, tech_0 to tech_4, clamp, early_key (a key
during line 185), none (no transports; 38207 = 1 and 38208 = 1), twice
(a planet taken twice in one visit).

The port is not written yet. Times measured for it, in emulated ms (a
video frame is 16.67):

| what | ms |
|---|---|
| RUN GROUND FORCES from COM / from RECALL or SHORE LEAVE's bounce | 6028 / 5207-5385 |
| RUN RECALL, RUN COLLECT, RUN SHORE LEAVE | 2269, 2427, 7184 |
| RUN COM from line 75 or 310, COLLECT 17 / from 670 or 1130 (drive spinning) | 7240 / 6351-6363 |
| line 11: prompts at +956.5, +1188.9, +1208.0, line 12 at +1241 (RECALL: +1113.0, +1345.4, +1364.4, end +1397) | |
| line 12 (22 + 12 rows of 21.4), 13, 14, 30/40/50, 60 up to the GET | 282, 112, 24, 49 each, 40 |
| after the key: 60, 62, 65, line 12 again, 65, 66, 67, 70 | 6.5, 66, 4, 284, 23 (33 NO BASE), 18 (100), 18 (78), 11-14 |
| 100 (41 + 16 rows of 43.7), 110, 120, 130, 140, 145, 150, 170 (4 rows of 43.9) | 748, 81, 53, 62, 44, 30, 19, 186-189 |
| 172, 175, 177, 178-179 | 16, 9, 7, 23 |
| 180 (print, FOR 4000, print), 185 (FOR 2000 1865, print 35), 190 | 3878, 1900, 2622 |
| 195 + 170, 200-210 | 193, 19 |
| 220 / 230 + 170 / 740 | 71 / 3948 + 189 / 3835 |
| 300 / 305 | 140 / 3820 |
| 330 to 340 / 340 with, without the message / 350 | 2914 / 46, 9 / 3814 |
| 400 to 410 / 410 | 2914 / 3814 |
| 450 to 480 / 480 | 4271 / 3853 |
| 500-510, 550-600, 650 + 4000-4001, 4010, 4020-4030, the clicks, 1100 | 50, 294, 33, 75-83, 4, 30, 21 |
| 660-670 with nothing to do, 675, 680 | 14, 1877, 3.5 |
| surrender: 660 + 170, the rest of 660, 690 (FOR 5000 + 170), its print | 204, 69, 5006, 38 |
| MISC FILE written (800; inside 670 and 1120) | 3069-3083 |
| retreat: 1100-1120, 170, 1120's prints + write, 1121 | 42, 189, 3137, 10 |
| COLLECT: 0-11, 800-805, tech 1's text + its three sums, 810 | 24, 11, 100 + 78, 6874 |
| COLLECT: 15 (at SOL), 16 + 160-170, 16's prints | 53, 200, 40 |
