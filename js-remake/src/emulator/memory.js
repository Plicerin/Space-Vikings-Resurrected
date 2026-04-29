/**
 * Apple II Memory System for Space Vikings
 * 
 * Handles Apple II memory mapping, BASIC interpreter, and game state
 * Based on analysis of memory addresses from disassembly
 */

class AppleIIMemory {
    constructor() {
        // 64KB RAM
        this.ram = new Uint8Array(0x10000);
        
        // ROM areas (Apple II specific)
        this.rom = new Uint8Array(0x10000);
        
        // Memory-mapped game state
        this.gameState = {
            // Game mechanics from BASIC analysis
            crewMorale: 0x03CE,      // $03CE (974)
            credits: 0x9541,         // $9541 (38209)
            coreState: 0x9516,       // $9516 (38166)
            joystickPos: 0x95FD,     // $95FD-$95FE (38397-38398)
            copyProtection: 0x95F7,  // $95F7 (38391)
            
            // Additional state locations discovered
            navigation: 0x9520,      // Navigation state
            combat: 0x9530,          // Combat state
            trading: 0x9540,         // Trading state
            shipStatus: 0x9550,      // Ship status
            
            // MEM TRANSFER A tables
            tableA: 0x8BEC,          // Source table (216 bytes)
            tableB: 0x8D7C,          // Destination table (216 bytes)
            transferCounter: 0x9532  // Counter for transfers
        };
        
        // Load actual Apple II ROM if available
        this.loadROM();
        
        // Initialize game state memory
        this.initializeGameState();
        
        // Track memory access for debugging
        this.accessLog = [];
        this.logEnabled = false;
    }
    
    /**
     * Load Apple II ROM (simplified for now)
     */
    loadROM() {
        // Apple II ROM starts at $D000-$FFFF
        // For now, just initialize with some defaults
        for (let i = 0xD000; i <= 0xFFFF; i++) {
            this.rom[i] = 0xFF; // Fill with NOPs
        }
        
        // Initialize some ROM routines
        // BASIC interpreter entry points
        this.rom[0xE000] = 0x4C; // JMP to BASIC cold start
        this.rom[0xE001] = 0x00;
        this.rom[0xE002] = 0xE0;
        
        console.log('Apple II ROM initialized');
    }
    
    /**
     * Initialize game state based on analysis
     */
    initializeGameState() {
        // Initialize key memory locations
        
        // Copy protection location - should be 77 ('M') on original disk
        this.ram[this.gameState.copyProtection] = 0x4D; // 'M'
        
        // Joystick positions (from STARSHIP SIMULATOR.bas)
        this.ram[this.gameState.joystickPos] = 128;     // Center X
        this.ram[this.gameState.joystickPos + 1] = 128; // Center Y
        
        // Initialize credits (38209)
        this.ram[this.gameState.credits] = 100; // Starting credits
        
        // Initialize crew morale (974)
        this.ram[this.gameState.crewMorale] = 50; // Starting morale
        
        // Initialize core game state
        this.ram[this.gameState.coreState] = 0x01; // Game active
        
        // Initialize MEM TRANSFER A tables
        for (let i = 0; i < 216; i++) {
            this.ram[this.gameState.tableA + i] = 0;
            this.ram[this.gameState.tableB + i] = 0;
        }
        
        // Initialize transfer counter
        this.ram[this.gameState.transferCounter] = 0;
        
        console.log('Game state memory initialized');
    }
    
    /**
     * Read from memory with Apple II specific handling
     * @param {number} address - 16-bit address
     * @returns {number} - Value at address
     */
    read(address) {
        if (address < 0 || address > 0xFFFF) {
            console.error(`Invalid memory read address: $${address.toString(16).toUpperCase()}`);
            return 0;
        }
        
        let value;
        
        // Handle memory regions
        if (address >= 0xD000 && address <= 0xFFFF) {
            // ROM region
            value = this.rom[address];
        } else if (address >= 0xC000 && address <= 0xCFFF) {
            // I/O region - handled by CPU
            value = this.handleIORead(address);
        } else {
            // RAM region
            value = this.ram[address];
        }
        
        // Log memory access if enabled
        if (this.logEnabled) {
            this.accessLog.push({
                type: 'read',
                address: address,
                value: value,
                timestamp: Date.now()
            });
            
            // Keep log manageable
            if (this.accessLog.length > 1000) {
                this.accessLog.shift();
            }
        }
        
        return value;
    }
    
