// scripts/playground-gate/browser_harness.mjs — the ONE browser harness the
// playground's browser-driven gates share (#1033, #1049).
//
// WHY THIS FILE EXISTS. #1033 established the pattern: to measure what a
// READER gets, drive the real staged bundle in a real Chromium over CDP.
// #1049 needs exactly the same rig for a different assertion (the Tree
// pane's rendering). Copying #1033's ~200 lines of boot into a second
// script would give the playground TWO harnesses that agree today and
// drift tomorrow — a second Chrome flag set, a second readiness rule, a
// second idea of which wasm bundle counts. So the boot is factored here
// and both gates import it. A change to how the page is reached lands on
// both gates at once or on neither.
//
// WHAT IT DOES NOT DECIDE. This module gets a caller to a booted page with
// a ready cxlib and a JSPI engine, and reaps everything on the way out.
// What to ASSERT once there is entirely the caller's business — there is
// no shared notion of pass/fail here, deliberately.
//
// BOUNDED (the #988 rule). Every wait has a bound: a whole-run deadline
// the caller sets, a per-CDP-call timeout, and a bounded wait for both the
// static server and Chrome's debugging port. The server and the browser are
// reaped on every exit path — pass, fail, or signal. A gate that hangs is
// worse than a gate that fails.
//
// Overrides honoured: CX_CHROME=<Chromium-family browser>, CX_BIN=<native cx>.

import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';

export const ROOT = resolve(import.meta.dirname, '../..');
export const PLAYGROUND = resolve(ROOT, 'scripts/gen_guide/playground');
export const PREVIEW = resolve(ROOT, 'dist/playground-preview');
export const NATIVE = process.env.CX_BIN
  ? resolve(process.env.CX_BIN) : resolve(ROOT, 'deps/cx-core-code/vcx/target/cx');

// Chromium-family candidates. CX_CHROME wins; otherwise the usual install
// locations. A missing browser is a LOUD setup failure — these gates have
// no weaker engine to fall back to (node exposes no JSPI under any flag,
// measured on v22.22.2; see test_playground_wasm_eval.mjs's header for the
// measurement and what it cost).
const CHROME_CANDIDATES = [
  process.env.CX_CHROME,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
  '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser',
].filter(Boolean);

