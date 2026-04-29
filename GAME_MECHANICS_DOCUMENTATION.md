# Space Vikings Resurrected - Comprehensive Game Mechanics Documentation

## Executive Summary

Space Vikings is a 1982 Apple II space trading and combat game with multiple subsystems:
1. **Space Flight Simulator** - Navigation and piloting
2. **Trading System** - Resource buying/selling across planets
3. **Combat System** - Ship-to-ship and ground combat
4. **Exploration System** - Planet discovery and mapping
5. **Crew Management** - Hiring, training, morale
6. **Ship Customization** - Equipment, weapons, shields
7. **Mission System** - Contracts, bounties, special operations

## Core Systems Analysis

### 1. Navigation & Flight System
- **Input**: Joystick positions stored at $95FD (38397) and $95FE (38398)
- **Source**: STARSHIP SIMULATOR.bas: `J = PDL(1):K = PDL(0): POKE 38397,J: POKE 38398,K`
- **Game Logic**: Branches based on paddle values for movement, docking, combat

### 2. Trading System
**Key Memory Addresses:**
- **$9527 (38183)**: Wine/Liquor inventory quantity
- **$9526 (38182)**: Food inventory quantity  
- **$951D (38173)**: General goods inventory
- **$9513 (38163)**: Navigation coordinates/market prices
- **$9541 (38209)**: Most frequently accessed - likely credits/currency

**Trading Mechanics:**
- Prices fluctuate based on RNG (RND(1) * multiplier)
- Inventory caps at 255 units per item type
- Goods: Food, Wine/Liquor, General Goods
- Bulk trading with quantity adjustments (`.6` multiplier for discounts)

### 3. Combat System
**Ship Statistics:**
- **$9505 (38149)**: Ship status flags (9 references)
- **$9507 (38151)**: Mission/operation status (13 references)
- **$9516 (38166)**: Frequently modified combat state (20 references)

**Combat Resolution:**
- Random number generation for hit/miss calculations
- Damage proportional to weapon strength
- Shield absorption calculations
- Morale impact on combat effectiveness

### 4. Crew Management
**Morale & Training:**
- **$03CE (974)**: Crew morale/status (62 references)
- **$03CD (973)**: Training level/experience (31 references)
- Morale affects mission success rates
- Training improves combat and navigation skills

### 5. Mission System
**Mission Types Identified:**
1. **Transport Missions** - Deliver goods between planets
2. **Combat Missions** - Engage enemy ships/pirates
3. **Exploration Missions** - Discover new planets
4. **Rescue Missions** - Recover personnel/assets
5. **Bounty Missions** - Hunt specific targets

**Mission State Tracking:**
- **$9540 (38208)**: Current mission objective (14 references)
- **$9542 (38210)**: Mission progress/completion (15 references)

## Memory Architecture

### Game State Region ($9500-$97FF)

#### Ship Configuration ($9500-$950F)
```
$9505 (38149): Ship status flags         [9 refs]
$9506 (38150): SHIP'S DATA loading addr  [7 refs]
$9507 (38151): Mission/operation status  [13 refs]
$950B (38155): Weapon systems            [4 refs]
$950C (38156): Shield systems            [3 refs]
$950E (38158): Engine/thruster status    [4 refs]
```

#### Resource Management ($9510-$951F)
```
$9513 (38163): Navigation/market data    [9 refs]
$9516 (38166): Core game state           [20 refs]
$951D (38173): General goods inventory   [4 refs]
```

#### Financial System ($9540-$954F)
```
$9540 (38208): Mission objective         [14 refs]
$9541 (38209): Credits/currency          [33 refs] - MOST FREQUENT
$9542 (38210): Mission progress          [15 refs]
```

### Inventory System ($9520-$952F)
```
$9526 (38182): Food inventory            [RND(1)*5 adjustments]
$9527 (38183): Wine/Liquor inventory     [RND(1)*5 adjustments]
```

### Crew System ($03C0-$03FF)
```
$03CD (973):  Training level            [31 refs]
$03CE (974):  Crew morale               [62 refs] - MOST REFERENCED
```

## File Formats & Data Storage

### 1. PLANET FILE ($954C - 175 bytes)
**Template Format:** 42 repeating `FF FF 01 01` patterns
**Saved Game Format:**
- First 32 bytes: Visited flags (01=visited, 00=unvisited)
- Remaining bytes: Numeric game state (coordinates, resources, etc.)

### 2. P_F File ($97E1 - 320 bytes)
**Structure:** 20 records × 16 bytes each
**Record Format:**
- 2 word values (4 bytes)
- Flag (0/1) - indicates active record
- Record ID (1-20)
- 10 bytes reserved

**Active Records:** IDs 1, 4, 7, 8, 11, 12, 15 (flag=1)
**Purpose:** Likely mission/contract database

