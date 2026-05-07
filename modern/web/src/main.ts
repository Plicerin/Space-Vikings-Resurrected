import { Hires } from './engine/hires';
import { SceneManager } from './engine/sceneManager';
import { GameState } from './engine/gameState';
import { Input } from './engine/input';
import { Audio } from './engine/audio';
import { Loader } from './engine/loader';
import { startScene } from './scenes/start';
import { shapeDemoScene } from './scenes/shapeDemo';
import { comScene } from './scenes/com';
import { statusScene } from './scenes/status';
import { supplyScene } from './scenes/supply';
import { instrumentsScene } from './scenes/instruments';
import { radarScene } from './scenes/radar';
import { hyperdriveScene } from './scenes/hyperdrive';
import {
  reentryScene,
  orbitScene,
  exScene,
  dmgScene,
  playerDeathScene,
} from './scenes/transitions';
import { cockpitScene } from './scenes/cockpit';
import { groundForcesScene } from './scenes/groundForces';
import { galaxyMapScene } from './scenes/galaxyMap';
import { endScene } from './scenes/end';
import { recallScene } from './scenes/recall';
import { collectScene } from './scenes/collect';
import { shoreLeaveScene } from './scenes/shoreLeave';
import { shipIdScene } from './scenes/shipId';
import { shipDebugScene } from './scenes/shipDebug';
import { initCopyButton } from './engine/gameLog';

// Initialize UI elements
initCopyButton();

const canvas = document.getElementById('stage') as HTMLCanvasElement;
const hires = new Hires(canvas);
const state = new GameState();
const input = new Input();
const audio = new Audio();
const loader = new Loader();

if (typeof window !== 'undefined') {
  (window as any).__spaceVikingsState = state;
}

const scenes = new SceneManager({ hires, state, input, audio, loader });
const resumeAudio = () => { void audio.resume(); };
window.addEventListener('pointerdown', resumeAudio, { passive: true });
window.addEventListener('keydown', resumeAudio, { passive: true });
window.addEventListener('touchstart', resumeAudio, { passive: true });

for (const el of document.querySelectorAll<HTMLButtonElement>('.touch-control')) {
  const code = el.dataset.code;
  if (!code) continue;
  const hold = el.dataset.hold === '1';

  const press = (ev: PointerEvent) => {
    ev.preventDefault();
    if (hold) input.pressHold(code);
    else input.press(code);
  };

  const release = () => {
    if (hold) input.releaseHold(code);
  };

  el.addEventListener('pointerdown', press);
  el.addEventListener('pointerup', release);
  el.addEventListener('pointerleave', release);
  el.addEventListener('pointercancel', release);
}

scenes.register('start', startScene);
scenes.register('shapes', shapeDemoScene);
scenes.register('com', comScene);
scenes.register('status', statusScene);
scenes.register('supply', supplyScene);
scenes.register('instruments', instrumentsScene);
scenes.register('radar', radarScene);
scenes.register('hyperdrive', hyperdriveScene);
scenes.register('groundForces', groundForcesScene);
scenes.register('galaxyMap', galaxyMapScene);
scenes.register('end', endScene);
scenes.register('starshipSimulator', cockpitScene);
scenes.register('reentry', reentryScene);
scenes.register('orbit', orbitScene);
scenes.register('ex', exScene);
scenes.register('dmg', dmgScene);
scenes.register('playerDeath', playerDeathScene);
scenes.register('recall', recallScene);
scenes.register('collect', collectScene);
scenes.register('shoreLeave', shoreLeaveScene);
scenes.register('shipId', shipIdScene);
scenes.register('shipDebug', shipDebugScene);

// Allow ?scene=<name> URL param to pick the scene; default 'start'.
const params = new URLSearchParams(window.location.search);
const initial = params.get('scene') || 'start';
scenes.run(initial).catch(err => console.error('[scene]', initial, 'crashed:', err));
