// scripts/test_playground_nav.mjs — the playground NAVIGATION gate (#1380,
// PLAY-1; readings and the picker's corpus amended by PLAY-3, #1741/#1743).
//
// WHAT IT ASSERTS, against the SHIPPED playground.html + playground.js in a
// jsdom document (no wasm, no browser):
//   (a) every PRIMER picker option keeps its `[N]` number — since PLAY-1 the
//       example's place in the primer — and names its fixture id;
//   (b) the arrow keys work FROM THE PICKER: after an example is chosen the
//       <select> holds focus, and a `keydown` ArrowRight there must move to
//       the next example, ArrowDown to the next section;
//   (c) the keys never hijack an editor: an ArrowRight in the program or
//       the document textarea leaves the selection alone;
//   (d) the breadcrumb names the example's number;
//   (e) the TWO READING tabs (PLAY-3, amending PLAY-1's three): each lists
//       every primer fixture AND every corpus example of that reading (data
//       — section data/*; code — everything else, #1743), the primer's
//       fixtures first in primer order, the corpus's after; Data shows the
//       document alone, Code the program (and, when the loaded example
//       actually reads one, the document too — never a separate query tab,
//       #1741).
// RED-PROOF: at 1fe8528a3 (a) and (b) both fail — the label strip and the
// handler's early return for every <select>.
//
// Usage: node scripts/test_playground_nav.mjs   (jsdom from scripts/playground-gate)
//   CX_PLAYGROUND_JS=/path/to/playground.js overrides the script under test
//   (used for the red-proof against an older build).

import { createRequire } from 'node:module';
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const ROOT = resolve(import.meta.dirname, '..');
const PLAYGROUND = resolve(ROOT, 'scripts/gen_guide/playground');
const GATE_MODULES = resolve(ROOT, 'scripts/playground-gate/node_modules');
const JS = process.env.CX_PLAYGROUND_JS || resolve(PLAYGROUND, 'playground.js');

function fail(msg) { console.error(`test-playground-nav: FAIL — ${msg}`); process.exit(1); }
function setupFail(msg, hint) {
  console.error(`test-playground-nav: SETUP FAILURE — ${msg}`);
  if (hint) console.error(`  hint: ${hint}`);
  process.exit(2);
}

if (!existsSync(resolve(GATE_MODULES, 'jsdom'))) {
  setupFail('jsdom is not installed under scripts/playground-gate/node_modules', 'npm --prefix scripts/playground-gate ci');
}
const gateRequire = createRequire(resolve(GATE_MODULES, 'noop.js'));
const { JSDOM } = gateRequire('jsdom');

const dom = new JSDOM(readFileSync(resolve(PLAYGROUND, 'playground.html'), 'utf8'), {
  url: 'http://localhost/', pretendToBeVisual: true, runScripts: 'outside-only',
});
const win = dom.window;
globalThis.window = win;
globalThis.document = win.document;
Object.defineProperty(globalThis, 'navigator', { value: win.navigator, configurable: true, writable: true });
// No engine: the page guards every cxlib use, and navigation is DOM-only.
win.eval(readFileSync(resolve(PLAYGROUND, 'playground.primer.js'), 'utf8'));
win.eval(readFileSync(resolve(PLAYGROUND, 'playground.examples.js'), 'utf8'));
win.eval(readFileSync(JS, 'utf8'));

const primer = (win.cxPlaygroundPrimer || {}).examples || [];
if (primer.length === 0) setupFail('playground.primer.js yielded no examples', 'make docs');
const programExamples = (win.cxPlaygroundExamples || {}).program || {};
if (Object.keys(programExamples).length === 0) setupFail('playground.examples.js yielded no examples', 'make guide');
// The corpus's own two-way split (unchanged since before PLAY-1): data/* is
// the data reading, everything else (code/*, everyday/*) is code.
const legacyReading = (section) => (section || '').startsWith('data/') ? 'data' : 'code';

const pick = win.document.getElementById('cxp-pick');
const input = win.document.getElementById('cxp-input');
const doc = win.document.getElementById('cxp-doc');
const crumb = win.document.getElementById('cxp-crumb');
if (!pick) setupFail('no #cxp-pick in playground.html');
if (!input || !doc) setupFail('no program (#cxp-input) or document (#cxp-doc) editor in playground.html');

function key(target, k) {
  const ev = new win.KeyboardEvent('keydown', { key: k, bubbles: true, cancelable: true });
  target.dispatchEvent(ev);
  return ev.defaultPrevented;
}
const tab = (r) => win.document.querySelector(`.cxp-reading-tab[data-reading="${r}"]`);
if (tab('query')) fail('a "query" reading tab is still in the page — PLAY-3 amends PLAY-2\'s three readings to two (#1741)');

