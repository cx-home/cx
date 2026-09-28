// scripts/test_playground_tree.mjs — the playground TREE PANE gate (#1049).
//
// WHAT IT ASSERTS. A pinned set of examples is loaded into the real page,
// through the page's own controls, and its TREE is rendered at each Detail
// rung by the page's own `renderTree` over the page's own `cxlib.tree()`.
// What the DOM then contains is compared against a committed fixture:
// row counts, chip counts, the exact `(+K more attrs)` overflow note, the
// one-row value-leaf rule, the `?name` spelling of directives, and the
// click-bridge round-trip in both directions.
//
// WHY IT EXISTS. #1001's element branch read `node.attrs` / `node.items` —
// fields the `cxlib.tree()` contract does not carry — so it was DEAD CODE,
// and `Detail` had no observable effect on the Tree at any rung. It sat
// inert through the whole #992 quality package. It survived because
// NOTHING RENDERS THE TREE:
//
//   make test-playground-mermaid   parses DIAGRAMS (2,070 of them). Never
//                                  calls renderTree.
//   make test-playground-wasm-eval evaluates the corpus in the shipped
//                                  engine. Never calls renderTree.
//   scripts/test_playground_smoke  serves the bundle and checks ASSETS.
//                                  Never calls renderTree.
//
// #1001's own close-out (TD-7 in ledger/rulings_2026_08_26_playground_
// tree_detail_1001.md) recorded that gap as open rather than glossing it.
// This is that gate. TD-1..TD-7 is its specification; each assertion below
// names the rung of the ruling it holds.
//
// WHAT MAKES IT HARD TO FOOL. The gate does not call renderTree, or import
// playground.js, or reconstruct the expected HTML. It drives the CONTROLS a
// reader touches — the example picker's `change`, the Detail select's
// `change`, the Source and Tree tab clicks — and reads the DOM those
// handlers produced. So a defect anywhere between the control and the
// pixel reddens it, including the #1001 shape: reading fields that do not
// exist yields the raw JSON walk, and the raw JSON walk is asserted ABSENT
// (`rawWalkLabels` / `arrayRows` must be empty at every rung on every
// example). That check is shape-based rather than count-based on purpose —
// re-pinning the counts cannot silently make it pass.
//
// WHY A REAL BROWSER. Same measurement as #1033, and the harness is
// literally the same file: node cannot load the JSPI bundle the page loads
// (`WebAssembly.Suspending` is undefined under every node 22 flag,
// measured), so a node harness would be rendering a tree from a DIFFERENT
// engine than the reader's. See scripts/playground-gate/browser_harness.mjs.
//
// THE EXPECTATIONS ARE PINNED, NOT DERIVED — and that is the opposite
// choice from #1033's, deliberately. #1033 compares wasm against native, so
// it has a second implementation to derive truth from. Here there is no
// second Tree renderer to ask; the only honest reference is a set of
// numbers a human read and agreed to. They live in ONE reviewable file,
// scripts/playground-gate/tree_expectations.json, so a DELIBERATE Tree
// change re-pins them in one place with the diff visible in review —
// `node scripts/test_playground_tree.mjs --pin` rewrites it, and the diff
// is the change request.
//
// BOUNDED (the #988 rule): whole-run deadline, per-CDP timeouts, server and
// browser reaped on every exit path.
//
// USAGE
//   make build-playground                 (stages dist/playground-preview)
//   node scripts/test_playground_tree.mjs [--verbose] [--pin]
//
// Overrides: CX_CHROME=<browser>, CX_BIN=<native cx>, TREE_GATE_DEADLINE=<s>,
// TREE_EXPECTATIONS=<path to a fixture> (used by the red-proofs).
//
// Exit 0 when every case matches its pin; 1 on any mismatch; 2 on a setup
// problem — never a silent skip.

import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { createHarness, loadExamples, ROOT }
  from './playground-gate/browser_harness.mjs';

