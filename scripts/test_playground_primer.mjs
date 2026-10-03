// scripts/test_playground_primer.mjs — the playground PRIMER gate (PLAY-1).
//
// WHAT IT ASSERTS, in headless Chrome against a served docroot — the staged
// preview (dist/playground-preview/, `make build-playground`), or with
// CX_PLAYGROUND_ROOT=site the assembled site `make site` builds, which is
// what the Site workflow uploads to cxhome.org:
//
//   (1) the ENGINE LOADS: the page's cxlib becomes ready on the JSPI bundle
//       (browser_harness.mjs asserts which bundle) — cxhome.org answered 404
//       for wasm/cxlib.js before PLAY-1, and the page loaded with no engine;
//   (2) the page PRINTS ON LOAD: with no link, the first code example is
//       loaded and run, and its answer is the fixture's recorded answer;
//   (3) the picker is the PRIMER: the page's examples are the file the tree
//       generates (scripts/gen_guide/playground/playground.primer.js, byte
//       for byte), each picker option names its fixture id, and the fixture
//       strip names the id and the suite;
//   (4) every primer example, loaded THROUGH THE PAGE'S OWN CONTROLS (its
//       reading tab, then the picker's `change`), answers what its fixture
//       records — exact, or by the fixture's CXER code for a recorded
//       refusal — unless the fixture itself says the browser cannot run it
//       (`runnable: false`: program arguments, an XML input), which is
//       counted and named, never graded as a pass;
//   (5) the READINGS are the page's own reading tabs (PLAY-3: data and
//       code — read from the page, never a list of this file's), every
//       primer example's reading is one of them and every tab holds a
//       primer example: Data shows the document editor alone; Code shows
//       the program editor, and the document editor beside it exactly when
//       the example reads a real document (PLAY-3's former query);
//   (6) an ERROR IS A VALUE: a program the engine refuses prints an
//       `[err …]` value in the CX pane, projected to JSON too — never an
//       empty pane or a crash banner alone;
//   (7) SHARE-BY-URL round-trips: edited text shared from the Data
//       reading, from the Code reading, and from a Code example that reads
//       a document reopens, from the link alone, as the same reading and
//       the same text in every editor that reading shows.
//
// Exit 0 iff all hold; 1 on any failure; 2 on a setup problem (no staged
// docroot, no Chromium-family browser) — never a silent skip.
//
// Usage: node scripts/test_playground_primer.mjs [--verbose]
//   CX_PLAYGROUND_ROOT=<dir>  the docroot to serve (default dist/playground-preview)
//   CX_CHROME=<browser>       CX_BIN=<cx that runs scripts/serve_static.cx>
//   PRIMER_GATE_DEADLINE=<s>  whole-run bound (default 600)

