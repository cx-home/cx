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
// Diagram shapes (emitted by the V-side renderer using
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
// Mermaid.js dependency: SAME-ORIGIN, never a CDN (#1015, the class
// #1007 closed for the playground). On first connectedCallback the
// component loads `./vendor/mermaid.min.js` resolved against its OWN
// script URL — so a consumer who copies cx-diagram.js and the vendored
// bundle out together, keeping their relative layout, gets a renderer
// that works offline with zero configuration.
//
// The injection point is `cxDiagramConfig.mermaidUrl`: set it before the
// first attach to point anywhere else. It must name a CLASSIC/UMD build
// (one that assigns `window.mermaid`) — that is what the vendored
// artifact is. There is no CDN fallback by design: a floating remote
// version is exactly what this component stopped doing. If neither a
// configured URL nor the component's own script URL can be resolved,
// rendering fails with an explicit message naming the property to set —
// never a silent reach for the network.
//
// This repo does not keep a second copy of the 3.3 MB bundle: the ONE
// vendored artifact lives at scripts/gen_guide/playground/vendor/ (pin of
// record in its README — mermaid 10.9.8, UMD, SHA-256 recorded), and
// `make stage-web-component` stages it beside this file under
// dist/web-component-preview/ for the demo page and the offline gate.
//
// Browser support: modern evergreen (custom elements v1, ES modules,
// fetch). No IE11 polyfill ships here.

(function (global) {
  'use strict';

  // Where did THIS file get loaded from? `document.currentScript` answers
  // for a classic <script>; it is null under `type="module"`, so fall back
  // to finding our own tag in the DOM. Both are lookups of one fact — the
  // component's own URL — not two ways of configuring anything.
  function selfScriptUrl() {
    var cur = global.document && global.document.currentScript;
    if (cur && cur.src) return cur.src;
    var tags = global.document
      ? global.document.querySelectorAll('script[src]')
      : [];
    for (var i = 0; i < tags.length; i++) {
      if (/cx-diagram\.js(\?|#|$)/.test(tags[i].src)) return tags[i].src;
    }
    return null;
  }

  // Resolved at parse time: `document.currentScript` is only valid while
  // this script is executing, and our own tag is in the DOM by now.
  var SELF_URL = selfScriptUrl();
  var DEFAULT_MERMAID_URL = SELF_URL
    ? new global.URL('./vendor/mermaid.min.js', SELF_URL).href
    : null;

  global.cxDiagramConfig = global.cxDiagramConfig || {
    mermaidUrl: DEFAULT_MERMAID_URL,
  };

  var mermaidPromise = null;

  function loadMermaid() {
    if (mermaidPromise) return mermaidPromise;
    mermaidPromise = new Promise(function (resolve, reject) {
      var url = global.cxDiagramConfig.mermaidUrl;
      if (!url) {
        reject(new Error(
          'no mermaid URL: could not resolve cx-diagram.js\'s own script URL, ' +
          'so the default ./vendor/mermaid.min.js could not be located. Set ' +
          'window.cxDiagramConfig.mermaidUrl to a same-origin UMD mermaid ' +
          'build before the first <cx-diagram> attaches.'));
        return;
      }
      // The vendored artifact is a UMD bundle: it assigns window.mermaid
      // and exports nothing to an ES module namespace, so `import()` on it
      // would "succeed" while producing no mermaid (#1007). Load it the way
      // it is built to be loaded, and read the global it defines.
      var tag = global.document.createElement('script');
      tag.src = url;
      tag.async = true;
      tag.onload = function () {
        var mermaid = global.mermaid;
        if (!mermaid || typeof mermaid.render !== 'function') {
          reject(new Error('loaded ' + url + ' but window.mermaid is not a ' +
            'mermaid build (cxDiagramConfig.mermaidUrl must name a ' +
            'classic/UMD bundle)'));
          return;
        }
        mermaid.initialize({ startOnLoad: false });
        resolve(mermaid);
      };
      tag.onerror = function () {
        reject(new Error('could not load mermaid from ' + url +
          ' (the renderer is same-origin by design — there is no CDN ' +
          'fallback; stage vendor/mermaid.min.js beside cx-diagram.js or ' +
          'set cxDiagramConfig.mermaidUrl)'));
      };
      global.document.head.appendChild(tag);
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