const VERBOSE = process.argv.includes('--verbose');
const PIN = process.argv.includes('--pin');
const DEADLINE_MS = (parseInt(process.env.TREE_GATE_DEADLINE || '600', 10)) * 1000;
const FIXTURE = process.env.TREE_EXPECTATIONS
  ? resolve(process.env.TREE_EXPECTATIONS)
  : resolve(ROOT, 'scripts/playground-gate/tree_expectations.json');

const H = createHarness({ label: 'playground-tree', deadlineMs: DEADLINE_MS });
const { setupFail, checkDeadline, cleanup } = H;

const RUNGS = ['min', 'compact', 'full'];

// ── the fixture ────────────────────────────────────────────────
let fixture;
try {
  fixture = JSON.parse(readFileSync(FIXTURE, 'utf8'));
} catch (e) {
  if (!PIN) {
    setupFail(`could not read the expectation fixture ${FIXTURE}: ${e.message}`,
              'node scripts/test_playground_tree.mjs --pin  (then REVIEW the diff)');
  }
  fixture = { cases: [], bridge: {} };
}
if (!PIN && (!Array.isArray(fixture.cases) || fixture.cases.length === 0)) {
  setupFail(`the expectation fixture ${FIXTURE} pins no cases.`,
            'a Tree gate with nothing pinned is a vacuous pass');
}

// The case set and the bridge targets are the fixture's OWN — the gate has
// no built-in list, so adding an example is a fixture edit and shows up in
// review as one.
const CASES = fixture.cases.map(c => ({ example: c.example, why: c.why || '' }));
const BRIDGE = fixture.bridge || {};

