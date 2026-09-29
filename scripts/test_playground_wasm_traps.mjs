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
// Since PLAY-1 the page's picker is the primer's fixtures
// (playground.primer.js, `window.cxPlaygroundPrimer.examples`), each run in
// its own reading; the corpus above stays reachable by its #ex=<key> link.
// Both are swept.
const fakeWindow = {};
for (const f of ['playground.primer.js', 'playground.examples.js']) {
  try {
    new Function('window', 'globalThis', readFileSync(resolve(PLAYGROUND, f), 'utf8'))(fakeWindow, fakeWindow);
  } catch (e) {
    setupFail(`could not evaluate ${f}: ${e.message}`);
  }
}
const program = (fakeWindow.cxPlaygroundExamples || {}).program || {};
const primer = (fakeWindow.cxPlaygroundPrimer || {}).examples || [];
const keys = Object.keys(program);
if (keys.length === 0) setupFail('playground.examples.js yielded no examples.');
if (primer.length === 0) setupFail('playground.primer.js yielded no examples.', 'make docs');

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

// ── platform probes (#1381) ──────────────────────────────────────────────
// Ring-2 surfaces the playground never lists but the shipped engine must
// still not TRAP on: each of these used to die in a wasm-ld
// `signature_mismatch:syscall` thunk because V's crypto.rand draws entropy
// through a Linux getrandom syscall the wasm stub declared with another
// shape. A refusal is acceptable here; a trap never is.
const PROBES = {
  'probe:1381:journal-mem-open':
    "[?lib 'cx-platform/journal'] [?let [= $j [$journal:open \"mem://probe-1381\" \"acme\"]] [$name $j]]",
  'probe:1381:random-crypto-bytes':
    "[?lib 'cx-stdlib/random'] [$count [$random-crypto-bytes 8]]",
  'probe:1381:crypto-ed25519-keypair':
    "[?lib 'cx-stdlib/crypto'] [$name [$crypto-ed25519-keypair]]",
  // the issue's motivating case: a flow run over a mem:// journal (the
  // flow.cxd flow-023 document, start only) — every verb it reaches must be
  // closure-free under the single-threaded bundle.
  'probe:1381:flow-start': [
    "[?lib 'cx-platform/flow'] [?lib 'cx-platform/journal']",
    "[?def unreserve impure [effects] ($sku='') [unreserved sku=$sku]]",
    "[?def reserve impure [effects] [compensates unreserve] ($sku='') [reserved sku=$sku]]",
    "[?def place-order impure [effects] ($order='') [placed order=$order]]",
    "[?let [= $j [$journal:open \"mem://probe-1381-flow\" \"acme\"]]",
    "[= $f [$cx:parse \"[flow name='checkout' [args [sku::string] [order::string]] [step name='reserve' [do 'inventory/reserve' [sku $args/sku]]] [step name='place' pivot=true [do 'orders/place' [order $args/order]]]]\"]]",
    "[= $e [resolver [act name='inventory/reserve' resolved='sha2-256:11' compensates='inventory/unreserve' [fn $reserve]] [act name='orders/place' resolved='sha2-256:22' [fn $place-order]]]]",
    "[= $o {env: $e flow: $f actor: \"did:key:z6Mk\" authority: \"cap:sha2-256:c1\" nonce: \"n1\" stream: \"order:o-1\"}]",
    "[= $r1 [$flow:start $j $f [args [sku \"88\"] [order \"o-1\"]] $o]]",
    "[status $r1@status]]",
  ].join('\n'),
};
const cases = keys.map(key => {
  const entry = program[key];
  return [key, entry.input ?? entry.source ?? entry.src ?? '', ''];
}).filter(([, source]) => source);
// A primer example runs the way the page runs it: a document through the
// data reading, a query over its document bound as $doc.
for (const p of primer) {
  cases.push([`primer:${p.id}`, p.reading === 'data' ? p.doc : p.src,
              p.reading === 'query' ? p.doc : '', p.reading]);
}
for (const [key, source] of Object.entries(PROBES)) cases.push([key, source, '']);

const counts = { ok: 0, refused: 0, abort: 0, trap: 0 };
const traps = [];
const aborts = [];
for (const [key, source, input, reading] of cases) {
  let verdict = 'OK', detail = '';
  try {
    if (reading === 'data') cxlib.toCx(source);
    else cxlib.evalCode(source, 'cx', input || '');
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

console.log(`test-playground-wasm-traps: ${cases.length} examples+probes — ok ${counts.ok}, refused ${counts.refused}, aborted ${counts.abort} (single-threaded bundle), TRAPS ${counts.trap}`);
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
