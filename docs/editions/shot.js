// Photograph the specimen sheet: node docs/editions/shot.js "?mode=floor" docs/editions/floor.png
// or the lit sheet, the shaders emulated per pixel: node docs/editions/shot.js "lit.html?tilt=0.9,0.4" out.png
// Needs Playwright (npm i -g playwright). The sheet is drawn in a browser from the same dice and marks as
// Stub/Edition; it is a design tool and a specimen, not a proof of the app (the simulator is, ADR-003).
const path = require('path');
let chromium;
try { ({ chromium } = require('playwright')); } catch { ({ chromium } = require(path.join(process.env.NODE_PATH || '/opt/node22/lib/node_modules', 'playwright'))); }
(async () => {
  const [, , query = '', out = 'specimen.png'] = process.argv;
  const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: 1500, height: 1300 }, deviceScaleFactor: 1 });
  page.on('pageerror', e => console.error('error:', e.message));
  const [file, q] = query.includes('.html') ? query.split(/(?=\?)/) : ['specimen.html', query];
  await page.goto('file://' + path.join(__dirname, file) + (q || ''));
  await page.waitForSelector('body[data-ready="1"]', { timeout: 120000 });
  await page.waitForTimeout(300);
  await page.screenshot({ path: out, fullPage: true });
  await browser.close();
})();
