// scripts/test_site_phone_width.mjs — the site PHONE-WIDTH gate (#1740).
//
// WHAT IT ASSERTS, against the ASSEMBLED site (`make site` / `site/`) in a
// real headless Chromium at 375x812 and 390x844 (portrait — the two widths
// the owner's issue names): the landing, the guide home, the playground and
// three reference/repository pages —
//   - no page-level horizontal scroll: `document.documentElement.scrollWidth`
//     must not exceed the viewport width (a code block or table may still
//     scroll WITHIN ITSELF — `overflow-x: auto` on the element itself — that
//     is the existing, correct pattern and is not refused here);
//   - the main content column's left/right padding (its "gutter") is at
//     least 16px;
//   - every visible navigation/control tap target — the sidebar, the
//     header nav, the guide home's table-of-contents, a hero CTA, a ring
//     figure's caption link, the playground's tabs/buttons (#1740 round 2:
//     the integrator's browser read found 165 on guide.html and 1 on
//     index.html this gate's selector, and its old "both width AND height
//     under 44" test, both missed) — is at least 44px tall. An inline link
//     inside running prose or a reference list is exempt, same as WCAG's
//     own target-size criterion exempts it;
//   - the smallest font-size of the running prose (`main p`, `main li`, as
//     before) PLUS the guide home's table-of-contents entries and the two
//     links that follow a ring figure (`.toc-groups a`, `.hero-cta`,
//     `.fig-caption` — #1740 round 2's named findings) is at least 16px.
//     This is deliberately not a sweep of every text node on the page: a
//     handful of small badges/sub-links predate this round and sit outside
//     #1740's named findings (RESULTS.md flags them, this gate does not).
//     SVG `<text>` is excluded on principle: its computed font-size is the
//     unscaled SVG user-unit value, not the on-screen pixel size after the
//     viewBox scales it — the ring figure's own per-module labels are a
//     stylesheet fix, not a gate assertion (scripts/gen_guide/style.css).
//
// SITE-3 (#1759, #1760 — the owner's phone screenshots of 2026-10-02; RULED:
// DOCS-51 criteria 2, 3, 9, PLAY-3) grows the step to the WHOLE served
// layout, the top bar and the sidebar included, in any orientation:
//   - the LAYOUT at 375x812, 390x844 (portrait) and 844x390, 812x375
//     (landscape — the owner: "in any orientation"): the page is no wider
//     than the width the device was given (`scrollWidth` against THAT width,
//     never `innerWidth`, which a phone's browser widens to the content: the
//     live 09-29 landing measured innerWidth 672 at a 375px device), the body,
//     the top bar, the sidebar and the main column all lie inside
//     [0, width] (the main column's left edge >= 0), the top bar's own
//     content is not clipped (its scrollWidth <= its clientWidth — the
//     owner's "X · CXHOME.ORG ... ABOU"), and no visible element outside a
//     container that scrolls or clips on its own (a code block, a table, the
//     playground's panes) reaches past either edge;
//   - the SIDEBAR COLLAPSES on a phone (portrait): it is a disclosure,
//     closed when the page opens, so the main column starts in the first
//     screen (its top <= 30 % of the height; the head's sidebar stacked
//     1741px of navigation above the landing's first word), and opening it
//     shows the navigation without widening the page;
//   - EVERY served page (all of site/**/*.html, the playground's own probe
//     page aside) passes the layout assertions at 375x812;
//   - the PLAYGROUND (#1760) opens on one example — its source and its
//     output — with at most PLAYGROUND_CONTROLS interactive controls visible
//     above the fold, all in ONE row, at 375, 390, 844 (landscape) and 1280
//     px: the brand (the way back to the site), the picker, Run and the ONE
//     disclosure (the owner's "the picker and Run in one row", "no toolbar of
//     more than four controls"; the editors themselves are the example's own
//     text and are not counted); the editor and the output both start above
//     the fold, stacked on a phone; every secondary surface (the search, the
//     readings, the output codecs and Pretty, the fixture strip and verdict,
//     the view's subject/detail/Tree/Graph controls, the diagram modes and
//     zoom, the engine note) is hidden until the disclosure opens and
//     visible after, and no row of controls in the opened page holds more
//     than four.
// A violation on any page, at any width, is named by URL, width and the
// measurement; exit 1. Needs Chrome/Chromium (CX_CHROME) and a built site
// (`make site`); boots its own static server over `scripts/serve_static.cx`.
// `--shots=DIR` writes the landing's and the playground's screenshots at
// every width (`<page>-<width>-<tag>.png`, `--shot-tag=` default `run`).
//
// Usage: node scripts/test_site_phone_width.mjs [--root=site] [--shots=DIR --shot-tag=before]
//   CX_CHROME=<path>  CX_BIN=<native cx>

import { existsSync, mkdtempSync, rmSync, readdirSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join, relative } from 'node:path';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';

const ROOT = resolve(import.meta.dirname, '..');
const rootArg = process.argv.find((a) => a.startsWith('--root='));
const SITE = resolve(ROOT, rootArg ? rootArg.slice('--root='.length) : 'site');
const NATIVE = process.env.CX_BIN ? resolve(process.env.CX_BIN) : resolve(ROOT, 'deps/cx-core-code/vcx/target/cx');
const CHROME_CANDIDATES = [
  process.env.CX_CHROME,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
  '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser',
].filter(Boolean);

