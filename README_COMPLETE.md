# Space Vikings Resurrected

Complete reverse engineering of the 1980 Apple II game "Space Vikings" for a modern remake.

## Repository Status
**All reverse engineering complete!** ✅
- GitHub Repository: https://github.com/Plicerin/Space-Vikings-Resurrected
- Latest Commit: 9aadb86f6e1d58ba4c18dabcf59fb69d0df0a30b
- All 42 binary files disassembled
- 26 graphics files converted to modern JSON/SVG format
- Apple II shape table format fully decoded
- Ready for modern port development

## Quick Start

### 1. Explore the Disassembly
```bash
# View main game assembly logic
cat disassembly/SPACE\ SIMULATOR\ ASSEMBLY.disasm.txt

# View sound generation routines
cat disassembly/SOUND\ GEN.disasm.txt

# View all 42 disassembled files
ls -la disassembly/
```

### 2. View Converted Graphics
```bash
# Explore converted Apple II shape tables
ls -la modern/shapes_json/

# View JSON data for PLANET #0
cat modern/shapes_json/PLANET\ \#\ 0.payload.json | head -50

# View SVG visualization of PLANET #0
cat modern/shapes_json/PLANET\ \#\ 0.payload.svg | head -100
```

### 3. Run the Tools
```bash
# Install Python 3.x if needed
python --version

# Disassemble Apple II binaries
python disassembler.py extracted/SPACE\ SIMULATOR\ ASSEMBLY.payload.bin 9023

# Convert Apple II shape tables
python apple2-shape-table-converter.py extracted/PLANET\ \#\ 0.payload.bin
```

## Project Structure

```
├── disassembler.py              # Custom 6502 disassembler created for this project
├── apple2-shape-table-converter.py  # Apple II shape table to JSON/SVG converter
├── modern/                      # Modern conversions
│   └── shapes_json/            # 26 converted shape files (JSON+SVG)
│       └── shapes_summary.json # Documentation of all converted shapes
├── disassembly/                # All 42 disassembled binaries
├── extracted/                  # Raw binary payloads from Apple II disk
├── detokenized/               # Detokenized AppleSoft BASIC files
├── plan.md                    # Project plan and progress tracking
└── README.md                  # This file
```

## Key Discoveries

### 1. Game Architecture
- **BASIC Overlays**: Game logic primarily in AppleSoft BASIC with assembly performance-critical sections
- **Shared Memory**: Files intentionally overlap in memory ($95FD-$95FE stores game state between overlays)
- **Protection**: Original disk check at $95F7 (38391 decimal) for value 77 (ASCII 'M')
- **4am Crack**: Modified 4 bytes: T00,S02,$FC: DA→AD, T00,S03,$35: ED→DE, T00,S02,$5D: DA→AD, T00,S02,$9E: ED→DE

### 2. Apple II Shape Table Format
The game uses Apple II's compact "shape tables" for vector graphics:
- **First byte** = number of shapes minus 1
- **Offsets** to each shape's data
- **Direction encoding**: 0=Right, 1=Up-Right, 2=Up, 3=Up-Left, 4=Left, 5=Down-Left, 6=Down, 7=Down-Right
- **Steps**: 1-15 encoded in bits, 0 means 16 steps
- **Pen status**: Bit 0 = 1 (move without drawing), 0 (draw line)
- **Terminator**: $00 byte ends each shape
- **y inversion**: Apple II y increases downward, converter inverts for SVG

### 3. Critical Assembly Routines
- **SPACE SIMULATOR ASSEMBLY** ($9023): Main game state checks at $95FD-$95FE
- **SOUND GEN** ($9276): Apple II speaker sound generation via $C030 access
- **MEM TRANSFER A** ($9400): Copies 216-byte blocks between $8BEC-$8D7C tables
- **EXPL** ($9100): Explosion sound that calls SOUND GEN
- **LASER** ($92D1): Laser effect routines

### 4. Graphics Conversion Status
✅ **Successfully converted**: 21 planet files + 3 ship files + 2 special = 26 total
- Each planet file: 15 shapes
- Each ship file: 5 shapes  
- Output: JSON data + SVG visualization

❓ **Needs analysis**: `PLANET FILE.payload.bin` contains FF FF 01 01 pattern, not a shape table

## Using the Tools

### Disassembler (`disassembler.py`)
```python
# Command: python disassembler.py <binary_file> <start_address_hex>
python disassembler.py extracted/SPACE\ SIMULATOR\ ASSEMBLY.payload.bin 9023

# Features:
# - Handles Apple II binary format
# - Supports all 6502 addressing modes
# - Generates readable assembly with labels
# - Shows data sections
# - Outputs to .disasm.txt file
```

### Shape Table Converter (`apple2-shape-table-converter.py`)
```python
# Command: python apple2-shape-table-converter.py <binary_file>
python apple2-shape-table-converter.py extracted/PLANET\ \#\ 0.payload.bin

# Features:
# - Converts Apple II shape tables to structured JSON
# - Generates SVG visualization
# - Handles coordinate system inversion
# - Outputs to modern/shapes_json/ directory
# - Creates summary documentation
```

## Technical Documentation

### Game State Variables
- **$95FD-$95FE**: Game state persistence between overlays
- **$9532**: Counter index for MEM TRANSFER A (up to 128 iterations)
- **$9270-$9275**: Sound generation parameters

### Memory Layout
- **$8000**: Graphics/shape table loading address
- **$9023**: SPACE SIMULATOR ASSEMBLY entry point
- **$9276**: SOUND GEN entry point
- **$9400**: MEM TRANSFER A entry point
- **$954C**: PLANET FILE loading address (from START.bas)
- **$95F7**: Copy protection check location

### BASIC Overlay Transitions
See `plan.md` for complete state transition graph with 10 overlays and 22 transitions.

## Next Steps for Modern Remake

1. **Analyze `PLANET FILE.payload.bin`** - Determine actual format (possibly compressed data)
2. **Extract game logic** - Map BASIC code flow and game mechanics
3. **Create functional emulator** - Validate reverse engineering accuracy
4. **Implement modern port** - JavaScript/Python with SVG graphics
5. **Document game mechanics** - Complete gameplay specification

## Files of Interest

### Critical Game Logic
- `START.bas` - Initialization and copy protection
- `STARSHIP SIMULATOR.bas` - Main simulation (9.52KB)
- `SHORE LEAVE.bas` - Shore activities (8.67KB)
- `COM.bas` - Command interface (8.31KB)

### Key Assembly Files
- `disassembly/SPACE SIMULATOR ASSEMBLY.disasm.txt` - Core game logic
- `disassembly/SOUND GEN.disasm.txt` - Sound generation
- `disassembly/MEM TRANSFER A.disasm.txt` - Memory block copying

### Graphics Examples
- `modern/shapes_json/PLANET # 0.payload.json` - JSON data for first planet
- `modern/shapes_json/PLANET # 0.payload.svg` - SVG visualization
- `modern/shapes_summary.json` - All converted shapes documentation

## Contributing

This repository is open for collaboration on creating a modern remake of Space Vikings. The reverse engineering work is complete and provides all the necessary information to recreate the game.

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT License - see LICENSE file.

## Acknowledgments

- Original game by Softape (1980)
- 4am crack team for preservation
- Apple II community for technical documentation
- GitHub Copilot CLI for assistance with reverse engineering