    /**
     * Write to memory with Apple II specific handling
     * @param {number} address - 16-bit address
     * @param {number} value - Value to write
     */
    write(address, value) {
        if (address < 0 || address > 0xFFFF) {
            console.error(`Invalid memory write address: $${address.toString(16).toUpperCase()}`);
            return;
        }
        
        value = value & 0xFF; // Ensure byte value
        
        // Handle memory regions
        if (address >= 0xD000 && address <= 0xFFFF) {
            // ROM region - cannot write (ignored)
            console.warn(`Attempt to write to ROM at $${address.toString(16).toUpperCase()}`);
            return;
        } else if (address >= 0xC000 && address <= 0xCFFF) {
            // I/O region - handled by CPU
            this.handleIOWrite(address, value);
        } else {
            // RAM region
            this.ram[address] = value;
            
            // Check for game state updates
            this.checkGameStateUpdate(address, value);
        }
        
        // Log memory access if enabled
        if (this.logEnabled) {
            this.accessLog.push({
                type: 'write',
                address: address,
                value: value,
                timestamp: Date.now()
            });
            
            // Keep log manageable
            if (this.accessLog.length > 1000) {
                this.accessLog.shift();
            }
        }
    }
    
    /**
     * Handle I/O region reads (simplified)
     */
    handleIORead(address) {
        // Default implementation - CPU will override
        return 0;
    }
    
    /**
     * Handle I/O region writes (simplified)
     */
    handleIOWrite(address, value) {
        // Default implementation - CPU will override
        // Log I/O writes for debugging
        if (address >= 0xC000) {
            console.log(`I/O write: $${address.toString(16).toUpperCase()} = $${value.toString(16).toUpperCase()}`);
        }
    }
    
    /**
     * Check for game state updates and trigger events
     */
    checkGameStateUpdate(address, value) {
        // Crew morale change
        if (address === this.gameState.crewMorale) {
            this.onCrewMoraleChange(value);
        }
        
        // Credits change
        if (address === this.gameState.credits) {
            this.onCreditsChange(value);
        }
        
        // Joystick position update
        if (address === this.gameState.joystickPos) {
            this.onJoystickXChange(value);
        }
        if (address === this.gameState.joystickPos + 1) {
            this.onJoystickYChange(value);
        }
        
        // Copy protection check
        if (address === this.gameState.copyProtection) {
            this.onCopyProtectionChange(value);
        }
        
        // MEM TRANSFER A operations
        if (address === this.gameState.transferCounter) {
            this.onTransferCounterChange(value);
        }
    }
    
    /**
     * Event handlers for game state changes
     */
    onCrewMoraleChange(value) {
        console.log(`Crew morale updated: ${value}`);
        // Could trigger UI updates or game events
    }
    
    onCreditsChange(value) {
        console.log(`Credits updated: ${value}`);
        // Update credit display
    }
    
    onJoystickXChange(value) {
        console.log(`Joystick X updated: ${value}`);
        // Update ship position
    }
    
    onJoystickYChange(value) {
        console.log(`Joystick Y updated: ${value}`);
        // Update ship position
    }
    
    onCopyProtectionChange(value) {
        console.log(`Copy protection check: ${value} (${value === 0x4D ? 'Original' : 'Copy'})`);
        // Trigger copy protection routine if needed
    }
    
    onTransferCounterChange(value) {
        console.log(`Transfer counter updated: ${value}`);
        // Check if MEM TRANSFER A should execute
        if (value > 0 && value <= 128) {
            this.executeMemTransfer(value);
        }
    }
    
    /**
     * Execute MEM TRANSFER A routine ($9400)
     * Copies blocks between $8BEC and $8D7C tables
     */
    executeMemTransfer(count) {
        const source = this.gameState.tableA;
        const dest = this.gameState.tableB;
        const blockSize = 216; // Based on disassembly analysis
        
        console.log(`MEM TRANSFER A: Copying ${count} blocks (${blockSize} bytes each)`);
        
        for (let block = 0; block < count; block++) {
            const srcAddr = source + (block * blockSize);
            const dstAddr = dest + (block * blockSize);
            
            // Copy block
            for (let i = 0; i < blockSize; i++) {
                this.ram[dstAddr + i] = this.ram[srcAddr + i];
            }
        }
        
        console.log(`MEM TRANSFER A: Copied ${count * blockSize} bytes`);
    }
    
    /**
     * Load binary data into memory
     * @param {Uint8Array} data - Binary data
     * @param {number} baseAddress - Starting address
     * @param {boolean} isROM - Whether to load into ROM
     */
    loadBinary(data, baseAddress, isROM = false) {
        const target = isROM ? this.rom : this.ram;
        
        for (let i = 0; i < data.length; i++) {
            const addr = baseAddress + i;
            if (addr < 0 || addr > 0xFFFF) {
                console.error(`Binary load out of bounds at $${addr.toString(16).toUpperCase()}`);
                break;
            }
            target[addr] = data[i];
        }
        
        console.log(`Loaded ${data.length} bytes at $${baseAddress.toString(16).toUpperCase()} (${isROM ? 'ROM' : 'RAM'})`);
        return data.length;
    }
    
