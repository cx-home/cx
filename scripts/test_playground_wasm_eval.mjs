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

// The server / browser / CDP boot lives in scripts/playground-gate/
// browser_harness.mjs, shared with the #1049 Tree gate: two copies of this
// rig would be two Chrome flag sets and two readiness rules drifting apart.
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHarness, loadExamples, ROOT, NATIVE }
  from './playground-gate/browser_harness.mjs';

const VERBOSE = process.argv.includes('--verbose');
const LIMIT_IX = process.argv.indexOf('--limit');
const LIMIT = LIMIT_IX >= 0 ? parseInt(process.argv[LIMIT_IX + 1], 10) : Infinity;

const DEADLINE_MS = (parseInt(process.env.WASM_EVAL_DEADLINE || '900', 10)) * 1000;

const H = createHarness({ label: 'playground-wasm-eval', deadlineMs: DEADLINE_MS });
const { setupFail, checkDeadline, cleanup } = H;

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
// Measured on the example that first needed it (57-map-par-bulkhead: a
// 2-slot `[?bulkhead]` over 8 `[par]` items): 10 DISTINCT native results
// in 12 runs, from zero saturation errs to six — and one of those runs
// happened to equal the wasm result exactly. That is not hypothetical
// flakiness: this gate flipped between "justified marker" and "stale
// marker" on consecutive runs before the state existed.
//
// THE SET IS CURRENTLY EMPTY (#1043): example 57 was redesigned so its
// value cannot depend on thread timing (`[par N]` bounds the width; the
// `[?bulkhead]` is sized so it cannot shed), and it is now compared
// against native like every other example. The state is kept because the
// hazard is structural, not because anything uses it — the summary line
// below reports 0, and a future non-zero count should be challenged
// rather than accepted.
//
// What the sweep asserts for these is the weaker but TRUE property: the
// example must still EVALUATE in the wasm engine. A refusal is a
// different defect and does not get to hide behind this marker. Marked
// examples are listed in the summary so the set cannot grow unnoticed.
function noStableValue(ex) {
  const m = ex.noStableValue;
  return (typeof m === 'string' && m.trim()) ? m.trim() : '';
}

// ── run ────────────────────────────────────────────────────────
// The whole rig — preconditions, static server, headless Chrome, a tab on
// playground.html, cxlib ready, and the JSPI engine ASSERTED — comes from
// the shared harness. See its header for why a browser and not node.
const program = loadExamples(readFileSync, setupFail);
const keys = Object.keys(program).slice(0, LIMIT);

const { evalJs, close } = await H.bootPage({
  portBase: 8790, cdpBase: 9330, needNative: true, verbose: VERBOSE,
});
console.log(`[playground-wasm-eval] examples: ${keys.length}\n`);

const tmpDir = H.mkTmp('cx-wasm-eval-');
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
