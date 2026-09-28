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
//   (2) the page PRINTS ON LOAD: with no link, the first Program example is
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
//   (5) the three READINGS: Document shows the document editor alone,
//       Query both, Program the program editor alone;
//   (6) an ERROR IS A VALUE: a program the engine refuses prints an
//       `[err …]` value in the CX pane, projected to JSON too — never an
//       empty pane or a crash banner alone;
//   (7) SHARE-BY-URL round-trips: edited text shared from the Program and
//       Query readings reopens, from the link alone, as the same reading
//       and the same text.
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
// Open one example through the page's own controls: its reading tab, then
// the picker's `change` — the two things a reader does.
async function open(e) {
  await evalJs(`(() => {
    document.querySelector('.cxp-reading-tab[data-reading="${e.reading}"]').click();
    const pick = document.getElementById('cxp-pick');
    pick.value = ${JSON.stringify(`primer:${e.id}`)};
    pick.dispatchEvent(new Event('change', { bubbles: true }));
  })()`, 20000);
  return waitFor(s => s.pick === `primer:${e.id}` && s.match !== '', `the answer for ${e.id}`);
}

// (2) prints on load — an ANSWER, not a refusal: the page opens on the first
// Program example a reader should write and the engine runs (not the wrong
// half of an anti-pattern pair, not terminal-only, not marked wasm-unsupported,
// and not a fixture whose recorded answer is itself an [err …] value).
{
  const opening = (e) => e.reading === 'program' && e.role !== 'wrong' && e.runnable !== false
    && !(typeof e.wasmUnsupported === 'string' && e.wasmUnsupported.trim())
    && !/^\s*\[err\b/.test(e.expected || '');
  const first = EXAMPLES.find(opening) || { id: '(none)', n: 0, expected: '' };
  if (first.id === '(none)') fail('no primer Program example qualifies to open the page (every one is a wrong half, terminal-only, unsupported or an [err] answer)');
  const s = await waitFor(s => s.match !== '', 'the first run');
  const before = failures.length;
  if (s.pick !== `primer:${first.id}`) fail(`on load the picker holds ${s.pick}, expected the first Program example a reader should write, primer:${first.id}`);
  if (!s.cx.trim()) fail('on load the CX pane is empty — the page did not print an answer');
  if (/^\s*\[err\b/.test(s.cx)) fail(`on load the page printed a refusal, not an answer: ${s.cx.split('\n')[0]}`);
  if (s.match !== 'yes') fail(`on load ${first.id} answered ${JSON.stringify(s.cx)}; the fixture records ${JSON.stringify(first.expected)}`);
  else if (failures.length === before) console.log(`  ok   prints on load: [${first.n}] ${first.id} → ${s.cx.split('\n')[0]}`);
}

// (3, second half) every option names its fixture id
{
  const opts = JSON.parse(await evalJs(`(() => {
    const out = {};
    for (const r of ['document', 'query', 'program']) {
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
  const total = Object.values(opts).reduce((n, l) => n + l.length, 0);
  if (total !== EXAMPLES.length) fail(`the three pickers hold ${total} options for ${EXAMPLES.length} primer examples`);
  else console.log(`  ok   ${total} picker options, one per primer fixture, each naming its id`);
}

// (4) + (5) every example through the page's own controls
const counts = { match: 0, terminal: 0, marked: 0 };
const terminalOnly = [], marked = [];
for (const e of EXAMPLES) {
  const s = await open(e);
  const want = { document: [false, true], query: [false, false], program: [true, false] }[e.reading];
  if (s.reading !== e.reading) fail(`${e.id}: the page is in the ${s.reading} reading, the fixture's is ${e.reading}`);
  if (s.docHidden !== want[0] || s.progHidden !== want[1]) {
    fail(`${e.id}: the ${e.reading} reading shows document=${!s.docHidden} program=${!s.progHidden}`);
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
console.log(`  ok   readings: every example opened in its own reading with the editors that reading needs`);

// (6) an error is a value
{
  const refusal = EXAMPLES.find(e => e.runnable !== false && !e.wasmUnsupported && e.match === 'contains' && e.reading === 'program');
  if (!refusal) fail('no primer example records a refusal — (6) has nothing to grade');
  else {
    const s = await open(refusal);
    if (!/^\s*\[err\b/.test(s.cx)) fail(`${refusal.id}: a refusal printed ${JSON.stringify(s.cx.slice(0, 160))}, not an [err …] value`);
    else if (!s.json.trim() || /projection failed/.test(s.json)) fail(`${refusal.id}: the [err] value has no JSON projection (${JSON.stringify(s.json.slice(0, 120))})`);
    else console.log(`  ok   an error is a value: ${refusal.id} → ${s.cx.split('\n')[0].slice(0, 90)}`);
  }
}

// (7) share-by-URL, from the link alone
async function shareRoundTrip(r, edit) {
  const first = EXAMPLES.find(e => e.reading === r && e.runnable !== false && !e.wasmUnsupported);
  await open(first);
  const edited = await evalJs(`(() => {
    const p = document.getElementById('cxp-input'), d = document.getElementById('cxp-doc');
    ${edit}
    p.dispatchEvent(new Event('input', { bubbles: true }));
    d.dispatchEvent(new Event('input', { bubbles: true }));
    document.getElementById('cxp-share').click();
    return JSON.stringify({ prog: p.value, doc: d.value });
  })()`, 20000).then(JSON.parse);
  const link = (await waitFor(s => /^#r=/.test(s.hash), `the share link (${r})`)).hash;
  // Reopen from the link alone: clear the panes, then hand the page the link.
  await evalJs(`(() => {
    for (const k of ['cx', 'json', 'xml']) document.getElementById('cxp-out-' + k).querySelector('code').dataset.raw = '';
    history.replaceState(null, '', '#');
    location.hash = ${JSON.stringify(link)};
  })()`, 20000);
  const s = await waitFor(s => s.hash === link && s.cx !== '', `the reopened link (${r})`);
  if (s.reading !== r) fail(`share (${r}): the link reopened the ${s.reading} reading`);
  if (r !== 'document' && s.prog !== edited.prog) fail(`share (${r}): the program came back ${JSON.stringify(s.prog.slice(0, 80))}`);
  if (r !== 'program' && s.doc !== edited.doc) fail(`share (${r}): the document came back ${JSON.stringify(s.doc.slice(0, 80))}`);
  else console.log(`  ok   share (${r}): a ${link.length}-char link reopens the same reading and text → ${s.cx.split('\n')[0].slice(0, 60)}`);
}
await shareRoundTrip('program', `p.value = '[?let [= $x "é — ünïcode"] [shared text=$x n=[+ 40 2]]]';`);
await shareRoundTrip('query', `d.value = '[users [user [name Ada] [email ada@x.org]]]';`);

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
