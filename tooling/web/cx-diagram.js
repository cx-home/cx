// <cx-diagram> — reference web component (Phase 4.4).
//
// Renders a CX program as an inline diagram in the browser.
//
// Inputs (in priority order):
//   - `mermaid` attribute / property — Mermaid text to render directly.
//   - `src` attribute — URL of a Mermaid text file (fetched lazy).
//   - Inner text content (default slot) — Mermaid text.
//
// The CX → Mermaid conversion is the server-side responsibility (run
// `cx diagram program.cx --format=mermaid` to produce the input).
// v0.8.0 diagram shapes (emitted by the V-side renderer using
// standard Mermaid flowchart primitives — no JS-layer styling hooks
// required; the component stays a generic Mermaid host):
//
//   - `[?if cond [then T] [else E]]` → diamond (rhombus)
//                                    with two-way arms labeled
//                                    `true` / `false`
//   - `[?match expr [case … R] [else E]]` → dispatcher round-rect
//                                    (stadium) with one outgoing
//                                    edge per arm, labeled with arm
//                                    pattern truncated to 30 chars
//                                    (code.md §8.2)
//   - `[?for [in $x seq] [yield body]]` → loop-box (header + body +
//                                    exit) with `binds $x` edge
//                                    label on header→body and a
//                                    body→header back-edge
//   - `[?modify focus [action …]]` → single update-block (rectangle)
//                                    labeled with focus + action
//                                    vocabulary (code.md §8.10)
//   - `[?def name [returns T] body]` → sub-graph cluster grouping
//                                    every basic-block emitted by
//                                    the def's body (code.md §12.2)
//   - CXPath query step → rectangular path-node
//                                    (code.md §5.5)
//
// Future work: in-browser WASM build of `cx_code_diagram` so the
// component can take raw CX program text directly (capability
// bit 31).
//
// Round-trip metadata: if the Mermaid text begins with the CX
// `%%cx:<base64>%%` marker, the component preserves it on output via
// the `cxSource` property — JS consumers can call element.cxSource
// to recover the original program. This mirrors the reverse_parse_
// diagram() Python/Go/V binding contract.
//
// Mermaid.js dependency: loaded from a CDN (jsdelivr) on first
// connectedCallback. Override `cxDiagramConfig.mermaidUrl` before the
// first attach to use a local copy.
//
// Browser support: modern evergreen (custom elements v1, ES modules,
// fetch). No IE11 polyfill ships here.

(function (global) {
  'use strict';

  var DEFAULT_MERMAID_URL =
    'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';

  global.cxDiagramConfig = global.cxDiagramConfig || {
    mermaidUrl: DEFAULT_MERMAID_URL,
  };

  var mermaidPromise = null;

  function loadMermaid() {
    if (mermaidPromise) return mermaidPromise;
    mermaidPromise = import(global.cxDiagramConfig.mermaidUrl).then(function (mod) {
      var mermaid = mod.default || mod;
      mermaid.initialize({ startOnLoad: false });
      return mermaid;
    });
    return mermaidPromise;
  }

  function extractCxSource(mermaidText) {
    var open = '%%cx:';
    var close = '%%';
    var a = mermaidText.indexOf(open);
    if (a < 0) return null;
    var rest = mermaidText.substring(a + open.length);
    var b = rest.indexOf(close);
    if (b < 0) return null;
    var encoded = rest.substring(0, b);
    try {
      // atob handles latin-1; for UTF-8 program text decode via
      // TextDecoder over the resulting byte string.
      var bin = global.atob(encoded);
      var bytes = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
      return new TextDecoder('utf-8').decode(bytes);
    } catch (e) {
      return null;
    }
  }

  var idCounter = 0;

  class CxDiagramElement extends global.HTMLElement {
    constructor() {
      super();
      this._cxSource = null;
      this._lastText = null;
    }

    static get observedAttributes() {
      return ['mermaid', 'src'];
    }

    attributeChangedCallback() {
      this.render();
    }

    connectedCallback() {
      this.render();
    }

    get cxSource() {
      return this._cxSource;
    }

    get mermaidText() {
      return this._lastText;
    }

    async render() {
      var text = this.getAttribute('mermaid');
      if (text == null) {
        var src = this.getAttribute('src');
        if (src) {
          try {
            var res = await fetch(src);
            text = await res.text();
          } catch (e) {
            this.innerHTML = '<pre style="color:#c00">cx-diagram: fetch ' + src + ' failed: ' + e + '</pre>';
            return;
          }
        }
      }
      if (text == null || text === '') {
        text = this.textContent || '';
      }
      text = text.trim();
      if (!text) {
        this.innerHTML = '';
        return;
      }
      this._lastText = text;
      this._cxSource = extractCxSource(text);
      try {
        var mermaid = await loadMermaid();
        idCounter++;
        var renderId = 'cx-diagram-' + idCounter;
        var rendered = await mermaid.render(renderId, text);
        this.innerHTML = rendered.svg;
        if (rendered.bindFunctions) {
          rendered.bindFunctions(this);
        }
      } catch (e) {
        this.innerHTML = '<pre style="color:#c00">cx-diagram: ' + (e && e.message ? e.message : e) + '</pre>';
      }
    }
  }

  if (!global.customElements.get('cx-diagram')) {
    global.customElements.define('cx-diagram', CxDiagramElement);
  }
  global.CxDiagramElement = CxDiagramElement;
})(typeof window !== 'undefined' ? window : globalThis);
