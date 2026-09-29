// scripts/test_playground_nav.mjs — the playground NAVIGATION gate (#1380,
// PLAY-1).
//
// WHAT IT ASSERTS, against the SHIPPED playground.html + playground.js in a
// jsdom document (no wasm, no browser):
//   (a) every picker option keeps its `[N]` number — since PLAY-1 the
//       example's place in the primer — and names its fixture id;
//   (b) the arrow keys work FROM THE PICKER: after an example is chosen the
//       <select> holds focus, and a `keydown` ArrowRight there must move to
//       the next example, ArrowDown to the next primer section;
//   (c) the keys never hijack an editor: an ArrowRight in the program or
//       the document textarea leaves the selection alone;
//   (d) the breadcrumb names the example's number;
//   (e) the three READING tabs (PLAY-1): each lists exactly that reading's
//       primer examples, and shows the editors that reading needs —
//       Data the document alone, Query both, Code the program alone.
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

// (e) the readings
for (const r of ['data', 'query', 'code']) {
  if (!tab(r)) setupFail(`no reading tab for ${r}`);
  tab(r).click();
  const values = [...pick.querySelectorAll('option')].map(o => o.value);
  const want = primer.filter(p => p.reading === r).map(p => `primer:${p.id}`);
  if (JSON.stringify(values) !== JSON.stringify(want)) {
    fail(`the ${r} tab lists ${values.length} option(s), expected that reading's ${want.length} primer examples in primer order`);
  }
  const docShown = !win.document.getElementById('cxp-doc-block').hidden;
  const progShown = !win.document.getElementById('cxp-prog-block').hidden;
  const expect = { data: [true, false], query: [true, true], code: [false, true] }[r];
  if (docShown !== expect[0] || progShown !== expect[1]) {
    fail(`the ${r} reading shows document=${docShown} program=${progShown}, expected document=${expect[0]} program=${expect[1]}`);
  }
}

tab('query').click();
const options = [...pick.querySelectorAll('option')].filter(o => !o.disabled);
if (options.length < 3) setupFail(`picker holds ${options.length} options`);

// (a) numbers and ids
const unnumbered = options.filter(o => !/^\[\d+\]\s/.test(o.textContent));
if (unnumbered.length) fail(`${unnumbered.length} picker option(s) lost their [N] number, e.g. ${JSON.stringify(unnumbered[0].textContent)}`);
const unnamed = options.filter(o => !o.textContent.includes(o.value.replace(/^primer:/, '')));
if (unnamed.length) fail(`${unnamed.length} picker option(s) do not name their fixture id, e.g. ${JSON.stringify(unnamed[0].textContent)}`);

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

// (d) crumb carries the number
if (crumb) {
  const sel = pick.selectedOptions[0];
  const num = /^\[(\d+)\]/.exec(sel.textContent)[1];
  if (!crumb.textContent.includes(`[${num}]`)) fail(`breadcrumb ${JSON.stringify(crumb.textContent)} does not name example [${num}]`);
}

// (c) never in an editor
const before = pick.value;
for (const ed of [input, doc]) {
  ed.focus();
  key(ed, 'ArrowRight');
  if (pick.value !== before) fail(`ArrowRight inside the ${ed.id} textarea changed the selected example`);
}

console.log(`test-playground-nav: OK — ${primer.length} primer examples across the three reading tabs, each tab showing its editors; numbered options naming their fixture ids; arrows step examples and sections from the picker, never from an editor; crumb names the number.`);
