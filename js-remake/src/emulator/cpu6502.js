/**
 * JavaScript 6502 CPU Emulator for Space Vikings Remake
 * 
 * Emulates Apple II 6502 CPU with memory-mapped I/O
 * Based on analysis of disassembled code from $9023, $9400, etc.
 */

class CPU6502 {
    constructor() {
        // Apple II has 64KB address space
        this.memory = new Uint8Array(0x10000);
        
        // 6502 registers
        this.registers = {
            A: 0,      // Accumulator
            X: 0,      // X index register
            Y: 0,      // Y index register
            PC: 0x600, // Program Counter (Apple II BASIC starts at $600)
            SP: 0xFF,  // Stack Pointer (Apple II uses page 1)
            P: 0x24    // Processor Status: 00100100 (Interrupt disable = 1)
        };
        
        // Cycle counter for timing accuracy
        this.cycles = 0;
        
        // Apple II specific I/O
        this.io = {
            // Speaker ($C030)
            speaker: 0,
            
            // Keyboard ($C000-$C00F)
            keyboard: new Uint8Array(16),
            
            // Graphics modes
            textMode: true,
            hiresMode: false,
            
            // Joystick/Game Controller (mapped to $95FD-$95FE)
            joystickX: 0,
            joystickY: 0,
            joystickButton: 0
        };
        
        // Initialize instruction set
        this.instructions = this.setupInstructions();
        
        // Load game state from analysis
        this.gameState = {
            // Memory-mapped game state locations
            crewMorale: 0x03CE,      // $03CE (974)
            credits: 0x9541,         // $9541 (38209)
            coreState: 0x9516,       // $9516 (38166)
            joystickPos: 0x95FD,     // $95FD-$95FE (38397-38398)
            copyProtection: 0x95F7   // $95F7 (38391)
        };
    }
    
    /**
     * Set up 6502 instruction set
     * Based on actual instructions found in disassembly
     */
    setupInstructions() {
        return {
            // Load/Store operations
            'LDA': this.insLDA.bind(this),
            'LDX': this.insLDX.bind(this),
            'LDY': this.insLDY.bind(this),
            'STA': this.insSTA.bind(this),
            'STX': this.insSTX.bind(this),
            'STY': this.insSTY.bind(this),
            
            // Arithmetic
            'ADC': this.insADC.bind(this),
            'SBC': this.insSBC.bind(this),
            'INC': this.inc.bind(this),
            'DEC': this.dec.bind(this),
            
            // Logic
            'AND': this.insAND.bind(this),
            'ORA': this.insORA.bind(this),
            'EOR': this.insEOR.bind(this),
            
            // Shifts
            'ASL': this.insASL.bind(this),
            'LSR': this.insLSR.bind(this),
            'ROL': this.insROL.bind(this),
            'ROR': this.insROR.bind(this),
            
            // Branches
            'BCC': this.insBCC.bind(this),
            'BCS': this.insBCS.bind(this),
            'BEQ': this.insBEQ.bind(this),
            'BNE': this.insBNE.bind(this),
            'BMI': this.insBMI.bind(this),
            'BPL': this.insBPL.bind(this),
            'BVC': this.insBVC.bind(this),
            'BVS': this.insBVS.bind(this),
            
            // Jumps/Subroutines
            'JMP': this.insJMP.bind(this),
            'JSR': this.insJSR.bind(this),
            'RTS': this.insRTS.bind(this),
            
            // Stack operations
            'PHA': this.insPHA.bind(this),
            'PHP': this.insPHP.bind(this),
            'PLA': this.insPLA.bind(this),
            'PLP': this.insPLP.bind(this),
            
            // Compare
            'CMP': this.insCMP.bind(this),
            'CPX': this.insCPX.bind(this),
            'CPY': this.insCPY.bind(this),
            
            // Transfer
            'TAX': this.insTAX.bind(this),
            'TAY': this.insTAY.bind(this),
            'TXA': this.insTXA.bind(this),
            'TYA': this.insTYA.bind(this),
            'TSX': this.insTSX.bind(this),
            'TXS': this.insTXS.bind(this),
            
            // Flags
            'CLC': this.insCLC.bind(this),
            'CLD': this.insCLD.bind(this),
            'CLI': this.insCLI.bind(this),
            'CLV': this.insCLV.bind(this),
            'SEC': this.insSEC.bind(this),
            'SED': this.insSED.bind(this),
            'SEI': this.insSEI.bind(this)
        };
    }
    
