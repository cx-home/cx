// CX Playground — canned-example sandbox.
//
// Today: a fixed corpus of CX and CXL examples, each with the
// canonical / JSON / XML output recorded ahead of time. The
// "Run" button surfaces those outputs and re-syntax-highlights
// every pane. Source-pane edits are preserved but not executed —
// libcx-wasm is not built yet.
//
// When libcx-wasm lands, the same UI drives a live evaluator; the
// shape of this file does not change — `refreshOutputs(key)` will
// route the textarea contents through the WASM module instead of
// the lookup table. See docs/concepts/wasm for the transition plan.
(function () {
  'use strict';

  const examples = {
    atom: {
      lang: 'cx',
      input: '[pizza size=large]',
      cx:   '[pizza size=large]',
      json: '{"pizza":{"@size":"large"}}',
      xml:  '<pizza size="large"/>'
    },
    attrs: {
      lang: 'cx',
      input: [
        '[server',
        '  host=api.example.com',
        '  port=:u16=8080',
        '  +tls',
        '  -debug',
        '  ratio=:decimal=3.14159]'
      ].join('\n'),
      cx: [
        '[server',
        '  host=api.example.com',
        '  port=:u16=8080',
        '  +tls',
        '  -debug',
        '  ratio=:decimal=3.14159]'
      ].join('\n'),
      json: '{"server":{"@host":"api.example.com","@port":8080,"@tls":true,"@debug":false,"@ratio":"3.14159"}}',
      xml:  '<server host="api.example.com" port="8080" tls="true" debug="false" ratio="3.14159"/>'
    },
    sigils: {
      lang: 'cx',
      input: [
        '[order #o123 :paid',
        '  [line item=@margherita count=2]',
        '  [line item=@pepperoni  count=1]]'
      ].join('\n'),
      cx: [
        '[order #o123 :paid',
        '  [line item=@margherita count=2]',
        '  [line item=@pepperoni count=1]]'
      ].join('\n'),
      json: '{"order":{"@id":"o123","@:":"paid","line":[{"@item":"@margherita","@count":2},{"@item":"@pepperoni","@count":1}]}}',
      xml: [
        '<order id="o123" type="paid">',
        '  <line item="@margherita" count="2"/>',
        '  <line item="@pepperoni" count="1"/>',
        '</order>'
      ].join('\n')
    },
    table: {
      lang: 'cx',
      input: [
        '[orders :table[item:string qty:u32 paid:bool when:date]',
        '  Margherita 2 true  2026-05-09',
        '  Hawaiian   1 false 2026-05-09]'
      ].join('\n'),
      cx: [
        '[orders :table[item:string qty:u32 paid:bool when:date]',
        '  Margherita 2 true 2026-05-09',
        '  Hawaiian 1 false 2026-05-09]'
      ].join('\n'),
      json: '{"orders":[{"item":"Margherita","qty":2,"paid":true,"when":"2026-05-09"},{"item":"Hawaiian","qty":1,"paid":false,"when":"2026-05-09"}]}',
      xml: [
        '<orders>',
        '  <row><item>Margherita</item><qty>2</qty><paid>true</paid><when>2026-05-09</when></row>',
        '  <row><item>Hawaiian</item><qty>1</qty><paid>false</paid><when>2026-05-09</when></row>',
        '</orders>'
      ].join('\n')
    },
    merge: {
      lang: 'cx',
      input: [
        '[defaults &shared timeout=30 retries=3]',
        '[server *shared name=api]',
        '[server *shared name=worker retries=5]'
      ].join('\n'),
      cx: [
        '[server timeout=30 retries=3 name=api]',
        '[server timeout=30 retries=3 name=worker retries=5]'
      ].join('\n'),
      json: '[{"server":{"@timeout":30,"@retries":3,"@name":"api"}},{"server":{"@timeout":30,"@retries":5,"@name":"worker"}}]',
      xml: [
        '<server timeout="30" retries="3" name="api"/>',
        '<server timeout="30" retries="5" name="worker"/>'
      ].join('\n')
    },
    mixed: {
      lang: 'cx',
      input: [
        "[article",
        "  [h1 New Haven Story]",
        "  [p Founded in [em 1987]. See the [a href=/menu menu].]",
        "  [p Still [strong hand-tossing] every pie.]]"
      ].join('\n'),
      cx: [
        "[article",
        "  [h1 New Haven Story]",
        "  [p Founded in [em 1987]. See the [a href=/menu menu].]",
        "  [p Still [strong hand-tossing] every pie.]]"
      ].join('\n'),
      json: '{"article":{"h1":"New Haven Story","p":["Founded in <em>1987</em>. See the <a href=\\"/menu\\">menu</a>.","Still <strong>hand-tossing</strong> every pie."]}}',
      xml: [
        '<article>',
        '  <h1>New Haven Story</h1>',
        '  <p>Founded in <em>1987</em>. See the <a href="/menu">menu</a>.</p>',
        '  <p>Still <strong>hand-tossing</strong> every pie.</p>',
        '</article>'
      ].join('\n')
    },
    'multi-doc': {
      lang: 'cx',
      input: [
        '[menu name=Lunch  [pizza name=Margherita]]',
        '---',
        '[menu name=Dinner [pizza name=Hawaiian]]'
      ].join('\n'),
      cx: [
        '[menu name=Lunch [pizza name=Margherita]]',
        '---',
        '[menu name=Dinner [pizza name=Hawaiian]]'
      ].join('\n'),
      json: '[{"menu":{"@name":"Lunch","pizza":{"@name":"Margherita"}}},{"menu":{"@name":"Dinner","pizza":{"@name":"Hawaiian"}}}]',
      xml: [
        '<menu name="Lunch"><pizza name="Margherita"/></menu>',
        '<menu name="Dinner"><pizza name="Hawaiian"/></menu>'
      ].join('\n')
    },
    'cxl-substitute': {
      lang: 'cxl',
      input: [
        "[page title='New Haven Pizza']",
        '[h1 [?= //page/@title]]'
      ].join('\n'),
      cx:   '[h1 New Haven Pizza]',
      json: '{"h1":"New Haven Pizza"}',
      xml:  '<h1>New Haven Pizza</h1>'
    },
    'cxl-for': {
      lang: 'cxl',
      input: [
        '[menu',
        '  [pizza name=Margherita price=12]',
        '  [pizza name=Hawaiian   price=14]',
        '  [pizza name=Diavola    price=13]]',
        '',
        '[?for p :in //pizza :return',
        '  [li [?= p/@name] - [?= p/@price] euros;]]'
      ].join('\n'),
      cx: [
        '[li Margherita - 12 euros;]',
        '[li Hawaiian - 14 euros;]',
        '[li Diavola - 13 euros;]'
      ].join('\n'),
      json: '[{"li":"Margherita - 12 euros;"},{"li":"Hawaiian - 14 euros;"},{"li":"Diavola - 13 euros;"}]',
      xml: [
        '<li>Margherita - 12 euros;</li>',
        '<li>Hawaiian - 14 euros;</li>',
        '<li>Diavola - 13 euros;</li>'
      ].join('\n')
    },
    'cxl-if': {
      lang: 'cxl',
      input: [
        '[pizza stock=2]',
        '',
        '[?if [',
        '  [@stock > 100, plenty],',
        '  [@stock > 10, some],',
        '  [@stock > 0,  last few],',
        '  [*, sold out]',
        ']]'
      ].join('\n'),
      cx:   'last few',
      json: '"last few"',
      xml:  'last few'
    },
    'cxl-let': {
      lang: 'cxl',
      input: [
        '[pizza price=12]',
        '',
        '[?let tax :be @price * 0.22 :return',
        '  Total: [?= @price + tax] euros]'
      ].join('\n'),
      cx:   'Total: 14.64 euros',
      json: '"Total: 14.64 euros"',
      xml:  'Total: 14.64 euros'
    },
    'cxl-filters': {
      lang: 'cxl',
      input: [
        "[pizza name='  margherita  ']",
        '',
        '[?= @name |> trim |> upper]'
      ].join('\n'),
      cx:   'MARGHERITA',
      json: '"MARGHERITA"',
      xml:  'MARGHERITA'
    },
    'cxl-templates': {
      lang: 'cxl',
      input: [
        '[?def line :params [p] :body',
        '  [li [?= p/@name] - [?= p/@price]]]',
        '',
        '[order [pizza name=Margherita price=12]',
        '       [pizza name=Hawaiian   price=14]]',
        '',
        '[ul [?for p :in //pizza :return [?line p]]]'
      ].join('\n'),
      cx: [
        '[ul',
        '  [li Margherita - 12]',
        '  [li Hawaiian - 14]]'
      ].join('\n'),
      json: '{"ul":{"li":["Margherita - 12","Hawaiian - 14"]}}',
      xml: [
        '<ul>',
        '  <li>Margherita - 12</li>',
        '  <li>Hawaiian - 14</li>',
        '</ul>'
      ].join('\n')
    },
    'cxl-paths': {
      lang: 'cxl',
      input: [
        '[shop',
        '  [pizza name=Margherita price=12]',
        '  [pizza name=Hawaiian   price=14]',
        '  [pizza name=Diavola    price=13]]',
        '',
        '[?for p :in //pizza[@price > 10] :return',
        '  [hit [?= p/@name]]]'
      ].join('\n'),
      cx: [
        '[hit Margherita]',
        '[hit Hawaiian]',
        '[hit Diavola]'
      ].join('\n'),
      json: '[{"hit":"Margherita"},{"hit":"Hawaiian"},{"hit":"Diavola"}]',
      xml: '<hit>Margherita</hit>\n<hit>Hawaiian</hit>\n<hit>Diavola</hit>'
    },
    'cxl-merge': {
      lang: 'cxl',
      input: [
        '[?cx use-module=cx]',
        '[order [pizza name=Margherita price=12]]',
        '[coupon [pizza price=10]]',
        '',
        '[?= [?cx:merge [//order, //coupon]]]'
      ].join('\n'),
      cx:   '[order [pizza name=Margherita price=10]]',
      json: '{"order":{"pizza":{"@name":"Margherita","@price":10}}}',
      xml:  '<order><pizza name="Margherita" price="10"/></order>'
    },
    'cxl-includes': {
      lang: 'cxl',
      input: [
        '# main.cxl',
        '[page',
        "  [?cx include=partials/header.cxl]",
        '  [section Body content goes here.]]'
      ].join('\n'),
      cx: [
        '[page',
        '  [header [logo Acme]]',
        '  [section Body content goes here.]]'
      ].join('\n'),
      json: '{"page":{"header":{"logo":"Acme"},"section":"Body content goes here."}}',
      xml: [
        '<page>',
        '  <header><logo>Acme</logo></header>',
        '  <section>Body content goes here.</section>',
        '</page>'
      ].join('\n')
    }
  };

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

  if (!pick || !input) return;

  // Status line surfaces transient feedback (Run/Reset/error) on top
  // of the static explanatory default. Set msg='' to restore default;
  // pass level='ok'|'error' for the palette flash. Errors stick until
  // the next setStatus call; ok/info auto-clear after 3s.
  let statusTimer = null;
  function setStatus(msg, level) {
    if (!status) return;
    if (statusTimer) { clearTimeout(statusTimer); statusTimer = null; }
    status.classList.remove('ok', 'error', 'info');
    if (level) status.classList.add(level);
    status.textContent = msg || status.dataset.default || '';
    if (level && level !== 'error') {
      statusTimer = setTimeout(() => {
        status.classList.remove(level);
        status.textContent = status.dataset.default || '';
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
    const ex = examples[key];
    if (!ex) return;
    input.value = ex.input;
    setInputLang(ex.lang);
    refreshOutputs(key);
    highlightInput();
    syncScroll();
  }

  // Refresh the three output tabs without touching the source pane.
  // Today the outputs come from the canned example corpus — a future
  // libcx-wasm build will route the current source through a live
  // evaluator instead. Either way the Source pane preserves user edits.
  function refreshOutputs(key) {
    const ex = examples[key];
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

  input.addEventListener('input', () => { highlightInput(); syncScroll(); });
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
  runBtn.addEventListener('click', () => {
    // Re-render the canned outputs for the selected example. User
    // edits in the Source pane are preserved; libcx-wasm is not built
    // yet, so Run is a re-render of the canned corpus rather than
    // actual evaluation of whatever is in the textarea.
    try {
      const key = pick.value;
      const ex = examples[key];
      if (!ex) {
        throw new Error(`no canned outputs registered for example '${key}'`);
      }
      const edited = input.value !== ex.input;
      refreshOutputs(key);
      flashRun(edited ? 'rendered (no eval)' : 'rendered', 'ran');
      setStatus(
        edited
          ? "Output panes re-rendered from the canned corpus. Your Source edits aren't being executed — libcx-wasm is not built yet."
          : 'Canned outputs re-rendered for the selected example.',
        'ok'
      );
    } catch (err) {
      flashRun('failed', 'failed');
      setStatus(`Run failed: ${err && err.message ? err.message : err}`, 'error');
      // Surface to the console for offline debugging.
      // eslint-disable-next-line no-console
      console.error('[cx-playground] Run failed:', err);
    }
  });
  tabs.forEach(t => t.addEventListener('click', () => setTab(t.dataset.tab)));

  // Initial load — surface boot errors visibly rather than silently
  // failing to populate the panes.
  try {
    load(pick.value || 'atom');
  } catch (err) {
    setStatus(`Playground failed to initialise: ${err && err.message ? err.message : err}`, 'error');
    // eslint-disable-next-line no-console
    console.error('[cx-playground] init failed:', err);
  }
})();
