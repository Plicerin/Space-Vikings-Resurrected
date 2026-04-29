/**
 * 6502 CPU Emulator for Space Vikings Remake
 * 
 * This implements a 6502 processor emulator with Apple II memory mapping
 * Supports PEEK/POKE operations and BASIC interpreter integration
 */

export default class CPU6502 {
    constructor() {
        // 6502 Registers
        this.A = 0;        // Accumulator
        this.X = 0;        // X Register
        this.Y = 0;        // Y Register
        this.PC = 0x9023;  // Program Counter - default to SPACE SIMULATOR ASSEMBLY start
        this.SP = 0xFF;    // Stack Pointer
        this.STATUS = 0x20; // Status Register (bit 5 always 1)
        
        // Status Register bits
        this.FLAGS = {
            C: 0,  // Carry Flag
            Z: 0,  // Zero Flag
            I: 1,  // Interrupt Disable (default enabled)
            D: 0,  // Decimal Mode (Apple II doesn't use BCD)
            B: 0,  // Break Command
            V: 0,  // Overflow Flag
            N: 0   // Negative Flag
        };
        
        // Apple II Memory Map (64KB)
        this.memory = new Uint8Array(0x10000);
        
        // Game-specific memory locations
        this.gameState = {
            // Known memory addresses from reverse engineering
            0x95FD: 0,  // Joystick X position
            0x95FE: 0,  // Joystick Y position
            0x95F7: 0,  // Copy protection check (original: 77 = 'M')
            0x03CE: 0,  // Crew morale
            0x9541: 0,  // Credits/money
            // Add more as discovered
        };
        
        // Instruction set
        this.opcodes = new Map();
        this.setupOpcodes();
        
        // Performance tracking
        this.cycles = 0;
        this.instructionsExecuted = 0;
        
        // Debug mode
        this.debug = false;
    }
    
    /**
     * Initialize memory with Apple II ROM/RAM layout
     */
    initMemory() {
        // Zero out all memory
        this.memory.fill(0);
        
        // Initialize game state memory locations
        for (const [addr, value] of Object.entries(this.gameState)) {
            this.memory[addr] = value;
        }
        
        // Load BASIC ROM at $E000-$FFFF (optional)
        // For now, we'll handle BASIC via emulation layer
        
        return this;
    }
    
    /**
     * Set up 6502 instruction set
     */
    setupOpcodes() {
        // LDA - Load Accumulator
        this.opcodes.set(0xA9, () => this.ldaImmediate());  // LDA Immediate
        this.opcodes.set(0xAD, () => this.ldaAbsolute());   // LDA Absolute
        
        // STA - Store Accumulator
        this.opcodes.set(0x8D, () => this.staAbsolute());   // STA Absolute
        
        // JMP - Jump
        this.opcodes.set(0x4C, () => this.jmpAbsolute());   // JMP Absolute
        
        // RTS - Return from Subroutine
        this.opcodes.set(0x60, () => this.rts());
        
        // Basic arithmetic
        this.opcodes.set(0x69, () => this.adcImmediate());  // ADC Immediate
        
        // Compare instructions
        this.opcodes.set(0xC9, () => this.cmpImmediate());  // CMP Immediate
        
        // Branch instructions
        this.opcodes.set(0xD0, () => this.bne());           // BNE
        this.opcodes.set(0xF0, () => this.beq());           // BEQ
        
        // Add more opcodes as needed for Space Vikings
        // Based on disassembly analysis
    }
    
    /**
     * Load a binary file into memory
     * @param {Uint8Array} data - Binary data
     * @param {number} address - Starting address
     */
    loadBinary(data, address) {
        if (address + data.length > 0x10000) {
            throw new Error('Memory overflow');
        }
        
        this.memory.set(data, address);
        
        if (this.debug) {
            console.log(`Loaded ${data.length} bytes at $${address.toString(16).toUpperCase()}`);
        }
        
        return this;
    }
    
    /**
     * Execute a single instruction
     * @returns {number} Cycles taken
     */
    step() {
        const opcode = this.memory[this.PC];
        const instruction = this.opcodes.get(opcode);
        
        if (!instruction) {
            throw new Error(`Unknown opcode: $${opcode.toString(16).toUpperCase()} at PC: $${this.PC.toString(16).toUpperCase()}`);
        }
        
        // Execute instruction
        const cycles = instruction.call(this);
        
        // Update cycle count
        this.cycles += cycles;
        this.instructionsExecuted++;
        
        if (this.debug) {
            console.log(`PC: $${this.PC.toString(16).toUpperCase()} A: $${this.A.toString(16).toUpperCase()} X: $${this.X.toString(16).toUpperCase()} Y: $${this.Y.toString(16).toUpperCase()} SP: $${this.SP.toString(16).toUpperCase()} STATUS: $${this.STATUS.toString(16).toUpperCase()}`);
        }
        
        return cycles;
    }
    
    /**
     * Execute multiple instructions
     * @param {number} count - Number of instructions to execute
     */
    run(count = 1000) {
        for (let i = 0; i < count; i++) {
            try {
                this.step();
            } catch (e) {
                console.error(`Execution stopped at PC: $${this.PC.toString(16).toUpperCase()}: ${e.message}`);
                break;
            }
        }
        
        return this;
    }
    