// ── the page probes ────────────────────────────────────────────
//
// PROBE 1 — drive the controls, then MEASURE the tree they drew.
//
// Everything here is a control a reader can touch. `pick`'s `change` is
// what loadExample() listens for; `detailSelect`'s `change` is what the
// Detail rung listens for; the Source and Tree tabs are buttons. Nothing
// reaches into playground.js's closure, so the gate cannot pass by calling
// a function the page never calls.
function probeCase(example, rung) {
  return `(async () => {
    const out = { errors: [] };
    const pick   = document.getElementById('cxp-pick');
    const detail = document.getElementById('cxp-detail-select');
    const subj   = document.querySelector('.cxp-subject-tab[data-subject="source"]');
    const tab    = document.querySelector('.cxp-viz-tab[data-viz="tree"]');
    if (!pick)   out.errors.push('no #cxp-pick — the example picker is gone');
    if (!detail) out.errors.push('no #cxp-detail-select — the Detail control is gone (TD-4 moved it to the View header)');
    if (!subj)   out.errors.push('no Source subject tab');
    if (!tab)    out.errors.push('no Tree representation tab');
    if (out.errors.length) return JSON.stringify(out);

    tab.click();
    subj.click();
    // The picker's option values are 'KIND:key' (rebuildPick), and the
    // fixture pins the corpus key. Try the qualified form the page builds,
    // then the bare key, and say which forms were tried if neither takes —
    // a renamed corpus must fail LOUDLY here, not render the wrong example.
    //
    // PLAY-1: the picker lists the primer's fixtures; these pinned examples
    // are the playground corpus, which a reader reaches by its link
    // (#ex=<key>) — so that is the control used when the picker has no
    // such option, and the page then carries it as the picker's one
    // 'legacy:<key>' option.
    const want = ${JSON.stringify(example)};
    let picked = '';
    for (const v of ['legacy:' + want, 'program:' + want, want]) {
      pick.value = v;
      if (pick.value === v) { picked = v; break; }
    }
    if (picked) {
      pick.dispatchEvent(new Event('change', { bubbles: true }));
    } else {
      location.hash = '#ex=' + encodeURIComponent(want);
      for (let i = 0; i < 100 && pick.value !== 'legacy:' + want; i++) {
        await new Promise(r => setTimeout(r, 20));
      }
      if (pick.value !== 'legacy:' + want) {
        out.errors.push('the page has no such example — tried the picker ("legacy:' + want + '", "program:' + want + '", "' + want + '") and the link #ex=' + want);
        return JSON.stringify(out);
      }
    }
    detail.value = ${JSON.stringify(rung)};
    if (detail.value !== ${JSON.stringify(rung)}) {
      out.errors.push('the Detail control has no such rung: ' + ${JSON.stringify(rung)});
      return JSON.stringify(out);
    }
    detail.dispatchEvent(new Event('change', { bubbles: true }));

    const host = document.getElementById('cxp-viz-tree');
    if (!host) { out.errors.push('no #cxp-viz-tree pane'); return JSON.stringify(out); }
    const part = host.querySelector('.cxp-viz-part[data-subject="source"]');
    const sec  = (part && part.querySelector('.cxp-viz-part-body')) || host;
    const txt = el => (el && el.textContent || '').trim();
    const all = el => [...sec.querySelectorAll(el)].map(txt);

    // The placeholder means the pane drew NOTHING — an unavailable tree, an
    // empty subject. Reported rather than counted as zero rows, because a
    // gate that reads 0/0/0 off a broken pane is the vacuous pass this lane
    // exists to prevent.
    const ph = sec.querySelector('.cxp-viz-placeholder');
    out.placeholder = ph ? txt(ph) : '';

    const nodes = [...sec.querySelectorAll('.cxt-node')];
    out.rows = nodes.length;

    // TD-2b — attribute chips, and the loud overflow note. The cap is 2 at
    // compact and unbounded at full; \`min\` draws none at all.
    out.chips    = sec.querySelectorAll('.cxt-attr-chip').length;
    out.overflow = all('.cxt-attr-more');

    // TD-2c — element and directive captions, IN ORDER. A directive is
    // spelled '?' + name, the instance graph's own spelling; this list is
    // what pins that, and it pins the nesting order with it.
    out.names = all('.cxt-label-name');

    // TD-2a — a lone scalar / text body rides its element's row.
    out.inlineScalars = sec.querySelectorAll('.cxt-inline-scalar').length;

    // TD-5 — a value leaf is ONE ROW. The element branch appends a
    // .cxt-children container; the value-leaf branch returns without one.
    // So counting childless nodes counts leaves rendered by the leaf rule,
    // structurally, rather than by their text.
    out.leafRows = nodes.filter(n => !n.querySelector(':scope > .cxt-children')).length;

    // TD-1 / TD-5 — THE DEFECT SIGNATURE, asserted ABSENT.
    //
    // When the element branch reads fields the contract does not carry (the
    // #1001 shape), or a value leaf falls through to the generic object
    // walk (the TD-5 shape), the Tree draws the raw JSON: rows LABELLED
    // with contract keys ('kind:', 'value:', 'children:') and 'array(N)'
    // container rows. Neither can appear in a correctly-rendered tree of
    // these examples. This is shape-based, not count-based, so re-pinning
    // the counts above cannot make a raw-walk regression pass.
    const CONTRACT_KEYS = new Set(['kind','name','value','children','attrs','items','loc']);
    out.rawWalkLabels = [...new Set(all('.cxt-label-attr').filter(t => CONTRACT_KEYS.has(t)))].sort();
    out.arrayRows = [...new Set(all('.cxt-label-meta').filter(t => /^array\\(\\d+\\)$/.test(t)))].sort();

    return JSON.stringify(out);
  })()`;
}

