// scripts/test_landing_run.mjs — the landing RUN gate (HOME-1; RULED: DOCS-51
// §4, DOCS-41, DOCS-47; PLAY-1's on-load rule applied to the landing).
//
// WHAT IT ASSERTS, in headless Chrome against the ASSEMBLED site (`make
// site`; CX_PLAYGROUND_ROOT names another docroot that holds index.html at
// its root):
//
//   (1) the page's BYTES carry the answer: before any script runs, index.html
//       holds the running example's program, the fixture's recorded answer
//       and the fixture line naming the case and its suite — a browser
//       without the engine sees the recorded answer, never a blank;
//   (2) the ENGINE LOADS on the landing: cxlib becomes ready on the JSPI
//       bundle (asserted, as the playground gates assert it);
//   (3) the example RUNS ON LOAD, with no click: the page marks the answer as
//       run (body[data-home-run="ran"]) and the answer it printed is the
//       fixture's recorded one, byte for byte after the trailing newline;
//   (4) the CHROME is the guide's: the sidebar's five groups in order, Home
//       active, the sheet bar and the title block present;
//   (5) the three DOORS and the four JOURNEY cards each link a file the
//       docroot serves (the manifest rule, walked on the assembled tree).
//
// Exit 0 iff all hold; 1 on any failure; 2 on a setup problem (no assembled
// site, no Chromium-family browser) — never a silent skip. It prints the
// reader's walk RESULTS.md quotes: the first screen's text and the answer
// the engine printed.
//
// Usage: node scripts/test_landing_run.mjs [--verbose]
//   CX_PLAYGROUND_ROOT=<dir>   the docroot to serve (default site)
//   CX_CHROME=<browser>        LANDING_GATE_DEADLINE=<s> (default 600)

