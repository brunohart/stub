// Prototype of Stub's editions. Mirrors Stub/Edition/*.swift: same dice, same marks, same coordinates, same parts
// (Genome version 2, ADR-016). Every change to a movement lands here and in the Swift in the same commit.
const MASK = (1n << 64n) - 1n;
function fnv(s) { let h = 0xcbf29ce484222325n; for (const b of new TextEncoder().encode(s)) { h ^= BigInt(b); h = (h * 0x100000001b3n) & MASK; } return h; }
class Dice {
  constructor(seed) { this.seed = seed; this.state = seed; }
  next() { this.state = (this.state + 0x9E3779B97F4A7C15n) & MASK; let z = this.state; z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & MASK; z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & MASK; return z ^ (z >> 31n); }
  unit() { return Number(this.next() >> 11n) / 2 ** 53; }
  between(a, b) { return a + (b - a) * this.unit(); }
  index(n) { return Number(this.next() % BigInt(n)); }
  pick(xs) { return xs[this.index(xs.length)]; }
  chance(p) { return this.unit() < p; }
  sign() { return this.chance(0.5) ? -1 : 1; }
  fork(l) { return new Dice(this.seed ^ fnv(l)); }
}
// As Release.key: formats stripped (up to three), diacritics and case folded, "&" read as "and", anything that is
// not a letter or a digit in any script a space.
const FORMATS = /\s*\(?\b(2D|3D|IMAX|4DX|ATMOS|DOLBY|VMAX|GOLD CLASS|OC|CC|M|PG|R13|R16|R18|G)\b\)?\s*$/i;
function releaseKey(t) {
  let bare = t.trim();
  for (let i = 0; i < 3; i++) { const s = bare.replace(FORMATS, '').trim(); if (s === bare) break; bare = s; }
  return bare.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replace(/&/g, ' and ')
    .replace(/[^\p{L}\p{N}]/gu, ' ').split(/\s+/).filter(Boolean).join(' ');
}
const MOVEMENTS = ['swiss', 'constructivist', 'deco', 'cutout', 'riso', 'letterpress', 'blueprint', 'noir'];
const PALETTES = ['sand', 'night', 'ember', 'tide', 'moss', 'chalk', 'bruise', 'oxide', 'cobalt', 'citrus', 'blush', 'smoke'];
const STOCKS = ['cotton', 'coated', 'foil', 'holographic'];
const INKS = {
  sand: [0xEDE0C4, 0xB5451B, 0xD99A2B, 0x2A1D14, 0xC9A45C], night: [0x15171D, 0x3C5DA8, 0xC9B98F, 0xEDE6D6, 0xB9BEC6],
  ember: [0x1D1512, 0xC4391D, 0xE9A23B, 0xF3E7D3, 0xC08457], tide: [0xE3ECEA, 0x1F5E73, 0xE07A5F, 0x0F2A33, 0xB9BEC6],
  moss: [0xE5E3D1, 0x4F6B3A, 0xB89B5E, 0x1F2A1A, 0xC9A45C], chalk: [0xF4F1EA, 0x1A1A1A, 0xD4622B, 0x1A1A1A, 0xB9BEC6],
  bruise: [0xE8E0E9, 0x5B2A6E, 0xD9577A, 0x24122B, 0xB9BEC6], oxide: [0xDAD2C2, 0x7A2E1F, 0x3E4F5C, 0x1E1B18, 0xC08457],
  cobalt: [0x0F2B5C, 0xE9EEF5, 0xF2C14E, 0xF4F1EA, 0xB9BEC6], citrus: [0xF6EFD9, 0xEFA92F, 0x2F7F6F, 0x22302B, 0xC9A45C],
  blush: [0xF3E3DA, 0xE2725B, 0x2F3E75, 0x2A1F2E, 0xC9A45C], smoke: [0xD8D8D3, 0x2B2B2B, 0x9E1B1B, 0x121212, 0xB9BEC6],
};
function lum(h) { const c = [(h >> 16) & 255, (h >> 8) & 255, h & 255].map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }); return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]; }
function contrast(a, b) { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
function hex(h) { return '#' + h.toString(16).padStart(6, '0'); }

const W = 330, H = 528, PH = 408, PAD = 22;
function floorEdition(title) { const k = releaseKey(title), seed = fnv(k); const d = new Dice(seed).fork('genome'); return { release: k, seed, movement: d.pick(MOVEMENTS), palette: d.pick(PALETTES), stock: d.pick(STOCKS) }; }

// Palette roles. `light`/`dark` are the lighter and darker of ground and ink.
function palette(name) {
  const [ground, primary, secondary, ink, metal] = INKS[name];
  const groundIsLight = lum(ground) > lum(ink);
  return { ground, primary, secondary, ink, metal, light: groundIsLight ? ground : ink, dark: groundIsLight ? ink : ground, groundIsLight };
}

// Face widths per character, as a fraction of the size. Estimates; the renderer measures and shrinks to fit.
const CW = { grotesk300: 0.56, grotesk500: 0.55, grotesk700: 0.58, grotesk800: 0.62, serif: 0.47, serifItalic: 0.43, mono: 0.6 };
function balanced(words, n) {
  // Break `words` into n lines minimising the longest line (characters). Brute force; titles are short.
  if (n <= 1 || words.length <= 1) return [words.join(' ')];
  n = Math.min(n, words.length);
  let best = null;
  const rec = (start, left, acc) => {
    if (left === 1) { const line = words.slice(start).join(' '); const all = [...acc, line]; const m = Math.max(...all.map(l => l.length)); if (!best || m < best.m) best = { m, lines: all }; return; }
    for (let i = start + 1; i <= words.length - left + 1; i++) rec(i, left - 1, [...acc, words.slice(start, i).join(' ')]);
  };
  rec(0, n, []);
  return best.lines;
}
// Measured, like Swift's `Measure.width` (CoreText there, a canvas here).
const FACE_CSS = { grotesk300: '300 100px "Host Grotesk"', grotesk500: '500 100px "Host Grotesk"', grotesk700: '700 100px "Host Grotesk"', grotesk800: '800 100px "Host Grotesk"', serif: '400 100px Newsreader', serifItalic: 'italic 400 100px Newsreader', mono: '400 100px "Fragment Mono"' };
// Under Node (the goldens, `node docs/editions/golden.js`) there is no canvas; titles are then estimated from `CW`,
// so only marks that set no type are pinned from there.
const ctx2d = typeof document === 'undefined' ? null : document.createElement('canvas').getContext('2d');
function measure(text, face, size, track = 0) {
  if (!ctx2d) return CW[face] * text.length * size + track * size * text.length;
  ctx2d.font = FACE_CSS[face]; return ctx2d.measureText(text).width * size / 100 + track * size * text.length;
}
// The largest setting of `text` in a box: tries 1…maxLines lines, keeps the one with the biggest size.
function setTitle(text, { width, height, maxSize, face, lead = 0.95, maxLines = 4, upper = false, lower = false, track = 0 }) {
  let t = upper ? text.toUpperCase() : lower ? text.toLowerCase() : text;
  const words = t.split(/\s+/).filter(Boolean);
  let best = null;
  for (let n = 1; n <= Math.min(maxLines, words.length); n++) {
    const lines = balanced(words, n);
    const widest = Math.max(...lines.map(l => measure(l, face, 1, track)));
    const size = Math.min(maxSize, width / widest, height / (n * lead));
    if (!best || size > best.size + 0.5) best = { lines, size };
  }
  return best;
}

// ---- Marks ----------------------------------------------------------------------------------------------
// {k:'rect'|'circle'|'ring'|'poly'|'line'|'text'|'halftone', ink:role, op, plate:1|2|3, foil:bool, rot:{deg,cx,cy}, blend}
function title(lines, size, { x, y, face, color = 'ink', anchor = 'start', lead = 0.95, track = 0, plate = 3, foil = false, rot, op = 1, maxW, blend, baseline = 'last' }) {
  // y is the baseline of the last line (baseline 'last') or of the first ('first').
  const out = [];
  const step = size * lead;
  const first = baseline === 'last' ? y - step * (lines.length - 1) : y;
  lines.forEach((l, i) => out.push({ k: 'text', text: l, x, y: first + i * step, size, face, ink: color, anchor, track, plate, foil, rot, op, maxW, blend }));
  return out;
}
function on(c, role) { return contrast(c.pal[role], c.pal.ground) >= contrast(c.pal[role], c.pal.ink) ? 'ground' : 'ink'; }
function strong(c, role) { return contrast(c.pal[role], c.pal.ground) >= 3 ? role : 'ink'; }
function torn(d, x0, y0, x1, y1, width, jag) {
  // A strip torn along both long edges, from (x0,y0) to (x1,y1).
  const n = 12, pts = [], back = [];
  const dx = x1 - x0, dy = y1 - y0, len = Math.hypot(dx, dy), nx = -dy / len, ny = dx / len;
  for (let i = 0; i <= n; i++) {
    const t = i / n, px = x0 + dx * t, py = y0 + dy * t;
    pts.push([px + nx * (width / 2 + d.between(-jag, jag)), py + ny * (width / 2 + d.between(-jag, jag))]);
    back.push([px - nx * (width / 2 + d.between(-jag, jag)), py - ny * (width / 2 + d.between(-jag, jag))]);
  }
  return pts.concat(back.reverse());
}
function blob(d, cx, cy, r, n, jag) { const pts = []; const a0 = d.between(0, Math.PI * 2); for (let i = 0; i < n; i++) { const a = a0 + i / n * Math.PI * 2; const rr = r * d.between(1 - jag, 1 + jag); pts.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]); } return pts; }

