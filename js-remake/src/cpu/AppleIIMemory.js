/**
 * Apple II Memory System Emulator
 * 
 * Handles Apple II memory mapping, BASIC integration, and game-specific
 * memory locations for Space Vikings.
 */

export default class AppleIIMemory {
    constructor() {
        // 64KB memory
        this.memory = new Uint8Array(0x10000);
        
        // Memory segments
        this.segments = {
            // Zero Page: $0000-$00FF
            zeroPage: 0x0000,
            
            // Stack: $0100-$01FF
            stack: 0x0100,
            
            // BASIC Program: $0800-$BFFF (typical)
            basicProgram: 0x0800,
            
            // Hi-Res Graphics Page 1: $2000-$3FFF
            hiresPage1: 0x2000,
            
            // Hi-Res Graphics Page 2: $4000-$5FFF
            hiresPage2: 0x4000,
            
            // Game Assembly Routines: $8000-$BFFF (from disassembly)
            assemblyRoutines: 0x8000,
            
            // I/O Area: $C000-$C0FF
            ioArea: 0xC000,
            
            // ROM: $E000-$FFFF
            rom: 0xE000
        };
        
        // Space Vikings specific memory locations (from reverse engineering)
        this.gameMemory = {
            // Assembly routine entry points
            0x9023: 'SPACE SIMULATOR ASSEMBLY entry',
            0x9276: 'SOUND GEN entry',
            0x92D1: 'LASER entry',
            0x9100: 'EXPL (explosion) entry',
            0x9400: 'MEM TRANSFER A entry (forward)',
            0x9434: 'MEM TRANSFER A entry (backward)',
            
            // Game state locations
            0x95FD: 'Joystick X position',
            0x95FE: 'Joystick Y position',
            0x95F7: 'Copy protection check (original: 77 = "M")',
            0x03CE: 'Crew morale',
            0x9541: 'Credits/money',
            
            // Data file loading addresses
            0x954C: 'PLANET FILE loading address (175 bytes)',
            0x97E1: 'P_F file loading address (320 bytes)',
            0x9506: 'SHIP\'S DATA loading address',
            
            // Memory transfer areas
            0x8BEC: 'MEM TRANSFER source table (216 bytes)',
            0x8D7C: 'MEM TRANSFER destination table (216 bytes)',
            0x9532: 'MEM TRANSFER counter/index'
        };
        
        // Initialize memory with known values
        this.init();
    }
    
    /**
     * Initialize memory with Apple II defaults
     */
    init() {
        // Clear all memory
        this.memory.fill(0);
        
        // Set up game-specific initial values
        // Copy protection check (original disk has 'M' at $95F7)
        this.memory[0x95F7] = 0; // Cracked version sets to 0
        
        // Initialize joystick positions
        this.memory[0x95FD] = 128; // Center X
        this.memory[0x95FE] = 128; // Center Y
        
        // Initialize crew morale
        this.memory[0x03CE] = 100;
        
        // Initialize credits
        this.memory[0x9541] = 1000;
        
        // Initialize MEM TRANSFER counter
        this.memory[0x9532] = 0;
        
        return this;
    }
    
    /**
     * Load binary data into memory
     * @param {Uint8Array} data - Binary data
     * @param {number} address - Starting address
     */
    loadBinary(data, address) {
        if (address + data.length > 0x10000) {
            throw new Error(`Memory overflow: trying to load ${data.length} bytes at $${address.toString(16).toUpperCase()}`);
        }
        
        this.memory.set(data, address);
        
        console.log(`Loaded ${data.length} bytes at $${address.toString(16).toUpperCase()}`);
        
        return this;
    }
    
    /**
     * Load Space Vikings assembly routine
     * @param {string} routineName - Name of routine
     * @param {Uint8Array} data - Binary data
     */
    loadAssemblyRoutine(routineName, data) {
        let address;
        
        switch (routineName) {
            case 'SPACE SIMULATOR ASSEMBLY':
                address = 0x9023;
                break;
            case 'SOUND GEN':
                address = 0x9276;
                break;
            case 'LASER':
                address = 0x92D1;
                break;
            case 'EXPL':
                address = 0x9100;
                break;
            case 'MEM TRANSFER A':
                address = 0x9400;
                break;
            default:
                throw new Error(`Unknown routine: ${routineName}`);
        }
        
        return this.loadBinary(data, address);
    }
    
    /**
     * Load game data file
     * @param {string} fileName - Name of file
     * @param {Uint8Array} data - Binary data
     */
    loadGameData(fileName, data) {
        let address;
        let expectedLength;
        
        switch (fileName) {
            case 'PLANET FILE':
                address = 0x954C;
                expectedLength = 175;
                break;
            case 'P_F':
                address = 0x97E1;
                expectedLength = 320;
                break;
            case 'SHIP\'S DATA':
                address = 0x9506;
                expectedLength = data.length; // Variable
                break;
            default:
                throw new Error(`Unknown data file: ${fileName}`);
        }
        
        if (expectedLength && data.length !== expectedLength) {
            console.warn(`Warning: ${fileName} expected ${expectedLength} bytes, got ${data.length}`);
        }
        
        return this.loadBinary(data, address);
    }
    
    /**
     * Read byte from memory (PEEK operation)
     * @param {number} address - Memory address
     * @returns {number} Value at address
     */
    peek(address) {
        if (address < 0 || address > 0xFFFF) {
            throw new Error(`Invalid memory address: $${address.toString(16).toUpperCase()}`);
        }
        
        return this.memory[address];
    }
    
