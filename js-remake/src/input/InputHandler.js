// Input Handler for Space Vikings Remake
// Converts modern controls to Apple II joystick/button input

export class InputHandler {
  constructor() {
    this.keys = new Set();
    this.mouse = { x: 0, y: 0, down: false };
    this.gamepad = null;
    this.joystick = { x: 0, y: 0, button: false };
    this.callbacks = new Map();
    
    this.setupEventListeners();
  }

  setupEventListeners() {
    // Keyboard events
    window.addEventListener('keydown', (e) => {
      this.keys.add(e.key.toLowerCase());
      this.triggerCallbacks('keydown', e.key);
    });

    window.addEventListener('keyup', (e) => {
      this.keys.delete(e.key.toLowerCase());
      this.triggerCallbacks('keyup', e.key);
    });

    // Mouse events
    window.addEventListener('mousemove', (e) => {
      this.mouse.x = e.clientX;
      this.mouse.y = e.clientY;
      this.triggerCallbacks('mousemove', { x: e.clientX, y: e.clientY });
    });

    window.addEventListener('mousedown', () => {
      this.mouse.down = true;
      this.triggerCallbacks('mousedown');
    });

    window.addEventListener('mouseup', () => {
      this.mouse.down = false;
      this.triggerCallbacks('mouseup');
    });

    // Touch events
    window.addEventListener('touchstart', (e) => {
      if (e.touches.length > 0) {
        this.mouse.x = e.touches[0].clientX;
        this.mouse.y = e.touches[0].clientY;
        this.mouse.down = true;
        this.triggerCallbacks('touchstart');
      }
    });

    window.addEventListener('touchmove', (e) => {
      if (e.touches.length > 0) {
        this.mouse.x = e.touches[0].clientX;
        this.mouse.y = e.touches[0].clientY;
        this.triggerCallbacks('touchmove');
      }
      e.preventDefault();
    });

    window.addEventListener('touchend', () => {
      this.mouse.down = false;
      this.triggerCallbacks('touchend');
    });

    // Gamepad events
    window.addEventListener('gamepadconnected', (e) => {
      this.gamepad = e.gamepad;
      console.log('Gamepad connected:', e.gamepad.id);
      this.triggerCallbacks('gamepadconnected', e.gamepad);
    });

    window.addEventListener('gamepaddisconnected', (e) => {
      if (this.gamepad && this.gamepad.index === e.gamepad.index) {
        this.gamepad = null;
        console.log('Gamepad disconnected:', e.gamepad.id);
        this.triggerCallbacks('gamepaddisconnected', e.gamepad);
      }
    });
  }

  // Update gamepad state (call in game loop)
  updateGamepad() {
    if (navigator.getGamepads) {
      const gamepads = navigator.getGamepads();
      if (gamepads[0]) {
        this.gamepad = gamepads[0];
        
        // Convert gamepad axes to joystick values
        const axisX = this.gamepad.axes[0] || 0;
        const axisY = this.gamepad.axes[1] || 0;
        
        // Convert to Apple II joystick range (0-255)
        this.joystick.x = Math.floor((axisX + 1) * 127.5);
        this.joystick.y = Math.floor((axisY + 1) * 127.5);
        
        // Button 0 as joystick button
        this.joystick.button = this.gamepad.buttons[0]?.pressed || false;
      }
    }
  }

  // Convert modern controls to Apple II joystick values (95FD-95FE)
  getJoystickValues() {
    // Use arrow keys or WASD as fallback
    let x = 127;  // Center position
    let y = 127;  // Center position
    
    if (this.keys.has('arrowleft') || this.keys.has('a')) x = 50;
    if (this.keys.has('arrowright') || this.keys.has('d')) x = 200;
    if (this.keys.has('arrowup') || this.keys.has('w')) y = 50;
    if (this.keys.has('arrowdown') || this.keys.has('s')) y = 200;
    
    // Override with gamepad if available
    if (this.gamepad) {
      x = this.joystick.x;
      y = this.joystick.y;
    }
    
    // Map to Apple II joystick memory addresses
    // $95FD = X value (0-255)
    // $95FE = Y value (0-255)
    return {
      x,  // $95FD
      y   // $95FE
    };
  }

  // Get joystick button state
  getButtonState() {
    // Space, Enter, or mouse click as button
    const keyboardButton = this.keys.has(' ') || this.keys.has('enter');
    
    // Combine with gamepad button
    const buttonPressed = keyboardButton || this.mouse.down || this.joystick.button;
    
    return buttonPressed;
  }

  // Check for specific key
  isKeyPressed(key) {
    return this.keys.has(key.toLowerCase());
  }

  // Check for key combination
  isComboPressed(keys) {
    return keys.every(key => this.keys.has(key.toLowerCase()));
  }

  // Register callback for specific event
  on(event, callback) {
    if (!this.callbacks.has(event)) {
      this.callbacks.set(event, []);
    }
    this.callbacks.get(event).push(callback);
  }

  // Trigger all callbacks for an event
  triggerCallbacks(event, data = null) {
    const callbacks = this.callbacks.get(event);
    if (callbacks) {
      callbacks.forEach(callback => callback(data));
    }
  }

  // Get control mapping for current input method
  getControlMapping() {
    if (this.gamepad) {
      return {
        method: 'gamepad',
        mapping: {
          move: 'Left Stick',
          fire: 'A Button',
          select: 'B Button',
          menu: 'Start Button',
          special: 'X Button'
        }
      };
    } else if (this.mouse.down || window.matchMedia('(pointer: coarse)').matches) {
      return {
        method: 'touch',
        mapping: {
          move: 'Tap & Drag',
          fire: 'Tap',
          select: 'Double Tap',
          menu: 'Long Press',
          special: 'Two Finger Tap'
        }
      };
    } else {
      return {
        method: 'keyboard',
        mapping: {
          move: 'WASD / Arrow Keys',
          fire: 'Space',
          select: 'Enter',
          menu: 'Escape',
          special: 'Shift'
        }
      };
    }
  }

  // Get input summary for debugging
  getInputSummary() {
    return {
      keys: Array.from(this.keys),
      mouse: { ...this.mouse },
      gamepad: this.gamepad ? {
        id: this.gamepad.id,
        axes: this.gamepad.axes.map(a => a.toFixed(2)),
        buttons: this.gamepad.buttons.map(b => b.pressed)
      } : null,
      joystick: this.getJoystickValues(),
      button: this.getButtonState()
    };
  }

  // Reset all inputs
  reset() {
    this.keys.clear();
    this.mouse.down = false;
    this.joystick.x = 127;
    this.joystick.y = 127;
    this.joystick.button = false;
  }
}