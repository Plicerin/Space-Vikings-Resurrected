/**
 * BASIC Loader for Space Vikings Remake
 * 
 * Loads Apple II BASIC programs into 6502 emulator memory.
 * BASIC programs on Apple II typically load at $0800-$AFFF.
 */

class BASICLoader {
    constructor(memory) {
        this.memory = memory;
        this.loadedPrograms = new Map();
        this.programAddresses = this.getProgramAddresses();
    }

    /**
     * Map of known program loading addresses from analysis
     */
    getProgramAddresses() {
        return {
            // Main programs and their typical load addresses
            'START.bas': 0x0800,  // Apple II BASIC starts at $0800
            'COM.bas': 0x0800,
            'STARSHIP SIMULATOR.bas': 0x0800,
            'SHORE LEAVE.bas': 0x0800,
            'GROUND FORCES.bas': 0x0800,
            'GALAXY MAP.bas': 0x0800,
            'COLLECT.bas': 0x0800,
            'STATUS.bas': 0x0800,
            'ORBIT.bas': 0x0800,
            'END.bas': 0x0800,
            'DMG.bas': 0x0800,
            'EX.bas': 0x0800,
            'RE.bas': 0x0800,
            'RADAR.bas': 0x0800,
            'INSTRUMENTS.bas': 0x0800,
            'SUPPLY.bas': 0x0800,
            'RECALL.bas': 0x0800,
            'S_X.bas': 0x0800,
            'H_D.bas': 0x0800,
            
            // Ship ID files (smaller, could load elsewhere)
            'SHIP no 0 I.D..bas': 0x0800,
            'SHIP no 1 I.D..bas': 0x0800,
            'SHIP no 3 I.D..bas': 0x0800,
            'SHIP no 4 I.D..bas': 0x0800
        };
    }

    /**
     * Load a BASIC program into memory
     * @param {string} filename - Name of the BASIC file
     * @param {string} content - Detokenized BASIC content
     * @param {number} [addressOverride] - Optional override for load address
     * @returns {Object} Information about loaded program
     */
    loadBASICProgram(filename, content, addressOverride = null) {
        const address = addressOverride || this.programAddresses[filename] || 0x0800;
        
        console.log(`Loading ${filename} at $${address.toString(16).toUpperCase()}`);
        
        // Convert BASIC lines to Apple II tokenized format
        const tokenized = this.tokenizeBASIC(content);
        
        // Load into memory
        for (let i = 0; i < tokenized.length; i++) {
            this.memory.poke(address + i, tokenized[i]);
        }
        
        // Store metadata
        const programInfo = {
            filename,
            address,
            length: tokenized.length,
            lines: this.countBASICLines(content),
            tokenizedLength: tokenized.length
        };
        
        this.loadedPrograms.set(filename, programInfo);
        
        console.log(`Loaded ${filename}: ${programInfo.lines} lines, ${tokenized.length} bytes at $${address.toString(16).toUpperCase()}`);
        
        return programInfo;
    }

    /**
     * Convert detokenized BASIC to Apple II tokenized format
     * Apple II BASIC tokens are stored with high bit set
     */
    tokenizeBASIC(content) {
        const bytes = [];
        
        // Split into lines
        const lines = content.split('\n');
        
        for (const line of lines) {
            if (!line.trim()) continue;
            
            // Parse line number at start (first token before space)
            const match = line.match(/^(\d+)\s+(.*)$/);
            if (!match) continue;
            
            const lineNumber = parseInt(match[1]);
            const lineContent = match[2];
            
            // Store line number as two bytes (little-endian)
            const lineLow = lineNumber & 0xFF;
            const lineHigh = (lineNumber >> 8) & 0xFF;
            bytes.push(lineLow, lineHigh);
            
            // Tokenize line content
            // Simple tokenization: common BASIC keywords
            const tokens = this.tokenizeLine(lineContent);
            bytes.push(...tokens);
            
            // End of line marker (0x00)
            bytes.push(0x00);
        }
        
        // End of program marker (0x00 0x00)
        bytes.push(0x00, 0x00);
        
        return new Uint8Array(bytes);
    }

    /**
     * Tokenize a single BASIC line
     * Basic implementation - converts keywords to Apple II tokens
     */
    tokenizeLine(line) {
        const bytes = [];
        let i = 0;
        
        while (i < line.length) {
            const remaining = line.substring(i);
            
            // Check for common BASIC keywords
            const keyword = this.matchKeyword(remaining);
            if (keyword) {
                bytes.push(keyword.token);
                i += keyword.length;
                continue;
            }
            
            // Regular ASCII character with high bit set
            const charCode = line.charCodeAt(i);
            if (charCode >= 32 && charCode <= 127) {
                bytes.push(charCode | 0x80); // Apple II sets high bit
            } else {
                bytes.push(charCode); // Control characters
            }
            i++;
        }
        
        return bytes;
    }