// ---- Parts (ADR-016) ----------------------------------------------------------------------------------------
// As Stub/Edition/Movements/*.swift: each movement's parts in the order they are drawn, [id, name, kind, hangs].
// A frame reads only its own die; a piece its own and, when it hangs, the frame's outputs; a set part rolls nothing.
const PARTS = {
  swiss: [['swiss/grid', 'the grid', 'frame', false], ['swiss/columns', 'the columns', 'set', true], ['swiss/title', 'the title', 'set', true]],
  constructivist: [['constructivist/diagonal', 'the diagonal', 'frame', false], ['constructivist/disc', 'the disc', 'piece', true], ['constructivist/bars', 'the bars', 'piece', true], ['constructivist/title', 'the title', 'set', true], ['constructivist/year', 'the year', 'set', true]],
  deco: [['deco/sunburst', 'the sunburst', 'frame', false], ['deco/sun', 'the sun', 'piece', true], ['deco/border', 'the border', 'set', false], ['deco/title', 'the title', 'set', false], ['deco/year', 'the year', 'set', true]],
  cutout: [['cutout/field', 'the field', 'set', false], ['cutout/strip', 'the torn strip', 'piece', false], ['cutout/block', 'the block', 'piece', false], ['cutout/scrap', 'the scrap', 'piece', false], ['cutout/label', 'the label', 'piece', false]],
  riso: [['riso/screen', 'the screen', 'piece', false], ['riso/disc', 'the disc', 'piece', false], ['riso/register', 'the register', 'piece', false], ['riso/title', 'the title', 'set', false]],
  letterpress: [['letterpress/rules', 'the rules', 'set', false], ['letterpress/ornament', 'the ornament', 'piece', false], ['letterpress/title', 'the title', 'set', false], ['letterpress/year', 'the year', 'set', false]],
  blueprint: [['blueprint/grid', 'the grid', 'set', false], ['blueprint/circle', 'the circle', 'frame', false], ['blueprint/radius', 'the radius', 'piece', true], ['blueprint/dimension', 'the dimension', 'set', true], ['blueprint/block', 'the title block', 'set', false]],
  noir: [['noir/night', 'the night', 'set', false], ['noir/blind', 'the blind', 'piece', false], ['noir/title', 'the title', 'set', false], ['noir/time', 'the time', 'set', false]],
};
// A poster's marks, part by part: every mark added while `part` is set carries it (Swift's `Sheet`).
function sheet() { const marks = []; const s = { part: null, marks, add(mk) { marks.push({ ...mk, part: s.part }); }, addAll(mks) { mks.forEach(mk => s.add(mk)); } }; return s; }

