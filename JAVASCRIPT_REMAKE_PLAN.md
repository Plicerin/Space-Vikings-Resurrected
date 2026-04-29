# JavaScript/Web Remake Implementation Plan

## Overview
Complete modern remake of "Space Vikings" (1982 Apple II game) as a JavaScript web application. Preserve original game logic while providing modern graphics, controls, and user experience.

## Technical Architecture

### Core Components
1. **6502 JavaScript Emulator** - CPU and memory emulation
2. **Game State Manager** - Memory-mapped state conversion
3. **Graphics Renderer** - Canvas + SVG rendering
4. **Input Handler** - Modern control system
5. **Audio System** - Web Audio API integration
6. **UI Framework** - Responsive web interface
7. **Save System** - Modern JSON save format
8. **Testing Framework** - Validation against original

## Phase 1: Core Emulation (4-6 weeks)

### 1.1 JavaScript 6502 Emulator
```javascript
// CPU emulator structure
class CPU6502 {
  constructor() {
    this.memory = new Uint8Array(0x10000); // 64KB Apple II memory
    this.registers = { A: 0, X: 0, Y: 0, PC: 0, SP: 0, P: 0 };
    this.instructions = this.setupInstructions();
  }
  
  // Emulate Apple II specific features
  emulateAppleII() {
    // I/O ports, keyboard, speaker ($C000-$CFFF)
    // Graphics modes: TEXT, HGR, HGR2
    // PEEK/POKE support for BASIC
  }
}
```

### 1.2 Memory Management
- **$0000-$BFFF**: Standard Apple II RAM
- **$C000-$CFFF**: I/O space (keyboard, speaker, graphics)
- **$D000-$FFFF**: ROM (BASIC, monitor, firmware)
- **Memory-mapped game state**: 
  - `$03CE` (974): Crew morale
  - `$9541` (38209): Credits/currency
  - `$9516` (38166): Core game state
  - `$95FD-$95FE` (38397-38398): Joystick positions

### 1.3 BASIC Interpreter Integration
- Parse detokenized BASIC code
- Map BASIC statements to JavaScript functions
- Handle GOTO, GOSUB, IF-THEN logic
- Support PEEK/POKE memory access

## Phase 2: Game Systems (6-8 weeks)

### 2.1 Navigation & Trading System
**Based on GALAXY MAP.bas and STARSHIP SIMULATOR.bas**
```javascript
class NavigationSystem {
  constructor() {
    this.galaxy = this.generateGalaxy();
    this.currentPosition = { sector: 0, system: 0 };
    this.fuel = 100;
    this.jumpDistance = 5;
  }
  
  // Navigation logic from original
  calculateJump(destination) {
    // Distance calculation
    // Fuel consumption
    // Random encounters
  }
  
  // Trading system
  tradeGoods(planet, goods) {
    // Economic simulation
    // Supply/demand fluctuations
    // Profit calculation
  }
}
```

### 2.2 Combat System
**Based on STARSHIP SIMULATOR.bas and GROUND FORCES.bas**
```javascript
class CombatSystem {
  constructor() {
    this.playerShip = {
      shields: 100,
      hull: 100,
      weapons: ['laser', 'missiles'],
      energy: 100
    };
    
    this.enemyAI = this.createEnemyAI();
  }
  
  // Space combat
  spaceCombat(enemy) {
    // Turn-based combat from original
    // Weapon targeting
    // Shield management
    // Damage calculation
  }
  
  // Ground combat
  groundCombat(planet, enemyForces) {
    // Troop deployment
    // Tactical positioning
    // Morale effects
  }
}
```

### 2.3 Crew Management System
**Based on SHORE LEAVE.bas and crew mechanics**
```javascript
class CrewSystem {
  constructor() {
    this.crew = [];
    this.morale = 100; // $03CE
    this.skills = {
      piloting: 0,
      gunnery: 0,
      engineering: 0,
      medical: 0
    };
  }
  
  // Shore leave activities
  shoreLeave(planet) {
    // Recreation options
    // Morale recovery
    // Random events
  }
  
  // Crew assignments
  assignCrew(station, crewMember) {
    // Skill checks
    // Efficiency calculation
    // Fatigue management
  }
}
```

## Phase 3: Graphics & Interface (4-6 weeks)

