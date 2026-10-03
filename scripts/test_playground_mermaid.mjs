// scripts/test_playground_mermaid.mjs — the playground diagram VALIDITY
// gate (#992).
//
// WHAT IT ASSERTS. Every diagram the playground can put on screen must
// PARSE. The full cross product is walked:
//
//     example × {auto, instance} × {source, output} × {min, compact, full}
//
// where `example` is every example the page can open: the primer's
// fixtures (playground.primer.js — the picker since PLAY-1), each drawn in
// its own reading, and the playground corpus (playground.examples.js,
// reachable by its #ex=<key> link).
//
// against THE VERY BUNDLE the page loads. A diagram that does not parse
// is a pane the reader cannot use — which is how `string @size "'large'"`
// sat in front of visitors for five releases (#992): every piece of the
// pipeline "worked", and nothing checked the one property that decides
// whether a human sees a picture.
//
// ONE ARTIFACT, NOT TWO PINS (#1007). This gate used to resolve its own
// `mermaid` from scripts/playground-gate/node_modules while the page
// pulled the floating range `mermaid@10` off jsDelivr — two pins that
// drifted independently and only happened to agree. Both now read
// scripts/gen_guide/playground/vendor/mermaid.min.js, so "the version the
// gate blessed" and "the version the reader got" are the same bytes by
// construction. Moving the pin is therefore a repo change this gate sees,
// not a CDN change it can't.
//
// WHY BOTH SUBJECTS. `auto` comes from the CX diagram module inside the
// wasm engine; `instance` is built in playground.js in the browser. They
// are different emitters with different failure modes, and both draw
// into the same pane. `source` and `output` are different DOCUMENTS —
// an example's value routinely has a shape its program does not — so a
// diagram that is valid for one can be invalid for the other.
//
// WHY IT DRIVES THE REAL FILES. The instance graphs come from
// playground.js's own builder, reached through the `cxPlaygroundInternals`
// seam, and the auto graphs come from the built wasm bundle. Nothing
// here reimplements either; a reimplementation would go green while the
// shipped code rotted.
//
// USAGE
//   npm --prefix scripts/playground-gate install     (once — jsdom only)
//   node scripts/test_playground_mermaid.mjs [--verbose] [--limit N]
//
// Requires `make build-playground` to have produced dist/wasm/. The
// renderer needs no install: it is in the tree.
// Exit 0 when every diagram parses; 1 on any failure; 2 on a setup
// problem (missing deps / missing bundle) — never a silent skip.

import { createRequire } from 'node:module';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const require = createRequire(import.meta.url);
const ROOT = resolve(import.meta.dirname, '..');
const VERBOSE = process.argv.includes('--verbose');
// `--slice FROM:TO` selects a half-open range of the example list.
// The gate SHARDS itself across child processes (see the dispatcher at
// the bottom) because one wasm module instance cannot survive all 182
// examples; each child gets a fresh engine for its slice.
const SLICE_IX = process.argv.indexOf('--slice');
const SLICE = SLICE_IX >= 0 ? process.argv[SLICE_IX + 1] : '';
const LIMIT_IX = process.argv.indexOf('--limit');
const LIMIT = LIMIT_IX >= 0 ? parseInt(process.argv[LIMIT_IX + 1], 10) : Infinity;

