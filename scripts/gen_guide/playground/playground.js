// CX Playground — controller.
//
// Toolbar: example dropdown + prev/next + Run / Reset / Load.
// Source pane (top-left): textarea overlaid on a highlighted render
//   layer. Edits trigger re-highlight + AST re-parse (for the tree).
// Output pane (bottom-left): CX / JSON / XML tabs. Streamed CX fills
//   in chunk-by-chunk; JSON / XML re-derive from the final CX.
// View pane (right column, 1/3 width): Source ↔ Output toggle + Tree
//   ↔ Graph toggle. Tree is interactive; Graph renders Mermaid via
//   the global `mermaid` lib (CDN-loaded).
// Selection bridge: clicking a tree node selects the corresponding
//   text range in the source / output pane (via the AST's loc info).

(function () {
  'use strict';

  const examples = (window.cxPlaygroundExamples || { data: {}, program: {} });
  const programEntries = examples.program || {};
  const dataEntries    = examples.data    || {};

  // Flat ordered list — single dropdown, no optgroup separation.
  const ALL_ENTRIES = [];
  for (const [key, ex] of Object.entries(programEntries)) ALL_ENTRIES.push({ key, kind: 'program', ex });
  for (const [key, ex] of Object.entries(dataEntries))    ALL_ENTRIES.push({ key, kind: 'data',    ex });

  const pick     = document.getElementById('cxp-pick');
  const prevBtn  = document.getElementById('cxp-prev');
  const nextBtn  = document.getElementById('cxp-next');
  const runBtn   = document.getElementById('cxp-run');
  const resetBtn = document.getElementById('cxp-reset');
  const loadBtn  = document.getElementById('cxp-load');
  const loadFile = document.getElementById('cxp-load-file');
  const status   = document.getElementById('cxp-status');
  const input    = document.getElementById('cxp-input');
  const renderEl = document.getElementById('cxp-input-render');
  const outTabs  = [...document.querySelectorAll('.cxp-tab')];
  const vizTabs  = [...document.querySelectorAll('.cxp-viz-tab')];
  const vizSrcTabs = [...document.querySelectorAll('.cxp-viz-src-tab')];
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
  const vizPanes   = { tree: vizTreeEl, graph: vizGraphEl };

  // ── State ─────────────────────────────────────────────────
  let vizSource = 'source';   // which pane the View pane visualizes
  let lastEvalOutput = '';    // last successful CX-projection output

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

  // ── Example dropdown ─────────────────────────────────────
  function populatePicker() {
    pick.innerHTML = '';
    for (const e of ALL_ENTRIES) {
      const o = document.createElement('option');
      o.value = `${e.kind}:${e.key}`;
      o.textContent = e.ex.label || e.key;
      pick.appendChild(o);
    }
  }
  populatePicker();

  function lookup(key) {
    if (!key) return null;
    const idx = ALL_ENTRIES.findIndex(e => `${e.kind}:${e.key}` === key);
    return idx >= 0 ? { idx, ...ALL_ENTRIES[idx] } : null;
  }

  function composeSource(ex) {
    if (!ex) return '';
    if (ex.note) {
      // Trailing `[-- … --]` dash-block comment. Parser strips it
      // at eval time; the editor still shows the prose so each
      // example self-documents.
      return `${ex.input}\n\n[--------------------------------------------\n${ex.note}\n--------------------------------------------]\n`;
    }
    return ex.input;
  }

  function syncRender() {
    if (!renderEl) return;
    renderEl.innerHTML = highlight('cx', input.value);
  }
  function syncScroll() {
    if (!renderEl) return;
    renderEl.parentElement.scrollTop  = input.scrollTop;
    renderEl.parentElement.scrollLeft = input.scrollLeft;
  }

  function loadExample(key) {
    const found = lookup(key);
    if (!found) return;
    input.value = composeSource(found.ex);
    syncRender();
    for (const k of Object.keys(outs)) outs[k].textContent = '';
    lastEvalOutput = '';
    resetVizPanes();
    refreshView();  // populate tree from the source even before Run
  }

  pick.addEventListener('change', () => loadExample(pick.value));
  resetBtn.addEventListener('click', () => loadExample(pick.value));
  prevBtn.addEventListener('click', () => stepExample(-1));
  nextBtn.addEventListener('click', () => stepExample(+1));
  function stepExample(delta) {
    const cur = lookup(pick.value);
    if (!cur) return;
    let next = (cur.idx + delta + ALL_ENTRIES.length) % ALL_ENTRIES.length;
    const target = ALL_ENTRIES[next];
    pick.value = `${target.kind}:${target.key}`;
    loadExample(pick.value);
  }
  input.addEventListener('input', () => { syncRender(); refreshView(); });
  input.addEventListener('scroll', syncScroll);
  // Cursor change → highlight covering tree node.
  ['keyup','mouseup','click','select'].forEach(ev =>
    input.addEventListener(ev, () => highlightTreeAtCursor()));

  // ── Load local file ─────────────────────────────────────
  loadBtn.addEventListener('click', () => loadFile.click());
  loadFile.addEventListener('change', () => {
    const f = loadFile.files && loadFile.files[0];
    if (!f) return;
    const reader = new FileReader();
    reader.onload = () => {
      input.value = String(reader.result || '');
      syncRender();
      for (const k of Object.keys(outs)) outs[k].textContent = '';
      lastEvalOutput = '';
      resetVizPanes();
      refreshView();
      setStatus(`Loaded ${escapeHtml(f.name)} (${f.size} bytes). Click Run.`, 'ok');
    };
    reader.readAsText(f);
    loadFile.value = '';
  });

  // ── Output tab switching ─────────────────────────────────
  outTabs.forEach(t => t.addEventListener('click', () => setOutTab(t.dataset.tab)));
  function setOutTab(name) {
    outTabs.forEach(t => t.classList.toggle('is-active', t.dataset.tab === name));
    for (const k of Object.keys(outPres)) {
      outPres[k].classList.toggle('is-active', k === name);
    }
  }

  // ── View tab switching (Tree / Graph) ────────────────────
  vizTabs.forEach(t => t.addEventListener('click', () => setVizTab(t.dataset.viz)));
  function setVizTab(name) {
    vizTabs.forEach(t => t.classList.toggle('is-active', t.dataset.viz === name));
    for (const k of Object.keys(vizPanes)) {
      vizPanes[k].classList.toggle('is-active', k === name);
    }
    // Re-render the just-revealed tab if the source changed since.
    refreshView();
  }

  // ── View source toggle (Source / Output) ─────────────────
  vizSrcTabs.forEach(t => t.addEventListener('click', () => {
    vizSource = t.dataset.vizsrc;
    vizSrcTabs.forEach(x => x.classList.toggle('is-active', x.dataset.vizsrc === vizSource));
    refreshView();
  }));

  function resetVizPanes() {
    vizTreeEl.innerHTML  = '<p class="cxp-viz-placeholder">Run a program to see its structural tree.</p>';
    vizGraphEl.innerHTML = '<p class="cxp-viz-placeholder">Run a program to see its diagram.</p>';
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
    } else {
      setStatus(
        `Powered by <code>libcx.wasm ${ver}</code> · single-threaded ASYNCIFY — ` +
        `<code>:par</code> produces correct output but doesn't accelerate. ` +
        `For real parallelism: <code>make guide-http</code> or run <code>cx</code> in your terminal.`,
        null);
    }
  }

  // ── Tree view builder ───────────────────────────────────
  // Walk a tree-JSON object, emit collapsible HTML. Records the
  // node-to-loc mapping so cursor-in-source → highlight-in-tree
  // works (and vice-versa).
  let nodeRegistry = [];   // [{loc:{start,end}, el:HTMLElement}, …]
  function renderTree(treeJson) {
    nodeRegistry = [];
    if (treeJson == null) {
      vizTreeEl.innerHTML = '<p class="cxp-viz-placeholder">(empty tree)</p>';
      return;
    }
    vizTreeEl.innerHTML = '';
    vizTreeEl.appendChild(renderNode(treeJson));
    // Toggle clicks + row clicks
    vizTreeEl.querySelectorAll('.cxt-toggle').forEach(t => {
      t.addEventListener('click', (e) => {
        e.stopPropagation();
        const node = t.closest('.cxt-node');
        node.classList.toggle('is-collapsed');
        t.textContent = node.classList.contains('is-collapsed') ? '▸' : '▾';
      });
    });
    vizTreeEl.querySelectorAll('.cxt-row').forEach(row => {
      row.addEventListener('click', (e) => {
        e.stopPropagation();
        const node = row.closest('.cxt-node');
        const locStr = node && node.dataset.loc;
        if (!locStr) return;
        const { start, end } = JSON.parse(locStr);
        // Source-pane: select text range matching loc.
        input.focus();
        input.setSelectionRange(start, end);
        // Mark this tree node as selected (for visual feedback).
        vizTreeEl.querySelectorAll('.cxt-node.is-selected').forEach(n => n.classList.remove('is-selected'));
        node.classList.add('is-selected');
      });
    });
  }

  function renderNode(node, label) {
    const wrap = document.createElement('div');
    wrap.className = 'cxt-node';
    // Capture loc info if the node carries one.
    if (node && typeof node === 'object' && node.loc && typeof node.loc.start === 'number') {
      wrap.dataset.loc = JSON.stringify({ start: node.loc.start, end: node.loc.end });
      nodeRegistry.push({ start: node.loc.start, end: node.loc.end, el: wrap });
    }
    const rowHtml = (toggle, body) =>
      `${toggle}<span class="cxt-row">${labelPart(label)}${body}</span>`;
    if (node === null || node === undefined) {
      wrap.innerHTML = rowHtml('<span class="cxt-toggle">·</span>', '<span class="cxt-label-meta">null</span>');
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
      node.forEach((c, i) => kids.appendChild(renderNode(c, `[${i}]`)));
      wrap.appendChild(kids);
      return wrap;
    }
    // Object
    const keys = Object.keys(node);
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
    for (const k of keys) {
      if (k === 'loc') continue;  // suppress noisy meta
      kids.appendChild(renderNode(node[k], k));
    }
    wrap.appendChild(kids);
    return wrap;
  }
  function labelPart(label) {
    if (label == null) return '';
    return `<span class="cxt-label-attr">${escapeHtml(String(label))}</span>: `;
  }

  function highlightTreeAtCursor() {
    if (vizSource !== 'source') return;
    if (!nodeRegistry.length) return;
    const pos = input.selectionStart;
    // Find tightest node covering pos (smallest span).
    let best = null, bestSpan = Infinity;
    for (const n of nodeRegistry) {
      if (n.start <= pos && pos <= n.end) {
        const span = n.end - n.start;
        if (span < bestSpan) { best = n; bestSpan = span; }
      }
    }
    vizTreeEl.querySelectorAll('.cxt-node.is-selected').forEach(el => el.classList.remove('is-selected'));
    if (best) {
      best.el.classList.add('is-selected');
      // Auto-expand ancestors so the selected node is visible.
      let p = best.el.parentElement;
      while (p && p !== vizTreeEl) {
        if (p.classList && p.classList.contains('cxt-node')) {
          p.classList.remove('is-collapsed');
        }
        p = p.parentElement;
      }
      best.el.scrollIntoView({ block: 'nearest', behavior: 'auto' });
    }
  }

  // Strip the trailing `[-- … --]` annotation block before feeding
  // source to cxlib.tree() / cxlib.diagram() — the wasm tree builder
  // currently chokes on block comments inside the parsed program.
  function stripAnnotation(src) {
    return src.replace(/\n*\[-{2,}[\s\S]*?-{2,}\]\s*$/, '').trim();
  }

  let mermaidIdCounter = 0;
  function renderGraph(src) {
    if (!src) {
      vizGraphEl.innerHTML = '<p class="cxp-viz-placeholder">(no diagram available)</p>';
      return;
    }
    // Strip the `%%cx:<base64>%%` leading comment + any markdown
    // fence wrapping cxlib.diagram() may emit. Keep just the
    // mermaid body (flowchart / sequenceDiagram + nodes).
    let body = src.replace(/^%%cx:[^\n]*\n?/m, '').trim();
    body = body.replace(/^```mermaid\s*/, '').replace(/```\s*$/, '').trim();
    if (!body) {
      vizGraphEl.innerHTML = '<p class="cxp-viz-placeholder">(no diagram body)</p>';
      return;
    }
    if (!window.mermaid || typeof window.mermaid.render !== 'function') {
      // Fallback: show the source as a code block.
      vizGraphEl.innerHTML = `<pre><code>${escapeHtml(body)}</code></pre>`;
      return;
    }
    const id = `cxp-mmd-${++mermaidIdCounter}`;
    window.mermaid.render(id, body).then(({ svg }) => {
      vizGraphEl.innerHTML = svg;
    }).catch(err => {
      vizGraphEl.innerHTML =
        `<p class="cxp-viz-placeholder">Mermaid render failed: ${escapeHtml(err.message)}</p>` +
        `<pre><code>${escapeHtml(body)}</code></pre>`;
    });
  }

  function refreshView() {
    const cxlib = globalThis.cxlib;
    if (!cxlib || !cxlib.ready) return;
    const sourceMode = vizSource === 'source';
    const srcForViz = sourceMode
      ? stripAnnotation(input.value)
      : (lastEvalOutput || '');
    if (!srcForViz) {
      vizTreeEl.innerHTML = `<p class="cxp-viz-placeholder">${sourceMode ? 'Source is empty.' : 'No evaluated output yet — click Run.'}</p>`;
      vizGraphEl.innerHTML = `<p class="cxp-viz-placeholder">${sourceMode ? 'Source is empty.' : 'No evaluated output yet — click Run.'}</p>`;
      nodeRegistry = [];
      return;
    }
    // Tree
    try {
      const treeJson = (typeof cxlib.tree === 'function') ? cxlib.tree(srcForViz) : null;
      const parsed = typeof treeJson === 'string' ? JSON.parse(treeJson) : treeJson;
      renderTree(parsed);
    } catch (e) {
      vizTreeEl.innerHTML = `<p class="cxp-viz-placeholder">Tree view unavailable: ${escapeHtml(e.message)}</p>`;
      nodeRegistry = [];
    }
    // Graph
    try {
      const d = (typeof cxlib.diagram === 'function') ? cxlib.diagram(srcForViz, 'mermaid') : '';
      renderGraph(d);
    } catch (e) {
      vizGraphEl.innerHTML = `<p class="cxp-viz-placeholder">Diagram unavailable: ${escapeHtml(e.message)}</p>`;
    }
  }

  // ── Activate when wasm is ready ─────────────────────────
  const ready = (globalThis.cxlib && globalThis.cxlib.ready)
    ? globalThis.cxlib.ready
    : Promise.reject(new Error('cxlib failed to load — check console'));

  ready.then(() => {
    runBtn.disabled = false;
    setReadyStatus();
    // Initialize Mermaid once the lib has loaded.
    if (window.mermaid && typeof window.mermaid.initialize === 'function') {
      try {
        window.mermaid.initialize({
          startOnLoad: false,
          theme: 'dark',
          securityLevel: 'loose',
          flowchart: { curve: 'basis' },
        });
      } catch (_) {}
    }
    if (pick.options.length > 0) {
      pick.selectedIndex = 0;
      loadExample(pick.value);
    }
  }, (err) => {
    setStatus(`Failed to load wasm runtime: ${escapeHtml(err.message)}`, 'error');
  });

  // ── Run ────────────────────────────────────────────────
  runBtn.addEventListener('click', async () => {
    if (runBtn.disabled) return;
    const cxlib = globalThis.cxlib;
    const src = input.value;
    if (!src.trim()) {
      setStatus('Source is empty. Pick an example or type something to evaluate.', 'error');
      return;
    }
    for (const k of Object.keys(outs)) outs[k].textContent = '';
    runBtn.classList.add('is-running');
    runBtn.disabled = true;
    setStatus('Evaluating…', 'pending');
    await new Promise(r => setTimeout(r, 500));

    let accumulated = '';
    try {
      if (typeof cxlib.evalCodeStreamingAsync === 'function') {
        await cxlib.evalCodeStreamingAsync(src, 'cx', (chunk) => {
          accumulated += chunk;
          outs.cx.textContent = accumulated;
        }, '');
      } else if (typeof cxlib.evalCodeAsync === 'function') {
        accumulated = await cxlib.evalCodeAsync(src, 'cx', '');
        outs.cx.textContent = accumulated;
      } else {
        accumulated = cxlib.evalCode(src, 'cx', '');
        outs.cx.textContent = accumulated;
      }
      if (accumulated) {
        try { outs.json.textContent = cxlib.toJson(accumulated); }
        catch (e) { outs.json.textContent = `// JSON projection failed: ${e.message}`; }
        try { outs.xml.textContent  = cxlib.toXml(accumulated); }
        catch (e) { outs.xml.textContent = `// XML projection failed: ${e.message}`; }
      }
      // Re-highlight output panes.
      Object.entries(outs).forEach(([lang, el]) => {
        const t = el.textContent;
        if (t) el.innerHTML = highlight(lang, t);
      });
      lastEvalOutput = accumulated;
      refreshView();
      setStatus(`Evaluated — ${accumulated.length} bytes.`, 'ok');
    } catch (err) {
      const msg = (err && err.message) ? err.message : String(err);
      setStatus(`Run failed: ${escapeHtml(msg)}`, 'error');
      // eslint-disable-next-line no-console
      console.error('[cx-playground] Run failed:', err);
    } finally {
      runBtn.classList.remove('is-running');
      runBtn.disabled = false;
    }
  });
})();
