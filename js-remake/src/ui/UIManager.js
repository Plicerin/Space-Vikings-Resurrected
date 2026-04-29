// UI Manager for Space Vikings Remake
// Manages modern HTML UI while preserving original game feel

export class UIManager {
  constructor() {
    this.elements = new Map();
    this.screens = new Map();
    this.currentScreen = 'loading';
    this.theme = 'dark';
    this.isMobile = this.checkMobile();
    
    this.createBaseUI();
    this.setupEventListeners();
  }

  // Check if running on mobile device
  checkMobile() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  }

  // Create base UI structure
  createBaseUI() {
    this.createContainer();
    this.createLoadingScreen();
    this.createMainGameScreen();
    this.createHUD();
    this.createDialogs();
    this.createMenus();
  }

  // Create main container
  createContainer() {
    const container = document.createElement('div');
    container.id = 'game-container';
    container.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: #000;
      color: #fff;
      font-family: 'Courier New', monospace;
      overflow: hidden;
    `;
    document.body.appendChild(container);
    this.container = container;
  }

  // Create loading screen
  createLoadingScreen() {
    const loadingScreen = document.createElement('div');
    loadingScreen.id = 'loading-screen';
    loadingScreen.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      background: #000;
      z-index: 1000;
    `;
    
    const title = document.createElement('h1');
    title.textContent = 'SPACE VIKINGS';
    title.style.cssText = `
      font-size: 48px;
      margin-bottom: 20px;
      text-shadow: 0 0 10px #4ecdc4;
      animation: pulse 2s infinite;
    `;
    
    const subtitle = document.createElement('h2');
    subtitle.textContent = 'RESURRECTED';
    subtitle.style.cssText = `
      font-size: 24px;
      margin-bottom: 40px;
      color: #ff6b6b;
    `;
    
    const progressBar = document.createElement('div');
    progressBar.id = 'loading-progress';
    progressBar.style.cssText = `
      width: 300px;
      height: 20px;
      background: #333;
      border: 2px solid #4ecdc4;
      border-radius: 10px;
      overflow: hidden;
    `;
    
    const progressFill = document.createElement('div');
    progressFill.id = 'loading-progress-fill';
    progressFill.style.cssText = `
      width: 0%;
      height: 100%;
      background: linear-gradient(90deg, #4ecdc4, #44a08d);
      transition: width 0.3s ease;
    `;
    
    progressBar.appendChild(progressFill);
    
    const loadingText = document.createElement('div');
    loadingText.id = 'loading-text';
    loadingText.textContent = 'Initializing systems...';
    loadingText.style.cssText = `
      margin-top: 20px;
      font-size: 16px;
      color: #aaa;
    `;
    
    loadingScreen.appendChild(title);
    loadingScreen.appendChild(subtitle);
    loadingScreen.appendChild(progressBar);
    loadingScreen.appendChild(loadingText);
    
    this.container.appendChild(loadingScreen);
    this.screens.set('loading', loadingScreen);
  }

  // Create main game screen with canvas
  createMainGameScreen() {
    const gameScreen = document.createElement('div');
    gameScreen.id = 'game-screen';
    gameScreen.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      display: none;
    `;
    
    const canvas = document.createElement('canvas');
    canvas.id = 'game-canvas';
    canvas.width = 800;
    canvas.height = 600;
    canvas.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      cursor: crosshair;
    `;
    
    gameScreen.appendChild(canvas);
    this.container.appendChild(gameScreen);
    this.screens.set('game', gameScreen);
    this.canvas = canvas;
  }

  // Create Heads-Up Display
  createHUD() {
    const hud = document.createElement('div');
    hud.id = 'game-hud';
    hud.style.cssText = `
      position: absolute;
      top: 20px;
      left: 20px;
      right: 20px;
      z-index: 100;
      display: flex;
      justify-content: space-between;
      pointer-events: none;
    `;
    
    // Left panel: Status
    const statusPanel = document.createElement('div');
    statusPanel.id = 'hud-status';
    statusPanel.style.cssText = `
      background: rgba(0, 0, 0, 0.7);
      border: 2px solid #4ecdc4;
      border-radius: 10px;
      padding: 10px 20px;
      backdrop-filter: blur(5px);
    `;
    
    const credits = document.createElement('div');
    credits.id = 'hud-credits';
    credits.textContent = 'CREDITS: 5,000';
    credits.style.cssText = 'font-size: 18px; margin-bottom: 5px;';
    
    const morale = document.createElement('div');
    morale.id = 'hud-morale';
    morale.textContent = 'MORALE: 50%';
    morale.style.cssText = 'font-size: 18px; margin-bottom: 5px;';
    
    const location = document.createElement('div');
    location.id = 'hud-location';
    location.textContent = 'LOCATION: SOL SYSTEM';
    location.style.cssText = 'font-size: 18px; color: #ff6b6b;';
    
    statusPanel.appendChild(credits);
    statusPanel.appendChild(morale);
    statusPanel.appendChild(location);
    
    // Right panel: Controls
    const controlsPanel = document.createElement('div');
    controlsPanel.id = 'hud-controls';
    controlsPanel.style.cssText = `
      background: rgba(0, 0, 0, 0.7);
      border: 2px solid #ff6b6b;
      border-radius: 10px;
      padding: 10px;
      backdrop-filter: blur(5px);
      display: ${this.isMobile ? 'flex' : 'none'};
      gap: 10px;
    `;
    
    if (this.isMobile) {
      const upBtn = this.createTouchButton('↑', 'touch-up');
      const downBtn = this.createTouchButton('↓', 'touch-down');
      const leftBtn = this.createTouchButton('←', 'touch-left');
      const rightBtn = this.createTouchButton('→', 'touch-right');
      const fireBtn = this.createTouchButton('FIRE', 'touch-fire');
      
      controlsPanel.appendChild(upBtn);
      controlsPanel.appendChild(downBtn);
      controlsPanel.appendChild(leftBtn);
      controlsPanel.appendChild(rightBtn);
      controlsPanel.appendChild(fireBtn);
    }
    
    hud.appendChild(statusPanel);
    hud.appendChild(controlsPanel);
    
    this.container.appendChild(hud);
    this.elements.set('hud', hud);
  }

  // Create touch control button
  createTouchButton(text, id) {
    const button = document.createElement('button');
    button.id = id;
    button.textContent = text;
    button.style.cssText = `
      width: 50px;
      height: 50px;
      border: 2px solid #4ecdc4;
      border-radius: 50%;
      background: rgba(0, 0, 0, 0.7);
      color: #fff;
      font-size: 20px;
      font-weight: bold;
      cursor: pointer;
      pointer-events: auto;
      transition: all 0.1s;
    `;
    
    button.addEventListener('touchstart', (e) => {
      e.preventDefault();
      button.style.background = '#4ecdc4';
      button.style.transform = 'scale(0.95)';
    });
    
    button.addEventListener('touchend', (e) => {
      e.preventDefault();
      button.style.background = 'rgba(0, 0, 0, 0.7)';
      button.style.transform = 'scale(1)';
    });
    
    return button;
  }

  // Create dialog system
  createDialogs() {
    const dialogContainer = document.createElement('div');
    dialogContainer.id = 'dialog-container';
    dialogContainer.style.cssText = `
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      z-index: 200;
      display: none;
    `;
    
    this.container.appendChild(dialogContainer);
    this.elements.set('dialogContainer', dialogContainer);
  }

  // Create menu system
  createMenus() {
    const menuContainer = document.createElement('div');
    menuContainer.id = 'menu-container';
    menuContainer.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0, 0, 0, 0.9);
      z-index: 300;
      display: none;
      flex-direction: column;
      justify-content: center;
      align-items: center;
    `;
    
    this.container.appendChild(menuContainer);
    this.elements.set('menuContainer', menuContainer);
  }

  // Setup event listeners
  setupEventListeners() {
    // Escape key for menu
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.toggleMenu();
      }
    });
    
    // Window resize
    window.addEventListener('resize', () => {
      this.handleResize();
    });
  }

  // Switch between screens
  switchScreen(screenName) {
    // Hide all screens
    this.screens.forEach((screen, name) => {
      screen.style.display = 'none';
    });
    
    // Show requested screen
    const screen = this.screens.get(screenName);
    if (screen) {
      screen.style.display = 'flex';
      this.currentScreen = screenName;
    }
  }

  // Update loading progress
  updateLoadingProgress(percent, message) {
    const progressFill = document.getElementById('loading-progress-fill');
    const loadingText = document.getElementById('loading-text');
    
    if (progressFill) {
      progressFill.style.width = `${percent}%`;
    }
    
    if (loadingText) {
      loadingText.textContent = message;
    }
    
    if (percent >= 100) {
      setTimeout(() => {
        this.switchScreen('game');
      }, 500);
    }
  }

  // Update HUD values
  updateHUD(data) {
    const credits = document.getElementById('hud-credits');
    const morale = document.getElementById('hud-morale');
    const location = document.getElementById('hud-location');
    
    if (credits && data.credits !== undefined) {
      credits.textContent = `CREDITS: ${data.credits.toLocaleString()}`;
    }
    
    if (morale && data.morale !== undefined) {
      morale.textContent = `MORALE: ${data.morale}%`;
    }
    
    if (location && data.location !== undefined) {
      location.textContent = `LOCATION: ${data.location}`;
    }
  }

  // Show dialog
  showDialog(title, message, options = []) {
    const dialogContainer = this.elements.get('dialogContainer');
    if (!dialogContainer) return;
    
    // Clear previous content
    dialogContainer.innerHTML = '';
    
    // Create dialog
    const dialog = document.createElement('div');
    dialog.style.cssText = `
      background: rgba(0, 0, 0, 0.9);
      border: 2px solid #4ecdc4;
      border-radius: 10px;
      padding: 30px;
      min-width: 300px;
      max-width: 500px;
      color: #fff;
    `;
    
    const dialogTitle = document.createElement('h2');
    dialogTitle.textContent = title;
    dialogTitle.style.cssText = `
      font-size: 24px;
      margin-bottom: 20px;
      color: #ff6b6b;
      text-align: center;
    `;
    
    const dialogMessage = document.createElement('div');
    dialogMessage.textContent = message;
    dialogMessage.style.cssText = `
      font-size: 16px;
      margin-bottom: 30px;
      line-height: 1.5;
      text-align: center;
    `;
    
    const buttonContainer = document.createElement('div');
    buttonContainer.style.cssText = `
      display: flex;
      justify-content: center;
      gap: 10px;
    `;
    
    dialog.appendChild(dialogTitle);
    dialog.appendChild(dialogMessage);
    dialog.appendChild(buttonContainer);
    
    // Add buttons
    options.forEach((option, index) => {
      const button = document.createElement('button');
      button.textContent = option.label;
      button.style.cssText = `
        padding: 10px 20px;
        border: 2px solid #4ecdc4;
        border-radius: 5px;
        background: #000;
        color: #fff;
        font-family: 'Courier New', monospace;
        font-size: 16px;
        cursor: pointer;
        transition: all 0.2s;
      `;
      
      button.addEventListener('mouseenter', () => {
        button.style.background = '#4ecdc4';
      });
      
      button.addEventListener('mouseleave', () => {
        button.style.background = '#000';
      });
      
      button.addEventListener('click', () => {
        dialogContainer.style.display = 'none';
        if (option.callback) option.callback();
      });
      
      buttonContainer.appendChild(button);
    });
    
    // Close button if no options
    if (options.length === 0) {
      const closeButton = document.createElement('button');
      closeButton.textContent = 'CLOSE';
      closeButton.style.cssText = `
        padding: 10px 20px;
        border: 2px solid #ff6b6b;
        border-radius: 5px;
        background: #000;
        color: #fff;
        font-family: 'Courier New', monospace;
        font-size: 16px;
        cursor: pointer;
      `;
      
      closeButton.addEventListener('click', () => {
        dialogContainer.style.display = 'none';
      });
      
      buttonContainer.appendChild(closeButton);
    }
    
    dialogContainer.appendChild(dialog);
    dialogContainer.style.display = 'block';
  }

  // Toggle menu
  toggleMenu() {
    const menuContainer = this.elements.get('menuContainer');
    if (!menuContainer) return;
    
    if (menuContainer.style.display === 'none' || menuContainer.style.display === '') {
      menuContainer.style.display = 'flex';
      this.createMenuContent();
    } else {
      menuContainer.style.display = 'none';
    }
  }

  // Create menu content
  createMenuContent() {
    const menuContainer = this.elements.get('menuContainer');
    menuContainer.innerHTML = '';
    
    const menu = document.createElement('div');
    menu.style.cssText = `
      background: rgba(0, 0, 0, 0.95);
      border: 2px solid #ff6b6b;
      border-radius: 10px;
      padding: 30px;
      min-width: 300px;
      color: #fff;
    `;
    
    const menuTitle = document.createElement('h2');
    menuTitle.textContent = 'SPACE VIKINGS';
    menuTitle.style.cssText = `
      font-size: 32px;
      margin-bottom: 30px;
      text-align: center;
      color: #4ecdc4;
      text-shadow: 0 0 10px #4ecdc4;
    `;
    
    const buttonContainer = document.createElement('div');
    buttonContainer.style.cssText = `
      display: flex;
      flex-direction: column;
      gap: 15px;
    `;
    
    const menuItems = [
      { label: 'RESUME GAME', action: () => this.toggleMenu() },
      { label: 'SAVE GAME', action: () => this.showDialog('Save Game', 'Save current game progress?', [
        { label: 'SAVE', callback: () => console.log('Game saved') },
        { label: 'CANCEL', callback: () => {} }
      ]) },
      { label: 'LOAD GAME', action: () => this.showDialog('Load Game', 'Load saved game?', [
        { label: 'LOAD', callback: () => console.log('Game loaded') },
        { label: 'CANCEL', callback: () => {} }
      ]) },
      { label: 'SETTINGS', action: () => this.showSettings() },
      { label: 'HELP', action: () => this.showHelp() },
      { label: 'QUIT', action: () => this.showDialog('Quit Game', 'Are you sure you want to quit?', [
        { label: 'QUIT', callback: () => window.close() },
        { label: 'CANCEL', callback: () => {} }
      ]) }
    ];
    
    menuItems.forEach(item => {
      const button = document.createElement('button');
      button.textContent = item.label;
      button.style.cssText = `
        padding: 15px 30px;
        border: 2px solid #4ecdc4;
        border-radius: 5px;
        background: #000;
        color: #fff;
        font-family: 'Courier New', monospace;
        font-size: 18px;
        cursor: pointer;
        transition: all 0.2s;
      `;
      
      button.addEventListener('mouseenter', () => {
        button.style.background = '#4ecdc4';
      });
      
      button.addEventListener('mouseleave', () => {
        button.style.background = '#000';
      });
      
      button.addEventListener('click', item.action);
      
      buttonContainer.appendChild(button);
    });
    
    menu.appendChild(menuTitle);
    menu.appendChild(buttonContainer);
    menuContainer.appendChild(menu);
  }

  // Show settings dialog
  showSettings() {
    this.showDialog('Settings', 'Game Settings', [
      { label: 'GRAPHICS', callback: () => console.log('Graphics settings') },
      { label: 'SOUND', callback: () => console.log('Sound settings') },
      { label: 'CONTROLS', callback: () => console.log('Control settings') },
      { label: 'BACK', callback: () => this.toggleMenu() }
    ]);
  }

  // Show help dialog
  showHelp() {
    const helpText = `CONTROLS:
- Arrow Keys / WASD: Move
- Space: Fire / Select
- Enter: Confirm
- Escape: Menu

GAME OBJECTIVE:
Explore planets, trade resources,
engage in space combat, and manage
your crew's morale.

Visit https://github.com/Plicerin/Space-Vikings-Resurrected
for more information.`;
    
    this.showDialog('Help', helpText, [
      { label: 'BACK', callback: () => this.toggleMenu() }
    ]);
  }

  // Handle window resize
  handleResize() {
    const canvas = this.canvas;
    if (canvas) {
      // Maintain aspect ratio
      const aspectRatio = 800 / 600;
      const width = window.innerWidth;
      const height = window.innerHeight;
      
      let newWidth = width;
      let newHeight = height;
      
      if (width / height > aspectRatio) {
        newWidth = height * aspectRatio;
      } else {
        newHeight = width / aspectRatio;
      }
      
      canvas.style.width = `${newWidth}px`;
      canvas.style.height = `${newHeight}px`;
    }
  }

  // Get canvas element
  getCanvas() {
    return this.canvas;
  }

  // Get container element
  getContainer() {
    return this.container;
  }
}