    /**
     * Match BASIC keywords at start of string
     */
    matchKeyword(str) {
        // Common Apple II BASIC keywords with their token values
        const keywords = [
            // Tokens from Apple II BASIC
            { pattern: ' PRINT ', token: 0xBA, length: 6 },
            { pattern: 'GOTO ', token: 0xAB, length: 5 },
            { pattern: 'GOSUB ', token: 0xAC, length: 6 },
            { pattern: 'RETURN', token: 0xAD, length: 6 },
            { pattern: 'FOR ', token: 0x81, length: 4 },
            { pattern: 'TO ', token: 0xA4, length: 3 },
            { pattern: 'STEP ', token: 0xA5, length: 5 },
            { pattern: 'NEXT ', token: 0x82, length: 5 },
            { pattern: 'IF ', token: 0xAD, length: 3 },
            { pattern: 'THEN ', token: 0xAF, length: 5 },
            { pattern: 'PEEK(', token: 0xC3, length: 5 },
            { pattern: 'POKE ', token: 0xC4, length: 5 },
            { pattern: 'CALL ', token: 0xC5, length: 5 },
            { pattern: 'ON ', token: 0xC9, length: 3 },
            { pattern: 'AND ', token: 0xAF, length: 4 },
            { pattern: 'OR ', token: 0xB0, length: 3 },
            { pattern: 'NOT ', token: 0xB1, length: 4 },
            { pattern: 'RUN ', token: 0x8E, length: 4 },
            { pattern: 'END', token: 0x80, length: 3 },
            { pattern: 'REM ', token: 0x8F, length: 4 },
            { pattern: 'STOP', token: 0x90, length: 4 },
            { pattern: 'CONT', token: 0x91, length: 4 },
            { pattern: 'LIST ', token: 0x93, length: 5 },
            { pattern: 'CLEAR', token: 0x94, length: 5 },
            { pattern: 'NEW', token: 0x95, length: 3 },
            
            // Mathematical operators and functions
            { pattern: '=', token: 0xB2, length: 1 },
            { pattern: '<', token: 0xB3, length: 1 },
            { pattern: '>', token: 0xB4, length: 1 },
            { pattern: '<=', token: 0xB5, length: 2 },
            { pattern: '>=', token: 0xB6, length: 2 },
            { pattern: '<>', token: 0xB7, length: 2 },
            { pattern: '+', token: 0xAA, length: 1 },
            { pattern: '-', token: 0xAB, length: 1 },
            { pattern: '*', token: 0xAC, length: 1 },
            { pattern: '/', token: 0xAD, length: 1 },
            { pattern: '^', token: 0xAE, length: 1 },
            { pattern: 'ABS(', token: 0xBE, length: 4 },
            { pattern: 'SQR(', token: 0xC0, length: 4 },
            { pattern: 'RND(', token: 0xC1, length: 4 },
            { pattern: 'SIN(', token: 0xC2, length: 4 },
            { pattern: 'COS(', token: 0xC3, length: 4 },
            { pattern: 'TAN(', token: 0xC4, length: 4 },
            { pattern: 'ATN(', token: 0xC5, length: 4 },
            { pattern: 'LOG(', token: 0xC6, length: 4 },
            { pattern: 'EXP(', token: 0xC7, length: 4 },
            
            // String functions
            { pattern: 'CHR$(', token: 0xE5, length: 5 },
            { pattern: 'STR$(', token: 0xE6, length: 5 },
            { pattern: 'VAL(', token: 0xE7, length: 4 },
            { pattern: 'LEN(', token: 0xE8, length: 4 },
            { pattern: 'ASC(', token: 0xE9, length: 4 },
            { pattern: 'LEFT$(', token: 0xEA, length: 6 },
            { pattern: 'RIGHT$(', token: 0xEB, length: 7 },
            { pattern: 'MID$(', token: 0xEC, length: 5 },
        ];
        
        // Try to match keywords case-insensitively
        const upperStr = str.toUpperCase();
        for (const kw of keywords) {
            if (upperStr.startsWith(kw.pattern.toUpperCase())) {
                return { token: kw.token, length: kw.length };
            }
        }
        
        return null;
    }

    /**
     * Count lines in BASIC program
     */
    countBASICLines(content) {
        return content.split('\n').filter(line => line.trim() && /^\d+/.test(line)).length;
    }

