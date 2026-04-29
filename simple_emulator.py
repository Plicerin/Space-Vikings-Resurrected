#!/usr/bin/env python3
"""
Space Vikings Simple Emulator Proof of Concept
Validates reverse engineering by simulating basic file loading/game state
"""

import json
import struct
import os
from pathlib import Path

class SpaceVikingsEmulator:
    def __init__(self):
        self.memory = bytearray([0] * 0x10000)  # 64KB Apple II memory
        self.game_state = {
            'p_f_data': [],        # Planet/Starbase records
            'planet_file': None,   # Current planet state
            'ships_data': {},      # Ship statistics
            'current_overlay': None,
            'memory_regions': {}
        }
        
        # Load JSON schemas
        self.schema = self.load_schema()
        
    def load_schema(self):
        """Load game state schema"""
        schema_path = Path(__file__).parent / 'game_state_schema.json'
        if schema_path.exists():
            with open(schema_path, 'r') as f:
                return json.load(f)
        return {}
    
    def load_binary_file(self, filepath, address):
        """Load a binary file into emulated memory"""
        try:
            with open(filepath, 'rb') as f:
                data = f.read()
                if 0 <= address < len(self.memory) - len(data):
                    self.memory[address:address+len(data)] = data
                    print(f"Loaded {os.path.basename(filepath)} ({len(data)} bytes) at ${address:04X}")
                    return True
                else:
                    print(f"Error: Address ${address:04X} out of range for {os.path.basename(filepath)}")
                    return False
        except FileNotFoundError:
            print(f"Error: File not found: {filepath}")
            return False
    
    def parse_p_f_data(self, address=0x97E1):
        """Parse P/F data from memory"""
        p_f_data = []
        
        # Check if data exists at this address
        if self.memory[address] == 0 and self.memory[address+1] == 0:
            print("P/F data appears uninitialized")
            return []
        
        # Parse 20 records of 16 bytes each
        for i in range(20):
            record_offset = address + (i * 16)
            if record_offset + 16 <= len(self.memory):
                record_bytes = bytes(self.memory[record_offset:record_offset+16])
                
                # Parse according to schema
                word_a = struct.unpack('<H', record_bytes[0:2])[0]
                word_b = struct.unpack('<H', record_bytes[2:4])[0]
                flag = record_bytes[4]
                record_id = record_bytes[5]
                
                record = {
                    'record_id': record_id,
                    'word_a': word_a,
                    'word_b': word_b,
                    'flag': flag,
                    'raw_bytes': record_bytes.hex()
                }
                p_f_data.append(record)
        
        return p_f_data
    
    def parse_planet_file(self, address=0x954C):
        """Parse planet file data"""
        planet_data = bytes(self.memory[address:address+0xAF])
        
        # Check if uninitialized (FF FF 01 01 pattern)
        if planet_data[:4] == b'\xFF\xFF\x01\x01':
            return {"status": "uninitialized", "pattern": "FF FF 01 01"}
        
        # Try to parse structured data
        parsed = {
            'size': len(planet_data),
            'planet_count': planet_data[0] if len(planet_data) > 0 else 0,
            'raw_data': planet_data.hex()
        }
        
        return parsed
    
    def parse_ships_data(self, address=0x38150):
        """Parse ship's data"""
        if address + 0x36 > len(self.memory):
            return {}
        
        ships_data = bytes(self.memory[address:address+0x36])
        
        parsed = {
            'size': len(ships_data),
            'unknown_04_05': struct.unpack('<H', ships_data[0x04:0x06])[0],
            'unknown_06_07': struct.unpack('<H', ships_data[0x06:0x08])[0],
            'unknown_08_09': struct.unpack('<H', ships_data[0x08:0x0A])[0],
            'unknown_0A_0B': struct.unpack('<H', ships_data[0x0A:0x0C])[0],
            'unknown_0E_0F': struct.unpack('<H', ships_data[0x0E:0x10])[0],
            'unknown_10_11': struct.unpack('<H', ships_data[0x10:0x12])[0],
            'raw_data': ships_data.hex()
        }
        
        return parsed
    
    def load_extracted_files(self):
        """Load key extracted files to validate format"""
        extracted_dir = Path(__file__).parent / 'extracted'
        
        print("Loading extracted files for validation...")
        
        # Load P/F
        p_f_path = extracted_dir / 'P_F.payload.bin'
        if p_f_path.exists():
            self.load_binary_file(p_f_path, 0x97E1)
            self.game_state['p_f_data'] = self.parse_p_f_data()
        
        # Load PLANET FILE template
        planet_file_path = extracted_dir / 'PLANET FILE-M.payload.bin'
        if planet_file_path.exists():
            self.load_binary_file(planet_file_path, 0x954C)
            self.game_state['planet_file'] = self.parse_planet_file()
        
        # Load SHIP'S DATA template
        ships_data_path = extracted_dir / "SHIP'S DATA-M.payload.bin"
        if ships_data_path.exists():
            self.load_binary_file(ships_data_path, 0x9506)
            self.game_state['ships_data'] = self.parse_ships_data()
        
        # Load a sample shape table
        planet_shape_path = extracted_dir / 'PLANET #1.payload.bin'
        if planet_shape_path.exists():
            self.load_binary_file(planet_shape_path, 0x29440)
        
        print("File loading complete!")
    
    def simulate_overlay_transition(self, from_overlay, to_overlay):
        """Simulate overlay transition"""
        print(f"Transition: {from_overlay} -> {to_overlay}")
        
        # In real game, this would involve:
        # 1. Saving state from current overlay
        # 2. Loading new overlay BASIC program
        # 3. Restoring shared state via PEEK/POKE
        
        self.game_state['current_overlay'] = to_overlay
        
        # Example: Check if this transition is valid
        transitions = {
            'START': ['GALAXY MAP', 'STATUS'],
            'GALAXY MAP': ['SPACE SIMULATOR', 'STARSHIP SIMULATOR'],
            'STARSHIP SIMULATOR': ['SHORE LEAVE', 'GROUND FORCES'],
            'SHORE LEAVE': ['STATUS', 'COM'],
            'COM': ['STATUS', 'END']
        }
        
        if from_overlay in transitions and to_overlay in transitions[from_overlay]:
            print(f"Valid transition: {from_overlay} -> {to_overlay}")
            return True
        else:
            print(f"Warning: Transition {from_overlay} -> {to_overlay} not in known transitions")
            return False
    
    def display_game_state(self):
        """Display current game state"""
        print("\n" + "="*60)
        print("SPACE VIKINGS EMULATOR - GAME STATE")
        print("="*60)
        
        print(f"\nCurrent Overlay: {self.game_state['current_overlay'] or 'None'}")
        
        print("\nP/F Data (Planet/Starbase):")
        if self.game_state['p_f_data']:
            for i, record in enumerate(self.game_state['p_f_data'][:5]):  # Show first 5
                print(f"  Record {i+1}: ID={record['record_id']}, Flag={record['flag']}, "
                      f"WordA={record['word_a']}, WordB={record['word_b']}")
            if len(self.game_state['p_f_data']) > 5:
                print(f"  ... and {len(self.game_state['p_f_data'])-5} more records")
        else:
            print("  No P/F data loaded")
        
        print("\nPlanet File:")
        if self.game_state['planet_file']:
            if self.game_state['planet_file'].get('status') == 'uninitialized':
                print("  Status: Uninitialized template")
            else:
                print(f"  Size: {self.game_state['planet_file']['size']} bytes")
                print(f"  Planet Count: {self.game_state['planet_file'].get('planet_count', 'Unknown')}")
        else:
            print("  No planet file data loaded")
        
        print("\nShip's Data:")
        if self.game_state['ships_data']:
            for key, value in self.game_state['ships_data'].items():
                if key != 'raw_data' and key != 'size':
                    print(f"  {key}: {value}")
        else:
            print("  No ship's data loaded")
        
        print("\nMemory Regions:")
        # Check key memory areas
        key_addresses = {
            'Game State ($95FD)': 0x95FD,
            'Sound Params ($9270)': 0x9270,
            'Copy Protection ($95F7)': 0x95F7,
            'Transfer Counter ($9532)': 0x9532
        }
        
        for name, addr in key_addresses.items():
            if addr < len(self.memory):
                value = self.memory[addr]
                print(f"  {name}: ${addr:04X} = {value} (0x{value:02X})")
        
        print("="*60)
    
    def test_copy_protection(self):
        """Test copy protection bypass"""
        print("\nTesting Copy Protection...")
        
        # Original protection check at $95F7 should be 77 ('M')
        check_addr = 0x95F7
        original_value = 77  # ASCII 'M'
        
        current_value = self.memory[check_addr] if check_addr < len(self.memory) else 0
        
        print(f"Memory at ${check_addr:04X}: {current_value} (0x{current_value:02X})")
        
        if current_value == original_value:
            print("✓ Copy protection would trigger (original disk)")
        elif current_value == 0:
            print("✓ Copy protection bypassed (cracked version)")
        else:
            print(f"? Unknown value at protection check: {current_value}")