// PROBE 2 — the click bridge, TREE → SOURCE (TD-3, TD-6a).
//
// Clicks the loc-bearing half of an attribute chip and reads back what the
// editor selected. TD-3 REFUSED to trade the per-attribute click target
// away for the chips' vertical space; this is the assertion that the price
// was actually paid. The click is dispatched on the chip half, and the
// page's own .cxt-row handler resolves it through
// `e.target.closest('.cxt-row [data-loc]')` — the reader's exact path.
function probeBridgeForward(targets) {
  return `(() => {
    const host = document.getElementById('cxp-viz-tree');
    const part = host.querySelector('.cxp-viz-part[data-subject="source"]');
    const sec  = (part && part.querySelector('.cxp-viz-part-body')) || host;
    const input = document.getElementById('cxp-input');
    const chips = [...sec.querySelectorAll('.cxt-attr-chip')];
    const res = [];
    for (const t of ${JSON.stringify(targets)}) {
      const chip = chips[t.chip];
      if (!chip) { res.push({ ...t, error: 'no chip at index ' + t.chip + ' (chips: ' + chips.length + ')' }); continue; }
      const el = (t.half === 'name') ? chip.querySelector('.cxt-chip-k') : chip.querySelector('.v');
      if (!el) { res.push({ ...t, error: 'chip ' + t.chip + ' has no ' + t.half + ' half' }); continue; }
      if (!el.dataset.loc) { res.push({ ...t, error: 'chip ' + t.chip + ' ' + t.half + ' half carries NO data-loc — the TD-3 click target was traded away' }); continue; }
      el.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      res.push({
        chip: t.chip, half: t.half,
        chipText: (chip.textContent || '').trim(),
        selected: input.value.slice(input.selectionStart, input.selectionEnd),
        // Exactly one target may carry the mark at a time (TD-6a).
        markedCount: sec.querySelectorAll('.is-selected').length,
      });
    }
    return JSON.stringify(res);
  })()`;
}

// PROBE 3 — the click bridge, SOURCE → TREE (TD-6a, reverse direction).
//
// Places the caret inside a token in the editor and dispatches the very
// event the page listens for ('keyup'), then reads which Tree element the
// page marked. `occurrence` disambiguates when the token also appears in
// the example's trailing note.
function probeBridgeReverse(targets) {
  return `(() => {
    const host = document.getElementById('cxp-viz-tree');
    const part = host.querySelector('.cxp-viz-part[data-subject="source"]');
    const sec  = (part && part.querySelector('.cxp-viz-part-body')) || host;
    const input = document.getElementById('cxp-input');
    const res = [];
    for (const t of ${JSON.stringify(targets)}) {
      let at = -1;
      for (let n = 0; n <= (t.occurrence || 0); n++) at = input.value.indexOf(t.token, at + 1);
      if (at < 0) { res.push({ ...t, error: 'token not found in the editor: ' + t.token }); continue; }
      const pos = at + Math.max(1, Math.floor(t.token.length / 2));
      input.focus();
      input.setSelectionRange(pos, pos);
      input.dispatchEvent(new Event('keyup', { bubbles: true }));
      const sel = sec.querySelector('.is-selected');
      res.push({
        token: t.token, occurrence: t.occurrence || 0,
        markedText: sel ? (sel.textContent || '').trim() : null,
        markedClass: sel ? sel.className.replace(/\\bis-selected\\b/, '').trim() : null,
        markedCount: sec.querySelectorAll('.is-selected').length,
      });
    }
    return JSON.stringify(res);
  })()`;
}

// ── run ────────────────────────────────────────────────────────
const program = loadExamples(readFileSync, setupFail);
for (const c of CASES) {
  if (!program[c.example]) {
    setupFail(`the fixture pins an example the corpus does not have: ${c.example}`,
              'the corpus was regenerated — re-pin, and READ the diff');
  }
}

const { evalJs, close } = await H.bootPage({
  portBase: 8850, cdpBase: 9660, needNative: true, verbose: VERBOSE,
});
console.log(`[playground-tree] fixture: ${FIXTURE.replace(ROOT + '/', '')}`);
console.log(`[playground-tree] cases:   ${CASES.length} examples × ${RUNGS.length} rungs\n`);

const measured = [];
let fail = 0;
const failRows = [];

