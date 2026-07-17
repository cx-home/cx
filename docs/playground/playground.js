// CX Playground — controller.

(function () {
  'use strict';

  const examples = (window.cxPlaygroundExamples || { program: {} });
  const programEntries = examples.program || {};
  const ALL_ENTRIES = [];
  for (const [key, ex] of Object.entries(programEntries)) ALL_ENTRIES.push({ key, kind: 'program', ex });

  const pick     = document.getElementById('cxp-pick');
  const searchEl = document.getElementById('cxp-search');
  const prevBtn  = document.getElementById('cxp-prev');
  const nextBtn  = document.getElementById('cxp-next');
  const runBtn   = document.getElementById('cxp-run');
  const resetBtn = document.getElementById('cxp-reset');
  const loadBtn  = document.getElementById('cxp-load');
  const loadFile = document.getElementById('cxp-load-file');
  const fmtBtn   = document.getElementById('cxp-format');
  const status   = document.getElementById('cxp-status');
  const input    = document.getElementById('cxp-input');
  const renderEl = document.getElementById('cxp-input-render');
  const outTabs  = [...document.querySelectorAll('.cxp-tab')];
  const vizTabs  = [...document.querySelectorAll('.cxp-viz-tab')];
  const vizSrcToggle = document.getElementById('cxp-viz-src-toggle');
  const detailTabs = [...document.querySelectorAll('.cxp-detail-tab')];
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
  let vizSource = 'source';         // 'source' | 'output' — which content the view pane visualizes
  let prettyMode = true;            // output panes are pretty-printed by default
  let lastEvalRawCx   = '';         // last successful raw streaming CX output
  let nodeRegistry    = [];         // [{start, end, el, kind, key}, …] — for source ↔ tree bridge
  let nodeRegistrySource = '';      // which content (source vs output) nodeRegistry maps onto
  let graphScale      = 1;          // current SVG zoom factor
  // Detail level controls how much element-shape information shows up
  // in the View pane (Tree + Graph). 'min' = element name only;
  // 'compact' (default) = name + first 2 attrs + (+N more) + inlined
  // scalar bodies of leaf children; 'full' = name + all attrs +
  // scalar bodies. Persists to localStorage per-browser.
  const COMPACT_ATTR_CAP = 2;
  let detailLevel = 'compact';
  try {
    const stored = localStorage.getItem('cxp.detailLevel');
    if (stored === 'min' || stored === 'compact' || stored === 'full') {
      detailLevel = stored;
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
    // CX — route through cxlib.toCx if available; falls back to a
    // local bracket-depth-aware indenter when wasm isn't ready.
    const cxlib = globalThis.cxlib;
    if (cxlib && typeof cxlib.toCx === 'function') {
      try { return cxlib.toCx(text); } catch (_) {}
    }
    return cxPrettyFallback(text);
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

  // Bracket-aware CX indenter used as fallback when cxlib.toCx isn't
  // available. Wraps a child element / sequence onto its own line when
  // depth changes, indents two spaces per nest level.
  function cxPrettyFallback(text) {
    let depth = 0, out = '', i = 0, inString = false, sq = false;
    while (i < text.length) {
      const c = text[i];
      if (inString) {
        out += c;
        if (c === '\\' && i + 1 < text.length) { out += text[i+1]; i += 2; continue; }
        if ((!sq && c === '"') || (sq && c === '\'')) inString = false;
        i++; continue;
      }
      if (c === '"' || c === '\'') { inString = true; sq = (c === '\''); out += c; i++; continue; }
      if (c === '[') {
        if (out && !out.endsWith('\n') && !out.endsWith(' ')) out += '\n' + '  '.repeat(depth);
        out += '[';
        depth++;
        i++; continue;
      }
      if (c === ']') {
        depth = Math.max(0, depth - 1);
        out += ']';
        i++; continue;
      }
      out += c;
      i++;
    }
    return out.replace(/\n{2,}/g, '\n').trim();
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

  // ── Example dropdown ─────────────────────────────────────
  function populatePicker(filter) {
    pick.innerHTML = '';
    const q = (filter || '').trim().toLowerCase();
    let shown = 0;
    for (const e of ALL_ENTRIES) {
      if (q && !exampleMatches(e, q)) continue;
      const o = document.createElement('option');
      o.value = `${e.kind}:${e.key}`;
      o.textContent = e.ex.label || e.key;
      pick.appendChild(o);
      shown++;
    }
    if (shown === 0) {
      const o = document.createElement('option');
      o.disabled = true;
      o.textContent = `(no matches for "${q}")`;
      pick.appendChild(o);
    }
  }
  // Match an example against a lowercased query: label, tags array,
  // and source text all participate. Multi-word queries AND-match
  // (every word must appear somewhere).
  function exampleMatches(e, q) {
    const haystack = [
      (e.ex.label || '').toLowerCase(),
      (e.ex.tags || []).join(' ').toLowerCase(),
      (e.ex.input || '').toLowerCase(),
    ].join(' ');
    const words = q.split(/\s+/).filter(Boolean);
    return words.every(w => haystack.includes(w));
  }
  populatePicker();

  if (searchEl) {
    searchEl.addEventListener('input', () => {
      populatePicker(searchEl.value);
      // After re-populating, auto-select the first visible option so
      // Run / Reset / prev / next operate on something sensible.
      if (pick.options.length > 0 && !pick.options[0].disabled) {
        pick.selectedIndex = 0;
        loadExample(pick.value);
      }
    });
  }

  function lookup(key) {
    if (!key) return null;
    const idx = ALL_ENTRIES.findIndex(e => `${e.kind}:${e.key}` === key);
    return idx >= 0 ? { idx, ...ALL_ENTRIES[idx] } : null;
  }

  // ANNOTATION_RE matches the trailing `[; ─── … ─── ]` block we append to
  // each example's source. We strip it before feeding source to
  // cxlib.tree() / cxlib.diagram() (wasm tree builder bug with block
  // comments) and we use its position to figure out where the program
  // ends in the editor (for the cursor-to-tree bridge).
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
      return `${ex.input}\n\n[; \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n${ex.note}\n\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500 ]\n`;
    }
    return ex.input;
  }

  function syncRender() {
    if (!renderEl) return;
    renderEl.innerHTML = highlight('cx', input.value);
    updateGutter(inputGutter, input.value);
  }
  function syncScroll() {
    if (!renderEl) return;
    renderEl.parentElement.scrollTop  = input.scrollTop;
    renderEl.parentElement.scrollLeft = input.scrollLeft;
    if (inputGutter) inputGutter.scrollTop = input.scrollTop;
  }

  function loadExample(key) {
    const found = lookup(key);
    if (!found) return;
    input.value = composeSource(found.ex);
    syncRender();
    for (const k of Object.keys(outs)) { outs[k].dataset.raw = ''; outs[k].textContent = ''; }
    lastEvalRawCx = '';
    resetVizPanes();
    refreshView();
    // Examples flagged runnable:false need a capability the file:// wasm
    // sandbox can't grant (net / subprocess / fs). They still Run — they just
    // return a capability-denied `[err …]` value. Surface that up front so the
    // result isn't mistaken for a bug.
    if (found.ex.runnable === false) {
      setStatus('This example needs a capability unavailable in the wasm playground '
        + '(network / subprocess / filesystem). Run it under `make guide-http` or '
        + '`cx --allow-net` in your terminal; here it returns a capability-denied result.',
        'pending');
    }
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
  ['keyup','mouseup','click','select'].forEach(ev =>
    input.addEventListener(ev, () => highlightTreeAtSourceCursor()));

  // ── Load local file ─────────────────────────────────────
  loadBtn.addEventListener('click', () => loadFile.click());
  loadFile.addEventListener('change', () => {
    const f = loadFile.files && loadFile.files[0];
    if (!f) return;
    const reader = new FileReader();
    reader.onload = () => {
      input.value = String(reader.result || '');
      syncRender();
      for (const k of Object.keys(outs)) { outs[k].dataset.raw = ''; outs[k].textContent = ''; }
      lastEvalRawCx = '';
      resetVizPanes();
      refreshView();
      setStatus(`Loaded ${escapeHtml(f.name)} (${f.size} bytes). Click Run.`, 'ok');
    };
    reader.readAsText(f);
    loadFile.value = '';
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
  vizTabs.forEach(t => t.addEventListener('click', () => setVizTab(t.dataset.viz)));
  function setVizTab(name) {
    vizTabs.forEach(t => t.classList.toggle('is-active', t.dataset.viz === name));
    for (const k of Object.keys(vizPanes)) {
      vizPanes[k].classList.toggle('is-active', k === name);
    }
    refreshView();
  }
  if (vizSrcToggle) {
    vizSrcToggle.addEventListener('click', () => {
      vizSource = (vizSource === 'source') ? 'output' : 'source';
      vizSrcToggle.dataset.vizsrc = vizSource;
      vizSrcToggle.textContent = (vizSource === 'source') ? 'Source' : 'Output';
      refreshView();
    });
  }
  function applyDetailActiveState() {
    detailTabs.forEach(t => t.classList.toggle('is-active', t.dataset.detail === detailLevel));
  }
  applyDetailActiveState();
  detailTabs.forEach(t => t.addEventListener('click', () => {
    detailLevel = t.dataset.detail;
    applyDetailActiveState();
    try { localStorage.setItem('cxp.detailLevel', detailLevel); } catch (_) {}
    refreshView();
  }));

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
    } else {
      setStatus(
        `Powered by <code>libcx.wasm ${ver}</code> · single-threaded ASYNCIFY — ` +
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
  function renderTree(treeJson, sourceText) {
    nodeRegistry = [];
    nodeRegistrySource = sourceText || '';
    if (treeJson == null) {
      vizTreeEl.innerHTML = '<p class="cxp-viz-placeholder">(empty tree)</p>';
      return;
    }
    vizTreeEl.innerHTML = '';
    vizTreeEl.appendChild(renderNode(treeJson, null, null));
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
        let { start, end } = JSON.parse(locStr);
        // For source-mode, translate loc offsets (which are computed
        // against the stripped source) onto the textarea's offsets.
        // The annotation we append lives strictly AFTER the stripped
        // source, so program-side offsets are stable — but if the
        // user has deleted content above the click target, the loc
        // may now point past the end. Clamp.
        const target = (vizSource === 'source') ? input.value : '';
        if (vizSource === 'source') {
          const cap = annotationStart(target);
          if (end > cap) end = cap;
          if (start > cap) start = cap;
          input.focus();
          input.setSelectionRange(start, end);
        }
        markSelected(node);
      });
    });
  }

  // ── Inline-attr + inline-scalar helpers (detail-level aware) ──
  // Renders `attrs` as small space-separated chips (`@name=value`) on
  // the element's head row. At Compact, caps at COMPACT_ATTR_CAP and
  // appends `(+K more)`; at Full shows all.
  function renderAttrChips(attrs, level) {
    if (!attrs || attrs.length === 0) return '';
    const cap = (level === 'full') ? attrs.length : COMPACT_ATTR_CAP;
    let out = '';
    for (let i = 0; i < Math.min(attrs.length, cap); i++) {
      const a = attrs[i];
      const name = (a && typeof a === 'object') ? a.name : '';
      const val  = (a && typeof a === 'object') ? a.value : a;
      out += `<span class="cxt-attr-chip">@${escapeHtml(String(name))}=<span class="v">${formatAttrValue(val)}</span></span>`;
    }
    const remaining = attrs.length - cap;
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
  // Renders a single inlined scalar leaf body next to its parent
  // element's name row (Compact/Full only).
  function renderInlineScalar(node) {
    const v = (node && typeof node === 'object') ? node.value : node;
    if (typeof v === 'string')  return `<span class="cxt-inline-scalar">"${escapeHtml(v)}"</span>`;
    if (typeof v === 'number')  return `<span class="cxt-inline-scalar num">${v}</span>`;
    if (typeof v === 'boolean') return `<span class="cxt-inline-scalar bool">${v}</span>`;
    return `<span class="cxt-inline-scalar">${escapeHtml(String(v))}</span>`;
  }

  function renderNode(node, label, inheritedLoc) {
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
      nodeRegistry.push({ start: loc.start, end: loc.end, el: wrap });
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
      node.forEach((c, i) => kids.appendChild(renderNode(c, `[${i}]`, loc)));
      wrap.appendChild(kids);
      return wrap;
    }
    // Object
    const keys = Object.keys(node);
    // ── Element specialization (detail-level aware) ─────────────
    // Elements get inline attr chips + inline-scalar leaf bodies at
    // compact/full; Min hides attrs entirely. Skip keys 'attrs' /
    // 'items' from the default walk and handle them ourselves.
    const isElement = node.kind === 'element' && typeof node.name === 'string';
    let skipKeys = null;
    let inlineScalarValue = null;
    if (isElement) {
      const attrs = Array.isArray(node.attrs) ? node.attrs : [];
      const items = Array.isArray(node.items) ? node.items : [];
      skipKeys = new Set(['kind', 'name', 'attrs', 'items']);
      // Inline scalar leaf body? Only when a single scalar item lives
      // under this element and the user wants at least Compact detail.
      if (detailLevel !== 'min' && items.length === 1) {
        const only = items[0];
        if (only && typeof only === 'object' && only.kind === 'scalar') {
          inlineScalarValue = only;
        }
      }
      const showChildren = !(inlineScalarValue && attrs.length === 0);
      const hasChildren = items.length > 0 || (Object.keys(node).some(k => !skipKeys.has(k)));
      const toggleChar = (showChildren && hasChildren && !inlineScalarValue) ? '▾' : '·';
      let head = `<span class="cxt-label-name">${escapeHtml(node.name)}</span>`;
      if (detailLevel !== 'min' && attrs.length > 0) {
        head += renderAttrChips(attrs, detailLevel);
      }
      if (inlineScalarValue) {
        head += renderInlineScalar(inlineScalarValue);
      }
      wrap.innerHTML = rowHtml(`<span class="cxt-toggle">${toggleChar}</span>`, head);
      // Walk only non-skip keys (excludes attrs/items handled above)
      const kids = document.createElement('div');
      kids.className = 'cxt-children';
      // Walk items as children unless we inlined the single scalar.
      if (!inlineScalarValue) {
        for (const child of items) {
          kids.appendChild(renderNode(child, '', loc));
        }
      }
      for (const k of keys) {
        if (skipKeys.has(k) || k === 'loc') continue;
        kids.appendChild(renderNode(node[k], k, loc));
      }
      wrap.appendChild(kids);
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
          'cxt-label-attr',  nameLoc));
        kids.appendChild(makeLeaf('value', node.value,
          inferValueClass(node.value), valLoc));
      }
    } else {
      for (const k of keys) {
        if (k === 'loc') continue;
        kids.appendChild(renderNode(node[k], k, loc));
      }
    }
    wrap.appendChild(kids);
    return wrap;
  }

  // Synthesize a leaf row with a hand-rolled loc — used to split an
  // attribute into name+value rows. Each leaf is registered for the
  // cursor-to-tree bridge just like a real AST node.
  function makeLeaf(label, value, valueCls, leafLoc) {
    const wrap = document.createElement('div');
    wrap.className = 'cxt-node';
    wrap.dataset.loc = JSON.stringify(leafLoc);
    nodeRegistry.push({ start: leafLoc.start, end: leafLoc.end, el: wrap });
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
    vizTreeEl.querySelectorAll('.cxt-node.is-selected').forEach(n => n.classList.remove('is-selected'));
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
    if (vizSource !== 'source') return;
    if (!nodeRegistry.length) return;
    const pos = input.selectionStart;
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
  async function renderGraph(src) {
    const canvas = vizGraphEl.querySelector('.cxp-graph-canvas');
    if (!canvas) return;
    sweepMermaidOrphans();
    if (!src) {
      canvas.innerHTML = '<p class="cxp-viz-placeholder">(no diagram available)</p>';
      return;
    }
    let body = src.replace(/^%%cx:[^\n]*\n?/m, '').trim();
    body = body.replace(/^```mermaid\s*/, '').replace(/```\s*$/, '').trim();
    if (!body) {
      canvas.innerHTML = '<p class="cxp-viz-placeholder">(empty diagram)</p>';
      return;
    }
    if (!window.mermaid || typeof window.mermaid.render !== 'function') {
      canvas.innerHTML = `<pre><code>${escapeHtml(body)}</code></pre>`;
      return;
    }
    // Validate FIRST: mermaid.parse() only validates (no DOM injection), so a
    // bad diagram surfaces a clean inline message instead of mermaid injecting
    // an orphaned bomb SVG into <body>.
    if (typeof window.mermaid.parse === 'function') {
      try {
        await window.mermaid.parse(body);
      } catch (err) {
        canvas.innerHTML =
          `<p class="cxp-viz-placeholder">Diagram not renderable: ${escapeHtml((err && err.message) || String(err))}</p>` +
          `<pre><code>${escapeHtml(body)}</code></pre>`;
        sweepMermaidOrphans();
        return;
      }
    }
    const id = `cxp-mmd-${++mermaidIdCounter}`;
    try {
      const { svg } = await window.mermaid.render(id, body);
      canvas.innerHTML = svg;
      const svgEl = canvas.querySelector('svg');
      if (svgEl) {
        svgEl.classList.add('cxp-graph-svg');
        graphScale = 1;
        applyGraphTransform();
      }
    } catch (err) {
      canvas.innerHTML =
        `<p class="cxp-viz-placeholder">Mermaid render failed: ${escapeHtml(err.message)}</p>` +
        `<pre><code>${escapeHtml(body)}</code></pre>`;
    } finally {
      sweepMermaidOrphans();
    }
  }

  function applyGraphTransform() {
    const svg = vizGraphEl.querySelector('svg.cxp-graph-svg');
    if (!svg) return;
    svg.style.transform = `scale(${graphScale})`;
    svg.style.transformOrigin = 'top left';
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

  function refreshView() {
    const cxlib = globalThis.cxlib;
    if (!cxlib || !cxlib.ready) return;
    const srcForViz = (vizSource === 'source')
      ? stripAnnotation(input.value)
      : (lastEvalRawCx || '');
    const canvas = vizGraphEl.querySelector('.cxp-graph-canvas');
    if (!srcForViz) {
      const msg = (vizSource === 'source')
        ? 'Source is empty.'
        : 'No evaluated output yet — click Run.';
      vizTreeEl.innerHTML = `<p class="cxp-viz-placeholder">${msg}</p>`;
      if (canvas) canvas.innerHTML = `<p class="cxp-viz-placeholder">${msg}</p>`;
      nodeRegistry = [];
      return;
    }
    // Tree
    try {
      const treeJson = (typeof cxlib.tree === 'function') ? cxlib.tree(srcForViz) : null;
      const parsed = typeof treeJson === 'string' ? JSON.parse(treeJson) : treeJson;
      renderTree(parsed, srcForViz);
    } catch (e) {
      vizTreeEl.innerHTML = `<p class="cxp-viz-placeholder">Tree view unavailable: ${escapeHtml(e.message)}</p>`;
      nodeRegistry = [];
    }
    // Graph
    try {
      // Encode the View pane's current detail level into the format
      // suffix; the V side parses `mermaid:LEVEL` per render_diagram.
      const fmtWithDetail = `mermaid:${detailLevel}`;
      const d = (typeof cxlib.diagram === 'function') ? cxlib.diagram(srcForViz, fmtWithDetail) : '';
      renderGraph(d);
    } catch (e) {
      if (canvas) canvas.innerHTML = `<p class="cxp-viz-placeholder">Diagram unavailable: ${escapeHtml(e.message)}</p>`;
    }
  }

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
    // Strip the trailing `[; ─── note ─── ]` annotation before evaluating,
    // exactly as the tree/diagram path does. The note is documentation, not
    // program input; passing it through is harmless when its brackets balance
    // but turns the block comment unterminated (→ CXER0100) when the prose
    // contains an unbalanced bracket. Stripping makes a Run immune to note
    // content; results are identical for well-formed notes.
    const evalSrc = stripAnnotation(src);
    for (const k of Object.keys(outs)) { outs[k].dataset.raw = ''; outs[k].textContent = ''; }
    runBtn.classList.add('is-running');
    runBtn.disabled = true;
    setStatus('Evaluating…', 'pending');
    await new Promise(r => setTimeout(r, 500));

    let accumulated = '';
    try {
      if (typeof cxlib.evalCodeStreamingAsync === 'function') {
        await cxlib.evalCodeStreamingAsync(evalSrc, 'cx', (chunk) => {
          accumulated += chunk;
          outs.cx.textContent = accumulated;
        }, '');
      } else if (typeof cxlib.evalCodeAsync === 'function') {
        accumulated = await cxlib.evalCodeAsync(evalSrc, 'cx', '');
        outs.cx.textContent = accumulated;
      } else {
        accumulated = cxlib.evalCode(evalSrc, 'cx', '');
        outs.cx.textContent = accumulated;
      }
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