    /**
     * Load memory with binary data from disassembly
     * @param {Uint8Array} data - Binary data to load
     * @param {number} address - Starting address
     */
    loadBinary(data, address) {
        for (let i = 0; i < data.length; i++) {
            this.memory[address + i] = data[i];
        }
        console.log(`Loaded ${data.length} bytes at address $${address.toString(16).toUpperCase()}`);
    }
    
    /**
     * Emulate Apple II specific memory mapping
     * @param {number} address - Memory address
     * @returns {number} - Value at address
     */
    readMemory(address) {
        // Handle Apple II I/O space ($C000-$CFFF)
        if (address >= 0xC000 && address <= 0xCFFF) {
            return this.readIO(address);
        }
        
        // Handle game-specific memory locations
        switch(address) {
            case 0x95F7: // Copy protection location
                return this.memory[address];
                
            case 0x95FD: // Joystick X position
                return this.io.joystickX;
                
            case 0x95FE: // Joystick Y position
                return this.io.joystickY;
                
            default:
                return this.memory[address];
        }
    }
    
    /**
     * Write to memory with Apple II I/O handling
     * @param {number} address - Memory address
     * @param {number} value - Value to write
     */
    writeMemory(address, value) {
        // Handle Apple II I/O space
        if (address >= 0xC000 && address <= 0xCFFF) {
            this.writeIO(address, value);
            return;
        }
        
        // Game-specific memory handling
        this.memory[address] = value;
        
        // Log important game state changes
        switch(address) {
            case 0x03CE: // Crew morale
                console.log(`Crew morale updated: ${value}`);
                break;
                
            case 0x9541: // Credits
                console.log(`Credits updated: ${value}`);
                break;
                
            case 0x9516: // Core game state
                console.log(`Core game state updated: ${value}`);
                break;
        }
    }
    
    /**
     * Handle Apple II I/O reads
     */
    readIO(address) {
        switch(address) {
            case 0xC000: // Keyboard strobe
                return this.io.keyboard[0];
                
            case 0xC010: // Clear keyboard strobe
                this.io.keyboard[0] = 0;
                return 0;
                
            case 0xC030: // Speaker (toggles speaker)
                this.io.speaker ^= 1;
                return this.io.speaker;
                
            default:
                return 0;
        }
    }
    
    /**
     * Handle Apple II I/O writes
     */
    writeIO(address, value) {
        switch(address) {
            case 0xC000: // Keyboard
                this.io.keyboard[0] = value & 0x7F;
                break;
                
            case 0xC030: // Speaker
                this.io.speaker = value;
                // Generate sound based on SOUND GEN algorithm
                this.generateSound(value);
                break;
                
            // Graphics mode switches
            case 0xC050: // Graphics mode off (TEXT)
                this.io.textMode = true;
                this.io.hiresMode = false;
                break;
                
            case 0xC051: // Graphics mode on
                this.io.textMode = false;
                break;
                
            case 0xC056: // HGR mode on
                this.io.hiresMode = true;
                break;
                
            case 0xC057: // HGR mode off
                this.io.hiresMode = false;
                break;
        }
    }
    
    /**
     * Generate sound based on SOUND GEN algorithm at $9276
     */
    generateSound(parameter) {
        // Simplified version of SOUND GEN algorithm
        // Original uses XOR, ROR, ASL operations on $9270-$9275
        const frequency = (parameter * 100) + 100;
        const duration = 100; // milliseconds
        
        console.log(`SOUND GEN: freq=${frequency}Hz, dur=${duration}ms`);
        
        // In browser, this would trigger Web Audio API
        // For now, just log the sound event
        return {
            frequency,
            duration,
            type: 'sound'
        };
    }
    
    /**
     * Execute a single instruction
     */
    execute() {
        const opcode = this.readMemory(this.registers.PC);
        this.registers.PC++;
        
        // Decode and execute instruction
        const instruction = this.decode(opcode);
        if (instruction) {
            instruction.execute();
            this.cycles += instruction.cycles;
        } else {
            console.warn(`Unknown opcode: $${opcode.toString(16).toUpperCase()} at PC=$${this.registers.PC.toString(16).toUpperCase()}`);
        }
        
        return this.cycles;
    }
    
    /**
     * Decode opcode to instruction
     */
    decode(opcode) {
        // Simplified decoding - actual implementation would handle all 6502 opcodes
        const instructionMap = {
            0xA9: { name: 'LDA', mode: 'immediate', cycles: 2 },
            0xA5: { name: 'LDA', mode: 'zeroPage', cycles: 3 },
            0xAD: { name: 'LDA', mode: 'absolute', cycles: 4 },
            
            0x8D: { name: 'STA', mode: 'absolute', cycles: 4 },
            
            0x20: { name: 'JSR', mode: 'absolute', cycles: 6 },
            0x60: { name: 'RTS', mode: 'implied', cycles: 6 },
            
            0x4C: { name: 'JMP', mode: 'absolute', cycles: 3 },
            
            // Add more opcodes as needed
        };
        
        const info = instructionMap[opcode];
        if (!info) return null;
        
        return {
            name: info.name,
            mode: info.mode,
            cycles: info.cycles,
            execute: () => this.executeInstruction(info.name, info.mode)
        };
    }
    