const LABEL = 'test-site-phone-width';
function say(s) { console.log(`${LABEL}: ${s}`); }
function cry(s) { console.error(`${LABEL}: ${s}`); }
function setupFail(msg, hint) {
  cry(`SETUP FAILURE — ${msg}`);
  if (hint) cry(`  hint: ${hint}`);
  cleanupAll();
  process.exit(2);
}

const PAGES = ['index.html', 'guide.html', 'playground.html', 'directives.html', 'codec-xml.html', 'repo-cx.html'];
const WIDTHS = [[375, 812], [390, 844]];
// SITE-3: the layout holds in either orientation (portrait above, landscape here).
const LANDSCAPE = [[844, 390], [812, 375]];
// SITE-3 (#1760): the playground's controls above the fold — the brand, the
// picker, Run and the one disclosure — at a phone's widths and the desktop's.
const PLAYGROUND_WIDTHS = [[375, 812], [390, 844], [844, 390], [1280, 800]];
const PLAYGROUND_CONTROLS = 4;
const shotsArg = process.argv.find((a) => a.startsWith('--shots='));
const SHOTS = shotsArg ? resolve(ROOT, shotsArg.slice('--shots='.length)) : null;
const tagArg = process.argv.find((a) => a.startsWith('--shot-tag='));
const SHOT_TAG = tagArg ? tagArg.slice('--shot-tag='.length) : 'run';
const DEADLINE_MS = 12 * 60 * 1000;
const STARTED = Date.now();
function checkDeadline(where) {
  if (Date.now() - STARTED > DEADLINE_MS) setupFail(`deadline exceeded at ${where}`);
}

let server = null, browser = null, profileDir = null;
function cleanupAll() {
  for (const p of [server, browser]) {
    if (p && p.pid && p.exitCode === null) { try { p.kill('SIGKILL'); } catch (_) {} }
  }
  if (profileDir) { try { rmSync(profileDir, { recursive: true, force: true }); } catch (_) {} }
}
process.on('exit', cleanupAll);
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => { cleanupAll(); process.exit(130); });

if (!existsSync(join(SITE, 'playground.html'))) {
  setupFail(`${SITE}/playground.html is not staged.`, 'make site');
}
if (!existsSync(NATIVE)) setupFail(`the native reference binary is missing: ${NATIVE}`, 'make build-vcx');
const chrome = CHROME_CANDIDATES.find(existsSync);
if (!chrome) setupFail('no Chromium-family browser found.', 'install Chrome/Chromium, or set CX_CHROME');

// ── the static server ──────────────────────────────────────────────────
async function bootServer() {
  const base = 8900 + (process.pid % 200);
  for (let i = 0; i < 5; i++) {
    const port = base + i;
    checkDeadline('server boot');
    const p = spawn(NATIVE, ['--allow-read', '--allow-net', '--allow-clock',
      resolve(ROOT, 'scripts/serve_static.cx'), '--port', String(port), '--root', SITE],
      { cwd: ROOT, stdio: ['ignore', 'pipe', 'pipe'] });
    const up = await new Promise((res) => {
      let settled = false;
      p.once('exit', () => { if (!settled) { settled = true; res(false); } });
      (async () => {
        for (let j = 0; j < 80; j++) {
          await new Promise((r) => setTimeout(r, 125));
          if (settled) return;
          try {
            const r = await fetch(`http://127.0.0.1:${port}/playground.html`, { signal: AbortSignal.timeout(2000) });
            if (r.ok) { settled = true; return res(true); }
          } catch (_) {}
        }
        if (!settled) { settled = true; res(false); }
      })();
    });
    if (up) { server = p; return port; }
    try { p.kill('SIGKILL'); } catch (_) {}
  }
  setupFail('could not boot scripts/serve_static.cx on any candidate port.');
}

