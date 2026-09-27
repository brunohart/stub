// The version 2 goldens (ADR-016): the first marks of three fixtures' compositions, computed by the mirror and pinned
// by `PressTests.goldensMatchTheMirror`. Run: node docs/editions/golden.js
// Only marks that set no type are printed: under Node there is no canvas to measure a face with.
const { floorEdition, compose } = require('./edition.js');

const copy = title => ({ title, viewing: 1, viewings: 1, viewingWords: 'First viewing', year: 2024, time: '19:30', seat: 'H12' });
const n = x => Number(x.toPrecision(15));
function describe(mk) {
  const at = { part: mk.part, k: mk.k };
  if (mk.k === 'rect') Object.assign(at, { x: n(mk.x), y: n(mk.y), w: n(mk.w), h: n(mk.h) });
  if (mk.k === 'circle' || mk.k === 'ring') Object.assign(at, { cx: n(mk.cx), cy: n(mk.cy), r: n(mk.r) });
  if (mk.k === 'line') Object.assign(at, { x1: n(mk.x1), y1: n(mk.y1), x2: n(mk.x2), y2: n(mk.y2) });
  if (mk.k === 'halftone') Object.assign(at, { fx: n(mk.fx), fy: n(mk.fy), R: n(mk.R) });
  if (mk.rot) at.rot = n(mk.rot.deg);
  return at;
}
for (const [title, takes] of [['The Brutalist', {}], ['The Brutalist', { 'constructivist/disc': 14 }], ['Dune Part Two', {}], ['Past Lives', {}]]) {
  const edition = { ...floorEdition(title), takes };
  const { poster } = compose(edition, copy(title));
  const shapes = poster.filter(mk => mk.k !== 'text' && !(edition.movement === 'blueprint' && mk.part === 'blueprint/grid'));
  console.log(`${title} ${edition.movement} ${JSON.stringify(takes)}`);
  for (const mk of shapes.slice(0, 5)) console.log('  ' + JSON.stringify(describe(mk)));
}
