// Static click-to-select Dasher layout for the #roadmap canvas. The right half shows the top-K
// candidates as probability-weighted boxes; clicking one accepts it (make) and the right half
// refreshes from the new frontier. The left half is the committed history. No animation, no zoom.

import { MAX_Y, K, HISTORY_SLOTS, HISTORY_SHRINK, NEXTNEXT_RIGHT_FRAC, RIGHT_MARGIN_PX } from "./spec";
import {
  topKIntervals,
  childrenIntervals,
  boxContaining,
  type FrontierEntry,
  type DasherBox,
  type NextNextBox,
} from "./layout";

const BG = "#0d1117";
const INK = "#f4f7fb";
const DARK_INK = "#1a1206";
const LABEL_LIGHT = "rgba(244, 247, 251, 0.7)";
const LABEL_DARK = "rgba(26, 18, 6, 0.62)";
const NEXTNEXT_FILL = "rgba(13, 17, 23, 0.5)";
const HISTORY = "#3d4654";
const DIVIDER = "rgba(224, 163, 58, 0.55)";
const BOX_RADIUS = 10;

// Amber, brightest at the top rank and dimming down the list, so the strongest recommendation
// reads at a glance. Returns the fill and whether it is light enough to need dark text.
function candidateFill(rank: number, total: number): { fill: string; dark: boolean } {
  const f = total > 1 ? (total - 1 - rank) / (total - 1) : 1;
  const l = 30 + f * 34;
  return { fill: `hsl(38, ${(40 + f * 42).toFixed(0)}%, ${l.toFixed(0)}%)`, dark: l > 50 };
}

const MORPH_MS = 320;
const ACCEPT_FROM = "#e9b24f";

const lerp = (a: number, b: number, e: number): number => a + (b - a) * e;

// Interpolate between two #rrggbb colors.
function hexLerp(a: string, b: string, e: number): string {
  const pa = parseInt(a.slice(1), 16);
  const pb = parseInt(b.slice(1), 16);
  const ch = (s: number) => [(s >> 16) & 255, (s >> 8) & 255, s & 255];
  const [r1, g1, b1] = ch(pa);
  const [r2, g2, b2] = ch(pb);
  return `rgb(${Math.round(lerp(r1, r2, e))}, ${Math.round(lerp(g1, g2, e))}, ${Math.round(lerp(b1, b2, e))})`;
}

export type ZoomerOptions = {
  canvas: HTMLCanvasElement;
  onCommit: (cp: number) => void;
  k?: number;
};

export class DasherZoomer {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private onCommit: (cp: number) => void;
  private k: number;

  private boxes: DasherBox[] = [];
  private children = new Map<number, NextNextBox[]>();
  private history: number[] = [];

  // Morph transition state.
  private prevBoxes: DasherBox[] = [];
  private accepted: number | null = null;
  private acceptedRect: { x: number; y: number; w: number; h: number } | null = null;
  private t0: number | null = null;
  private raf = 0;
  private reducedMotion: boolean;

  constructor(opts: ZoomerOptions) {
    const ctx = opts.canvas.getContext("2d");
    if (!ctx) throw new Error("missing canvas context");
    this.canvas = opts.canvas;
    this.ctx = ctx;
    this.onCommit = opts.onCommit;
    this.k = opts.k ?? K;
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    this.canvas.addEventListener("click", this.onClick);
  }

  // Rebuild the candidate boxes and their next-next previews. When `acceptedCp` is given, morph
  // from the previous layout: the accepted glyph flies to history while the rest resize in place.
  reseed(frontier: FrontierEntry[], dependentsMap?: Map<number, number[]>, acceptedCp?: number): void {
    cancelAnimationFrame(this.raf);
    this.prevBoxes = this.boxes;
    this.boxes = topKIntervals(frontier, this.k);
    this.children = new Map<number, NextNextBox[]>();
    for (const box of this.boxes) {
      this.children.set(box.cp, childrenIntervals(box, dependentsMap?.get(box.cp) ?? []));
    }

    const prev = acceptedCp != null ? this.prevBoxes.find((b) => b.cp === acceptedCp) : undefined;
    if (prev && !this.reducedMotion) {
      this.accepted = acceptedCp!;
      this.acceptedRect = {
        x: this.canvas.width / 2,
        y: this.yOf(prev.lo),
        w: this.canvas.width / 2,
        h: this.yOf(prev.hi) - this.yOf(prev.lo),
      };
      this.t0 = null;
      this.raf = requestAnimationFrame(this.tick);
    } else {
      this.render();
    }
  }