// createHarness — one per gate process. `label` prefixes every line this
// module prints so a combined log says which gate spoke; `deadlineMs`
// bounds the whole run from the moment this is called.
export function createHarness({ label, deadlineMs }) {
  const STARTED = Date.now();
  let server = null, browser = null, profileDir = null;
  const extraTmp = [];

  function cleanup() {
    for (const p of [server, browser]) {
      if (p && p.pid && p.exitCode === null) {
        try { p.kill('SIGKILL'); } catch (_) {}
      }
    }
    for (const d of [profileDir, ...extraTmp]) {
      if (d) { try { rmSync(d, { recursive: true, force: true }); } catch (_) {} }
    }
  }
  process.on('exit', cleanup);
  for (const sig of ['SIGINT', 'SIGTERM']) {
    process.on(sig, () => { cleanup(); process.exit(130); });
  }

  // A setup problem is exit 2, never a skip and never a pass: a gate that
  // cannot reach the thing it measures must say so loudly.
  function setupFail(msg, hint) {
    console.error(`\n[${label}] SETUP FAILURE: ${msg}`);
    if (hint) console.error(`[${label}]   → ${hint}`);
    cleanup();
    process.exit(2);
  }

  function checkDeadline(where) {
    if (Date.now() - STARTED > deadlineMs) {
      console.error(`\n[${label}] DEADLINE: exceeded ${deadlineMs / 1000}s at ${where}`);
      cleanup();
      process.exit(1);
    }
  }

  // mkTmp — a temp dir this harness reaps with everything else.
  function mkTmp(prefix) {
    const d = mkdtempSync(join(tmpdir(), prefix));
    extraTmp.push(d);
    return d;
  }

  // ── preconditions (all loud) ─────────────────────────────────
  function requirePreconditions({ needNative = true, root = PREVIEW } = {}) {
    if (!existsSync(join(root, 'playground.html'))) {
      setupFail(`${root}/playground.html is not staged.`, 'make build-playground (or make site for site/)');
    }
    if (!existsSync(join(root, 'wasm/libcx-async.js'))) {
      setupFail(`the JSPI bundle ${root}/wasm/libcx-async.js is missing.`,
                'make build-playground');
    }
    if (needNative && !existsSync(NATIVE)) {
      setupFail(`the native reference binary is missing: ${NATIVE}`, 'make build-vcx-dev');
    }
    const chrome = CHROME_CANDIDATES.find(existsSync);
    if (!chrome) {
      setupFail('no Chromium-family browser found — this gate needs one (node has no JSPI).',
                'install Chrome/Chromium, or set CX_CHROME=<path>');
    }
    return chrome;
  }

  // ── the static server ──────────────────────────────────────
  // The page is served over HTTP rather than opened as file:// because a
  // headless browser's file:// origin rules vary by version; the BUNDLE
  // selection is what matters and it is identical (cxlib picks libcx-async
  // unless crossOriginIsolated + SharedArrayBuffer are present, which
  // neither file:// nor this plain server provides). Callers assert the
  // JSPI bundle loaded, so this choice cannot silently change the engine.
  //
  // `portBase` is per-gate so two of these can run side by side.
  async function bootServer({ portBase, verbose = false, root = PREVIEW }) {
    const candidates = [];
    const base = portBase + (process.pid % 200);
    for (let i = 0; i < 5; i++) candidates.push(base + i);
    for (const port of candidates) {
      checkDeadline('server boot');
      const p = spawn(NATIVE, [
        '--allow-read', '--allow-net', '--allow-clock',
        resolve(ROOT, 'scripts/serve_static.cx'),
        '--port', String(port), '--root', root,
      ], { cwd: ROOT, stdio: ['ignore', 'pipe', 'pipe'] });
      let stderr = '';
      p.stderr.on('data', d => { stderr += String(d); });
      // serve_static.cx exits rc 1 fast on a busy port, so a failed boot IS
      // the busy check (the same contract test_playground_smoke.sh relies on).
      const up = await new Promise(res => {
        let settled = false;
        p.once('exit', () => { if (!settled) { settled = true; res(false); } });
        (async () => {
          for (let i = 0; i < 80; i++) {
            await new Promise(r => setTimeout(r, 125));
            if (settled) return;
            try {
              const r = await fetch(`http://127.0.0.1:${port}/playground.html`,
                                    { signal: AbortSignal.timeout(2000) });
              if (r.ok) { settled = true; return res(true); }
            } catch (_) { /* not yet */ }
          }
          if (!settled) { settled = true; res(false); }
        })();
      });
      if (up) { server = p; return port; }
      try { p.kill('SIGKILL'); } catch (_) {}
      if (stderr && verbose) console.log(`[server] port ${port}: ${stderr.trim().split('\n')[0]}`);
    }
    setupFail('could not boot scripts/serve_static.cx on any candidate port.',
              'is another copy of this gate running?');
  }

  // ── the browser + CDP ──────────────────────────────────────
  async function bootBrowser(pageUrl, { chrome, cdpBase }) {
    const cdpPort = cdpBase + (process.pid % 300);
    profileDir = mkdtempSync(join(tmpdir(), 'cx-pg-gate-profile-'));
    browser = spawn(chrome, [
      `--remote-debugging-port=${cdpPort}`,
      '--headless=new', '--no-first-run', '--no-default-browser-check',
      '--disable-gpu', '--disable-dev-shm-usage',
      `--user-data-dir=${profileDir}`,
      'about:blank',
    ], { stdio: ['ignore', 'pipe', 'pipe'] });

    let version = null;
    for (let i = 0; i < 160; i++) {
      checkDeadline('browser boot');
      if (browser.exitCode !== null) {
        setupFail(`the browser exited (code ${browser.exitCode}) before its debugging port opened.`);
      }
      await new Promise(r => setTimeout(r, 250));
      try {
        const r = await fetch(`http://127.0.0.1:${cdpPort}/json/version`,
                              { signal: AbortSignal.timeout(2000) });
        if (r.ok) { version = await r.json(); break; }
      } catch (_) { /* not yet */ }
    }
    if (!version) setupFail(`the browser's CDP port ${cdpPort} never opened.`);

    const tabRes = await fetch(
      `http://127.0.0.1:${cdpPort}/json/new?${encodeURI(pageUrl)}`,
      { method: 'PUT', signal: AbortSignal.timeout(15000) });
    if (!tabRes.ok) setupFail(`CDP refused to open a tab: HTTP ${tabRes.status}`);
    const tab = await tabRes.json();

    const ws = new WebSocket(tab.webSocketDebuggerUrl);
    let msgId = 0;
    const pending = new Map();
    ws.addEventListener('message', ev => {
      const m = JSON.parse(ev.data);
      if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
    });
    const opened = await new Promise(res => {
      const t = setTimeout(() => res(false), 20000);
      ws.addEventListener('open', () => { clearTimeout(t); res(true); }, { once: true });
      ws.addEventListener('error', () => { clearTimeout(t); res(false); }, { once: true });
    });
    if (!opened) setupFail('could not open the CDP websocket to the page.');

    function send(method, params, timeoutMs = 60000) {
      const id = ++msgId;
      return new Promise((res, rej) => {
        const t = setTimeout(() => { pending.delete(id); rej(new Error(`CDP ${method} timed out`)); }, timeoutMs);
        pending.set(id, m => { clearTimeout(t); res(m); });
        ws.send(JSON.stringify({ id, method, params }));
      });
    }
    async function evalJs(expression, timeoutMs = 60000) {
      const r = await send('Runtime.evaluate',
        { expression, awaitPromise: true, returnByValue: true, timeout: timeoutMs - 2000 },
        timeoutMs);
      if (r.error) throw new Error(`CDP error: ${JSON.stringify(r.error).slice(0, 300)}`);
      const res = r.result || {};
      if (res.exceptionDetails) {
        throw new Error(`page threw: ${JSON.stringify(res.exceptionDetails).slice(0, 300)}`);
      }
      return res.result ? res.result.value : undefined;
    }
    return { evalJs, version, close: () => { try { ws.close(); } catch (_) {} } };
  }

  // bootPage — the whole rig in one call: preconditions, static server,
  // headless Chrome, a tab on playground.html, cxlib ready, and the ENGINE
  // ASSERTED. A non-JSPI bundle is a setup failure, never a quiet downgrade
  // to the weaker engine whose verdicts are known to be wrong.
  async function bootPage({ portBase, cdpBase, needNative = true, verbose = false, root = PREVIEW }) {
    const chrome = requirePreconditions({ needNative, root });
    const port = await bootServer({ portBase, verbose, root });
    const pageUrl = `http://127.0.0.1:${port}/playground.html`;
    const { evalJs, version, close } = await bootBrowser(pageUrl, { chrome, cdpBase });
    console.log(`[${label}] browser: ${version['Browser']}`);
    console.log(`[${label}] page:    ${pageUrl}`);

    // Wait for the page's own cxlib to finish booting.
    let ready = '';
    for (let i = 0; i < 200; i++) {
      checkDeadline('cxlib boot');
      try {
        ready = await evalJs(`(async () => {
          if (!globalThis.cxlib) return 'no-cxlib';
          try { await cxlib.ready; } catch (e) { return 'ready-threw:' + (e && e.message); }
          return 'ready';
        })()`, 30000);
      } catch (e) { ready = `cdp:${e.message}`; }
      if (ready === 'ready') break;
      await new Promise(r => setTimeout(r, 500));
    }
    if (ready !== 'ready') setupFail(`the page's cxlib never became ready (${ready}).`);

    const engine = JSON.parse(await evalJs(`JSON.stringify({
      scripts: [...document.scripts].map(s => s.src).filter(s => /libcx/.test(s)),
      suspending: typeof WebAssembly.Suspending,
    })`, 30000));
    const bundle = (engine.scripts || []).join(' ');
    if (!/libcx-(async|pthreads)\.js/.test(bundle)) {
      setupFail(`the page loaded a NON-JSPI bundle (${bundle || 'none'}).`,
                'this gate must measure the engine the reader gets; see test_playground_wasm_eval.mjs');
    }
    if (engine.suspending !== 'function') {
      setupFail('WebAssembly.Suspending is unavailable in this browser — it cannot run the JSPI bundle.',
                'use a newer Chromium-family browser, or set CX_CHROME');
    }
    console.log(`[${label}] engine:  ${bundle.replace(/^.*\//, '')} (JSPI)`);
    return { evalJs, version, close, pageUrl, bundle };
  }

  return { setupFail, checkDeadline, cleanup, mkTmp, bootPage, bootServer, bootBrowser,
           requirePreconditions, startedAt: STARTED };
}

// loadExamples — the playground corpus, evaluated the way the page loads it
// (one script defining `window.cxPlaygroundExamples`). Shared so both gates
// read the SAME corpus by the same route.
export function loadExamples(readFileSync, setupFail) {
  const src = readFileSync(resolve(PLAYGROUND, 'playground.examples.js'), 'utf8');
  const fakeWindow = {};
  try {
    new Function('window', 'globalThis', src)(fakeWindow, fakeWindow);
  } catch (e) {
    setupFail(`could not evaluate playground.examples.js: ${e.message}`);
  }
  const program = (fakeWindow.cxPlaygroundExamples || {}).program || {};
  if (Object.keys(program).length === 0) {
    setupFail('playground.examples.js yielded no examples.');
  }
  return program;
}
