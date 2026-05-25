// CX Playground — slim controller.
//
// Wires the toolbar + source pane + output tabs + status bar to
// cxlib.evalCodeStreamingAsync. No tree views, no diagrams, no
// selection bridge, no canned-corpus fallback — wasm is always
// available (libcx-async.js is SINGLE_FILE so file:// works too;
// libcx-pthreads.js takes over under crossOriginIsolated HTTP).
//
// Example records (playground.examples.js):
//   { label, input, note? }    program example
//   { label, input }           data example
// `note` is appended to the editor as a trailing `[- … -]` block
// comment so the example is self-documenting and the parser strips
// the prose at eval time.

(function () {
  'use strict';

  const examples = (window.cxPlaygroundExamples || { data: {}, program: {} });
  const pick     = document.getElementById('cxp-pick');
  const input    = document.getElementById('cxp-input');
  const runBtn   = document.getElementById('cxp-run');
  const resetBtn = document.getElementById('cxp-reset');
  const loadBtn  = document.getElementById('cxp-load');
  const loadFile = document.getElementById('cxp-load-file');
  const status   = document.getElementById('cxp-status');
  const tabs     = [...document.querySelectorAll('.cxp-tab')];
  const outs     = {
    cx:   document.getElementById('cxp-out-cx'),
    json: document.getElementById('cxp-out-json'),
    xml:  document.getElementById('cxp-out-xml'),
  };

  // ── Example dropdown ───────────────────────────────────────
  function populatePicker() {
    pick.innerHTML = '';
    function group(label, entries) {
      if (Object.keys(entries).length === 0) return;
      const g = document.createElement('optgroup');
      g.label = label;
      for (const [key, ex] of Object.entries(entries)) {
        const o = document.createElement('option');
        o.value = label === 'Data' ? `data:${key}` : `program:${key}`;
        o.textContent = ex.label || key;
        g.appendChild(o);
      }
      pick.appendChild(g);
    }
    group('Data', examples.data || {});
    group('Programs', examples.program || {});
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
      // Trailing `[- … -]` block comment. CX strips block comments
      // at parse time; the editor still shows the prose so the
      // example documents itself.
      return `${ex.input}\n\n[--------------------------------------------\n${ex.note}\n--------------------------------------------]\n`;
    }
    return ex.input;
  }

  function loadExample(key) {
    const found = lookup(key);
    if (!found) return;
    input.value = composeSource(found.ex);
    // Clear any prior output so the user knows nothing has been
    // evaluated against the freshly-loaded source.
    for (const k of Object.keys(outs)) outs[k].textContent = '';
  }

  pick.addEventListener('change', () => loadExample(pick.value));
  resetBtn.addEventListener('click', () => loadExample(pick.value));

  // ── Load local file ─────────────────────────────────────────
  loadBtn.addEventListener('click', () => loadFile.click());
  loadFile.addEventListener('change', () => {
    const f = loadFile.files && loadFile.files[0];
    if (!f) return;
    const reader = new FileReader();
    reader.onload = () => {
      input.value = String(reader.result || '');
      for (const k of Object.keys(outs)) outs[k].textContent = '';
      setStatus(`Loaded ${f.name} (${f.size} bytes). Click Run to evaluate.`, 'ok');
    };
    reader.readAsText(f);
    loadFile.value = '';
  });

  // ── Tab switching ──────────────────────────────────────────
  tabs.forEach(t => t.addEventListener('click', () => setTab(t.dataset.tab)));
  function setTab(name) {
    tabs.forEach(t => t.classList.toggle('is-active', t.dataset.tab === name));
    for (const k of Object.keys(outs)) {
      outs[k].classList.toggle('is-active', k === name);
    }
  }

  // ── Status ─────────────────────────────────────────────────
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
        `<code>:par</code> runs on real OS threads.`,
        null
      );
    } else {
      setStatus(
        `Powered by <code>libcx.wasm ${ver}</code> · single-threaded ASYNCIFY — ` +
        `<code>:par</code> produces correct output but doesn't accelerate. ` +
        `For real parallelism: <code>make guide-http</code> or run <code>cx</code> in your terminal.`,
        null
      );
    }
  }

  // ── Activate when wasm is ready ────────────────────────────
  const ready = (globalThis.cxlib && globalThis.cxlib.ready)
    ? globalThis.cxlib.ready
    : Promise.reject(new Error('cxlib failed to load — check console'));

  ready.then(() => {
    runBtn.disabled = false;
    setReadyStatus();
    // Pre-load first example if dropdown has options.
    if (pick.options.length > 0) {
      pick.selectedIndex = 0;
      loadExample(pick.value);
    }
  }, (err) => {
    setStatus(`Failed to load wasm runtime: ${err.message}`, 'error');
  });

  // ── Run ────────────────────────────────────────────────────
  runBtn.addEventListener('click', async () => {
    if (runBtn.disabled) return;
    const cxlib = globalThis.cxlib;
    const src = input.value;
    if (!src.trim()) {
      setStatus('Source is empty. Pick an example or type something to evaluate.', 'error');
      return;
    }
    // Clear stale output first so the user sees the reset. Hold for
    // 500ms (plain setTimeout, not rAF — rAF gets throttled in
    // background tabs) so the cleared state actually paints.
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
      // Re-project to JSON / XML once the final CX is in hand. These
      // calls are pure / synchronous on the wasm side.
      if (accumulated) {
        try { outs.json.textContent = cxlib.toJson(accumulated); }
        catch (e) { outs.json.textContent = `// JSON projection failed: ${e.message}`; }
        try { outs.xml.textContent  = cxlib.toXml(accumulated); }
        catch (e) { outs.xml.textContent = `// XML projection failed: ${e.message}`; }
      }
      setStatus(`Evaluated — ${accumulated.length} bytes.`, 'ok');
    } catch (err) {
      const msg = (err && err.message) ? err.message : String(err);
      setStatus(`Run failed: ${msg}`, 'error');
      // eslint-disable-next-line no-console
      console.error('[cx-playground] Run failed:', err);
    } finally {
      runBtn.classList.remove('is-running');
      runBtn.disabled = false;
    }
  });
})();