const MOVES = {
  swiss(c) {
    const m = sheet();
    m.part = 'swiss/grid';
    const d = c.dice('swiss/grid'), variant = d.index(3);
    let infoY;
    if (variant === 0) { const h = d.between(176, 230); m.add({ k: 'rect', x: PAD, y: 0, w: d.between(22, 38), h, ink: 'primary', plate: 1, foil: true }); infoY = h + 26; }
    else if (variant === 1) { const r = d.between(100, 140), cy = d.between(34, 84); m.add({ k: 'circle', cx: W - d.between(24, 70), cy, r, ink: 'primary', plate: 1, foil: true }); infoY = cy + r + 26; }
    else { const h = d.between(132, 172); m.add({ k: 'rect', x: 0, y: 0, w: W, h, ink: 'primary', plate: 1, foil: true }); infoY = h + 26; }
    infoY = Math.min(infoY, 238);
    // The grid: a hairline, then three columns of what the night was.
    m.part = 'swiss/columns';
    m.add({ k: 'line', x1: PAD, y1: infoY - 14, x2: W - PAD, y2: infoY - 14, w: 0.75, ink: 'ink', plate: 2 });
    const cols = [c.copy.year ? String(c.copy.year) : null, c.copy.time, c.copy.seat].filter(Boolean);
    cols.forEach((t, i) => m.add({ k: 'text', text: t, x: PAD + i * ((W - 2 * PAD) / 3), y: infoY, size: 11, face: 'mono', ink: 'ink', plate: 3 }));
    const sq = 11;
    m.add({ k: 'rect', x: W - PAD - sq, y: infoY - 9, w: sq, h: sq, ink: 'secondary', plate: 2 });
    m.part = 'swiss/title';
    const t = setTitle(c.copy.title, { width: W - 2 * PAD, height: PH - infoY - 50, maxSize: 88, face: 'grotesk700', lead: 0.9, lower: true, maxLines: 4 });
    m.addAll(title(t.lines, t.size, { x: PAD - 2, y: PH - 26, face: 'grotesk700', lead: 0.9, track: -0.045, maxW: W - 2 * PAD }));
    return m.marks;
  },
  constructivist(c) {
    const m = sheet();
    m.part = 'constructivist/diagonal';
    const d = c.dice('constructivist/diagonal');
    const s = d.sign(), angle = -s * d.between(20, 30), bandW = d.between(80, 104);
    const cx = W / 2, cy = PH * 0.5 + d.between(-24, 24);
    const rot = { deg: angle, cx, cy };
    m.add({ k: 'rect', x: cx - 420, y: cy - bandW / 2, w: 840, h: bandW, ink: 'primary', plate: 1, rot });
    m.part = 'constructivist/disc';
    const disc = c.dice('constructivist/disc');
    const r = disc.between(56, 84);
    m.add({ k: 'circle', cx: s > 0 ? W * 0.3 : W * 0.7, cy: PH * 0.2 + disc.between(-10, 20), r, ink: 'secondary', plate: 2, foil: true });
    m.part = 'constructivist/bars';
    const bars = c.dice('constructivist/bars');
    const x1 = cx - 150 + bars.between(-40, 40), w1 = bars.between(200, 280);
    m.add({ k: 'rect', x: x1, y: cy + bandW / 2 + 16, w: w1, h: 7, ink: 'ink', plate: 2, rot });
    const x2 = cx - 120 + bars.between(-40, 40), w2 = bars.between(90, 150);
    m.add({ k: 'rect', x: x2, y: cy + bandW / 2 + 30, w: w2, h: 3, ink: 'ink', plate: 2, rot });
    const x3 = s > 0 ? cx + bars.between(10, 60) : cx - bars.between(110, 170), w3 = bars.between(60, 100);
    m.add({ k: 'rect', x: x3, y: cy - bandW / 2 - 22, w: w3, h: 12, ink: 'ink', plate: 2, rot });
    m.part = 'constructivist/title';
    const t = setTitle(c.copy.title, { width: 300, height: bandW * 0.82, maxSize: bandW * 0.66, face: 'grotesk800', lead: 0.88, upper: true, maxLines: 2 });
    const block = t.size * 0.88 * (t.lines.length - 1);
    m.addAll(title(t.lines, t.size, { x: cx, y: cy + t.size * 0.35 - block / 2, face: 'grotesk800', color: on(c, 'primary'), anchor: 'middle', lead: 0.88, track: -0.02, rot, baseline: 'first', maxW: 300 }));
    m.part = 'constructivist/year';
    if (c.copy.year) m.add({ k: 'text', text: String(c.copy.year), x: s > 0 ? W - PAD : PAD, y: PH - 24, size: 34, face: 'mono', ink: 'ink', plate: 3, anchor: s > 0 ? 'end' : 'start' });
    return m.marks;
  },
  deco(c) {
    const m = sheet(), cx = W / 2;
    m.part = 'deco/sunburst';
    const d = c.dice('deco/sunburst');
    const cy = PH * d.pick([0.66, 0.72]), n = d.pick([24, 28, 32, 36]);
    for (let i = 0; i < n; i += 2) {
      const a0 = i / n * Math.PI * 2, a1 = (i + 1) / n * Math.PI * 2, R = 700;
      m.add({ k: 'poly', pts: [[cx, cy], [cx + Math.cos(a0) * R, cy + Math.sin(a0) * R], [cx + Math.cos(a1) * R, cy + Math.sin(a1) * R]], ink: 'primary', op: 0.2, plate: 1 });
    }
    for (let i = 1; i < n; i += 2) {
      const a = i / n * Math.PI * 2;
      m.add({ k: 'line', x1: cx + Math.cos(a) * 58, y1: cy + Math.sin(a) * 58, x2: cx + Math.cos(a) * 700, y2: cy + Math.sin(a) * 700, w: 1, ink: 'primary', op: 0.55, plate: 1, foil: true });
    }
    m.part = 'deco/sun';
    const sun = c.dice('deco/sun').between(40, 52);
    m.add({ k: 'circle', cx, cy, r: sun, ink: 'ground', plate: 1 });
    m.add({ k: 'ring', cx, cy, r: sun, w: 2, ink: 'primary', plate: 1, foil: true });
    m.add({ k: 'ring', cx, cy, r: sun - 6, w: 0.75, ink: 'primary', plate: 1, foil: true });
    // Stepped frame.
    m.part = 'deco/border';
    const f = (i, step) => [[i + step, i], [W - i - step, i], [W - i - step, i + step], [W - i, i + step], [W - i, PH - i - step], [W - i - step, PH - i - step], [W - i - step, PH - i], [i + step, PH - i], [i + step, PH - i - step], [i, PH - i - step], [i, i + step], [i + step, i + step]];
    m.add({ k: 'poly', pts: f(12, 10), stroke: 1.5, ink: 'primary', plate: 1, foil: true });
    m.add({ k: 'poly', pts: f(18, 10), stroke: 0.75, ink: 'primary', plate: 1, foil: true });
    // Title plaque: ground behind the title so it reads over the rays.
    m.part = 'deco/title';
    const t = setTitle(c.copy.title, { width: W - 90, height: 120, maxSize: 40, face: 'grotesk300', lead: 1.08, upper: true, maxLines: 3, track: 0.16 });
    const lines = t.lines.length, block = t.size * 1.08 * lines;
    const ty = 60;
    m.add({ k: 'rect', x: 34, y: ty - 16, w: W - 68, h: block + 30, ink: 'ground', plate: 1 });
    m.add({ k: 'line', x1: 44, y1: ty - 8, x2: W - 44, y2: ty - 8, w: 0.75, ink: 'primary', plate: 1, foil: true });
    m.add({ k: 'line', x1: 44, y1: ty + block + 6, x2: W - 44, y2: ty + block + 6, w: 0.75, ink: 'primary', plate: 1, foil: true });
    m.addAll(title(t.lines, t.size, { x: cx, y: ty + t.size * 0.86, face: 'grotesk300', color: 'ink', anchor: 'middle', lead: 1.08, track: 0.16, baseline: 'first', foil: true, maxW: W - 90 }));
    m.part = 'deco/year';
    if (c.copy.year) m.add({ k: 'text', text: String(c.copy.year), x: cx, y: cy + 4, size: 12, face: 'mono', ink: 'ink', plate: 3, anchor: 'middle' });
    return m.marks;
  },
  cutout(c) {
    const m = sheet();
    m.part = 'cutout/field';
    m.add({ k: 'rect', x: 0, y: 0, w: W, h: PH, ink: 'primary', plate: 1 });
    m.part = 'cutout/strip';
    const strip = c.dice('cutout/strip');
    const x0 = strip.between(40, W - 60), x1 = x0 + strip.between(-70, 70), sw = strip.between(34, 58);
    m.add({ k: 'poly', pts: torn(strip, x0, -20, x1, PH + 20, sw, 4), ink: 'ink', plate: 2 });
    m.part = 'cutout/block';
    const d = c.dice('cutout/block');
    const bx = d.between(30, 140), by = d.between(40, 140);
    const corners = [[bx, by], [bx + d.between(120, 190), by + d.between(-20, 30)], [bx + d.between(90, 170), by + d.between(70, 120)], [bx + d.between(-10, 30), by + d.between(60, 110)]];
    m.add({ k: 'poly', pts: corners.map(([x, y]) => [x + d.between(-3, 3), y + d.between(-3, 3)]), ink: 'ink', plate: 2, foil: true });
    m.part = 'cutout/scrap';
    const sc = c.dice('cutout/scrap');
    const sx = sc.between(60, W - 60), sy = sc.between(180, 250), sr = sc.between(24, 40);
    m.add({ k: 'poly', pts: blob(sc, sx, sy, sr, 9, 0.18), ink: 'secondary', plate: 2 });
    m.part = 'cutout/label';
    const label = c.dice('cutout/label');
    const t = setTitle(c.copy.title, { width: W - 2 * PAD - 28, height: 120, maxSize: 44, face: 'grotesk700', lead: 0.95, lower: true, maxLines: 3 });
    const block = t.size * 0.95 * t.lines.length, ly = PH - 34 - block;
    const rot = { deg: label.between(-3, 3), cx: W / 2, cy: ly + block / 2 };
    m.add({ k: 'rect', x: PAD, y: ly - 12, w: W - 2 * PAD, h: block + 24, ink: 'ground', plate: 2, rot });
    m.addAll(title(t.lines, t.size, { x: PAD + 14, y: ly + t.size * 0.8, face: 'grotesk700', color: 'ink', lead: 0.95, track: -0.03, rot, baseline: 'first', maxW: W - 2 * PAD - 28 }));
    return m.marks;
  },
  riso(c) {
    const m = sheet(), blend = c.pal.groundIsLight ? 'multiply' : 'screen';
    m.part = 'riso/screen';
    const screen = c.dice('riso/screen');
    const fx = screen.between(60, W - 60), fy = screen.between(60, 200), R = screen.between(170, 230);
    m.add({ k: 'halftone', x: 0, y: 0, w: W, h: PH, step: 6.5, fx, fy, R, rmax: 3.4, ink: 'primary', plate: 1, blend });
    m.part = 'riso/disc';
    const disc = c.dice('riso/disc');
    const sx = disc.between(70, W - 70), sy = disc.between(110, 230), sr = disc.between(80, 120);
    m.add({ k: 'circle', cx: sx, cy: sy, r: sr, ink: 'secondary', op: 0.9, plate: 2, blend, foil: true });
    const t = setTitle(c.copy.title, { width: W - 2 * PAD, height: 170, maxSize: 72, face: 'grotesk700', lead: 0.92, maxLines: 4 });
    m.part = 'riso/register';
    const register = c.dice('riso/register');
    const off = [register.between(2.5, 4), register.between(1.5, 3)];
    m.addAll(title(t.lines, t.size, { x: PAD - 1 + off[0], y: PH - 28 + off[1], face: 'grotesk700', color: c.pal.groundIsLight ? 'secondary' : 'primary', op: c.pal.groundIsLight ? 1 : 0.85, lead: 0.92, track: -0.04, plate: 2, blend: c.pal.groundIsLight ? 'multiply' : null, maxW: W - 2 * PAD }));
    m.part = 'riso/title';
    m.addAll(title(t.lines, t.size, { x: PAD - 1, y: PH - 28, face: 'grotesk700', color: 'ink', lead: 0.92, track: -0.04, blend: c.pal.groundIsLight ? 'multiply' : null, maxW: W - 2 * PAD }));
    return m.marks;
  },
  letterpress(c) {
    const m = sheet(), cx = W / 2;
    m.part = 'letterpress/rules';
    m.add({ k: 'rect', x: 16, y: 16, w: W - 32, h: PH - 16, stroke: 2, ink: 'ink', plate: 1, foil: true });
    m.add({ k: 'rect', x: 21, y: 21, w: W - 42, h: PH - 26, stroke: 0.75, ink: 'ink', plate: 1 });
    m.part = 'letterpress/ornament';
    const oy = c.dice('letterpress/ornament').between(64, 80);
    m.add({ k: 'line', x1: cx - 44, y1: oy, x2: cx - 10, y2: oy, w: 0.75, ink: 'ink', plate: 1 });
    m.add({ k: 'line', x1: cx + 10, y1: oy, x2: cx + 44, y2: oy, w: 0.75, ink: 'ink', plate: 1 });
    m.add({ k: 'rect', x: cx - 3.5, y: oy - 3.5, w: 7, h: 7, ink: strong(c, 'primary'), plate: 2, foil: true, rot: { deg: 45, cx, cy: oy } });
    m.part = 'letterpress/title';
    const t = setTitle(c.copy.title, { width: W - 80, height: 170, maxSize: 48, face: 'serif', lead: 1.08, maxLines: 4 });
    const block = t.size * 1.08 * t.lines.length, top = PH * 0.46 - block / 2;
    m.addAll(title(t.lines, t.size, { x: cx, y: top + t.size * 0.82, face: 'serif', anchor: 'middle', lead: 1.08, baseline: 'first', maxW: W - 80 }));
    if (c.copy.cinema) m.add({ k: 'text', text: c.copy.cinema, x: cx, y: top + block + 24, size: 15, face: 'serifItalic', ink: 'ink', plate: 3, anchor: 'middle', maxW: W - 90 });
    m.add({ k: 'line', x1: cx - 16, y1: top + block + 44, x2: cx + 16, y2: top + block + 44, w: 0.75, ink: 'ink', plate: 1 });
    m.part = 'letterpress/year';
    if (c.copy.year) m.add({ k: 'text', text: String(c.copy.year), x: cx, y: PH - 40, size: 11, face: 'mono', ink: 'ink', plate: 3, anchor: 'middle' });
    return m.marks;
  },
  blueprint(c) {
    const m = sheet(), line = strong(c, 'primary');
    m.part = 'blueprint/grid';
    for (let x = 11, i = 1; x < W; x += 11, i++) m.add({ k: 'line', x1: x, y1: 0, x2: x, y2: PH, w: i % 5 === 0 ? 0.6 : 0.35, ink: line, op: i % 5 === 0 ? 0.3 : 0.14, plate: 1 });
    for (let y = 11, i = 1; y < PH; y += 11, i++) m.add({ k: 'line', x1: 0, y1: y, x2: W, y2: y, w: i % 5 === 0 ? 0.6 : 0.35, ink: line, op: i % 5 === 0 ? 0.3 : 0.14, plate: 1 });
    m.part = 'blueprint/circle';
    const d = c.dice('blueprint/circle');
    const r = d.between(84, 112), cx = W / 2 + d.between(-36, 36), cy = PH * 0.38 + d.between(-20, 16);
    m.add({ k: 'ring', cx, cy, r, w: 1.6, ink: line, plate: 2, foil: true });
    m.add({ k: 'ring', cx, cy, r: r * 0.62, w: 0.75, ink: line, plate: 2, dash: [4, 3] });
    m.add({ k: 'line', x1: cx - r - 16, y1: cy, x2: cx + r + 16, y2: cy, w: 0.75, ink: line, plate: 2, dash: [10, 3, 2, 3] });
    m.add({ k: 'line', x1: cx, y1: cy - r - 16, x2: cx, y2: cy + r + 16, w: 0.75, ink: line, plate: 2, dash: [10, 3, 2, 3] });
    m.part = 'blueprint/radius';
    const a = c.dice('blueprint/radius').between(-2.4, -0.7);
    m.add({ k: 'line', x1: cx, y1: cy, x2: cx + Math.cos(a) * r, y2: cy + Math.sin(a) * r, w: 1, ink: 'secondary', plate: 2 });
    m.add({ k: 'circle', cx: cx + Math.cos(a) * r, cy: cy + Math.sin(a) * r, r: 3, ink: 'secondary', plate: 2, foil: true });
    if (c.copy.seat) m.add({ k: 'text', text: 'SEAT ' + c.copy.seat, x: cx + Math.cos(a) * r + (Math.cos(a) > 0 ? 8 : -8), y: cy + Math.sin(a) * r - 6, size: 9.5, face: 'mono', ink: line, plate: 3, anchor: Math.cos(a) > 0 ? 'start' : 'end' });
    m.part = 'blueprint/dimension';
    const dy = cy + r + 26;
    m.add({ k: 'line', x1: cx - r, y1: dy, x2: cx + r, y2: dy, w: 0.75, ink: line, plate: 2 });
    for (const [x, s] of [[cx - r, 1], [cx + r, -1]]) {
      m.add({ k: 'line', x1: x, y1: dy - 8, x2: x, y2: dy + 4, w: 0.75, ink: line, plate: 2 });
      m.add({ k: 'line', x1: x, y1: dy, x2: x + 6 * s, y2: dy - 3, w: 0.75, ink: line, plate: 2 });
      m.add({ k: 'line', x1: x, y1: dy, x2: x + 6 * s, y2: dy + 3, w: 0.75, ink: line, plate: 2 });
    }
    const label = c.copy.time || (c.copy.year ? String(c.copy.year) : null);
    if (label) { m.add({ k: 'rect', x: cx - 22, y: dy - 7, w: 44, h: 14, ink: 'ground', plate: 2 }); m.add({ k: 'text', text: label, x: cx, y: dy + 3.5, size: 9.5, face: 'mono', ink: line, plate: 3, anchor: 'middle' }); }
    m.part = 'blueprint/block';
    const bx = PAD, by = PH - 92, bw = W - 2 * PAD, bh = 70;
    m.add({ k: 'rect', x: bx, y: by, w: bw, h: bh, ink: 'ground', plate: 2 });
    m.add({ k: 'rect', x: bx, y: by, w: bw, h: bh, stroke: 1, ink: line, plate: 2 });
    m.add({ k: 'line', x1: bx, y1: by + bh - 20, x2: bx + bw, y2: by + bh - 20, w: 0.75, ink: line, plate: 2 });
    m.add({ k: 'line', x1: bx + bw / 2, y1: by + bh - 20, x2: bx + bw / 2, y2: by + bh, w: 0.75, ink: line, plate: 2 });
    const t = setTitle(c.copy.title, { width: bw - 20, height: 40, maxSize: 22, face: 'mono', lead: 1.0, upper: true, maxLines: 2 });
    m.addAll(title(t.lines, t.size, { x: bx + 10, y: by + bh - 28, face: 'mono', color: 'ink', lead: 1.0, maxW: bw - 20 }));
    m.add({ k: 'text', text: `VIEWING ${c.copy.viewing} OF ${c.copy.viewings}`, x: bx + 8, y: by + bh - 6.5, size: 8.5, face: 'mono', ink: line, plate: 3 });
    if (c.copy.screen) m.add({ k: 'text', text: (/^\d+$/.test(c.copy.screen) ? 'SCREEN ' + c.copy.screen : c.copy.screen.toUpperCase()), x: bx + bw / 2 + 8, y: by + bh - 6.5, size: 8.5, face: 'mono', ink: line, plate: 3 });
    return m.marks;
  },
  noir(c) {
    const m = sheet();
    m.part = 'noir/night';
    m.add({ k: 'rect', x: 0, y: 0, w: W, h: PH, ink: 'dark', plate: 1 });
    m.part = 'noir/blind';
    const d = c.dice('noir/blind');
    const n = 7 + d.index(4), angle = -d.between(18, 30), thick = d.between(12, 16), gap = d.between(9, 13);
    const px = W * d.between(0.55, 0.85), py = -30;
    for (let i = 0; i < n; i++) m.add({ k: 'rect', x: px - 360, y: py + 40 + i * (thick + gap), w: 520, h: thick, ink: 'light', op: 0.16 * (1 - i / n * 0.75), plate: 1, rot: { deg: angle, cx: px, cy: py } });
    m.part = 'noir/title';
    const t = setTitle(c.copy.title, { width: W - 2 * PAD, height: 150, maxSize: 60, face: 'serifItalic', lead: 1.0, maxLines: 3 });
    m.addAll(title(t.lines, t.size, { x: PAD, y: PH - 30, face: 'serifItalic', color: 'light', lead: 1.0, foil: true, maxW: W - 2 * PAD }));
    m.part = 'noir/time';
    const top = PH - 30 - t.size * (t.lines.length - 1) - t.size * 0.9;
    const accent = contrast(c.pal.secondary, c.pal.dark) >= 3 ? 'secondary' : contrast(c.pal.primary, c.pal.dark) >= 3 ? 'primary' : 'light';
    m.add({ k: 'line', x1: PAD, y1: top - 14, x2: PAD + 28, y2: top - 14, w: 1, ink: accent, plate: 2 });
    if (c.copy.time) m.add({ k: 'text', text: c.copy.time, x: PAD + 36, y: top - 10.5, size: 11, face: 'mono', ink: accent, plate: 3 });
    return m.marks;
  },
};

