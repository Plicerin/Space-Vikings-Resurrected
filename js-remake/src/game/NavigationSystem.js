/**
 * Navigation System for Space Vikings Remake
 * 
 * Implements the STARSHIP SIMULATOR.bas navigation mechanics
 * Based on analysis of coordinate system and joystick control
 */

class NavigationSystem {
    constructor(gameState) {
        this.gameState = gameState;
        this.shipPosition = {
            x: 0,   // Current X coordinate
            y: 0,   // Current Y coordinate
            z: 0,   // Current Z coordinate (vertical/depth)
            xi: 0,  // Integer part of X
            yi: 0,  // Integer part of Y
            zi: 0   // Integer part of Z
        };
        
        // Navigation parameters from STARSHIP SIMULATOR.bas analysis
        this.params = {
            // Constants found in the BASIC code
            hl: 255,          // HL parameter from line 1
            hh: 256,          // HH parameter
            di: 32768,        // DI parameter
            ca: 36899,        // CA parameter (display memory)
            w1: 20000,        // Coordinate window bounds
            w2: -20000,       // Opposite window bounds
            ee: 199,          // EE parameter
            vv: 160,          // VV parameter
            q: 1.41,          // Q parameter (sqrt(2))
            x9: 400,          // Starting X
            y9: 100,          // Starting Y
            z9: 3500          // Starting Z
        };
        
        // Control parameters
        this.joystickPosition = {
            x: 0,   // From $95FD
            y: 0    // From $95FE
        };
        
        this.velocity = {
            h: 0,   // Horizontal velocity
            p: 0    // Vertical/propulsion velocity
        };
        
        this.initializeNavigation();
    }
    
    /**
     * Initialize navigation system with starting values
     */
    initializeNavigation() {
        // Set initial position from BASIC constants
        this.shipPosition.x = this.params.x9;
        this.shipPosition.y = this.params.y9;
        this.shipPosition.z = this.params.z9;
        
        // Initialize integer coordinates
        this.updateIntegerCoordinates();
        
        // Initialize velocities
        this.velocity.h = 0;
        this.velocity.p = 0;
        
        console.log('Navigation System Initialized');
        console.log(`Starting position: X=${this.shipPosition.x}, Y=${this.shipPosition.y}, Z=${this.shipPosition.z}`);
    }
    
    /**
     * Update integer coordinates (XI, YI, ZI) from floating point values
     * Simulates the BASIC code: L��(XI):H��(XI�1):�6600:X�H
     */
    updateIntegerCoordinates() {
        // Convert floating point to integer coordinates
        this.shipPosition.xi = Math.floor(this.shipPosition.x);
        this.shipPosition.yi = Math.floor(this.shipPosition.y);
        this.shipPosition.zi = Math.floor(this.shipPosition.z);
        
        // Update game state for PEEK/POKE access
        this.gameState.state.shipPosition = { ...this.shipPosition };
    }
    
    /**
     * Process joystick input for navigation
     * Based on analysis of $95FD-$95FE memory locations
     */
    processJoystickInput() {
        // Read joystick position from game state
        const joyX = this.gameState.peek('$95FD');
        const joyY = this.gameState.peek('$95FE');
        
        // Store for calculations
        this.joystickPosition.x = joyX;
        this.joystickPosition.y = joyY;
        
        // Apply joystick sensitivity (from BASIC analysis)
        const sensitivity = 0.1;
        
        // Calculate velocity changes based on joystick
        // From BASIC: H velocity affected by joystick Y, P velocity by joystick X
        this.velocity.h += (joyY - 127) * sensitivity * 0.01;
        this.velocity.p += (joyX - 127) * sensitivity * 0.01;
        
        // Apply velocity damping (air resistance simulation)
        this.velocity.h *= 0.98;
        this.velocity.p *= 0.98;
        
        // Clamp velocities to reasonable ranges
        this.velocity.h = Math.max(-5, Math.min(5, this.velocity.h));
        this.velocity.p = Math.max(-5, Math.min(5, this.velocity.p));
        
        console.log(`Joystick: X=${joyX}, Y=${joyY}, Velocity H=${this.velocity.h.toFixed(2)}, P=${this.velocity.p.toFixed(2)}`);
    }
    
    /**
     * Update ship position based on velocities
     * Based on STARSHIP SIMULATOR.bas navigation equations
     */
    updatePosition() {
        // Apply velocity to position
        this.shipPosition.x += this.velocity.h;
        this.shipPosition.y += this.velocity.p;
        
        // Apply slight drift/drift correction
        // From BASIC: X2�S2�(ZP�XH):Y2�S2�YP:Z2�S2�ZP�ZH
        const driftFactor = 0.01;
        this.shipPosition.z += (this.velocity.p - this.velocity.h) * driftFactor;
        
        // Update integer coordinates
        this.updateIntegerCoordinates();
        
        // Check boundaries from BASIC: �X�W2�X�W1
        this.checkBoundaries();
        
        // Update game state
        this.updateGameState();
        
        return this.shipPosition;
    }
    
