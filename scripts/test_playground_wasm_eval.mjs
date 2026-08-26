// scripts/test_playground_wasm_eval.mjs — the playground WASM EVALUATION
// sweep (#1033).
//
// WHAT IT ASSERTS. Every example in the playground corpus, evaluated in
// the SHIPPED wasm engine as a READER GETS IT, either
//
//   (a) produces the same value the native reference implementation
//       produces for the same source under the same (zero) grants, or
//   (b) is EXPLICITLY marked wasm-unsupported in the corpus, with a
//       reason the page shows the reader.
//
// Nothing else is green. In particular a marker that is not JUSTIFIED —
// an example marked wasm-unsupported that in fact evaluates correctly
// here — is a FAILURE, not a pass. Without that rule the gate could be
// defeated by marking the corpus wholesale, which is exactly the
// green-by-construction this lane exists to prevent.
//
// WHY IT EXISTS. `make verify-playground-examples` replays all 182
// examples through NATIVE cx; `make test-playground-mermaid` checks that
// the DIAGRAMS parse. Neither evaluates the corpus in the engine the
// reader gets. The mermaid gate comes closest — it calls evalCode to
// obtain its `output` subject — but it deliberately swallows the result:
//
//     try { output = String(cxlib.evalCode(source, 'cx') || ''); }
//     catch (_) { output = ''; }
//
// turning "this example refuses in the browser" into "this example has
// no output subject", counted as a SKIP. So wasm-refusing examples
// shipped green through two release cuts and the owner found them the
// way readers do: by clicking one (#1033).
//
// ── WHY A REAL BROWSER, AND NOT NODE ─────────────────────────────────
//
// This was MEASURED, not assumed, and the measurement is the reason this
// harness costs what it costs.
//
// The cheap harness is node: the #992/#1007 mermaid gate already drives
// a bundle that way. But node cannot run the bundle the page loads.
// libcx-async / libcx-pthreads are JSPI builds (-sASYNCIFY=2, #930);
// they call `new WebAssembly.Suspending(...)` at instantiation and abort
// under node, so a node harness must fall back to libcx-sync. Node 22
// exposes no JSPI at all — `WebAssembly.Suspending` is undefined with
// --experimental-wasm-jspi AND --experimental-wasm-stack-switching
// (both measured on v22.22.2).
//
// And the two bundles DISAGREE about this corpus. Measured, same tree:
//
//   example                 libcx-sync (node)   libcx-async (Chrome)
//   42-for-yield-par        REFUSED             evaluates
//   44-for-yield-stream     REFUSED             evaluates
//   50-map-par-wall         REFUSED             evaluates
//   82-sleep-wall           REFUSED             evaluates
//   89-worker-basic         REFUSED             REFUSED
//   172-seq-…-backpressure  REFUSED             REFUSED
//
// A node/sync harness reports 18 refusals; the reader's engine has 10.
// It would therefore have demanded a wasm-unsupported marker on 8
// examples that work perfectly on the page — and the page would then
// have told readers a banner's worth of lies about working code. A
// cheaper harness that produces false markers is not the cheaper honest
// harness; it is a cheaper dishonest one. So this sweep drives Chrome.
//
// It asserts the engine it got: if the page ever loads a NON-JSPI
// bundle here, that is a setup failure, never a quiet downgrade to the
// weaker engine whose verdicts we know to be wrong.
//
// WHAT IT DOES NOT COVER, STATED. cxlib picks `libcx-pthreads` when
// crossOriginIsolated + SharedArrayBuffer are available (COOP/COEP, i.e.
// `make guide-http`) and `libcx-async` otherwise — file://, GitHub
// Pages, generic HTTP. This sweep measures the ASYNC path, which is what
// the published playground and a local file:// reader actually get. Real
// OS threads under pthreads are a second configuration; several
// examples' own notes already promise different behavior there, and this
// lane does not speak for it.
//
// THE EXPECTATION IS DERIVED, NOT SNAPSHOTTED. The reference value comes
// from spawning THIS TREE's `cx` on the same source with zero grants —
// the same grant-free isolated child gen_examples.cx's audit uses,
// mirroring the sandbox. A committed 182-entry expectation file would be
// one more artifact to drift; deriving it means the gate asserts the
// property that matters (wasm ≡ native) and cannot go stale.
//
// BOUNDED (the #988 rule). Every wait has a bound: a whole-run deadline,
// a per-evaluation CDP timeout, a bounded native child, and a bounded
// wait for Chrome's debugging port. The static server and the browser are
// reaped on every exit path — pass, fail, or signal. A gate that hangs is
// worse than a gate that fails.
//
// USAGE
//   make build-playground                  (stages dist/playground-preview)
//   node scripts/test_playground_wasm_eval.mjs [--verbose] [--limit N]
//
// Overrides: CX_CHROME=<path to a Chromium-family browser>,
// CX_BIN=<native cx>, WASM_EVAL_DEADLINE=<seconds>.
//
// Exit 0 when every example evaluates or is justifiably marked; 1 on any
// failure; 2 on a setup problem — never a silent skip.