    /**
     * Load game components based on START.bas BLOAD addresses
     */
    loadGameComponents() {
        // Based on START.bas BLOAD commands:
        // BLOAD PLANET FILE,A$954C,L$AF
        // BLOAD P_F,A$97E1,L$140
        // BLOAD SHIP'S DATA,A$9506
        // BLOAD SHIP1,A$8000
        // etc.
        
        const components = {
            'PLANET FILE': { address: 0x954C, length: 0xAF },    // 175 bytes
            'P_F': { address: 0x97E1, length: 0x140 },           // 320 bytes
            'SHIPS DATA': { address: 0x9506, length: null },     // Variable
            'SHIP1': { address: 0x8000, length: null },          // Graphics
            'PLANET1': { address: 0x8000, length: null },        // Graphics
            // Add more based on actual files
        };
        
        console.log('Game component memory addresses loaded');
        return components;
    }
    
    /**
     * Get memory dump for debugging
     * @param {number} start - Start address
     * @param {number} length - Number of bytes
     * @returns {Array} - Array of [address, value] pairs
     */
    getMemoryDump(start, length) {
        const dump = [];
        for (let i = 0; i < length; i++) {
            const addr = start + i;
            if (addr > 0xFFFF) break;
            dump.push({
                address: addr,
                value: this.read(addr),
                hex: `$${this.read(addr).toString(16).toUpperCase().padStart(2, '0')}`
            });
        }
        return dump;
    }
    
    /**
     * Get game state summary
     */
    getGameState() {
        return {
            crewMorale: this.read(this.gameState.crewMorale),
            credits: this.read(this.gameState.credits),
            joystickX: this.read(this.gameState.joystickPos),
            joystickY: this.read(this.gameState.joystickPos + 1),
            copyProtection: this.read(this.gameState.copyProtection),
            coreState: this.read(this.gameState.coreState),
            navigation: this.read(this.gameState.navigation),
            combat: this.read(this.gameState.combat),
            trading: this.read(this.gameState.trading),
            shipStatus: this.read(this.gameState.shipStatus)
        };
    }
    
    /**
     * Set joystick position (for input system)
     */
    setJoystickPosition(x, y) {
        this.ram[this.gameState.joystickPos] = x;
        this.ram[this.gameState.joystickPos + 1] = y;
        
        // Trigger events
        this.onJoystickXChange(x);
        this.onJoystickYChange(y);
    }
    
    /**
     * Update credits (with bounds checking)
     */
    updateCredits(delta) {
        const current = this.read(this.gameState.credits);
        const newValue = Math.max(0, Math.min(255, current + delta));
        this.write(this.gameState.credits, newValue);
        return newValue;
    }
    
    /**
     * Update crew morale (with bounds checking)
     */
    updateCrewMorale(delta) {
        const current = this.read(this.gameState.crewMorale);
        const newValue = Math.max(0, Math.min(100, current + delta));
        this.write(this.gameState.crewMorale, newValue);
        return newValue;
    }
    
    /**
     * Enable/disable memory access logging
     */
    setLogging(enabled) {
        this.logEnabled = enabled;
        if (enabled) {
            this.accessLog = [];
            console.log('Memory access logging enabled');
        }
    }
    
    /**
     * Get access log for debugging
     */
    getAccessLog(filter = null) {
        if (!filter) return this.accessLog;
        
        return this.accessLog.filter(entry => {
            if (filter.type && entry.type !== filter.type) return false;
            if (filter.address && entry.address !== filter.address) return false;
            if (filter.minValue && entry.value < filter.minValue) return false;
            if (filter.maxValue && entry.value > filter.maxValue) return false;
            return true;
        });
    }
    
    /**
     * Save memory to file (for save games)
     */
    saveToFile() {
        // Convert RAM to ArrayBuffer for saving
        const buffer = this.ram.buffer;
        return buffer;
    }
    
    /**
     * Load memory from file (for load games)
     */
    loadFromFile(buffer) {
        const newRam = new Uint8Array(buffer);
        if (newRam.length !== this.ram.length) {
            console.error(`Invalid save file size: ${newRam.length}`);
            return false;
        }
        
        this.ram.set(newRam);
        console.log('Memory loaded from file');
        return true;
    }
}

module.exports = AppleIIMemory;