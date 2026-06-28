// Layout constants for the static Dasher view. The lattice [0, MAX_Y] carries the vertical
// probability split; everything else is box geometry.

export const MAX_Y = 4096;

// Number of top frontier candidates shown as boxes.
export const K = 10;

// Softmax temperature over max-normalized scores. Lower = sharper, so the top pick clearly
// dominates instead of all boxes looking the same height.
export const SOFTMAX_T = 0.28;

// Every top-K box keeps at least MIN_BOX_FRAC of MAX_Y after normalization, so low scorers stay clickable.
export const MIN_BOX_FRAC = 0.02;

// History trail: per-step shrink and slot count of accepted targets drawn left of center.
export const HISTORY_SHRINK = 0.7;
export const HISTORY_SLOTS = 6;

// Next-next preview: cap on dependents per box, the rightmost slice they occupy, and the right margin.
export const NEXTNEXT_MAX = 8;
export const NEXTNEXT_RIGHT_FRAC = 0.35;
export const RIGHT_MARGIN_PX = 24;