import { readFileSync, writeFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const ROOT = resolve(import.meta.dirname, '..');
const VERBOSE = process.argv.includes('--verbose');
const LIMIT_IX = process.argv.indexOf('--limit');
const LIMIT = LIMIT_IX >= 0 ? parseInt(process.argv[LIMIT_IX + 1], 10) : Infinity;

const PLAYGROUND = resolve(ROOT, 'scripts/gen_guide/playground');
const PREVIEW = resolve(ROOT, 'dist/playground-preview');
const NATIVE = process.env.CX_BIN
  ? resolve(process.env.CX_BIN) : resolve(ROOT, 'vcx/target/cx');
const DEADLINE_MS = (parseInt(process.env.WASM_EVAL_DEADLINE || '900', 10)) * 1000;
const STARTED = Date.now();

// Chromium-family candidates. CX_CHROME wins; otherwise the usual
// install locations. A missing browser is a LOUD setup failure — this
// gate has no weaker engine to fall back to (see the header).
const CHROME_CANDIDATES = [
  process.env.CX_CHROME,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
  '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser',
].filter(Boolean);

let server = null, browser = null, profileDir = null, tmpDir = null;

function cleanup() {
  for (const p of [server, browser]) {
    if (p && p.pid && p.exitCode === null) {
      try { p.kill('SIGKILL'); } catch (_) {}
    }
  }
  for (const d of [profileDir, tmpDir]) {
    if (d) { try { rmSync(d, { recursive: true, force: true }); } catch (_) {} }
  }
}
process.on('exit', cleanup);
for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => { cleanup(); process.exit(130); });
}

function setupFail(msg, hint) {
  console.error(`\n[playground-wasm-eval] SETUP FAILURE: ${msg}`);
  if (hint) console.error(`[playground-wasm-eval]   → ${hint}`);
  cleanup();
  process.exit(2);
}

function checkDeadline(where) {
  if (Date.now() - STARTED > DEADLINE_MS) {
    console.error(`\n[playground-wasm-eval] DEADLINE: exceeded ${DEADLINE_MS / 1000}s at ${where}`);
    cleanup();
    process.exit(1);
  }
}

// ── preconditions (all loud) ───────────────────────────────────
if (!existsSync(join(PREVIEW, 'playground.html'))) {
  setupFail('dist/playground-preview/ is not staged.', 'make build-playground');
}
if (!existsSync(join(PREVIEW, 'wasm/libcx-async.js'))) {
  setupFail('the JSPI bundle dist/playground-preview/wasm/libcx-async.js is missing.',
            'make build-playground');
}
if (!existsSync(NATIVE)) {
  setupFail(`the native reference binary is missing: ${NATIVE}`, 'make build-vcx-dev');
}
const CHROME = CHROME_CANDIDATES.find(existsSync);
if (!CHROME) {
  setupFail('no Chromium-family browser found — this gate needs one (node has no JSPI).',
            'install Chrome/Chromium, or set CX_CHROME=<path>');
}