    /**
     * Execute specific instruction
     */
    executeInstruction(name, mode) {
        const handler = this.instructions[name];
        if (handler) {
            handler(mode);
        }
    }
    
    // Instruction implementations
    insLDA(mode) {
        let value;
        switch(mode) {
            case 'immediate':
                value = this.readMemory(this.registers.PC);
                this.registers.PC++;
                break;
            case 'zeroPage':
                const zpAddr = this.readMemory(this.registers.PC);
                this.registers.PC++;
                value = this.readMemory(zpAddr);
                break;
            case 'absolute':
                const low = this.readMemory(this.registers.PC);
                this.registers.PC++;
                const high = this.readMemory(this.registers.PC);
                this.registers.PC++;
                const addr = (high << 8) | low;
                value = this.readMemory(addr);
                break;
        }
        
        this.registers.A = value;
        this.updateFlagsNZ(value);
    }
    
    insSTA(mode) {
        let addr;
        switch(mode) {
            case 'absolute':
                const low = this.readMemory(this.registers.PC);
                this.registers.PC++;
                const high = this.readMemory(this.registers.PC);
                this.registers.PC++;
                addr = (high << 8) | low;
                break;
        }
        
        this.writeMemory(addr, this.registers.A);
    }
    
    insJSR(mode) {
        // Push return address - 1 onto stack
        const returnAddr = this.registers.PC + 1;
        this.push((returnAddr >> 8) & 0xFF);
        this.push(returnAddr & 0xFF);
        
        // Jump to subroutine
        const low = this.readMemory(this.registers.PC);
        this.registers.PC++;
        const high = this.readMemory(this.registers.PC);
        this.registers.PC++;
        this.registers.PC = (high << 8) | low;
    }
    
    insRTS(mode) {
        // Pull return address from stack
        const low = this.pop();
        const high = this.pop();
        const returnAddr = (high << 8) | low;
        
        // Set PC to return address + 1
        this.registers.PC = returnAddr + 1;
    }
    
    // Stack operations
    push(value) {
        this.writeMemory(0x100 + this.registers.SP, value);
        this.registers.SP--;
        if (this.registers.SP < 0) this.registers.SP = 0xFF;
    }
    
    pop() {
        this.registers.SP++;
        if (this.registers.SP > 0xFF) this.registers.SP = 0;
        return this.readMemory(0x100 + this.registers.SP);
    }
    
    // Flag updates
    updateFlagsNZ(value) {
        // Negative flag
        this.setFlag('N', (value & 0x80) !== 0);
        // Zero flag
        this.setFlag('Z', value === 0);
    }
    
    setFlag(flag, set) {
        const flagBits = {
            'N': 7, // Negative
            'V': 6, // Overflow
            'B': 4, // Break
            'D': 3, // Decimal
            'I': 2, // Interrupt disable
            'Z': 1, // Zero
            'C': 0  // Carry
        };
        
        const bit = flagBits[flag];
        if (set) {
            this.registers.P |= (1 << bit);
        } else {
            this.registers.P &= ~(1 << bit);
        }
    }
    
    // More instruction implementations would go here...
    
    /**
     * Reset CPU to initial state
     */
    reset() {
        this.registers = {
            A: 0,
            X: 0,
            Y: 0,
            PC: 0x600,
            SP: 0xFF,
            P: 0x24
        };
        this.cycles = 0;
        console.log('CPU reset');
    }
    
    /**
     * Get current CPU state for debugging
     */
    getState() {
        return {
            registers: { ...this.registers },
            PC: `$${this.registers.PC.toString(16).toUpperCase()}`,
            SP: `$${this.registers.SP.toString(16).toUpperCase()}`,
            P: `$${this.registers.P.toString(16).toUpperCase()} (${this.registers.P.toString(2).padStart(8, '0')})`,
            cycles: this.cycles,
            memory: {
                'crewMorale': this.readMemory(0x03CE),
                'credits': this.readMemory(0x9541),
                'joystickX': this.readMemory(0x95FD),
                'joystickY': this.readMemory(0x95FE),
                'copyProtection': this.readMemory(0x95F7)
            }
        };
    }
}

module.exports = CPU6502;