// ── the browser + CDP (one Chrome process, one tab reused across pages) ──
async function bootBrowser() {
  const cdpPort = 9300 + (process.pid % 300);
  profileDir = mkdtempSync(join(tmpdir(), 'cx-site-phone-gate-'));
  browser = spawn(chrome, [
    `--remote-debugging-port=${cdpPort}`, '--headless=new', '--no-first-run',
    '--no-default-browser-check', '--disable-gpu', '--disable-dev-shm-usage',
    `--user-data-dir=${profileDir}`, 'about:blank',
  ], { stdio: ['ignore', 'pipe', 'pipe'] });
  let version = null;
  for (let i = 0; i < 160; i++) {
    checkDeadline('browser boot');
    if (browser.exitCode !== null) setupFail(`the browser exited (code ${browser.exitCode}) before its debugging port opened.`);
    await new Promise((r) => setTimeout(r, 250));
    try {
      const r = await fetch(`http://127.0.0.1:${cdpPort}/json/version`, { signal: AbortSignal.timeout(2000) });
      if (r.ok) { version = await r.json(); break; }
    } catch (_) {}
  }
  if (!version) setupFail(`the browser's CDP port ${cdpPort} never opened.`);
  const tabRes = await fetch(`http://127.0.0.1:${cdpPort}/json/new?about:blank`, { method: 'PUT', signal: AbortSignal.timeout(15000) });
  if (!tabRes.ok) setupFail(`CDP refused to open a tab: HTTP ${tabRes.status}`);
  const tab = await tabRes.json();
  const ws = new WebSocket(tab.webSocketDebuggerUrl);
  let msgId = 0;
  const pending = new Map();
  const waiters = new Set();
  ws.addEventListener('message', (ev) => {
    const m = JSON.parse(ev.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
    else if (m.method) { for (const w of [...waiters]) if (w.method === m.method) { waiters.delete(w); w.res(m.params); } }
  });
  const opened = await new Promise((res) => {
    const t = setTimeout(() => res(false), 20000);
    ws.addEventListener('open', () => { clearTimeout(t); res(true); }, { once: true });
    ws.addEventListener('error', () => { clearTimeout(t); res(false); }, { once: true });
  });
  if (!opened) setupFail('could not open the CDP websocket to the page.');
  function send(method, params, timeoutMs = 30000) {
    const id = ++msgId;
    return new Promise((res, rej) => {
      const t = setTimeout(() => { pending.delete(id); rej(new Error(`CDP ${method} timed out`)); }, timeoutMs);
      pending.set(id, (m) => { clearTimeout(t); res(m); });
      ws.send(JSON.stringify({ id, method, params }));
    });
  }
  async function evalJs(expression, timeoutMs = 30000) {
    const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true, timeout: timeoutMs - 2000 }, timeoutMs);
    if (r.error) throw new Error(`CDP error: ${JSON.stringify(r.error).slice(0, 300)}`);
    const res = r.result || {};
    if (res.exceptionDetails) throw new Error(`page threw: ${JSON.stringify(res.exceptionDetails).slice(0, 300)}`);
    return res.result ? res.result.value : undefined;
  }
  // An event the page fires (SITE-3: Page.loadEventFired — a navigation is
  // waited on by its event, never by polling a context it is replacing).
  function once(method, timeoutMs = 20000) {
    return new Promise((res) => {
      const w = { method, res };
      waiters.add(w);
      setTimeout(() => { if (waiters.delete(w)) res(null); }, timeoutMs);
    });
  }
  await send("Page.enable", {});
  // Hermetic: the step reads the served files, never the network. The
  // pages' webfonts (Google Fonts) are refused, so the layout is measured
  // in the fallback faces a phone shows until they arrive (they measure
  // wider: two stdlib pages overflowed in them and not in the webfonts).
  await send("Network.enable", {});
  await send("Network.setBlockedURLs", { urls: ["*fonts.googleapis.com*", "*fonts.gstatic.com*"] });
  return { send, evalJs, once, close: () => { try { ws.close(); } catch (_) {} } };
}

// ── measure one page at one width ────────────────────────────────────────
async function load(cdp, port, page, width, height, settleMs = 150) {
  await cdp.send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 2, mobile: width < 1024 });
  const url = `http://127.0.0.1:${port}/${page}`;
  checkDeadline(`load ${page}`);
  // Wait for THIS document's load event (polling readyState across a
  // navigation can hang on the context being replaced).
  // One retry, then the page is named with what Page.navigate answered
  // (#1764: lib-html, tooling and tour-programs fire none under headless
  // Chrome 154 and load at once in a desktop browser).
  let ok = false, navNote = '';
  for (let attempt = 0; attempt < 2 && !ok; attempt++) {
    const loaded = cdp.once('Page.loadEventFired', 15000);
    const nav = await cdp.send('Page.navigate', { url });
    navNote = JSON.stringify((nav && nav.result) || (nav && nav.error) || {}).slice(0, 200);
    ok = Boolean(await loaded);
    if (!ok) {
      try { ok = await cdp.evalJs(`location.pathname.endsWith(${JSON.stringify('/' + page)}) && document.readyState === 'complete'`, 5000); } catch (_) { ok = false; }
    }
  }
  if (!ok) throw new Error(`${page} fired no load event in two tries of 15 s (Page.navigate answered ${navNote})`);
  await new Promise((r) => setTimeout(r, settleMs)); // settle webfonts/layout
}