  private tick = (now: number): void => {
    if (this.t0 === null) this.t0 = now;
    const t = Math.min(1, (now - this.t0) / MORPH_MS);
    const e = 1 - Math.pow(1 - t, 3);
    this.renderMorph(e);
    if (t < 1) {
      this.raf = requestAnimationFrame(this.tick);
    } else {
      this.accepted = null;
      this.acceptedRect = null;
      this.render();
    }
  };

  // Capped FIFO of committed cps; index 0 is most recent, oldest dropped past HISTORY_SLOTS.
  historyPush(cp: number): void {
    this.history.unshift(cp);
    if (this.history.length > HISTORY_SLOTS) this.history.length = HISTORY_SLOTS;
  }

  // Accept the candidate whose row was clicked in the right half.
  private onClick = (e: MouseEvent): void => {
    if (this.boxes.length === 0) return;
    const [px, py] = this.at(e);
    if (px < this.canvas.width / 2) return;
    const box = boxContaining(this.boxes, (py / this.canvas.height) * MAX_Y);
    if (box) this.onCommit(box.cp);
  };

  // Client coords -> internal canvas pixels by the rect ratio.
  private at(e: MouseEvent): [number, number] {
    const r = this.canvas.getBoundingClientRect();
    return [
      ((e.clientX - r.left) / r.width) * this.canvas.width,
      ((e.clientY - r.top) / r.height) * this.canvas.height,
    ];
  }

  // Lattice Y -> screen Y (the whole lattice maps to the full canvas height).
  private yOf(latY: number): number {
    return (latY / MAX_Y) * this.canvas.height;
  }

  render(): void {
    const c = this.ctx;
    const w = this.canvas.width;
    const h = this.canvas.height;
    c.clearRect(0, 0, w, h);
    c.fillStyle = BG;
    c.fillRect(0, 0, w, h);

    if (this.boxes.length === 0) {
      this.drawDone(w, h);
      return;
    }

    this.drawCandidates(w, h);
    this.drawHistory(w, h);
    this.drawDivider(w, h);
  }

  // One morph frame at eased progress `e`: candidates resize old->new, the accepted glyph flies
  // to the history slot it is about to occupy.
  private renderMorph(e: number): void {
    const c = this.ctx;
    const w = this.canvas.width;
    const h = this.canvas.height;
    c.clearRect(0, 0, w, h);
    c.fillStyle = BG;
    c.fillRect(0, 0, w, h);
    this.drawCandidatesMorph(w, e);
    this.drawHistory(w, h, 1);
    this.drawAcceptedFly(e);
    this.drawDivider(w, h);
  }

