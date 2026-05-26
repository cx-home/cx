// CX Playground — controller.
//
// Wires toolbar + source editor (textarea + highlighted render layer)
// + output tabs (CX/JSON/XML) + view tabs (Tree/Graph) + status.
// Streams through cxlib.evalCodeStreamingAsync; rebuilds the view
// pane from cxlib.tree() / cxlib.diagram() on every Run.

(function () {
  'use strict';

  const examples = (window.cxPlaygroundExamples || { data: {}, program: {} });
  const pick     = document.getElementById('cxp-pick');
  const input    = document.getElementById('cxp-input');
  const renderEl = document.getElementById('cxp-input-render');
  const runBtn   = document.getElementById('cxp-run');
  const resetBtn = document.getElementById('cxp-reset');
  const loadBtn  = document.getElementById('cxp-load');
  const loadFile = document.getElementById('cxp-load-file');
  const status   = document.getElementById('cxp-status');
  const tabs     = [...document.querySelectorAll('.cxp-tab')];
  const vizTabs  = [...document.querySelectorAll('.cxp-viz-tab')];
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
  const vizGraphEl = document.querySelector('#cxp-viz-graph code');
  const vizPanes   = {
    tree:  document.getElementById('cxp-viz-tree'),
    graph: document.getElementById('cxp-viz-graph'),
  };

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
    function group(label, entries, prefix) {
      const keys = Object.keys(entries);
      if (keys.length === 0) return;
      const g = document.createElement('optgroup');
      g.label = label;
      for (const key of keys) {
        const ex = entries[key];
        const o = document.createElement('option');
        o.value = `${prefix}:${key}`;
        o.textContent = ex.label || key;
        g.appendChild(o);
      }
      pick.appendChild(g);
    }
    group('Data',     examples.data    || {}, 'data');
    group('Programs', examples.program || {}, 'program');
  }
  populatePicker();

  function lookup(key) {
    if (!key) return null;
    if (key.startsWith('data:')) {
      const ex = (examples.data || {})[key.slice(5)];
      return ex ? { kind: 'data', ex } : null;
    }
    if (key.startsWith('program:')) {
      const ex = (examples.program || {})[key.slice(8)];
      return ex ? { kind: 'program', ex } : null;
    }
    return null;
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

  // Sync the render layer's content to whatever the textarea shows.
  function syncRender() {
    if (!renderEl) return;
    renderEl.innerHTML = highlight('cx', input.value);
  }
  // Keep scroll positions in sync between the textarea and render layer.
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
    // Clear prior output + view so the user knows nothing has been
    // evaluated against the freshly-loaded source.
    for (const k of Object.keys(outs)) outs[k].textContent = '';
    resetVizPanes();
  }

  pick.addEventListener('change', () => loadExample(pick.value));
  resetBtn.addEventListener('click', () => loadExample(pick.value));
  input.addEventListener('input', syncRender);
  input.addEventListener('scroll', syncScroll);

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
      resetVizPanes();
      setStatus(`Loaded ${escapeHtml(f.name)} (${f.size} bytes). Click Run.`, 'ok');
    };
    reader.readAsText(f);
    loadFile.value = '';
  });

  // ── Output tab switching ─────────────────────────────────
  tabs.forEach(t => t.addEventListener('click', () => setOutTab(t.dataset.tab)));
  function setOutTab(name) {
    tabs.forEach(t => t.classList.toggle('is-active', t.dataset.tab === name));
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
  }

  function resetVizPanes() {
    vizTreeEl.innerHTML = '<p class="cxp-viz-placeholder">Run a program to see its structural tree.</p>';
    if (vizGraphEl) vizGraphEl.textContent = '';
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
  // cxlib.tree(src) returns a JSON-shaped projection of the parsed
  // program. Shape per ADR 0037 D2: a JSON object whose recursive
  // structure mirrors the CX AST. We walk it and emit collapsible
  // HTML rows. Any unknown shape falls back to a JSON dump.
  function renderTree(treeJson) {
    if (treeJson == null) {
      vizTreeEl.innerHTML = '<p class="cxp-viz-placeholder">(empty tree)</p>';
      return;
    }
    vizTreeEl.innerHTML = '';
    vizTreeEl.appendChild(renderNode(treeJson));
    // Wire toggle clicks
    vizTreeEl.querySelectorAll('.cxt-toggle').forEach(t => {
      t.addEventListener('click', (e) => {
        e.stopPropagation();
        t.closest('.cxt-node').classList.toggle('is-collapsed');
        t.textContent = t.closest('.cxt-node').classList.contains('is-collapsed') ? '▸' : '▾';
      });
    });
  }
  function renderNode(node, label) {
    const wrap = document.createElement('div');
    wrap.className = 'cxt-node';
    if (node === null || node === undefined) {
      wrap.innerHTML = `${labelPart(label)}<span class="cxt-label-meta">null</span>`;
      return wrap;
    }
    if (typeof node === 'string') {
      wrap.innerHTML = `${labelPart(label)}<span class="cxt-label-string">"${escapeHtml(node)}"</span>`;
      return wrap;
    }
    if (typeof node === 'number') {
      wrap.innerHTML = `${labelPart(label)}<span class="cxt-label-number">${node}</span>`;
      return wrap;
    }
    if (typeof node === 'boolean') {
      wrap.innerHTML = `${labelPart(label)}<span class="cxt-label-boolean">${node}</span>`;
      return wrap;
    }
    if (Array.isArray(node)) {
      const toggle = node.length > 0
        ? '<span class="cxt-toggle">▾</span>' : '<span class="cxt-toggle">·</span>';
      wrap.innerHTML = `${toggle}${labelPart(label)}<span class="cxt-label-meta">array(${node.length})</span>`;
      const kids = document.createElement('div');
      kids.className = 'cxt-children';
      node.forEach((c, i) => kids.appendChild(renderNode(c, `[${i}]`)));
      wrap.appendChild(kids);
      return wrap;
    }
    // object — show key:value rows
    const keys = Object.keys(node);
    const isName = keys.length === 1 && typeof node[keys[0]] === 'object';
    const toggle = keys.length > 0
      ? '<span class="cxt-toggle">▾</span>' : '<span class="cxt-toggle">·</span>';
    const head = keys.length === 0
      ? '<span class="cxt-label-meta">{}</span>'
      : `<span class="cxt-label-name">${escapeHtml(keys[0])}</span>` +
        (keys.length > 1 ? ` <span class="cxt-label-meta">…+${keys.length-1}</span>` : '');
    wrap.innerHTML = `${toggle}${labelPart(label)}${head}`;
    const kids = document.createElement('div');
    kids.className = 'cxt-children';
    for (const k of keys) {
      kids.appendChild(renderNode(node[k], k));
    }
    wrap.appendChild(kids);
    return wrap;
  }
  function labelPart(label) {
    if (label == null) return '';
    return `<span class="cxt-label-attr">${escapeHtml(String(label))}</span>: `;
  }

  // Strip the trailing `[-- … --]` annotation block before feeding
  // source to cxlib.tree() / cxlib.diagram(). The wasm tree builder
  // currently emits invalid JSON when block comments are present in
  // the parsed program (escapes a `-` mid-string and breaks JSON.parse).
  // The annotation is purely documentation, so dropping it for the
  // viz pass changes nothing the user can observe.
  function stripAnnotation(src) {
    return src.replace(/\n*\[-{2,}[\s\S]*?-{2,}\]\s*$/, '').trim();
  }

  function refreshView(src) {
    const cxlib = globalThis.cxlib;
    const cleaned = stripAnnotation(src);
    // Tree
    try {
      const treeJson = (typeof cxlib.tree === 'function') ? cxlib.tree(cleaned) : null;
      const parsed = typeof treeJson === 'string' ? JSON.parse(treeJson) : treeJson;
      renderTree(parsed);
    } catch (e) {
      vizTreeEl.innerHTML = `<p class="cxp-viz-placeholder">Tree view unavailable: ${escapeHtml(e.message)}</p>`;
    }
    // Graph (Mermaid source for now — render with a Mermaid lib if/when added)
    if (vizGraphEl) {
      try {
        const d = (typeof cxlib.diagram === 'function') ? cxlib.diagram(cleaned, 'mermaid') : '';
        vizGraphEl.textContent = d || '(no diagram available for this program)';
      } catch (e) {
        vizGraphEl.textContent = `Diagram unavailable: ${e.message}`;
      }
    }
  }

  // ── Activate when wasm is ready ─────────────────────────
  const ready = (globalThis.cxlib && globalThis.cxlib.ready)
    ? globalThis.cxlib.ready
    : Promise.reject(new Error('cxlib failed to load — check console'));

  ready.then(() => {
    runBtn.disabled = false;
    setReadyStatus();
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
    // Clear stale output + view first; hold for 500ms (plain setTimeout
    // because rAF is throttled in background tabs).
    for (const k of Object.keys(outs)) outs[k].textContent = '';
    resetVizPanes();
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
      // Refresh tree + graph from the source (not the output —
      // the view shows program structure, not value structure).
      refreshView(src);
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