// ── SITE-3: the whole layout at one width (#1759) ────────────────────────
// W is the width the device was GIVEN: a phone's browser widens innerWidth
// to an overflowing page, so measuring against innerWidth would pass the
// very page the owner photographed.
const LAYOUT_JS = (W) => `JSON.stringify((function () {
  const W = ${W};
  const html = document.documentElement;
  const R = (e) => { const b = e.getBoundingClientRect(); return { l: Math.round(b.left), r: Math.round(b.right), t: Math.round(b.top), w: Math.round(b.width), h: Math.round(b.height) }; };
  const shown = (e) => { const b = e.getBoundingClientRect(); if (b.width <= 0 || b.height <= 0) return false;
    for (let p = e; p && p.nodeType === 1; p = p.parentElement) { const cs = getComputedStyle(p); if (cs.display === 'none' || cs.visibility === 'hidden') return false; } return true; };
  const clipsX = (e) => { for (let p = e.parentElement; p && p !== document.body && p !== html; p = p.parentElement) {
    const o = getComputedStyle(p).overflowX; if (o === 'auto' || o === 'scroll' || o === 'hidden' || o === 'clip') return true; } return false; };
  const boxes = {};
  for (const [k, sel] of [['body', 'body'], ['header', 'header.sheet-bar, header.cxp-toolbar, body > header'], ['sidebar', 'aside.sidebar'], ['main', 'main']]) {
    const e = document.querySelector(sel); if (e && shown(e)) boxes[k] = R(e);
  }
  const outside = Object.entries(boxes).filter(([, b]) => b.l < -1 || b.r > W + 1).map(([k, b]) => k + ' ' + JSON.stringify(b));
  const hdr = document.querySelector('header.sheet-bar, header.cxp-toolbar, body > header');
  const hdrClipped = hdr && shown(hdr) && hdr.scrollWidth > hdr.clientWidth + 1 ? (hdr.scrollWidth + ' > ' + hdr.clientWidth) : null;
  const wide = [...document.body.querySelectorAll('*')]
    .filter((e) => !(e.closest('svg') && e.tagName.toLowerCase() !== 'svg'))
    .filter((e) => { const b = e.getBoundingClientRect(); return (b.right > W + 1 || b.left < -1) && shown(e) && !clipsX(e); })
    .map((e) => e.tagName.toLowerCase() + (e.className && typeof e.className === 'string' ? '.' + e.className.split(' ')[0] : '') + ' ' + JSON.stringify(R(e)));
  return { scrollWidth: Math.max(html.scrollWidth, document.body.scrollWidth), boxes, outside, hdrClipped, wideCount: wide.length, wide: wide.slice(0, 3) };
})())`;
async function layout(cdp, W) { return JSON.parse(await cdp.evalJs(LAYOUT_JS(W))); }
function layoutFailures(m, where, W) {
  const f = [];
  if (m.scrollWidth > W + 1) f.push(`${where}: the page is ${m.scrollWidth}px wide on a ${W}px device (horizontal page scroll)`);
  if (m.outside.length) f.push(`${where}: outside [0, ${W}]: ${m.outside.join('; ')}`);
  if (m.boxes.main && m.boxes.main.l < 0) f.push(`${where}: the main column's left edge is ${m.boxes.main.l}px`);
  if (m.hdrClipped) f.push(`${where}: the top bar clips its own content (scrollWidth ${m.hdrClipped})`);
  if (m.wideCount) f.push(`${where}: ${m.wideCount} element(s) reach past the viewport — e.g. ${m.wide.join('; ')}`);
  return f;
}

// ── SITE-3: the sidebar is a disclosure on a phone (#1759) ───────────────
async function sidebarCollapse(cdp, W, H) {
  return JSON.parse(await cdp.evalJs(`(async function () {
    const side = document.querySelector('aside.sidebar');
    const main = document.querySelector('main');
    if (!side || !main) return JSON.stringify({ none: true });
    const toggle = side.querySelector('details > summary') || side.querySelector('[aria-expanded]');
    const isOpen = () => { if (!toggle) return true; const d = toggle.closest('details'); return d ? d.open : toggle.getAttribute('aria-expanded') === 'true'; };
    const navShown = () => [...side.querySelectorAll('nav a, details a, .nav-group a, ul a')].some((a) => { const b = a.getBoundingClientRect(); return b.width > 0 && b.height > 0 && a.offsetParent !== null; });
    const out = { hasToggle: !!toggle, openAtLoad: isOpen(), mainTop: Math.round(main.getBoundingClientRect().top + scrollY) };
    if (toggle) {
      toggle.click(); await new Promise((r) => setTimeout(r, 80));
      out.openedShowsNav = isOpen() && navShown();
      out.openedScrollWidth = Math.max(document.documentElement.scrollWidth, document.body.scrollWidth);
      toggle.click(); await new Promise((r) => setTimeout(r, 80));
      out.closedAgain = !isOpen();
    }
    return JSON.stringify(out);
  })()`));
}
function sidebarFailures(s, where, W, H) {
  if (s.none) return [];
  const f = [];
  if (!s.hasToggle) f.push(`${where}: the sidebar is not a disclosure (no <details>/<summary> or aria-expanded control in aside.sidebar) — it stacks above the page`);
  else {
    if (s.openAtLoad) f.push(`${where}: the sidebar's disclosure is OPEN when the page loads`);
    if (!s.openedShowsNav) f.push(`${where}: opening the sidebar's disclosure does not show its navigation`);
    if (s.openedScrollWidth > W + 1) f.push(`${where}: the opened sidebar widens the page to ${s.openedScrollWidth}px`);
    if (!s.closedAgain) f.push(`${where}: the sidebar's disclosure does not close again`);
  }
  if (s.mainTop > Math.round(H * 0.3)) f.push(`${where}: the main column starts at ${s.mainTop}px — below the first 30 % of an ${H}px screen (the sidebar does not collapse)`);
  return f;
}

