// Graphics Renderer for Space Vikings Remake
// Renders Apple II shape tables to modern HTML5 Canvas

export class GraphicsRenderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.scaleFactor = 2;
    this.shapeCache = new Map();
    
    // Load converted shape data
    this.loadShapes();
  }

  // Load converted JSON shape data
  async loadShapes() {
    try {
      // Load planet shapes (converted from Apple II shape tables)
      const planetResponse = await fetch('/shapes_json/PLANET0.shape.json');
      this.planetShapes = await planetResponse.json();
      
      // Load ship shapes
      const shipResponse = await fetch('/shapes_json/SHIP0.shape.json');
      this.shipShapes = await shipResponse.json();
      
      console.log('Shapes loaded:', this.planetShapes.length, 'planets,', this.shipShapes.length, 'ships');
    } catch (error) {
      console.warn('Could not load shape data:', error);
      this.createDefaultShapes();
    }
  }

  // Create default shapes if loading fails
  createDefaultShapes() {
    this.planetShapes = Array(21).fill(null).map((_, i) => ({
      id: `PLANET${i}`,
      name: `Planet ${i + 1}`,
      vertices: this.generateCirclePoints(30 + i * 2, 8 + i % 4)
    }));
    
    this.shipShapes = [
      {
        id: 'SHIP0',
        name: 'Player Ship',
        vertices: [[0, -10], [10, 5], [0, 0], [-10, 5]]
      },
      {
        id: 'SHIP1',
        name: 'Enemy Ship',
        vertices: [[0, -8], [8, 8], [-8, 8]]
      }
    ];
  }

  // Generate points for a circle
  generateCirclePoints(radius, segments) {
    const points = [];
    for (let i = 0; i < segments; i++) {
      const angle = (i / segments) * Math.PI * 2;
      points.push([
        Math.cos(angle) * radius,
        Math.sin(angle) * radius
      ]);
    }
    return points;
  }

  // Render a shape at coordinates
  renderShape(shapeId, x, y, scale = 1, rotation = 0, color = '#fff') {
    const shape = this.getShape(shapeId);
    if (!shape) return;

    this.ctx.save();
    this.ctx.translate(x, y);
    this.ctx.scale(scale * this.scaleFactor, scale * this.scaleFactor);
    this.ctx.rotate(rotation * Math.PI / 180);
    
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = 1;
    this.ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
    
    this.ctx.beginPath();
    shape.vertices.forEach((vertex, i) => {
      if (i === 0) {
        this.ctx.moveTo(vertex[0], vertex[1]);
      } else {
        this.ctx.lineTo(vertex[0], vertex[1]);
      }
    });
    this.ctx.closePath();
    this.ctx.fill();
    this.ctx.stroke();
    
    this.ctx.restore();
  }

  // Get shape by ID
  getShape(shapeId) {
    // Search in planet shapes
    const planetShape = this.planetShapes?.find(s => s.id === shapeId);
    if (planetShape) return planetShape;
    
    // Search in ship shapes
    const shipShape = this.shipShapes?.find(s => s.id === shapeId);
    if (shipShape) return shipShape;
    
    return null;
  }

  // Render text (Apple II style monospace)
  renderText(text, x, y, color = '#fff', size = 14) {
    this.ctx.save();
    this.ctx.font = `${size}px monospace`;
    this.ctx.fillStyle = color;
    this.ctx.textBaseline = 'top';
    this.ctx.fillText(text, x, y);
    this.ctx.restore();
  }

  // Clear canvas
  clear(color = '#000') {
    this.ctx.fillStyle = color;
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
  }

  // Render galaxy map
  renderGalaxyMap(planets, currentPlanetIndex) {
    this.clear('#000');
    
    // Draw starfield background
    this.renderStarfield();
    
    // Draw planets
    planets.forEach((planet, index) => {
      const angle = (index / planets.length) * Math.PI * 2;
      const distance = 150 + index * 20;
      const x = this.canvas.width / 2 + Math.cos(angle) * distance;
      const y = this.canvas.height / 2 + Math.sin(angle) * distance;
      
      const color = index === currentPlanetIndex ? '#ff6b6b' : '#4ecdc4';
      
      this.renderShape(`PLANET${index % 21}`, x, y, 1, 0, color);
      this.renderText(planet.name, x - 20, y + 30, '#fff', 10);
    });
  }

  // Render starfield background
  renderStarfield() {
    this.ctx.save();
    for (let i = 0; i < 100; i++) {
      const x = Math.random() * this.canvas.width;
      const y = Math.random() * this.canvas.height;
      const size = Math.random() * 2;
      
      this.ctx.beginPath();
      this.ctx.arc(x, y, size, 0, Math.PI * 2);
      this.ctx.fillStyle = '#fff';
      this.ctx.fill();
    }
    this.ctx.restore();
  }

  // Render ship in combat
  renderShipCombat(ship, x, y, isPlayer = true) {
    const shipType = isPlayer ? 'SHIP0' : 'SHIP1';
    const color = isPlayer ? '#4ecdc4' : '#ff6b6b';
    
    this.renderShape(shipType, x, y, 1, ship.rotation || 0, color);
    
    // Draw health bar
    if (ship.health !== undefined) {
      const barWidth = 40;
      const barHeight = 4;
      const healthPercent = ship.health / ship.maxHealth;
      
      this.ctx.fillStyle = '#555';
      this.ctx.fillRect(x - barWidth / 2, y - 40, barWidth, barHeight);
      this.ctx.fillStyle = healthPercent > 0.5 ? '#4ecdc4' : healthPercent > 0.25 ? '#f7b267' : '#ff6b6b';
      this.ctx.fillRect(x - barWidth / 2, y - 40, barWidth * healthPercent, barHeight);
    }
  }

  // Render laser beam
  renderLaser(fromX, fromY, toX, toY, intensity = 1) {
    this.ctx.save();
    this.ctx.strokeStyle = `rgba(255, ${100 + intensity * 155}, 100, 0.8)`;
    this.ctx.lineWidth = intensity * 3;
    this.ctx.lineCap = 'round';
    
    this.ctx.beginPath();
    this.ctx.moveTo(fromX, fromY);
    this.ctx.lineTo(toX, toY);
    this.ctx.stroke();
    
    // Glow effect
    this.ctx.strokeStyle = `rgba(255, ${50 + intensity * 105}, 50, 0.4)`;
    this.ctx.lineWidth = intensity * 6;
    this.ctx.stroke();
    
    this.ctx.restore();
  }

  // Render explosion
  renderExplosion(x, y, radius, intensity = 1) {
    this.ctx.save();
    
    // Outer circle
    const gradient = this.ctx.createRadialGradient(x, y, 0, x, y, radius);
    gradient.addColorStop(0, `rgba(255, ${100 + intensity * 155}, 0, 0.8)`);
    gradient.addColorStop(0.5, `rgba(255, ${50 + intensity * 105}, 0, 0.4)`);
    gradient.addColorStop(1, 'rgba(255, 50, 0, 0)');
    
    this.ctx.fillStyle = gradient;
    this.ctx.beginPath();
    this.ctx.arc(x, y, radius, 0, Math.PI * 2);
    this.ctx.fill();
    
    // Particles
    for (let i = 0; i < intensity * 20; i++) {
      const angle = Math.random() * Math.PI * 2;
      const distance = Math.random() * radius;
      const particleX = x + Math.cos(angle) * distance;
      const particleY = y + Math.sin(angle) * distance;
      const size = Math.random() * 3 + 1;
      
      this.ctx.fillStyle = `rgba(255, ${100 + Math.random() * 155}, 0, 0.8)`;
      this.ctx.beginPath();
      this.ctx.arc(particleX, particleY, size, 0, Math.PI * 2);
      this.ctx.fill();
    }
    
    this.ctx.restore();
  }
}