### 3. SHIP'S DATA ($9506 - variable size)
**Contents:** Ship statistics, cargo manifest, equipment state
**Size:** Varies by actual saved game file

### 4. Memory Transfer System ($9400-$95A6)
**Purpose:** State persistence between game sessions
**Buffers:** $8BEC-$8D7C (source) ↔ $8D7C-$8F0C (destination)
**Operation:** 216-byte block copying with $9532 counter

## Graphics System

### Shape Tables ($8000 loading address)
**26 Files Converted:** 21 planets + 3 ships + 2 special graphics
**Format Decoded:**
- First byte: Number of shapes minus 1
- Offsets table to each shape
- Vector drawing with 8 directions
- Pen up/down control via bit 0

**Direction Encoding:**
```
0: Right          4: Left
1: Up-Right       5: Down-Left  
2: Up             6: Down
3: Up-Left        7: Down-Right
```

## Sound System

### SOUND GEN ($9276)
**Core Routine:** Apple II speaker access via $C030
**Parameters:** $9270-$9275 memory locations
**Algorithm:** XOR, ROR, ASL operations for tone generation

### EXPL ($9100)
**Explosion Effects:** Calls SOUND GEN with specific parameters
**Non-critical path:** Can be emulated or replaced in modern port

## Protection System Analysis

### Original Protection ($95F7)
- Checks for value 77 (ASCII 'M') at $95F7 (38391)
- Triggers BSAVE PLANET FILE if protection passes
- Found in START.bas line 26

### 4am Crack Modifications
Modified 4 specific bytes on disk:
1. T00,S02,$FC: DA → AD
2. T00,S03,$35: ED → DE  
3. T00,S02,$5D: DA → AD
4. T00,S02,$9E: ED → DE

**Result:** Protection check passes without original disk

## Game Flow & State Transitions

### Overlay System (10 overlays)
**Transition Pattern:** `PRINT "\x04RUN X"` where X = next module
**Key Modules:**
1. START.bas - Initialization & protection
2. COM.bas - Command interface (8.31KB)
3. STARSHIP SIMULATOR.bas - Core flight (9.52KB)
4. SHORE LEAVE.bas - Planet activities (8.67KB)
5. GROUND FORCES.bas - Combat (7.24KB)
6. GALAXY MAP.bas - Navigation (4.15KB)
7. STATUS.bas - Ship status (2.82KB)

### Memory Sharing Strategy
- Files intentionally overlap in memory
- Must use BLOAD addresses from START.bas, not catalog addresses
- Shared state enables persistence across module transitions

## Modern Porting Strategy

### 1. Emulation Layer
- Replace 6502 assembly with JavaScript/Python equivalents
- Map Apple II memory addresses to modern object properties
- Emulate BASIC interpreter for game logic

### 2. Graphics Conversion
- Shape tables → SVG/Canvas drawing
- Maintain original vector aesthetics
- Add modern enhancements (shaders, animations)

### 3. Input System
- Joystick → Keyboard/Mouse/Gamepad
- Map paddle values to analog/digital inputs
- Preserve original response curves

### 4. State Management
- Convert memory blocks to JSON state objects
- Implement autosave/load system
- Add modern UI for state inspection/debugging

### 5. Sound System
- Sample-based replacement for Apple II speaker
- Optional authentic emulation mode
- Modern sound effects/music

## Technical Implementation Notes

### Critical Dependencies
1. **Joystick Values** ($95FD-$95FE) - Must be emulated for navigation
2. **Game State Region** ($9500-$97FF) - Core persistence area
3. **Memory Transfer** ($9400) - Essential for state saving
4. **Graphics Loading** ($8000) - Shape table format must be preserved

### Performance Considerations
- Apple II ran at ~1MHz with 48KB RAM
- Modern systems can easily emulate but must respect timing
- Original used disk swapping - modern can load instantly

### Testing Strategy
1. **Unit Tests** - Individual system emulation
2. **Integration Tests** - Module transitions
3. **Gameplay Tests** - Full mission completion
4. **Compatibility Tests** - Saved game compatibility

## Estimated Development Timeline

**Phase 1: Core Emulation (4-6 weeks)**
- Memory system emulation
- BASIC interpreter core
- Graphics conversion pipeline

**Phase 2: Game Systems (6-8 weeks)**
- Navigation/trading implementation
- Combat system recreation
- UI/UX modernization

**Phase 3: Polish & Testing (4-6 weeks)**
- Bug fixing
- Performance optimization
- Documentation

**Total: 14-20 weeks part-time for experienced developer**

## Conclusion

Space Vikings demonstrates sophisticated 1982 game design with:
- Complex state management across multiple overlays
- Detailed economic simulation with fluctuating markets
- Multiple interconnected gameplay systems
- Effective memory optimization for 48KB constraints

The game's modular architecture and clear memory layout make it exceptionally well-suited for modern recreation while preserving the original gameplay experience.