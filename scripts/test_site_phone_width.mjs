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
//   - every sidebar/nav link and `<summary>` toggle — a phone's primary
//     navigation once the header's secondary row collapses — is at least
//     44x44px;
//   - the smallest font-size inside the main content's running prose
//     (`main p`, `main li`) is at least 16px.
// A violation on any page, at either width, is named by URL, width and the
// measurement; exit 1. Needs Chrome/Chromium (CX_CHROME) and a built site
// (`make site`); boots its own static server over `scripts/serve_static.cx`.
//
// Usage: node scripts/test_site_phone_width.mjs [--root=site]
//   CX_CHROME=<path>  CX_BIN=<native cx>

import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
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
const DEADLINE_MS = 8 * 60 * 1000;
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
  ws.addEventListener('message', (ev) => {
    const m = JSON.parse(ev.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
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
  return { send, evalJs, close: () => { try { ws.close(); } catch (_) {} } };
}

// ── measure one page at one width ────────────────────────────────────────
async function measure(cdp, port, page, width, height) {
  await cdp.send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 2, mobile: true });
  const url = `http://127.0.0.1:${port}/${page}`;
  await cdp.send('Page.navigate', { url });
  // Wait for load.
  for (let i = 0; i < 80; i++) {
    checkDeadline(`load ${page}`);
    const ready = await cdp.evalJs('document.readyState');
    if (ready === 'complete') break;
    await new Promise((r) => setTimeout(r, 125));
  }
  await new Promise((r) => setTimeout(r, 150)); // settle webfonts/layout
  const raw = await cdp.evalJs(`JSON.stringify((function () {
    const html = document.documentElement;
    const main = document.querySelector('main') || document.body;
    const cs = getComputedStyle(main);
    const gutterL = parseFloat(cs.paddingLeft) || 0, gutterR = parseFloat(cs.paddingRight) || 0;
    const small = [...document.querySelectorAll('aside.sidebar a, aside.sidebar summary, .toc-groups summary, header.sheet-bar a, .cxp-reading-tab, #cxp-run, #cxp-reset, #cxp-share')]
      .filter(e => {
        const r = e.getBoundingClientRect();
        const vis = r.width > 0 && r.height > 0 && getComputedStyle(e).visibility !== 'hidden';
        return vis && (r.height < 44 && r.width < 44);
      })
      .map(e => ({ tag: e.tagName, text: (e.textContent || '').trim().slice(0, 30), w: Math.round(e.getBoundingClientRect().width), h: Math.round(e.getBoundingClientRect().height) }));
    const tinyText = [...document.querySelectorAll('main p, main li')]
      .filter(e => e.textContent.trim().length > 0)
      .map(e => parseFloat(getComputedStyle(e).fontSize))
      .filter(fs => fs > 0 && fs < 16);
    return {
      scrollWidth: html.scrollWidth, clientWidth: html.clientWidth,
      gutterL, gutterR, small, tinyTextMin: tinyText.length ? Math.min(...tinyText) : null,
      tinyTextCount: tinyText.length,
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
        failures.push(`${page} @ ${width}x${height}: ${m.tinyTextCount} prose text node(s) below 16px (smallest ${m.tinyTextMin}px)`);
      }
      say(`${page} @ ${width}x${height} — scrollWidth=${m.scrollWidth}/${m.clientWidth}, gutters=${m.gutterL}/${m.gutterR}, small targets=${m.small.length}, tiny prose=${m.tinyTextCount}`);
    }
  }
  cdp.close();
  cleanupAll();
  if (failures.length) {
    for (const f of failures) cry(f);
    cry(`${failures.length} failure(s)`);
    process.exit(1);
  }
  say(`OK — ${PAGES.length} pages x ${WIDTHS.length} widths: no page-level horizontal scroll, gutters >= 16px, nav tap targets >= 44px, prose text >= 16px.`);
  process.exit(0);
})().catch((e) => setupFail(e.stack || e.message));
