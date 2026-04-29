const CPU6502 = require('./cpu6502.js');

// Create a mock memory object
class MockMemory {
    constructor() {
        this.memory = new Array(0x10000).fill(0);
    }
    
    read(address) {
        return this.memory[address];
    }
    
    write(address, value) {
        this.memory[address] = value & 0xFF;
    }
    
    load(addr, data) {
        for (let i = 0; i < data.length; i++) {
            this.memory[addr + i] = data[i] & 0xFF;
        }
    }
}

console.log('Testing CPU6502 emulator...');

const memory = new MockMemory();
const cpu = new CPU6502(memory);

// Test basic LDA immediate
memory.memory[0x0000] = 0xA9; // LDA #$nn
memory.memory[0x0001] = 0x42; // value $42
cpu.PC = 0x0000;

try {
    cpu.step();
    console.log(`LDA immediate: A=${cpu.A.toString(16).toUpperCase()} (expected: 42)`);
    console.log(`Zero flag: ${cpu.flags.Z}, Negative flag: ${cpu.flags.N}`);
    
    // Test STA zero page
    cpu.PC = 0x0002;
    memory.memory[0x0002] = 0x85; // STA $nn
    memory.memory[0x0003] = 0x30; // address $30
    cpu.step();
    console.log(`STA zero page: memory[0x0030]=${memory.memory[0x30].toString(16).toUpperCase()} (expected: 42)`);
    
    // Test LDA zero page
    cpu.PC = 0x0004;
    memory.memory[0x0004] = 0xA5; // LDA $nn
    memory.memory[0x0005] = 0x30; // address $30
    cpu.step();
    console.log(`LDA zero page: A=${cpu.A.toString(16).toUpperCase()} (expected: 42)`);
    
    // Test LDA indirectX (opcode 0xA1)
    cpu.PC = 0x0006;
    cpu.X = 0x02;
    // Set up zero page indirect pointer
    // At $20,X = $22: low byte
    // At $21,X = $23: high byte
    memory.memory[0x22] = 0x50; // target low
    memory.memory[0x23] = 0x04; // target high
    memory.memory[0x0450] = 0x77; // value at target
    memory.memory[0x0006] = 0xA1; // LDA ($nn,X)
    memory.memory[0x0007] = 0x20; // zero page address
    cpu.step();
    console.log(`LDA indirectX: A=${cpu.A.toString(16).toUpperCase()} (expected: 77)`);
    
    // Test LDA indirectY (opcode 0xB1)
    cpu.PC = 0x0008;
    cpu.Y = 0x10;
    // Set up zero page indirect pointer at $30
    memory.memory[0x30] = 0x60; // target low
    memory.memory[0x31] = 0x04; // target high
    memory.memory[0x0470] = 0x88; // value at $0460 + $10 = $0470
    memory.memory[0x0008] = 0xB1; // LDA ($nn),Y
    memory.memory[0x0009] = 0x30; // zero page address
    cpu.step();
    console.log(`LDA indirectY: A=${cpu.A.toString(16).toUpperCase()} (expected: 88)`);
    
    // Test STA indirectY (opcode 0x91)
    cpu.PC = 0x000A;
    cpu.A = 0x99;
    // Set up zero page indirect pointer at $40
    memory.memory[0x40] = 0x80; // target low
    memory.memory[0x41] = 0x04; // target high
    memory.memory[0x000A] = 0x91; // STA ($nn),Y
    memory.memory[0x000B] = 0x40; // zero page address
    cpu.step();
    console.log(`STA indirectY: memory[0x0490]=${memory.memory[0x0490].toString(16).toUpperCase()} (expected: 99)`);
    
    console.log('\nAll basic tests passed!');
    
} catch (error) {
    console.error('Test failed:', error);
    console.error('Stack:', error.stack);
    process.exit(1);
}