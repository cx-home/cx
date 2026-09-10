// scripts/test_playground_nav.mjs — the playground NAVIGATION gate (#1380).
//
// WHAT IT ASSERTS, against the SHIPPED playground.html + playground.js in a
// jsdom document (no wasm, no browser):
//   (a) every picker option keeps its authored `[NNN]` number — the number is
//       how the owner, the issues and the notes name an example;
//   (b) the arrow keys work FROM THE PICKER: after an example is chosen the
//       <select> holds focus, and a `keydown` ArrowRight there must move to
//       the next example, ArrowDown to the next subcategory;
//   (c) the keys never hijack the editor: an ArrowRight in the source
//       textarea leaves the selection alone;
//   (d) the breadcrumb names the example's number.
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
win.eval(readFileSync(resolve(PLAYGROUND, 'playground.examples.js'), 'utf8'));
win.eval(readFileSync(JS, 'utf8'));

const pick = win.document.getElementById('cxp-pick');
const input = win.document.getElementById('cxp-input') || win.document.querySelector('textarea');
const crumb = win.document.getElementById('cxp-crumb');
if (!pick) setupFail('no #cxp-pick in playground.html');
if (!input) setupFail('no source textarea in playground.html');

const options = [...pick.querySelectorAll('option')].filter(o => !o.disabled);
if (options.length < 3) setupFail(`picker holds ${options.length} options`);

// (a) numbers
const unnumbered = options.filter(o => !/^\[\d+\]\s/.test(o.textContent));
if (unnumbered.length) fail(`${unnumbered.length} picker option(s) lost their [NNN] number, e.g. ${JSON.stringify(unnumbered[0].textContent)}`);

function key(target, k) {
  const ev = new win.KeyboardEvent('keydown', { key: k, bubbles: true, cancelable: true });
  target.dispatchEvent(ev);
  return ev.defaultPrevented;
}
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
if (groupAfter === groupBefore) fail(`ArrowDown on the picker stayed in subcategory ${JSON.stringify(groupBefore)}`);
key(pick, 'ArrowLeft'); key(pick, 'ArrowUp');

// (d) crumb carries the number
if (crumb) {
  const sel = pick.selectedOptions[0];
  const num = /^\[(\d+)\]/.exec(sel.textContent)[1];
  if (!crumb.textContent.includes(`[${num}]`)) fail(`breadcrumb ${JSON.stringify(crumb.textContent)} does not name example [${num}]`);
}

// (c) never in the editor
const before = pick.value;
input.focus();
key(input, 'ArrowRight');
if (pick.value !== before) fail('ArrowRight inside the source textarea changed the selected example');

console.log(`test-playground-nav: OK — ${options.length} numbered options; arrows step examples and subcategories from the picker, never from the editor; crumb names the number.`);
