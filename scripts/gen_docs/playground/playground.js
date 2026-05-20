// CX Playground — canned-example sandbox. v0.7.x will wire a libcx-WASM
// build through this surface; the current build ships pre-recorded
// outputs per example.
(function () {
  'use strict';

  const examples = {
    atom: {
      input: '[pizza size=large]',
      cx:   '[pizza size=large]',
      json: '{"pizza":{"@size":"large"}}',
      xml:  '<pizza size="large"/>'
    },
    attrs: {
      input: '[server\n  host=api.example.com\n  port=:u16=8080\n  +tls\n  -debug\n  ratio=:decimal=3.14159]',
      cx:    '[server host=api.example.com port=:u16=8080 +tls -debug ratio=:decimal=3.14159]',
      json:  '{"server":{"@host":"api.example.com","@port":8080,"@tls":true,"@debug":false,"@ratio":"3.14159"}}',
      xml:   '<server host="api.example.com" port="8080" tls="true" debug="false" ratio="3.14159"/>'
    },
    sigils: {
      input: '[order #o123 :paid\n  [line item=@margherita count=2]\n  [line item=@pepperoni count=1]]',
      cx:    '[order #o123 :paid [line item=@margherita count=2][line item=@pepperoni count=1]]',
      json:  '{"order":{"@id":"o123","@:":"paid","line":[{"@item":"@margherita","@count":2},{"@item":"@pepperoni","@count":1}]}}',
      xml:   '<order id="o123" type="paid"><line item="@margherita" count="2"/><line item="@pepperoni" count="1"/></order>'
    },
    table: {
      input: '[orders :table[item:string qty:u32 paid:bool when:date]\n  Margherita 2 true  2026-05-09\n  Hawaiian   1 false 2026-05-09\n]',
      cx:    '[orders :table[item:string qty:u32 paid:bool when:date]\n  Margherita 2 true 2026-05-09\n  Hawaiian 1 false 2026-05-09]',
      json:  '{"orders":[{"item":"Margherita","qty":2,"paid":true,"when":"2026-05-09"},{"item":"Hawaiian","qty":1,"paid":false,"when":"2026-05-09"}]}',
      xml:   '<orders>\n  <row><item>Margherita</item><qty>2</qty><paid>true</paid><when>2026-05-09</when></row>\n  <row><item>Hawaiian</item><qty>1</qty><paid>false</paid><when>2026-05-09</when></row>\n</orders>'
    },
    merge: {
      input: '[defaults &shared timeout=30 retries=3]\n[server *shared name=api]\n[server *shared name=worker]',
      cx:    '[server timeout=30 retries=3 name=api]\n[server timeout=30 retries=3 name=worker]',
      json:  '[{"server":{"@timeout":30,"@retries":3,"@name":"api"}},{"server":{"@timeout":30,"@retries":3,"@name":"worker"}}]',
      xml:   '<server timeout="30" retries="3" name="api"/>\n<server timeout="30" retries="3" name="worker"/>'
    },
    'cxl-substitute': {
      input: '[page title="Pepes Pizza"]\n[?=//page/@title]',
      cx:    'Pepes Pizza',
      json:  '"Pepes Pizza"',
      xml:   'Pepes Pizza'
    },
    'cxl-for': {
      input: '[menu\n  [pizza name=Margherita price=12]\n  [pizza name=Hawaiian   price=14]\n  [pizza name=Diavola    price=13]]\n[?for p :in //pizza :return [li [?=p/@name] - [?=p/@price] euros;]]',
      cx:    '[li Margherita - 12 euros;][li Hawaiian - 14 euros;][li Diavola - 13 euros;]',
      json:  '[{"li":"Margherita - 12 euros;"},{"li":"Hawaiian - 14 euros;"},{"li":"Diavola - 13 euros;"}]',
      xml:   '<li>Margherita - 12 euros;</li><li>Hawaiian - 14 euros;</li><li>Diavola - 13 euros;</li>'
    },
    'cxl-if': {
      input: '[pizza stock=2]\n[?if [[@stock > 100, plenty], [@stock > 10, some], [@stock > 0, last few], [*, sold out]]]',
      cx:    'last few',
      json:  '"last few"',
      xml:   'last few'
    }
  };

  const pick   = document.getElementById('cxp-pick');
  const input  = document.getElementById('cxp-input');
  const runBtn = document.getElementById('cxp-run');
  const reset  = document.getElementById('cxp-reset');
  const outCx   = document.getElementById('cxp-out-cx');
  const outJson = document.getElementById('cxp-out-json');
  const outXml  = document.getElementById('cxp-out-xml');
  const tabs   = document.querySelectorAll('.cxp-tab');
  const panes  = document.querySelectorAll('.cxp-pane');

  if (!pick || !input) return;

  function load(key) {
    const ex = examples[key];
    if (!ex) return;
    input.value = ex.input;
    outCx.textContent   = ex.cx;
    outJson.textContent = ex.json;
    outXml.textContent  = ex.xml;
  }

  function setTab(name) {
    tabs.forEach(t => t.classList.toggle('is-active', t.dataset.tab === name));
    panes.forEach(p => p.classList.toggle('is-active', p.id === 'cxp-out-' + name));
  }

  pick.addEventListener('change', () => load(pick.value));
  reset.addEventListener('click', () => load(pick.value));
  runBtn.addEventListener('click', () => load(pick.value));
  tabs.forEach(t => t.addEventListener('click', () => setTab(t.dataset.tab)));

  load(pick.value || 'atom');
})();
