// cxlib.js — slim JS wrapper around libcx.wasm (v0.8.0, Phase 7.1 + 7.2).
// Surface = the 16-method Layer-1 contract from `spec/bindings.md §2.1`
// (eval / selectAll / modify / findAll / parse / bytes / hash / equals
// + the converter helpers) plus the playground-only `evalCode` /
// `evalCodeStreaming` / `diagram` / `tree` family. Loads after libcx.js
// (emscripten loader); attaches to globalThis as `cxlib`.
//
// Layer-1 Doc shape: a Doc handle is just its canonical CX bytes
// (a JS string). `parse(input)` normalises input to canonical bytes;
// `bytes(doc)` is the identity; `equals(a, b)` compares canonical
// forms; `eval(doc, code)` evaluates a CX program against the doc;
// `selectAll(doc, cxpath)` / `findAll(doc, name)` / `modify(doc,
// focus, action)` route through `_cx_code_eval_with_len`.
//
//   cxlib.ready          Promise<void>
//
//   ── Layer-1 (spec/bindings.md §2.1) ─────────────────────────
//   cxlib.parse(input)                                                    → string  (canonical CX bytes)
//   cxlib.bytes(doc)                                                      → string  (identity)
//   cxlib.hash(input)                                                     → string  (SHA-256 hex)
//   cxlib.equals(a, b)                                                    → bool
//   cxlib.eval(doc, code, target='cx')                                    → string
//   cxlib.selectAll(doc, cxpath, target='cx')                             → string
//   cxlib.findAll(doc, name)                                              → string
//   cxlib.modify(doc, focusCxpath, action)                                → string  (new Doc)
//
//   ── Playground extras ───────────────────────────────────────
//   cxlib.evalCode(programSource, target='cx', input='')                  → string
//   cxlib.evalCodeStreaming(programSource, target, sink, input='')        → void
// cxlib.diagram(programSource, format='mermaid') → string (ERD/CFG auto-detect)
// cxlib.tree(programSource) → object (parsed JSON contract)
//   cxlib.programAst(programSource)                                       → string  (transitional; Phase 7.7 retires in favour of tree)
//   cxlib.toCx / toCxCompact / toJson / toXml / toYaml / toToml    → string
//   cxlib.canonical(input)                                                → string
//   cxlib.features() / cxlib.version()                                    → string
//   cxlib.reset() / cxlib.setArenaSize(bytes)                             → void
//
// `sink(chunk)` receives a string per write_cb call; return non-zero
// (or throw) to abort the streaming evaluation.
//
// libcx errors (cx-err:CXER… or in-band CXERnnnn:msg) surface as JS
// Error objects with .cxCode set to the bare CXER code.