    /**
     * Load all BASIC programs from detokenized directory
     */
    async loadAllBASICPrograms() {
        console.log('Loading all BASIC programs from extracted directory...');
        
        // List of all 23 BASIC files from the extracted directory
        const allPrograms = [
            'START.bas',
            'COM.bas',
            'STARSHIP SIMULATOR.bas',
            'SHORE LEAVE.bas',
            'GROUND FORCES.bas',
            'GALAXY MAP.bas',
            'STATUS.bas',
            'COLLECT.bas',
            'ORBIT.bas',
            'END.bas',
            'DMG.bas',
            'EX.bas',
            'RE.bas',
            'RADAR.bas',
            'INSTRUMENTS.bas',
            'SUPPLY.bas',
            'RECALL.bas',
            'S_X.bas',
            'H_D.bas',
            'SHIP no 0 I.D..bas',
            'SHIP no 1 I.D..bas',
            'SHIP no 3 I.D..bas',
            'SHIP no 4 I.D..bas'
        ];
        
        // Track successful loads
        let successCount = 0;
        let failCount = 0;
        
        for (const program of allPrograms) {
            try {
                const content = await this.fetchBASICContent(program);
                if (content) {
                    this.loadBASICProgram(program, content);
                    successCount++;
                    console.log(`✓ Loaded ${program}`);
                } else {
                    console.warn(`✗ No content for ${program}`);
                    failCount++;
                }
            } catch (error) {
                console.warn(`✗ Failed to load ${program}:`, error.message);
                failCount++;
            }
        }
        
        console.log(`BASIC Loading Complete: ${successCount} successful, ${failCount} failed`);
        console.log(`Loaded ${this.loadedPrograms.size} BASIC programs`);
        return this.loadedPrograms;
    }

    /**
     * Fetch BASIC content from detokenized files
     * In a real implementation, this would fetch from server
     */
    async fetchBASICContent(filename) {
        try {
            // Check if we're in Node.js environment
            if (typeof window === 'undefined' && typeof require !== 'undefined') {
                // Node.js environment - read from filesystem
                const fs = require('fs');
                const path = require('path');
                
                // Path to extracted directory (relative to this file)
                const extractedPath = path.join(__dirname, '..', '..', '..', 'extracted', filename);
                
                if (fs.existsSync(extractedPath)) {
                    const content = fs.readFileSync(extractedPath, 'utf-8');
                    console.log(`Loaded actual file: ${filename} (${content.length} bytes)`);
                    return content;
                } else {
                    console.warn(`File not found: ${filename} at ${extractedPath}`);
                    // Fallback to simulated content for testing
                    return this.getSimulatedContent(filename);
                }
            } else {
                // Browser environment - use fetch API
                try {
                    const response = await fetch(`../extracted/${filename}`);
                    if (response.ok) {
                        const content = await response.text();
                        console.log(`Loaded via fetch: ${filename} (${content.length} bytes)`);
                        return content;
                    } else {
                        console.warn(`Failed to fetch ${filename}: ${response.status}`);
                        return this.getSimulatedContent(filename);
                    }
                } catch (error) {
                    console.warn(`Fetch error for ${filename}:`, error.message);
                    return this.getSimulatedContent(filename);
                }
            }
        } catch (error) {
            console.warn(`Error loading ${filename}:`, error.message);
            return this.getSimulatedContent(filename);
        }
    }

    getSimulatedContent(filename) {
        // Fallback simulated content for testing
        const simulatedContent = `10 PRINT "SIMULATED ${filename} FOR TESTING"
20 GOTO 10`;
        console.warn(`Using simulated content for ${filename}`);
        return simulatedContent;
    }

    /**
     * Get information about a loaded program
     */
    getProgramInfo(filename) {
        return this.loadedPrograms.get(filename);
    }

    /**
     * Get all loaded programs
     */
    getAllPrograms() {
        return Array.from(this.loadedPrograms.values());
    }

    /**
     * Jump to a specific BASIC program (simulate RUN command)
     */
    runProgram(filename) {
        const program = this.loadedPrograms.get(filename);
        if (!program) {
            throw new Error(`Program ${filename} not loaded`);
        }
        
        // Set BASIC execution pointer to start of program
        // In Apple II, $67-68 holds the current line pointer
        this.memory.poke(0x67, program.address & 0xFF);
        this.memory.poke(0x68, (program.address >> 8) & 0xFF);
        
        console.log(`Running ${filename} from $${program.address.toString(16).toUpperCase()}`);
        
        return program;
    }
}

export default BASICLoader;