### 3.1 Graphics Renderer
**Using converted SVG graphics from modern/shapes_json/**
```javascript
class GraphicsRenderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.scaleFactor = 2; // Scale up from original 280x192
    
    // Load converted graphics
    this.graphics = {
      planets: this.loadPlanetGraphics(),
      ships: this.loadShipGraphics(),
      ui: this.loadUIGraphics()
    };
  }
  
  // Render Apple II shape tables
  renderShape(shapeData, x, y) {
    // Convert Apple II coordinates to Canvas
    // Apply modern shaders/effects
    // Handle animation frames
  }
  
  // Modern visual effects
  addVisualEffects() {
    // Particle systems for lasers/explosions
    // Lighting effects
    // Screen shake for impacts
  }
}
```

### 3.2 Modern UI Components
```javascript
class GameUI {
  constructor() {
    this.screens = {
      galaxyMap: new GalaxyMapScreen(),
      cockpit: new CockpitScreen(),
      status: new StatusScreen(),
      trading: new TradingScreen(),
      combat: new CombatScreen()
    };
    
    this.currentScreen = 'cockpit';
  }
  
  // Responsive layout
  updateLayout() {
    // Mobile/tablet/desktop layouts
    // Touch-optimized controls
    // Accessibility features
  }
  
  // Quality-of-life improvements
  addModernFeatures() {
    // Tooltips and tutorials
    // Quick save/load
    // Speed controls
    // Visual feedback
  }
}
```

## Phase 4: Audio & Input (2-4 weeks)

### 4.1 Web Audio System
**Porting SOUND GEN algorithm from $9276**
```javascript
class AudioSystem {
  constructor() {
    this.audioContext = new AudioContext();
    this.sounds = {
      laser: this.createLaserSound(),
      explosion: this.createExplosionSound(),
      engine: this.createEngineSound(),
      ui: this.createUISounds()
    };
    
    // Convert original SOUND GEN algorithm
    this.soundGenerator = this.convertSoundGen();
  }
  
  // Port Apple II speaker algorithm
  convertSoundGen() {
    // Original algorithm used XOR, ROR, ASL operations
    // Apple II speaker at $C030
    // Convert to Web Audio API oscillators and filters
  }
  
  // Modern sound design
  enhanceSounds() {
    // Spatial audio
    // Dynamic mixing
    // Volume controls
  }
}
```

### 4.2 Input System
```javascript
class InputSystem {
  constructor() {
    this.bindings = {
      moveUp: ['ArrowUp', 'W', 'GamepadUp'],
      moveDown: ['ArrowDown', 'S', 'GamepadDown'],
      fire: ['Space', 'Enter', 'GamepadA'],
      menu: ['Escape', 'GamepadStart']
    };
    
    // Convert joystick to modern inputs
    this.joystickMapping = {
      PDL(0): 'horizontal',
      PDL(1): 'vertical',
      BUTTON(0): 'fire'
    };
  }
  
  // Handle multiple input types
  handleInput(event) {
    // Keyboard
    // Mouse/Touch
    // Gamepad/Controller
    // Touch gestures
  }
  
  // Input customization
  configureControls() {
    // Rebindable keys
    // Sensitivity settings
    // Controller detection
  }
}
```

## Phase 5: Testing & Deployment (2-3 weeks)

### 5.1 Testing Framework
```javascript
class TestSuite {
  constructor() {
    this.tests = [];
    this.originalEmulator = this.setupAppleIIEmulator();
  }
  
  // Compare against original
  compareBehavior(testCase) {
    const originalResult = this.runOriginal(testCase);
    const remakeResult = this.runRemake(testCase);
    
    return this.validateMatch(originalResult, remakeResult);
  }
  
  // Automated validation
  validateGameMechanics() {
    // Navigation accuracy
    // Combat calculations
    // Economic simulation
    // Random number generation
  }
}
```

### 5.2 Deployment Strategy
- **GitHub Pages** hosting
- **Progressive Web App** features:
  - Offline capability
  - Installable on desktop/mobile
  - Save game synchronization
- **Analytics & monitoring**
- **Error reporting**

## Technical Requirements

### Development Stack
- **Frontend**: HTML5, CSS3, JavaScript (ES6+)
- **Graphics**: Canvas 2D, WebGL (optional)
- **Audio**: Web Audio API
- **Build**: Webpack, Babel
- **Testing**: Jest, Puppeteer
- **Deployment**: GitHub Actions, GitHub Pages

### Performance Targets
- 60 FPS on modern browsers
- < 5MB initial load
- < 100ms input latency
- Mobile-friendly (touch support)

### Compatibility
- Chrome, Firefox, Safari, Edge
- iOS Safari, Android Chrome
- Desktop, tablet, mobile

## File Structure
```
space-vikings-remake/
├── src/
│   ├── emulator/
│   │   ├── cpu6502.js
│   │   ├── memory.js
│   │   ├── basic-interpreter.js
│   │   └── apple-ii-io.js
│   ├── game/
│   │   ├── state-manager.js
│   │   ├── navigation.js
│   │   ├── combat.js
│   │   ├── trading.js
│   │   └── crew.js
│   ├── graphics/
│   │   ├── renderer.js
│   │   ├── shapes-loader.js
│   │   ├── effects.js
│   │   └── ui-components.js
│   ├── audio/
│   │   ├── sound-gen-converter.js
│   │   ├── audio-manager.js
│   │   └── music.js
│   ├── input/
│   │   ├── input-handler.js
│   │   ├── controls-mapper.js
│   │   └── gamepad.js
│   └── ui/
│       ├── screens/
│       ├── components/
│       └── layout-manager.js
├── assets/
│   ├── converted-graphics/
│   ├── sounds/
│   └── fonts/
├── tests/
│   ├── emulator-tests.js
│   ├── game-tests.js
│   └── integration-tests.js
├── docs/
│   ├── api/
│   └── mechanics/
└── public/
    ├── index.html
    ├── manifest.json
    └── service-worker.js
```

## Implementation Timeline
**Total: 14-20 weeks (part-time)**

### Phase 1: Core Emulation (4-6 weeks)
- Week 1-2: 6502 CPU emulator
- Week 3: Apple II memory/IO emulation
- Week 4: BASIC interpreter integration
- Week 5-6: Game state mapping

### Phase 2: Game Systems (6-8 weeks)
- Week 7-8: Navigation & trading
- Week 9-10: Combat system
- Week 11-12: Crew management
- Week 13-14: Mission system

### Phase 3: Graphics & Interface (4-6 weeks)
- Week 15-16: Graphics renderer
- Week 17: UI components
- Week 18: Modern effects

### Phase 4: Audio & Input (2-4 weeks)
- Week 19: Audio system
- Week 20: Input system

### Phase 5: Testing & Deployment (2-3 weeks)
- Week 21: Testing framework
- Week 22: Deployment & polish

## Key Technical Challenges

### 1. 6502 Timing Accuracy
Apple II games rely on precise timing for sound and graphics. Must emulate CPU cycles accurately.

### 2. BASIC Logic Conversion
Converting GOTO-based spaghetti code to structured JavaScript while preserving behavior.

### 3. Graphics Fidelity
Converting Apple II shape tables to modern graphics while preserving artistic intent.

### 4. Game State Synchronization
Ensuring memory-mapped state behaves identically between original and remake.

### 5. Performance Optimization
JavaScript emulation must be efficient enough for 60 FPS on all platforms.

## Success Metrics
1. **Functional Accuracy**: All game mechanics match original within 1%
2. **Performance**: 60 FPS on mid-range hardware
3. **Accessibility**: WCAG 2.1 AA compliance
4. **User Experience**: Modern controls and intuitive interface
5. **Preservation**: Faithful recreation of original gameplay feel

## Risk Mitigation

### Technical Risks
1. **Emulation complexity** - Start with minimal CPU emulator, expand gradually
2. **Performance issues** - Profile early, use Web Workers for heavy computation
3. **Browser compatibility** - Test on multiple browsers from day 1

### Scope Risks
1. **Feature creep** - Stick to original mechanics, defer enhancements
2. **Time estimation** - Regular progress reviews, adjust timeline as needed
3. **Quality assurance** - Automated testing from beginning

## Next Immediate Actions
1. **Set up development environment** with modern JavaScript tooling
2. **Create 6502 CPU emulator skeleton** with basic instructions
3. **Implement memory system** with Apple II memory map
4. **Load converted graphics** and verify rendering
5. **Create basic test harness** to validate against original

## Current Implementation Status
**Starting Phase 1: Core Emulation** - JavaScript 6502 Emulator
- Updating todos to reflect in_progress status
- Creating initial JavaScript files
- Testing with actual disassembled code

## References
- **Disassembled code**: `disassembly/` directory
- **Converted graphics**: `modern/shapes_json/` directory  
- **Memory layout**: `analysis/MEMORY_LAYOUT.md`
- **Game mechanics**: `GAME_MECHANICS_DOCUMENTATION.md`
- **Original BASIC**: `detokenized/` directory