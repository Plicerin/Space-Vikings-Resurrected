// Command Mode — port of COM.bas.
//
// The original screen splits 280 px wide between a Computer Display on the
// left (text menu) and a Damage Control panel on the right (12 cells in a
// 3x4 grid). Each cell carries a 2-line label; if the corresponding system
// is below ~16% efficiency the cell paints inverse / "white trouble light".
//
// This port renders the same layout via hires.text() at the same logical
// 24x40 grid the original used. Submenus (Computer, Nav, Galaxy Directory)
// re-enter from the main menu via inner functions.

import type { SceneContext, SceneManager } from '../engine/sceneManager';
import { drawTitle, drawOptions, drawPrompt, getChoice, drawBox, writeLines, clearLines } from '../engine/menu';
import type { GameState } from '../engine/gameState';
import { chooseCommanderScene } from '../engine/commander';

const PLANET_NAMES = [
  'SOL',
  'ALPHA CENTAURI',
  "BARNARD'S STAR",
  'WOLF 359',
  'LUYTEN',
  'LALANDE 21185',
  'SIRIUS',
  'VARCAR',
  'XANADON',
  'EPSILON ERIDANA',
  'CYGNI',
  'PROCYON',
  'TAU CETI',
  'LACAILLE 9352',
  'LARSEN-C',
  'GROOMBRIDGE 168',
  'KRUGER 60',
  'EPSILON INDI',
  'ARGO',
  'SHIVANDA',
];

// Damage Control panel labels (COM.bas:15000-15030 DATA statements).
// Each cell = 2 lines of 5 chars. 12 cells in a 3-col x 4-row grid.
const DAMAGE_LABELS: Array<[string, string]> = [
  ['  1  ', ' ENG '],
  ['  2  ', ' ENG '],
  [' COMP', 'NO/GO'],
  ['RADAR', 'NO/GO'],
  [' ENV ', 'NO/GO'],
  [' HULL', ' DMG '],
  ['POWER', ' LOW '],
  [' SHLD', 'NO/GO'],
  ['HYPER', 'DRIVE'],
  [' MSL ', 'NO/GO'],
  ['LASER', 'NO/GO'],
  [' COM ', 'NO/GO'],
];

function damageStatusFor(state: GameState, idx: number): number {
  // Map cell index to the corresponding subsystem percentage (or 100).
  switch (idx) {
    case 0: return state.damage.engine1Pct;
    case 1: return state.damage.engine2Pct;
    case 2: return state.damage.computerPct;
    case 3: return state.damage.radarPct;
    case 4: return state.damage.envPct;
    case 5: return state.damage.hullPct;
    case 6: return state.damage.powerPct;
    case 7: return state.damage.shieldsPct;
    case 8: return state.damage.hyperdrivePct;
    case 9: return state.damage.missilePct;
    case 10: return state.damage.laserPct;
    case 11: return state.damage.comsPct;
    default: return 100;
  }
}

function drawDamagePanel(ctx: SceneContext): void {
  const { hires, state } = ctx;
  // Right-side panel from x≈140 to x≈278, y≈0 to y≈110.
  drawBox(hires, 140, 1, 138, 109, 1);
  for (let i = 0; i < DAMAGE_LABELS.length; i++) {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const cellX = 21 + col * 6; // text-grid column
    const cellY = 2 + row * 3;
    const pct = damageStatusFor(state, i);
    const trouble = pct < 16; // white trouble light per manual
    if (trouble) hires.hcolor(3); // bright/white
    else hires.hcolor(1); // green = ok
    hires.text(DAMAGE_LABELS[i][0], cellX, cellY);
    hires.text(DAMAGE_LABELS[i][1], cellX, cellY + 1);
  }
  hires.hcolor(1);
  hires.text('  COMPUTER DISPLAY', 1, 15);
  hires.text('     DAMAGE CONTROL', 21, 15);
}

export async function comScene(ctx: SceneContext, scenes: SceneManager): Promise<void> {
  const { hires, state, input } = ctx;

  // Outer loop: redraw and accept choice each iteration.
  for (;;) {
    if (state.commanderMode) {
      const next = chooseCommanderScene(state);
      if (next) {
        return scenes.run(next);
      }
    }

    hires.hgr();
    drawDamagePanel(ctx);
    drawBox(hires, 1, 1, 138, 109, 6); // left panel (computer display) frame
    drawTitle(hires, 2, 4, 'COMMAND MODE');
    drawOptions(
      hires,
      [
        { key: '1', label: 'COMPUTER' },
        { key: '2', label: 'GROUND FORCES' },
        { key: '3', label: 'RADAR' },
        { key: '4', label: 'END' },
        { key: '5', label: 'RETURN' },
      ],
      4,
      2,
    );
    drawPrompt(hires, 11, 2);

    const c = await getChoice(input, hires, 1, 5);

    if (c === 1) {
      const exit = await computerSubmenu(ctx, scenes);
      if (exit === 'cockpit') return scenes.run('starshipSimulator');
      // else loop back to Command Mode
    } else if (c === 2) {
      // GROUND FORCES — sketch only
      return scenes.run('groundForces');
  } else if (c === 3) {
    return scenes.run('radar');
    } else if (c === 4) {
      return scenes.run('end');
    } else if (c === 5) {
      return scenes.run('starshipSimulator');
    }
  }
}