// (e) the two readings: every primer fixture of that reading, in primer
// order, THEN every corpus example of that reading (#1743 — the corpus is
// offered in the picker, not only reachable by its stable link).
for (const r of ['data', 'code']) {
  if (!tab(r)) setupFail(`no reading tab for ${r}`);
  tab(r).click();
  const values = [...pick.querySelectorAll('option')].map(o => o.value);
  const wantPrimer = primer.filter(p => p.reading === r).map(p => `primer:${p.id}`);
  const gotPrimerPart = values.slice(0, wantPrimer.length);
  if (JSON.stringify(gotPrimerPart) !== JSON.stringify(wantPrimer)) {
    fail(`the ${r} tab's primer options are ${JSON.stringify(gotPrimerPart)}, expected ${JSON.stringify(wantPrimer)} (primer order)`);
  }
  const wantLegacy = Object.keys(programExamples)
    .filter((k) => legacyReading(programExamples[k].section) === r)
    .map((k) => `legacy:${k}`);
  const gotLegacyPart = values.slice(wantPrimer.length);
  const sorted = (a) => [...a].sort();
  if (JSON.stringify(sorted(gotLegacyPart)) !== JSON.stringify(sorted(wantLegacy))) {
    fail(`the ${r} tab offers ${gotLegacyPart.length} corpus example(s), expected its ${wantLegacy.length} (#1743 — every corpus example the engine can run is offered)`);
  }
  // Data: the document alone. Code: the program always; the document too
  // only when the loaded example actually reads one (no separate query
  // reading, #1741) — checked below per-example, not here.
  if (r === 'data' && values.length) {
    pick.value = values[0];
    pick.dispatchEvent(new win.Event('change', { bubbles: true }));
    const docShown = !win.document.getElementById('cxp-doc-block').hidden;
    const progShown = !win.document.getElementById('cxp-prog-block').hidden;
    if (!docShown || progShown) fail(`the data reading shows document=${docShown} program=${progShown}, expected document=true program=false`);
  }
}

// (e, continued) the code reading's document pane tracks the LOADED
// example, not the tab: a former-query fixture (a real document, shown
// beside the program) shows it; one that reads no document hides it.
tab('code').click();
const codeWithDoc = primer.find((p) => p.reading === 'code' && p.doc);
const codeNoDoc = primer.find((p) => p.reading === 'code' && !p.doc);
if (codeWithDoc) {
  pick.value = `primer:${codeWithDoc.id}`;
  pick.dispatchEvent(new win.Event('change', { bubbles: true }));
  const docShown = !win.document.getElementById('cxp-doc-block').hidden;
  if (!docShown) fail(`${codeWithDoc.id} reads a document (PLAY-3's former query) but the document pane is hidden`);
  const progShown = !win.document.getElementById('cxp-prog-block').hidden;
  if (!progShown) fail(`${codeWithDoc.id}: the program editor is hidden under the code reading`);
} else {
  console.log('test-playground-nav: no code-reading fixture reads a document — the former-query case is unchecked this run');
}
if (codeNoDoc) {
  pick.value = `primer:${codeNoDoc.id}`;
  pick.dispatchEvent(new win.Event('change', { bubbles: true }));
  const docShown = !win.document.getElementById('cxp-doc-block').hidden;
  if (docShown) fail(`${codeNoDoc.id} reads no document but the document pane is shown under the code reading`);
}

tab('code').click();
const options = [...pick.querySelectorAll('option')].filter(o => !o.disabled);
if (options.length < 3) setupFail(`picker holds ${options.length} options`);

// (a) numbers and ids — the primer's own fixtures, which cite a conformance
// id a reader can look up; the corpus's entries are named by their own
// human label (never a bare key) and are exempt from the id-naming half.
const primerOptions = options.filter((o) => o.value.startsWith('primer:'));
const unnumbered = primerOptions.filter(o => !/^\[\d+\]\s/.test(o.textContent));
if (unnumbered.length) fail(`${unnumbered.length} picker option(s) lost their [N] number, e.g. ${JSON.stringify(unnumbered[0].textContent)}`);
const unnamed = primerOptions.filter(o => !o.textContent.includes(o.value.replace(/^primer:/, '')));
if (unnamed.length) fail(`${unnamed.length} picker option(s) do not name their fixture id, e.g. ${JSON.stringify(unnamed[0].textContent)}`);
const unlabeled = options.filter((o) => o.value.startsWith('legacy:') && !o.textContent.trim());
if (unlabeled.length) fail(`${unlabeled.length} corpus picker option(s) carry no label`);

const startValue = options[0].value;
pick.value = startValue;
pick.dispatchEvent(new win.Event('change', { bubbles: true }));
pick.focus();

// (b) from the picker
const prevented = key(pick, 'ArrowRight');
if (pick.value === startValue) fail('ArrowRight with focus on the picker did not move to the next example');
if (!prevented) fail('ArrowRight on the picker was not preventDefault-ed (the native select would step too)');
if (pick.value !== options[1].value) fail(`ArrowRight moved to ${pick.value}, expected ${options[1].value}`);
const groupBefore = pick.selectedOptions[0].parentElement.label;
key(pick, 'ArrowDown');
const groupAfter = pick.selectedOptions[0].parentElement.label;
if (groupAfter === groupBefore) fail(`ArrowDown on the picker stayed in section ${JSON.stringify(groupBefore)}`);
key(pick, 'ArrowLeft'); key(pick, 'ArrowUp');

// (d) crumb carries the number (primer fixtures only — their [N] is the
// primer's own place; the corpus's crumb is checked separately below).
if (crumb) {
  const primerFirst = primerOptions[0];
  if (primerFirst) {
    pick.value = primerFirst.value;
    pick.dispatchEvent(new win.Event('change', { bubbles: true }));
    const num = /^\[(\d+)\]/.exec(primerFirst.textContent)[1];
    if (!crumb.textContent.includes(`[${num}]`)) fail(`breadcrumb ${JSON.stringify(crumb.textContent)} does not name example [${num}]`);
  }
}

// (c) never in an editor
const before = pick.value;
for (const ed of [input, doc]) {
  ed.focus();
  key(ed, 'ArrowRight');
  if (pick.value !== before) fail(`ArrowRight inside the ${ed.id} textarea changed the selected example`);
}

console.log(`test-playground-nav: OK — ${primer.length} primer fixtures + ${Object.keys(programExamples).length} corpus examples across the two reading tabs (#1743), each tab showing its editors (#1741); numbered primer options naming their fixture ids; arrows step examples and sections from the picker, never from an editor; crumb names the number.`);