import { readFileSync, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { createHarness, PREVIEW, PLAYGROUND, ROOT } from './playground-gate/browser_harness.mjs';

const VERBOSE = process.argv.includes('--verbose');
const DOCROOT = PREVIEW;   // CX_PLAYGROUND_ROOT, read by the harness
const DEADLINE = 1000 * Number(process.env.PRIMER_GATE_DEADLINE || 600);
const H = createHarness({ label: 'playground-primer', deadlineMs: DEADLINE });

const failures = [];
const fail = (m) => { failures.push(m); console.log(`  FAIL ${m}`); };

// (3, first half) the served examples file IS the tree's generated file.
const served = join(DOCROOT, 'playground/playground.primer.js');
if (!existsSync(served)) H.setupFail(`${served} is not staged.`, 'make build-playground, or make site');
const treeFile = readFileSync(resolve(PLAYGROUND, 'playground.primer.js'), 'utf8');
for (const f of ['playground.primer.js', 'playground.js', 'playground.css']) {
  const s = join(DOCROOT, 'playground', f);
  if (!existsSync(s) || readFileSync(s, 'utf8') !== readFileSync(resolve(PLAYGROUND, f), 'utf8')) {
    H.setupFail(`the served ${s.replace(ROOT + '/', '')} is not scripts/gen_guide/playground/${f} — the docroot is stale`,
                'rebuild it (make guide / make build-playground / make site)');
  }
}
const fakeWindow = {};
new Function('window', treeFile)(fakeWindow);
const EXAMPLES = ((fakeWindow.cxPlaygroundPrimer || {}).examples) || [];
if (EXAMPLES.length === 0) H.setupFail('playground.primer.js yields no examples.', 'make docs');

const { evalJs, close } = await H.bootPage({
  portBase: 9990, cdpBase: 10300, needNative: false, verbose: VERBOSE, root: DOCROOT,
});
console.log(`[playground-primer] docroot:  ${DOCROOT.replace(ROOT + '/', '')}`);
console.log(`[playground-primer] examples: ${EXAMPLES.length}\n`);

// The page's visible state, read through the DOM a reader sees. A read
// that lands mid-reload (the page restarts its engine by reloading itself)
// is retried rather than failed.
const state = () => evalJs(`JSON.stringify({
  reading: document.body.dataset.reading,
  pick: document.getElementById('cxp-pick').value,
  cx: document.getElementById('cxp-out-cx').querySelector('code').dataset.raw || '',
  json: document.getElementById('cxp-out-json').querySelector('code').dataset.raw || '',
  match: document.getElementById('cxp-verdict').dataset.match || '',
  fixture: document.getElementById('cxp-fixture').textContent,
  doc: document.getElementById('cxp-doc').value,
  prog: document.getElementById('cxp-input').value,
  docHidden: document.getElementById('cxp-doc-block').hidden,
  progHidden: document.getElementById('cxp-prog-block').hidden,
  running: document.getElementById('cxp-run').classList.contains('is-running'),
  ready: !!(globalThis.cxlib && document.body.dataset.ran),
  restarts: Number(sessionStorage.getItem('cxp.restarts') || 0),
  hash: location.hash,
})`, 20000).then(JSON.parse);
async function waitFor(pred, what) {
  let last = null;
  for (let i = 0; i < 1200; i++) {
    H.checkDeadline(what);
    try {
      last = await state();
      if (last.ready && !last.running && pred(last)) return last;
    } catch (_) { /* the page is reloading */ }
    await new Promise(r => setTimeout(r, 100));
  }
  throw new Error(`the page never reached: ${what} (last: ${JSON.stringify(last).slice(0, 300)})`);
}
// A primer example "reads a document" by the page's own rule
// (playground.js updateDocVisibility): a code example whose document is
// real text, not blank, keeps the document editor shown beside the program.
const readsDoc = (e) => Boolean(e.doc && e.doc.trim() !== '');
// Open one example through the page's own controls: its reading tab, then
// the picker's `change` — the two things a reader does. An example whose
// reading has no tab on the page is a FAIL by name (never a TypeError).
async function open(e) {
  const tabbed = await evalJs(`(() => {
    const tab = document.querySelector(${JSON.stringify(`.cxp-reading-tab[data-reading="${e.reading}"]`)});
    if (!tab) return 'no-tab';
    tab.click();
    const pick = document.getElementById('cxp-pick');
    pick.value = ${JSON.stringify(`primer:${e.id}`)};
    pick.dispatchEvent(new Event('change', { bubbles: true }));
    return 'ok';
  })()`, 20000);
  if (tabbed === 'no-tab') { fail(`${e.id}: the page has no ${e.reading} reading tab to open it through`); return null; }
  return waitFor(s => s.pick === `primer:${e.id}` && s.match !== '', `the answer for ${e.id}`);
}

// (2) prints on load — an ANSWER, not a refusal: the page opens on the first
// code example a reader should write and the engine runs (not the wrong
// half of an anti-pattern pair, not terminal-only, not marked wasm-unsupported,
// and not a fixture whose recorded answer is itself an [err …] value).
{
  const opening = (e) => e.reading === 'code' && e.role !== 'wrong' && e.runnable !== false
    && !(typeof e.wasmUnsupported === 'string' && e.wasmUnsupported.trim())
    && !/^\s*\[err\b/.test(e.expected || '');
  const first = EXAMPLES.find(opening) || { id: '(none)', n: 0, expected: '' };
  if (first.id === '(none)') fail('no primer code example qualifies to open the page (every one is a wrong half, terminal-only, unsupported or an [err] answer)');
  const s = await waitFor(s => s.match !== '', 'the first run');
  const before = failures.length;
  if (s.pick !== `primer:${first.id}`) fail(`on load the picker holds ${s.pick}, expected the first code example a reader should write, primer:${first.id}`);
  if (!s.cx.trim()) fail('on load the CX pane is empty — the page did not print an answer');
  if (/^\s*\[err\b/.test(s.cx)) fail(`on load the page printed a refusal, not an answer: ${s.cx.split('\n')[0]}`);
  if (s.match !== 'yes') fail(`on load ${first.id} answered ${JSON.stringify(s.cx)}; the fixture records ${JSON.stringify(first.expected)}`);
  else if (failures.length === before) console.log(`  ok   prints on load: [${first.n}] ${first.id} → ${s.cx.split('\n')[0]}`);
}

// (5, first half) the readings are the page's own tabs (PLAY-3: data and
// code), read from the page; every primer example's reading is one of
// them and every tab holds at least one primer example.
const READINGS = JSON.parse(await evalJs(`JSON.stringify(
  [...document.querySelectorAll('.cxp-reading-tab')].map(t => t.dataset.reading || ''))`, 20000));
{
  const before = failures.length;
  if (READINGS.length === 0) fail('the page has no reading tabs');
  if (new Set(READINGS).size !== READINGS.length) fail(`the page's reading tabs repeat a reading: ${JSON.stringify(READINGS)}`);
  const exampleReadings = [...new Set(EXAMPLES.map(e => e.reading))];
  for (const r of exampleReadings) {
    if (!READINGS.includes(r)) fail(`primer examples are filed under the ${JSON.stringify(r)} reading, which has no tab on the page (tabs: ${READINGS.join(', ')})`);
  }
  for (const r of READINGS) {
    if (!exampleReadings.includes(r)) fail(`the page's ${JSON.stringify(r)} reading tab holds no primer example`);
  }
  if (failures.length === before) {
    const n = (r) => EXAMPLES.filter(e => e.reading === r).length;
    console.log(`  ok   readings from the page: ${READINGS.map(r => `${r} (${n(r)})`).join(', ')}`);
  }
}

// (3, second half) every primer option names its fixture id. The picker
// also offers the playground corpus beside the primer (PLAY-3, #1743:
// `legacy:<key>` options, graded by test-playground-nav); the count here is
// the primer's options, one per fixture across the readings.
{
  const opts = JSON.parse(await evalJs(`(() => {
    const out = {};
    for (const r of ${JSON.stringify(READINGS)}) {
      document.querySelector('.cxp-reading-tab[data-reading="' + r + '"]').click();
      out[r] = [...document.getElementById('cxp-pick').options].map(o => [o.value, o.textContent]);
    }
    return JSON.stringify(out);
  })()`, 30000));
  for (const e of EXAMPLES) {
    const row = (opts[e.reading] || []).find(([v]) => v === `primer:${e.id}`);
    if (!row) fail(`the ${e.reading} picker has no option for ${e.id}`);
    else if (!row[1].includes(e.id)) fail(`the option for ${e.id} does not name its fixture id: ${JSON.stringify(row[1])}`);
  }
  const primerOpts = Object.values(opts).flat().filter(([v]) => v.startsWith('primer:'));
  const total = primerOpts.length;
  const ids = new Set(EXAMPLES.map(e => `primer:${e.id}`));
  for (const [v] of primerOpts) if (!ids.has(v)) fail(`the picker offers ${v}, which is not a primer fixture of playground.primer.js`);
  if (total !== EXAMPLES.length) fail(`the ${READINGS.length} pickers hold ${total} primer options for ${EXAMPLES.length} primer examples`);
  else console.log(`  ok   ${total} primer picker options across ${READINGS.length} readings, one per primer fixture, each naming its id`);
}

// (4) + (5) every example through the page's own controls
const counts = { match: 0, terminal: 0, marked: 0 };
const terminalOnly = [], marked = [];
const shownBy = {};   // "<reading> document=<b> program=<b>" → examples opened so
for (const e of EXAMPLES) {
  const s = await open(e);
  if (!s) continue;
  // The editors a reading shows (PLAY-3): data the document alone; code the
  // program, with the document beside it exactly when the example reads one.
  const wantDoc = e.reading === 'data' || readsDoc(e);
  const wantProg = e.reading !== 'data';
  if (s.reading !== e.reading) fail(`${e.id}: the page is in the ${s.reading} reading, the fixture's is ${e.reading}`);
  if (s.docHidden !== !wantDoc || s.progHidden !== !wantProg) {
    fail(`${e.id}: the ${e.reading} reading shows document=${!s.docHidden} program=${!s.progHidden}, expected document=${wantDoc} program=${wantProg}`);
  } else {
    const k = `${e.reading} document=${wantDoc} program=${wantProg}`;
    shownBy[k] = (shownBy[k] || 0) + 1;
  }
  if (!s.fixture.includes(e.id) || !s.fixture.includes(e.suite)) fail(`${e.id}: the fixture strip does not name the id and the suite: ${JSON.stringify(s.fixture)}`);
  if (s.doc !== e.doc || s.prog !== e.src) fail(`${e.id}: the editors do not hold the fixture's text`);
  if (e.runnable === false) {
    counts.terminal++;
    terminalOnly.push(`${e.id} (${e.why})`);
    if (VERBOSE) console.log(`  term ${e.id} — ${e.why}`);
    continue;
  }
  if (e.wasmUnsupported) {
    // A declared difference (primer_wasm.cxd) is graded too: a marker the
    // engine no longer needs is a false sentence on the page.
    if (s.match === 'yes') fail(`${e.id} is listed in primer_wasm.cxd as one the engine cannot reproduce, but it answers as its fixture records — drop the row`);
    else { counts.marked++; marked.push(e.id); if (VERBOSE) console.log(`  mark ${e.id} — ${e.wasmUnsupported}`); }
    continue;
  }
  if (s.match === 'yes') {
    counts.match++;
    if (VERBOSE) console.log(`  ok   [${e.n}] ${e.id}`);
  } else {
    fail(`${e.id} (${e.reading}): this engine answers ${JSON.stringify(s.cx.slice(0, 240))}; the fixture records (${e.match}) ${JSON.stringify(e.expected.slice(0, 240))}`);
  }
}
console.log(`  ok   readings: every example opened in its own reading with the editors that reading needs — `
  + Object.entries(shownBy).map(([k, n]) => `${n} × ${k}`).join('; '));

// (6) an error is a value
{
  const refusal = EXAMPLES.find(e => e.runnable !== false && !e.wasmUnsupported && e.match === 'contains' && e.reading === 'code');
  if (!refusal) fail('no primer example records a refusal — (6) has nothing to grade');
  else {
    const s = await open(refusal);
    if (!s) { /* named by open() */ }
    else if (!/^\s*\[err\b/.test(s.cx)) fail(`${refusal.id}: a refusal printed ${JSON.stringify(s.cx.slice(0, 160))}, not an [err …] value`);
    else if (!s.json.trim() || /projection failed/.test(s.json)) fail(`${refusal.id}: the [err] value has no JSON projection (${JSON.stringify(s.json.slice(0, 120))})`);
    else console.log(`  ok   an error is a value: ${refusal.id} → ${s.cx.split('\n')[0].slice(0, 90)}`);
  }
}

// (7) share-by-URL, from the link alone — from each reading the page has,
// and from a code example that reads a document (both editors shown, both
// texts in the link). `what` names the case; `pickBy` chooses the example.
async function shareRoundTrip(what, r, pickBy, edit) {
  const first = EXAMPLES.find(e => e.reading === r && e.runnable !== false && !e.wasmUnsupported && pickBy(e));
  if (!first) { fail(`share (${what}): no runnable primer example to share from`); return; }
  if (!(await open(first))) return;
  const edited = await evalJs(`(() => {
    const p = document.getElementById('cxp-input'), d = document.getElementById('cxp-doc');
    ${edit}
    p.dispatchEvent(new Event('input', { bubbles: true }));
    d.dispatchEvent(new Event('input', { bubbles: true }));
    document.getElementById('cxp-share').click();
    return JSON.stringify({ prog: p.value, doc: d.value });
  })()`, 20000).then(JSON.parse);
  const link = (await waitFor(s => /^#r=/.test(s.hash), `the share link (${what})`)).hash;
  // Reopen from the link alone: clear the panes, then hand the page the link.
  await evalJs(`(() => {
    for (const k of ['cx', 'json', 'xml']) document.getElementById('cxp-out-' + k).querySelector('code').dataset.raw = '';
    history.replaceState(null, '', '#');
    location.hash = ${JSON.stringify(link)};
  })()`, 20000);
  const s = await waitFor(s => s.hash === link && s.cx !== '', `the reopened link (${what})`);
  const before = failures.length;
  const showsDoc = r === 'data' || readsDoc(first);
  const showsProg = r !== 'data';
  if (s.reading !== r) fail(`share (${what}): the link reopened the ${s.reading} reading`);
  if (s.docHidden !== !showsDoc || s.progHidden !== !showsProg) fail(`share (${what}): the reopened link shows document=${!s.docHidden} program=${!s.progHidden}`);
  if (showsProg && s.prog !== edited.prog) fail(`share (${what}): the program came back ${JSON.stringify(s.prog.slice(0, 80))}`);
  if (showsDoc && s.doc !== edited.doc) fail(`share (${what}): the document came back ${JSON.stringify(s.doc.slice(0, 80))}`);
  if (failures.length === before) console.log(`  ok   share (${what}): a ${link.length}-char link reopens the same reading and text → ${s.cx.split('\n')[0].slice(0, 60)}`);
}
for (const r of READINGS) {
  if (r === 'data') {
    await shareRoundTrip('data', r, () => true, `d.value = '[users [user [name Ada] [email ada@x.org]]]';`);
  } else {
    await shareRoundTrip(r, r, e => !readsDoc(e), `p.value = '[?let [= $x "é — ünïcode"] [shared text=$x n=[+ 40 2]]]';`);
    if (EXAMPLES.some(e => e.reading === r && readsDoc(e))) {
      await shareRoundTrip(`${r} with its document`, r, readsDoc, `d.value = '[users [user [name Ada] [email ada@x.org]]]';`);
    }
  }
}

const restarts = (await state()).restarts;
close();
console.log(`\n[playground-primer] ${EXAMPLES.length} primer examples: ${counts.match} answer as their fixture records, `
  + `${counts.marked} declared engine differences (primer_wasm.cxd), ${counts.terminal} terminal-only by the fixture's own invocation; `
  + `${restarts} engine restart(s) in one page session; ${failures.length} failure(s)`);
if (marked.length) console.log(`  declared differences: ${marked.join(', ')}`);
if (terminalOnly.length) console.log(`  terminal-only: ${terminalOnly.join('; ')}`);
if (failures.length) {
  console.log('FAIL — see the FAIL lines above.');
  process.exit(1);
}
console.log('OK — the engine loads, the page prints on load, and every primer example answers as its fixture records or says why it cannot.');
process.exit(0);