  // Interpolate each candidate by codepoint identity: persisting boxes resize, new ones grow from
  // their center, departing ones fade out. No labels or children mid-flight, for clarity.
  private drawCandidatesMorph(w: number, e: number): void {
    const c = this.ctx;
    const left = w / 2;
    const boxW = w - left;
    const newTotal = this.boxes.length;
    const oldTotal = this.prevBoxes.length;
    const newByCp = new Map(this.boxes.map((b, i) => [b.cp, { b, i }]));
    const oldByCp = new Map(this.prevBoxes.map((b, i) => [b.cp, { b, i }]));
    for (const cp of new Set<number>([...newByCp.keys(), ...oldByCp.keys()])) {
      if (cp === this.accepted) continue;
      const nn = newByCp.get(cp);
      const oo = oldByCp.get(cp);
      let lo: number, hi: number, alpha: number, fill: string, dark: boolean;
      if (nn && oo) {
        lo = lerp(oo.b.lo, nn.b.lo, e);
        hi = lerp(oo.b.hi, nn.b.hi, e);
        alpha = 1;
        ({ fill, dark } = candidateFill(nn.i, newTotal));
      } else if (nn) {
        const mid = (nn.b.lo + nn.b.hi) / 2;
        lo = lerp(mid, nn.b.lo, e);
        hi = lerp(mid, nn.b.hi, e);
        alpha = e;
        ({ fill, dark } = candidateFill(nn.i, newTotal));
      } else {
        lo = oo!.b.lo;
        hi = oo!.b.hi;
        alpha = 1 - e;
        ({ fill, dark } = candidateFill(oo!.i, oldTotal));
      }
      const top = this.yOf(lo);
      const bh = this.yOf(hi) - top;
      if (bh < 0.5) continue;
      const r = Math.min(BOX_RADIUS, bh / 2);
      c.globalAlpha = alpha;
      c.fillStyle = fill;
      c.beginPath();
      c.roundRect(left, top + 1, boxW, bh - 2, [r, 0, 0, r]);
      c.fill();
      if (bh >= 16) {
        c.fillStyle = dark ? DARK_INK : INK;
        c.textAlign = "left";
        c.textBaseline = "middle";
        c.font = `${Math.min(60, Math.max(18, bh * 0.46))}px system-ui, sans-serif`;
        c.fillText(String.fromCodePoint(cp), left + 18, top + bh / 2);
      }
      c.globalAlpha = 1;
    }
  }

  // The accepted glyph travelling from its old box to the newest history slot, amber fading to slate.
  private drawAcceptedFly(e: number): void {
    if (this.acceptedRect == null || this.accepted == null) return;
    const c = this.ctx;
    const h = this.canvas.height;
    const base = Math.min(64, h * 0.14);
    const r0 = this.acceptedRect;
    const x = lerp(r0.x, this.canvas.width / 2 - 6 - base, e);
    const y = lerp(r0.y, h / 2 - base / 2, e);
    const ww = lerp(r0.w, base, e);
    const hh = lerp(r0.h, base, e);
    c.fillStyle = hexLerp(ACCEPT_FROM, HISTORY, e);
    c.beginPath();
    c.roundRect(x, y, ww, hh, Math.min(BOX_RADIUS, hh * 0.16));
    c.fill();
    c.fillStyle = INK;
    c.textAlign = "center";
    c.textBaseline = "middle";
    c.font = `${Math.max(12, Math.min(ww, hh) * 0.5)}px system-ui, sans-serif`;
    c.fillText(String.fromCodePoint(this.accepted), x + ww / 2, y + hh / 2);
    c.textAlign = "left";
  }

  // Candidate boxes fill the right half, stacked by weight and shaded by rank; glyph on top,
  // U+code and score under.
  private drawCandidates(w: number, h: number): void {
    const c = this.ctx;
    const left = w / 2;
    const boxW = w - left;
    const total = this.boxes.length;
    this.boxes.forEach((box, i) => {
      const top = this.yOf(box.lo);
      const bh = this.yOf(box.hi) - top;
      if (bh < 0.5) return;

      const { fill, dark } = candidateFill(i, total);
      const r = Math.min(BOX_RADIUS, bh / 2);
      c.fillStyle = fill;
      c.beginPath();
      c.roundRect(left, top + 1, boxW, bh - 2, [r, 0, 0, r]);
      c.fill();

      this.drawChildren(box, left, boxW);

      if (bh < 16) return;
      const cy = top + bh / 2;
      const x = left + 18;
      const glyph = String.fromCodePoint(box.cp);
      const big = Math.min(60, Math.max(18, bh * 0.46));
      c.textAlign = "left";
      c.fillStyle = dark ? DARK_INK : INK;
      if (bh >= 52) {
        const small = 14;
        const yy = cy - (big + 4 + small) / 2;
        c.textBaseline = "top";
        c.font = `${big}px system-ui, sans-serif`;
        c.fillText(glyph, x, yy);
        c.fillStyle = dark ? LABEL_DARK : LABEL_LIGHT;
        c.font = `${small}px system-ui, sans-serif`;
        c.fillText(
          `U+${box.cp.toString(16).toUpperCase().padStart(4, "0")} · ${box.score.toFixed(1)}`,
          x,
          yy + big + 4,
        );
      } else {
        c.textBaseline = "middle";
        c.font = `${big}px system-ui, sans-serif`;
        c.fillText(glyph, x, cy);
      }
    });
  }