// Anything a correct Tree can never contain, on ANY example at ANY rung.
// Held whether or not the fixture pins it, so a re-pin cannot bless it.
function invariantFailures(example, rung, m) {
  const out = [];
  if (m.placeholder) {
    out.push({ what: 'the Tree pane drew a PLACEHOLDER instead of a tree',
               detail: m.placeholder });
  }
  if (m.rows === 0) {
    out.push({ what: 'the Tree pane drew ZERO rows', detail: 'nothing rendered' });
  }
  if (m.rawWalkLabels.length) {
    out.push({
      what: 'RAW JSON WALK — rows labelled with cxlib.tree() contract keys (the #1001 defect shape)',
      detail: `labels: ${m.rawWalkLabels.join(', ')} — the element/leaf branch is not firing; `
            + 'it is reading fields the tree contract does not carry (TD-1, TD-5)',
    });
  }
  if (m.arrayRows.length) {
    out.push({
      what: 'RAW JSON WALK — `array(N)` container rows (the #1001 defect shape)',
      detail: `rows: ${m.arrayRows.join(', ')} (TD-1)`,
    });
  }
  if (rung === 'min' && (m.chips > 0 || m.inlineScalars > 0)) {
    out.push({
      what: 'the `min` rung drew VALUES',
      detail: `chips=${m.chips} inlineScalars=${m.inlineScalars} — `
            + '`min` is names and nesting only (TD-2, TD-3a)',
    });
  }
  if (rung !== 'compact' && m.overflow.length) {
    out.push({
      what: `the \`${rung}\` rung drew an attribute-overflow note`,
      detail: `${m.overflow.join(' ')} — only \`compact\` caps attributes (TD-2b)`,
    });
  }
  return out;
}

for (const c of CASES) {
  for (const rung of RUNGS) {
    checkDeadline(`${c.example} @ ${rung}`);
    let m;
    try {
      m = JSON.parse(await evalJs(probeCase(c.example, rung), 60000));
    } catch (e) {
      fail++;
      failRows.push({ example: c.example, rung,
                      what: 'the harness lost the page while rendering this case',
                      detail: e.message });
      console.log(`FAIL    ${c.example} @ ${rung}\n        harness/CDP: ${e.message}`);
      continue;
    }
    if (m.errors && m.errors.length) {
      fail++;
      failRows.push({ example: c.example, rung, what: 'the page could not be driven',
                      detail: m.errors.join('; ') });
      console.log(`FAIL    ${c.example} @ ${rung}\n        ${m.errors.join('; ')}`);
      continue;
    }
    delete m.errors;
    measured.push({ example: c.example, rung, m });

    const bad = invariantFailures(c.example, rung, m);
    for (const b of bad) {
      fail++;
      failRows.push({ example: c.example, rung, what: b.what, detail: b.detail });
      console.log(`FAIL    ${c.example} @ ${rung}\n        ${b.what}\n        ${b.detail}`);
    }
    if (PIN) {
      if (VERBOSE) console.log(`PIN     ${c.example} @ ${rung}  rows=${m.rows} chips=${m.chips}`);
      continue;
    }

    const pinned = (fixture.cases.find(x => x.example === c.example) || {}).rungs || {};
    const exp = pinned[rung];
    if (!exp) {
      fail++;
      failRows.push({ example: c.example, rung, what: 'the fixture pins no expectation for this rung',
                      detail: 're-pin and review' });
      console.log(`FAIL    ${c.example} @ ${rung}\n        no pinned expectation`);
      continue;
    }
    const diffs = [];
    for (const k of Object.keys(exp)) {
      const a = JSON.stringify(exp[k]), b = JSON.stringify(m[k]);
      if (a !== b) diffs.push(`${k}: expected ${a}, got ${b}`);
    }
    if (diffs.length) {
      fail++;
      failRows.push({ example: c.example, rung,
                      what: 'the Tree does not match its pinned expectation',
                      detail: diffs.join('\n      ') });
      console.log(`FAIL    ${c.example} @ ${rung}\n      ${diffs.join('\n      ')}`);
    } else if (VERBOSE) {
      console.log(`OK      ${c.example} @ ${rung}  rows=${m.rows} chips=${m.chips}`
                + (m.overflow.length ? `  ${m.overflow.join(' ')}` : ''));
    }
  }
}

