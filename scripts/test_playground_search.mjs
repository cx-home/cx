// scripts/test_playground_search.mjs — the playground SEARCH gate (#1742).
//
// WHAT IT ASSERTS, against the SHIPPED playground.html + playground.js in a
// jsdom document (no wasm, no browser):
//   for each of three terms (flow, for, sequence — the owner's own words,
//   2026-10-01: "I can't find all examples that match a term such as 'flow'
//   or 'for' or 'sequence'"), typing the term into #cxp-search must list AT
//   LEAST as many results as a plain grep of the term over every OFFERED
//   example's own source text (primer `src`/`doc`, corpus `input`) — the
//   search also matches id, title, output and reading, so it can only ever
//   find MORE than the source-only grep, never fewer (PLAY-3, amending
//   PLAY-1/PLAY-2's dropped search; sibling of #1743).
//
// Usage: node scripts/test_playground_search.mjs   (jsdom from scripts/playground-gate)
//   CX_PLAYGROUND_JS=/path/to/playground.js overrides the script under test

import { createRequire } from 'node:module';
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const ROOT = resolve(import.meta.dirname, '..');
const PLAYGROUND = resolve(ROOT, 'scripts/gen_guide/playground');
const GATE_MODULES = resolve(ROOT, 'scripts/playground-gate/node_modules');
const JS = process.env.CX_PLAYGROUND_JS || resolve(PLAYGROUND, 'playground.js');

function fail(msg) { console.error(`test-playground-search: FAIL — ${msg}`); process.exit(1); }
function setupFail(msg, hint) {
  console.error(`test-playground-search: SETUP FAILURE — ${msg}`);
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
win.eval(readFileSync(resolve(PLAYGROUND, 'playground.primer.js'), 'utf8'));
win.eval(readFileSync(resolve(PLAYGROUND, 'playground.examples.js'), 'utf8'));
win.eval(readFileSync(JS, 'utf8'));

const primer = (win.cxPlaygroundPrimer || {}).examples || [];
const programExamples = (win.cxPlaygroundExamples || {}).program || {};
if (primer.length === 0) setupFail('playground.primer.js yielded no examples', 'make docs');
if (Object.keys(programExamples).length === 0) setupFail('playground.examples.js yielded no examples', 'make guide');

const searchEl = win.document.getElementById('cxp-search');
const resultsEl = win.document.getElementById('cxp-search-results');
if (!searchEl) setupFail('no #cxp-search in playground.html — the full-text search box is missing (#1742)');
if (!resultsEl) setupFail('no #cxp-search-results in playground.html');

// The floor: a plain grep of the term over every offered example's OWN
// source text (primer src/doc, corpus input) — case-insensitive.
function grepFloor(term) {
  const t = term.toLowerCase();
  let n = 0;
  for (const p of primer) {
    const hay = `${p.src || ''}\n${p.doc || ''}`.toLowerCase();
    if (hay.includes(t)) n++;
  }
  for (const k of Object.keys(programExamples)) {
    const hay = String(programExamples[k].input || '').toLowerCase();
    if (hay.includes(t)) n++;
  }
  return n;
}

function search(term) {
  searchEl.value = term;
  searchEl.dispatchEvent(new win.Event('input', { bubbles: true }));
  if (resultsEl.hidden) fail(`searching "${term}" left the results list hidden`);
  return [...resultsEl.querySelectorAll('.cxp-search-result')];
}

for (const term of ['flow', 'for', 'sequence']) {
  const floor = grepFloor(term);
  if (floor === 0) setupFail(`grep floor for "${term}" is 0 — the fixture corpus does not name it; pick another term`);
  const results = search(term);
  if (results.length < floor) {
    fail(`"${term}" found ${results.length} example(s), fewer than the ${floor} a plain grep over the examples' own source finds`);
  }
  // Every result names its reading (data/code), beside the picker's words.
  const unbadged = results.filter((li) => !/data|code/i.test(li.textContent));
  if (unbadged.length) fail(`"${term}": ${unbadged.length} result(s) do not carry a reading badge`);
  console.log(`test-playground-search: "${term}" — ${results.length} result(s), >= the ${floor}-example source grep`);
}

// Opening a result loads it (id ends up in the location hash) and clears
// the search box, so a reader is never left looking at a stale list.
const seqResults = search('sequence');
const first = seqResults[0];
if (!first) setupFail('no result to open for "sequence"');
first.dispatchEvent(new win.MouseEvent('click', { bubbles: true }));
if (searchEl.value !== '') fail('opening a search result left the search box carrying the old query');
if (resultsEl.hidden !== true) fail('opening a search result left the results list open');
if (!/^#ex=/.test(win.location.hash)) fail(`opening a search result did not navigate to an example (hash: ${JSON.stringify(win.location.hash)})`);

// No separate query grouping leaks into a result's reading badge (#1741).
const allBadges = [...resultsEl.querySelectorAll('.cxp-search-result-reading')].map((b) => b.textContent);
search('e');
const anyQuery = [...resultsEl.querySelectorAll('.cxp-search-result-reading')].some((b) => /query/i.test(b.textContent));
if (anyQuery) fail('a search result carries a "query" reading badge — PLAY-3 amends PLAY-2\'s three readings to two (#1741)');

console.log('test-playground-search: OK — flow/for/sequence each find at least the source grep\'s examples, beside the picker, opening on a click, in the two readings\' words.');
