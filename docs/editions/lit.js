// The edition lit: Stub/Shaders/Edition.metal ported line for line to JavaScript and run per pixel over canvas
// layers drawn from the same marks, so the surfaces can be judged before a Mac builds them. Slow, faithful.
function drawMarks(g, marks, pal, { foilOnly = false, metallic, printed = 9, colourOverride, plates = [1, 2, 3] } = {}) {
  for (const mk of marks) {
    const toFoil = mk.foil && metallic;
    if (foilOnly ? !toFoil : toFoil) continue;
    if (!foilOnly && !plates.includes(mk.plate)) continue;
    if (mk.plate > printed) continue;
    g.save();
    g.globalAlpha = mk.op ?? 1;
    g.globalCompositeOperation = mk.blend === 'multiply' ? 'multiply' : mk.blend === 'screen' ? 'screen' : 'source-over';
    if (mk.rot) { g.translate(mk.rot.cx, mk.rot.cy); g.rotate(mk.rot.deg * Math.PI / 180); g.translate(-mk.rot.cx, -mk.rot.cy); }
    const col = colourOverride || hex(pal[mk.ink]);
    g.fillStyle = col; g.strokeStyle = col;
    const dash = mk.dash || [];
    g.setLineDash(dash);
    if (mk.k === 'rect') { if (mk.stroke) { g.lineWidth = mk.stroke; g.strokeRect(mk.x, mk.y, mk.w, mk.h); } else g.fillRect(mk.x, mk.y, mk.w, mk.h); }
    else if (mk.k === 'circle') { g.beginPath(); g.arc(mk.cx, mk.cy, mk.r, 0, Math.PI * 2); g.fill(); }
    else if (mk.k === 'ring') { g.beginPath(); g.arc(mk.cx, mk.cy, mk.r, 0, Math.PI * 2); g.lineWidth = mk.w; g.stroke(); }
    else if (mk.k === 'poly') { g.beginPath(); mk.pts.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.closePath(); if (mk.stroke) { g.lineWidth = mk.stroke; g.stroke(); } else g.fill(); }
    else if (mk.k === 'line') { g.beginPath(); g.moveTo(mk.x1, mk.y1); g.lineTo(mk.x2, mk.y2); g.lineWidth = mk.w; g.stroke(); }
    else if (mk.k === 'halftone') {
      g.beginPath();
      for (let y = mk.y + mk.step / 2; y < mk.y + mk.h; y += mk.step) for (let x = mk.x + mk.step / 2 + ((Math.round(y / mk.step) % 2) * mk.step / 2); x < mk.x + mk.w; x += mk.step) {
        const t = 1 - Math.hypot(x - mk.fx, y - mk.fy) / mk.R; if (t <= 0.04) continue; const r = mk.rmax * Math.sqrt(t); g.moveTo(x + r, y); g.arc(x, y, r, 0, Math.PI * 2);
      }
      g.fill();
    } else if (mk.k === 'text') {
      const [fam, wt, st] = FONT[mk.face];
      let size = mk.size;
      const font = s => `${st === 'italic' ? 'italic ' : ''}${wt} ${s}px "${fam}"`;
      g.font = font(size); g.letterSpacing = `${(mk.track || 0) * size}px`;
      let wdt = g.measureText(mk.text).width;
      if (mk.maxW && wdt > mk.maxW) { size = size * mk.maxW / wdt; g.font = font(size); g.letterSpacing = `${(mk.track || 0) * size}px`; wdt = g.measureText(mk.text).width; }
      g.textBaseline = 'alphabetic';
      const x = mk.anchor === 'middle' ? mk.x - wdt / 2 : mk.anchor === 'end' ? mk.x - wdt : mk.x;
      g.fillText(mk.text, x, mk.y);
    }
    g.restore();
  }
}
const STOCK = { cotton: { grain: 0.05, fibre: 0.045, gloss: 0.02, depth: 2.2, reach: 1.2 }, coated: { grain: 0.025, fibre: 0, gloss: 0.10, depth: 1, reach: 0.8 }, foil: { grain: 0.025, fibre: 0, gloss: 0.08, depth: 1, reach: 0.8 }, holographic: { grain: 0.025, fibre: 0, gloss: 0.10, depth: 1, reach: 0.8 } };
const fract = x => x - Math.floor(x);
const hash2 = (x, y) => fract(Math.sin(x * 127.1 + y * 311.7) * 43758.5453);
function vnoise(x, y) { const ix = Math.floor(x), iy = Math.floor(y), fx = x - ix, fy = y - iy; const ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy); const a = hash2(ix, iy), b = hash2(ix + 1, iy), c = hash2(ix, iy + 1), d = hash2(ix + 1, iy + 1); return (a + (b - a) * ux) * (1 - uy) + (c + (d - c) * ux) * uy; }
function sheen(u, v, lx, ly, width) { const n = Math.hypot(0.8, 0.6); const along = ((u - 0.5) * 0.8 + (v - 0.5) * 0.6) / n; const shift = (lx + 0.45) * 0.9 + (ly + 0.6) * 0.6; const t = (along + shift) * width; return Math.exp(-t * t); }
function norm3(x, y, z) { const l = Math.hypot(x, y, z) || 1; return [x / l, y / l, z / l]; }
function litCard(edition, copy, tilt = [0, 0], scale = 2) {
  const { pal, poster, strip: st, stripField, posterField } = compose(edition, copy);
  const metallic = edition.stock === 'foil' || edition.stock === 'holographic';
  const S = STOCK[edition.stock], depth = S.depth * (edition.movement === 'letterpress' ? 1.6 : 1);
  const w = W * scale, h = H * scale;
  const layer = () => { const cv = document.createElement('canvas'); cv.width = w; cv.height = h; const g = cv.getContext('2d'); g.scale(scale, scale); return [cv, g]; };
  const [gcv, gg] = layer(); gg.fillStyle = hex(pal[posterField]); gg.fillRect(0, 0, W, PH); gg.fillStyle = hex(pal[stripField]); gg.fillRect(0, PH, W, H - PH);
  const [icv, ig] = layer(); ig.save(); ig.beginPath(); ig.rect(0, 0, W, PH); ig.clip(); drawMarks(ig, poster, pal, { metallic, plates: [1, 2] }); ig.restore(); drawMarks(ig, st, pal, { metallic, plates: [1, 2] });
  // The type over the foil, as EditionFace lays it.
  const [tcv, tg] = layer(); tg.save(); tg.beginPath(); tg.rect(0, 0, W, PH); tg.clip(); drawMarks(tg, poster, pal, { metallic, plates: [3] }); tg.restore(); drawMarks(tg, st, pal, { metallic, plates: [3] });
  const [fcv, fg] = layer(); fg.beginPath(); fg.rect(0, 0, W, PH); fg.clip(); drawMarks(fg, poster, pal, { foilOnly: true, metallic, colourOverride: '#fff' });
  const G = gg.getImageData(0, 0, w, h).data, I = ig.getImageData(0, 0, w, h).data, F = fg.getImageData(0, 0, w, h).data, T = tcv.getContext('2d').getImageData(0, 0, w, h).data;
  const out = new ImageData(w, h), O = out.data;
  const lx = -0.45 + tilt[0] * 0.9, ly = -0.6 + tilt[1] * 0.9; const L = norm3(lx, ly, 1); const Hh = norm3(L[0], L[1], L[2] + 1);
  const seed = Number(edition.seed % 997n);
  const metal = (() => { const b = pal.groundIsLight ? parseInt(((a, b2, t) => { const ch = s => [(s >> 16) & 255, (s >> 8) & 255, s & 255]; const A = ch(a), B = ch(b2); return A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, '0')).join(''); })(pal.metal, pal.ink, 0.38), 16) : pal.metal; return [(b >> 16 & 255) / 255, (b >> 8 & 255) / 255, (b & 255) / 255]; })();
  const px = (D, x, y) => { x = Math.max(0, Math.min(w - 1, Math.round(x))); y = Math.max(0, Math.min(h - 1, Math.round(y))); const i = (y * w + x) * 4; return [D[i] / 255, D[i + 1] / 255, D[i + 2] / 255, D[i + 3] / 255]; };
  // premultiplied height, as edition_height: a - 0.6 * luma(premultiplied rgb)
  const height = (D, x, y) => { const [r, g, b, a] = px(D, x, y); return a - 0.6 * (0.299 * r + 0.587 * g + 0.114 * b) * a; };
  const R = S.reach * scale, e = 0.6 * scale;
  // The relief shader: a layer's pixel with its wall shading, premultiplied (getImageData is not, so multiply).
  const relief = (D, x, y) => {
    const i = (y * w + x) * 4, a = D[i + 3] / 255;
    const hl = height(D, x - R, y), hr = height(D, x + R, y), hu = height(D, x, y - R), hd = height(D, x, y + R);
    const nn = norm3((hr - hl) * depth, (hd - hu) * depth, 2 * S.reach);
    const shade = Math.max(-1, Math.min(1, (nn[0] * L[0] + nn[1] * L[1] + nn[2] * L[2] - L[2]) * 1.6));
    const tone = shade > 0 ? [shade * 0.5, shade * 0.5, shade * 0.5, shade * 0.5] : [0, 0, 0, -shade * 0.55];
    const ink = [D[i] / 255 * a, D[i + 1] / 255 * a, D[i + 2] / 255 * a, a];
    return [0, 1, 2, 3].map(k => tone[k] + ink[k] * (1 - tone[3]));
  };
  const over = (top, c) => [0, 1, 2].map(k => top[k] + c[k] * (1 - top[3]));
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 4, pos = [x / scale, y / scale], u = pos[0] / W, v = pos[1] / H;
    // stock
    const n = hash2(Math.floor(pos[0]) + seed, Math.floor(pos[1]) + seed) - 0.5;
    const f = vnoise(pos[0] * 0.11 + seed * 13, pos[1] * 0.32 + seed * 13) * 0.65 + vnoise(pos[0] * 0.31 + seed * 7, pos[1] * 0.9 + seed * 7) * 0.35 - 0.5;
    const s = sheen(u, v, lx, ly, 2.2) * S.gloss;
    let c = [0, 1, 2].map(k => Math.min(1, Math.max(0, G[i + k] / 255 + n * S.grain + f * S.fibre + s)));
    c = over(relief(I, x, y), c);
    // foil
    const fa = F[i + 3] / 255;
    if (metallic && fa > 0.002) {
      const al = px(F, x - e, y)[3], ar = px(F, x + e, y)[3], au = px(F, x, y - e)[3], ad = px(F, x, y + e)[3];
      const fn = norm3(-(ar - al) * 1.4, -(ad - au) * 1.4, 2 * 0.6);
      const spec = Math.pow(Math.max(fn[0] * Hh[0] + fn[1] * Hh[1] + fn[2] * Hh[2], 0), 48);
      const edge = Math.max(-1, Math.min(1, (fn[0] * L[0] + fn[1] * L[1] + fn[2] * L[2] - L[2]) * 2));
      const sh = sheen(u, v, lx, ly, 3.2);
      const brush = hash2(0, Math.floor(pos[1] * 2)) - 0.5;
      let col;
      if (edition.stock === 'holographic') {
        const t = (u * 0.9 + v * 0.5) * 4.2 + lx * 2.2 + ly * 1.4;
        let film = [0, 0.33, 0.67].map(o => 0.5 + 0.5 * Math.cos(6.28318 * (t + o)));
        if (pal.groundIsLight) film = film.map(q => q * 0.62);
        col = [0, 1, 2].map(k => (metal[k] + (film[k] - metal[k]) * 0.38) * (0.78 + 0.55 * sh));
      } else col = metal.map(q => q * (0.62 + 0.72 * sh));
      col = col.map(q => Math.min(1, Math.max(0, q + spec * 0.35 + edge * 0.18 + brush * (edition.stock === 'holographic' ? 0.015 : 0.045))));
      c = [0, 1, 2].map(k => col[k] * fa + c[k] * (1 - fa));
    }
    c = over(relief(T, x, y), c);
    O[i] = c[0] * 255; O[i + 1] = c[1] * 255; O[i + 2] = c[2] * 255; O[i + 3] = 255;
  }
  const cv = document.createElement('canvas'); cv.width = w; cv.height = h; cv.getContext('2d').putImageData(out, 0, 0);
  // The ticket's outline, punched.
  const mcv = document.createElement('canvas'); mcv.width = w; mcv.height = h; const m = mcv.getContext('2d'); m.scale(scale, scale);
  m.beginPath(); m.roundRect(0, 0, W, H, 10); m.fill(); m.globalCompositeOperation = 'destination-out';
  for (const cx of [0, W]) { m.beginPath(); m.arc(cx, PH, 8, 0, Math.PI * 2); m.fill(); }
  for (let hx = 16; hx < W - 14; hx += 7.5) { m.beginPath(); m.arc(hx, PH, 1.7, 0, Math.PI * 2); m.fill(); }
  m.globalCompositeOperation = 'source-in'; m.setTransform(1, 0, 0, 1, 0, 0); m.drawImage(cv, 0, 0);
  mcv.style.width = W + 'px'; mcv.style.height = H + 'px';
  return mcv;
}