// ── the click bridge ───────────────────────────────────────────
const bridgeMeasured = {};
if (BRIDGE.example) {
  checkDeadline('bridge');
  // Render the bridge case at its rung first — the probes read the tree
  // that is on screen, not one of their own.
  const pre = JSON.parse(await evalJs(probeCase(BRIDGE.example, BRIDGE.rung || 'full'), 60000));
  if (pre.errors && pre.errors.length) {
    setupFail(`could not render the bridge case ${BRIDGE.example}: ${pre.errors.join('; ')}`);
  }
  const fwd = JSON.parse(await evalJs(probeBridgeForward(
    (BRIDGE.forward || []).map(t => ({ chip: t.chip, half: t.half })) ), 60000));
  const rev = JSON.parse(await evalJs(probeBridgeReverse(
    (BRIDGE.reverse || []).map(t => ({ token: t.token, occurrence: t.occurrence || 0 })) ), 60000));
  bridgeMeasured.forward = fwd;
  bridgeMeasured.reverse = rev;

  const cmp = (dir, got, want) => {
    for (let i = 0; i < Math.max(got.length, want.length); i++) {
      const g = got[i], w = want[i];
      if (!g || !w) {
        fail++;
        failRows.push({ example: BRIDGE.example, rung: `bridge/${dir}`,
                        what: 'the pinned bridge targets and the measured ones differ in COUNT',
                        detail: `pinned ${want.length}, measured ${got.length}` });
        console.log(`FAIL    ${BRIDGE.example} bridge/${dir}: target count differs`);
        return;
      }
      if (g.error) {
        fail++;
        failRows.push({ example: BRIDGE.example, rung: `bridge/${dir}`,
                        what: 'a bridge target could not be exercised', detail: g.error });
        console.log(`FAIL    ${BRIDGE.example} bridge/${dir}\n        ${g.error}`);
        continue;
      }
      const diffs = [];
      for (const k of Object.keys(w)) {
        const a = JSON.stringify(w[k]), b = JSON.stringify(g[k]);
        if (a !== b) diffs.push(`${k}: expected ${a}, got ${b}`);
      }
      if (diffs.length) {
        fail++;
        failRows.push({ example: BRIDGE.example, rung: `bridge/${dir}`,
                        what: 'a click-bridge round-trip does not match its pin',
                        detail: diffs.join('\n      ') });
        console.log(`FAIL    ${BRIDGE.example} bridge/${dir}\n      ${diffs.join('\n      ')}`);
      } else if (VERBOSE) {
        console.log(`OK      ${BRIDGE.example} bridge/${dir} #${i}`);
      }
    }
  };
  if (!PIN) {
    cmp('forward', fwd, BRIDGE.forward || []);
    cmp('reverse', rev, BRIDGE.reverse || []);
  }
}

close();