(function (root) {
  // dual-loader. Detect the runtime mode at script-load
  // time + dynamically inject the right libcx-*.js artifact:
  //   libcx-pthreads.js — when crossOriginIsolated + SAB are available
  //                       (make guide-http with COOP+COEP headers)
  //   libcx-async.js    — otherwise (file://, GitHub Pages, generic HTTP)
  // The artifact defines createCxModule (emscripten factory) which is
  // then called below to instantiate the wasm module.
  //
  // Compatibility: if root.createCxModule is already defined (e.g. a
  // host page that explicitly loaded a specific libcx-*.js via a
  // <script> tag before cxlib.js), use that directly + skip injection.
  const detectedMode = (typeof root.crossOriginIsolated !== 'undefined'
                        && root.crossOriginIsolated === true
                        && typeof root.SharedArrayBuffer === 'function')
                       ? 'pthreads' : 'async';

  function injectLoader() {
    return new Promise((resolve, reject) => {
      if (typeof root.createCxModule === 'function') { resolve(); return; }
      if (typeof document === 'undefined') {
        reject(new Error('cxlib: no document — can\'t inject libcx loader'));
        return;
      }
      const me = document.currentScript;
      const here = me ? me.src : new URL('cxlib.js', root.location.href).href;
      const artifact = detectedMode === 'pthreads' ? 'libcx-pthreads.js' : 'libcx-async.js';
      const url = new URL(artifact, here).href;
      const s = document.createElement('script');
      s.src = url;
      s.async = false;
      s.onload = () => resolve();
      s.onerror = () => reject(new Error('cxlib: failed to load ' + url));
      document.head.appendChild(s);
    });
  }

  let M = null;
  let asyncifyAvailable = false;
  const ready = injectLoader().then(() => {
    const loader = root.createCxModule;
    if (typeof loader !== 'function') {
      throw new Error('cxlib: libcx loader did not define createCxModule');
    }
    return loader();
  }).then(mod => {
    M = mod;
    if (M.__vinit) M.__vinit(0, 0);
    // detect ASYNCIFY-instrumented builds. emscripten
    // exports `_asyncify_start_unwind` (or `Asyncify` runtime hooks)
    // when compiled with `-sASYNCIFY=1`. Under an ASYNCIFY build the
    // main browser thread can safely block on usleep — the call yields
    // through JS, setTimeout drives the deadline, and wasm resumes
    // without freezing the UI. So flip the wall-sleep opt-in on main
    // thread; bare [?sleep DUR] no longer raises CXER0270 here. Non-
    // ASYNCIFY builds keep the default (false), so the worker path or
    // the documented CXER0270 fallback continues to apply.
    // Probe the V-side build flag (cx_wasm_is_asyncify returns 1 when
    // emcc was invoked with ASYNCIFY=1 and V with `-d asyncify_build`).
    // emscripten's internal asyncify_* symbols aren't reliably surfaced
    // on Module by name, so we route detection through our own export.
    try {
      asyncifyAvailable = typeof M._cx_wasm_is_asyncify === 'function'
        && M._cx_wasm_is_asyncify() === 1;
    } catch (_) {
      asyncifyAvailable = false;
    }
    if (asyncifyAvailable && typeof M._cx_wasm_set_wall_sleep === 'function') {
      M._cx_wasm_set_wall_sleep(1);
    }
  });

  function pushBytes(s) {
    const n = M.lengthBytesUTF8(s);
    const p = M._malloc(n + 1);
    M.stringToUTF8(s, p, n + 1);
    return { p, n };
  }

  function throwCx(msg) {
    const e = new Error(msg);
    const m = /^(?:cx-err:)?(CXER\d+)/.exec(msg);
    if (m) e.cxCode = m[1];
    throw e;
  }

  function pullErrOrThrow(errPtrPtr, resultPtr) {
    const errPtr = M.getValue(errPtrPtr, 'i32');
    M._free(errPtrPtr);
    if (resultPtr) {
      const out = M.UTF8ToString(resultPtr);
      M._cx_free(resultPtr);
      return out;
    }
    let msg = 'cxlib: unknown error';
    if (errPtr) { msg = M.UTF8ToString(errPtr); M._cx_free(errPtr); }
    throwCx(msg);
  }

  function callStringIn(fn, ...inputs) {
    if (!M) throw new Error('cxlib: not ready — await cxlib.ready first');
    const ptrs = inputs.map(s => pushBytes(s).p);
    const errPtrPtr = M._malloc(4); M.setValue(errPtrPtr, 0, 'i32');
    try { return pullErrOrThrow(errPtrPtr, M[fn].apply(null, ptrs.concat([errPtrPtr]))); }
    finally { ptrs.forEach(p => M._free(p)); }
  }

  function evalCode(programSource, target, input) {
    if (!M) throw new Error('cxlib: not ready — await cxlib.ready first');
    const prog = pushBytes(programSource);
    const inp  = pushBytes(input || '');
    const tgt  = pushBytes(target || 'cx');
    const errPtrPtr = M._malloc(4); M.setValue(errPtrPtr, 0, 'i32');
    try {
      const res = M._cx_code_eval_with_len(inp.p, inp.n, prog.p, prog.n, tgt.p, errPtrPtr);
      return pullErrOrThrow(errPtrPtr, res);
    } finally { M._free(prog.p); M._free(inp.p); M._free(tgt.p); }
  }

  // evalCodeAsyncInternal — Promise-aware variant for ASYNCIFY builds.
  // Direct `M._cx_code_eval_with_len(...)` returns 0 even when the
  // wasm suspends (Asyncify's resume machinery isn't wired into raw
  // export calls without ccall's {async: true} option). ccall handles
  // both the Asyncify suspend/resume bookkeeping and the int→string
  // marshalling. Buffers are owned by ccall in this path.
  async function evalCodeAsyncInternal(programSource, target, input) {
    if (!M) throw new Error('cxlib: not ready — await cxlib.ready first');
    const errPtrPtr = M._malloc(4); M.setValue(errPtrPtr, 0, 'i32');
    try {
      const resStr = await M.ccall(
        'cx_code_eval_with_len',
        'string',
        ['number', 'number', 'string', 'number', 'string', 'number'],
        [0, 0, programSource, M.lengthBytesUTF8(programSource),
         target || 'cx', errPtrPtr],
        { async: true }
      );
      if (resStr) return resStr;
      // Eval returned NULL — error pointer carries the message.
      const errPtr = M.getValue(errPtrPtr, 'i32');
      if (errPtr) {
        const msg = M.UTF8ToString(errPtr);
        M._cx_free(errPtr);
        throwCx(msg);
      }
      throwCx('cxlib: unknown error');
    } finally { M._free(errPtrPtr); }
  }

  // Streaming routes through the cx_code_eval_streaming C ABI with a
  // real per-chunk callback. The V side (vcx/code/cabi.v) stashes the
  // C function pointer in module-globals + uses a non-closure sink to
  // avoid V's runtime-generated mprotect trampolines (wasm32 can't
  // honour PROT_EXEC). emscripten's addFunction installs `sink` as a
  // wasm function table entry; the wasm code calls it via the standard
  // C ABI signature `(const char* bytes, size_t n, void* user) → int`.
  // Each [?for] :yield emit becomes one sink call; final whole-program
  // flush is one call as well (CXStreamCtx.flush).
  function evalCodeStreaming(programSource, target, sink, input) {
    if (typeof sink !== 'function') throw new Error('cxlib: sink must be a function');
    if (!M) throw new Error('cxlib: not ready — await cxlib.ready first');
    if (typeof M.addFunction !== 'function') {
      // RESERVE_FUNCTION_TABLE / ALLOW_TABLE_GROWTH not enabled. Fall
      // back to single-flush.
      const out = evalCode(programSource, target, input);
      sink(out);
      return;
    }
    // Signature 'iiii' = (i32 bytes, i32 n, i32 user) → i32 (return 0
    // on success, non-zero to abort the stream per spec/abi.md §2.16.1).
    const cbFn = (bytesPtr, n, _user) => {
      try {
        const chunk = M.UTF8ToString(bytesPtr, n);
        sink(chunk);
        return 0;
      } catch (_) {
        return 1;
      }
    };
    const cbPtr = M.addFunction(cbFn, 'iiii');
    const prog = pushBytes(programSource);
    const inp  = pushBytes(input || '');
    const tgt  = pushBytes(target || 'cx');
    const errPtrPtr = M._malloc(4); M.setValue(errPtrPtr, 0, 'i32');
    try {
      M._cx_code_eval_streaming(inp.p, inp.n, prog.p, prog.n, tgt.p,
                                cbPtr, 0, errPtrPtr);
      const errPtr = M.getValue(errPtrPtr, 'i32');
      if (errPtr) {
        const msg = M.UTF8ToString(errPtr); M._cx_free(errPtr);
        throwCx(msg);
      }
    } finally {
      M._free(errPtrPtr);
      M._free(prog.p); M._free(inp.p); M._free(tgt.p);
      M.removeFunction(cbPtr);
    }
  }

  // diagram(src, format) — `format` may carry a detail-level suffix
  // (e.g. `'mermaid:compact'`, `'mermaid:full'`, `'mermaid:min'`).
  // Bare `'mermaid'` defaults to `compact`.
  //
  // When the wasm module exports `cx_code_diagram_with_level`
  // D12.6 new ABI, gate 37.13), this function routes through it — the
  // §D4 / §D13 emitter honors the ternary D1 dispatch (ERD / CFG / SEQ)
  // and the level taxonomy. Falls back to the legacy `cx_code_diagram`
  // (which routes through `render_diagram`) when the new symbol isn't
  // exported (older binding builds).
  function diagram(programSource, format) {
    if (!M) throw new Error('cxlib: not ready — await cxlib.ready first');
    const fmtStr = format || 'mermaid';
    // Parse level suffix from format: 'mermaid:min' → 0, 'mermaid:compact' → 1,
    // 'mermaid:full' → 2, bare 'mermaid' → 1 (compact, the 
    // default).
    let level = 1;
    const colonIdx = fmtStr.indexOf(':');
    if (colonIdx >= 0) {
      const tail = fmtStr.slice(colonIdx + 1).toLowerCase();
      if (tail === 'min') level = 0;
      else if (tail === 'full') level = 2;
      else level = 1;
    }
    const src = pushBytes(programSource);
    try {
      // Prefer the canonical numeric export (the §D4/§D13 emitter — richer
      // output, e.g. classDef styling). If it ever degrades to a HEADER-ONLY
      // diagram (its internal parse failing — a bug seen historically in the
      // wasm build, since fixed engine-side with a raw-source parse fallback),
      // fall through to the legacy string-format `_cx_code_diagram` export,
      // which routes through `render_diagram` and is robust. Both emit valid
      // Mermaid; `fmtStr` ('mermaid:full' …) carries the same level as `level`.
      if (typeof M._cx_code_diagram_with_level === 'function') {
        const outPtr = M._cx_code_diagram_with_level(src.p, src.n, level);
        const out = M.UTF8ToString(outPtr); M._cx_free(outPtr);
        if (/^CXER\d+:/.test(out)) throwCx(out);
        // A real diagram has body lines past the header keyword; a header-only
        // result (no newline) means the canonical path degraded — fall back.
        if (out && out.trim().includes('\n')) return out;
      }
      if (typeof M._cx_code_diagram === 'function') {
        const fmt = pushBytes(fmtStr);
        try {
          const outPtr = M._cx_code_diagram(src.p, src.n, fmt.p, fmt.n);
          const out = M.UTF8ToString(outPtr); M._cx_free(outPtr);
          if (/^CXER\d+:/.test(out)) throwCx(out);
          return out;
        } finally { M._free(fmt.p); }
      }
      throw new Error('cxlib: no diagram export available');
    } finally { M._free(src.p); }
  }

  // programAst — transitional AST JSON string; superseded by tree() at
  // v0.8.0; retained until the playground rewire (Phase 7.7) finishes.
  function programAst(programSource) {
    if (!M) throw new Error('cxlib: not ready — await cxlib.ready first');
    const src = pushBytes(programSource);
    try {
      const outPtr = M._cx_code_ast_json(src.p, src.n);
      const out = M.UTF8ToString(outPtr); M._cx_free(outPtr);
      if (/^CXER\d+:/.test(out)) throwCx(out);
      return out;
    } finally { M._free(src.p); }
  }

  // tree — parsed tree projection JSON; returns the
  // parsed object (not a string) so cross-pane consumers (Tree view +
  // selection bridge) stay single-purpose.
  function tree(programSource) {
    if (!M) throw new Error('cxlib: not ready — await cxlib.ready first');
    const src = pushBytes(programSource);
    const outLenPtr = M._malloc(4); M.setValue(outLenPtr, 0, 'i32');
    try {
      const outPtr = M._cx_code_tree(src.p, src.n, outLenPtr);
      const out = M.UTF8ToString(outPtr); M._cx_free(outPtr);
      if (/^CXER\d+:/.test(out)) throwCx(out);
      return JSON.parse(out);
    } finally { M._free(src.p); M._free(outLenPtr); }
  }

  // ── Layer-1 surface (spec/bindings.md §2.1) ──────────────────
  // Doc handle = canonical CX bytes (string). parse() normalises;
  // bytes() is identity; equals() compares canonical forms.
  function parse(input)   { return callStringIn('_cx_to_cx', input); }
  function bytes(doc)     { return doc; }
  function equals(a, b)   { return parse(a) === parse(b); }
  function evalDoc(doc, code, target) {
    return evalCode(code, target || 'cx', doc || '');
  }
  function selectAll(doc, cxpath, target) {
    return evalCode(cxpath, target || 'cx', doc || '');
  }
  function findAll(doc, name) {
    return selectAll(doc, '//' + name);
  }
  function modify(doc, focusCxpath, action) {
    const program = '[?modify $doc ' + focusCxpath + ' ' + action + ']';
    return evalCode(program, 'cx', doc || '');
  }

  const cxlib = {
    ready,
    // Layer-1
    parse, bytes, equals,
    eval: evalDoc,
    selectAll, findAll, modify,
    // Playground extras
    evalCode, evalCodeStreaming, diagram, tree, programAst,
    toCx(input)        { return callStringIn('_cx_to_cx', input); },
    toCxCompact(input) { return callStringIn('_cx_to_cx_compact', input); },
    toJson(input)      { return callStringIn('_cx_to_json', input); },
    toXml(input)       { return callStringIn('_cx_to_xml', input); },
    toYaml(input)      { return callStringIn('_cx_to_yaml', input); },
    toToml(input)      { return callStringIn('_cx_to_toml', input); },
    canonical(input)   { return callStringIn('_cx_canonical', input); },
    hash(input)        { return callStringIn('_cx_hash', input); },
    features()         { return M.UTF8ToString(M._cx_features()); },
    version()          { return M.UTF8ToString(M._cx_version()); },
    reset()            { M._cx_wasm_reset(); },
    setArenaSize(b)    { M._cx_wasm_set_arena_size(b >>> 0); },
    // opt into blocking wall-clock [?sleep DUR] in this
    // wasm host. Default is OFF (bare [?sleep DUR] raises CXER0270);
    // Web-Worker hosts that can safely block their own thread call
    // wasmSetWallSleep(true) at init. Main-thread playgrounds should
    // leave this OFF and rely on [?sleep DUR :mock] for deterministic
    // demos. See playground.worker.js for the canonical opt-in site.
    wasmSetWallSleep(enabled) { M._cx_wasm_set_wall_sleep(enabled ? 1 : 0); },
    // Reports whether the loaded wasm was built with -sASYNCIFY=1. When
    // true, bare wall-clock [?sleep DUR] on the main thread is safe —
    // wasm suspends, JS event loop continues, UI stays responsive. When
    // false, the playground uses a Web Worker (HTTP) or falls back to
    // CXER0270 (file://).
    isAsyncify() { return asyncifyAvailable; },
    // reports which artifact loaded:
    //   'pthreads' — libcx-pthreads.{js,wasm} loaded; SAB enabled;
    //                :par runs on real OS threads.
    //   'async'    — libcx-async.js loaded; ASYNCIFY-only;
    //                :par produces correct output but doesn't
    //                accelerate (single-threaded eval).
    // Set by the dual-loader bootstrap above based on host environment
    // detection (crossOriginIsolated + SAB). The playground UI banner
    // consumes this to communicate the parallelism story.
    runtimeMode: detectedMode,
  };

  // ── Worker-host async eval ────────────────────────────
  //
  // Lazy-creates a dedicated Web Worker that loads its own libcx-wasm
  // instance + opts into wall-clock sleep, and routes evalCode through
  // it via postMessage. The worker's blocking sleep doesn't freeze the
  // main thread, so playground demos can show observable wall-clock
  // parallelism with bare [?sleep DUR] — alongside the existing main-
  // thread cxlib.evalCode which keeps CXER0270 semantics. Pass-through
  // helper used by playground.js when it detects a program contains
  // bare wall-clock [?sleep] (or unconditionally for futures + worker
  // body demos).
  let _worker = null;
  let _pending = new Map();  // id → { resolve, reject }
  let _nextId = 1;
  let _workerReady = null;   // Promise<void>

  let _workerUnavailable = false;

  function ensureWorker() {
    if (_workerUnavailable) return Promise.reject(new Error('worker unavailable'));
    if (_worker) return _workerReady;
    // Resolve the worker script URL relative to the current page.
    // Both deployment layouts (dist/playground-preview/ and
    // docs/guide/) put the worker under `playground/` next to
    // playground.html. Callers can override via
    // cxlib.workerUrl = '/path/to/worker' before the first async eval.
    const url = cxlib.workerUrl
      ? cxlib.workerUrl
      : new URL('playground/playground.worker.js',
                typeof location !== 'undefined' ? location.href : 'http://localhost/');
    try {
      _worker = new Worker(url);
    } catch (err) {
      // Browsers refuse `new Worker(...)` under `file://` origin
      // (Chrome / Edge: "cannot be accessed from origin 'null'";
      // Safari raises SecurityError). Fall back to main-thread eval
      // — :mock examples work fine there, and bare wall-clock sleep
      // raises CXER0270 with a clear pointer toward `:mock`. The
      // page-level UI shouldn't crash just because the user opened
      // playground.html by double-click instead of via http server.
      _workerUnavailable = true;
      return Promise.reject(new Error('worker construction failed: ' + (err && err.message || String(err))));
    }
    _worker.onmessage = (ev) => {
      const msg = ev.data || {};
      if (msg.kind === 'ready' || msg.kind === 'init-error') return;
      const pending = _pending.get(msg.id);
      if (!pending) return;
      _pending.delete(msg.id);
      if (msg.ok) pending.resolve(msg.result);
      else pending.reject(new Error(msg.error || 'worker eval error'));
    };
    _workerReady = new Promise((resolve, reject) => {
      const initHandler = (ev) => {
        const msg = ev.data || {};
        if (msg.kind === 'ready') {
          _worker.removeEventListener('message', initHandler);
          resolve();
        } else if (msg.kind === 'init-error') {
          _worker.removeEventListener('message', initHandler);
          reject(new Error(msg.error || 'worker init error'));
        }
      };
      _worker.addEventListener('message', initHandler);
    });
    return _workerReady;
  }

  // evalCodeAsync — wall-clock-capable eval. Three execution paths in
  // priority order:
  //
  //   1. ASYNCIFY build (preferred when available): sync main-thread
  //      evalCode runs through the Asyncify-instrumented wasm, which
  //      yields to the JS event loop on usleep/sleep boundaries. Works
  //      everywhere — http://, file://, Web Worker, Node.js — without
  //      requiring a separate Worker. Slightly slower per call than
  //      raw wasm but immediate UI responsiveness across all hosts.
  //
  //   2. Web Worker (HTTP non-ASYNCIFY): a dedicated Worker hosts its
  //      own libcx instance with cx_wasm_set_wall_sleep(true). Blocking
  //      sleep stays on the worker thread; main thread free.
  //
  //   3. Sync fallback: bare wall-clock [?sleep] raises CXER0270 with
  //      the documented pointer toward `:mock`. :mock evals work
  //      transparently.
  cxlib.evalCodeAsync = async function (src, target, input) {
    // Path 1: ASYNCIFY-instrumented build. Main-thread eval is safe;
    // the wasm yields cooperatively on sleep boundaries. Route through
    // the Promise-aware internal eval so async-returning exports get
    // awaited (otherwise pullErrOrThrow sees a Promise as if it were
    // a NULL result and throws "unknown error").
    if (asyncifyAvailable) {
      return evalCodeAsyncInternal(src, target || 'cx', input || '');
    }
    // Path 2: Web Worker (when available; file:// origin will fail).
    if (typeof Worker === 'undefined') {
      return cxlib.evalCode(src, target || 'cx', input || '');
    }
    try {
      await ensureWorker();
    } catch (_) {
      // Path 3: Worker construction denied (file:// origin without
      // ASYNCIFY). Sync main-thread fallback.
      return cxlib.evalCode(src, target || 'cx', input || '');
    }
    const id = _nextId++;
    return new Promise((resolve, reject) => {
      _pending.set(id, { resolve, reject });
      _worker.postMessage({
        id, action: 'evalCode',
        src, target: target || 'cx', input: input || '',
      });
    });
  };

  // evalCodeStreamingAsync — Asyncify-aware streaming. Same shape as
  // evalCodeStreaming but ccall {async:true} so the streaming wasm
  // call can yield through [?sleep] without freezing the main thread.
  // Each sink(chunk) callback fires synchronously from the wasm side
  // between yields; the surrounding Promise resolves when the wasm
  // function returns. Falls back to one-shot evalCodeAsync when the
  // build doesn't support addFunction.
  cxlib.evalCodeStreamingAsync = async function (programSource, target, sink, input) {
    if (typeof sink !== 'function') throw new Error('cxlib: sink must be a function');
    if (!M) throw new Error('cxlib: not ready — await cxlib.ready first');
    if (typeof M.addFunction !== 'function' || !asyncifyAvailable) {
      // Without addFunction or without Asyncify, fall back to the
      // one-shot async path so :mock / non-sleeping evals still work.
      const out = await cxlib.evalCodeAsync(programSource, target, input);
      sink(out);
      return;
    }
    const cbFn = (bytesPtr, n, _user) => {
      try { sink(M.UTF8ToString(bytesPtr, n)); return 0; }
      catch (_) { return 1; }
    };
    const cbPtr = M.addFunction(cbFn, 'iiii');
    const errPtrPtr = M._malloc(4); M.setValue(errPtrPtr, 0, 'i32');
    try {
      // Pass user=1 to signal CX_STREAM_UNBUFFERED — flush after every
      // [?for] :yield emit instead of buffering 32 KiB. Playground
      // demos want immediate per-yield visibility; the default
      // throughput-tuned buffer threshold hides individual chunks.
      await M.ccall(
        'cx_code_eval_streaming',
        null,
        ['number', 'number', 'string', 'number', 'string', 'number', 'number', 'number'],
        [0, 0, programSource, M.lengthBytesUTF8(programSource),
         target || 'cx', cbPtr, 1, errPtrPtr],
        { async: true }
      );
      const errPtr = M.getValue(errPtrPtr, 'i32');
      if (errPtr) {
        const msg = M.UTF8ToString(errPtr); M._cx_free(errPtr);
        throwCx(msg);
      }
    } finally {
      M._free(errPtrPtr);
      M.removeFunction(cbPtr);
    }
  };

  root.cxlib = cxlib;
  if (typeof module !== 'undefined' && module.exports) module.exports = cxlib;
})(typeof globalThis !== 'undefined' ? globalThis : this);