// ── the corpus ─────────────────────────────────────────────────
function loadExamples() {
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

// wasmMarker — the corpus's explicit wasm-unsupported marker, or ''.
//
// `wasmUnsupported` is the field of record (#1033): a REASON string, so
// the page can tell the reader WHY rather than showing an engine error or
// a quietly wrong answer. It covers BOTH ways the engine can fail to
// reproduce native — an outright refusal (the [?worker]/[?async] class)
// and a real value divergence (example 57: a [?bulkhead] never saturates
// when [par] is sequential). It rides from examples.cxd through
// gen_examples.cx, so a corpus regeneration preserves it.
//
// `runnable: false` is the OLDER, narrower marker — the generator derives
// it from a CXER0271 in the grant-free native audit, i.e. "needs net /
// subprocess / fs". Those examples DO evaluate in wasm: they return a
// capability-denied `[err …]` value, and native under the same zero
// grants returns the same, so they MATCH and are not treated as marked
// here. Only a genuine engine refusal or a real value divergence needs
// `wasmUnsupported`.
function wasmMarker(ex) {
  const m = ex.wasmUnsupported;
  return (typeof m === 'string' && m.trim()) ? m.trim() : '';
}

// noStableValue — the THIRD state, and not a softer spelling of the
// second. The example has NO single expected value to compare against
// because its native result is a RACE, so a wasm≡native assertion on it
// is not a test, it is a coin flip.
//
// Measured on the one example that needs it (57-map-par-bulkhead: a
// 2-slot `[?bulkhead]` over 8 `[par]` items): 10 DISTINCT native results
// in 12 runs, from zero saturation errs to six — and one of those runs
// happened to equal the wasm result exactly. That is not hypothetical
// flakiness: this gate flipped between "justified marker" and "stale
// marker" on consecutive runs before the state existed.
//
// What the sweep asserts for these is the weaker but TRUE property: the
// example must still EVALUATE in the wasm engine. A refusal is a
// different defect and does not get to hide behind this marker. Marked
// examples are listed in the summary so the set cannot grow unnoticed.
function noStableValue(ex) {
  const m = ex.noStableValue;
  return (typeof m === 'string' && m.trim()) ? m.trim() : '';
}

// ── the static server ──────────────────────────────────────────
// The page is served over HTTP rather than opened as file:// because a
// headless browser's file:// origin rules vary by version; the BUNDLE
// selection is what matters and it is identical (cxlib picks libcx-async
// unless crossOriginIsolated + SAB are present, which neither file:// nor
// this plain server provides). The gate asserts the JSPI bundle loaded,
// so this choice cannot silently change the engine under test.
function freePortCandidates() {
  const base = 8790 + (process.pid % 200);
  return [base, base + 1, base + 2, base + 3, base + 4];
}

async function bootServer() {
  for (const port of freePortCandidates()) {
    checkDeadline('server boot');
    const p = spawn(NATIVE, [
      '--allow-read', '--allow-net', '--allow-clock',
      resolve(ROOT, 'scripts/serve_static.cx'),
      '--port', String(port), '--root', PREVIEW,
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
    if (stderr && VERBOSE) console.log(`[server] port ${port}: ${stderr.trim().split('\n')[0]}`);
  }
  setupFail('could not boot scripts/serve_static.cx on any candidate port.',
            'is another copy of this gate running?');
}

// ── the browser + CDP ──────────────────────────────────────────
async function bootBrowser(pageUrl) {
  const cdpPort = 9330 + (process.pid % 300);
  profileDir = mkdtempSync(join(tmpdir(), 'cx-wasm-eval-profile-'));
  browser = spawn(CHROME, [
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

// ── run ────────────────────────────────────────────────────────
const program = loadExamples();
const keys = Object.keys(program).slice(0, LIMIT);

const port = await bootServer();
const pageUrl = `http://127.0.0.1:${port}/playground.html`;
const { evalJs, version, close } = await bootBrowser(pageUrl);
console.log(`[playground-wasm-eval] browser: ${version['Browser']}`);
console.log(`[playground-wasm-eval] page:    ${pageUrl}`);

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

// ASSERT THE ENGINE. A non-JSPI bundle here means the gate is measuring
// the weaker engine whose verdicts are known to be wrong (see header) —
// a setup failure, never a quiet downgrade.
const engine = JSON.parse(await evalJs(`JSON.stringify({
  scripts: [...document.scripts].map(s => s.src).filter(s => /libcx/.test(s)),
  suspending: typeof WebAssembly.Suspending,
  mode: (cxlib.mode && cxlib.mode()) || (cxlib.info && cxlib.info().mode) || '',
})`, 30000));
const bundle = (engine.scripts || []).join(' ');
if (!/libcx-(async|pthreads)\.js/.test(bundle)) {
  setupFail(`the page loaded a NON-JSPI bundle (${bundle || 'none'}).`,
            'this gate must measure the engine the reader gets; see the header');
}
if (engine.suspending !== 'function') {
  setupFail('WebAssembly.Suspending is unavailable in this browser — it cannot run the JSPI bundle.',
            'use a newer Chromium-family browser, or set CX_CHROME');
}
console.log(`[playground-wasm-eval] engine:  ${bundle.replace(/^.*\//, '')} (JSPI)`);
console.log(`[playground-wasm-eval] examples: ${keys.length}\n`);

tmpDir = mkdtempSync(join(tmpdir(), 'cx-wasm-eval-'));
const TMP_CX = join(tmpDir, 'example.cx');

// nativeEval — the reference value: THIS tree's cx, zero grants, one
// isolated bounded child, as gen_examples.cx's audit runs it (and as the
// sandbox constrains the page). `cx <file>`, never `cx eval`.
function nativeEval(source) {
  writeFileSync(TMP_CX, source);
  const r = spawnSync(NATIVE, [TMP_CX], {
    cwd: ROOT, encoding: 'utf8', timeout: 20000,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  return {
    out: (r.stdout || '').trim(),
    err: (r.stderr || '').trim(),
    timedOut: !!(r.error && r.error.code === 'ETIMEDOUT'),
  };
}

const norm = s => String(s == null ? '' : s).trim();
const SEP = '';

let ok = 0, marked = 0, unstable = 0, fail = 0;
const markedRows = [], unstableRows = [], failRows = [];

for (const key of keys) {
  checkDeadline(`example ${key}`);
  const ex = program[key];
  const source = String(ex.input || '');
  const marker = wasmMarker(ex);
  const unstableNote = noStableValue(ex);

  // Evaluate in the page, through the page's own cxlib, grant-free —
  // the exact call the Run handler makes. reset() reclaims the arena
  // between examples so a late example fails on its own merits.
  let raw;
  try {
    raw = await evalJs(`(async () => {
      try { if (typeof cxlib.reset === 'function') cxlib.reset(); } catch (e) {}
      try {
        const out = (typeof cxlib.evalCodeAsync === 'function')
          ? await cxlib.evalCodeAsync(${JSON.stringify(source)}, 'cx', '')
          : cxlib.evalCode(${JSON.stringify(source)}, 'cx', '');
        return 'OK${SEP}' + String(out == null ? '' : out);
      } catch (e) { return 'THREW${SEP}' + ((e && e.message) || String(e)); }
    })()`, 60000);
  } catch (e) {
    // The harness itself lost the page. That is a failure of the run,
    // not a verdict about the example — say so and stop guessing.
    fail++;
    failRows.push({ key, why: 'the harness lost the page while evaluating this example.',
                    detail: e.message });
    console.log(`FAIL    ${key}\n        harness/CDP: ${e.message}`);
    continue;
  }

  const cut = String(raw).indexOf(SEP);
  const verdict = cut < 0 ? 'THREW' : String(raw).slice(0, cut);
  const body = cut < 0 ? String(raw) : String(raw).slice(cut + 1);

  if (verdict === 'THREW') {
    const detail = norm(body).split('\n').slice(0, 2).join(' | ');
    if (marker) {
      marked++;
      markedRows.push({ key, marker, detail: `refused: ${detail}` });
      if (VERBOSE) console.log(`MARKED  ${key}  (refused: ${detail})`);
    } else {
      fail++;
      failRows.push({
        key,
        why: 'REFUSED in the shipped wasm engine and NOT marked wasm-unsupported.',
        detail: `engine: ${detail}`,
      });
      console.log(`FAIL    ${key}\n        refused, unmarked: ${detail}`);
    }
    continue;
  }

  // Evaluated. If the example has no stable value, that is all this lane
  // can honestly assert — do not derive an expectation it would only be
  // comparing against luck.
  if (unstableNote) {
    unstable++;
    unstableRows.push({ key, note: unstableNote, detail: norm(body).slice(0, 160) });
    if (VERBOSE) console.log(`UNSTABLE ${key}  (evaluated; value not compared)`);
    continue;
  }

  const ref = nativeEval(source);
  if (ref.timedOut) {
    fail++;
    failRows.push({
      key, why: 'the NATIVE reference run timed out — no expectation could be derived.',
      detail: 'a corpus/engine problem, not a wasm one; verify-playground-examples owns it',
    });
    console.log(`FAIL    ${key}\n        native reference timed out`);
    continue;
  }
  const expectation = ref.out || ref.err;

  if (norm(body) === norm(expectation)) {
    if (marker) {
      // STALE MARKER. Telling a reader "unsupported" about code that
      // works is a lie the page would repeat, and blanket marking is how
      // a gate like this gets defeated.
      fail++;
      failRows.push({
        key, why: 'STALE MARKER — marked wasm-unsupported, but it evaluates here and matches native.',
        detail: `take the marker off in examples.cxd (reason on file: ${marker})`,
      });
      console.log(`FAIL    ${key}\n        stale wasm-unsupported marker: it works here`);
    } else {
      ok++;
      if (VERBOSE) console.log(`OK      ${key}`);
    }
    continue;
  }

  const detail = `wasm:   ${JSON.stringify(norm(body).slice(0, 220))}\n      `
               + `native: ${JSON.stringify(norm(expectation).slice(0, 220))}`;
  if (marker) {
    marked++;
    markedRows.push({ key, marker, detail: `diverges from native — ${detail}` });
    if (VERBOSE) console.log(`MARKED  ${key}  (diverges from native)`);
  } else {
    fail++;
    failRows.push({
      key, why: 'wasm evaluated to a DIFFERENT value than native cx, and is NOT marked.',
      detail,
    });
    console.log(`FAIL    ${key}\n        ${detail}`);
  }
}

close();

if (markedRows.length) {
  console.log('\n=== marked wasm-unsupported (justified) ===');
  for (const r of markedRows) {
    console.log(`  ${r.key}\n      reason: ${r.marker}\n      engine: ${r.detail}`);
  }
}
if (unstableRows.length) {
  console.log('\n=== marked no-stable-value (evaluated; value NOT compared) ===');
  for (const r of unstableRows) {
    console.log(`  ${r.key}\n      reason: ${r.note}\n      wasm:   ${r.detail}`);
  }
}
if (failRows.length) {
  console.log('\n=== FAILURES ===');
  for (const r of failRows) console.log(`  ${r.key}\n      ${r.why}\n      ${r.detail}`);
}

console.log('\n══════════════════════════════════════════════════════════');
console.log('playground wasm evaluation sweep — TOTAL');
console.log(`  examples                ${keys.length}`);
console.log(`  evaluated == native     ${ok}`);
console.log(`  marked wasm-unsupported ${marked}`);
console.log(`  marked no-stable-value  ${unstable}   (evaluated, value not compared)`);
console.log(`  FAILURES                ${fail}`);
console.log('══════════════════════════════════════════════════════════');

if (fail > 0) {
  console.log('\nA failing example either refuses in the shipped wasm engine or produces a');
  console.log('different value than native cx, and is NOT marked in the corpus. Fix the');
  console.log('engine, or mark the example wasm-unsupported in');
  console.log('scripts/gen_guide/playground/examples.cxd with a reason a reader can act on');
  console.log('— a marked example renders an honest banner, never a raw refusal. A "stale');
  console.log('marker" failure is the reverse: it works here, so the marker must come OFF.');
  cleanup();
  process.exit(1);
}
console.log('OK — every example evaluates in the shipped wasm engine or is justifiably marked.');
cleanup();
process.exit(0);