// RULED: 1170-d. An `output` text that is the emitter-internal `cx:` image
// (`[cx:op …]`, `[cx:int …]`, …) is NOT authorable CX: approved spec keeps it
// unreadable — E210 stays intact — until semantic_value_model.md §2 L78 lowers
// quoted trees at the I1 epoch (#708). The Diagram pane shows the same empty
// placeholder for it, so it is a NAMED, COUNTED skip here, not a failure and
// not a silent pass. The class is self-clearing: the day L78 lands the image
// stops matching and these rows grade again with nothing to un-mark.
const CX_IMAGE_REASON = 'output is the emitter-internal cx: image; not authorable until semantic_value_model.md §2 L78 lowers quoted trees (#708/I1)';
const isCxImage = (text) => /^\s*\[cx:[A-Za-z]/.test(text);

const GATE_MODULES = resolve(ROOT, 'scripts/playground-gate/node_modules');
const PLAYGROUND = resolve(ROOT, 'scripts/gen_guide/playground');
// The renderer the PAGE loads (#1007). Not an npm resolution — the file
// playground.html points its <script> at.
const VENDORED_MERMAID = resolve(PLAYGROUND, 'vendor/mermaid.min.js');

function setupFail(msg, hint) {
  console.error(`\n[playground-mermaid] SETUP FAILURE: ${msg}`);
  if (hint) console.error(`[playground-mermaid]   → ${hint}`);
  process.exit(2);
}

// ── shard dispatcher ───────────────────────────────────────────
//
// WHY THE GATE FORKS. One wasm module instance cannot survive all 182
// examples: each one costs an evalCode + a tree + six diagram calls, and
// somewhere around example 130 the engine's arena is spent and
// emscripten abort()s. After an abort every later call throws, so a
// single-process walk reports ~150 "failures" that are one resource
// limit wearing 150 masks — measured, and exactly the kind of noisy
// red that teaches people to ignore a gate.
//
// `cxlib.reset()` does not reclaim enough to matter (also measured), and
// a browser visitor never meets this: they open one example at a time on
// a fresh page. So the gate gives each slice its own process and its own
// engine, which is both the honest model of how the page is used and the
// thing that makes a red result mean a bad diagram.
//
// #1377 (the view axis): a subject is now drawn under SIX views, not two,
// so an example costs ~30 MB of arena instead of ~10 (measured: RSS
// 295 → 692 MB over examples 1-14 in one instance, `V panic: memory
// allocation failure` at example 15; the lane saw the same wall at 19 as
// 240 cascading "Program terminated with exit(1)" failures). Twenty per
// shard no longer fits the 512 MB wasm ceiling, and six does not either:
// 168-erd-large-org-structure ALONE grows the process by ~310 MB across its
// 36 subjects (RSS 236 → 547 MB, measured), so any shard that reaches it
// with a warm arena dies at it and takes the shard's tail with it. One
// example per process is the model the paragraph above already names — a
// visitor opens one example on a fresh page — and it is the only shard
// size under which a red here can only mean a bad diagram.
const SHARD_SIZE = 1;

// pageExamples — every example the page can put on screen, in one list:
// the primer's fixtures (playground.primer.js, the picker since PLAY-1)
// first, then the playground corpus (playground.examples.js, reachable by
// its #ex=<key> link). Each row carries what the View pane draws as Source
// (`input`) and how its Output is produced (`reading`, `doc`).
function pageExamples(win) {
  const rows = [];
  for (const p of ((win.cxPlaygroundPrimer || {}).examples || [])) {
    rows.push([`primer:${p.id}`, {
      input: p.reading === 'data' ? p.doc : p.src,
      reading: p.reading, doc: p.doc, runnable: p.runnable,
    }]);
  }
  for (const [key, ex] of Object.entries((win.cxPlaygroundExamples || {}).program || {})) {
    rows.push([key, { ...ex, reading: 'code', doc: '' }]);
  }
  return rows;
}
function countExamples() {
  // Cheap: the examples files are self-contained scripts that assign to
  // window. No jsdom, no wasm — the dispatcher must not pay for either.
  const fakeWindow = {};
  for (const f of ['playground.primer.js', 'playground.examples.js']) {
    try {
      new Function('window', 'globalThis', readFileSync(resolve(PLAYGROUND, f), 'utf8'))(fakeWindow, fakeWindow);
    } catch (e) {
      setupFail(`could not evaluate ${f}: ${e.message}`);
    }
  }
  return pageExamples(fakeWindow).length;
}

if (!SLICE) {
  const total = Math.min(countExamples(), LIMIT);
  if (total === 0) setupFail('playground.examples.js yielded no examples.');
  const totals = { pass: 0, empty: 0, skipped: 0, cximage: 0, fail: 0 };
  let sawSetupFailure = false;
  for (let from = 0; from < total; from += SHARD_SIZE) {
    const to = Math.min(from + SHARD_SIZE, total);
    const args = [process.argv[1], '--slice', `${from}:${to}`];
    if (VERBOSE) args.push('--verbose');
    const r = spawnSync(process.execPath, args, {
      cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
    });
    const out = r.stdout || '';
    // Children speak one machine-readable line; everything else they
    // print is human text that belongs on this console verbatim.
    const m = /^__SHARD__ (\{.*\})$/m.exec(out);
    process.stdout.write(out.replace(/^__SHARD__ .*$/m, '').replace(/\n{3,}/g, '\n\n'));
    if (r.status === 2) { sawSetupFailure = true; process.stderr.write(r.stderr || ''); break; }
    if (m) {
      const s = JSON.parse(m[1]);
      totals.pass += s.pass; totals.empty += s.empty;
      totals.skipped += s.skipped; totals.fail += s.fail;
      totals.cximage += s.cximage || 0;
    } else {
      // A child that died without reporting is itself a failure — never
      // let a crashed shard read as a clean slice.
      totals.fail += 1;
      process.stderr.write(`[playground-mermaid] shard ${from}:${to} produced no summary\n`);
      process.stderr.write(r.stderr || '');
    }
  }
  if (sawSetupFailure) process.exit(2);
  console.log('\n══════════════════════════════════════════════════════════');
  console.log('playground diagram validity gate — TOTAL');
  console.log(`  examples          ${total}   (in shards of ${SHARD_SIZE})`);
  console.log(`  diagrams parsed   ${totals.pass}`);
  console.log(`  empty (no shape)  ${totals.empty}`);
  console.log(`  no subject        ${totals.skipped}`);
  console.log(`  cx: image (1170-d) ${totals.cximage}   named skip — ${CX_IMAGE_REASON}`);
  console.log(`  FAILURES          ${totals.fail}`);
  console.log('══════════════════════════════════════════════════════════');
  if (totals.fail > 0) process.exit(1);
  console.log('OK — every diagram the playground can emit parses.');
  process.exit(0);
}

// ── deps ───────────────────────────────────────────────────────
if (!existsSync(GATE_MODULES)) {
  setupFail(
    'the gate\'s dev dependencies are not installed.',
    'npm --prefix scripts/playground-gate install',
  );
}
const gateRequire = createRequire(resolve(GATE_MODULES, 'noop.js'));
let JSDOM;
try {
  ({ JSDOM } = gateRequire('jsdom'));
} catch (e) {
  setupFail(`could not load jsdom: ${e.message}`,
            'npm --prefix scripts/playground-gate install');
}
// mermaid is NOT an npm dependency of this gate any more (#1007) — it is
// vendored beside the page. A missing bundle is a setup failure, never a
// silent fall back to some node_modules copy, because a copy is exactly
// the drift this closes.
if (!existsSync(VENDORED_MERMAID)) {
  setupFail(`the vendored mermaid bundle is missing: ${VENDORED_MERMAID}`,
            'see scripts/gen_guide/playground/vendor/README.md — the pin of record');
}

// ── wasm engine ────────────────────────────────────────────────
// The JSPI bundles (libcx-async / libcx-pthreads) call
// `new WebAssembly.Suspending(...)` at instantiation and abort under
// node, so the gate loads the plain one. It carries the SAME engine —
// same V sources, same embedded stdlib — which is what the diagram
// emitters live in.
const BUNDLE = ['dist/wasm/libcx-sync.js', 'dist/wasm/libcx.js']
  .map(p => resolve(ROOT, p)).find(existsSync);
if (!BUNDLE) {
  setupFail('no node-loadable wasm bundle under dist/wasm/.',
            'make build-playground');
}
globalThis.createCxModule = require(BUNDLE);
require(resolve(ROOT, 'dist/wasm/cxlib.js'));
const cxlib = globalThis.cxlib;
if (!cxlib) setupFail('cxlib.js did not attach to globalThis.', 'make build-playground');
await cxlib.ready;

// ── the page, in a document ────────────────────────────────────
// playground.js is a browser IIFE over the real playground.html DOM.
// Loading both here means the gate exercises the SHIPPED files.
const dom = new JSDOM(readFileSync(resolve(PLAYGROUND, 'playground.html'), 'utf8'), {
  url: 'http://localhost/',
  pretendToBeVisual: true,
  runScripts: 'outside-only',
});
const win = dom.window;
globalThis.window = win;
globalThis.document = win.document;
Object.defineProperty(globalThis, 'navigator',
  { value: win.navigator, configurable: true, writable: true });

// mermaid — THE VENDORED BUNDLE, the one the page's <script> loads (#1007).
//
// Loaded through an explicit CJS shim rather than `import()` or `require()`
// on purpose. The bundle is UMD, and which branch of a UMD prelude fires
// under node depends on the nearest package.json's `type` field: with
// `type: "module"` in scope node parses it as ESM, no `module` is in
// scope, the prelude falls through to its global-assignment branch and
// `import()` hands back an empty namespace object — a load that "succeeds"
// while producing no mermaid. Handing it a `module`/`exports` pair makes
// the first branch fire deterministically, wherever the file sits and
// whatever package.json happens to be above it.
//
// This runs AFTER the jsdom globals are installed above: the bundle's
// bundled d3 touches `document` while evaluating.
const MERMAID_SRC = readFileSync(VENDORED_MERMAID, 'utf8');
const MERMAID_BYTES = statSync(VENDORED_MERMAID).size;
const MERMAID_SHA = createHash('sha256').update(MERMAID_SRC).digest('hex');
const mermaid = (() => {
  const mod = { exports: {} };
  new Function('module', 'exports', MERMAID_SRC)(mod, mod.exports);
  const m = mod.exports && mod.exports.default ? mod.exports.default : mod.exports;
  if (!m || typeof m.parse !== 'function') {
    setupFail('the vendored mermaid bundle loaded but exposes no parse().',
              `is ${VENDORED_MERMAID} the UMD build (dist/mermaid.min.js)?`);
  }
  return m;
})();
mermaid.initialize({
  startOnLoad: false, theme: 'dark', securityLevel: 'loose',
  htmlLabels: true, flowchart: { curve: 'basis', htmlLabels: true },
});

// The page reads cxlib at load; the real one is handed over so the
// page's own emitters run against the real engine. `window.mermaid` is
// deliberately NOT set: mermaid's renderer needs CSSStyleSheet, which
// jsdom does not implement, and the gate's business is parsing, not
// rendering. Without it the page takes its "renderer still loading"
// branch and stays quiet while this file drives mermaid.parse directly.
win.cxlib = cxlib;
win.eval(readFileSync(resolve(PLAYGROUND, 'playground.primer.js'), 'utf8'));
win.eval(readFileSync(resolve(PLAYGROUND, 'playground.examples.js'), 'utf8'));
win.eval(readFileSync(resolve(PLAYGROUND, 'playground.js'), 'utf8'));

const internals = win.cxPlaygroundInternals;
if (!internals || typeof internals.buildInstanceGraph !== 'function') {
  setupFail('playground.js did not expose cxPlaygroundInternals.buildInstanceGraph.',
            'the verification seam at the end of playground.js was removed or renamed');
}

const ALL_ROWS = pageExamples(win);
const examples = Object.fromEntries(ALL_ROWS);
const ALL_KEYS = ALL_ROWS.map(([k]) => k);
let keys;
if (SLICE) {
  const [a, b] = SLICE.split(':').map(n => parseInt(n, 10));
  keys = ALL_KEYS.slice(a, b);
} else {
  keys = ALL_KEYS.slice(0, LIMIT);
}
if (keys.length === 0) setupFail('the page yielded no examples.');

// ── the walk ───────────────────────────────────────────────────
const LEVELS   = ['min', 'compact', 'full'];
const SUBJECTS = ['source', 'output'];
// #1377: the forced views are graded too — a diagram the engine DRAWS for a
// forced view must parse and be structurally sound like any other; the
// engine's own refusal (CXER0282 E_VIEW_NOT_CARRIED — the source cannot carry
// that view) is a recorded SKIP, never a failure and never a pass.
const VIEWS    = ['auto', 'erd', 'cfg', 'seq', 'effects', 'instance'];

// Mirrors renderGraphNow()'s pre-parse normalisation exactly, so the
// gate parses the same bytes the pane does.
// structuralFaults — what `mermaid.parse` cannot tell you.
//
// Returns a list of human-readable faults, empty when the diagram is sound.
// Two checks, each anchored to a defect that shipped through the parse-only
// version of this gate:
//
//   DANGLING TARGET  every id on an edge must be DECLARED by a node
//                    statement somewhere in the diagram. mermaid invents an
//                    empty box instead of complaining (#1068).
//   DUPLICATE ID     no id may be declared twice with different labels.
//                    mermaid keeps the last silently (#1349).
//
// Deliberately conservative: it only looks at flowchart node/edge syntax and
// ignores sequence/ER diagrams entirely, because those have no id-declaration
// grammar to check and a false failure here would be worse than the gap.
function structuralFaults(body) {
  const faults = [];
  const lines = body.split('\n').map((l) => l.trim());
  if (!/^(flowchart|graph)\b/.test(lines[0] || '')) return faults; // CFG only

  // A node DECLARATION carries a shape: id[...] id(...) id{{...}} id(((...)))
  const declared = new Map();
  const declRe = /^([A-Za-z_][A-Za-z0-9_]*)\s*(\[|\(|\{)/;
  for (const l of lines) {
    const m = l.match(declRe);
    if (!m) continue;
    const id = m[1];
    if (id === 'subgraph' || id === 'end' || id === 'flowchart' || id === 'graph') continue;
    const label = l.slice(m[1].length);
    if (declared.has(id) && declared.get(id) !== label) {
      faults.push(`DUPLICATE node id \`${id}\` declared twice with different labels — mermaid keeps the last`);
    }
    declared.set(id, label);
  }

  // An EDGE mentions two ids around an arrow. Covers -->, -.->, ---, -- "x" -->
  // and the dotted labelled form -. "x" .->
  const edgeRe = /^([A-Za-z_][A-Za-z0-9_]*)\s*(?:-[-.].*?)?(?:--&gt;|-->|\.-&gt;|\.->|---)\s*([A-Za-z_][A-Za-z0-9_]*)/;
  for (const l of lines) {
    const m = l.match(edgeRe);
    if (!m) continue;
    for (const id of [m[1], m[2]]) {
      if (!declared.has(id)) {
        faults.push(`DANGLING edge target \`${id}\` — no node declares it; mermaid would auto-create an empty box`);
      }
    }
  }
  return [...new Set(faults)];
}

function normalise(src) {
  let body = String(src || '').replace(/^%%cx:[^\n]*\n?/m, '').trim();
  return body.replace(/^```mermaid\s*/, '').replace(/```\s*$/, '').trim();
}

let pass = 0, fail = 0, empty = 0, skipped = 0, cximage = 0;
const failures = [];


for (const key of keys) {
  const ex = examples[key];
  const source = String(ex.input || '');

  // Reclaim the engine arena between examples. A browser visitor meets
  // ONE example at a time with idle gaps; this loop meets 182 back to
  // back in one module instance, and without the reset the arena is
  // exhausted around example 130 — after which emscripten abort()s and
  // EVERY later call fails, turning one resource limit into a wall of
  // false diagram failures. Measured: 151 cascading failures, all of
  // which were this and none of which were a bad diagram.
  try { cxlib.reset(); } catch (_) { /* older bundle without the export */ }

  // The `output` subject is the value the program evaluated to. An
  // example that cannot run here (a capability the wasm sandbox lacks,
  // a wall-clock sleep the plain bundle refuses) simply has no output
  // subject — the pane shows its empty placeholder, and there is no
  // diagram to check. That is a SKIP, and it is counted and named.
  let output = '';
  if (ex.runnable !== false) {
    // The page's own reading (PLAY-3's two): a document is its own value; a
    // code example runs over its document bound as $doc whenever it reads a
    // real one (playground.js's runOnce), a program over nothing otherwise.
    try {
      output = String((ex.reading === 'data'
        ? cxlib.toCx(ex.doc || source)
        : cxlib.evalCode(source, 'cx', ex.doc && ex.doc.trim() !== '' ? ex.doc : '')) || '');
    }
    catch (_) { output = ''; }
  }

  const texts = { source, output };
  for (const subject of SUBJECTS) {
    const text = texts[subject];
    if (!text) { skipped += VIEWS.length * LEVELS.length; continue; }
    if (subject === 'output' && isCxImage(text)) {
      cximage += VIEWS.length * LEVELS.length;
      console.log(`SKIP  ${key} · output — ${CX_IMAGE_REASON}`);
      continue;
    }
    // The tree is what the instance view graphs; one call feeds every
    // rung, exactly as refreshView() does it.
    let parsedTree = null;
    try {
      const t = cxlib.tree(text);
      parsedTree = typeof t === 'string' ? JSON.parse(t) : t;
    } catch (_) { parsedTree = null; }

    for (const view of VIEWS) {
      for (const level of LEVELS) {
        const label = `${key} · ${view} · ${subject} · ${level}`;
        let diagram = '';
        try {
          diagram = (view === 'instance')
            ? (parsedTree == null ? '' : internals.buildInstanceGraph(parsedTree, level))
            : (cxlib.diagram(text, `mermaid:${level}`, view) || '');
        } catch (e) {
          if (view !== 'auto' && view !== 'instance' && /CXER0282/.test(String((e && e.message) || e))) {
            skipped++;
            if (VERBOSE) console.log(`SKIP  ${label} — ${String(e.message).split('\n')[0].slice(0, 100)}`);
            continue;
          }
          fail++;
          failures.push({ label, msg: `emitter threw: ${e.message}`, body: '' });
          continue;
        }
        const body = normalise(diagram);
        if (!body) { empty++; continue; }
        try {
          await mermaid.parse(body);
          // PARSING IS NOT ENOUGH, and three shipped defects proved it.
          // mermaid AUTO-DECLARES any id it meets on an edge, and silently
          // keeps the LAST of two declarations sharing an id — so a diagram
          // whose edges point at nodes that do not exist, or whose nodes
          // collide, parses perfectly and renders wrongly. This gate was
          // parse-only, so it was vacuous for that whole class:
          //   #1068  a `resolves` bridge pointed at a PHANTOM node (the
          //          target was the literal string "lb"); 58 of 182 examples
          //          rendered a wrong bridge, 1 of them dangling.
          //   #1349  `lh`/`lb` are minted as a constant per scope, so nested
          //          for-comprehensions collide on one id and mermaid keeps
          //          the last — reproducing the `lt --> lt` self-edge #1036
          //          had already fixed one construct over.
          //   #1350  a golden left stale by the regen tool, invisible here.
          const structural = structuralFaults(body);
          if (structural.length > 0) {
            fail++;
            const msg = structural.slice(0, 3).join(' | ');
            failures.push({ label, msg, body });
            console.log(`FAIL  ${label}\n      ${msg}`);
            continue;
          }
          pass++;
          if (VERBOSE) console.log(`PASS  ${label}`);
        } catch (e) {
          fail++;
          const msg = ((e && e.message) || String(e)).split('\n').slice(0, 3).join(' | ');
          failures.push({ label, msg, body });
          console.log(`FAIL  ${label}\n      ${msg}`);
        }
      }
    }
  }
}

// ── verdict (one shard) ────────────────────────────────────────
if (fail > 0) {
  console.log('\n=== failing diagrams ===');
  for (const f of failures.slice(0, 20)) {
    console.log(`\n### ${f.label}\n${f.msg}\n---\n${f.body}\n---`);
  }
  if (failures.length > 20) console.log(`\n… and ${failures.length - 20} more`);
} else if (VERBOSE) {
  // Identify the renderer by the BYTES, not by a self-reported version
  // string (the UMD bundle exports none) — the digest is what a reader
  // actually ran, and it is the value the vendor README pins.
  console.log(`shard ${SLICE}: ${pass} parsed, 0 failures `
    + `(vendored mermaid, ${MERMAID_BYTES} bytes, sha256 ${MERMAID_SHA.slice(0, 12)}…)`);
}
// The line the dispatcher reads. Kept last and kept unique.
console.log(`__SHARD__ ${JSON.stringify({ pass, empty, skipped, cximage, fail })}`);
process.exit(fail === 0 ? 0 : 1);
