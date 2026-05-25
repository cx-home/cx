// CX Playground.
//
// 12 starter examples — 3 data + 9 programs — numbered continuously
// 1-12 across both optgroups in the dropdown so users can reference
// "example 7" unambiguously regardless of kind. The slim corpus is
// per the Phase 7.3 brief: a tight, walkable tour rather than the
// v0.7.x 50-example sprawl. Nine starters port forward from v0.7.x
// (now exercising the v0.8.0 surface); three are net-new and showcase
// the v0.8.0 marquee ADRs:
//
//   • ADR 0028 — CXPath as first-class value kind (`//user[@x=y]`)
//   • ADR 0029 — multi-arm [?match] (`:case` / `:when` / `:else`)
//   • ADR 0030 — pure-functional [?modify] (`:set` / `:delete` / …)
//
// Every example carries a single `input` field — the verbatim textarea
// content. Data examples are pure CX (round-trip through toCx / toJson
// / toXml). Program examples intermingle data + directives in one CX
// document; data and code share the same syntax in CX, so the
// playground passes the same source as both the program and the bound
// document to cxlib.evalCode(src, 'cx', src). code.parse
// accepts data literals as expression statements; the directive at
// the tail walks the data literals at the head.
//
// JSON / XML output panes use a *secondary pass* over the program's
// CX output — `cxlib.toJson(programCxOutput)` produces the clean
// data-projection JSON (`{"item":[1,2,3]}`) rather than the AST-JSON
// projection that `evalCode(..., 'json', ...)` emits (which is
// useful for renderers but verbose for the playground UX).
//
// Two modes, decided at page-load time by detecting `window.cxlib`:
//
//  • Live mode: libcx-wasm is bundled with the site. The Run button
//    is enabled, the PLANNED notice is retired, and Run routes the
//    *current source textarea* through cxlib.evalCode / toCx /
//    toJson / toXml — user edits are actually executed.
//
//  • Canned mode (no-wasm fallback): the Run button stays disabled,
//    the PLANNED notice stays, and Run is a re-render of the canned
//    outputs for the selected example. User edits are preserved but
//    never executed.
//
// See docs/concepts/wasm and spec/decisions/0026 + 0037 for the rollout.
(function () {
  'use strict';

  // ── Data starters (3) — pure CX, round-trips through toCx/toJson/toXml.
  const dataExamples = window.cxPlaygroundExamples.data;

  // ── Program starters (9) — six v0.7.x ports + three v0.8.0 ADR debuts.
  //
  //   Ports (6):
  //     find-attr-eq   [?for] over data — attribute predicate
  //     for-seq        [?for] comprehension over a literal sequence
  //     for-where      [?for] :where filter
  //     let-arith      [?let] bind + arithmetic
  //     if-truthy      [?if] :then / :else
  //     def-double     [?def] named closure + invocation
  //
  //   New for v0.8.0 ADRs (3):
  //     cxpath-predicate  ADR 0028 — CXPath `//user[@active=true]`
  //     match-multi       ADR 0029 — multi-arm [?match] :case/:when/:else
  //     modify-set        ADR 0030 — [?modify] :set (structural sharing)
  const programExamples = window.cxPlaygroundExamples.program;



  // ── Lookup helpers ──────────────────────────────────────────────
  // Picker option values use 'data:<key>' or 'program:<key>' prefixes
  // so the kind is recoverable from the value alone.
  function lookupExample(key) {
    if (typeof key !== 'string') return null;
    if (key.startsWith('data:')) {
      const ex = dataExamples[key.slice(5)];
      return ex ? { kind: 'data', key, ex } : null;
    }
    if (key.startsWith('program:')) {
      const ex = programExamples[key.slice(8)];
      return ex ? { kind: 'program', key, ex } : null;
    }
    return null;
  }


  const pick      = document.getElementById('cxp-pick');
  const input     = document.getElementById('cxp-input');
  const inputRender = document.getElementById('cxp-input-render');
  const inputCopy = document.getElementById('cxp-input-copy');
  const runBtn    = document.getElementById('cxp-run');
  const reset     = document.getElementById('cxp-reset');
  const sourceLang = document.getElementById('cxp-source-lang');
  const outCx   = document.querySelector('#cxp-out-cx code');
  const outJson = document.querySelector('#cxp-out-json code');
  const outXml  = document.querySelector('#cxp-out-xml code');
  const status  = document.getElementById('cxp-status');
  const tabs    = document.querySelectorAll('.cxp-tab');
  const panes   = document.querySelectorAll('.cxp-pane');
  const vizSourcePane  = document.getElementById('cxp-viz-source-pane');
  const vizOutputPane  = document.getElementById('cxp-viz-output-pane');
  const vizSourceMount = document.getElementById('cxp-viz-source-mount');
  const vizOutputMount = document.getElementById('cxp-viz-output-mount');
  const sourceRow = document.querySelector('.cxp-source-row');
  const outputRow = document.querySelector('.cxp-output-row');

  if (!pick || !input) return;
  // ── Populate dropdown via <optgroup> (data + program corpora) ──
  // Examples are numbered ("1. Atom — …", "2. Nested — …") within
  // their group so they can be referenced by index in writing /
  // conversation.
  function populatePicker() {
    pick.innerHTML = '';
    let n = 1;
    const dataGroup = document.createElement('optgroup');
    dataGroup.label = 'Data — pure CX (round-trips through toCx/toJson/toXml)';
    for (const [key, ex] of Object.entries(dataExamples)) {
      const opt = document.createElement('option');
      opt.value = 'data:' + key;
      opt.textContent = n + '. ' + ex.label;
      dataGroup.appendChild(opt);
      n++;
    }
    pick.appendChild(dataGroup);
    const progGroup = document.createElement('optgroup');
    progGroup.label = 'Programs — v0.8.0 directives (cxlib.evalCode)';
    for (const [key, ex] of Object.entries(programExamples)) {
      const opt = document.createElement('option');
      opt.value = 'program:' + key;
      opt.textContent = n + '. ' + ex.label;
      progGroup.appendChild(opt);
      n++;
    }
    pick.appendChild(progGroup);
  }
  populatePicker();


  // ── Output-pane Tree | Graph toggle (ADR 0037 D9) ─────────────────
  // Per-pane session-scoped state — held in component state for the
  // lifetime of the playground session, defaults to 'tree' on every
  // fresh source load. cached per source-text identity so an edit
  // invalidates both tree + graph caches (see refreshOutputViz).
  let outputViewMode = 'tree';  // 'tree' | 'graph' — Output pane mode
  const outputCache = { source: null, tree: null, graph: null };

  function syncOutputViewModeButtons() {
    document.querySelectorAll('.cxp-output-view-mode').forEach((b) => {
      b.classList.toggle('is-active', b.dataset.mode === outputViewMode);
    });
  }
  syncOutputViewModeButtons();


  // ── live mode detection (libcx-wasm bundled with the site) ──────────
  // `window.cxlib` is set by /wasm/cxlib.js if the WASM artifacts
  // loaded successfully. The wrapper's `ready` promise resolves once
  // _vinit has run. We capture that promise here and flip the UI
  // state when it lands. Until then the Run button stays disabled and
  // the PLANNED notice stays — exactly the v0.7.0 visual state.
  let liveActive = false;
  // Indirection so setStatus() below can pick up the LIVE-mode
  // default once it flips.
  const statusDefaultHTMLRef = { value: status ? status.innerHTML : '' };

  function activateLiveMode() {
    liveActive = true;
    if (runBtn) {
      runBtn.disabled = false;
      runBtn.removeAttribute('title');
    }
    // Retire the PLANNED notice — swap in a one-line "Powered by
    // libcx.wasm vX.Y.Z" footer per ADR 0026 §D6.
    if (status) {
      const cxlib = globalThis.cxlib;
      const ver = (cxlib && cxlib.version) ? cxlib.version() : 'wasm';
      status.innerHTML = 'Powered by <strong>libcx.wasm ' + ver + '</strong> — '
        + 'edits to the Source pane are evaluated live. '
        + '<a href="concepts/wasm.html">Concepts → WebAssembly Target</a>.';
      status.classList.remove('error', 'info');
      statusDefaultHTMLRef.value = status.innerHTML;
    }
    // The init pass may have toggled Visualize ON before liveActive
    // flipped — in that case the Source diagram pane is showing the
    // "Mermaid diagrams require live libcx.wasm" placeholder. Now
    // that wasm is up, run a deferred Run + refresh so the panes
    // pick up the live evaluator without an extra user click.
    liveEvaluate(pick.value)
      .then((outs) => {
        applyOutputs(outs);
        lastJsonText = outs.json || '';
      })
      .catch(() => { /* swallow — the panes already show canned outputs */ })
      .finally(() => {
        if (typeof refreshSourceViz === 'function' && vizSourceOn) refreshSourceViz();
        if (typeof refreshOutputViz === 'function' && vizOutputOn) refreshOutputViz();
      });
  }

  const liveReady = (typeof globalThis !== 'undefined' && globalThis.cxlib && globalThis.cxlib.ready)
    ? globalThis.cxlib.ready.then(() => true, () => false)
    : Promise.resolve(false);
  liveReady.then(ok => { if (ok) activateLiveMode(); });

  // Status line surfaces transient feedback (Run/Reset/error) on top
  // of the static explanatory default. The default is rich HTML (with
  // a PLANNED badge + <strong> emphasis + a link to concepts/wasm), so
  // we capture the initial innerHTML once and restore that exact
  // markup when transient state clears. Transient text is plain.
  // Pass level='ok'|'error' for the palette flash. Errors stick
  // until the next setStatus call; ok auto-clears after 3s.
  let statusTimer = null;
  function setStatus(msg, level) {
    if (!status) return;
    if (statusTimer) { clearTimeout(statusTimer); statusTimer = null; }
    status.classList.remove('ok', 'error', 'info');
    if (level) status.classList.add(level);
    if (msg) {
      status.textContent = msg;
    } else {
      status.innerHTML = statusDefaultHTMLRef.value;
    }
    if (level && level !== 'error') {
      statusTimer = setTimeout(() => {
        status.classList.remove(level);
        status.innerHTML = statusDefaultHTMLRef.value;
      }, 3000);
    }
  }

  function flashRun(label, cls) {
    if (!runBtn) return;
    const orig = runBtn.dataset.origText || (runBtn.dataset.origText = runBtn.textContent);
    runBtn.textContent = label;
    runBtn.classList.add(cls);
    setTimeout(() => { runBtn.textContent = orig; runBtn.classList.remove(cls); }, 1500);
  }

  function highlightOutputs() {
    if (!window.CXHighlight) return;
    for (const el of [outCx, outJson, outXml]) {
      if (!el) continue;
      const cls = el.className.match(/language-([\w-]+)/);
      const lang = cls ? cls[1] : 'cx';
      el.innerHTML = window.CXHighlight.highlight(el.textContent, lang);
    }
  }

  function highlightInput() {
    if (!inputRender) return;
    const lang = (inputRender.className.match(/language-([\w-]+)/) || [, 'cx'])[1];
    // Append a trailing space so the render box always agrees with
    // the textarea on height after a final newline.
    const text = input.value + (input.value.endsWith('\n') ? ' ' : '');
    if (window.CXHighlight) {
      inputRender.innerHTML = window.CXHighlight.highlight(text, lang);
    } else {
      inputRender.textContent = text;
    }
  }

  function syncScroll() {
    if (!inputRender) return;
    const pre = inputRender.parentElement;
    if (!pre) return;
    pre.scrollTop = input.scrollTop;
    pre.scrollLeft = input.scrollLeft;
  }

  function setInputLang(lang) {
    if (sourceLang) sourceLang.textContent = lang;
    if (inputRender) {
      inputRender.className = inputRender.className.replace(/language-[\w-]+/, 'language-' + lang);
    }
  }

  function load(key) {
    const found = lookupExample(key);
    if (!found) return;
    const ex = found.ex;
    // Data examples carry .input; program examples carry .program
    // (the textarea always shows just the program — the .data is
    // combined invisibly at evalCode time).
    input.value = ex.input;
    setInputLang('cx');
    refreshOutputs(key);
    lastJsonText = ex.json || '';
    highlightInput();
    syncScroll();
    // Invalidate per-source viz cache on every fresh load (ADR 0037 D9).
    outputCache.source = null;
    outputCache.tree = null;
    outputCache.graph = null;
    // Fresh source — reset Output view to default 'tree' per ADR 0037 D9.
    outputViewMode = 'tree';
    syncOutputViewModeButtons();
    if (vizOutputOn) refreshOutputViz();
    if (vizSourceOn) refreshSourceViz();
  }

  // Refresh the three output tabs without touching the source pane.
  // Today the outputs come from the canned example corpus — a future
  // libcx-wasm build will route the current source through a live
  // evaluator instead. Either way the Source pane preserves user edits.
  function refreshOutputs(key) {
    const found = lookupExample(key); const ex = found && found.ex;
    if (!ex) return;
    if (outCx)   outCx.textContent = ex.cx;
    if (outJson) outJson.textContent = ex.json;
    if (outXml)  outXml.textContent = ex.xml;
    highlightOutputs();
  }

  function setTab(name) {
    tabs.forEach(t => t.classList.toggle('is-active', t.dataset.tab === name));
    panes.forEach(p => p.classList.toggle('is-active', p.id === 'cxp-out-' + name));
  }

  input.addEventListener('input', () => {
    highlightInput();
    syncScroll();
    // Edit invalidates per-source caches (ADR 0037 D9).
    outputCache.source = null;
    outputCache.tree = null;
    outputCache.graph = null;
  });
  input.addEventListener('scroll', syncScroll);

  // Copy button for the Source pane. Mirrors the global pre>.copy-btn
  // behaviour the scaffold injects for output panes: writes the
  // textarea value to the clipboard, flashes "copied" / "failed", and
  // falls back to a hidden-textarea copy if the async clipboard API
  // is blocked (older browsers, insecure contexts).
  if (inputCopy) {
    inputCopy.addEventListener('click', async () => {
      const text = input.value;
      const flash = (label, cls) => {
        inputCopy.textContent = label;
        inputCopy.classList.add(cls);
        setTimeout(() => { inputCopy.textContent = 'copy'; inputCopy.classList.remove(cls); }, 1500);
      };
      try {
        await navigator.clipboard.writeText(text);
        flash('copied', 'copied');
      } catch (_) {
        try {
          const ta = document.createElement('textarea');
          ta.value = text;
          ta.style.position = 'fixed';
          ta.style.opacity = '0';
          document.body.appendChild(ta);
          ta.select();
          document.execCommand('copy');
          document.body.removeChild(ta);
          flash('copied', 'copied');
        } catch (__) {
          flash('failed', 'failed');
        }
      }
    });
  }

  pick.addEventListener('change', () => load(pick.value));
  reset.addEventListener('click', () => load(pick.value));

  // ── Phase 7.9 — Local file load ─────────────────────────────────
  // "Load…" toolbar button proxies to a hidden <input type="file">.
  // FileReader.readAsText() drops the file content verbatim into the
  // Source pane, then the existing pipeline (highlightInput +
  // refreshSourceViz + refreshOutputViz) picks it up. The Output
  // panes show canned-mode-style empty state until the user clicks
  // Run (live mode: routes the loaded source through cxlib.evalCode;
  // canned mode: panes stay at the last canned outputs).
  //
  // For each of the 12 starters: this UI is sourced-side only —
  // round-trip is verified by selecting a starter, loading its
  // serialized form via this affordance, and confirming the source
  // pane round-trips through the existing eval/tree/diagram glue.
  const loadBtn  = document.getElementById('cxp-load');
  const loadFile = document.getElementById('cxp-load-file');
  if (loadBtn && loadFile) {
    loadBtn.addEventListener('click', () => loadFile.click());
    loadFile.addEventListener('change', (ev) => {
      const file = ev.target.files && ev.target.files[0];
      if (!file) return;
      // Soft size guard — playground inputs are walkable-tour scale.
      // ADR 0037 gate-17 audit noted a ~64 KB soft cap; we surface a
      // friendly status at 256 KB so a user dragging in a giant log
      // file gets a clear signal rather than a UI hang.
      if (file.size > 256 * 1024) {
        setStatus(
          `File "${file.name}" exceeds the 256 KB playground guard. ` +
          'Try a smaller corpus or split the input.',
          'error'
        );
        loadFile.value = '';
        return;
      }
      const reader = new FileReader();
      reader.onload = () => {
        input.value = String(reader.result || '');
        setInputLang('cx');
        highlightInput();
        syncScroll();
        // Invalidate viz caches and refresh — same path as load(key).
        outputCache.source = null;
        outputCache.tree = null;
        outputCache.graph = null;
        outputViewMode = 'tree';
        syncOutputViewModeButtons();
        if (vizSourceOn) refreshSourceViz();
        if (vizOutputOn) refreshOutputViz();
        // Status feedback so users see the affordance landed.
        setStatus(
          `Loaded "${file.name}" (${file.size} bytes). ` +
          (liveActive
            ? 'Click Run to evaluate.'
            : 'Live evaluator not bundled — Source pane shows the loaded file; Output panes keep the last canned outputs.'),
          'ok'
        );
        // Reset the input so the same file can be re-selected.
        loadFile.value = '';
      };
      reader.onerror = () => {
        setStatus(`Failed to read "${file.name}": ${reader.error}`, 'error');
        loadFile.value = '';
      };
      reader.readAsText(file);
    });
  }
  // Live evaluation via cxlib (libcx-wasm v0.8.0 surface — ADR 0037 §D7).
  //
  // Data examples — textarea is pure CX, routed through the
  // canonical-conversion entries (toCx / toJson / toXml).
  //
  // Program examples — textarea is the v0.8.0 program; the bound
  // input document (the example's .data field, optional) lives in
  // the example record. liveEvaluate combines them at Run time and
  // routes through evalCode for the CX output, then takes a
  // secondary pass through toJson / toXml on that CX output for
  // the clean data-projection JSON / XML (vs the verbose AST-JSON
  // that evalCode(..., 'json', ...) would emit).
  async function liveEvaluate(key) {
    const src = input.value;
    const cxlib = globalThis.cxlib;
    const found = lookupExample(key);
    if (!found || found.kind === 'data') {
      return {
        cx:   cxlib.toCx(src),
        json: cxlib.toJson(src),
        xml:  cxlib.toXml(src),
      };
    }
    // Just pass the source straight through. CX is homoiconic — a
    // single source can carry inert data + active directives at the
    // same top level. The runtime auto-binds $doc from leading inert
    // structures when no explicit input is given.
    const dataInput = (found.ex && typeof found.ex.data === 'string')
      ? found.ex.data
      : '';
    // Streaming path: route each [?for] :yield emit through the
    // streaming C ABI so the CX output pane fills in incrementally
    // (visible per-chunk progress instead of one final flush after
    // every wall-clock sleep completes). The streaming wrapper falls
    // back to one-shot eval when the build doesn't expose addFunction
    // / Asyncify. JSON / XML re-derive from the final CX once stream
    // completes — they're not chunk-shaped.
    if (typeof cxlib.evalCodeStreamingAsync === 'function') {
      let accumulated = '';
      if (outCx) outCx.textContent = '';
      await cxlib.evalCodeStreamingAsync(src, 'cx', (chunk) => {
        accumulated += chunk;
        if (outCx) outCx.textContent = accumulated;
      }, dataInput);
      return {
        cx:   accumulated,
        json: accumulated ? cxlib.toJson(accumulated) : '',
        xml:  accumulated ? cxlib.toXml(accumulated) : '',
      };
    }
    // Fallback: one-shot async eval.
    const cxOut = (typeof cxlib.evalCodeAsync === 'function')
      ? await cxlib.evalCodeAsync(src, 'cx', dataInput)
      : cxlib.evalCode(src, 'cx', dataInput);
    return {
      cx:   cxOut,
      json: cxOut ? cxlib.toJson(cxOut) : '',
      xml:  cxOut ? cxlib.toXml(cxOut) : '',
    };
  }

  function applyOutputs(outputs) {
    if (outCx)   outCx.textContent   = outputs.cx;
    if (outJson) outJson.textContent = outputs.json;
    if (outXml)  outXml.textContent  = outputs.xml;
    highlightOutputs();
  }

  // ── Visualize toggles (ADR 0037 D2 + D3 + D9) ──────────────────
  // Source pane → Mermaid diagram via cxlib.diagram (live wasm only;
  // canned mode shows a placeholder since we can't generate Mermaid
  // from the canned corpus). Output pane → Tree | Graph toggle per
  // ADR 0037 D9: Tree mode walks the cxlib.tree() JSON; Graph mode
  // runs cxlib.diagram() (CFG for programs, ERD for data). Tree→text
  // bridge: clicking a tree node highlights the first substring match
  // in the active Output text tab.
  // Source pane viz components — one for each mode. srcVizKind picks
  // which one's currently mounted to vizSourceMount.
  const srcTreeView = (globalThis.CxTreeView && vizSourceMount)
    ? new globalThis.CxTreeView({ onSelect: bridgeHighlight })
    : null;
  const diagView = (globalThis.CxDiagramView && vizSourceMount)
    ? new globalThis.CxDiagramView({ onClose: () => setVizSource(false) })
    : null;
  // Output pane viz components — Tree (containment-only structure
  // of the evaluated value) + Diagram (ERD/CFG via cxlib.diagram).
  const treeView = (globalThis.CxTreeView && vizOutputMount)
    ? new globalThis.CxTreeView({ onSelect: bridgeHighlight })
    : null;
  const outputDiagView = (globalThis.CxDiagramView && vizOutputMount)
    ? new globalThis.CxDiagramView({ onClose: () => setVizOutput(false) })
    : null;
  let vizSourceOn = false;
  let vizOutputOn = false;
  let srcVizKind = 'tree';  // 'tree' | 'graph' — Source pane mode
  let lastSource = '';
  let lastJsonText = '';

  // ADR 0037 D5 — text → tree direction. Source-pane caret moves
  // walk srcTreeView's flat loc index to select the deepest covering
  // tree node. Only the source tree carries source-coordinate loc
  // values; the output tree's coordinates point into the JSON
  // projection (post-evaluation), so the bridge is one-tree-deep on
  // v0.8.0. The tree → text direction lives in bridgeHighlight()
  // and applies to both panes.
  const selectionBridge = (globalThis.CxSelectionBridge && srcTreeView)
    ? new globalThis.CxSelectionBridge({
        editor: input,
        getTreeView: () => (vizSourceOn && srcVizKind === 'tree' ? srcTreeView : null),
      })
    : null;
  if (selectionBridge) selectionBridge.attach();

  // Mode buttons live in the LEFT pane headers (CX Source, CX Output).
  // syncSourceModeButtons / syncOutputModeButtons reflect the current
  // (vizSourceOn, srcVizKind) / vizOutputOn state on the button row.
  function syncSourceModeButtons() {
    document.querySelectorAll('.cxp-viz-mode[data-target="source"]').forEach((b) => {
      b.classList.toggle('is-active', vizSourceOn && b.dataset.mode === srcVizKind);
    });
  }
  function syncOutputModeButtons() {
    document.querySelectorAll('.cxp-viz-mode[data-target="output"]').forEach((b) => {
      b.classList.toggle('is-active', vizOutputOn && b.dataset.mode === 'tree');
    });
  }

  function setVizSource(on) {
    vizSourceOn = !!on;
    if (vizSourcePane) {
      if (vizSourceOn) vizSourcePane.removeAttribute('hidden');
      else vizSourcePane.setAttribute('hidden', '');
    }
    // .has-viz no longer toggles the row layout (grid is always 50/50);
    // we keep the class set for any CSS that wants to read open-state.
    if (sourceRow) sourceRow.classList.toggle('has-viz', vizSourceOn);
    syncSourceModeButtons();
    if (vizSourceOn) refreshSourceViz();
  }

  function setVizOutput(on) {
    vizOutputOn = !!on;
    if (vizOutputPane) {
      if (vizOutputOn) vizOutputPane.removeAttribute('hidden');
      else vizOutputPane.setAttribute('hidden', '');
    }
    if (outputRow) outputRow.classList.toggle('has-viz', vizOutputOn);
    syncOutputModeButtons();
    if (vizOutputOn) refreshOutputViz();
  }

  // Source pane has two viz modes (Tree of the source AST, or Graph
  // via Mermaid). Switching modes unmounts the previous component
  // and mounts the next at the same vizSourceMount element so the
  // pane geometry stays put.
  function setSrcVizKind(kind) {
    srcVizKind = (kind === 'graph') ? 'graph' : 'tree';
    // Unmount the previous component so its toolbar/canvas drop out.
    if (diagView && diagView.container) diagView.unmount();
    if (srcTreeView && srcTreeView.container) srcTreeView.unmount();
    syncSourceModeButtons();
    if (vizSourceOn) refreshSourceViz();
  }

  // Output pane's Tree | Graph toggle per ADR 0037 D9. Mode is
  // per-session, defaults to 'tree' on every fresh source. Cache is
  // per-source: edit invalidates both tree + graph entries.
  function setOutputViewMode(mode) {
    outputViewMode = (mode === 'graph') ? 'graph' : 'tree';
    if (outputDiagView && outputDiagView.container) outputDiagView.unmount();
    if (treeView && treeView.container) treeView.unmount();
    syncOutputViewModeButtons();
    if (vizOutputOn) refreshOutputViz();
  }

  function refreshSourceViz() {
    if (!vizSourceOn || !vizSourceMount) return;
    const src = input.value;
    lastSource = src;
    const cxlib = globalThis.cxlib;
    if (srcVizKind === 'tree') {
      vizSourceMount.classList.add('cxp-viz-tree-mount');
      if (!srcTreeView) {
        vizSourceMount.innerHTML = '<div class="cxdv-empty">Tree view unavailable</div>';
        return;
      }
      if (!srcTreeView.container) srcTreeView.mount(vizSourceMount);
      let parsed = null;
      if (liveActive && cxlib && typeof cxlib.tree === 'function') {
        // Prefer the v0.8.0 cx_code_tree projection (ADR 0037 D2) which
        // carries loc{start,end} for the selection-bridge contract (D5).
        try {
          parsed = cxlib.tree(src);
        } catch (_) {
          // Fallback for pure-data sources where tree() may decline:
          // retry via the universal data projection.
          try {
            const jsonText = cxlib.toJson(src);
            parsed = JSON.parse(jsonText);
          } catch (__) { parsed = null; }
        }
      }
      srcTreeView.update(parsed);
      return;
    }
    // Graph mode — Mermaid via cxlib.diagram (requires live wasm).
    vizSourceMount.classList.remove('cxp-viz-tree-mount');
    if (!diagView) {
      vizSourceMount.innerHTML = '<div class="cxdv-empty">Graph view unavailable</div>';
      return;
    }
    if (!liveActive || !cxlib || typeof cxlib.diagram !== 'function') {
      if (diagView.container) diagView.unmount();
      vizSourceMount.innerHTML =
        '<div class="cxdv-empty">Mermaid diagrams require live libcx.wasm</div>';
      return;
    }
    if (!diagView.container) diagView.mount(vizSourceMount);
    try {
      // ADR 0037 D1 auto-detect: cxlib.diagram emits flowchart (CFG)
      // for code sources, erDiagram for data sources. No JS-side
      // pre-classify — the wasm export does the right thing.
      const mermaidText = cxlib.diagram(src, 'mermaid');
      diagView.render(mermaidText);
    } catch (err) {
      renderDiagramError(vizSourceMount, diagView, err, src);
    }
  }

  // Phase 7.5 — graceful fallback for `i-playground-graph-mixed-input`.
  // When the source mixes top-level data + an EvalDirective at the tail,
  // the v0.8.0 wasm `cx_code_diagram` parser can raise CXER0100 (the V-
  // side parser's mixed-input limit). Per backlog resolution-plan, we
  // emit an empty Mermaid `erDiagram` + a friendly hint rather than
  // surfacing the raw `CXER…:` string in the diagram pane. This keeps
  // the playground walkable for mixed corpus inputs while the V-side
  // graceful-degrade landing path catches up.
  function renderDiagramError(mount, view, err, src) {
    if (!mount) return;
    const raw = String(err && err.message ? err.message : err);
    // CXER0100 (or other CXERnnnn from cx_code_diagram) → soft fallback:
    // unmount the diagram canvas, paint a plain-language hint that
    // matches the canned-mode placeholder vocabulary (".cxdv-empty").
    // The hint nudges the user toward the Tree view, which always
    // works because `cx_code_tree` doesn't depend on full parse success.
    if (/CXER\d+/.test(raw)) {
      if (view && view.container) view.unmount();
      mount.innerHTML =
        '<div class="cxdv-empty">' +
        'Diagram unavailable for this source — mixed data + directives ' +
        "exceed the v0.8.0 parser's diagram surface. " +
        'Switch to <strong>Tree</strong> view for a structural projection.' +
        '</div>';
      return;
    }
    // Non-CXER errors (Mermaid render glitches, etc.) keep the raw
    // message for debuggability — these are programmer-facing.
    mount.innerHTML =
      '<pre class="cxdv-error">' +
      raw.replace(
        /[<&>]/g,
        (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;' }[c])
      ) +
      '</pre>';
  }

  function refreshOutputViz() {
    if (!vizOutputOn || !vizOutputMount) return;
    const cxlib = globalThis.cxlib;
    // Cache lookup: per-source identity, invalidated on edit / load.
    const src = input.value;
    if (outputCache.source !== src) {
      outputCache.source = src;
      outputCache.tree = null;
      outputCache.graph = null;
    }
    if (outputViewMode === 'tree') {
      vizOutputMount.classList.add('cxp-viz-tree-mount');
      if (outputDiagView && outputDiagView.container) outputDiagView.unmount();
      if (!treeView) {
        vizOutputMount.innerHTML = '<div class="cxdv-empty">Tree view unavailable</div>';
        return;
      }
      if (!treeView.container) treeView.mount(vizOutputMount);
      let parsed = outputCache.tree;
      if (parsed === null) {
        // Prefer the live JSON we just emitted; fall back to the active
        // Output JSON tab text (canned-mode path).
        const jsonText = lastJsonText || (outJson ? outJson.textContent : '');
        if (jsonText) {
          try { parsed = JSON.parse(jsonText); } catch (_) { parsed = null; }
        }
        outputCache.tree = parsed;
      }
      treeView.update(parsed);
      return;
    }
    // Graph mode — ADR 0037 D9 toggle: cxlib.diagram on the *Output*
    // text. ERD if the rendered output is pure data (the common case
    // for [?for] / [?modify] / data examples); CFG if the source
    // itself was a program and the diagram applies to the program AST.
    vizOutputMount.classList.remove('cxp-viz-tree-mount');
    if (treeView && treeView.container) treeView.unmount();
    if (!outputDiagView) {
      vizOutputMount.innerHTML = '<div class="cxdv-empty">Graph view unavailable</div>';
      return;
    }
    if (!liveActive || !cxlib || typeof cxlib.diagram !== 'function') {
      if (outputDiagView.container) outputDiagView.unmount();
      vizOutputMount.innerHTML =
        '<div class="cxdv-empty">Mermaid diagrams require live libcx.wasm</div>';
      return;
    }
    if (!outputDiagView.container) outputDiagView.mount(vizOutputMount);
    let mermaidText = outputCache.graph;
    if (mermaidText === null) {
      try {
        // Diagram the source so CFG/ERD auto-detect kicks in per D1.
        // For pure-data starters this renders the ERD; for [?…]
        // starters the CFG.
        mermaidText = cxlib.diagram(src, 'mermaid');
        outputCache.graph = mermaidText;
      } catch (err) {
        renderDiagramError(vizOutputMount, outputDiagView, err, src);
        return;
      }
    }
    outputDiagView.render(mermaidText);
  }

  function bridgeHighlight(node) {
    // Tree → text direction. ADR 0037 D5: prefer loc{start,end} from
    // cx_code_tree if present; fall back to substring match against
    // node.hint for canned-mode trees that lack loc.
    const active = document.querySelector('.cxp-pane.is-active code');
    if (!active || !node) return;
    const text = active.textContent;
    let start = -1, end = -1;
    if (node.loc && typeof node.loc.start === 'number' && typeof node.loc.end === 'number') {
      start = node.loc.start;
      end = node.loc.end;
    } else if (node.hint) {
      start = text.indexOf(node.hint);
      end = start < 0 ? -1 : start + node.hint.length;
    }
    if (start < 0 || end <= start) return;
    // Re-highlight from scratch (escape away any prior <mark>).
    const before = text.slice(0, start);
    const hit = text.slice(start, end);
    const after = text.slice(end);
    const esc = (s) => s.replace(/[<&>]/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;' }[c]));
    // Re-run syntax highlight on before/after if present, but keep
    // the matched span as a flat <mark> (no per-token re-tokenization).
    const lang = (active.className.match(/language-([\w-]+)/) || [, 'cx'])[1];
    const h = (s) => (window.CXHighlight ? window.CXHighlight.highlight(s, lang) : esc(s));
    active.innerHTML = h(before) + '<mark class="cxp-bridge-hit">' + esc(hit) + '</mark>' + h(after);
    // Scroll the match into view.
    const mark = active.querySelector('mark.cxp-bridge-hit');
    if (mark && mark.scrollIntoView) mark.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  }

  // Viz mode buttons live in the LEFT pane headers (CX Source / CX
  // Output) and act as openers for the corresponding visual pane:
  //
  //   Click Tree (inactive) → open visual pane, mode=tree, render
  //   Click Graph (inactive) → open visual pane, mode=graph, render
  //   Click already-active mode → close the visual pane
  //   Click other mode while pane open → switch mode in place
  //
  // The × button in the visual pane header closes that pane and
  // deactivates the corresponding mode buttons. Listeners are
  // document-delegated so dynamically-rendered buttons (e.g. from a
  // future component swap) still respond.
  //
  // The Output pane carries an additional Tree | Graph toggle in its
  // header (ADR 0037 D9) — distinct CSS class .cxp-output-view-mode.
  document.addEventListener('click', (ev) => {
    const outputModeBtn = ev.target.closest && ev.target.closest('.cxp-output-view-mode');
    if (outputModeBtn) {
      setOutputViewMode(outputModeBtn.dataset.mode);
      return;
    }
    const modeBtn = ev.target.closest && ev.target.closest('.cxp-viz-mode');
    if (modeBtn) {
      const target = modeBtn.dataset.target;
      const mode = modeBtn.dataset.mode;
      if (target === 'source') {
        if (vizSourceOn && srcVizKind === mode) {
          // Same active mode clicked → close.
          setVizSource(false);
        } else if (vizSourceOn) {
          // Different mode while open → switch.
          setSrcVizKind(mode);
        } else {
          // Closed → open in the requested mode.
          srcVizKind = mode;
          setVizSource(true);
        }
      } else if (target === 'output') {
        // Output has Tree only — toggle the pane.
        setVizOutput(!vizOutputOn);
      }
      return;
    }
    const closeBtn = ev.target.closest && ev.target.closest('.cxp-viz-close');
    if (closeBtn) {
      const target = closeBtn.dataset.target;
      if (target === 'source') setVizSource(false);
      else if (target === 'output') setVizOutput(false);
    }
  });

  runBtn.addEventListener('click', async () => {
    try {
      const key = pick.value;
      const found = lookupExample(key); const ex = found && found.ex;
      if (!ex) {
        throw new Error(`no example registered for '${key}'`);
      }
      if (liveActive) {
        // Clear stale output panes on each Run so the user sees a
        // visible "something happened" reset before the new eval
        // completes. Wall-clock examples can take seconds; without
        // the clear, the panes appear frozen on the previous result.
        applyOutputs({ cx: '', json: '', xml: '' });
        // Async evaluate via the Worker host (ADR 0039 D8) so bare
        // wall-clock [?sleep DUR] examples don't freeze the UI.
        setStatus('Evaluating…', 'pending');
        // Yield to the browser so the cleared panes actually paint
        // before we kick off the eval. Without this, instant evals
        // (data examples, :mock examples) clear-and-fill within one
        // microtask flush and the user perceives "no change" — the
        // cleared state never reaches the screen. rAF guarantees a
        // paint when the tab is visible; setTimeout backstop covers
        // hidden tabs (where rAF is throttled or paused entirely)
        // so the eval doesn't hang waiting for a frame that never
        // arrives. Whichever fires first wins.
        await new Promise(r => {
          let done = false;
          const resolve = () => { if (!done) { done = true; r(); } };
          requestAnimationFrame(resolve);
          setTimeout(resolve, 30);
        });
        const outs = await liveEvaluate(key);
        applyOutputs(outs);
        lastJsonText = outs.json || '';
        // Run invalidates the per-source viz cache — new live emit.
        outputCache.source = null;
        outputCache.tree = null;
        outputCache.graph = null;
        flashRun('evaluated', 'ran');
        setStatus('Source evaluated through libcx.wasm.', 'ok');
      } else {
        // Canned-corpus fallback: re-render the recorded outputs
        // for the selected example. User edits are preserved but
        // not executed — libcx-wasm is not bundled with this site.
        const orig = ex.input;
        const edited = input.value !== orig;
        refreshOutputs(key);
        lastJsonText = ex.json || '';
        flashRun(edited ? 'rendered (no eval)' : 'rendered', 'ran');
        setStatus(
          edited
            ? "Output panes re-rendered from the canned corpus. Your Source edits aren't being executed — libcx-wasm is not built yet."
            : 'Canned outputs re-rendered for the selected example.',
          'ok'
        );
      }
      // Viz refresh happens in the finally block below so a failed
      // live-eval still drives the Source-pane diagram.
    } catch (err) {
      flashRun('failed', 'failed');
      setStatus(`Run failed: ${err && err.message ? err.message : err}`, 'error');
      // eslint-disable-next-line no-console
      console.error('[cx-playground] Run failed:', err);
    } finally {
      // Viz refresh runs in finally so a failed live-eval (Output
      // pane keeps its prior state) still drives the diagram pane
      // — Source-pane Visualize is a property of the source text,
      // not the eval result, and the tree falls back to the
      // previous JSON snapshot when lastJsonText is stale.
      if (vizSourceOn) refreshSourceViz();
      if (vizOutputOn) refreshOutputViz();
    }
  });
  tabs.forEach(t => t.addEventListener('click', () => setTab(t.dataset.tab)));

  // Initial load — surface boot errors visibly rather than silently
  // failing to populate the panes.
  try {
    load(pick.value || 'data:atom');
    // Visualize toggles default ON so users see the diagram + tree
    // immediately without an extra click. Each toggle is still a
    // user-controllable switch — clicking turns them off.
    setVizSource(true);
    setVizOutput(true);
  } catch (err) {
    setStatus(`Playground failed to initialise: ${err && err.message ? err.message : err}`, 'error');
    // eslint-disable-next-line no-console
    console.error('[cx-playground] init failed:', err);
  }
})();