async function computerSubmenu(
  ctx: SceneContext,
  scenes: SceneManager,
): Promise<'cockpit' | 'continue'> {
  const { hires, state, input } = ctx;
  for (;;) {
    if (state.damage.computerPct < 16) {
      writeLines(hires, 2, 5, ['COMPUTER NOT', 'FUNCTIONING.']);
      await new Promise((r) => setTimeout(r, 2000));
      return 'continue';
    }
    hires.hgr();
    drawDamagePanel(ctx);
    drawBox(hires, 1, 1, 138, 109, 6);
    drawTitle(hires, 2, 2, 'CENTRAL COMPUTER');
    drawOptions(
      hires,
      [
        { key: '1', label: 'NAVIGATION COMP.' },
        { key: '2', label: 'GALAXY DIRECTORY' },
        { key: '3', label: 'GALAXY MAP' },
        { key: '4', label: 'SHIP STATUS' },
        { key: '5', label: 'SUPPLIES REPORT' },
        { key: '6', label: 'RETURN' },
      ],
      4,
      2,
    );
    drawPrompt(hires, 12, 2, 'READY');

    const c = await getChoice(input, hires, 1, 6);
    if (c === 1) {
      await navigationComputer(ctx);
    } else if (c === 2) {
      await galaxyDirectory(ctx);
    } else if (c === 3) {
      await scenes.run('galaxyMap');
      return 'continue';
    } else if (c === 4) {
      await scenes.run('status');
    } else if (c === 5) {
      await scenes.run('supply');
    } else if (c === 6) {
      return 'continue';
    }
  }
}

async function navigationComputer(ctx: SceneContext): Promise<void> {
  const { hires, state, input } = ctx;
  for (;;) {
    hires.hgr();
    drawDamagePanel(ctx);
    drawBox(hires, 1, 1, 138, 109, 6);
    drawTitle(hires, 2, 2, 'NAVIGATION COMPUTER');
    drawOptions(
      hires,
      [
        { key: '1', label: 'DIRECTORY' },
        { key: '2', label: 'SET COURSE' },
        { key: '3', label: 'RETURN' },
      ],
      4,
      2,
    );
    drawPrompt(hires, 9, 2, 'READY');

    const c = await getChoice(input, hires, 1, 3);
    if (c === 1) {
      await galaxyDirectory(ctx);
    } else if (c === 2) {
      const dest = await readNumeric(ctx, 2, 8, 'ENTER DESIRED DESTINATION');
      if (dest === null) continue;
      if (dest < 1 || dest > 20) {
        await flashMessage(ctx, '<ERROR>', 1500);
        continue;
      }
      const idx = dest - 1;
      if (idx === state.planetIndex) {
        await flashMessage(ctx, "THAT'S WHERE WE ARE NOW, SIR!", 2000);
        continue;
      }
      state.navDestination = idx;
      writeLines(hires, 2, 11, [PLANET_NAMES[idx], 'COURSE SET.']);
      await new Promise((r) => setTimeout(r, 1500));
    } else if (c === 3) {
      return;
    }
  }
}

async function galaxyDirectory(ctx: SceneContext): Promise<void> {
  const { hires, state, input } = ctx;
  for (;;) {
    drawComputerFullScreen(hires);
    hires.hcolor(3);
    hires.text('** GALAXY DIRECTORY **', 10, 1);
    for (let i = 0; i < 10; i++) {
      const left = `${i + 1})${PLANET_NAMES[i]}`;
      const right = `${i + 11})${PLANET_NAMES[i + 10]}`;
      hires.text(left.slice(0, 18), 2, 3 + i);
      hires.text(right.slice(0, 18), 21, 3 + i);
    }
    hires.hcolor(3);
    hires.text('1) DISPLAY PLANETARY DATA', 7, 14);
    hires.text('2) RETURN                ', 7, 15);
    drawPrompt(hires, 16, 10, 'READY');

    const c = await getChoice(input, hires, 1, 2, 16, 10);
    if (c === 2) return;

    const sys = await readGalaxyDirectorySystem(ctx);
    if (sys === null) continue;
    await displayPlanetaryData(ctx, sys - 1);
  }
}

