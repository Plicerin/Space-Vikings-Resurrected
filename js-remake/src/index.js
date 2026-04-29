/**
 * Space Vikings Remake - Main Entry Point
 * 
 * This is the main JavaScript entry point for the Space Vikings Remake.
 * It initializes the 6502 emulator, game state, graphics, and UI.
 */

import CPU6502 from './cpu/CPU6502.js';
import AppleIIMemory from './cpu/AppleIIMemory.js';
import GameState from './game/GameState.js';
import GraphicsRenderer from './graphics/GraphicsRenderer.js';
import InputHandler from './input/InputHandler.js';
import { loadGameAssets, setupUI } from './ui/UIManager.js';

class SpaceVikingsGame {
    constructor() {
        this.isInitialized = false;
        this.isRunning = false;
        this.lastFrameTime = 0;
        
        // Core systems
        this.cpu = null;
        this.memory = null;
        this.gameState = null;
        this.graphics = null;
        this.input = null;
        
        // UI elements
        this.canvas = null;
        this.ctx = null;
        
        // Game loop
        this.animationFrameId = null;
        
        // Performance tracking
        this.fps = 0;
        this.frameCount = 0;
        this.lastFpsUpdate = 0;
    }
    
    async init() {
        console.log('Initializing Space Vikings Remake...');
        
        try {
            // Initialize core systems
            this.memory = new AppleIIMemory();
            this.cpu = new CPU6502();
            this.gameState = new GameState();
            this.graphics = new GraphicsRenderer();
            this.input = new InputHandler();
            
            // Get canvas context
            this.canvas = document.getElementById('game-canvas');
            if (!this.canvas) {
                throw new Error('Canvas element not found');
            }
            this.ctx = this.canvas.getContext('2d');
            
            // Initialize systems
            await this.memory.init();
            await this.graphics.init(this.canvas);
            await this.gameState.init(this.memory);
            await this.input.init();
            
            // Load game assets
            await loadGameAssets();
            
            // Setup UI event handlers
            setupUI(this);
            
            // Load initial game state
            await this.loadInitialState();
            
            // Hide loading screen, show game
            this.showGameScreen();
            
            this.isInitialized = true;
            console.log('Space Vikings Remake initialized successfully');
            
            // Start game loop
            this.start();
            
        } catch (error) {
            console.error('Failed to initialize game:', error);
            this.showErrorScreen(`Initialization failed: ${error.message}`);
        }
    }
    
    async loadInitialState() {
        console.log('Loading initial game state...');
        
        // Load BASIC program at $0800 (typical Apple II BASIC start)
        // TODO: Load actual BASIC program
        
        // Load assembly routines at their respective addresses
        // TODO: Load disassembled routines
        
        // Initialize game state from known memory locations
        this.memory.poke(0x95F7, 0);  // Disable copy protection (original would be 77 = 'M')
        this.memory.poke(0x03CE, 100); // Initial crew morale
        this.memory.poke(0x9541, 1000); // Initial credits
        
        // Set up joystick position defaults
        this.memory.poke(0x95FD, 128); // Center X
        this.memory.poke(0x95FE, 128); // Center Y
        
        console.log('Initial game state loaded');
    }
    
    showGameScreen() {
        const loadingScreen = document.getElementById('loading-screen');
        const gameContainer = document.getElementById('game-container');
        
        if (loadingScreen && gameContainer) {
            loadingScreen.classList.add('hidden');
            gameContainer.classList.remove('hidden');
        }
    }
    
    showErrorScreen(message) {
        const loadingScreen = document.getElementById('loading-screen');
        if (loadingScreen) {
            const loadingText = loadingScreen.querySelector('.loading-text');
            if (loadingText) {
                loadingText.textContent = `Error: ${message}`;
                loadingText.style.color = '#ff6b6b';
            }
        }
    }
    
    start() {
        if (!this.isInitialized) {
            console.error('Cannot start game: not initialized');
            return;
        }
        
        this.isRunning = true;
        this.lastFrameTime = performance.now();
        this.frameCount = 0;
        this.lastFpsUpdate = this.lastFrameTime;
        
        console.log('Starting game loop...');
        this.gameLoop();
    }
    
    stop() {
        this.isRunning = false;
        if (this.animationFrameId) {
            cancelAnimationFrame(this.animationFrameId);
            this.animationFrameId = null;
        }
        console.log('Game stopped');
    }
    
    gameLoop(timestamp) {
        if (!this.isRunning) return;
        
        // Calculate delta time
        const deltaTime = timestamp - this.lastFrameTime;
        this.lastFrameTime = timestamp;
        
        // Update FPS counter
        this.frameCount++;
        if (timestamp - this.lastFpsUpdate >= 1000) {
            this.fps = Math.round((this.frameCount * 1000) / (timestamp - this.lastFpsUpdate));
            this.frameCount = 0;
            this.lastFpsUpdate = timestamp;
            
            // Update FPS display if it exists
            const fpsElement = document.getElementById('fps-counter');
            if (fpsElement) {
                fpsElement.textContent = `FPS: ${this.fps}`;
            }
        }
        
        // Process input
        this.input.update();
        
        // Update game state
        this.update(deltaTime);
        
        // Render graphics
        this.render();
        
        // Continue game loop
        this.animationFrameId = requestAnimationFrame((ts) => this.gameLoop(ts));
    }
    