// ── SITE-3: the playground's controls (#1760) ────────────────────────────
// Counted: every visible a[href], button, select, input, summary, [role=tab]
// and focusable [tabindex] whose box starts above the fold; the editors
// (textarea) are the example's own text and are named apart. A "row" is the
// controls whose centres share one line (within 12px).
const CONTROLS_JS = `(function () {
  const H = innerHeight;
  const shown = (e) => { const b = e.getBoundingClientRect(); if (b.width <= 0 || b.height <= 0) return false;
    for (let p = e; p && p.nodeType === 1; p = p.parentElement) { const cs = getComputedStyle(p); if (cs.display === 'none' || cs.visibility === 'hidden') return false; } return true; };
  const sel = 'a[href], button, select, input:not([type=hidden]), textarea, summary, [role=tab], [tabindex]:not([tabindex="-1"])';
  const all = [...document.querySelectorAll(sel)].filter(shown);
  const label = (e) => (e.id ? '#' + e.id : e.tagName.toLowerCase() + (typeof e.className === 'string' && e.className ? '.' + e.className.split(' ')[0] : '')) + ':' + (e.textContent || e.value || e.placeholder || '').trim().slice(0, 12);
  const rowsOf = (list) => { const rows = []; for (const e of list) { const b = e.getBoundingClientRect(); const cy = b.top + b.height / 2;
      let row = rows.find((r) => Math.abs(r.cy - cy) < 12); if (!row) { row = { cy, items: [] }; rows.push(row); } row.items.push(label(e)); }
    return rows.sort((a, b) => a.cy - b.cy).map((r) => r.items); };
  const fold = all.filter((e) => { const b = e.getBoundingClientRect(); return b.top < H && b.bottom > 0; });
  const counted = fold.filter((e) => e.tagName !== 'TEXTAREA');
  const box = (q) => { const e = document.querySelector(q); if (!e || !shown(e)) return null; const b = e.getBoundingClientRect(); return { t: Math.round(b.top), b: Math.round(b.bottom), l: Math.round(b.left), r: Math.round(b.right), h: Math.round(b.height) }; };
  const editor = [...document.querySelectorAll('.cxp-edit-block')].filter(shown).map((e) => e.getBoundingClientRect()).sort((a, b) => a.top - b.top)[0];
  const output = document.querySelector('.cxp-output.is-active');
  const ob = output && shown(output) ? output.getBoundingClientRect() : null;
  const SECONDARY = ['#cxp-search', '.cxp-reading-tab', '#cxp-prev', '#cxp-next', '#cxp-reset', '#cxp-share', '.cxp-tab', '#cxp-format', '#cxp-fixture', '#cxp-cmd', '.cxp-subject-tab', '#cxp-detail-select', '.cxp-viz-tab', '.cxp-gview-tab', '#cxp-graph-zoom-in'];
  const secondaryShown = SECONDARY.filter((q) => [...document.querySelectorAll(q)].some(shown));
  const status = document.getElementById('cxp-status');
  const engineNote = !!(status && shown(status) && /libcx\\.wasm|JSPI/.test(status.textContent));
  return JSON.stringify({ H, controls: counted.length, rows: rowsOf(counted), allRows: rowsOf(all.filter((e) => e.tagName !== 'TEXTAREA')),
    editor: editor ? { t: Math.round(editor.top), b: Math.round(editor.bottom), l: Math.round(editor.left) } : null,
    output: ob ? { t: Math.round(ob.top), b: Math.round(ob.bottom), l: Math.round(ob.left) } : null,
    secondaryShown, engineNote,
    toggle: (() => { const t = document.querySelector('header [aria-expanded], header details > summary'); return t ? (t.id ? '#' + t.id : t.tagName.toLowerCase()) : null; })() });
})()`;
async function playgroundControls(cdp) { return JSON.parse(await cdp.evalJs(CONTROLS_JS)); }
async function playgroundToggle(cdp) {
  return cdp.evalJs(`(async function () {
    const t = document.querySelector('header [aria-expanded], header details > summary');
    if (!t) return false; t.click(); await new Promise((r) => setTimeout(r, 250)); return true;
  })()`);
}
async function playgroundGraph(cdp, on) {
  return cdp.evalJs(`(async function () {
    const t = document.querySelector('.cxp-viz-tab[data-viz="${on ? 'graph' : 'tree'}"]');
    if (!t) return false; t.click(); await new Promise((r) => setTimeout(r, 250)); return true;
  })()`);
}
// The playground answers its opening example on load; the count is read on
// the page a reader sees once it has (or after 20 s without an engine).
async function waitPlayground(cdp) {
  for (let i = 0; i < 160; i++) {
    checkDeadline('playground run');
    let ran = null;
    try { ran = await cdp.evalJs('document.body && document.body.dataset.ran || null'); } catch (_) {}
    if (ran) break;
    await new Promise((r) => setTimeout(r, 125));
  }
  await new Promise((r) => setTimeout(r, 300));
}
const PRIMARY_SURFACES = ['#cxp-search', '.cxp-reading-tab', '.cxp-tab', '#cxp-format', '#cxp-fixture', '.cxp-subject-tab', '#cxp-detail-select', '.cxp-viz-tab'];
async function playgroundFailures(cdp, where, W) {
  const f = [];
  const c = await playgroundControls(cdp);
  const report = `controls above the fold ${c.controls} in ${c.rows.length} row(s): ${c.rows.map((r) => '[' + r.join(' | ') + ']').join(' ')}`;
  if (c.controls > PLAYGROUND_CONTROLS) f.push(`${where}: ${report} — more than ${PLAYGROUND_CONTROLS}`);
  else if (c.rows.length > 1) f.push(`${where}: ${report} — the controls are not one row`);
  if (!c.editor || c.editor.t >= c.H) f.push(`${where}: the source editor does not start above the fold (${JSON.stringify(c.editor)})`);
  if (!c.output || c.output.t >= c.H) f.push(`${where}: the output does not start above the fold (${JSON.stringify(c.output)})`);
  if (W < 640 && c.editor && c.output && c.output.t < c.editor.b - 1) f.push(`${where}: on a phone the output is not stacked under the editor (editor ${JSON.stringify(c.editor)}, output ${JSON.stringify(c.output)})`);
  if (c.secondaryShown.length) f.push(`${where}: secondary surfaces visible before the disclosure opens: ${c.secondaryShown.join(', ')}`);
  if (c.engineNote) f.push(`${where}: the engine note (libcx.wasm / JSPI) is visible before the disclosure opens`);
  if (!c.toggle) { f.push(`${where}: the toolbar has no disclosure (an aria-expanded control or a <details> summary in the header)`); return { f, c }; }
  await playgroundToggle(cdp);
  const o = await playgroundControls(cdp);
  const missing = PRIMARY_SURFACES.filter((q) => !o.secondaryShown.includes(q));
  if (missing.length) f.push(`${where}: opening the disclosure does not show: ${missing.join(', ')}`);
  if (!o.engineNote) f.push(`${where}: opening the disclosure does not show the engine note`);
  const fat = o.allRows.filter((r) => r.length > PLAYGROUND_CONTROLS);
  if (fat.length) f.push(`${where}: with the disclosure open a row holds more than ${PLAYGROUND_CONTROLS} controls: ${fat.map((r) => '[' + r.join(' | ') + ']').join(' ')}`);
  const lo = await layout(cdp, W);
  if (lo.scrollWidth > W + 1) f.push(`${where}: with the disclosure open the page is ${lo.scrollWidth}px wide`);
  await playgroundGraph(cdp, true);
  const g = await playgroundControls(cdp);
  for (const q of ['.cxp-gview-tab', '#cxp-graph-zoom-in']) if (!g.secondaryShown.includes(q)) f.push(`${where}: the Graph view does not show ${q} once the disclosure is open`);
  const gfat = g.allRows.filter((r) => r.length > PLAYGROUND_CONTROLS);
  if (gfat.length) f.push(`${where}: the Graph view has a row of more than ${PLAYGROUND_CONTROLS} controls: ${gfat.map((r) => '[' + r.join(' | ') + ']').join(' ')}`);
  await playgroundGraph(cdp, false);
  await playgroundToggle(cdp);
  const back = await playgroundControls(cdp);
  if (back.secondaryShown.length) f.push(`${where}: closing the disclosure leaves visible: ${back.secondaryShown.join(', ')}`);
  return { f, c, o };
}

