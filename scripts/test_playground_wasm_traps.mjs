// scripts/test_playground_wasm_traps.mjs — the playground WASM TRAP sweep
// (#1374).
//
// WHAT IT ASSERTS. No example in the playground corpus makes the shipped
// wasm engine TRAP — `RuntimeError: table index is out of bounds`, a memory
// access out of bounds, `unreachable` — when evaluated the way the page
// evaluates it (`cxlib.evalCode(source, 'cx', '')`). A trap is an ENGINE
// defect, never a refusal the corpus may mark: it is what a V closure
// (an mprotect'd code trampoline, vlib/builtin/closure) does when wasm32
// calls it, and it is how `[$sort (3, 1, 2)]` died on the page (#1374). A
// `wasm-unsupported` marker does not excuse a trap — the marker exists so
// the page can SAY why an example refuses, and a trap says nothing.
//
// WHAT IT DOES NOT ASSERT. Parity with native is `test-playground-wasm-eval`'s
// (Chrome, the JSPI bundle — see its header for why a node harness cannot
// grade parity). A cx-level refusal (`[err …]`, a thrown CXER) is fine here;
// so is an emscripten ABORT (`Aborted(… Not supported)` — the `go` a
// `[?async]` future needs has no thread in the single-threaded bundle):
// both are counted and listed, neither fails the sweep.
//
// WHY IT EXISTS. Nothing else runs the corpus in the engine under node and
// looks at HOW it failed: `test-playground-mermaid` calls evalCode but
// swallows every exception into "no output subject"; the wasm-eval sweep
// needs headless Chrome. Two release cuts shipped a trapping example.
//
// Usage: node scripts/test_playground_wasm_traps.mjs [--verbose]
// Exit 0 iff no example trapped. Needs dist/wasm/ (make build-playground).

import { createRequire } from 'node:module';
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const require = createRequire(import.meta.url);
const ROOT = resolve(import.meta.dirname, '..');
const PLAYGROUND = resolve(ROOT, 'scripts/gen_guide/playground');
const VERBOSE = process.argv.includes('--verbose');

function setupFail(msg, hint) {
  console.error(`test-playground-wasm-traps: SETUP FAILURE — ${msg}`);
  if (hint) console.error(`  hint: ${hint}`);
  process.exit(2);
}

// ── the corpus ───────────────────────────────────────────────────────────
// playground.examples.js is a self-contained IIFE assigning
// `window.cxPlaygroundExamples = { program }`; `program` maps key → entry.
const examplesSrc = readFileSync(resolve(PLAYGROUND, 'playground.examples.js'), 'utf8');
const fakeWindow = {};
try {
  new Function('window', 'globalThis', examplesSrc)(fakeWindow, fakeWindow);
} catch (e) {
  setupFail(`could not evaluate playground.examples.js: ${e.message}`);
}
const program = (fakeWindow.cxPlaygroundExamples || {}).program || {};
const keys = Object.keys(program);
if (keys.length === 0) setupFail('playground.examples.js yielded no examples.');

// ── the engine ───────────────────────────────────────────────────────────
// The JSPI bundles abort under node (see test_playground_mermaid.mjs); the
// plain bundle carries the same engine — the same V sources, the same
// closures — which is what a trap is about.
const BUNDLE = ['dist/wasm/libcx-sync.js', 'dist/wasm/libcx.js']
  .map(p => resolve(ROOT, p)).find(existsSync);
if (!BUNDLE) setupFail('no node-loadable wasm bundle under dist/wasm/.', 'make build-playground');
globalThis.createCxModule = require(BUNDLE);
require(resolve(ROOT, 'dist/wasm/cxlib.js'));
const cxlib = globalThis.cxlib;
if (!cxlib) setupFail('cxlib.js did not attach to globalThis.', 'make build-playground');
await cxlib.ready;

const TRAP_RE = /table index is out of bounds|memory access out of bounds|\bunreachable\b|null function|indirect call|integer overflow|integer divide by zero/i;
const ABORT_RE = /Aborted\(|Not supported|program has already aborted/i;

function classify(e) {
  const msg = String((e && e.message) || e);
  if (e instanceof WebAssembly.RuntimeError || TRAP_RE.test(msg)) return ['TRAP', msg];
  if (ABORT_RE.test(msg)) return ['ABORT', msg];
  return ['REFUSED', msg];
}

const counts = { ok: 0, refused: 0, abort: 0, trap: 0 };
const traps = [];
const aborts = [];
for (const key of keys) {
  const entry = program[key];
  const source = entry.input ?? entry.source ?? entry.src ?? '';
  if (!source) continue;
  let verdict = 'OK', detail = '';
  try {
    cxlib.evalCode(source, 'cx', '');
  } catch (e) {
    [verdict, detail] = classify(e);
  }
  if (verdict === 'OK') counts.ok++;
  else if (verdict === 'REFUSED') counts.refused++;
  else if (verdict === 'ABORT') { counts.abort++; aborts.push(key); }
  else { counts.trap++; traps.push(`${key}: ${detail.split('\n')[0].slice(0, 120)}`); }
  if (VERBOSE || verdict === 'TRAP') console.log(`  ${verdict.padEnd(8)} ${key}${detail ? ' — ' + detail.split('\n')[0].slice(0, 100) : ''}`);
  // A trap can leave the engine inconsistent; start the next example clean.
  if (verdict === 'TRAP' || verdict === 'ABORT') { try { cxlib.reset(); } catch (_) { /* older bundle */ } }
}

console.log(`test-playground-wasm-traps: ${keys.length} examples — ok ${counts.ok}, refused ${counts.refused}, aborted ${counts.abort} (single-threaded bundle), TRAPS ${counts.trap}`);
if (aborts.length && VERBOSE) console.log(`  aborted: ${aborts.join(', ')}`);
if (traps.length) {
  console.log('FAIL — the shipped engine TRAPS on:');
  for (const t of traps) console.log(`  ${t}`);
  process.exit(1);
}
console.log('OK — no example traps the wasm engine.');
// An example that calls exit() inside the engine leaves emscripten's
// process.exitCode set (the "program exited (with status: 1)" notice above);
// the sweep's verdict is the trap count, so say so explicitly.
process.exit(0);
