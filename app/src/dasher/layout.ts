// Pure top-K interval layout over the lattice [0, MAX_Y]. No DOM, no wasm.

import { MAX_Y, SOFTMAX_T, MIN_BOX_FRAC } from "./spec";

export type FrontierEntry = { cp: number; score: number };
export type DasherBox = { cp: number; score: number; lo: number; hi: number };
export type NextNextBox = { cp: number; lo: number; hi: number };

// Tile [0, MAX_Y] into the top-K frontier candidates, lengths proportional to a
// rank-floored weight so zero-score and identical-score boxes stay legible.
export function topKIntervals(frontier: FrontierEntry[], k: number): DasherBox[] {
  if (frontier.length === 0) return [];
  const top = frontier.slice(0, Math.min(k, frontier.length));
  const n = top.length;

  const maxScore = Math.max(...top.map((e) => e.score), 0);
  const norm = maxScore > 0 ? maxScore : 1;
  // Softmax over max-normalized scores: equal scores split evenly, a clear leader takes most height.
  const weights = top.map((e) => Math.exp(e.score / norm / SOFTMAX_T));
  const sum = weights.reduce((a, b) => a + b, 0);

  const boxes: DasherBox[] = [];
  let lo = 0;
  for (let i = 0; i < n; i++) {
    const length = (MAX_Y * weights[i]) / sum;
    const hi = i === n - 1 ? MAX_Y : lo + length;
    boxes.push({ cp: top[i].cp, score: top[i].score, lo, hi });
    lo = hi;
  }
  return enforceMinHeight(boxes);
}

// Redistribute so no box falls below MIN_BOX_FRAC of MAX_Y while keeping the tiling contiguous.
function enforceMinHeight(boxes: DasherBox[]): DasherBox[] {
  const n = boxes.length;
  if (n === 0) return boxes;
  const minLen = MIN_BOX_FRAC * MAX_Y;
  if (minLen * n >= MAX_Y) {
    const even = MAX_Y / n;
    let lo = 0;
    return boxes.map((b, i) => {
      const hi = i === n - 1 ? MAX_Y : lo + even;
      const box = { ...b, lo, hi };
      lo = hi;
      return box;
    });
  }
  const lens = boxes.map((b) => b.hi - b.lo);
  let deficit = 0;
  let surplus = 0;
  for (const len of lens) {
    if (len < minLen) deficit += minLen - len;
    else surplus += len - minLen;
  }
  if (deficit === 0 || surplus === 0) return boxes;
  const scale = (surplus - deficit) / surplus;
  const adjusted = lens.map((len) => (len < minLen ? minLen : minLen + (len - minLen) * scale));
  let lo = 0;
  return boxes.map((b, i) => {
    const hi = i === n - 1 ? MAX_Y : lo + adjusted[i];
    const box = { ...b, lo, hi };
    lo = hi;
    return box;
  });
}

// Split a parent box's interval equally among its dependents. Empty if none.
// Equal split is the uniform-prior placeholder; structural weighting may replace it later.
export function childrenIntervals(parent: DasherBox, dependents: number[]): NextNextBox[] {
  const n = dependents.length;
  if (n === 0) return [];
  const span = parent.hi - parent.lo;
  const children: NextNextBox[] = [];
  let lo = parent.lo;
  for (let i = 0; i < n; i++) {
    const hi = i === n - 1 ? parent.hi : lo + span / n;
    children.push({ cp: dependents[i], lo, hi });
    lo = hi;
  }
  return children;
}

// Box whose interval contains the given lattice point, or null.
export function boxContaining(boxes: DasherBox[], latticeY: number): DasherBox | null {
  for (const b of boxes) {
    if (latticeY >= b.lo && latticeY < b.hi) return b;
  }
  if (boxes.length > 0 && latticeY >= boxes[boxes.length - 1].hi) return boxes[boxes.length - 1];
  return null;
}
