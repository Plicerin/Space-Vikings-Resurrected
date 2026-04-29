// Game State Manager for Space Vikings Remake
// Converts BASIC game state from $03CE, $9541, etc. to JavaScript objects

export class GameState {
  constructor() {
    this.initializeState();
  }

  initializeState() {
    // Memory-mapped state from original game
    this.state = {
      // $03CE - Crew morale (0-100)
      crewMorale: 50,
      
      // $9541 - Credits
      credits: 5000,
      
      // $95FD-$95FE - Joystick position values (from STARSHIP SIMULATOR.bas)
      joystickX: 0,
      joystickY: 0,
      
      // $95F7 - Copy protection check location
      protectionCheck: 0,
      
      // Game state from MEM TRANSFER A routine ($8BEC-$8D7C tables)
      memoryTables: {
        source: new Array(216).fill(0),  // $8BEC-$8D7C (216 bytes)
        destination: new Array(216).fill(0)  // Copy destination
      },
      
      // PLANET FILE data ($954C-$962A, 175 bytes)
      planetFile: {
        template: [0xFF, 0xFF, 0x01, 0x01],  // FF FF 01 01 pattern
        visitedFlags: new Array(21).fill(0),  // 21 planets visited status
        planetData: new Array(151).fill(0)    // Remaining planet data
      },
      
      // SHIP'S DATA
      shipData: {
        shipType: 0,
        weapons: [],
        cargo: [],
        crew: [],
        damage: 0
      },
      
      // Game overlay states (10 overlays)
      currentOverlay: 'START',
      overlayState: {}
    };
  }

  // Convert memory address to state property
  peek(address) {
    // Convert hex address to decimal for lookup
    const decAddress = parseInt(address, 16);
    
    switch(decAddress) {
      case 0x03CE: return this.state.crewMorale;
      case 0x9541: return this.state.credits;
      case 0x95FD: return this.state.joystickX;
      case 0x95FE: return this.state.joystickY;
      case 0x95F7: return this.state.protectionCheck;
      default: return 0;
    }
  }

  // Update state from memory address
  poke(address, value) {
    const decAddress = parseInt(address, 16);
    
    switch(decAddress) {
      case 0x03CE: this.state.crewMorale = value; break;
      case 0x9541: this.state.credits = value; break;
      case 0x95FD: this.state.joystickX = value; break;
      case 0x95FE: this.state.joystickY = value; break;
      case 0x95F7: this.state.protectionCheck = value; break;
    }
  }

  // Load PLANET FILE data
  loadPlanetFile(data) {
    if (data.length >= 175) {
      this.state.planetFile.template = data.slice(0, 4);
      this.state.planetFile.visitedFlags = data.slice(4, 25);
      this.state.planetFile.planetData = data.slice(25, 175);
    }
  }

  // MEM TRANSFER A routine simulation
  memTransfer(sourceStart, destStart, length) {
    const source = this.state.memoryTables.source;
    const dest = this.state.memoryTables.destination;
    
    for (let i = 0; i < length; i++) {
      dest[destStart + i] = source[sourceStart + i];
    }
  }

  // Save game state to JSON
  saveToJSON() {
    return JSON.stringify(this.state, null, 2);
  }

  // Load game state from JSON
  loadFromJSON(json) {
    this.state = JSON.parse(json);
  }
}