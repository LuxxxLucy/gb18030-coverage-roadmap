import init, { Roadmap } from "../pkg";
import "./style.css";
import { DasherZoomer } from "./dasher/zoomer";
import { K, NEXTNEXT_MAX } from "./dasher/spec";
import type { FrontierEntry } from "./dasher/layout";

type TargetState = { cp: number; state: number };
type GraphNode = { cp: number; state: number; layer: number };
type GraphEdge = { from_cp: number; to_cp: number };
type Graph = { nodes: GraphNode[]; edges: GraphEdge[] };

const canvas = document.querySelector<HTMLCanvasElement>("#roadmap");
const sitemap = document.querySelector<HTMLCanvasElement>("#sitemap");
const graph = document.querySelector<HTMLCanvasElement>("#graph");
const summary = document.querySelector<HTMLParagraphElement>("#summary");
if (!canvas || !sitemap || !graph || !summary) {
  throw new Error("missing app shell");
}
const sctx = sitemap.getContext("2d");
const gctx = graph.getContext("2d");
if (!sctx || !gctx) {
  throw new Error("missing canvas context");
}

// One hue for the reachable->designed progression, lightness rising; locked stays neutral.
const STATE_COLORS = ["#2b313a", "#3f8a5a", "#6cd98e"];
const STATE_TEXT = ["#8a94a0", "#eaf7ef", "#0c1f14"];
const STATE_LABELS = ["locked", "reachable", "designed"];
const SURFACE = "#10141a";
const MUTED = "#8a94a0";
const HAIRLINE = "#222932";

const MARGIN = 28;
const TILE = 46;
const TGAP = 8;
const GNODE = 36;

type GraphHit = { cp: number; x: number; y: number; w: number; h: number };

main();

async function main(): Promise<void> {
  await init();
  const roadmap = new Roadmap();
  let graphHits: GraphHit[] = [];

  const zoomer = new DasherZoomer({
    canvas: canvas!,
    onCommit: (cp: number) => commit(cp),
    k: K,
  });

  // Coalesce sitemap/graph redraw, list rebuild, and summary into one rAF tick.
  let refreshScheduled = false;
  const scheduleRefresh = (): void => {
    if (refreshScheduled) return;
    refreshScheduled = true;
    requestAnimationFrame(() => {
      refreshScheduled = false;
      refresh();
    });
  };

  const refresh = (): void => {
    const entries = roadmap.frontier() as FrontierEntry[];
    const coverage = roadmap.coverage();
    summary!.textContent = `coverage ${(coverage * 100).toFixed(0)}% · ${entries.length} candidates`;
    drawSitemap(roadmap.target_states() as TargetState[]);
    graphHits = drawGraph(roadmap.target_graph() as Graph);
  };

  // Rebuild the zoomer: each candidate's next-next preview is the core's unlocks() list, capped.
  const reseedZoomer = (acceptedCp?: number): void => {
    const frontier = roadmap.frontier() as FrontierEntry[];
    const deps = new Map<number, number[]>();
    for (const e of frontier) {
      deps.set(e.cp, (roadmap.unlocks(e.cp) as number[]).slice(0, NEXTNEXT_MAX));
    }
    zoomer.reseed(frontier, deps, acceptedCp);
  };

  const commit = (cp: number): void => {
    const states = roadmap.target_states() as TargetState[];
    if (states.some((s) => s.cp === cp && s.state === 2)) return;
    roadmap.make(cp);
    zoomer.historyPush(cp);
    reseedZoomer(cp);
    scheduleRefresh();
  };

  const at = (cv: HTMLCanvasElement, e: MouseEvent): [number, number] => {
    const r = cv.getBoundingClientRect();
    return [((e.clientX - r.left) / r.width) * cv.width, ((e.clientY - r.top) / r.height) * cv.height];
  };

  const designAt = (cv: HTMLCanvasElement, hits: GraphHit[]) =>
    (e: MouseEvent) => {
      const [px, py] = at(cv, e);
      const hit = hits.find((h) => px >= h.x && px <= h.x + h.w && py >= h.y && py <= h.y + h.h);
      if (hit) commit(hit.cp);
    };

  graph!.addEventListener("click", (e) => designAt(graph!, graphHits)(e));

  reseedZoomer();
  refresh();
}