    update(deltaTime) {
        // Convert deltaTime to 6502 cycles (approximate)
        const cyclesPerFrame = Math.floor(deltaTime * 0.1); // Rough approximation
        
        // Execute 6502 instructions for this frame
        for (let i = 0; i < cyclesPerFrame && this.cpu.PC < 0xFFFF; i++) {
            this.cpu.executeInstruction();
        }
        
        // Update game state based on CPU/memory state
        this.gameState.update(this.memory, this.cpu);
        
        // Update UI
        this.updateUI();
    }
    
    updateUI() {
        // Update credits display
        const creditsElement = document.getElementById('credits');
        if (creditsElement) {
            const credits = this.memory.peek(0x9541);
            creditsElement.textContent = `Credits: ${credits}`;
        }
        
        // Update crew morale display
        const crewElement = document.getElementById('crew');
        if (crewElement) {
            const morale = this.memory.peek(0x03CE);
            crewElement.textContent = `Crew: ${morale}%`;
            
            // Update morale bar
            const moraleBar = document.querySelector('.status-fill.engine');
            if (moraleBar) {
                moraleBar.style.width = `${morale}%`;
            }
        }
        
        // Update location display (placeholder)
        const locationElement = document.getElementById('location');
        if (locationElement && this.gameState.currentLocation) {
            locationElement.textContent = `Location: ${this.gameState.currentLocation}`;
        }
    }
    
    render() {
        // Clear canvas
        this.ctx.fillStyle = '#000';
        this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
        
        // Render game graphics
        this.graphics.render(this.ctx, this.memory, this.gameState);
        
        // Draw FPS counter
        this.ctx.fillStyle = '#0f0';
        this.ctx.font = '12px monospace';
        this.ctx.fillText(`FPS: ${this.fps}`, 10, 20);
        
        // Draw game state info
        this.ctx.fillText(`PC: $${this.cpu.PC.toString(16).toUpperCase()}`, 10, 40);
        this.ctx.fillText(`A: $${this.cpu.A.toString(16).toUpperCase()}`, 10, 60);
        this.ctx.fillText(`X: $${this.cpu.X.toString(16).toUpperCase()}`, 10, 80);
        this.ctx.fillText(`Y: $${this.cpu.Y.toString(16).toUpperCase()}`, 10, 100);
    }
    
    // Public API for UI interaction
    saveGame() {
        const saveData = {
            memory: Array.from(this.memory.memory),
            cpu: {
                A: this.cpu.A,
                X: this.cpu.X,
                Y: this.cpu.Y,
                PC: this.cpu.PC,
                SP: this.cpu.SP,
                STATUS: this.cpu.STATUS
            },
            gameState: this.gameState.export(),
            timestamp: Date.now()
        };
        
        localStorage.setItem('spaceVikingsSave', JSON.stringify(saveData));
        console.log('Game saved');
        
        // Show save confirmation
        this.showMessage('Game saved successfully');
    }
    
    loadGame() {
        const saveData = localStorage.getItem('spaceVikingsSave');
        if (!saveData) {
            this.showMessage('No saved game found');
            return;
        }
        
        try {
            const data = JSON.parse(saveData);
            
            // Restore memory
            data.memory.forEach((value, index) => {
                this.memory.memory[index] = value;
            });
            
            // Restore CPU state
            this.cpu.A = data.cpu.A;
            this.cpu.X = data.cpu.X;
            this.cpu.Y = data.cpu.Y;
            this.cpu.PC = data.cpu.PC;
            this.cpu.SP = data.cpu.SP;
            this.cpu.STATUS = data.cpu.STATUS;
            
            // Restore game state
            this.gameState.import(data.gameState);
            
            console.log('Game loaded');
            this.showMessage('Game loaded successfully');
            
        } catch (error) {
            console.error('Failed to load game:', error);
            this.showMessage('Failed to load saved game');
        }
    }
    
    showMessage(text) {
        const messageLog = document.getElementById('message-log');
        if (messageLog) {
            const messageElement = document.createElement('div');
            messageElement.className = 'message';
            messageElement.textContent = text;
            messageLog.appendChild(messageElement);
            
            // Limit message log size
            while (messageLog.children.length > 20) {
                messageLog.removeChild(messageLog.firstChild);
            }
            
            // Scroll to bottom
            messageLog.scrollTop = messageLog.scrollHeight;
        }
    }
    
    // Handle UI button actions
    handleNavigation() {
        this.showMessage('Navigation system activated');
        // TODO: Implement navigation UI
    }
    
    handleTrading() {
        this.showMessage('Trading system activated');
        // TODO: Implement trading UI
    }
    
    handleCombat() {
        this.showMessage('Combat system activated');
        // TODO: Implement combat UI
    }
    
    handleCrewManagement() {
        this.showMessage('Crew management activated');
        // TODO: Implement crew UI
    }
    
    handleShipStatus() {
        this.showMessage('Ship status displayed');
        // TODO: Implement ship status UI
    }
    
    handleGalaxyMap() {
        this.showMessage('Galaxy map activated');
        // TODO: Implement galaxy map
    }
}

// Create global game instance
window.spaceVikingsGame = new SpaceVikingsGame();

// Initialize game when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.spaceVikingsGame.init();
});

// Export for module usage
export default SpaceVikingsGame;