// ── pin mode ───────────────────────────────────────────────────
if (PIN) {
  const out = {
    _README: fixture._README || [
      'PINNED EXPECTATIONS for the playground Tree pane gate (#1049).',
      'Regenerate with: node scripts/test_playground_tree.mjs --pin',
      'A regeneration is a CHANGE REQUEST: read the diff, and only commit it when',
      'each moved number is one the Tree change intended. TD-1..TD-7 in',
      'ledger/rulings_2026_08_26_playground_tree_detail_1001.md is the contract',
      'these numbers hold; a diff that contradicts a TD rung is a defect, not a re-pin.',
    ],
    _fields: fixture._fields || {
      rows: 'total .cxt-node rows the Tree drew for the SOURCE subject',
      chips: 'TD-2b — .cxt-attr-chip count (0 at min; capped at 2 at compact; all at full)',
      overflow: 'TD-2b — the exact `(+K more attrs)` notes, in order (compact only)',
      names: 'TD-2c — element/directive captions in order; a directive is `?` + name',
      inlineScalars: 'TD-2a — lone scalar/text bodies ridden up onto their element row',
      leafRows: 'TD-5 — nodes rendered as ONE row with no children container',
      rawWalkLabels: 'TD-1 — MUST stay []: rows labelled with tree-contract keys = raw JSON walk',
      arrayRows: 'TD-1 — MUST stay []: `array(N)` container rows = raw JSON walk',
      placeholder: 'MUST stay "": a placeholder means the pane drew no tree at all',
    },
    cases: [],
    bridge: {},
  };
  for (const c of CASES) {
    const rungs = {};
    for (const rung of RUNGS) {
      const hit = measured.find(x => x.example === c.example && x.rung === rung);
      if (hit) rungs[rung] = hit.m;
    }
    out.cases.push({ example: c.example, why: c.why, rungs });
  }
  if (BRIDGE.example) {
    out.bridge = {
      _why: BRIDGE._why || 'TD-3 / TD-6a — the chips carry the per-attribute click targets '
          + 'the verbose walk used to provide, verified in BOTH directions.',
      example: BRIDGE.example,
      rung: BRIDGE.rung || 'full',
      forward: bridgeMeasured.forward || [],
      reverse: bridgeMeasured.reverse || [],
    };
  }
  writeFileSync(FIXTURE, JSON.stringify(out, null, 2) + '\n');
  console.log(`\n[playground-tree] PINNED → ${FIXTURE}`);
  console.log('[playground-tree] READ THE DIFF. A re-pin that contradicts a TD rung is a defect.');
  if (fail > 0) {
    console.log(`\n[playground-tree] ${fail} INVARIANT failure(s) during pinning — see above.`);
    console.log('[playground-tree] These are not re-pinnable: the fixture just recorded a broken Tree.');
    cleanup();
    process.exit(1);
  }
  cleanup();
  process.exit(0);
}

// ── report ─────────────────────────────────────────────────────
if (VERBOSE || fail === 0) {
  console.log('\n=== measured ===');
  console.log('  example                     rung      rows  chips  leaf  inline  overflow');
  for (const x of measured) {
    console.log(`  ${x.example.padEnd(26)}  ${x.rung.padEnd(8)}  `
      + `${String(x.m.rows).padStart(4)}  ${String(x.m.chips).padStart(5)}  `
      + `${String(x.m.leafRows).padStart(4)}  ${String(x.m.inlineScalars).padStart(6)}  `
      + `${x.m.overflow.join(' ')}`);
  }
}
if (failRows.length) {
  console.log('\n=== FAILURES ===');
  for (const r of failRows) {
    console.log(`  ${r.example} @ ${r.rung}\n      ${r.what}\n      ${r.detail}`);
  }
}

console.log('\n══════════════════════════════════════════════════════════');
console.log('playground Tree pane gate — TOTAL');
console.log(`  examples                ${CASES.length}`);
console.log(`  rungs                   ${RUNGS.join(' / ')}`);
console.log(`  case renders            ${measured.length}`);
console.log(`  bridge round-trips      ${(BRIDGE.forward || []).length + (BRIDGE.reverse || []).length}`);
console.log(`  FAILURES                ${fail}`);
console.log('══════════════════════════════════════════════════════════');

if (fail > 0) {
  console.log('\nThe Tree pane no longer draws what it is pinned to draw. Either the Tree');
  console.log('changed on purpose — in which case re-pin with');
  console.log('  node scripts/test_playground_tree.mjs --pin');
  console.log('and put the fixture diff in the review, one reviewable place — or it');
  console.log('regressed. A `RAW JSON WALK` failure is the #1001 shape specifically: the');
  console.log('element / value-leaf branch is reading fields the cxlib.tree() contract does');
  console.log('not carry, so it is dead code and Detail has no effect. That one is never');
  console.log('re-pinnable; see ledger/rulings_2026_08_26_playground_tree_detail_1001.md.');
  cleanup();
  process.exit(1);
}
console.log('OK — the Tree pane draws what TD-1..TD-7 says it draws, at every rung.');
cleanup();
process.exit(0);