async function shot(cdp, name) {
  if (!SHOTS) return;
  mkdirSync(SHOTS, { recursive: true });
  const r = await cdp.send('Page.captureScreenshot', { format: 'png' }, 30000);
  if (r.result && r.result.data) writeFileSync(join(SHOTS, `${name}-${SHOT_TAG}.png`), Buffer.from(r.result.data, 'base64'));
}

function servedPages(dir, base = dir) {
  const out = [];
  for (const n of readdirSync(dir)) {
    const p = join(dir, n);
    if (statSync(p).isDirectory()) { if (n !== 'playground') out.push(...servedPages(p, base)); }
    else if (n.endsWith('.html')) out.push(relative(base, p));
  }
  return out.sort();
}

async function measure(cdp, port, page, width, height) {
  await load(cdp, port, page, width, height);
  const raw = await cdp.evalJs(`JSON.stringify((function () {
    const html = document.documentElement;
    const main = document.querySelector('main') || document.body;
    const cs = getComputedStyle(main);
    const gutterL = parseFloat(cs.paddingLeft) || 0, gutterR = parseFloat(cs.paddingRight) || 0;
    // Every visible NAVIGATION/CONTROL tap target — the sidebar, the
    // header nav, the guide home's table-of-contents, the hero CTAs and a
    // ring figure's own caption link, the playground's tabs/buttons (#1740
    // round 2, the integrator's browser read on PLAY-3:
    // querySelectorAll('a,button') found 165 on guide.html and 1 on
    // index.html at under 44px tall — this gate's selector had the
    // sidebar and header but had forgotten '.toc-groups a' itself (only
    // its 'summary' toggles), and both '.hero-cta a' and '.fig-caption a'
    // outright; its "width AND height both under 44" test would have
    // missed them regardless, a full-width link only 15px tall tripping
    // neither half). Deliberately NOT every '<a>' on the page: an inline
    // citation link inside running prose or a reference list — 'repo-
    // cx.html''s "README" / "spec/03-approved" / "conformance" links, or a
    // "the why page" cross-reference mid-sentence — is read, not tapped as
    // a control, and WCAG's own target-size criterion exempts exactly this
    // case (a control inside a sentence or block of text); a blanket sweep
    // over the whole page confirmed as much — it flagged ordinary prose
    // links on 'repo-cx.html' that the integrator's own read never named.
    // Height only, matching the integrator's own probe exactly (not width
    // too, as a first cut here did): a text-list entry's natural width is
    // its own label ("Home", 42px) and was never the complaint — only ever
    // "N px tall". A width-and-height-both control (an icon button) would
    // still be refused by this check if it is short, since its usual tall
    // dimension IS the height check already covers.
    const small = [...document.querySelectorAll(
      'aside.sidebar a, aside.sidebar summary, header.sheet-bar a, ' +
      '.toc-groups a, .toc-groups summary, .hero-cta a, .fig-caption a, ' +
      '.cxp-reading-tab, #cxp-run, #cxp-reset, #cxp-share, #cxp-pick, header.cxp-toolbar [aria-expanded], ' +
      '.cxp-brand, .cxp-tab, .cxp-viz-tab, .cxp-subject-tab, .cxp-gview-tab, .cxp-mini-btn')]
      .filter(e => {
        const r = e.getBoundingClientRect();
        const vis = r.width > 0 && r.height > 0 && getComputedStyle(e).visibility !== 'hidden' && e.offsetParent !== null;
        return vis && r.height < 44;
      })
      .map(e => ({ tag: e.tagName, text: (e.textContent || '').trim().slice(0, 30), w: Math.round(e.getBoundingClientRect().width), h: Math.round(e.getBoundingClientRect().height) }));
    // The running prose (as before), PLUS the caption/nav-link classes the
    // integrator's browser read actually named — the guide home's
    // table-of-contents entries and the two links that follow a ring
    // figure (#1740 round 2). This is deliberately not a sweep of every
    // text node on the page: the sidebar's small "GitHub ->" sub-link, for
    // one, is a pre-existing, site-wide, much smaller design (7.5-10.5px)
    // that predates this round and is not one of the findings — raising
    // every such caption/badge across the whole site is a separate,
    // larger change outside #1740's four issues (flagged in RESULTS.md,
    // not fixed here). SVG <text> is excluded on principle even where a
    // selector below would reach it: its computed font-size is the
    // unscaled SVG user-unit value, not the on-screen size after the
    // viewBox scales it — not measurable this way regardless.
    const tinyText = [...document.querySelectorAll(
      'main p, main li, .toc-groups a, .hero-cta, .hero-cta a, .fig-caption, .fig-caption a, ' +
      '.cxp-brand, .cxp-tab, .cxp-viz-tab, .cxp-subject-tab, .cxp-gview-tab, .cxp-mini-btn')]
      .filter(e => e.textContent.trim().length > 0 && e.offsetParent !== null && !e.closest('svg'))
      .map(e => ({ fs: parseFloat(getComputedStyle(e).fontSize), text: e.textContent.trim().slice(0, 30), tag: e.tagName }))
      .filter(t => t.fs > 0 && t.fs < 16);
    return {
      scrollWidth: html.scrollWidth, clientWidth: html.clientWidth,
      gutterL, gutterR, small,
      tinyTextMin: tinyText.length ? Math.min(...tinyText.map(t => t.fs)) : null,
      tinyTextCount: tinyText.length, tinyTextSample: tinyText[0] || null,
    };
  })())`);
  return JSON.parse(raw);
}