function strip(c) {
  const m = [], mv = c.edition.movement, X = 20;
  const face = { letterpress: 'serif', noir: 'serifItalic', blueprint: 'mono', deco: 'grotesk300' }[mv] || 'grotesk500';
  const tsize = { letterpress: 16, noir: 16, blueprint: 11.5, deco: 12 }[mv] || 13.5;
  const ttext = mv === 'blueprint' || mv === 'deco' || mv === 'constructivist' ? c.copy.title.toUpperCase() : c.copy.title;
  m.push({ k: 'text', text: ttext, x: X, y: PH + 32, size: tsize, face, ink: 'text', plate: 3, maxW: c.copy.price ? 200 : 290, track: mv === 'deco' ? 0.12 : 0 });
  if (c.copy.price) m.push({ k: 'text', text: c.copy.price, x: W - X, y: PH + 32, size: 11, face: 'mono', ink: 'text', plate: 3, anchor: 'end' });
  if (c.copy.cinema) m.push({ k: 'text', text: c.copy.cinema, x: X, y: PH + 50, size: 11.5, face: 'grotesk500', ink: 'text', op: 0.62, plate: 3, maxW: 290 });
  if (c.copy.when) m.push({ k: 'text', text: c.copy.when, x: X, y: PH + 82, size: 11, face: 'mono', ink: 'text', plate: 3 });
  if (c.copy.place) m.push({ k: 'text', text: c.copy.place, x: X, y: PH + 99, size: 11, face: 'mono', ink: 'text', plate: 3 });
  m.push({ k: 'text', text: c.copy.viewingWords, x: W - X, y: PH + 99, size: 13, face: 'serifItalic', ink: 'accent', plate: 3, anchor: 'end' });
  return m;
}