  // Next-next preview: the dependents this candidate unlocks, as amber slices in its rightmost
  // slice, subdividing its vertical interval. Display only; not clickable, no score.
  private drawChildren(parent: DasherBox, left: number, boxW: number): void {
    const kids = this.children.get(parent.cp);
    if (!kids || kids.length === 0) return;
    const c = this.ctx;
    const cw = boxW * NEXTNEXT_RIGHT_FRAC;
    const cx = left + boxW - cw - RIGHT_MARGIN_PX;
    if (cw < 4 || cx < left) return;
    for (const kid of kids) {
      const top = this.yOf(kid.lo);
      const kh = this.yOf(kid.hi) - top;
      if (kh < 0.5) continue;
      const r = Math.min(5, kh / 2);
      c.fillStyle = NEXTNEXT_FILL;
      c.beginPath();
      c.roundRect(cx, top + 1, cw, kh - 2, r);
      c.fill();
      if (kh < 14) continue;
      c.fillStyle = INK;
      c.textBaseline = "middle";
      c.textAlign = "left";
      c.font = `${Math.min(26, Math.max(13, kh * 0.55))}px system-ui, sans-serif`;
      c.fillText(String.fromCodePoint(kid.cp), cx + 7, top + kh / 2);
    }
  }

  // History trail: accepted targets left of center, most-recent nearest, each step shrinking and
  // fading. Display only; mirrors Dasher's left-scrolling text.
  // `skip` reserves the newest slots without drawing them (the flying glyph lands there mid-morph).
  private drawHistory(w: number, h: number, skip = 0): void {
    if (this.history.length === 0) return;
    const c = this.ctx;
    const cy = h / 2;
    const base = Math.min(64, h * 0.14);
    let edge = w / 2 - 6;
    for (let i = 0; i < this.history.length; i++) {
      const size = base * Math.pow(HISTORY_SHRINK, i);
      const x = edge - size;
      if (x < -size) break;
      if (i >= skip) {
        c.fillStyle = HISTORY;
        c.globalAlpha = Math.max(0.2, 1 - i * 0.16);
        c.beginPath();
        c.roundRect(x, cy - size / 2, size, size, Math.min(8, size * 0.16));
        c.fill();
        c.globalAlpha = 1;
        c.fillStyle = INK;
        c.textAlign = "center";
        c.textBaseline = "middle";
        c.font = `${Math.max(11, size * 0.5)}px system-ui, sans-serif`;
        c.fillText(String.fromCodePoint(this.history[i]), x + size / 2, cy);
      }
      edge = x - 4;
    }
    c.textAlign = "left";
  }

  // Vertical line at center: the boundary between accepted history (left) and candidates (right).
  private drawDivider(w: number, h: number): void {
    const c = this.ctx;
    c.strokeStyle = DIVIDER;
    c.lineWidth = 1.5;
    c.beginPath();
    c.moveTo(w / 2, 0);
    c.lineTo(w / 2, h);
    c.stroke();
  }

  private drawDone(w: number, h: number): void {
    const c = this.ctx;
    c.fillStyle = "#3fa45b";
    c.font = "600 28px system-ui, sans-serif";
    c.textAlign = "center";
    c.textBaseline = "middle";
    c.fillText("all targets covered", w / 2, h / 2);
    c.textAlign = "left";
  }
}