    /**
     * Write byte to memory (POKE operation)
     * @param {number} address - Memory address
     * @param {number} value - Value to write (0-255)
     */
    poke(address, value) {
        if (address < 0 || address > 0xFFFF) {
            throw new Error(`Invalid memory address: $${address.toString(16).toUpperCase()}`);
        }
        
        if (value < 0 || value > 255) {
            throw new Error(`Invalid value: ${value}. Must be 0-255`);
        }
        
        this.memory[address] = value;
        
        // Log game state changes
        if (this.gameMemory[address]) {
            console.log(`POKE $${address.toString(16).toUpperCase()} = ${value} (${this.gameMemory[address]})`);
        }
        
        return this;
    }
    
    /**
     * Read word (16-bit) from memory (little-endian)
     * @param {number} address - Memory address
     * @returns {number} 16-bit value
     */
    peekWord(address) {
        if (address < 0 || address > 0xFFFE) {
            throw new Error(`Invalid memory address for word read: $${address.toString(16).toUpperCase()}`);
        }
        
        return this.memory[address] | (this.memory[address + 1] << 8);
    }
    
    /**
     * Write word (16-bit) to memory (little-endian)
     * @param {number} address - Memory address
     * @param {number} value - 16-bit value to write
     */
    pokeWord(address, value) {
        if (address < 0 || address > 0xFFFE) {
            throw new Error(`Invalid memory address for word write: $${address.toString(16).toUpperCase()}`);
        }
        
        if (value < 0 || value > 0xFFFF) {
            throw new Error(`Invalid word value: ${value}. Must be 0-65535`);
        }
        
        this.memory[address] = value & 0xFF;
        this.memory[address + 1] = (value >> 8) & 0xFF;
        
        return this;
    }
    
    /**
     * Copy memory block (MEM TRANSFER A routine emulation)
     * @param {number} source - Source address
     * @param {number} dest - Destination address
     * @param {number} length - Number of bytes to copy
     * @param {boolean} forward - Direction (true = forward, false = backward)
     */
    memTransfer(source, dest, length, forward = true) {
        if (forward) {
            for (let i = 0; i < length; i++) {
                this.memory[dest + i] = this.memory[source + i];
            }
        } else {
            // Backward copy (used by MEM TRANSFER A at $9434)
            for (let i = length - 1; i >= 0; i--) {
                this.memory[dest + i] = this.memory[source + i];
            }
        }
        
        console.log(`MEM TRANSFER: $${source.toString(16).toUpperCase()} -> $${dest.toString(16).toUpperCase()} (${length} bytes, ${forward ? 'forward' : 'backward'})`);
        
        return this;
    }
    
    /**
     * Dump memory region for debugging
     * @param {number} start - Start address
     * @param {number} end - End address
     * @param {number} bytesPerLine - Bytes per line in output
     */
    dumpMemory(start, end, bytesPerLine = 16) {
        console.log(`Memory dump $${start.toString(16).toUpperCase()} - $${end.toString(16).toUpperCase()}:`);
        
        for (let addr = start; addr <= end; addr += bytesPerLine) {
            const lineBytes = [];
            const lineChars = [];
            
            for (let i = 0; i < bytesPerLine && addr + i <= end; i++) {
                const byte = this.memory[addr + i];
                lineBytes.push(byte.toString(16).padStart(2, '0').toUpperCase());
                lineChars.push(byte >= 32 && byte <= 126 ? String.fromCharCode(byte) : '.');
            }
            
            console.log(
                `$${addr.toString(16).toUpperCase().padStart(4, '0')}: ` +
                lineBytes.join(' ') +
                '  ' +
                lineChars.join('')
            );
        }
    }
    
    /**
     * Get memory as array for saving/loading
     */
    getMemoryArray() {
        return new Uint8Array(this.memory);
    }
    
    /**
     * Set memory from array
     * @param {Uint8Array} array - Memory array
     */
    setMemoryArray(array) {
        if (array.length !== 0x10000) {
            throw new Error(`Invalid memory array length: ${array.length}, expected 65536`);
        }
        
        this.memory.set(array);
        return this;
    }
    
    /**
     * Get game state as object
     */
    getGameState() {
        const state = {};
        
        for (const [addr, description] of Object.entries(this.gameMemory)) {
            const numAddr = typeof addr === 'string' ? parseInt(addr) : addr;
            state[numAddr] = {
                value: this.memory[numAddr],
                description: description
            };
        }
        
        return state;
    }
    
    /**
     * Set game state from object
     * @param {Object} state - Game state object
     */
    setGameState(state) {
        for (const [addr, data] of Object.entries(state)) {
            const numAddr = typeof addr === 'string' ? parseInt(addr) : addr;
            if (numAddr >= 0 && numAddr <= 0xFFFF) {
                this.memory[numAddr] = data.value;
            }
        }
        
        return this;
    }
    
    /**
     * Reset memory to initial state
     */
    reset() {
        this.init();
        return this;
    }
    
    /**
     * Get memory statistics
     */
    getStats() {
        let used = 0;
        let zero = 0;
        
        for (let i = 0; i < this.memory.length; i++) {
            if (this.memory[i] !== 0) {
                used++;
            } else {
                zero++;
            }
        }
        
        return {
            total: this.memory.length,
            used,
            zero,
            usedPercent: ((used / this.memory.length) * 100).toFixed(2) + '%'
        };
    }
}