import { readFileSync, existsSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { createHarness, ROOT } from './playground-gate/browser_harness.mjs';

const VERBOSE = process.argv.includes('--verbose');
const DOCROOT = process.env.CX_PLAYGROUND_ROOT
  ? resolve(ROOT, process.env.CX_PLAYGROUND_ROOT) : resolve(ROOT, 'site');
const DEADLINE = 1000 * Number(process.env.LANDING_GATE_DEADLINE || 600);
const H = createHarness({ label: 'landing-run', deadlineMs: DEADLINE });

const failures = [];
const fail = (m) => { failures.push(m); console.log(`  FAIL ${m}`); };
const ok = (m) => console.log(`  ok   ${m}`);

// (1) the bytes, before any script runs.
const indexPath = join(DOCROOT, 'index.html');
if (!existsSync(indexPath)) H.setupFail(`${indexPath} is not there.`, 'make site (the landing lives at the site root)');
const html = readFileSync(indexPath, 'utf8');
const attr = (name) => {
  const m = html.match(new RegExp(`<figure class="home-run"[^>]*\\s${name}="([^"]*)"`));
  return m ? m[1].replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&') : null;
};
const fixtureId = attr('data-id');
const expected = attr('data-expected');
if (!fixtureId || expected === null) fail('index.html carries no <figure class="home-run"> with data-id and data-expected — the running example is not on the page');
else {
  const outMatch = html.match(/<code id="home-run-out">([\s\S]*?)<\/code>/);
  const recorded = outMatch ? outMatch[1].replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&') : '';
  if (!recorded.includes(expected.replace(/\n+$/, ''))) fail(`the page's bytes do not carry the recorded answer for ${fixtureId}: ${JSON.stringify(recorded.slice(0, 120))}`);
  else ok(`the bytes carry the recorded answer: ${fixtureId} → ${recorded.split('\n').slice(1).join(' ').slice(0, 80)}`);
  const strip = new RegExp(`Fixture <code>${fixtureId.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}</code> in <code>[^<]+</code>`);
  if (!strip.test(html)) fail(`the page's bytes do not name the fixture ${fixtureId} and its suite beside the running example`);
  else ok('the fixture line names the case and its suite');
  if (!/<script src="wasm\/cxlib\.js/.test(html)) fail('the page does not load wasm/cxlib.js — nothing would run the example');
}

// (2) the engine loads on THIS page (the harness's bootPage opens
// playground.html; the landing is opened by the same rig, page by page).
const chrome = H.requirePreconditions({ needNative: false, root: DOCROOT });
const port = await H.bootServer({ portBase: 9970, verbose: VERBOSE, root: DOCROOT });
const pageUrl = `http://127.0.0.1:${port}/index.html`;
const { evalJs, version, close } = await H.bootBrowser(pageUrl, { chrome, cdpBase: 10500 });
console.log(`[landing-run] docroot: ${DOCROOT.replace(ROOT + '/', '')}`);
console.log(`[landing-run] browser: ${version['Browser']}`);
console.log(`[landing-run] page:    ${pageUrl}`);
{
  let ready = '';
  for (let i = 0; i < 200; i++) {
    H.checkDeadline('cxlib boot');
    try {
      ready = await evalJs(`(async () => {
        if (!globalThis.cxlib) return 'no-cxlib';
        try { await cxlib.ready; } catch (e) { return 'ready-threw:' + (e && e.message); }
        return 'ready';
      })()`, 30000);
    } catch (e) { ready = `cdp:${e.message}`; }
    if (ready === 'ready') break;
    await new Promise(r => setTimeout(r, 500));
  }
  if (ready !== 'ready') H.setupFail(`the landing's cxlib never became ready (${ready}).`);
  const engine = JSON.parse(await evalJs(`JSON.stringify({
    scripts: [...document.scripts].map(s => s.src).filter(s => /libcx/.test(s)),
    suspending: typeof WebAssembly.Suspending,
  })`, 30000));
  const bundle = (engine.scripts || []).join(' ');
  if (!/libcx-(async|pthreads)\.js/.test(bundle)) H.setupFail(`the landing loaded a NON-JSPI bundle (${bundle || 'none'}).`);
  if (engine.suspending !== 'function') H.setupFail('WebAssembly.Suspending is unavailable in this browser.');
  ok(`the engine loads on the landing: ${bundle.replace(/^.*\//, '')} (JSPI)`);
}

// (3) runs on load — the page's own verdict, read through the DOM.
const state = () => evalJs(`JSON.stringify({
  run: document.body.dataset.homeRun || '',
  verdict: (document.getElementById('home-run-verdict') || {}).textContent || '',
  out: (document.getElementById('home-run-out') || {}).textContent || '',
})`, 20000).then(JSON.parse);
{
  let s = null;
  for (let i = 0; i < 600; i++) {
    H.checkDeadline('the run on load');
    s = await state();
    if (s.run && s.run !== 'pending') break;
    await new Promise(r => setTimeout(r, 100));
  }
  if (!s || s.run === 'pending' || s.run === '') fail('the running example never reached a verdict on load');
  else if (s.run !== 'ran') fail(`on load the page marked the example ${JSON.stringify(s.run)}: ${s.verdict}`);
  else {
    const answer = s.out.split('\n').slice(1).join('\n').replace(/\n+$/, '');
    if (answer !== (expected || '').replace(/\n+$/, '')) fail(`the engine printed ${JSON.stringify(answer)}; the fixture records ${JSON.stringify(expected)}`);
    else ok(`runs on load: ${fixtureId} → ${answer.split('\n')[0]} (${s.verdict})`);
  }
}

// (4) the guide's chrome.
{
  const chrome = JSON.parse(await evalJs(`JSON.stringify({
    groups: [...document.querySelectorAll('aside.sidebar section > h4')].map(h => h.textContent.trim()),
    active: [...document.querySelectorAll('aside.sidebar a.active')].map(a => a.getAttribute('href')),
    bar: !!document.querySelector('header.sheet-bar'),
    block: !!document.querySelector('footer.title-block'),
    h1: (document.querySelector('.home-hero h1') || {}).textContent || '',
    lede: (document.querySelector('.home-hero p.lede') || {}).textContent || '',
    doors: [...document.querySelectorAll('.home-doors a.door')].map(a => [a.getAttribute('href'), (a.querySelector('b') || {}).textContent || '']),
    cards: [...document.querySelectorAll('.home-journey a.card')].map(a => [a.getAttribute('href'), (a.querySelector('b') || {}).textContent || '']),
    prose: (() => {
      const m = document.querySelector('main');
      if (!m) return '';
      const c = m.cloneNode(true);
      for (const p of c.querySelectorAll('pre, svg, figure.home-rings')) p.remove();
      document.body.appendChild(c);
      const t = c.innerText;
      c.remove();
      return t;
    })(),
    all: (document.querySelector('main') || {}).innerText || '',
  })`, 30000));
  const want = ['Start here', 'Guide', 'Reference', 'Repositories', 'LLM'];
  if (JSON.stringify(chrome.groups) !== JSON.stringify(want)) fail(`the sidebar's groups are ${JSON.stringify(chrome.groups)}, not the guide's five`);
  else ok(`the sidebar is the guide's: ${chrome.groups.join(' · ')}`);
  if (!chrome.active.includes('index.html')) fail(`the sidebar does not mark Home (index.html) active: ${JSON.stringify(chrome.active)}`);
  if (!chrome.bar || !chrome.block) fail('the sheet bar or the title block is missing');
  if (!/One syntax\./.test(chrome.h1)) fail(`the hero line is ${JSON.stringify(chrome.h1)}`);
  console.log(`  first screen: ${chrome.h1.replace(/\s+/g, ' ').trim()} — ${chrome.lede.replace(/\s+/g, ' ').trim().slice(0, 160)}…`);
  // (5) the doors and the cards.
  if (chrome.doors.length !== 3) fail(`${chrome.doors.length} doors on the page, not three`);
  if (chrome.cards.length !== 4) fail(`${chrome.cards.length} journey cards on the page, not four`);
  for (const [href, label] of [...chrome.doors, ...chrome.cards]) {
    const file = (href || '').split('#')[0].split('?')[0];
    if (!file || !existsSync(join(DOCROOT, file))) fail(`"${label}" links ${href}, which the site does not serve`);
    else if (VERBOSE) console.log(`  link ${label} → ${href}`);
  }
  ok(`doors: ${chrome.doors.map(([h, l]) => `${l} → ${h}`).join('; ')}`);
  ok(`journey: ${chrome.cards.map(([h, l]) => `${l} → ${h}`).join('; ')}`);
  const prose = chrome.prose.replace(/\s+/g, ' ').trim();
  const all = chrome.all.replace(/\s+/g, ' ').trim();
  console.log(`  prose as rendered: ${prose.length} characters (${all.length} with the code panes)`);
  if (prose.length >= 4000) fail(`the page's prose is ${prose.length} characters; the landing stays under 4,000 (HOME-1)`);
}

close();
console.log(`\n[landing-run] ${failures.length} failure(s)`);
if (failures.length) { console.log('FAIL — see the FAIL lines above.'); process.exit(1); }
console.log('OK — the landing carries its recorded answer, the engine loads and runs the example on load, and the page wears the guide\'s chrome.');
process.exit(0);