// As Edition.dice(_:take:): take 0 is the part's own die, forked from the seed by its id; take n forks that again.
function partDice(seed, id, take = 0) { const own = new Dice(seed).fork(id); return take === 0 ? own : own.fork('take ' + take); }

function compose(edition, copy) {
  const pal = palette(edition.palette);
  const takes = edition.takes || {};
  const c = { edition, pal, copy, dice: id => partDice(edition.seed, id, takes[id] || 0) };
  const poster = MOVES[edition.movement](c);
  const stripField = edition.movement === 'cutout' ? 'ground' : edition.movement === 'noir' ? 'dark' : 'ground';
  const textOnStrip = stripField === 'dark' ? 'light' : 'ink';
  const accent = contrast(pal.primary, pal[stripField]) >= 3 ? 'primary' : contrast(pal.secondary, pal[stripField]) >= 3 ? 'secondary' : textOnStrip;
  const s = strip(c).map(mk => ({ ...mk, ink: mk.ink === 'text' ? textOnStrip : mk.ink === 'accent' ? accent : mk.ink }));
  return { c, pal, poster, strip: s, stripField, posterField: edition.movement === 'noir' ? 'dark' : 'ground' };
}

// ---- SVG ---------------------------------------------------------------------------------------------------
const FONT = { grotesk300: ['Host Grotesk', 300, 'normal'], grotesk500: ['Host Grotesk', 500, 'normal'], grotesk700: ['Host Grotesk', 700, 'normal'], grotesk800: ['Host Grotesk', 800, 'normal'], serif: ['Newsreader', 400, 'normal'], serifItalic: ['Newsreader', 400, 'italic'], mono: ['Fragment Mono', 400, 'normal'] };
let uid = 0;
function render(edition, copy, { tilt = [0.3, -0.25], printed = 9 } = {}) {
  const id = 'e' + (uid++);
  const { pal, poster, strip: st, stripField, posterField } = compose(edition, copy);
  const metallic = edition.stock === 'foil' || edition.stock === 'holographic';
  const NS = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(NS, 'svg'); svg.setAttribute('viewBox', `0 0 ${W} ${H}`); svg.setAttribute('width', W); svg.setAttribute('height', H);
  const metal = pal.metal;
  const mix = (a, b, t) => { const ch = s => [(s >> 16) & 255, (s >> 8) & 255, s & 255]; const A = ch(a), B = ch(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, '0')).join(''); };
  // Foil must read against its ground: on light card it is pulled toward the ink, on dark card toward white.
  const base = pal.groundIsLight ? parseInt(mix(metal, pal.ink, 0.38).slice(1), 16) : metal;
  const holo = [0x9fb4d8, 0xd29ac8, 0xe0c98a, 0x8fd1b8, 0xa3a9e6, 0xe29fae].map(h => pal.groundIsLight ? parseInt(mix(h, pal.ink, 0.42).slice(1), 16) : h);
  const foilStops = edition.stock === 'holographic'
    ? holo.map((h, i) => mix(h, i % 2 ? 0xffffff : base, 0.25))
    : [mix(base, 0x000000, 0.35), mix(base, 0xffffff, 0.6), mix(base, 0x000000, 0.15), mix(base, 0xffffff, 0.3), mix(base, 0x000000, 0.4)];
  const ang = 35 + tilt[0] * 40;
  svg.innerHTML = `<defs>
    <linearGradient id="${id}f" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="${W}" y2="${H}" gradientTransform="rotate(${tilt[1] * 30} ${W / 2} ${H / 2})">${foilStops.map((s, i) => `<stop offset="${(i / (foilStops.length - 1) + tilt[0] * 0.3).toFixed(3)}" stop-color="${s}"/>`).join('')}</linearGradient>
    <linearGradient id="${id}g" x1="0" y1="0" x2="1" y2="1"><stop offset="${0.2 + tilt[0] * 0.3}" stop-color="#fff" stop-opacity="0"/><stop offset="${0.45 + tilt[0] * 0.3}" stop-color="#fff" stop-opacity="${edition.stock === 'cotton' ? 0.05 : 0.16}"/><stop offset="${0.7 + tilt[0] * 0.3}" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <clipPath id="${id}p"><rect x="0" y="0" width="${W}" height="${PH}"/></clipPath>
    <mask id="${id}m"><rect x="0" y="0" width="${W}" height="${H}" rx="10" fill="#fff"/>
      <circle cx="0" cy="${PH}" r="8" fill="#000"/><circle cx="${W}" cy="${PH}" r="8" fill="#000"/>
      ${Array.from({ length: 40 }, (_, i) => 16 + i * 7.5).filter(x => x < W - 14).map(x => `<circle cx="${x}" cy="${PH}" r="1.7" fill="#000"/>`).join('')}
    </mask>
    <filter id="${id}r" x="-5%" y="-5%" width="110%" height="110%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="${edition.stock === 'cotton' ? 0.9 : 0.5}" result="b"/>
      <feSpecularLighting in="b" surfaceScale="${edition.stock === 'cotton' ? -2.2 : -1.2}" specularConstant="0.6" specularExponent="18" lighting-color="#fff" result="s"><feDistantLight azimuth="${225 + tilt[0] * 60}" elevation="${48 + tilt[1] * 20}"/></feSpecularLighting>
      <feComposite in="s" in2="SourceAlpha" operator="in" result="sh"/>
      <feMerge><feMergeNode in="SourceGraphic"/><feMergeNode in="sh"/></feMerge>
    </filter>
  </defs>`;
  const card = document.createElementNS(NS, 'g'); card.setAttribute('mask', `url(#${id}m)`); svg.appendChild(card);
  const add = (parent, tag, attrs) => { const e = document.createElementNS(NS, tag); for (const [k, v] of Object.entries(attrs)) if (v !== undefined && v !== null) e.setAttribute(k, v); parent.appendChild(e); return e; };
  add(card, 'rect', { x: 0, y: 0, width: W, height: PH, fill: hex(pal[posterField]) });
  add(card, 'rect', { x: 0, y: PH, width: W, height: H - PH, fill: hex(pal[stripField]) });
  const posterG = add(card, 'g', { 'clip-path': `url(#${id}p)` });
  const inks = add(posterG, 'g', {});
  const foil = add(posterG, 'g', {});
  const type = add(posterG, 'g', {});   // over the foil, as EditionFace lays it
  const stripG = add(card, 'g', {});
  const draw = (mk, into) => {
    const toFoil = mk.foil && metallic;
    if (mk.plate > printed) return;
    const parent = toFoil ? foil : into;
    const fill = toFoil ? `url(#${id}f)` : hex(pal[mk.ink]);
    const common = { opacity: mk.op ?? 1, transform: mk.rot ? `rotate(${mk.rot.deg} ${mk.rot.cx} ${mk.rot.cy})` : null, style: mk.blend ? `mix-blend-mode:${mk.blend}` : null };
    if (mk.k === 'rect') return add(parent, 'rect', { x: mk.x, y: mk.y, width: mk.w, height: mk.h, ...(mk.stroke ? { fill: 'none', stroke: fill, 'stroke-width': mk.stroke } : { fill }), ...common });
    if (mk.k === 'circle') return add(parent, 'circle', { cx: mk.cx, cy: mk.cy, r: mk.r, fill, ...common });
    if (mk.k === 'ring') return add(parent, 'circle', { cx: mk.cx, cy: mk.cy, r: mk.r, fill: 'none', stroke: fill, 'stroke-width': mk.w, 'stroke-dasharray': mk.dash?.join(' '), ...common });
    if (mk.k === 'poly') return add(parent, 'polygon', { points: mk.pts.map(p => p.join(',')).join(' '), ...(mk.stroke ? { fill: 'none', stroke: fill, 'stroke-width': mk.stroke } : { fill }), ...common });
    if (mk.k === 'line') return add(parent, 'line', { x1: mk.x1, y1: mk.y1, x2: mk.x2, y2: mk.y2, stroke: fill, 'stroke-width': mk.w, 'stroke-dasharray': mk.dash?.join(' '), ...common });
    if (mk.k === 'halftone') {
      const g = add(parent, 'g', common);
      for (let y = mk.y + mk.step / 2; y < mk.y + mk.h; y += mk.step) for (let x = mk.x + mk.step / 2 + ((Math.round(y / mk.step) % 2) * mk.step / 2); x < mk.x + mk.w; x += mk.step) {
        const t = 1 - Math.hypot(x - mk.fx, y - mk.fy) / mk.R; if (t <= 0.04) continue; add(g, 'circle', { cx: x, cy: y, r: mk.rmax * Math.sqrt(t), fill });
      }
      return g;
    }
    if (mk.k === 'text') {
      const [fam, wt, st] = FONT[mk.face];
      const e = add(parent, 'text', { x: mk.x, y: mk.y, 'font-family': fam, 'font-weight': wt, 'font-style': st, 'font-size': mk.size, 'letter-spacing': (mk.track || 0) * mk.size, 'text-anchor': mk.anchor || 'start', fill, ...common });
      e.textContent = mk.text;
      if (mk.maxW) { const len = e.getComputedTextLength(); if (len > mk.maxW) e.setAttribute('font-size', mk.size * mk.maxW / len); }
      return e;
    }
  };
  poster.forEach(mk => draw(mk, mk.plate === 3 ? type : inks));
  st.forEach(mk => draw(mk, stripG));
  add(card, 'rect', { x: 0, y: 0, width: W, height: H, fill: `url(#${id}g)` });
  return svg;
}

if (typeof module !== 'undefined') module.exports = { fnv, Dice, releaseKey, floorEdition, compose, partDice, PARTS, MOVEMENTS, PALETTES, STOCKS };
