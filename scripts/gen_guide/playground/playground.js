// CX Playground — controller.

(function () {
  'use strict';

  // ── Examples (PLAY-1) ─────────────────────────────────────
  // THE PICKER is the primer's own examples: every conformance fixture
  // docs-src/llm/primer.md.tmpl cites, in the primer's order, filed under
  // the primer section it sits in, each carrying its READING — data,
  // query (a program over a document, bound as $doc) or code (RULED: PLAY-2) — and the
  // answer the fixture records. playground.primer.js is projected from the
  // corpus by primer_examples.cx (`make docs`), so the page and the primer
  // cannot show two programs under one id.
  //
  // The playground's older audited corpus (examples.cxd →
  // playground.examples.js) is not in the picker. It stays reachable by its
  // stable link, #ex=<key>, and stays the corpus the diagram and engine
  // sweeps grade; an example opened that way says what it is.
  const primer = ((window.cxPlaygroundPrimer || {}).examples) || [];
  const examples = (window.cxPlaygroundExamples || { program: {} });
  const programEntries = examples.program || {};
  const READINGS = ['data', 'query', 'code'];
  const READING_NAMES = { data: 'Data', query: 'Query', code: 'Code' };
  // ── Legacy corpus sections (#1375) — kept for the #ex=<key> crumb ─────
  const SECTION_ORDER = [
    'data/elements', 'data/collections', 'data/numbers', 'data/text', 'data/formats', 'data/schema',
    'code/bindings', 'code/control-flow', 'code/patterns', 'code/functions', 'code/comprehensions',
    'code/paths', 'code/transforms', 'code/queries', 'code/errors', 'code/effects', 'code/builtins',
    'code/concurrency', 'code/resilience', 'code/metaprogramming', 'code/diagrams',
    'everyday/files', 'everyday/text', 'everyday/collections',
    'everyday/documents', 'everyday/process', 'everyday/time', 'everyday/cli-errors',
    'everyday/testing', 'everyday/world',
  ];
  const SECTION_NAMES = {
    'data/elements': ['Data', 'Elements and attributes'],
    'data/collections': ['Data', 'Collections: sequences, arrays, maps'],
    'data/numbers': ['Data', 'Numbers and durations'],
    'data/text': ['Data', 'Text'],
    'data/formats': ['Data', 'Formats: JSON, XML, YAML, TOML, CSV'],
    'data/schema': ['Data', 'Schema and closed types'],
    'code/bindings': ['Code', 'Bindings, constants, modules'],
    'code/control-flow': ['Code', 'Control flow and match'],
    'code/patterns': ['Code', 'Patterns and destructuring'],
    'code/functions': ['Code', 'Functions and callables'],
    'code/comprehensions': ['Code', 'Comprehensions, map, reduce, slices'],
    'code/paths': ['Code', 'Paths (cxpath)'],
    'code/transforms': ['Code', 'Transforms: modify and pipe'],
    'code/queries': ['Code', 'Queries over graphs and sets'],
    'code/errors': ['Code', 'Errors and refusals'],
    'code/effects': ['Code', 'Effects, purity, capabilities'],
    'code/builtins': ['Code', 'Builtins and randomness'],
    'code/concurrency': ['Code', 'Concurrency'],
    'code/resilience': ['Code', 'Resilience'],
    'code/metaprogramming': ['Code', 'Quoting and splicing'],
    'code/diagrams': ['Code', 'Diagrams'],
    'everyday/files': ['Everyday scripts', 'Files and directories'],
    'everyday/text': ['Everyday scripts', 'Text and regex'],
    'everyday/collections': ['Everyday scripts', 'Collections, as scripts use them'],
    'everyday/documents': ['Everyday scripts', 'CX documents as data'],
    'everyday/process': ['Everyday scripts', 'Arguments, environment, processes'],
    'everyday/time': ['Everyday scripts', 'Dates, times, durations'],
    'everyday/cli-errors': ['Everyday scripts', 'Errors in a command-line tool'],
    'everyday/testing': ['Everyday scripts', 'Testing your own script'],
    'everyday/world': ['Everyday scripts', 'The world: HTTP, a database, mail'],
  };
  // ALL_ENTRIES — the picker's rows, in the primer's order. `ex` keeps the
  // field names the rest of this file (and the sweeps) read: `input` is the
  // text the View pane draws as Source — the document for the document
  // reading, the program otherwise.
  const ALL_ENTRIES = primer.map((p) => ({
    key: p.id, kind: 'primer', reading: p.reading,
    ex: {
      ...p,
      label: `[${p.n}] ${p.id}${p.role === 'wrong' ? ' — do not write this' : (p.role === 'right' ? ' — write this' : '')}`,
      section: p.heading,
      input: p.reading === 'data' ? p.doc : p.src,
    },
  }));
  // A legacy corpus entry, opened by #ex=<key>: always the code reading.
  function legacyEntry(key) {
    const ex = programEntries[key];
    if (!ex) return null;
    const names = SECTION_NAMES[ex.section] || ['', ex.section || ''];
    return {
      key, kind: 'legacy', reading: 'code',
      ex: { ...ex, id: key, doc: '', src: ex.input, heading: `${names[0]} › ${names[1]}`,
            suite: 'scripts/gen_guide/playground/examples.cxd', expected: '', cmd: 'cx program.cx' },
    };
  }
  const displayLabel = (e) => (e.ex.label || e.key);
  const exampleNumber = (e) => (e.ex.n ? String(e.ex.n) : '');
  const entriesOf = (reading) => ALL_ENTRIES.filter(e => e.reading === reading);

  const pick     = document.getElementById('cxp-pick');
  const prevBtn  = document.getElementById('cxp-prev');
  const nextBtn  = document.getElementById('cxp-next');
  const runBtn   = document.getElementById('cxp-run');
  const resetBtn = document.getElementById('cxp-reset');
  const shareBtn = document.getElementById('cxp-share');
  const fmtBtn   = document.getElementById('cxp-format');
  const status   = document.getElementById('cxp-status');
  const input    = document.getElementById('cxp-input');
  const renderEl = document.getElementById('cxp-input-render');
  const docInput = document.getElementById('cxp-doc');
  const docRender = document.getElementById('cxp-doc-render');
  const docGutter = document.getElementById('cxp-doc-gutter');
  const docBlock  = document.getElementById('cxp-doc-block');
  const progBlock = document.getElementById('cxp-prog-block');
  const docLabel  = document.getElementById('cxp-doc-label');
  const fixtureEl = document.getElementById('cxp-fixture');
  const cmdEl     = document.getElementById('cxp-cmd');
  const expectEl  = document.getElementById('cxp-expect');
  const expectText = document.getElementById('cxp-expect-text');
  const verdictEl = document.getElementById('cxp-verdict');
  const readingTabs = [...document.querySelectorAll('.cxp-reading-tab')];
  // The reading the page is in, and the entry the editors were loaded from
  // (null once the reader has typed their own text in, or opened a link).
  let reading = 'code';
  let current = null;
  const outTabs  = [...document.querySelectorAll('.cxp-tab')];
  const vizTabs  = [...document.querySelectorAll('.cxp-viz-tab')];
  const subjectTabs = [...document.querySelectorAll('.cxp-subject-tab')];
  const detailSelect = document.getElementById('cxp-detail-select');
  const gviewTabs = [...document.querySelectorAll('.cxp-gview-tab')];
  const outs     = {
    cx:   document.querySelector('#cxp-out-cx code'),
    json: document.querySelector('#cxp-out-json code'),
    xml:  document.querySelector('#cxp-out-xml code'),
  };
  const outPres  = {
    cx:   document.getElementById('cxp-out-cx'),
    json: document.getElementById('cxp-out-json'),
    xml:  document.getElementById('cxp-out-xml'),
  };
  const vizTreeEl  = document.getElementById('cxp-viz-tree');
  const vizGraphEl = document.getElementById('cxp-viz-graph');
  const graphZoomBtns = {
    zoomIn:  document.getElementById('cxp-graph-zoom-in'),
    zoomOut: document.getElementById('cxp-graph-zoom-out'),
    fit:     document.getElementById('cxp-graph-fit'),
  };
  const vizPanes   = { tree: vizTreeEl, graph: vizGraphEl };
  const inputGutter = document.getElementById('cxp-input-gutter');
  const outGutters  = {
    cx:   outPres.cx   && outPres.cx  .querySelector('.cxp-gutter'),
    json: outPres.json && outPres.json.querySelector('.cxp-gutter'),
    xml:  outPres.xml  && outPres.xml .querySelector('.cxp-gutter'),
  };

  // ── Line-number gutter helpers ────────────────────────────
  // Renders a `\n`-separated column of line numbers and keeps the
  // gutter's scrollTop in sync with the source/output element's.
  function updateGutter(gutterEl, text) {
    if (!gutterEl) return;
    const n = (text || '').split('\n').length;
    let s = '';
    for (let i = 1; i <= n; i++) s += i + '\n';
    gutterEl.textContent = s;
  }
  function wireGutterScroll(gutterEl, scrollEl) {
    if (!gutterEl || !scrollEl) return;
    scrollEl.addEventListener('scroll', () => {
      gutterEl.scrollTop = scrollEl.scrollTop;
    });
  }

  // ── State ─────────────────────────────────────────────────
  // vizSubject names WHAT the View pane draws:
  //   'source' — the program in the editor,
  //   'output' — the value that program evaluated to,
  //   'all'    — both, stacked, so you can see that a CX program and a
  //              CX value are the same shape rather than take it on
  //              faith. Persists across example switches (localStorage).
  let vizSubject = 'source';
  try {
    const storedSubject = localStorage.getItem('cxp.vizSubject');
    if (storedSubject === 'source' || storedSubject === 'output' || storedSubject === 'all') {
      vizSubject = storedSubject;
    }
  } catch (_) { /* sandboxed / disabled — keep default */ }
  let prettyMode = true;            // output panes are pretty-printed by default
  let lastEvalRawCx   = '';         // last successful raw streaming CX output
  // wasmUnsupportedNote — the loaded example's corpus-declared reason for
  // NOT running in this engine (#1033), or ''. Module-level rather than a
  // runProgram() argument on purpose: a marked example must get the honest
  // banner however the run STARTED, including a manual Run click, which
  // carries no options from loadExample().
  let wasmUnsupportedNote = '';
  // grantsNote — the loaded example's corpus-declared capability flags
  // (RULED: CXF-2), or ''. Same module-level reason as the marker above: an
  // example that names grants must carry its "run it locally" line however
  // the run STARTED, including a manual Run click. The native audit ran the
  // program UNDER these grants, so the answer in the guide is real; this
  // engine has no way to give them, so the page says so and shows the
  // command line rather than presenting a capability-denied result as THE
  // answer.
  let grantsNote = '';
  const grantsLine = (g) =>
    'This example names the grants it needs; the wasm playground cannot give them. '
    + `Run it locally: \`cx ${g} program.cx\``;
  // The remedy half of the banner, kept in ONE place rather than repeated
  // in every corpus entry: the corpus states the FACT about the example,
  // this states what the reader can do about it. cxlib loads the threaded
  // build only when crossOriginIsolated + SharedArrayBuffer are available
  // (COOP/COEP headers, i.e. `make guide-http`); on file:// or plain HTTP
  // it loads the single-threaded JSPI build, which has no `go`.
  const WASM_UNSUPPORTED_REMEDY =
    'Run it in your terminal (`cx program.cx`), or serve the playground with '
    + 'COOP/COEP (`make guide-http`) to load the threaded build.';
  let nodeRegistry    = [];         // [{start, end, el, kind, key}, …] — for source ↔ tree bridge
  let nodeRegistrySource = '';      // text of the tree currently being rendered
  let graphScale      = 1;          // current SVG zoom factor
  // Detail level controls how much element-shape information shows up
  // in the View pane (Tree + Graph). 'min' = element name only;
  // 'compact' (default) = name + first 2 attrs + (+N more) + inlined
  // scalar bodies of leaf children; 'full' = name + all attrs +
  // scalar bodies. Persists to localStorage per-browser.
  //
  // True of the Tree since #1001, not before it: the Tree's rung-aware
  // branch read `node.attrs` / `node.items`, which the `cxlib.tree()`
  // contract does not carry, so this comment described an intention
  // rather than the page. It reads the contract's `children` now,
  // through the same `splitElementChildren` the instance graph uses.
  const COMPACT_ATTR_CAP = 2;
  let detailLevel = 'compact';
  try {
    const stored = localStorage.getItem('cxp.detailLevel');
    if (stored === 'min' || stored === 'compact' || stored === 'full') {
      detailLevel = stored;
    }
  } catch (_) { /* sandboxed / disabled — keep default */ }

  // graphView names WHAT THE GRAPH PANE GRAPHS (#960). It is a SUBJECT
  // axis, not a detail rung — the same axis `cx code-diagram --view=`
  // carries on the CLI, whose spellings this reuses so the two surfaces
  // stay one vocabulary:
  //
  //   'auto'     — the INFERRED SHAPE, rendered by the CX diagram module
  //                through `cxlib.diagram(src, 'mermaid:LEVEL')`. For a
  //                data document that is an erDiagram: ONE entity per
  //                element NAME, carrying attribute names and kinds and
  //                never a single value. For code it is the CFG / SEQ
  //                auto-detection. Unchanged, and still the default.
  //   'instance' — one graphed node per element OCCURRENCE, labelled
  //                with that occurrence's OWN attribute values, edges
  //                parent → child. Built here in the browser from the
  //                `cxlib.tree()` contract, which already carries every
  //                value the label needs.
  //
  // Why the second view is not a fourth detail rung: `min`/`compact`/
  // `full` vary how much of ONE subject is drawn. Three sibling
  // `[node …]` elements collapse into a single ERD entity at EVERY rung,
  // so no rung can draw the example in #960. The subject itself has to
  // change. `detailLevel` still applies inside the instance view — there
  // it caps how many attribute VALUES ride each node's label.
  //
  // Persists to localStorage per-browser, like detailLevel / vizSubject.
  let graphView = 'auto';
  try {
    const storedView = localStorage.getItem('cxp.graphView');
    if (storedView === 'auto' || storedView === 'instance') {
      graphView = storedView;
    }
  } catch (_) { /* sandboxed / disabled — keep default */ }

  // ── Highlighting ──────────────────────────────────────────
  function highlight(lang, src) {
    if (window.CXHighlight && typeof window.CXHighlight.highlight === 'function') {
      try { return window.CXHighlight.highlight(src, lang); }
      catch (_) { /* fall through */ }
    }
    return escapeHtml(src);
  }
  function escapeHtml(s) {
    return s.replace(/[&<>"']/g, c =>
      ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  }

  // ── Pretty / minimised projection ────────────────────────
  // CX is line-oriented — pretty form is the streamed output as-is;
  // minimised form collapses runs of whitespace to a single space.
  // JSON is JSON.parse + JSON.stringify (indent 2 vs no indent).
  // XML pretty: insert newlines between tags; min: strip inter-tag
  // whitespace. Both are best-effort; rendering won't break if a
  // projection isn't valid JSON / XML.
  function pretty(lang, text) {
    if (!text) return '';
    if (lang === 'json') {
      try { return JSON.stringify(JSON.parse(text), null, 2); }
      catch (_) { return text; }
    }
    if (lang === 'xml') {
      let depth = 0, out = '';
      const tokens = text.split(/(<\/?[^>]+>)/g);
      for (const tok of tokens) {
        if (!tok) continue;
        if (tok.startsWith('</')) { depth = Math.max(0, depth - 1); out += '\n' + '  '.repeat(depth) + tok; }
        else if (tok.startsWith('<')) {
          out += (out && !out.endsWith('\n') ? '\n' : '') + '  '.repeat(depth) + tok;
          if (!tok.endsWith('/>') && !tok.startsWith('<?') && !tok.startsWith('<!')) depth++;
        } else {
          const t = tok.trim();
          if (t) out += t;
        }
      }
      return out.replace(/^\n/, '');
    }
    // CX — the engine's own answer, byte for byte (PLAY-1). It is what
    // `cx` prints and what the fixture records; re-emitting it through
    // cxlib.toCx re-reads the text as a DOCUMENT, which respells values
    // (`email='a@x.com'` came back `email=a@x.com`) beside a fixture that
    // records the first spelling.
    return text;
  }
  function minimised(lang, text) {
    if (!text) return '';
    if (lang === 'json') {
      try { return JSON.stringify(JSON.parse(text)); }
      catch (_) { return text.replace(/\s+/g, ' ').trim(); }
    }
    if (lang === 'xml') return text.replace(/>\s+</g, '><').replace(/\s+/g, ' ').trim();
    const cxlib = globalThis.cxlib;
    if (cxlib && typeof cxlib.toCxCompact === 'function') {
      try { return cxlib.toCxCompact(text); } catch (_) {}
    }
    return text.replace(/\s+/g, ' ').trim();
  }

  function applyOutputProjection() {
    for (const [lang, el] of Object.entries(outs)) {
      const raw = el.dataset.raw || '';
      const text = prettyMode ? pretty(lang, raw) : minimised(lang, raw);
      el.innerHTML = highlight(lang, text);
      updateGutter(outGutters[lang], text);
    }
    if (fmtBtn) fmtBtn.textContent = prettyMode ? 'Pretty' : 'Minified';
  }

  // Wire output-pane scroll → gutter sync once.
  for (const k of Object.keys(outPres)) {
    const pre = outPres[k] && outPres[k].querySelector('pre');
    wireGutterScroll(outGutters[k], pre);
  }

  // ── The picker: the primer's examples for the current reading ──────
  // One <optgroup> per primer section, in the primer's order; each option
  // is `[n] <fixture id>` — n is the example's place in the primer, the id
  // is the case the corpus grades.
  function populatePicker() {
    pick.innerHTML = '';
    let group = null;
    let groupSec = null;
    for (const e of entriesOf(reading)) {
      const sec = e.ex.section || '';
      if (sec !== groupSec) {
        group = document.createElement('optgroup');
        group.label = sec;
        pick.appendChild(group);
        groupSec = sec;
      }
      const o = document.createElement('option');
      o.value = `${e.kind}:${e.key}`;
      o.textContent = displayLabel(e);
      group.appendChild(o);
    }
    // A legacy example (opened by link) is shown as the one extra option, so
    // the picker never claims a primer example the editors do not hold.
    if (current && current.kind === 'legacy') {
      const g = document.createElement('optgroup');
      g.label = 'Opened by link — the playground corpus (examples.cxd)';
      const o = document.createElement('option');
      o.value = `legacy:${current.key}`;
      o.textContent = current.ex.label || current.key;
      g.appendChild(o);
      pick.appendChild(g);
    }
  }

  function lookup(value) {
    if (!value) return null;
    const i = value.indexOf(':');
    const kind = value.slice(0, i), key = value.slice(i + 1);
    if (kind === 'legacy') return legacyEntry(key);
    const list = ALL_ENTRIES;
    const idx = list.findIndex(e => e.key === key);
    return idx >= 0 ? { idx, ...list[idx] } : null;
  }

  // ANNOTATION_RE matches the trailing `[; ─── … ─── ]` note block a LEGACY
  // example's source carries; it is stripped before evaluating or drawing.
  const ANNOTATION_RE = /\n*\[;\s*─+[\s\S]*?─+\s*\]\s*$/;
  function annotationStart(src) {
    const m = src.match(ANNOTATION_RE);
    return m ? m.index : src.length;
  }
  function stripAnnotation(src) {
    return src.replace(ANNOTATION_RE, '').replace(/\s+$/, '');
  }
  function composeSource(ex) {
    if (!ex) return '';
    if (ex.note) {
      return `${ex.input}\n\n[; ────────────────────\n${ex.note}\n──────────────────── ]\n`;
    }
    return ex.input;
  }

  function syncRender() {
    if (renderEl) {
      renderEl.innerHTML = highlight('cx', input.value);
      updateGutter(inputGutter, input.value);
    }
    if (docRender) {
      docRender.innerHTML = highlight('cx', docInput.value);
      updateGutter(docGutter, docInput.value);
    }
  }
  function syncScroll() {
    if (renderEl) {
      renderEl.parentElement.scrollTop  = input.scrollTop;
      renderEl.parentElement.scrollLeft = input.scrollLeft;
      if (inputGutter) inputGutter.scrollTop = input.scrollTop;
    }
  }
  function syncDocScroll() {
    if (docRender) {
      docRender.parentElement.scrollTop  = docInput.scrollTop;
      docRender.parentElement.scrollLeft = docInput.scrollLeft;
      if (docGutter) docGutter.scrollTop = docInput.scrollTop;
    }
  }

  // ── The reading: which editors show, what Run does ──────────────────
  //   document  the document editor alone; Run shows the document itself
  //             (`cx --from=cx --to=cx input.cx`) as CX, JSON and XML
  //   query     the document editor, bound as $doc, and the program over it
  //             (`cx --data=input.cx prog.cx`)
  //   program   the program editor alone (`cx prog.cx`)
  function applyReading(r) {
    reading = READINGS.includes(r) ? r : 'code';
    readingTabs.forEach(t => {
      const on = t.dataset.reading === reading;
      t.classList.toggle('is-active', on);
      t.setAttribute('aria-selected', on ? 'true' : 'false');
    });
    if (docBlock)  docBlock.hidden  = (reading === 'code');
    if (progBlock) progBlock.hidden = (reading === 'data');
    if (docLabel) {
      docLabel.textContent = reading === 'query'
        ? 'input.cx — the document, bound as $doc'
        : 'input.cx — the document';
    }
    document.body.dataset.reading = reading;
  }
  // The text the reading reads, as the command line would see it.
  function sourceText() {
    return reading === 'data' ? docInput.value : stripAnnotation(input.value);
  }
  // The editor whose text the View pane draws as Source (the tree bridge
  // selects in it).
  function activeEditor() { return reading === 'data' ? docInput : input; }

  // The fixture strip: which case this is, where the corpus keeps it, and
  // where the primer shows it; plus the command line that gives the same
  // answer natively. An entry the browser cannot run as the fixture does
  // says why, rather than presenting a different answer as the fixture's.
  function showFixture(found) {
    if (!fixtureEl) return;
    fixtureEl.innerHTML = '';
    if (!found) {
      fixtureEl.innerHTML = '<span class="cxp-fixture-own">your own text — no fixture</span>';
      if (cmdEl) cmdEl.textContent = reading === 'data' ? '$ cx --from=cx --to=cx input.cx'
        : (reading === 'query' ? '$ cx --data=input.cx prog.cx' : '$ cx prog.cx');
      return;
    }
    const ex = found.ex;
    const id = document.createElement('code');
    id.className = 'cxp-fixture-id';
    id.textContent = found.key;
    id.title = found.kind === 'legacy' ? 'playground corpus key' : 'conformance fixture id';
    const where = document.createElement('span');
    where.className = 'cxp-fixture-where';
    where.textContent = found.kind === 'legacy'
      ? ' · the playground corpus (examples.cxd) — not a primer fixture'
      : ` · ${ex.suite} · primer ${ex.section}`;
    fixtureEl.append(found.kind === 'legacy' ? 'example ' : 'fixture ', id, where);
    if (ex.role) {
      const b = document.createElement('span');
      b.className = `cxp-fixture-role is-${ex.role}`;
      b.textContent = ex.role === 'wrong' ? 'anti-pattern — do not write this' : 'the fix — write this';
      fixtureEl.append(' ', b);
    }
    if (ex.runnable === false && ex.why) {
      const w = document.createElement('span');
      w.className = 'cxp-fixture-why';
      w.textContent = ` · run it in a terminal: ${ex.why}`;
      fixtureEl.append(w);
    }
    if (cmdEl) cmdEl.textContent = `$ ${ex.cmd || 'cx prog.cx'}`;
  }

  // The fixture's recorded answer, shown beside the live one. `match` is
  // the fixture's own rule: exact bytes, or — for a recorded refusal, which
  // the corpus pins by its CXER code rather than its wording — containment.
  function showExpected(found) {
    if (!expectEl) return;
    const exp = found && found.kind === 'primer' ? found.ex.expected : '';
    expectEl.hidden = !exp;
    if (expectText) expectText.innerHTML = exp ? highlight('cx', exp) : '';
    if (verdictEl) { verdictEl.textContent = ''; verdictEl.className = 'cxp-verdict'; delete verdictEl.dataset.match; }
  }
  function edited() {
    if (!current || current.kind !== 'primer') return true;
    const ex = current.ex;
    if (reading === 'data') return docInput.value !== ex.doc;
    if (reading === 'query') return docInput.value !== ex.doc || input.value !== ex.src;
    return input.value !== ex.src;
  }
  // A recorded refusal (`match: contains`) is pinned by its code, which the
  // native CLI prints as `cx-err:CXERnnnn: …` and the wasm engine throws as
  // `CXERnnnn: …` — the same code either way, so the prefix is not compared.
  function sameAnswer(got, ex) {
    const g = String(got || '').replace(/\s+$/, '');
    const e = String(ex.expected || '').replace(/\s+$/, '');
    if (ex.match !== 'contains') return g === e;
    const bare = (s) => s.replace(/cx-err:/g, '');
    return bare(g).includes(bare(e));
  }
  function showVerdict(raw) {
    if (!verdictEl || !current || current.kind !== 'primer') return;
    if (edited()) {
      verdictEl.textContent = 'edited — the fixture answers its own text';
      verdictEl.className = 'cxp-verdict is-edited';
      return;
    }
    const ok = sameAnswer(raw, current.ex);
    verdictEl.textContent = ok ? '✓ this engine reproduces it' : '≠ this engine answers differently';
    verdictEl.className = `cxp-verdict ${ok ? 'is-ok' : 'is-diff'}`;
    verdictEl.dataset.match = ok ? 'yes' : 'no';
  }

  // ── Share-by-URL ──────────────────────────────────────────────────
  // An unedited example is shared by its id (#ex=<fixture id>); anything
  // else by its text: #r=<reading>&d=<document>&p=<program>, each text
  // UTF-8 then base64url, so any program survives the round trip.
  function b64uEncode(s) {
    const bytes = new TextEncoder().encode(s);
    let bin = '';
    for (const b of bytes) bin += String.fromCharCode(b);
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }
  function b64uDecode(s) {
    const t = s.replace(/-/g, '+').replace(/_/g, '/');
    const bin = atob(t + '==='.slice((t.length + 3) % 4));
    return new TextDecoder().decode(Uint8Array.from(bin, c => c.charCodeAt(0)));
  }
  function shareHash() {
    if (current && !edited()) return `#ex=${encodeURIComponent(current.key)}`;
    const parts = [`r=${reading}`];
    if (reading !== 'code') parts.push(`d=${b64uEncode(docInput.value)}`);
    if (reading !== 'data') parts.push(`p=${b64uEncode(input.value)}`);
    return '#' + parts.join('&');
  }
  function parseHash(h) {
    const m = /^#ex=([^&]+)/.exec(h || '');
    if (m) return { ex: decodeURIComponent(m[1]) };
    const q = {};
    for (const kv of String(h || '').replace(/^#/, '').split('&')) {
      const i = kv.indexOf('=');
      if (i > 0) q[kv.slice(0, i)] = kv.slice(i + 1);
    }
    if (!q.r) return null;
    // A link minted before PLAY-2 names a reading by its old key.
    q.r = ({ document: 'data', program: 'code' })[q.r] || q.r;
    try {
      return { r: q.r, d: q.d ? b64uDecode(q.d) : '', p: q.p ? b64uDecode(q.p) : '' };
    } catch (_) { return null; }
  }
  if (shareBtn) shareBtn.addEventListener('click', async () => {
    const h = shareHash();
    try { history.replaceState(null, '', h); } catch (_) {}
    const url = location.href;
    let copied = false;
    try { if (navigator.clipboard) { await navigator.clipboard.writeText(url); copied = true; } } catch (_) {}
    setStatus(copied ? 'Link copied — it reopens exactly this text.'
                     : `Link: <code>${escapeHtml(url)}</code>`, 'ok');
  });

  // Picking an example RUNS it: a reader clicking through the list sees
  // each one answer, with no run control to hunt for.
  const crumbEl = document.getElementById('cxp-crumb');
  function showCrumb(found) {
    if (!crumbEl) return;
    if (!found) { crumbEl.textContent = READING_NAMES[reading]; return; }
    if (found.kind === 'legacy') { crumbEl.textContent = `${found.ex.label || found.key} · by link`; return; }
    const list = entriesOf(found.reading);
    const pos = list.findIndex(e => e.key === found.key) + 1;
    crumbEl.textContent = `[${exampleNumber(found)}] · ${READING_NAMES[found.reading]} · ${pos} of ${list.length}`;
    crumbEl.title = 'Left/right: previous/next example · Up/down: previous/next section (also from the picker)';
  }
  function loadExample(value) {
    const found = lookup(value);
    if (!found) return;
    current = found;
    applyReading(found.reading);
    populatePicker();
    pick.value = `${found.kind}:${found.key}`;
    showCrumb(found);
    showFixture(found);
    showExpected(found);
    try { history.replaceState(null, '', `#ex=${encodeURIComponent(found.key)}`); } catch (_) {}
    docInput.value = found.ex.doc || '';
    input.value = found.kind === 'legacy' ? composeSource(found.ex) : (found.ex.src || '');
    syncRender();
    clearResults();
    refreshView();
    wasmUnsupportedNote = (typeof found.ex.wasmUnsupported === 'string'
                           && found.ex.wasmUnsupported.trim())
      ? found.ex.wasmUnsupported.trim() : '';
    const unstableNote = (typeof found.ex.noStableValue === 'string'
                          && found.ex.noStableValue.trim())
      ? found.ex.noStableValue.trim() : '';
    grantsNote = (typeof found.ex.grants === 'string' && found.ex.grants.trim())
      ? found.ex.grants.trim() : '';
    const capNote = wasmUnsupportedNote
      ? (found.kind === 'primer'
        ? `${escapeHtml(wasmUnsupportedNote)} Run it in your terminal: <code>${escapeHtml(found.ex.cmd)}</code> — the answer under the output is the fixture's.`
        : `${wasmUnsupportedNote} ${WASM_UNSUPPORTED_REMEDY}`)
      : (unstableNote
        ? `This program has no single answer. ${unstableNote}`
        : (grantsNote
          ? grantsLine(grantsNote)
          : ((found.ex.runnable === false && found.kind === 'primer')
            ? `This fixture runs as <code>${escapeHtml(found.ex.cmd)}</code> — ${escapeHtml(found.ex.why)}; `
              + 'its recorded answer is shown under the output.'
            : ((found.ex.runnable === false)
              ? 'This example needs a capability unavailable in the wasm playground '
                + '(network / subprocess / filesystem). Run it with <code>cx</code> in your terminal; '
                + 'here it returns a capability-denied result.'
              : ''))));
    if (capNote) setStatus(capNote, 'pending');
    runProgram({ auto: true, capNote });
  }
  // A reading tab opens that reading's first example, unless the example
  // on screen is already one of its own.
  readingTabs.forEach(t => t.addEventListener('click', () => {
    const r = t.dataset.reading;
    if (current && current.reading === r && current.kind === 'primer') return;
    const first = entriesOf(r)[0];
    if (first) loadExample(`${first.kind}:${first.key}`);
    else { applyReading(r); populatePicker(); }
  }));

  // Drops any result carried over from the previous program. Called
  // before every load and at the head of every run, so a pane is never
  // showing one example's output next to another's source.
  function clearResults() {
    for (const k of Object.keys(outs)) { outs[k].dataset.raw = ''; outs[k].textContent = ''; }
    lastEvalRawCx = '';
    if (verdictEl) { verdictEl.textContent = ''; verdictEl.className = 'cxp-verdict'; delete verdictEl.dataset.match; }
    resetVizPanes();
  }

  pick.addEventListener('change', () => loadExample(pick.value));
  resetBtn.addEventListener('click', () => {
    if (current) loadExample(`${current.kind}:${current.key}`);
    else if (pick.value) loadExample(pick.value);
  });
  prevBtn.addEventListener('click', () => stepExample(-1));
  nextBtn.addEventListener('click', () => stepExample(+1));
  // ←/→ walk the current reading's examples (wrapping); ↑/↓ jump to the
  // first example of the previous/next primer section in it.
  function stepExample(delta) {
    const list = entriesOf(reading);
    if (!list.length) return;
    const i = current ? list.findIndex(e => e.key === current.key) : -1;
    const next = list[(Math.max(i, 0) + (i < 0 ? 0 : delta) + list.length) % list.length];
    loadExample(`${next.kind}:${next.key}`);
  }
  function stepSection(delta) {
    const list = entriesOf(reading);
    if (!list.length) return;
    const secs = [];
    for (const e of list) if (secs[secs.length - 1] !== e.ex.section) secs.push(e.ex.section);
    const cur = current ? current.ex.section : secs[0];
    const i = Math.max(0, secs.indexOf(cur));
    const target = secs[(i + delta + secs.length) % secs.length];
    const first = list.find(e => e.ex.section === target);
    if (first) loadExample(`${first.kind}:${first.key}`);
  }
  // Arrow keys navigate unless focus is in a TEXT field — typing in an
  // editor is never hijacked. The picker is not a text field: after a
  // choice it holds focus, and the keys keep working from there (#1380).
  // Ctrl/⌘+Enter runs from anywhere, the editors included.
  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Enter' && (ev.ctrlKey || ev.metaKey)) {
      ev.preventDefault();
      if (!runBtn.disabled) runProgram({ auto: false });
      return;
    }
    const t = ev.target;
    const tag = t && t.tagName ? t.tagName.toLowerCase() : '';
    if (tag === 'textarea' || tag === 'input' || (t && t.isContentEditable)) return;
    if (ev.altKey || ev.ctrlKey || ev.metaKey) return;
    if (ev.key === 'ArrowRight') { ev.preventDefault(); stepExample(+1); }
    else if (ev.key === 'ArrowLeft') { ev.preventDefault(); stepExample(-1); }
    else if (ev.key === 'ArrowDown') { ev.preventDefault(); stepSection(+1); }
    else if (ev.key === 'ArrowUp') { ev.preventDefault(); stepSection(-1); }
  });
  // Editing retires the loaded example's markers (#1033, CXF-2): they are
  // claims about THAT text, and an edited text may behave differently.
  function onEdit() {
    wasmUnsupportedNote = '';
    grantsNote = '';
    syncRender();
    refreshView();
    if (verdictEl && current && current.kind === 'primer' && edited()) {
      verdictEl.textContent = 'edited — the fixture answers its own text';
      verdictEl.className = 'cxp-verdict is-edited';
    }
  }
  input.addEventListener('input', onEdit);
  input.addEventListener('scroll', syncScroll);
  if (docInput) {
    docInput.addEventListener('input', onEdit);
    docInput.addEventListener('scroll', syncDocScroll);
  }
  ['keyup','mouseup','click','select'].forEach(ev => {
    input.addEventListener(ev, () => highlightTreeAtSourceCursor());
    if (docInput) docInput.addEventListener(ev, () => highlightTreeAtSourceCursor());
  });

  // ── Output tab + projection toggle ────────────────────────
  outTabs.forEach(t => t.addEventListener('click', () => setOutTab(t.dataset.tab)));
  function setOutTab(name) {
    outTabs.forEach(t => t.classList.toggle('is-active', t.dataset.tab === name));
    for (const k of Object.keys(outPres)) {
      outPres[k].classList.toggle('is-active', k === name);
    }
  }
  if (fmtBtn) {
    fmtBtn.addEventListener('click', () => {
      prettyMode = !prettyMode;
      applyOutputProjection();
    });
  }

  // ── View tab switching ───────────────────────────────────
  // Which representation is showing persists like every other control
  // on this page (#992): reloading the playground used to drop you back
  // on Tree even though your Auto/Instance and Detail choices survived,
  // which made the graph controls look like they had forgotten too.
  vizTabs.forEach(t => t.addEventListener('click', () => setVizTab(t.dataset.viz, true)));
  function setVizTab(name, persist) {
    if (!vizPanes[name]) return;
    vizTabs.forEach(t => t.classList.toggle('is-active', t.dataset.viz === name));
    for (const k of Object.keys(vizPanes)) {
      vizPanes[k].classList.toggle('is-active', k === name);
    }
    if (persist) { try { localStorage.setItem('cxp.vizMode', name); } catch (_) {} }
    refreshView();
  }
  (function restoreVizTab() {
    let stored = null;
    try { stored = localStorage.getItem('cxp.vizMode'); } catch (_) {}
    if (stored && vizPanes[stored]) setVizTab(stored, false);
  })();
  // ── View subject (source / output / all) ─────────────────
  function applySubjectActiveState() {
    subjectTabs.forEach(t => t.classList.toggle('is-active', t.dataset.subject === vizSubject));
  }
  applySubjectActiveState();
  subjectTabs.forEach(t => t.addEventListener('click', () => {
    vizSubject = t.dataset.subject;
    applySubjectActiveState();
    try { localStorage.setItem('cxp.vizSubject', vizSubject); } catch (_) {}
    refreshView();
  }));
  // ── Detail — a VIEW-pane control since #1001 ─────────────
  // It configures both representations the pane can draw (the Tree's
  // rows and the Graph's boxes), so by this pane's own control model it
  // sits on the axis header rather than inside one panel. #992 had it
  // in the graph bar because Detail was graph-only IN FACT — the Tree's
  // detail branch read fields the tree contract does not carry and
  // never ran. Persists to localStorage, like every other control here.
  function applyDetailActiveState() {
    if (detailSelect) detailSelect.value = detailLevel;
  }
  applyDetailActiveState();
  if (detailSelect) detailSelect.addEventListener('change', () => {
    detailLevel = detailSelect.value;
    try { localStorage.setItem('cxp.detailLevel', detailLevel); } catch (_) {}
    refreshView();
  });
  // ── Graph view (auto / instance) — #960 ──────────────────
  function applyGraphViewActiveState() {
    gviewTabs.forEach(t => t.classList.toggle('is-active', t.dataset.gview === graphView));
  }
  applyGraphViewActiveState();
  gviewTabs.forEach(t => t.addEventListener('click', () => {
    graphView = t.dataset.gview;
    applyGraphViewActiveState();
    try { localStorage.setItem('cxp.graphView', graphView); } catch (_) {}
    refreshView();
  }));

  // The Auto view is the diagram module's INFERRED shape. Which shape it
  // inferred is the reader's first question (#1375: 161–163 render a
  // sequence diagram while their neighbours render a flowchart), so the
  // graph bar names it — "Auto: sequence" — next to the selector, with the
  // rule that chose it. Forcing a shape is not an engine surface yet: the
  // wasm diagram entry takes only the detail rung, so the selector offers
  // what exists (Auto, Instance) and the label makes Auto legible.
  const gkindEl = document.getElementById('cxp-gkind');
  function detectedKind(mermaidText) {
    const head = String(mermaidText || '').trim().split('\n')[0].toLowerCase();
    if (head.startsWith('sequencediagram')) return 'sequence';
    if (head.startsWith('erdiagram')) return 'entity';
    if (head.startsWith('flowchart') || head.startsWith('graph')) return 'flowchart';
    if (head.startsWith('statediagram')) return 'state';
    return head ? head.split(/\s+/)[0] : '';
  }
  const KIND_WHY = {
    sequence: 'sequence diagram — the source declares async, worker or channel steps, so time runs down the page',
    entity: 'entity diagram — the root is data, so element names become entities',
    flowchart: 'flowchart — the source is code with branches or loops',
    state: 'state diagram',
    instance: 'one box per element occurrence, from the parsed tree',
  };
  // The forced views (#1377): the engine draws the asked-for subject or
  // refuses by name (CXER0282) — the label says which the reader asked for.
  const FORCED_VIEW_LABEL = { erd: 'Data shape', cfg: 'Control flow', seq: 'Sequence', effects: 'Effects' };
  function showGraphKind(kind) {
    if (!gkindEl) return;
    if (!kind) { gkindEl.textContent = ''; gkindEl.title = ''; return; }
    if (graphView === 'instance') { gkindEl.textContent = 'Instance'; gkindEl.title = KIND_WHY.instance; return; }
    if (FORCED_VIEW_LABEL[graphView]) {
      gkindEl.textContent = `${FORCED_VIEW_LABEL[graphView]} (forced)`;
      gkindEl.title = `you asked for the ${FORCED_VIEW_LABEL[graphView].toLowerCase()} view; Auto would draw: ${kind}`;
      return;
    }
    gkindEl.textContent = `Auto: ${kind}`;
    gkindEl.title = KIND_WHY[kind] || kind;
  }
  function resetVizPanes() {
    vizTreeEl.innerHTML  = '<p class="cxp-viz-placeholder">Run a program to see its structural tree.</p>';
    vizGraphEl.querySelector('.cxp-graph-canvas').innerHTML =
      '<p class="cxp-viz-placeholder">Run a program to see its diagram.</p>';
  }

  // ── Status ─────────────────────────────────────────────
  let statusTimer = null;
  function setStatus(html, kind) {
    if (statusTimer) { clearTimeout(statusTimer); statusTimer = null; }
    status.classList.remove('is-ok', 'is-error', 'is-pending');
    if (kind) status.classList.add(`is-${kind}`);
    status.innerHTML = html;
    if (kind === 'ok') {
      statusTimer = setTimeout(() => setReadyStatus(), 4000);
    }
  }
  function setReadyStatus() {
    const cxlib = globalThis.cxlib;
    const ver = (cxlib && cxlib.version) ? cxlib.version() : 'wasm';
    const mode = (cxlib && cxlib.runtimeMode) || 'async';
    if (mode === 'pthreads') {
      setStatus(
        `Powered by <code>libcx.wasm ${ver}</code> · pthreads + SharedArrayBuffer — ` +
        `<code>:par</code> runs on real OS threads.`, null);
    } else if (mode === 'sync') {
      setStatus(
        `Powered by <code>libcx.wasm ${ver}</code> · single-threaded compatibility build ` +
        `(this browser lacks WebAssembly JSPI) — wall-clock <code>[?sleep]</code> is ` +
        `unavailable (use <code>[?sleep DUR mock]</code>); <code>:par</code> produces ` +
        `correct output but doesn't accelerate.`, null);
    } else {
      setStatus(
        `Powered by <code>libcx.wasm ${ver}</code> · single-threaded JSPI — ` +
        `<code>:par</code> produces correct output but doesn't accelerate. ` +
        `For real parallelism: <code>make guide-http</code> or run <code>cx</code> in your terminal.`,
        null);
    }
  }

  // ── Tree view builder ───────────────────────────────────
  //
  // Walk the cxlib.tree() JSON into nested HTML rows. Each `<div
  // class="cxt-node">` carries `data-loc='{start, end}'` when the
  // AST node has loc info. Scalar / attribute values inherit their
  // parent's loc so clicking a leaf value still highlights the
  // covering bracket in the source.
  // `host` is the element to draw into (the pane itself, or one subject
  // section of it in `all` mode). `register` says whether this tree's
  // nodes feed the source ↔ tree bridge — only the SOURCE tree does,
  // because only its loc offsets index the editor's text.
  function renderTree(treeJson, sourceText, host, register) {
    // Attribute rows are split into name/value sub-rows by walking the
    // text the tree was built from — so this always tracks THIS tree's
    // text, source or output. Only the node REGISTRY (the editor
    // bridge) is source-only.
    nodeRegistrySource = sourceText || '';
    if (register) nodeRegistry = [];
    if (treeJson == null) {
      host.innerHTML = '<p class="cxp-viz-placeholder">(empty tree)</p>';
      return;
    }
    host.innerHTML = '';
    host.appendChild(renderNode(treeJson, null, null, register));
    host.querySelectorAll('.cxt-toggle').forEach(t => {
      t.addEventListener('click', (e) => {
        e.stopPropagation();
        const node = t.closest('.cxt-node');
        node.classList.toggle('is-collapsed');
        t.textContent = node.classList.contains('is-collapsed') ? '▸' : '▾';
      });
    });
    host.querySelectorAll('.cxt-row').forEach(row => {
      row.addEventListener('click', (e) => {
        e.stopPropagation();
        // A loc-bearing span ON the row — an attribute chip's name or
        // value half, a ridden-up scalar body — is a TIGHTER target
        // than the row's own node, and clicking it means it. Falling
        // back to the node keeps every other row behaving as before.
        const inner = e.target && e.target.closest
          ? e.target.closest('.cxt-row [data-loc]') : null;
        const node = row.closest('.cxt-node');
        const target = inner || node;
        const locStr = target && target.dataset.loc;
        if (!locStr) return;
        let { start, end } = JSON.parse(locStr);
        // Only the SOURCE tree indexes the editor: translate loc offsets
        // (computed against the stripped source) onto the textarea's
        // offsets. The annotation we append lives strictly AFTER the
        // stripped source, so program-side offsets are stable — but if
        // the user has deleted content above the click target, the loc
        // may now point past the end. Clamp.
        if (register) {
          const cap = annotationStart(activeEditor().value);
          if (end > cap) end = cap;
          if (start > cap) start = cap;
          activeEditor().focus();
          activeEditor().setSelectionRange(start, end);
        }
        markSelected(target);
      });
    });
  }

  // ── Inline-attr + inline-scalar helpers (detail-level aware) ──
  //
  // These read the `cxlib.tree()` contract DIRECTLY — attribute nodes as
  // the emitter hands them over, `{kind:'attribute', name, value, loc}`
  // entries inside `children`, partitioned by `splitElementChildren`,
  // the very function the instance-graph tables consume. Before #1001
  // this pair was fed `node.attrs` / `node.items`, which no node in that
  // contract carries, so neither ever ran: the Tree drew the raw JSON
  // walk at every rung (four rows per attribute) and `Detail` had no
  // observable effect on it at all.
  //
  // locStr renders one `data-loc` attribute for a click target, or ''
  // when the node carries no loc.
  function locStr(loc) {
    if (!loc || typeof loc.start !== 'number') return '';
    return ` data-loc='${JSON.stringify({ start: loc.start, end: loc.end })}'`;
  }
  // registerHeadTargets enrolls the loc-bearing spans that ride an
  // element's own row — attribute chips and a ridden-up scalar body —
  // into the source ↔ tree bridge, so collapsing them out of the walk
  // costs no click target. Scoped to THIS node's row: a descendant's
  // row is registered when that descendant is rendered.
  function registerHeadTargets(wrap) {
    let row = null;
    for (const c of wrap.children) {
      if (c.classList && c.classList.contains('cxt-row')) { row = c; break; }
    }
    if (!row) return;
    row.querySelectorAll('[data-loc]').forEach(el => {
      try {
        const l = JSON.parse(el.dataset.loc);
        if (typeof l.start === 'number') nodeRegistry.push({ start: l.start, end: l.end, el });
      } catch (_) { /* malformed loc — no target, never a crash */ }
    });
  }
  // attrSubLocs splits one attribute's loc — which covers the whole
  // `name=value` span — into its two halves, by walking the text this
  // tree was built from. This is the SAME split the verbose attribute
  // branch performs; factored out so the chips keep the per-half click
  // targets that branch provided rather than trading them away.
  function attrSubLocs(loc) {
    if (!loc || typeof loc.start !== 'number' || !nodeRegistrySource) return null;
    const span = nodeRegistrySource.slice(loc.start, loc.end);
    const eq = span.indexOf('=');
    if (eq < 0) return null;
    // The value's quote characters are part of its literal span and are
    // kept, so a highlight matches what the user sees in the source.
    return {
      nameLoc: { start: loc.start, end: loc.start + eq },
      valLoc:  { start: loc.start + eq + 1, end: loc.end },
    };
  }
  // Renders attribute nodes as small space-separated chips (`@name=value`)
  // on the element's head row. At Compact, caps at COMPACT_ATTR_CAP and
  // appends `(+K more)`; at Full shows all. The cap is 2 because a head
  // row is a LINE label, and 2-plus-overflow is what the diagram spec's
  // compact rung already spends on a line's attribute chips — the Tree
  // and the `mermaid:compact` label say the same thing at the same rung.
  function renderAttrChips(attrs, level) {
    if (!attrs || attrs.length === 0) return '';
    const cap = (level === 'full') ? attrs.length : COMPACT_ATTR_CAP;
    const shown = attrs.slice(0, cap);
    let out = '';
    for (const a of shown) {
      const sub = attrSubLocs(a.loc);
      out += `<span class="cxt-attr-chip"${sub ? '' : locStr(a.loc)}>`
        + `<span class="cxt-chip-k"${sub ? locStr(sub.nameLoc) : ''}>@${escapeHtml(String(a.name))}</span>=`
        + `<span class="v"${sub ? locStr(sub.valLoc) : ''}>${formatAttrValue(a.value)}</span>`
        + `</span>`;
    }
    const remaining = attrs.length - shown.length;
    if (remaining > 0) {
      out += `<span class="cxt-attr-more">(+${remaining} more attr${remaining === 1 ? '' : 's'})</span>`;
    }
    return out;
  }
  function formatAttrValue(v) {
    if (v === null || v === undefined) return '<span class="cxt-label-meta">null</span>';
    if (typeof v === 'string')  return `"${escapeHtml(v)}"`;
    if (typeof v === 'number')  return String(v);
    if (typeof v === 'boolean') return String(v);
    return escapeHtml(String(v));
  }
  // Renders a single inlined scalar / text body next to its parent
  // element's name row (Compact/Full only), carrying its own loc so the
  // ridden-up body stays its own click target.
  function renderInlineScalar(node) {
    const v = (node && typeof node === 'object') ? node.value : node;
    const at = (node && typeof node === 'object') ? locStr(node.loc) : '';
    if (typeof v === 'string')  return `<span class="cxt-inline-scalar"${at}>"${escapeHtml(v)}"</span>`;
    if (typeof v === 'number')  return `<span class="cxt-inline-scalar num"${at}>${v}</span>`;
    if (typeof v === 'boolean') return `<span class="cxt-inline-scalar bool"${at}>${v}</span>`;
    return `<span class="cxt-inline-scalar"${at}>${escapeHtml(String(v))}</span>`;
  }

  function renderNode(node, label, inheritedLoc, register) {
    const wrap = document.createElement('div');
    wrap.className = 'cxt-node';
    // Carry loc; scalars / attribute leaves inherit from the
    // nearest ancestor that has one.
    let loc = inheritedLoc;
    if (node && typeof node === 'object' && node.loc && typeof node.loc.start === 'number') {
      loc = { start: node.loc.start, end: node.loc.end };
    }
    if (loc) {
      wrap.dataset.loc = JSON.stringify(loc);
      if (register) nodeRegistry.push({ start: loc.start, end: loc.end, el: wrap });
    }
    const rowHtml = (toggle, body) =>
      `${toggle}<span class="cxt-row">${labelPart(label)}${body}</span>`;

    if (node === null || node === undefined) {
      wrap.innerHTML = rowHtml('<span class="cxt-toggle">·</span>',
        '<span class="cxt-label-meta">null</span>');
      return wrap;
    }
    if (typeof node === 'string') {
      wrap.innerHTML = rowHtml('<span class="cxt-toggle">·</span>',
        `<span class="cxt-label-string">"${escapeHtml(node)}"</span>`);
      return wrap;
    }
    if (typeof node === 'number') {
      wrap.innerHTML = rowHtml('<span class="cxt-toggle">·</span>',
        `<span class="cxt-label-number">${node}</span>`);
      return wrap;
    }
    if (typeof node === 'boolean') {
      wrap.innerHTML = rowHtml('<span class="cxt-toggle">·</span>',
        `<span class="cxt-label-boolean">${node}</span>`);
      return wrap;
    }
    if (Array.isArray(node)) {
      const toggle = node.length > 0 ? '<span class="cxt-toggle">▾</span>' : '<span class="cxt-toggle">·</span>';
      wrap.innerHTML = rowHtml(toggle, `<span class="cxt-label-meta">array(${node.length})</span>`);
      const kids = document.createElement('div');
      kids.className = 'cxt-children';
      node.forEach((c, i) => kids.appendChild(renderNode(c, `[${i}]`, loc, register)));
      wrap.appendChild(kids);
      return wrap;
    }
    // Object
    const keys = Object.keys(node);
    // ── Element / directive specialization, by DETAIL rung (#1001) ──
    //
    // The rung is applied to the SAME data the instance-graph tables
    // consume — `splitElementChildren` over the `cxlib.tree()`
    // contract's `children`, where attributes are
    // `{kind:'attribute', name, value, loc}` siblings of nested
    // elements and of scalar / text bodies. There is no second
    // projection here and no second copy of the partition rule.
    //
    // Before #1001 this branch read `node.attrs` / `node.items`, which
    // that contract does not carry, so it never fired:
    // `[user active=true verified=false admin=true blocked=false]`
    // drew seventeen rows (four per attribute) and `Detail` had no
    // observable effect on the Tree at any rung.
    //
    // The rungs mean here exactly what they mean in the graph:
    //   min      — NAMES and NESTING only. `instanceRows` returns no
    //              rows at that rung for the same reason: what the
    //              rung is for is the shape, not the values.
    //   compact  — the first COMPACT_ATTR_CAP attributes as chips plus
    //              a loud `(+K more attrs)`, and a lone scalar / text
    //              body ridden up onto the element's own row.
    //   full     — every attribute as a chip, same body rule.
    //
    // The chips do NOT cost the per-attribute click target that the
    // verbose walk provided: each chip carries its own `data-loc` for
    // the name half and another for the value half — the same split,
    // from the same helper, that the `attribute` branch below performs.
    const isElement = (node.kind === 'element' || node.kind === 'directive')
      && typeof node.name === 'string';
    if (isElement) {
      const parts = splitElementChildren(node);
      const skipKeys = new Set(['kind', 'name', 'children', 'loc']);
      // A LONE scalar / text body rides its element's row — the same
      // rule, on the same predicate, that `instanceRows` applies when
      // it gives such a body a row of its own: one body is content,
      // several are a LIST, and an element with element children of
      // its own is not a leaf.
      const usable = parts.bodies.filter(b =>
        (b.kind === 'scalar' || b.kind === 'text')
        && b.value !== '' && b.value !== null && b.value !== undefined);
      const inlineScalarValue = (detailLevel !== 'min'
        && usable.length === 1 && parts.elems.length === 0)
        ? usable[0] : null;
      // What still walks as rows: element / directive children always,
      // bodies unless the single one was ridden up, and any key the
      // contract grows that is not one of the four this branch owns
      // (so an addition surfaces instead of silently disappearing).
      // Attributes never walk here — at compact/full they are the
      // chips on the row above, and at `min` they are what the rung
      // cuts.
      const walked = [];
      for (const c of (Array.isArray(node.children) ? node.children : [])) {
        if (!c || typeof c !== 'object') { walked.push(c); continue; }
        if (c.kind === 'attribute') continue;
        if (c === inlineScalarValue) continue;
        walked.push(c);
      }
      const extraKeys = keys.filter(k => !skipKeys.has(k));
      const hasChildren = walked.length > 0 || extraKeys.length > 0;
      const toggleChar = hasChildren ? '▾' : '·';
      const title = (node.kind === 'directive' ? '?' : '') + node.name;
      let head = `<span class="cxt-label-name">${escapeHtml(title)}</span>`;
      if (detailLevel !== 'min' && parts.attrs.length > 0) {
        head += renderAttrChips(parts.attrs, detailLevel);
      }
      if (inlineScalarValue) {
        head += renderInlineScalar(inlineScalarValue);
      }
      wrap.innerHTML = rowHtml(`<span class="cxt-toggle">${toggleChar}</span>`, head);
      if (register) registerHeadTargets(wrap);
      const kids = document.createElement('div');
      kids.className = 'cxt-children';
      // `null`, not `''`: a contained child has no KEY naming it, and
      // `labelPart('')` would still draw the `: ` separator in front of
      // every row.
      for (const child of walked) {
        kids.appendChild(renderNode(child, null, loc, register));
      }
      for (const k of extraKeys) {
        kids.appendChild(renderNode(node[k], k, loc, register));
      }
      wrap.appendChild(kids);
      return wrap;
    }
    // ── Value leaves (#1001) ────────────────────────────────────
    // `{kind:'scalar'|'text'|'path', value, loc}` is a LEAF: one row
    // carrying its value, the way the element branch above spells a
    // ridden-up body. Walked as a bare object it drew three rows —
    // `scalar`, then `kind: "scalar"`, then `value: "$orders"` — which
    // is the same raw-JSON-walk defect #1001 reports for attributes,
    // one node kind over. The contract's own `kind` is what styles the
    // value; nothing here parses it.
    if (node.kind === 'scalar' || node.kind === 'text' || node.kind === 'path') {
      const v = node.value;
      const cls = (node.kind === 'path') ? 'cxt-label-meta' : inferValueClass(v);
      const shown = (typeof v === 'string' && node.kind !== 'path')
        ? `"${escapeHtml(v)}"` : escapeHtml(String(v));
      wrap.innerHTML = rowHtml('<span class="cxt-toggle">·</span>',
        `<span class="${cls}">${shown}</span>`);
      return wrap;
    }
    const toggle = keys.length > 0 ? '<span class="cxt-toggle">▾</span>' : '<span class="cxt-toggle">·</span>';
    let head;
    if (node.kind && node.name) {
      head = `<span class="cxt-label-name">${escapeHtml(node.name)}</span> <span class="cxt-label-meta">(${escapeHtml(node.kind)})</span>`;
    } else if (node.kind) {
      head = `<span class="cxt-label-meta">${escapeHtml(node.kind)}</span>`;
    } else if (keys.length === 0) {
      head = '<span class="cxt-label-meta">{}</span>';
    } else {
      head = `<span class="cxt-label-name">${escapeHtml(keys[0])}</span>` +
             (keys.length > 1 ? ` <span class="cxt-label-meta">…+${keys.length-1}</span>` : '');
    }
    wrap.innerHTML = rowHtml(toggle, head);
    const kids = document.createElement('div');
    kids.className = 'cxt-children';
    // Special-case `attribute` nodes: synthesize name + value sub-rows
    // with computed sub-locs so each piece is individually selectable
    // in the source pane. cxlib gives one loc per attribute (covering
    // "name=value"); we split it in JS by walking the source span.
    if (node.kind === 'attribute' && loc && nodeRegistrySource) {
      const span = nodeRegistrySource.slice(loc.start, loc.end);
      const eq = span.indexOf('=');
      if (eq >= 0) {
        const nameLoc  = { start: loc.start,           end: loc.start + eq };
        // Value starts after `=`; if quoted, the quote chars are part
        // of the literal span — we keep them so the highlight matches
        // what the user actually sees in source.
        const valLoc   = { start: loc.start + eq + 1,  end: loc.end };
        kids.appendChild(makeLeaf('name',  node.name,
          'cxt-label-attr',  nameLoc, register));
        kids.appendChild(makeLeaf('value', node.value,
          inferValueClass(node.value), valLoc, register));
      }
    } else {
      for (const k of keys) {
        if (k === 'loc') continue;
        kids.appendChild(renderNode(node[k], k, loc, register));
      }
    }
    wrap.appendChild(kids);
    return wrap;
  }

  // Synthesize a leaf row with a hand-rolled loc — used to split an
  // attribute into name+value rows. Each leaf is registered for the
  // cursor-to-tree bridge just like a real AST node.
  function makeLeaf(label, value, valueCls, leafLoc, register) {
    const wrap = document.createElement('div');
    wrap.className = 'cxt-node';
    wrap.dataset.loc = JSON.stringify(leafLoc);
    if (register) nodeRegistry.push({ start: leafLoc.start, end: leafLoc.end, el: wrap });
    const display = (typeof value === 'string')
      ? `<span class="cxt-label-string">"${escapeHtml(value)}"</span>`
      : `<span class="${valueCls}">${escapeHtml(String(value))}</span>`;
    wrap.innerHTML = `<span class="cxt-toggle">·</span><span class="cxt-row">` +
      `<span class="cxt-label-attr">${escapeHtml(label)}</span>: ${display}</span>`;
    return wrap;
  }
  function inferValueClass(v) {
    if (typeof v === 'string')  return 'cxt-label-string';
    if (typeof v === 'number')  return 'cxt-label-number';
    if (typeof v === 'boolean') return 'cxt-label-boolean';
    return 'cxt-label-meta';
  }
  function labelPart(label) {
    if (label == null) return '';
    return `<span class="cxt-label-attr">${escapeHtml(String(label))}</span>: `;
  }

  function markSelected(node) {
    // Not `.cxt-node.is-selected`: since #1001 the selection can land on
    // a span that rides an element's own row (an attribute chip half, a
    // ridden-up scalar body), and a stale mark on one of those would
    // never be cleared by a node-only sweep.
    vizTreeEl.querySelectorAll('.is-selected').forEach(n => n.classList.remove('is-selected'));
    if (!node) return;
    node.classList.add('is-selected');
    // Expand ancestors.
    let p = node.parentElement;
    while (p && p !== vizTreeEl) {
      if (p.classList && p.classList.contains('cxt-node')) {
        p.classList.remove('is-collapsed');
      }
      p = p.parentElement;
    }
    node.scrollIntoView({ block: 'nearest', behavior: 'auto' });
  }

  function highlightTreeAtSourceCursor() {
    if (vizSubject === 'output') return;   // no source tree on screen
    if (!nodeRegistry.length) return;
    const pos = activeEditor().selectionStart;
    // Tightest node covering pos.
    let best = null, bestSpan = Infinity;
    for (const n of nodeRegistry) {
      if (n.start <= pos && pos <= n.end) {
        const span = n.end - n.start;
        if (span < bestSpan) { best = n; bestSpan = span; }
      }
    }
    markSelected(best ? best.el : null);
  }

  // ── Instance graph (Graph: instance) — #960 ─────────────
  //
  // Emits a Mermaid `flowchart TD` in which ONE node is drawn per
  // element / directive OCCURRENCE, labelled with that occurrence's own
  // attribute VALUES, with one edge per parent → child containment
  // step. So
  //
  //   [node name=a id=4 [node name=b id=23] [node name=b1 id=35]]
  //
  // draws three boxes — `node @name='a' @id=4`, `node @name='b' @id=23`,
  // `node @name='b1' @id=35` — where the `auto` view draws a SINGLE
  // `node` ERD entity carrying attribute names and kinds and no value at
  // any rung, because an ERD has one entity per element NAME.
  //
  // Source of truth is the `cxlib.tree()` contract (vcx/cx/code_tree.v):
  // every node is `{kind, name?, value?, loc, children?}` and attributes
  // are `{kind:'attribute', name, value}` entries INSIDE `children`,
  // siblings of nested elements and of scalar / text bodies. Values
  // arrive JSON-typed — ints and floats as numbers, booleans as
  // booleans, atoms as strings keeping their leading `:`.
  //
  // (Measured 2026-08-25, FIXED at #1001: the Tree pane's element branch
  // above used to read `node.attrs` / `node.items`, which this contract
  // does not carry, so its attr chips were inert. It reads `children`
  // through `splitElementChildren` now — the same partition this view
  // takes, one projection for both.)
  // ── Why this view draws an HTML TABLE, not ER rows (#992) ────
  //
  // An occurrence box has to show `name │ value` per attribute. The
  // three mermaid forms that could carry that were measured against the
  // bundled mermaid 10.9.8 rather than argued from the docs:
  //
  //   erDiagram entity rows — the shape that LOOKS right, and the one
  //     the auto view already uses. Both of its unquoted columns are
  //     ATTRIBUTE_WORDs, `[A-Za-z_][A-Za-z0-9_\-\[\]()]*`, so `42`,
  //     `-5`, `99.5`, `:ok` and `can't` — the values of playground
  //     examples [3], [4] and [5] — CANNOT be spelled in either column.
  //     Putting them there means mangling `min=-5` into `min __5`,
  //     which is the same class of defect as the `"@"` comment this
  //     issue is fixing. Disqualified on the values, not on taste.
  //
  //   classDiagram members — permissive (every probe value survived
  //     except `{`/`}`), but mermaid routes any member containing `(`
  //     into the METHODS compartment, so a paren-carrying value jumps
  //     out of document order into a different half of the box.
  //
  //   flowchart node + HTML label — mermaid renders the label inside a
  //     foreignObject when `htmlLabels` is on, so a real <table> gives
  //     genuinely aligned columns, a header row for the element name,
  //     and CSS control from playground.css. Values are HTML-escaped,
  //     so nothing about a value can break the diagram.
  //
  // The third is what this emits. `htmlLabels` and `securityLevel` are
  // both set explicitly at mermaid.initialize() so the form the labels
  // are written for is the form that renders.
  const INSTANCE_NODE_CAP  = 200;  // bound: a 1,000-box diagram is unreadable
  const INSTANCE_VALUE_CAP = 48;   // per-value cell clip, in characters
  const INSTANCE_ROW_CAP   = 10;   // compact rung: attribute rows per box

  // splitElementChildren partitions one element's / directive's
  // `children` into the three roles the label and the walk each need.
  function splitElementChildren(node) {
    const attrs = [], elems = [], bodies = [];
    const kids = Array.isArray(node.children) ? node.children : [];
    for (const c of kids) {
      if (!c || typeof c !== 'object') continue;
      if (c.kind === 'attribute') attrs.push(c);
      else if (c.kind === 'element' || c.kind === 'directive') elems.push(c);
      else bodies.push(c);
    }
    return { attrs, elems, bodies };
  }

  // instanceValueText renders one JSON-typed value for a graph label.
  // Strings quote; numbers and booleans stay bare; an atom keeps its
  // `:name` spelling rather than being dressed as a string.
  function instanceValueText(v) {
    if (v === null || v === undefined) return 'null';
    if (typeof v === 'number' || typeof v === 'boolean') return String(v);
    const s = String(v);
    if (/^:[A-Za-z_][A-Za-z0-9_-]*$/.test(s)) return s;
    const clipped = (s.length > INSTANCE_VALUE_CAP)
      ? s.slice(0, INSTANCE_VALUE_CAP - 1) + '…'
      : s;
    return `'${clipped}'`;
  }

  // ── Operator-headed elements (#992, owner feedback) ─────
  //
  // `[= $score 87]` and `[>= $score 80]` are ELEMENTS whose head is an
  // operator and whose children are POSITIONAL ARGUMENTS — not
  // attributes. A name│value table is the wrong shape for them: there
  // are no names, only an order. They render as `head arg arg` on the
  // box's caption instead, which is how they are written and how they
  // read.
  //
  // Detecting one is DERIVED, not enumerated. Twelve of the ruled 18
  // heads (#976) are glyphs — `+ * - / % = != < <= > >= ~` — and a glyph
  // is precisely a name the identifier production cannot spell, so the
  // test below covers any glyph head the evaluator ever gains without
  // this file being told. Only the six WORD heads need listing, and
  // those are the stable half. The alphabet's single home is
  // `cx.operator_head_len` (vcx/cx/lexical.v); this is a presentation
  // test, not a second copy of the rule.
  const WORD_OPERATOR_HEADS = new Set(
    ['and', 'or', 'not', 'union', 'intersect', 'except']);
  const IDENTIFIER_NAME = /^[A-Za-z_][A-Za-z0-9_:.-]*$/;
  function isOperatorHead(name) {
    const n = String(name || '');
    if (n === '' || n === '_') return false;
    return WORD_OPERATOR_HEADS.has(n) || !IDENTIFIER_NAME.test(n);
  }

  const INSTANCE_ARG_CAP = 4;   // compact rung: args shown on a caption

  // instanceArgText renders ONE positional argument. A `$ref` stays bare
  // — it is a reference to a binding, and quoting it would dress it as
  // the literal string `'$score'`, which is a different program.
  function instanceArgText(v) {
    if (typeof v === 'string' && /^\$[A-Za-z_][A-Za-z0-9_-]*$/.test(v)) return v;
    return instanceValueText(v);
  }

  // instanceOperatorCaption composes `head arg arg …` for an
  // operator-headed element, honouring the detail rung: `min` keeps the
  // bare head, `compact` shows the first few args and counts the rest,
  // `full` shows every one.
  //
  // An ELEMENT child (a nested sub-expression, `[>= [+ $a 1] 80]`) is
  // rendered in place as `[name]` AND still drawn as its own box below.
  // The placeholder is not redundant: without it the caption would read
  // `>= 80`, quietly losing an operand and misreporting the arity.
  function instanceOperatorCaption(node, level) {
    const head = String(node.name || '_');
    if (level === 'min') return head;
    const kids = Array.isArray(node.children) ? node.children : [];
    const args = [];
    for (const c of kids) {
      if (!c || typeof c !== 'object') continue;
      if (c.kind === 'element' || c.kind === 'directive') {
        args.push(`[${(c.kind === 'directive' ? '?' : '') + String(c.name || '_')}]`);
      } else if (c.kind === 'attribute') {
        args.push(`${c.name}=${instanceValueText(c.value)}`);
      } else {
        args.push(instanceArgText(c.value));
      }
    }
    if (args.length === 0) return head;
    const cap = (level === 'full') ? args.length : INSTANCE_ARG_CAP;
    const shown = args.slice(0, cap);
    const hidden = args.length - shown.length;
    if (hidden > 0) shown.push(`(+${hidden})`);
    return head + ' ' + shown.join(' ');
  }

  // instanceRows applies the detail rung to one node's table body.
  // `min` shows no rows at all (the occurrence NAMES and their nesting
  // are the whole point at that rung); `compact` caps the rows and says
  // how many it withheld; `full` shows every one. A lone scalar / text
  // body earns a row of its own, labelled by its kind, so a
  // `[greeting "hello"]` occurrence still shows its value.
  function instanceRows(node, level) {
    if (level === 'min') return [];
    // An operator-headed ELEMENT's children are positional args, and
    // they ride its caption (above) rather than becoming table rows.
    // Gated on the kind for the same reason the caption branch is: a
    // DIRECTIVE spelled `[?not …]` is a directive, not the `not`
    // operator, and keeps its own `?`-prefixed rendering.
    if (node.kind === 'element' && isOperatorHead(node.name)) return [];
    const parts = splitElementChildren(node);
    const rows = [];
    for (const a of parts.attrs) {
      rows.push({ k: String(a.name), v: instanceValueText(a.value) });
    }
    // A LONE scalar / text body earns a row — the same rule the Tree
    // pane applies when it rides a single scalar up onto its element's
    // own line. It is deliberately not generalised to "every body":
    // one body is content, many are a LIST, and a list of values is not
    // what a two-column name/value table is for — a five-item sequence
    // would draw a five-row box whose left column says `scalar` five
    // times. (This guard was first written to bound #1000, which had
    // `cxlib.tree()` reporting a sequence literal's PUNCTUATION as
    // scalar children — `(1, 2, 3)` arrived as seven scalars, `(`, 1,
    // `,`, 2, `,`, 3, `)`. That is fixed at the emitter now; the rule
    // stands on its own ground, not on the defect.)
    const usable = parts.bodies.filter(b =>
      (b.kind === 'scalar' || b.kind === 'text')
      && b.value !== '' && b.value !== null && b.value !== undefined);
    if (usable.length === 1 && parts.elems.length === 0) {
      const only = usable[0];
      rows.push({ k: only.kind, v: instanceValueText(only.value), synthetic: true });
    }
    if (level === 'full' || rows.length <= INSTANCE_ROW_CAP) return rows;
    const shown = rows.slice(0, INSTANCE_ROW_CAP);
    const hidden = rows.length - shown.length;
    shown.push({ k: `+${hidden} more`, v: '', overflow: true });
    return shown;
  }

  // htmlText escapes one run of value text for an HTML label, then
  // neutralises `#` — mermaid's own entity introducer, which would
  // otherwise eat a `#35;`-looking tail out of the middle of a value.
  // The HTML escapes are NAMED for exactly that reason: a numeric
  // `&#40;` carries a `#` that mermaid would rewrite before the browser
  // ever saw it. Order matters — `&` first, `#` last.
  function htmlText(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/[\r\n\t]+/g, ' ')
      .replace(/#/g, '#35;');
  }

  // instanceNodeHtml composes one occurrence box. With no rows to show
  // it stays a plain bold caption rather than a one-cell table, so the
  // `min` rung reads as a clean shape diagram instead of a grid of
  // stubs.
  function instanceNodeHtml(node, level) {
    if (node.kind === 'element' && isOperatorHead(node.name)) {
      const c = instanceOperatorCaption(node, level);
      return `<span class='cxp-itbl-op'>${htmlText(c)}</span>`;
    }
    const title = (node.kind === 'directive' ? '?' : '') + String(node.name || '_');
    const rows = instanceRows(node, level);
    const cap = `<span class='cxp-itbl-name'>${htmlText(title)}</span>`;
    if (rows.length === 0) return cap;
    const body = rows.map(r => {
      const cls = r.overflow ? 'cxp-itbl-more' : (r.synthetic ? 'cxp-itbl-syn' : '');
      return `<tr class='${cls}'>`
        + `<td class='cxp-itbl-k'>${htmlText(r.k)}</td>`
        + `<td class='cxp-itbl-v'>${htmlText(r.v)}</td>`
        + `</tr>`;
    }).join('');
    return `<table class='cxp-itbl'>`
      + `<tr><th colspan='2'>${htmlText(title)}</th></tr>`
      + body
      + `</table>`;
  }

  // mermaidLabel escapes one PLAIN-TEXT label for a quoted Mermaid node
  // body (the cap note, and any caller that is not composing HTML).
  // `#` goes first — the entity form is itself `#`-introduced.
  // Brackets and braces matter in particular because a bracket-valued
  // attribute (`k=[a b]`) is captured VERBATIM by the tree emitter, so
  // real values do carry them.
  function mermaidLabel(s) {
    return String(s)
      .replace(/#/g,  '#35;')
      .replace(/"/g,  '#quot;')
      .replace(/</g,  '#lt;')
      .replace(/>/g,  '#gt;')
      .replace(/\[/g, '#91;')
      .replace(/\]/g, '#93;')
      .replace(/\(/g, '#40;')
      .replace(/\)/g, '#41;')
      .replace(/\{/g, '#123;')
      .replace(/\}/g, '#125;')
      .replace(/[\r\n]+/g, ' ');
  }

  // buildInstanceGraph walks the tree in document order. The cap bounds
  // what is DRAWN, never what is COUNTED — the "showing N of M" note has
  // to be true, so the walk continues past the cap to finish counting.
  function buildInstanceGraph(treeJson, level) {
    if (!treeJson || typeof treeJson !== 'object') return '';
    const lines = ['flowchart TD'];
    let total = 0, drawn = 0, idSeq = 0;
    const walk = (node, parentId) => {
      if (!node || typeof node !== 'object') return;
      let childParent = parentId;
      if (node.kind === 'element' || node.kind === 'directive') {
        total++;
        if (drawn < INSTANCE_NODE_CAP) {
          const myId = `i${idSeq++}`;
          drawn++;
          lines.push(`  ${myId}["${instanceNodeHtml(node, level)}"]`);
          if (parentId) lines.push(`  ${parentId} --> ${myId}`);
          childParent = myId;
        } else {
          childParent = null;   // nothing under an undrawn node is drawn
        }
      }
      const kids = Array.isArray(node.children) ? node.children : [];
      for (const c of kids) walk(c, childParent);
    };
    walk(treeJson, null);
    if (total === 0) {
      // Reachable: a document that is a bare scalar has no occurrence to
      // graph. Say so rather than emit an empty flowchart.
      return 'flowchart TD\n  i0["(no element occurrences to graph)"]';
    }
    if (total > drawn) {
      lines.push(`  cap["${mermaidLabel(
        `showing ${drawn} of ${total} element occurrences (node cap ${INSTANCE_NODE_CAP})`)}"]`);
    }
    return lines.join('\n');
  }

  // ── Graph rendering ─────────────────────────────────────
  let mermaidIdCounter = 0;
  // Mermaid's render() appends a temporary `d<id>` measurement node to <body>
  // and, on a parse failure, injects a "Syntax error" bomb SVG that it does NOT
  // remove — so with an incrementing id these orphans STACK indefinitely. Sweep
  // them before/after every render.
  function sweepMermaidOrphans() {
    document.querySelectorAll(
      'body > [id^="dcxp-mmd-"], body > svg[id^="cxp-mmd-"], body > [id^="cxp-mmd-"]'
    ).forEach(n => n.remove());
  }
  // Mermaid renders are SERIALISED. mermaid.render() is not reentrant:
  // it parks a temporary `d<id>` measurement node on <body> and our
  // sweep removes exactly those — so two renders in flight at once
  // delete each other's scratch node and one of them dies with
  // "Cannot read properties of null". `all` mode draws two diagrams,
  // so the queue is not optional.
  let graphChain = Promise.resolve();
  function renderGraph(src, host) {
    graphChain = graphChain.then(() => renderGraphNow(src, host)).catch((err) => {
      // eslint-disable-next-line no-console
      console.error('[cx-playground] graph render error:', err);
    });
    return graphChain;
  }

  // graphUnavailable — the ONE thing a reader sees when a shape has no
  // renderable diagram (#992). It used to be the raw mermaid source plus
  // mermaid's own parser error, dumped into the pane: a wall of text
  // that tells a person learning CX nothing about their program and
  // reads as if THEY broke something. The diagram source and the error
  // still reach console.debug for diagnosis — they are developer facts,
  // not reader facts.
  function graphUnavailable(host, body, err, why) {
    // eslint-disable-next-line no-console
    console.debug('[cx-playground] graph unavailable (%s):', why || 'parse', err, '\n' + body);
    if (!host || !host.isConnected) return;
    host.innerHTML = '<p class="cxp-viz-placeholder">Graph unavailable for this shape — '
      + 'the Tree tab shows it in full.</p>';
  }

  // `host` is the element to draw into — the whole canvas, or one
  // subject section of it in `all` mode. Each await point re-checks
  // `host.isConnected`: a newer refreshView() may have replaced the
  // canvas contents while mermaid was working, and a detached host
  // must not have its (now stale) diagram painted anywhere visible.
  async function renderGraphNow(src, host) {
    if (!host) return;
    sweepMermaidOrphans();
    if (!src) {
      host.innerHTML = '<p class="cxp-viz-placeholder">(no diagram available)</p>';
      return;
    }
    let body = src.replace(/^%%cx:[^\n]*\n?/m, '').trim();
    body = body.replace(/^```mermaid\s*/, '').replace(/```\s*$/, '').trim();
    if (!body) {
      host.innerHTML = '<p class="cxp-viz-placeholder">(empty diagram)</p>';
      return;
    }
    if (!window.mermaid || typeof window.mermaid.render !== 'function') {
      // Since #1007 the renderer is VENDORED beside this file and both
      // <script>s are `defer` in document order, so by the time anything
      // here runs mermaid is loaded — a CDN that never lands, or a proxy
      // that blocks it, is no longer a state a reader can reach. The
      // branch stays because it costs nothing and a missing asset should
      // read as "still loading", not as a broken shape.
      host.innerHTML = '<p class="cxp-viz-placeholder">Loading the diagram renderer…</p>';
      return;
    }
    // Validate FIRST: mermaid.parse() only validates (no DOM injection), so a
    // bad diagram surfaces a clean inline message instead of mermaid injecting
    // an orphaned bomb SVG into <body>.
    if (typeof window.mermaid.parse === 'function') {
      try {
        await window.mermaid.parse(body);
      } catch (err) {
        graphUnavailable(host, body, err, 'parse');
        sweepMermaidOrphans();
        return;
      }
    }
    if (!host.isConnected) return;
    const id = `cxp-mmd-${++mermaidIdCounter}`;
    try {
      const { svg } = await window.mermaid.render(id, body);
      if (!host.isConnected) return;
      host.innerHTML = svg;
      const svgEl = host.querySelector('svg');
      if (svgEl) {
        svgEl.classList.add('cxp-graph-svg');
        applyGraphTransform();
      }
    } catch (err) {
      graphUnavailable(host, body, err, 'render');
    } finally {
      sweepMermaidOrphans();
    }
  }

  // `all` mode paints two diagrams; zoom applies to every one of them
  // so the program and the value stay at a comparable scale.
  function applyGraphTransform() {
    vizGraphEl.querySelectorAll('svg.cxp-graph-svg').forEach(svg => {
      svg.style.transform = `scale(${graphScale})`;
      svg.style.transformOrigin = 'top left';
    });
  }
  if (graphZoomBtns.zoomIn)  graphZoomBtns.zoomIn .addEventListener('click', () => { graphScale = Math.min(4, graphScale * 1.25); applyGraphTransform(); });
  if (graphZoomBtns.zoomOut) graphZoomBtns.zoomOut.addEventListener('click', () => { graphScale = Math.max(0.25, graphScale / 1.25); applyGraphTransform(); });
  if (graphZoomBtns.fit)     graphZoomBtns.fit    .addEventListener('click', () => { graphScale = 1; applyGraphTransform(); vizGraphEl.querySelector('.cxp-graph-canvas').scrollTo(0, 0); });

  // ── Draggable pane dividers ──────────────────────────────
  // Two strips inside .cxp-main: a vertical column divider (between
  // the left column and the view pane) and a horizontal row divider
  // (between source and output). Mousedown captures, mousemove
  // rewrites --col1-pct / --row1-pct on .cxp-main, mouseup releases.
  (function wireDividers() {
    const main = document.querySelector('.cxp-main');
    const colDiv = document.getElementById('cxp-divider-col');
    const rowDiv = document.getElementById('cxp-divider-row');
    if (!main) return;
    function startDrag(axis, divEl) {
      return (e) => {
        if (e.button !== 0) return;
        e.preventDefault();
        divEl.classList.add('is-dragging');
        document.body.classList.add('cxp-resizing', `is-${axis}`);
        const rect = main.getBoundingClientRect();
        function onMove(ev) {
          if (axis === 'col') {
            const pct = ((ev.clientX - rect.left) / rect.width) * 100;
            const clamped = Math.max(20, Math.min(85, pct));
            main.style.setProperty('--col1-pct', `${clamped}%`);
          } else {
            const pct = ((ev.clientY - rect.top) / rect.height) * 100;
            const clamped = Math.max(15, Math.min(85, pct));
            main.style.setProperty('--row1-pct', `${clamped}%`);
          }
        }
        function onUp() {
          window.removeEventListener('mousemove', onMove);
          window.removeEventListener('mouseup', onUp);
          divEl.classList.remove('is-dragging');
          document.body.classList.remove('cxp-resizing', 'is-col', 'is-row');
        }
        window.addEventListener('mousemove', onMove);
        window.addEventListener('mouseup', onUp);
      };
    }
    if (colDiv) colDiv.addEventListener('mousedown', startDrag('col', colDiv));
    if (rowDiv) rowDiv.addEventListener('mousedown', startDrag('row', rowDiv));
    // Double-click resets the dragged divider to its default.
    if (colDiv) colDiv.addEventListener('dblclick', () => main.style.removeProperty('--col1-pct'));
    if (rowDiv) rowDiv.addEventListener('dblclick', () => main.style.removeProperty('--row1-pct'));
  })();

  // ── Diagram pan (drag) + wheel zoom ──────────────────────
  // Pan: hold mouse on canvas, drag to scroll. Wheel + ctrl: zoom.
  // Wheel alone: native scroll (delegated to canvas overflow:auto).
  (function wireGraphPan() {
    const canvas = vizGraphEl.querySelector('.cxp-graph-canvas');
    if (!canvas) return;
    let dragging = false;
    let startX = 0, startY = 0, scrollLeft = 0, scrollTop = 0;
    canvas.addEventListener('mousedown', (e) => {
      // Only left button, only on background / svg (not on buttons).
      if (e.button !== 0) return;
      if (e.target.closest('.cxp-graph-controls')) return;
      dragging = true;
      startX = e.pageX; startY = e.pageY;
      scrollLeft = canvas.scrollLeft; scrollTop = canvas.scrollTop;
      canvas.style.cursor = 'grabbing';
      e.preventDefault();
    });
    window.addEventListener('mousemove', (e) => {
      if (!dragging) return;
      canvas.scrollLeft = scrollLeft - (e.pageX - startX);
      canvas.scrollTop  = scrollTop  - (e.pageY - startY);
    });
    window.addEventListener('mouseup', () => {
      if (!dragging) return;
      dragging = false;
      canvas.style.cursor = '';
    });
    // Ctrl/Cmd + wheel = zoom; bare wheel = native scroll.
    canvas.addEventListener('wheel', (e) => {
      if (!(e.ctrlKey || e.metaKey)) return;
      e.preventDefault();
      const factor = e.deltaY < 0 ? 1.1 : 1 / 1.1;
      graphScale = Math.max(0.25, Math.min(4, graphScale * factor));
      applyGraphTransform();
    }, { passive: false });
  })();

  // The subjects the View pane must draw, in reading order. `text` is
  // the CX the renderers consume; `register` marks the one tree whose
  // node locs index the editor (the source).
  function vizParts() {
    const srcText = sourceText();
    const source = {
      id: 'source',
      title: 'Source',
      note: reading === 'data' ? 'the document you wrote' : 'the program you wrote',
      text: srcText,
      register: true,
      empty: 'Source is empty.',
    };
    const output = {
      id: 'output',
      title: 'Output',
      note: 'the value it evaluated to',
      text: lastEvalRawCx || '',
      register: false,
      empty: 'No output yet — this program produced none, or its run failed (see the Output pane).',
    };
    if (vizSubject === 'source') return [source];
    if (vizSubject === 'output') return [output];
    return [source, output];
  }

  // Makes the container a subject section draws into. In single-subject
  // mode the pane IS the section (no caption — the toggle already names
  // it); in `all` mode each subject gets a captioned block so the two
  // can never be confused for one another.
  function makeVizSection(parent, part, labelled) {
    const section = document.createElement('div');
    section.className = 'cxp-viz-part';
    section.dataset.subject = part.id;
    if (labelled) {
      const head = document.createElement('div');
      head.className = 'cxp-viz-part-head';
      head.textContent = part.title;
      const note = document.createElement('span');
      note.className = 'cxp-viz-part-note';
      note.textContent = '— ' + part.note;
      head.appendChild(note);
      section.appendChild(head);
    }
    const body = document.createElement('div');
    body.className = 'cxp-viz-part-body';
    section.appendChild(body);
    parent.appendChild(section);
    return body;
  }

  function refreshView() {
    const cxlib = globalThis.cxlib;
    if (!cxlib || !cxlib.ready) return;
    const canvas = vizGraphEl.querySelector('.cxp-graph-canvas');
    const parts = vizParts();
    const labelled = parts.length > 1;
    nodeRegistry = [];
    vizTreeEl.innerHTML = '';
    if (canvas) canvas.innerHTML = '';
    for (const part of parts) {
      const treeHost  = makeVizSection(vizTreeEl, part, labelled);
      const graphHost = canvas ? makeVizSection(canvas, part, labelled) : null;
      if (!part.text) {
        treeHost.innerHTML = `<p class="cxp-viz-placeholder">${escapeHtml(part.empty)}</p>`;
        if (graphHost) graphHost.innerHTML = `<p class="cxp-viz-placeholder">${escapeHtml(part.empty)}</p>`;
        continue;
      }
      // Tree. The parsed tree is hoisted because `Graph: instance`
      // graphs THIS SAME tree — one cxlib.tree() call feeds both panes.
      let parsedTree = null;
      try {
        const treeJson = (typeof cxlib.tree === 'function') ? cxlib.tree(part.text) : null;
        parsedTree = typeof treeJson === 'string' ? JSON.parse(treeJson) : treeJson;
        renderTree(parsedTree, part.text, treeHost, part.register);
      } catch (e) {
        treeHost.innerHTML = `<p class="cxp-viz-placeholder">Tree view unavailable: ${escapeHtml(e.message)}</p>`;
        if (part.register) nodeRegistry = [];
      }
      // Graph — the subject is graphView (#960), the rung is detailLevel.
      try {
        let d;
        if (graphView === 'instance') {
          // INSTANCE: one box per element occurrence, labelled with its
          // own attribute values. Built here from the tree contract.
          if (parsedTree == null) {
            throw new Error('the tree this view graphs is unavailable');
          }
          d = buildInstanceGraph(parsedTree, detailLevel);
        } else {
          // AUTO: the inferred shape (ERD / CFG / SEQ), rendered by the
          // CX diagram module; a FORCED view (erd / cfg / seq / effects,
          // #1377) asks the engine for that subject and shows its refusal
          // when the source cannot carry it. The View pane's detail level
          // rides in the format suffix (`mermaid:LEVEL`).
          const fmtWithDetail = `mermaid:${detailLevel}`;
          d = (typeof cxlib.diagram === 'function') ? cxlib.diagram(part.text, fmtWithDetail, graphView) : '';
        }
        showGraphKind(graphView === 'instance' ? 'instance' : detectedKind(d));
        renderGraph(d, graphHost);
      } catch (e) {
        graphUnavailable(graphHost, '', e, 'build');
      }
    }
  }

  // ── What the page opens on ──────────────────────────────
  // A link wins (#1375): #ex=<fixture id> opens that primer example,
  // #ex=<corpus key> a legacy one, #r=…&d=…&p=… the shared text. Otherwise
  // the first code example a reader should write and the engine runs —
  // the page prints an ANSWER on load, not the wrong half of an anti-pattern
  // pair, a terminal-only or wasm-unsupported fixture, or one whose recorded
  // answer is itself an [err …] (test-playground-primer holds the same rule).
  function openingEntry() {
    const list = entriesOf('code');
    const ok = (e) => {
      const ex = e.ex || {};
      return ex.role !== 'wrong' && ex.runnable !== false
        && !(typeof ex.wasmUnsupported === 'string' && ex.wasmUnsupported.trim())
        && !/^\s*\[err\b/.test(ex.expected || '');
    };
    return list.find(ok) || list[0];
  }
  function openInitial() {
    const h = parseHash(location.hash);
    if (h && h.ex) {
      const hit = ALL_ENTRIES.find(e => e.key === h.ex);
      if (hit) { loadExample(`primer:${hit.key}`); return; }
      if (programEntries[h.ex]) { loadExample(`legacy:${h.ex}`); return; }
    }
    if (h && h.r) {
      current = null;
      applyReading(h.r);
      populatePicker();
      pick.selectedIndex = -1;
      docInput.value = h.d || '';
      input.value = h.p || '';
      syncRender();
      showCrumb(null);
      showFixture(null);
      showExpected(null);
      clearResults();
      refreshView();
      runProgram({ auto: true });
      return;
    }
    const first = openingEntry() || ALL_ENTRIES[0];
    if (first) loadExample(`${first.kind}:${first.key}`);
  }
  // Before the engine is ready the page still shows what it will run.
  (function preload() {
    const h = parseHash(location.hash);
    if (h && (h.r || h.ex)) { applyReading(h.r || 'code'); populatePicker(); return; }
    const first = openingEntry();
    applyReading('code');
    populatePicker();
    if (first) {
      pick.value = `${first.kind}:${first.key}`;
      input.value = first.ex.src || '';
      syncRender();
    }
  })();

  // ── Activate when wasm is ready ─────────────────────────
  const ready = (globalThis.cxlib && globalThis.cxlib.ready)
    ? globalThis.cxlib.ready
    : Promise.reject(new Error('cxlib failed to load — check console'));

  ready.then(() => {
    runBtn.disabled = false;
    setReadyStatus();
    if (window.mermaid && typeof window.mermaid.initialize === 'function') {
      try {
        window.mermaid.initialize({
          startOnLoad: false,
          theme: 'dark',
          securityLevel: 'loose',
          // htmlLabels is what lets the instance view's occurrence boxes
          // be real <table>s (#992). It defaults on, but the labels are
          // WRITTEN for it, so it is set rather than assumed.
          htmlLabels: true,
          flowchart: { curve: 'basis', htmlLabels: true },
        });
      } catch (_) {}
    }
    openInitial();
    // A link pasted into this same tab changes only the hash; the page's own
    // hash updates go through replaceState, which fires no hashchange.
    window.addEventListener('hashchange', openInitial);
  }, (err) => {
    setStatus(`Failed to load wasm runtime: ${escapeHtml(err.message)}`, 'error');
  });

  // ── Run ────────────────────────────────────────────────
  //
  // One evaluator for both the Run button and the automatic run that
  // follows an example switch, with two guards:
  //
  //   runToken   — every request takes a ticket. Nothing paints unless
  //                its ticket is still the current one, so a switch
  //                during an in-flight run can never leave the previous
  //                example's output (or tree, or diagram) on screen.
  //   runChain   — requests are serialised. The wasm runtime is a
  //                single instance, and several examples sleep for
  //                seconds; overlapping calls would interleave. A
  //                superseded request is dropped at the head of its
  //                turn rather than evaluated and thrown away.
  let runToken = 0;
  let runChain = Promise.resolve();
  let runsInFlight = 0;

  function runProgram(opts) {
    const o = opts || {};
    const token = ++runToken;
    runChain = runChain.then(() => runOnce(token, o)).catch((err) => {
      // eslint-disable-next-line no-console
      console.error('[cx-playground] run chain error:', err);
    });
    return runChain;
  }

  // errValue — a refusal the engine THREW (a parse error, a top-level
  // CXER), shown as the value the language would have made of it: an
  // [err code=… message=…] element. Errors are values in CX, so the output
  // pane shows one as a value — projected to JSON and XML like any other —
  // rather than as a crash banner. The raw message is kept for the
  // fixture verdict, which the corpus pins by its CXER code.
  function cxString(s) {
    return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n') + '"';
  }
  function errValue(msg) {
    const m = /(?:cx-err:)?(CXER\d+):?\s*([\s\S]*)$/.exec(String(msg));
    const code = m ? m[1] : 'CXER0000';
    const text = (m ? m[2] : String(msg)).replace(/^cx-err:CXER\d+:?\s*/, '').trim();
    return `[err code=${code} message=${cxString(text || String(msg))}]`;
  }

  // ── A stopped engine is restarted, not shown as the answer ─────────
  // The wasm engine is one module instance built `-gc none`: its arena is
  // never reclaimed, so after enough runs in one page (measured: ~90 primer
  // examples with the Tree view drawing each) an eval dies inside the engine
  // — `memory access out of bounds`, `Program terminated`, an abort — and
  // every later call dies the same way. That is not the program's answer.
  // The page reloads itself on the text in the editors (its share link),
  // which gives a fresh engine, and runs it again there. If a FRESH engine
  // stops on that same text, that IS the answer and it is shown as a value.
  const ENGINE_STOPPED_RE = /memory access out of bounds|table index is out of bounds|\bunreachable\b|null function|indirect call|Aborted\(|Program terminated|program has already aborted|must be non-NULL and non-empty/i;
  function engineStopped(err, msg) {
    return (typeof WebAssembly !== 'undefined' && err instanceof WebAssembly.RuntimeError)
      || ENGINE_STOPPED_RE.test(msg);
  }
  function restartEngine() {
    const target = shareHash();
    let tried = '';
    try { tried = sessionStorage.getItem('cxp.restartedFor') || ''; } catch (_) { return false; }
    if (tried === target) {
      try { sessionStorage.removeItem('cxp.restartedFor'); } catch (_) {}
      return false;
    }
    try {
      sessionStorage.setItem('cxp.restartedFor', target);
      sessionStorage.setItem('cxp.restarts', String(1 + Number(sessionStorage.getItem('cxp.restarts') || 0)));
    } catch (_) { return false; }
    setStatus('The engine stopped after many runs in this page — restarting it on this text…', 'pending');
    try { history.replaceState(null, '', target); } catch (_) {}
    location.reload();
    return true;
  }
  function engineHealthy() {
    try { sessionStorage.removeItem('cxp.restartedFor'); } catch (_) {}
  }

  async function runOnce(token, o) {
    if (token !== runToken) return;          // superseded before we started
    const cxlib = globalThis.cxlib;
    if (!cxlib || !cxlib.ready) return;
    const rd = reading;
    const doc = docInput ? docInput.value : '';
    const prog = stripAnnotation(input.value);
    const src = rd === 'data' ? doc : prog;
    if (!src.trim()) {
      if (!o.auto) setStatus(rd === 'data'
        ? 'The document is empty. Pick an example or type a document.'
        : 'The program is empty. Pick an example or type something to evaluate.', 'error');
      return;
    }
    for (const k of Object.keys(outs)) { outs[k].dataset.raw = ''; outs[k].textContent = ''; }
    runsInFlight++;
    runBtn.classList.add('is-running');
    runBtn.disabled = true;
    setStatus('Evaluating…', 'pending');
    // An explicit Run holds the "Evaluating…" state briefly so the click
    // reads as an action; an automatic run only yields a frame.
    await new Promise(r => setTimeout(r, o.auto ? 0 : 300));

    let accumulated = '';
    let raw = '';                            // what the fixture verdict reads
    try {
      if (token !== runToken) { finishRun(); return; }
      if (rd === 'data') {
        // The data reading: the text IS the value (`--from=cx --to=cx`).
        accumulated = cxlib.toCx(doc);
      } else {
        const bound = rd === 'query' ? doc : '';
        if (typeof cxlib.evalCodeStreamingAsync === 'function') {
          await cxlib.evalCodeStreamingAsync(prog, 'cx', (chunk) => {
            accumulated += chunk;
            if (token === runToken) outs.cx.textContent = accumulated;
          }, bound);
        } else if (typeof cxlib.evalCodeAsync === 'function') {
          accumulated = await cxlib.evalCodeAsync(prog, 'cx', bound);
        } else {
          accumulated = cxlib.evalCode(prog, 'cx', bound);
        }
      }
      raw = accumulated;
      engineHealthy();
    } catch (err) {
      if (token !== runToken) { finishRun(); return; }
      const msg = (err && err.message) ? err.message : String(err);
      raw = msg;
      // eslint-disable-next-line no-console
      console.error('[cx-playground] refused:', err);
      if (wasmUnsupportedNote) {
        // The corpus already knew this engine refuses this program (#1033).
        accumulated = '';
        showRefusal(
          `// not supported in this playground build\n`
          + `// ${wasmUnsupportedNote}\n`
          + `// ${WASM_UNSUPPORTED_REMEDY}\n`
          + `//\n`
          + `// engine detail: ${msg}`);
        lastEvalRawCx = '';
        refreshView();
        showVerdict(raw);
        setStatus(`${wasmUnsupportedNote} ${WASM_UNSUPPORTED_REMEDY}`, 'pending');
        finishRun();
        return;
      }
      if (engineStopped(err, msg) && restartEngine()) { finishRun(); return; }
      accumulated = errValue(msg);
    }
    try {
      if (token !== runToken) return;        // a newer request owns the panes
      outs.cx.dataset.raw = accumulated;
      if (accumulated) {
        try { outs.json.dataset.raw = cxlib.toJson(accumulated); }
        catch (e) { outs.json.dataset.raw = `// JSON projection failed: ${e.message}`; }
        try { outs.xml.dataset.raw  = cxlib.toXml(accumulated); }
        catch (e) { outs.xml.dataset.raw = `// XML projection failed: ${e.message}`; }
      }
      applyOutputProjection();
      lastEvalRawCx = accumulated;
      refreshView();
      showVerdict(raw);
      const isErr = /^\s*\[err\b/.test(accumulated);
      const note = o.capNote || (grantsNote ? grantsLine(grantsNote) : '');
      if (accumulated) {
        setStatus(note || (isErr ? `Evaluated to an error value — ${accumulated.length} bytes.`
                                 : `Evaluated — ${accumulated.length} bytes.`),
                  note ? 'pending' : 'ok');
      } else {
        // An empty result is a real answer (e.g. an empty comprehension),
        // but a blank pane looks like a failure — say so in the pane.
        showRefusal('// evaluated to nothing — this program produced no output');
        setStatus(note || 'Evaluated — empty result.', note ? 'pending' : 'ok');
      }
    } finally {
      finishRun();
    }
  }
  // body[data-ran] counts settled runs: what a reader sees as "the answer
  // arrived", and what test-playground-primer waits on instead of a sleep.
  let settledRuns = 0;
  function finishRun() {
    runsInFlight--;
    if (runsInFlight <= 0) {
      runsInFlight = 0;
      runBtn.classList.remove('is-running');
      runBtn.disabled = false;
      document.body.dataset.ran = String(++settledRuns);
    }
  }

  // reader is looking at carries the explanation.
  function showRefusal(text) {
    for (const k of Object.keys(outs)) {
      outs[k].dataset.raw = text;
      outs[k].textContent = text;
      updateGutter(outGutters[k], text);
    }
    if (fmtBtn) fmtBtn.textContent = prettyMode ? 'Pretty' : 'Minified';
  }

  runBtn.addEventListener('click', () => {
    if (runBtn.disabled) return;
    runProgram({ auto: false });
  });

  // ── Verification seam (#992) ─────────────────────────────
  // scripts/test_playground_mermaid.mjs parses EVERY diagram this page
  // can emit — each example × {auto, instance} × {source, output} ×
  // each detail rung — against the very bundle the page loads: since
  // #1007 both read scripts/gen_guide/playground/vendor/mermaid.min.js,
  // so "the gate's mermaid" and "the reader's mermaid" are one artifact
  // and cannot drift (they were two independent pins before).
  // The instance graphs are built HERE, in the browser, so the gate has
  // to reach this builder rather than reimplement it; a reimplementation
  // would verify a copy and let the shipped one rot. That is the whole
  // seam: one function, read-only, named for what it is.
  window.cxPlaygroundInternals = { buildInstanceGraph };
})();
