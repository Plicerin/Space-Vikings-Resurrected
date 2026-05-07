// Apple II hi-res abstraction over Canvas 2D.
// Logical resolution stays at the Apple II's native 280x192 so all the
// coordinates from the BASIC source translate directly. The canvas itself
// renders at devicePixelRatio * cssScale for crisp anti-aliased output.

const W = 280;
const H = 192;

const PALETTE: Record<number, string> = {
  0: '#000000',
  1: '#22dd55', // green
  2: '#cc44ff', // violet
  3: '#ffffff', // white
  4: '#000000',
  5: '#ff8a2a', // orange
  6: '#3a8cff', // blue
  7: '#ffffff',
};

export class Hires {
  private ctx: CanvasRenderingContext2D;
  private color = '#ffffff';
  private penX = 0;
  private penY = 0;
  private cssScale = 3;
  private dpr = window.devicePixelRatio || 1;

  constructor(private canvas: HTMLCanvasElement) {
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('hires: 2d context unavailable');
    this.ctx = ctx;
    this.fitToViewport();
    this.resize();
    window.addEventListener('resize', () => {
      this.fitToViewport();
      this.resize();
    });
  }

  get width(): number { return W; }
  get height(): number { return H; }

  private fitToViewport(): void {
    const compact = window.innerWidth <= 840;
    const horizontalGutter = compact ? 32 : 48;
    const verticalReserve = compact ? 300 : 140;
    const maxW = Math.max(W, window.innerWidth - horizontalGutter);
    const maxH = Math.max(H, window.innerHeight - verticalReserve);
    const scale = Math.max(1, Math.min(maxW / W, maxH / H));
    this.cssScale = scale;
  }

  private resize(): void {
    const phys = this.cssScale * this.dpr;
    const cssWidth = W * this.cssScale;
    const cssHeight = H * this.cssScale;
    this.canvas.width = W * phys;
    this.canvas.height = H * phys;
    this.canvas.style.width = `${cssWidth}px`;
    this.canvas.style.height = `${cssHeight}px`;
    const frame = this.canvas.parentElement;
    if (frame instanceof HTMLElement) {
      frame.style.width = `${cssWidth}px`;
      frame.style.height = `${cssHeight}px`;
    }
    const cpuPanel = document.getElementById('cpu-panel');
    if (cpuPanel instanceof HTMLElement) {
      cpuPanel.style.width = `${cssWidth}px`;
    }
    this.ctx.setTransform(phys, 0, 0, phys, 0, 0);
    this.ctx.imageSmoothingEnabled = false;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.fillBlack();
  }

  private fillBlack(): void {
    this.ctx.save();
    this.ctx.setTransform(1, 0, 0, 1, 0, 0);
    this.ctx.fillStyle = '#000';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    this.ctx.restore();
  }

  // HGR — clear hi-res screen
  hgr(): void { this.fillBlack(); }

  // HCOLOR= n
  hcolor(idx: number): void {
    this.color = PALETTE[idx & 7] ?? '#ffffff';
  }

  // HPLOT x, y — single point
  hplot(x: number, y: number): void {
    this.penX = x;
    this.penY = y;
    this.ctx.fillStyle = this.color;
    this.ctx.fillRect(x, y, 1, 1);
  }

  // HPLOT TO x, y — line from pen to (x, y)
  hplotTo(x: number, y: number): void {
    this.ctx.beginPath();
    this.ctx.moveTo(this.penX + 0.5, this.penY + 0.5);
    this.ctx.lineTo(x + 0.5, y + 0.5);
    this.ctx.strokeStyle = this.color;
    this.ctx.lineWidth = 1;
    this.ctx.stroke();
    this.penX = x;
    this.penY = y;
  }

  // HPLOT x1,y1 TO x2,y2 — convenience
  line(x1: number, y1: number, x2: number, y2: number): void {
    this.hplot(x1, y1);
    this.hplotTo(x2, y2);
  }

  // HLIN x1, x2 AT y
  hlin(x1: number, x2: number, y: number): void {
    this.line(x1, y, x2, y);
  }

  clearRect(x: number, y: number, width: number, height: number): void {
    this.ctx.fillStyle = '#000';
    this.ctx.fillRect(x, y, width, height);
  }

  // VTAB / HTAB style text. Apple II text grid is 40 cols x 24 rows.
  // We use 1-based coordinates to match the BASIC convention.
  text(s: string, col: number, row: number, opts?: { invert?: boolean }): void {
    const cellW = 7;
    const cellH = 8;
    if (col < 1 || col > 40 || row < 1 || row > 24) return;
    const maxChars = 41 - col;
    if (maxChars <= 0) return;
    const visible = s.slice(0, maxChars);
    if (visible.length === 0) return;
    const px = (col - 1) * cellW;
    const py = (row - 1) * cellH;
    this.ctx.font = '8px "Courier New", ui-monospace, Menlo, Consolas, monospace';
    this.ctx.textAlign = 'left';
    this.ctx.textBaseline = 'top';
    if (opts?.invert) {
      this.ctx.fillStyle = this.color;
      const width = Math.max(visible.length * cellW, Math.ceil(this.ctx.measureText(visible).width));
      this.ctx.fillRect(px, py - 1, width, cellH + 1);
      this.ctx.fillStyle = '#000';
    } else {
      this.ctx.fillStyle = this.color;
    }
    this.ctx.fillText(visible, px, py);
  }
}
