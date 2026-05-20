// Tiny client-side site search for the CX docs.
//
// Index shape: [{slug, title, summary, text}, ...] emitted by
// scripts/gen_docs/scaffold.sh as <prefix>search-index.js — a
// regular <script src> that assigns window.CXSearchIndex. Using a
// script-tag load (rather than fetch of a .json) means the search
// works under file:// (cloned-and-opened) the same way it works
// over HTTP; browsers block fetch() of local JSON for security but
// load local <script src> happily.
//
// Ranking: case-insensitive token-AND. Each token must hit somewhere
// in title / summary / text. Title hits score 8, summary 3, body 1;
// per-token scores sum into a per-entry score; results sort
// descending by score, stable by slug.
//
// No frameworks, no dependencies; ~140 LOC.

(function () {
  'use strict';

  const input = document.getElementById('side-search-input');
  const list  = document.getElementById('side-search-results');
  if (!input || !list) return;

  let index = null;
  let indexErr = null;
  let active = -1;
  let last = '';

  // The search-index.js script-tag is `defer`, which means it runs
  // before DOMContentLoaded but after this file's IIFE registers its
  // event listeners. By the time the user actually focuses the
  // input, window.CXSearchIndex will be populated. If the script
  // failed to load (404, syntax error in the generated file), the
  // global is missing and we surface a clear error.
  function loadIndex() {
    if (index || indexErr) return;
    if (Array.isArray(window.CXSearchIndex)) {
      index = window.CXSearchIndex;
      return;
    }
    indexErr = new Error('window.CXSearchIndex missing — was search-index.js loaded?');
    renderError('Search index unavailable: index script did not load. Check that search-index.js is reachable from this page.');
    // eslint-disable-next-line no-console
    console.error('[cx-search] index load failed:', indexErr);
  }

  function tokenise(q) {
    return q.toLowerCase().split(/\s+/).filter(Boolean);
  }

  function score(entry, tokens) {
    const title = (entry.title || '').toLowerCase();
    const summary = (entry.summary || '').toLowerCase();
    const text = (entry.text || '').toLowerCase();
    let total = 0;
    for (const t of tokens) {
      if (!title.includes(t) && !summary.includes(t) && !text.includes(t)) {
        return 0;
      }
      if (title.includes(t)) total += 8;
      if (summary.includes(t)) total += 3;
      if (text.includes(t)) total += 1;
    }
    return total;
  }

  function snippet(text, tokens) {
    if (!text) return '';
    const low = text.toLowerCase();
    let pos = -1;
    for (const t of tokens) {
      const p = low.indexOf(t);
      if (p >= 0) { pos = p; break; }
    }
    if (pos < 0) return text.slice(0, 120) + (text.length > 120 ? '…' : '');
    const start = Math.max(0, pos - 40);
    const end = Math.min(text.length, pos + 100);
    const lead = start === 0 ? '' : '…';
    const tail = end === text.length ? '' : '…';
    return lead + text.slice(start, end) + tail;
  }

  function escapeHtml(s) {
    return s.replace(/[&<>"']/g, c => (
      c === '&' ? '&amp;' :
      c === '<' ? '&lt;' :
      c === '>' ? '&gt;' :
      c === '"' ? '&quot;' : '&#39;'
    ));
  }

  function highlight(s, tokens) {
    let out = escapeHtml(s);
    for (const t of tokens) {
      if (!t) continue;
      const re = new RegExp('(' + t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'gi');
      out = out.replace(re, '<mark>$1</mark>');
    }
    return out;
  }

  function renderError(msg) {
    list.hidden = false;
    list.innerHTML = '<li class="side-search-error">' + escapeHtml(msg) + '</li>';
  }

  function render(query) {
    if (indexErr) { renderError('Search index unavailable.'); return; }
    if (!index) { return; }
    const tokens = tokenise(query);
    if (tokens.length === 0) {
      list.hidden = true;
      list.innerHTML = '';
      active = -1;
      return;
    }
    const hits = [];
    for (const entry of index) {
      const s = score(entry, tokens);
      if (s > 0) hits.push({ entry, score: s });
    }
    hits.sort((a, b) => b.score - a.score || a.entry.slug.localeCompare(b.entry.slug));
    const top = hits.slice(0, 12);
    if (top.length === 0) {
      list.hidden = false;
      list.innerHTML = '<li class="side-search-empty">No matches for ' + escapeHtml(query) + '</li>';
      active = -1;
      return;
    }
    const prefix = input.dataset.prefix || '';
    list.innerHTML = top.map((h, i) => {
      const e = h.entry;
      const href = prefix + e.slug + '.html';
      return (
        '<li class="side-search-hit" data-i="' + i + '">' +
          '<a href="' + escapeHtml(href) + '">' +
            '<span class="side-search-title">' + highlight(e.title || e.slug, tokens) + '</span>' +
            '<span class="side-search-snip">' + highlight(snippet(e.summary || e.text || '', tokens), tokens) + '</span>' +
          '</a>' +
        '</li>'
      );
    }).join('');
    list.hidden = false;
    active = 0;
    updateActive();
  }

  function updateActive() {
    const items = list.querySelectorAll('li.side-search-hit');
    items.forEach((it, i) => it.classList.toggle('is-active', i === active));
  }

  function go(delta) {
    const items = list.querySelectorAll('li.side-search-hit');
    if (!items.length) return;
    active = (active + delta + items.length) % items.length;
    updateActive();
    items[active].scrollIntoView({ block: 'nearest' });
  }

  input.addEventListener('focus', loadIndex, { once: true });
  input.addEventListener('input', () => {
    const q = input.value.trim();
    if (q === last) return;
    last = q;
    if (!index && !indexErr) loadIndex();
    render(q);
  });
  input.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); go(1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); go(-1); }
    else if (e.key === 'Enter') {
      const items = list.querySelectorAll('li.side-search-hit a');
      if (active >= 0 && items[active]) { e.preventDefault(); items[active].click(); }
    } else if (e.key === 'Escape') {
      input.value = '';
      list.hidden = true;
      list.innerHTML = '';
      active = -1;
      last = '';
    }
  });
  // Hide on outside click.
  document.addEventListener('click', (e) => {
    if (e.target === input || list.contains(e.target)) return;
    list.hidden = true;
  });
})();