async function displayPlanetaryData(ctx: SceneContext, idx: number): Promise<void> {
  const { hires, state, input } = ctx;
  drawComputerFullScreen(hires);
  hires.hcolor(3);
  hires.text(`${PLANET_NAMES[idx]} STAR SYSTEM`, 5, 2);

  const planet = state.planets[idx];
  hires.hcolor(3);
  if (!planet.visited && !planet.surrendered && idx !== state.planetIndex) {
    writeLines(hires, 2, 4, ['NO INFORMATION AVAILABLE AT THIS TIME.'], 3);
  } else {
    hires.text('TECHNOLOGICAL DEVELOPMENT:', 2, 4);
    const t = planet.defender;
    const techLines = [
      'NO INTELLIGENT LIFEFORMS INDICATED.',
      'PRIMITIVE PSEUDO SOCIETY ONLY.',
      'LIMITED ATOMIC DEVELOPMENT',
      'SOPHISTICATED TECHNOLOGY WITH',
      'ADVANCED CAPABILITY-SUPERIOR TO',
    ];
    hires.text(techLines[Math.min(t, 4)], 2, 5);
    if (t === 3) hires.text('STARSHIP CAPABILITY.', 2, 6);
    if (t === 4) hires.text(' OURS!', 2, 6);
    if (t >= 2) {
      hires.text('ORBITING DEFENSE CAPABILITY --', 2, 8);
      hires.text('FIGHTER PROTECTION PROBABLE.', 2, 9);
    }
    hires.text(`POPULATION = APPROX. ${planet.population * 35294}`, 2, 11);
    hires.text(
      planet.surrendered
        ? `${PLANET_NAMES[idx]} HAS BEEN SECURED`
        : `${PLANET_NAMES[idx]} IS INDEPENDENT.`,
      2,
      12,
    );
    if (planet.hasBase) {
      hires.text('THERE IS AN OPERATIONAL REPAIR', 2, 14);
      hires.text('BASE ON THE PLANET.', 2, 15);
    }
  }
  drawPrompt(hires, 15, 1, 'READY');
  await input.waitForKey();
}

function drawComputerFullScreen(hires: SceneContext['hires']): void {
  hires.hgr();
  hires.hcolor(5);
  for (let y = 0; y <= 123; y++) hires.hlin(0, 279, y);
}

async function readGalaxyDirectorySystem(ctx: SceneContext): Promise<number | null> {
  const { hires, input } = ctx;
  hires.hcolor(3);
  hires.text('WHICH SYSTEM ', 10, 15);
  let buf = '';
  for (;;) {
    hires.text(`${buf.padEnd(2, ' ')}`, 25, 15);
    const k = await input.waitForKey();
    const ch = k & 0x7f;
    if (ch === 0x0d) {
      const n = parseInt(buf, 10);
      if (!isNaN(n) && n >= 1 && n <= 20) return n;
      hires.text('TRY AGAIN PLEASE.    ', 10, 15);
      await new Promise((r) => setTimeout(r, 1200));
      hires.text('                    ', 10, 15);
      hires.text('  ', 25, 15);
      hires.text('WHICH SYSTEM ', 10, 15);
      buf = '';
      continue;
    }
    if (ch === 0x1b) return null;
    if (ch === 0x08 || ch === 0x7f) {
      buf = buf.slice(0, -1);
      continue;
    }
    if (ch >= 0x30 && ch <= 0x39 && buf.length < 2) {
      buf += String.fromCharCode(ch);
    }
  }
}

async function readNumeric(
  ctx: SceneContext,
  col: number,
  row: number,
  prompt: string,
): Promise<number | null> {
  const { hires, input } = ctx;
  hires.hcolor(5);
  hires.text(`${prompt}: __`, col, row);
  let buf = '';
  for (;;) {
    const k = await input.waitForKey();
    const ch = k & 0x7f;
    if (ch === 0x0d) {
      const n = parseInt(buf, 10);
      return isNaN(n) ? null : n;
    }
    if (ch === 0x1b) return null;
    if (ch === 0x08 || ch === 0x7f) {
      // Backspace
      buf = buf.slice(0, -1);
    } else if (ch >= 0x30 && ch <= 0x39 && buf.length < 2) {
      buf += String.fromCharCode(ch);
    }
    hires.text(`${prompt}: ${buf.padEnd(2, '_')}`, col, row);
  }
}

async function flashMessage(ctx: SceneContext, msg: string, ms: number): Promise<void> {
  const { hires } = ctx;
  hires.hcolor(2);
  clearLines(hires, 2, 16, 30, 2);
  hires.text(msg.padEnd(30), 2, 16);
  await new Promise((r) => setTimeout(r, ms));
  clearLines(hires, 2, 16, 30, 2);
}