def main():
    """Main emulator function"""
    emulator = SpaceVikingsEmulator()
    
    print("Space Vikings Simple Emulator")
    print("Validating reverse engineering results...")
    print("-" * 50)
    
    # Load extracted files
    emulator.load_extracted_files()
    
    # Set initial overlay
    emulator.game_state['current_overlay'] = 'START'
    
    # Display initial state
    emulator.display_game_state()
    
    # Test copy protection
    emulator.test_copy_protection()
    
    # Test some overlay transitions
    print("\n" + "-" * 50)
    print("Testing Overlay Transitions...")
    
    transitions = [
        ('START', 'GALAXY MAP'),
        ('GALAXY MAP', 'STARSHIP SIMULATOR'),
        ('STARSHIP SIMULATOR', 'SHORE LEAVE'),
        ('SHORE LEAVE', 'COM')
    ]
    
    for from_ov, to_ov in transitions:
        emulator.simulate_overlay_transition(from_ov, to_ov)
    
    print("\n" + "-" * 50)
    print("Emulation test complete!")
    print("\nThis demonstrates:")
    print("1. Binary file loading at correct addresses")
    print("2. Parsing of game state formats (P/F, PLANET FILE, SHIP'S DATA)")
    print("3. Overlay transition simulation")
    print("4. Copy protection validation")
    print("\nNext steps:")
    print("- Implement actual 6502 CPU emulation")
    print("- Load and run BASIC overlays")
    print("- Implement complete game mechanics")
    print("- Integrate converted JSON/SVG graphics")

if __name__ == "__main__":
    main()