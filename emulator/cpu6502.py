#!/usr/bin/env python3
"""
6502 CPU emulator for Space Vikings reverse engineering.
"""

class CPU6502:
    def __init__(self):
        # Registers
        self.A = 0       # Accumulator
        self.X = 0       # X index register
        self.Y = 0       # Y index register
        self.PC = 0      # Program Counter
        self.SP = 0xFD   # Stack Pointer (Apple II page 1)
        self.P = 0x20    # Status register (initialized with Interrupt disabled)
        
        # Memory (64KB)
        self.memory = bytearray(0x10000)
        
        # Apple II specific memory locations
        # Speaker: $C030 (read or write toggles speaker)
        self.speaker_addr = 0xC030
        
        # Status register flags
        self.NEGATIVE = 0x80
        self.OVERFLOW = 0x40
        self.BREAK = 0x10
        self.DECIMAL = 0x08
        self.INTERRUPT = 0x04
        self.ZERO = 0x02
        self.CARRY = 0x01
        
        # Opcode table
        self.opcodes = {
            0x00: (self.BRK, 1, 7), 0x60: (self.RTS, 1, 6),
            0x18: (self.CLC, 1, 2), 0x38: (self.SEC, 1, 2),
            0xD8: (self.CLD, 1, 2), 0x58: (self.CLI, 1, 2),
            0xB8: (self.CLV, 1, 2), 0x78: (self.SEI, 1, 2),
            0xE8: (self.INX, 1, 2), 0xC8: (self.INY, 1, 2),
            0xCA: (self.DEX, 1, 2), 0x88: (self.DEY, 1, 2),
            0xAA: (self.TAX, 1, 2), 0xA8: (self.TAY, 1, 2),
            0x8A: (self.TXA, 1, 2), 0x98: (self.TYA, 1, 2),
            0x9A: (self.TXS, 1, 2), 0xBA: (self.TSX, 1, 2),
            0x48: (self.PHA, 1, 3), 0x68: (self.PLA, 1, 4),
            0x08: (self.PHP, 1, 3), 0x28: (self.PLP, 1, 4),
            0x69: (self.ADC, 2, 2), 0x65: (self.ADC, 2, 3),
            0xE9: (self.SBC, 2, 2), 0xE5: (self.SBC, 2, 3),
            0x29: (self.AND, 2, 2), 0x25: (self.AND, 2, 3),
            0x49: (self.EOR, 2, 2), 0x45: (self.EOR, 2, 3),
            0x09: (self.ORA, 2, 2), 0x05: (self.ORA, 2, 3),
            0xC9: (self.CMP, 2, 2), 0xC5: (self.CMP, 2, 3),
            0xE0: (self.CPX, 2, 2), 0xE4: (self.CPX, 2, 3),
            0xC0: (self.CPY, 2, 2), 0xC4: (self.CPY, 2, 3),
            0x24: (self.BIT, 2, 3), 0x2C: (self.BIT, 3, 4),
            0xA9: (self.LDA, 2, 2), 0xA5: (self.LDA, 2, 3),
            0xA2: (self.LDX, 2, 2), 0xA6: (self.LDX, 2, 3),
            0xA0: (self.LDY, 2, 2), 0xA4: (self.LDY, 2, 3),
            0x85: (self.STA, 2, 3), 0x86: (self.STX, 2, 3),
            0x84: (self.STY, 2, 3), 0x95: (self.STA, 2, 4),
            0x96: (self.STX, 2, 4), 0x94: (self.STY, 2, 4),
            0x8D: (self.STA, 3, 4), 0x8E: (self.STX, 3, 4),
            0x8C: (self.STY, 3, 4),
            0x4C: (self.JMP, 3, 3), 0x6C: (self.JMP, 3, 5),
            0x20: (self.JSR, 3, 6), 0x40: (self.RTI, 1, 6),
            0x90: (self.BCC, 2, 2), 0xB0: (self.BCS, 2, 2),
            0xF0: (self.BEQ, 2, 2), 0xD0: (self.BNE, 2, 2),
            0x30: (self.BMI, 2, 2), 0x10: (self.BPL, 2, 2),
            0x50: (self.BVC, 2, 2), 0x70: (self.BVS, 2, 2),
            0xEA: (self.NOP, 1, 2), 0x4A: (self.LSR, 1, 2),
            0x06: (self.ASL, 2, 5), 0x0A: (self.ASL, 1, 2),
            0x66: (self.ROR, 2, 5), 0x6A: (self.ROR, 1, 2),
            0x26: (self.ROL, 2, 5), 0x2A: (self.ROL, 1, 2),
            0x46: (self.LSR, 2, 5), 0xE6: (self.INC, 2, 5),
            0xEE: (self.INC, 3, 6), 0xC6: (self.DEC, 2, 5),
            0xCE: (self.DEC, 3, 6),
        }
        
        # Load Space Vikings key memory addresses
        self.game_state = {
            '95FD': 0,  # Game state variable 1
            '95FE': 0,  # Game state variable 2
            '7321': 0,  # Coordinate X
            '7322': 0,  # Coordinate Y  
            '7323': 0,  # Coordinate Z
            '95F7': 77, # Copy protection check (ASCII 'M')
        }
    
    def load_binary(self, filename, address):
        """Load binary file at specified address"""
        with open(filename, 'rb') as f:
            data = f.read()
            start_addr = address
            for i, byte in enumerate(data):
                self.memory[start_addr + i] = byte
            print(f"Loaded {len(data)} bytes from {filename} at ${address:04X}")
    
    def step(self):
        """Execute one instruction"""
        opcode = self.memory[self.PC]
        
        if opcode not in self.opcodes:
            print(f"Unknown opcode: ${opcode:02X} at ${self.PC:04X}")
            self.PC += 1
            return False
        
        func, size, cycles = self.opcodes[opcode]
        func()
        
        # Return True if BRK encountered
        return opcode == 0x00
    
    # Instruction implementations
    def BRK(self): 
        # BRK pushes PC+2 and P with B flag set
        self.push16(self.PC + 2)
        self.push(self.P | self.BREAK)
        # Set PC to IRQ vector ($FFFE-$FFFF)
        lo = self.memory[0xFFFE]
        hi = self.memory[0xFFFF]
        self.PC = (hi << 8) | lo
    
    def RTS(self):
        lo = self.pop()
        hi = self.pop()
        self.PC = ((hi << 8) | lo) + 1
    
    def JSR(self):
        addr = self.memory[self.PC + 1] | (self.memory[self.PC + 2] << 8)
        self.push16(self.PC + 2)
        self.PC = addr
    
    def JMP(self):
        if self.memory[self.PC] == 0x4C:  # Absolute
            lo = self.memory[self.PC + 1]
            hi = self.memory[self.PC + 2]
            self.PC = (hi << 8) | lo
        else:  # Indirect ($6C)
            ptr = self.memory[self.PC + 1] | (self.memory[self.PC + 2] << 8)
            lo = self.memory[ptr]
            hi = self.memory[ptr + 1]
            self.PC = (hi << 8) | lo
    
    def BCC(self): self._branch(not (self.P & self.CARRY))
    def BCS(self): self._branch(bool(self.P & self.CARRY))
    def BEQ(self): self._branch(bool(self.P & self.ZERO))
    def BNE(self): self._branch(not (self.P & self.ZERO))
    def BMI(self): self._branch(bool(self.P & self.NEGATIVE))
    def BPL(self): self._branch(not (self.P & self.NEGATIVE))
    def BVC(self): self._branch(not (self.P & self.OVERFLOW))
    def BVS(self): self._branch(bool(self.P & self.OVERFLOW))
    
    def _branch(self, condition):
        offset = self.memory[self.PC + 1]
        if condition:
            if offset & 0x80:  # Negative offset
                self.PC += 2 - (0x100 - offset)
            else:
                self.PC += 2 + offset
        else:
            self.PC += 2
    
    def LDA(self):
        value = self._get_operand()
        self.A = value
        self._set_flags_nz(value)
        self.PC += self._get_instruction_size()
    
    def LDX(self):
        value = self._get_operand()
        self.X = value
        self._set_flags_nz(value)
        self.PC += self._get_instruction_size()
    
    def LDY(self):
        value = self._get_operand()
        self.Y = value
        self._set_flags_nz(value)
        self.PC += self._get_instruction_size()
    
    def STA(self):
        addr = self._get_address()
        self.memory[addr] = self.A
        self.PC += self._get_instruction_size()
    
    def STX(self):
        addr = self._get_address()
        self.memory[addr] = self.X
        self.PC += self._get_instruction_size()
    
    def STY(self):
        addr = self._get_address()
        self.memory[addr] = self.Y
        self.PC += self._get_instruction_size()
    
    def CMP(self):
        value = self._get_operand()
        result = self.A - value
        self._set_flags_nz(result & 0xFF)
        self.P = (self.P & ~self.CARRY) | (1 if self.A >= value else 0)
        self.PC += self._get_instruction_size()
    
    def CPX(self):
        value = self._get_operand()
        result = self.X - value
        self._set_flags_nz(result & 0xFF)
        self.P = (self.P & ~self.CARRY) | (1 if self.X >= value else 0)
        self.PC += self._get_instruction_size()
    
    def CPY(self):
        value = self._get_operand()
        result = self.Y - value
        self._set_flags_nz(result & 0xFF)
        self.P = (self.P & ~self.CARRY) | (1 if self.Y >= value else 0)
        self.PC += self._get_instruction_size()
    
    def ADC(self):
        value = self._get_operand()
        result = self.A + value + (1 if self.P & self.CARRY else 0)
        
        # Set overflow flag
        overflow = ((self.A ^ result) & (value ^ result) & 0x80) != 0
        if overflow:
            self.P |= self.OVERFLOW
        else:
            self.P &= ~self.OVERFLOW
        
        self.A = result & 0xFF
        self._set_flags_nz(self.A)
        self.P = (self.P & ~self.CARRY) | (1 if result > 0xFF else 0)
        self.PC += self._get_instruction_size()
    
    def SBC(self):
        value = self._get_operand()
        # SBC is ADC with complemented value
        value = value ^ 0xFF
        result = self.A + value + (1 if self.P & self.CARRY else 0)
        
        self.A = result & 0xFF
        self._set_flags_nz(self.A)
        self.P = (self.P & ~self.CARRY) | (1 if result > 0xFF else 0)
        self.PC += self._get_instruction_size()
    
    def AND(self):
        value = self._get_operand()
        self.A &= value
        self._set_flags_nz(self.A)
        self.PC += self._get_instruction_size()
    
    def ORA(self):
        value = self._get_operand()
        self.A |= value
        self._set_flags_nz(self.A)
        self.PC += self._get_instruction_size()
    
    def EOR(self):
        value = self._get_operand()
        self.A ^= value
        self._set_flags_nz(self.A)
        self.PC += self._get_instruction_size()
    
    def BIT(self):
        value = self._get_operand()
        result = self.A & value
        self.P = (self.P & ~(self.ZERO | self.NEGATIVE | self.OVERFLOW))
        if result == 0:
            self.P |= self.ZERO
        if value & self.NEGATIVE:
            self.P |= self.NEGATIVE
        if value & 0x40:  # Bit 6 sets overflow
            self.P |= self.OVERFLOW
        self.PC += self._get_instruction_size()
    
    # Shift/rotate instructions
    def ASL(self):
        if self.memory[self.PC] == 0x0A:  # Accumulator mode
            carry = (self.A & 0x80) != 0
            self.A = (self.A << 1) & 0xFF
            self.P = (self.P & ~self.CARRY) | (carry << 0)
            self._set_flags_nz(self.A)
            self.PC += 1
        else:  # Memory mode
            addr = self._get_address()
            value = self.memory[addr]
            carry = (value & 0x80) != 0
            value = (value << 1) & 0xFF
            self.memory[addr] = value
            self.P = (self.P & ~self.CARRY) | (carry << 0)
            self._set_flags_nz(value)
            self.PC += self._get_instruction_size()
    
    def LSR(self):
        if self.memory[self.PC] in (0x4A, 0x46):  # Accumulator or memory
            if self.memory[self.PC] == 0x4A:
                carry = self.A & 0x01
                self.A >>= 1
                value = self.A
            else:
                addr = self._get_address()
                value = self.memory[addr]
                carry = value & 0x01
                value >>= 1
                self.memory[addr] = value
            
            self.P = (self.P & ~self.CARRY) | (carry << 0)
            self._set_flags_nz(value)
            self.PC += self._get_instruction_size()
    
    def ROL(self):
        if self.memory[self.PC] == 0x2A:  # Accumulator mode
            old_carry = (self.P & self.CARRY) != 0
            new_carry = (self.A & 0x80) != 0
            self.A = ((self.A << 1) | (1 if old_carry else 0)) & 0xFF
            self.P = (self.P & ~self.CARRY) | (new_carry << 0)
            self._set_flags_nz(self.A)
            self.PC += 1
        else:  # Memory mode
            addr = self._get_address()
            value = self.memory[addr]
            old_carry = (self.P & self.CARRY) != 0
            new_carry = (value & 0x80) != 0
            value = ((value << 1) | (1 if old_carry else 0)) & 0xFF
            self.memory[addr] = value
            self.P = (self.P & ~self.CARRY) | (new_carry << 0)
            self._set_flags_nz(value)
            self.PC += self._get_instruction_size()
    
    def ROR(self):
        if self.memory[self.PC] == 0x6A:  # Accumulator mode
            old_carry = (self.P & self.CARRY) != 0
            new_carry = self.A & 0x01
            self.A = ((self.A >> 1) | (0x80 if old_carry else 0))
            self.P = (self.P & ~self.CARRY) | (new_carry << 0)
            self._set_flags_nz(self.A)
            self.PC += 1
        else:  # Memory mode
            addr = self._get_address()
            value = self.memory[addr]
            old_carry = (self.P & self.CARRY) != 0
            new_carry = value & 0x01
            value = ((value >> 1) | (0x80 if old_carry else 0))
            self.memory[addr] = value
            self.P = (self.P & ~self.CARRY) | (new_carry << 0)
            self._set_flags_nz(value)
            self.PC += self._get_instruction_size()
    
    # Increment/Decrement
    def INC(self):
        addr = self._get_address()
        value = (self.memory[addr] + 1) & 0xFF
        self.memory[addr] = value
        self._set_flags_nz(value)
        self.PC += self._get_instruction_size()
    
    def DEC(self):
        addr = self._get_address()
        value = (self.memory[addr] - 1) & 0xFF
        self.memory[addr] = value
        self._set_flags_nz(value)
        self.PC += self._get_instruction_size()
    
    def INX(self):
        self.X = (self.X + 1) & 0xFF
        self._set_flags_nz(self.X)
        self.PC += 1
    
    def INY(self):
        self.Y = (self.Y + 1) & 0xFF
        self._set_flags_nz(self.Y)
        self.PC += 1
    
    def DEX(self):
        self.X = (self.X - 1) & 0xFF
        self._set_flags_nz(self.X)
        self.PC += 1
    
    def DEY(self):
        self.Y = (self.Y - 1) & 0xFF
        self._set_flags_nz(self.Y)
        self.PC += 1
    
    # Transfer instructions
    def TAX(self):
        self.X = self.A
        self._set_flags_nz(self.X)
        self.PC += 1
    
    def TAY(self):
        self.Y = self.A
        self._set_flags_nz(self.Y)
        self.PC += 1
    
    def TXA(self):
        self.A = self.X
        self._set_flags_nz(self.A)
        self.PC += 1
    
    def TYA(self):
        self.A = self.Y
        self._set_flags_nz(self.A)
        self.PC += 1
    
    def TSX(self):
        self.X = self.SP
        self._set_flags_nz(self.X)
        self.PC += 1
    
    def TXS(self):
        self.SP = self.X
        self.PC += 1
    
    # Stack operations
    def PHA(self):
        self.push(self.A)
        self.PC += 1
    
    def PLA(self):
        self.A = self.pop()
        self._set_flags_nz(self.A)
        self.PC += 1
    
    def PHP(self):
        self.push(self.P | self.BREAK)
        self.PC += 1
    
    def PLP(self):
        self.P = self.pop()
        self.PC += 1
    
    # Flag instructions
    def CLC(self):
        self.P &= ~self.CARRY
        self.PC += 1
    
    def SEC(self):
        self.P |= self.CARRY
        self.PC += 1
    
    def CLI(self):
        self.P &= ~self.INTERRUPT
        self.PC += 1
    
    def SEI(self):
        self.P |= self.INTERRUPT
        self.PC += 1
    
    def CLV(self):
        self.P &= ~self.OVERFLOW
        self.PC += 1
    
    def CLD(self):
        self.P &= ~self.DECIMAL
        self.PC += 1
    
    def SED(self):
        self.P |= self.DECIMAL
        self.PC += 1
    
    def NOP(self):
        self.PC += 1
    
    def RTI(self):
        self.P = self.pop()
        lo = self.pop()
        hi = self.pop()
        self.PC = (hi << 8) | lo
    
    # Helper methods
    def _get_operand(self):
        """Get operand value based on addressing mode"""
        opcode = self.memory[self.PC]
        
        if opcode in (0xA9, 0xA2, 0xA0, 0xC9, 0xE0, 0xC0, 0x69, 0xE9, 0x29, 0x49, 0x09):
            # Immediate mode
            return self.memory[self.PC + 1]
        elif opcode in (0xA5, 0xA6, 0xA4, 0xC5, 0xE4, 0xC4, 0x65, 0xE5, 0x25, 0x45, 0x05, 0x24):
            # Zero page
            addr = self.memory[self.PC + 1]
            return self.memory[addr]
        elif opcode in (0xAD, 0xAE, 0xAC, 0xCD, 0xEC, 0xCC, 0x6D, 0xED, 0x2D, 0x4D, 0x0D, 0x2C):
            # Absolute
            addr = self.memory[self.PC + 1] | (self.memory[self.PC + 2] << 8)
            return self.memory[addr]
        elif opcode in (0xBD, 0xBE, 0xBC):  # Absolute,X/Y
            addr = self.memory[self.PC + 1] | (self.memory[self.PC + 2] << 8)
            if opcode == 0xBD or opcode == 0xBC:  # LDA/STA/LDY absolute,X
                addr += self.X
            else:  # LDX absolute,Y
                addr += self.Y
            return self.memory[addr]
        elif opcode in (0xB5, 0xB6, 0xB4):  # Zero page,X/Y
            addr = (self.memory[self.PC + 1] + self.X) & 0xFF
            return self.memory[addr]
        elif opcode == 0x55:  # EOR zero page,X
            addr = (self.memory[self.PC + 1] + self.X) & 0xFF
            return self.memory[addr]
        else:
            print(f"Unknown addressing mode for opcode ${opcode:02X}")
            return 0
    
    def _get_address(self):
        """Get address for memory operations"""
        opcode = self.memory[self.PC]
        
        if opcode in (0x85, 0x86, 0x84, 0x65, 0xE5, 0x25, 0x45, 0x05, 0xC5, 0xE4, 0xC4, 0x06, 0xE6, 0x46, 0xC6, 0x24):
            # Zero page
            return self.memory[self.PC + 1]
        elif opcode in (0x8D, 0x8E, 0x8C, 0x6D, 0xED, 0x2D, 0x4D, 0x0D, 0xEE, 0xCE, 0x2C):
            # Absolute
            return self.memory[self.PC + 1] | (self.memory[self.PC + 2] << 8)
        elif opcode in (0x9D, 0x9E):  # Absolute,X/Y
            addr = self.memory[self.PC + 1] | (self.memory[self.PC + 2] << 8)
            if opcode == 0x9D:  # STA absolute,X
                addr += self.X
            else:  # STX absolute,Y
                addr += self.Y
            return addr
        elif opcode in (0x95, 0x96, 0x94):  # Zero page,X/Y
            return (self.memory[self.PC + 1] + self.X) & 0xFF
        elif opcode == 0x55:  # STA zero page,X
            return (self.memory[self.PC + 1] + self.X) & 0xFF
        else:
            print(f"Unknown addressing mode for opcode ${opcode:02X}")
            return 0
    
    def _get_instruction_size(self):
        """Get size of current instruction"""
        opcode = self.memory[self.PC]
        if opcode in self.opcodes:
            return self.opcodes[opcode][1]
        return 1
    
    def _set_flags_nz(self, value):
        """Set Negative and Zero flags based on value"""
        self.P = (self.P & ~(self.NEGATIVE | self.ZERO))
        if value & 0x80:
            self.P |= self.NEGATIVE
        if value == 0:
            self.P |= self.ZERO
    
    def push(self, value):
        """Push byte onto stack"""
        self.memory[0x100 + self.SP] = value
        self.SP = (self.SP - 1) & 0xFF
    
    def pop(self):
        """Pop byte from stack"""
        self.SP = (self.SP + 1) & 0xFF
        return self.memory[0x100 + self.SP]
    
    def push16(self, value):
        """Push 16-bit value onto stack (high byte first)"""
        self.push((value >> 8) & 0xFF)
        self.push(value & 0xFF)
    
    def pop16(self):
        """Pop 16-bit value from stack"""
        lo = self.pop()
        hi = self.pop()
        return (hi << 8) | lo
    
    def dump_registers(self):
        """Print CPU state"""
        return (f"PC=${self.PC:04X} A=${self.A:02X} X=${self.X:02X} Y=${self.Y:02X} "
                f"SP=${self.SP:02X} P=${self.P:02X}")

def main():
    """Test the emulator with Space Vikings code"""
    cpu = CPU6502()
    
    # Load key binaries at their original addresses
    print("Space Vikings 6502 Emulator")
    print("=" * 50)
    
    # Test with a simple program
    cpu.PC = 0x9023  # SPACE SIMULATOR ASSEMBLY entry point
    
    # Initialize game state memory
    cpu.memory[0x95FD] = 0x5A  # Initialize to middle value
    cpu.memory[0x95FE] = 0x5A
    cpu.memory[0x95F7] = 77    # Copy protection 'M'
    
    # Run a few instructions
    for i in range(20):
        brk = cpu.step()
        print(f"Step {i}: {cpu.dump_registers()}")
        if brk:
            print("BRK encountered")
            break
    
    print("\nGame state:")
    print(f"  $95FD = ${cpu.memory[0x95FD]:02X} ({cpu.memory[0x95FD]})")
    print(f"  $95FE = ${cpu.memory[0x95FE]:02X} ({cpu.memory[0x95FE]})")
    print(f"  $95F7 = ${cpu.memory[0x95F7]:02X} (ASCII: {chr(cpu.memory[0x95F7])})")

if __name__ == "__main__":
    main()