    /**
     * Check coordinate boundaries and apply corrections
     * From BASIC lines: �X�W2�X�W1, etc.
     */
    checkBoundaries() {
        const { w1, w2 } = this.params;
        
        // X boundary check
        if (this.shipPosition.x < w2) {
            this.shipPosition.x = w2;
            this.velocity.h = 0; // Stop at boundary
        } else if (this.shipPosition.x > w1) {
            this.shipPosition.x = w1;
            this.velocity.h = 0;
        }
        
        // Y boundary check
        if (this.shipPosition.y < w2) {
            this.shipPosition.y = w2;
            this.velocity.p = 0;
        } else if (this.shipPosition.y > w1) {
            this.shipPosition.y = w1;
            this.velocity.p = 0;
        }
        
        // Z boundary check
        if (this.shipPosition.z < w2) {
            this.shipPosition.z = w2;
        } else if (this.shipPosition.z > w1) {
            this.shipPosition.z = w1;
        }
    }
    
    /**
     * Update game state memory with current navigation values
     */
    updateGameState() {
        // Store coordinates in game state memory
        this.gameState.state.shipX = this.shipPosition.x;
        this.gameState.state.shipY = this.shipPosition.y;
        this.gameState.state.shipZ = this.shipPosition.z;
        
        // Store integer coordinates (for BASIC PEEK access)
        this.gameState.state.shipXI = this.shipPosition.xi;
        this.gameState.state.shipYI = this.shipPosition.yi;
        this.gameState.state.shipZI = this.shipPosition.zi;
        
        // Store velocities
        this.gameState.state.velocityH = this.velocity.h;
        this.gameState.state.velocityP = this.velocity.p;
        
        // Update joystick position in memory
        this.gameState.poke('$95FD', Math.floor(this.joystickPosition.x));
        this.gameState.poke('$95FE', Math.floor(this.joystickPosition.y));
    }
    
    /**
     * Jump to specific coordinates (for testing or teleportation)
     */
    jumpTo(x, y, z) {
        this.shipPosition.x = x;
        this.shipPosition.y = y;
        this.shipPosition.z = z;
        
        this.updateIntegerCoordinates();
        this.updateGameState();
        
        console.log(`Jumped to: X=${x}, Y=${y}, Z=${z}`);
    }
    
    /**
     * Calculate distance to target coordinates
     * From BASIC: ��(X)�900��(Y)�900��(Z)�900
     */
    calculateDistance(targetX, targetY, targetZ) {
        const dx = targetX - this.shipPosition.x;
        const dy = targetY - this.shipPosition.y;
        const dz = targetZ - this.shipPosition.z;
        
        // Simplified distance calculation (not exactly BASIC but close)
        return Math.sqrt(dx*dx + dy*dy + dz*dz);
    }
    
    /**
     * Check if ship is in orbit range of a planet
     * From BASIC: ��(38210)�1�Y�4000ĺ"RUNORBIT"
     */
    checkOrbitRange(planetY) {
        const distance = Math.abs(planetY - this.shipPosition.y);
        return distance <= 4000;
    }
    
    /**
     * Get navigation display information
     * For status screen display
     */
    getNavigationDisplay() {
        return {
            coordinates: {
                x: this.shipPosition.x.toFixed(2),
                y: this.shipPosition.y.toFixed(2),
                z: this.shipPosition.z.toFixed(2)
            },
            integerCoordinates: {
                xi: this.shipPosition.xi,
                yi: this.shipPosition.yi,
                zi: this.shipPosition.zi
            },
            velocity: {
                h: this.velocity.h.toFixed(2),
                p: this.velocity.p.toFixed(2),
                total: Math.sqrt(this.velocity.h*this.velocity.h + this.velocity.p*this.velocity.p).toFixed(2)
            },
            joystick: {
                x: this.joystickPosition.x,
                y: this.joystickPosition.y
            },
            status: this.getNavigationStatus()
        };
    }
    
    /**
     * Get textual navigation status
     */
    getNavigationStatus() {
        const speed = Math.abs(this.velocity.h) + Math.abs(this.velocity.p);
        
        if (speed < 0.1) {
            return 'Stationary';
        } else if (speed < 1) {
            return 'Moving slowly';
        } else if (speed < 3) {
            return 'Cruising';
        } else {
            return 'High speed';
        }
    }
    
    /**
     * Reset navigation system
     */
    reset() {
        this.initializeNavigation();
        console.log('Navigation System Reset');
    }
    
    /**
     * Simulate BASIC coordinate calculations
     * For testing and validation
     */
    simulateBASICCalculations() {
        // This simulates the complex coordinate calculations from BASIC
        const result = {
            xCalc: 0,
            yCalc: 0,
            zCalc: 0
        };
        
        // Simplified simulation of BASIC calculations
        result.xCalc = this.shipPosition.x * this.params.q;
        result.yCalc = this.shipPosition.y * this.params.q;
        result.zCalc = this.shipPosition.z * this.params.q;
        
        return result;
    }
}

export default NavigationSystem;