function clearBg(c: CanvasRenderingContext2D, cv: HTMLCanvasElement): void {
  c.clearRect(0, 0, cv.width, cv.height);
  c.fillStyle = SURFACE;
  c.fillRect(0, 0, cv.width, cv.height);
}

// Legend row of state swatches; `y` is the text center, swatch sits 7px above it.
function drawLegend(c: CanvasRenderingContext2D, y: number): void {
  c.textBaseline = "middle";
  c.font = "14px system-ui, sans-serif";
  STATE_LABELS.forEach((label, s) => {
    const x = MARGIN + s * 120;
    c.fillStyle = STATE_COLORS[s];
    c.fillRect(x, y - 7, 14, 14);
    c.fillStyle = MUTED;
    c.fillText(label, x + 20, y);
  });
}

// State-colored square with the glyph centered; dark text on the light "locked" tile.
function drawStateTile(
  c: CanvasRenderingContext2D,
  x: number,
  y: number,
  size: number,
  cp: number,
  state: number,
  font: string,
): void {
  c.fillStyle = STATE_COLORS[state] ?? STATE_COLORS[0];
  c.beginPath();
  c.roundRect(x, y, size, size, Math.max(3, size * 0.16));
  c.fill();
  c.fillStyle = STATE_TEXT[state] ?? STATE_TEXT[0];
  c.font = font;
  c.textAlign = "center";
  c.textBaseline = "middle";
  c.fillText(String.fromCodePoint(cp), x + size / 2, y + size / 2);
  c.textAlign = "left";
}

function drawSitemap(states: TargetState[]): void {
  clearBg(sctx!, sitemap!);
  drawLegend(sctx!, MARGIN + 7);

  const top = MARGIN + 28;
  const cols = Math.max(1, Math.floor((sitemap!.width - MARGIN * 2 + TGAP) / (TILE + TGAP)));
  states.forEach((s, i) => {
    const x = MARGIN + (i % cols) * (TILE + TGAP);
    const y = top + Math.floor(i / cols) * (TILE + TGAP);
    drawStateTile(sctx!, x, y, TILE, s.cp, s.state, "27px system-ui, sans-serif");
  });
}

// Lay nodes by layer (bottom = layer 0, top = max), spread evenly per layer; edges go upward
// from a component to each parent that names it; node color by state, with a legend.
function drawGraph(g: Graph): GraphHit[] {
  clearBg(gctx!, graph!);
  drawLegend(gctx!, MARGIN);

  const top = MARGIN + 22;
  const maxLayer = Math.max(0, ...g.nodes.map((n) => n.layer));
  const bandH = (graph!.height - top - MARGIN) / (maxLayer + 1);
  const yOf = (layer: number) => top + (maxLayer - layer) * bandH + bandH / 2;

  const byLayer = new Map<number, GraphNode[]>();
  g.nodes.forEach((n) => {
    if (!byLayer.has(n.layer)) byLayer.set(n.layer, []);
    byLayer.get(n.layer)!.push(n);
  });

  const pos = new Map<number, { x: number; y: number }>();
  byLayer.forEach((nodes, layer) => {
    // Sort by codepoint so positions are stable across redraws (the core's node order is not).
    nodes.sort((a, b) => a.cp - b.cp);
    const step = (graph!.width - MARGIN * 2) / (nodes.length + 1);
    nodes.forEach((n, i) => pos.set(n.cp, { x: MARGIN + step * (i + 1), y: yOf(layer) }));
  });

  gctx!.strokeStyle = HAIRLINE;
  gctx!.lineWidth = 1;
  g.edges.forEach((e) => {
    const a = pos.get(e.from_cp);
    const b = pos.get(e.to_cp);
    if (!a || !b) return;
    gctx!.beginPath();
    gctx!.moveTo(a.x, a.y);
    gctx!.lineTo(b.x, b.y);
    gctx!.stroke();
  });

  const hits: GraphHit[] = [];
  g.nodes.forEach((n) => {
    const p = pos.get(n.cp);
    if (!p) return;
    const x = p.x - GNODE / 2;
    const y = p.y - GNODE / 2;
    drawStateTile(gctx!, x, y, GNODE, n.cp, n.state, "21px system-ui, sans-serif");
    hits.push({ cp: n.cp, x, y, w: GNODE, h: GNODE });
  });
  return hits;
}