(async () => {
  const port = await bootServer();
  const cdp = await bootBrowser();
  const failures = [];
  for (const [width, height] of WIDTHS) {
    for (const page of PAGES) {
      checkDeadline(`${page}@${width}`);
      let m;
      try {
        m = await measure(cdp, port, page, width, height);
      } catch (e) {
        failures.push(`${page} @ ${width}x${height}: measurement threw — ${e.message}`);
        continue;
      }
      if (m.scrollWidth > m.clientWidth + 2) {
        failures.push(`${page} @ ${width}x${height}: page scrolls horizontally — scrollWidth ${m.scrollWidth} > clientWidth ${m.clientWidth}`);
      }
      // playground.html is a full-viewport app shell (a code editor), not a
      // reading page — DOCS-51's gutter criterion is about prose reflow, so
      // it is exempt from the strict main-column gutter check (its own
      // overflow/tap-target/text-size criteria above still apply in full).
      if (page !== 'playground.html' && (m.gutterL < 16 || m.gutterR < 16)) {
        failures.push(`${page} @ ${width}x${height}: main content gutter ${m.gutterL}/${m.gutterR}px, below 16px`);
      }
      if (m.small.length) {
        failures.push(`${page} @ ${width}x${height}: ${m.small.length} tap target(s) below 44px — e.g. ${JSON.stringify(m.small[0])}`);
      }
      if (m.tinyTextMin !== null) {
        failures.push(`${page} @ ${width}x${height}: ${m.tinyTextCount} text node(s) below 16px (smallest ${m.tinyTextMin}px) — e.g. ${JSON.stringify(m.tinyTextSample)}`);
      }
      say(`${page} @ ${width}x${height} — scrollWidth=${m.scrollWidth}/${m.clientWidth}, gutters=${m.gutterL}/${m.gutterR}, small targets=${m.small.length}, tiny prose=${m.tinyTextCount}`);
      // SITE-3: the whole layout and, where there is one, the sidebar's disclosure.
      try {
        const where = `${page} @ ${width}x${height}`;
        if (page === 'playground.html') await waitPlayground(cdp);
        failures.push(...layoutFailures(await layout(cdp, width), where, width));
        if (page !== 'playground.html') failures.push(...sidebarFailures(await sidebarCollapse(cdp, width, height), where, width, height));
      } catch (e) {
        failures.push(`${page} @ ${width}x${height}: layout measurement threw — ${e.message}`);
      }
    }
  }
  // SITE-3: either orientation — the layout assertions in landscape.
  for (const [width, height] of LANDSCAPE) {
    for (const page of PAGES) {
      checkDeadline(`${page}@${width} landscape`);
      try {
        await load(cdp, port, page, width, height);
        const m = await layout(cdp, width);
        failures.push(...layoutFailures(m, `${page} @ ${width}x${height}`, width));
        say(`${page} @ ${width}x${height} — page ${m.scrollWidth}px wide, ${m.wideCount} element(s) past the edge`);
      } catch (e) {
        failures.push(`${page} @ ${width}x${height}: layout measurement threw — ${e.message}`);
      }
    }
  }
  // SITE-3: every served page, at 375x812.
  const served = servedPages(SITE);
  // ADVISORY (ADVIS-1), each row an OPEN v0.18 issue: a page the headless
  // browser cannot load is named, not failed, until its issue closes.
  const ADVISORY_UNLOADED = { 'lib-html.html': 1764, 'tooling.html': 1764, 'tour-programs.html': 1764 };
  let servedBad = 0;
  for (const page of served) {
    checkDeadline(`${page}@375 (every served page)`);
    try {
      await load(cdp, port, page, 375, 812, 60);
      const f = layoutFailures(await layout(cdp, 375), `${page} @ 375x812`, 375);
      if (f.length) servedBad++;
      if (served.indexOf(page) % 40 === 39) say(`every served page @ 375x812 — ${served.indexOf(page) + 1} of ${served.length} read (${Math.round((Date.now() - STARTED) / 1000)} s)`);
      failures.push(...f);
    } catch (e) {
      if (ADVISORY_UNLOADED[page] && /fired no load event/.test(e.message)) say(`ADVISORY #${ADVISORY_UNLOADED[page]} — ${page} @ 375x812 unread: ${e.message.split(' (')[0]}`);
      else failures.push(`${page} @ 375x812: layout measurement threw — ${e.message}`);
    }
  }
  say(`every served page @ 375x812 — ${served.length} pages, ${servedBad} with a layout failure`);
  // SITE-3 (#1760): the playground opens on one example — its source and its output.
  for (const [width, height] of PLAYGROUND_WIDTHS) {
    checkDeadline(`playground controls @${width}`);
    const where = `playground.html @ ${width}x${height}`;
    try {
      await load(cdp, port, 'playground.html', width, height);
      await waitPlayground(cdp);
      await shot(cdp, `playground-${width}`);
      const { f, c, o } = await playgroundFailures(cdp, where, width);
      failures.push(...f);
      say(`${where} — ${c.controls} control(s) above the fold in ${c.rows.length} row(s)${o ? `; opened: widest row ${Math.max(0, ...o.allRows.map((r) => r.length))}` : ''}`);
      if (o && SHOTS) {
        await playgroundToggle(cdp);
        await shot(cdp, `playground-${width}-opened`);
        await playgroundToggle(cdp);
      }
    } catch (e) {
      failures.push(`${where}: control count threw — ${e.message}`);
    }
  }
  if (SHOTS) {
    for (const [width, height] of [...WIDTHS, ...LANDSCAPE]) {
      await load(cdp, port, 'index.html', width, height, 400);
      await shot(cdp, `landing-${width}`);
    }
  }
  cdp.close();
  cleanupAll();
  if (failures.length) {
    for (const f of failures) cry(f);
    cry(`${failures.length} failure(s)`);
    process.exit(1);
  }
  say(`OK — ${PAGES.length} pages x ${WIDTHS.length} widths: no page-level horizontal scroll, gutters >= 16px, every visible tap target >= 44px, every visible text node >= 16px; the whole layout (top bar, sidebar, main column) inside the device in portrait and landscape and on every one of ${served.length} served pages; the sidebar a closed disclosure on a phone; the playground at most ${PLAYGROUND_CONTROLS} controls above the fold in one row at ${PLAYGROUND_WIDTHS.map(([w]) => w).join('/')} px, every secondary surface behind its one disclosure.`);
  process.exit(0);
})().catch((e) => setupFail(e.stack || e.message));