    /**
     * PEEK operation - read memory location
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
     * POKE operation - write to memory location
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
        
        // Update game state tracking
        if (this.gameState.hasOwnProperty(address)) {
            this.gameState[address] = value;
        }
        
        return this;
    }
    
    /**
     * Get CPU state as object (for debugging/saving)
     */
    getState() {
        return {
            A: this.A,
            X: this.X,
            Y: this.Y,
            PC: this.PC,
            SP: this.SP,
            STATUS: this.STATUS,
            FLAGS: {...this.FLAGS},
            gameState: {...this.gameState},
            cycles: this.cycles,
            instructionsExecuted: this.instructionsExecuted
        };
    }
    
    /**
     * Set CPU state from object
     * @param {Object} state - CPU state object
     */
    setState(state) {
        this.A = state.A;
        this.X = state.X;
        this.Y = state.Y;
        this.PC = state.PC;
        this.SP = state.SP;
        this.STATUS = state.STATUS;
        this.FLAGS = {...state.FLAGS};
        this.gameState = {...state.gameState};
        this.cycles = state.cycles;
        this.instructionsExecuted = state.instructionsExecuted;
        
        // Update memory with game state
        for (const [addr, value] of Object.entries(this.gameState)) {
            this.memory[addr] = value;
        }
        
        return this;
    }
    
    // Instruction implementations
    ldaImmediate() {
        const value = this.memory[this.PC + 1];
        this.A = value;
        this.updateZeroNegativeFlags(this.A);
        this.PC += 2;
        return 2;
    }
    
    ldaAbsolute() {
        const addr = this.memory[this.PC + 1] | (this.memory[this.PC + 2] << 8);
        this.A = this.memory[addr];
        this.updateZeroNegativeFlags(this.A);
        this.PC += 3;
        return 4;
    }
    
    staAbsolute() {
        const addr = this.memory[this.PC + 1] | (this.memory[this.PC + 2] << 8);
        this.memory[addr] = this.A;
        this.PC += 3;
        return 4;
    }
    
    jmpAbsolute() {
        const addr = this.memory[this.PC + 1] | (this.memory[this.PC + 2] << 8);
        this.PC = addr;
        return 3;
    }
    
    rts() {
        const lo = this.memory[0x100 + this.SP + 1];
        const hi = this.memory[0x100 + this.SP + 2];
        this.PC = (hi << 8 | lo) + 1;
        this.SP += 2;
        return 6;
    }
    
    adcImmediate() {
        const value = this.memory[this.PC + 1];
        const result = this.A + value + this.FLAGS.C;
        this.FLAGS.C = result > 0xFF ? 1 : 0;
        this.FLAGS.V = ((this.A ^ result) & (value ^ result) & 0x80) ? 1 : 0;
        this.A = result & 0xFF;
        this.updateZeroNegativeFlags(this.A);
        this.PC += 2;
        return 2;
    }
    
    cmpImmediate() {
        const value = this.memory[this.PC + 1];
        const result = this.A - value;
        this.FLAGS.C = this.A >= value ? 1 : 0;
        this.updateZeroNegativeFlags(result & 0xFF);
        this.PC += 2;
        return 2;
    }
    
    bne() {
        const offset = this.memory[this.PC + 1];
        if (!this.FLAGS.Z) {
            this.PC += (offset & 0x80) ? offset - 256 : offset;
        }
        this.PC += 2;
        return 2 + (this.FLAGS.Z ? 0 : 1);
    }
    
    beq() {
        const offset = this.memory[this.PC + 1];
        if (this.FLAGS.Z) {
            this.PC += (offset & 0x80) ? offset - 256 : offset;
        }
        this.PC += 2;
        return 2 + (this.FLAGS.Z ? 1 : 0);
    }
    
    updateZeroNegativeFlags(value) {
        this.FLAGS.Z = (value === 0) ? 1 : 0;
        this.FLAGS.N = (value & 0x80) ? 1 : 0;
        this.updateStatusRegister();
    }
    
    updateStatusRegister() {
        this.STATUS = (this.FLAGS.N << 7) |
                     (this.FLAGS.V << 6) |
                     (1 << 5) |          // Bit 5 always 1
                     (this.FLAGS.B << 4) |
                     (this.FLAGS.D << 3) |
                     (this.FLAGS.I << 2) |
                     (this.FLAGS.Z << 1) |
                     this.FLAGS.C;
    }
    
    /**
     * Reset CPU to initial state
     */
    reset() {
        this.A = 0;
        this.X = 0;
        this.Y = 0;
        this.PC = 0x9023; // SPACE SIMULATOR ASSEMBLY start
        this.SP = 0xFF;
        this.STATUS = 0x20;
        this.FLAGS = {
            C: 0, Z: 0, I: 1, D: 0, B: 0, V: 0, N: 0
        };
        this.cycles = 0;
        this.instructionsExecuted = 0;
        
        return this;
    }
    
    /**
     * Enable/disable debug output
     */
    setDebug(enabled) {
        this.debug = enabled;
        return this;
    }
}