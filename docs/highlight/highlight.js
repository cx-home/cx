// CX docs syntax highlighter.
//
// Tiny regex-based tokenizer that handles the languages the docs
// actually use: cx, cxl, shell, python, go, rust, javascript,
// typescript, java, c, ruby, sql, ebnf, html, xml, csharp, kotlin,
// swift, v. No external library; one function, ~150 lines.
//
// Tokens are marked with class names that style.css colours:
//   .hl-comment .hl-string .hl-number .hl-literal .hl-keyword
//   .hl-element .hl-directive .hl-sigil .hl-type .hl-attr .hl-fn
//
// On load, every <code class="language-X"> inside a <pre> is
// highlighted by walking RULES[X] top-to-bottom and replacing
// matched bytes with <span class="hl-...">…</span>. Overlapping
// matches yield to the earlier-listed rule, so the order of rules
// per language is significant.
//
// Callers can also invoke highlightCode(text, lang) directly —
// the playground uses this to highlight its output panes.

(function (global) {
  'use strict';

  // A CX `[; … ]` block comment closes on the `]` that MATCHES the `[;`'s `[`:
  // brackets balance, and `[#…#]` / `[|…|]` are atomic spans whose inner `]`
  // does not count (mirrors the parser's read_until_close). A regex can't
  // balance brackets, so scan. Returns [{start,end}] spans (used as a rule
  // below — highlightCode accepts a function in the pattern slot).
  function scanCxComment(code) {
    const out = [];
    for (let i = 0; i < code.length; i++) {
      if (code[i] === '[' && code[i + 1] === ';') {
        let depth = 1;            // the `[;`'s `[`
        let j = i + 2;
        while (j < code.length && depth > 0) {
          const c = code[j], n = code[j + 1];
          if (c === '[' && n === '#') {           // atomic raw text [# … #]
            const k = code.indexOf('#]', j + 2);
            j = k === -1 ? code.length : k + 2;
          } else if (c === '[' && n === '|') {    // atomic block content [| … |]
            const k = code.indexOf('|]', j + 2);
            j = k === -1 ? code.length : k + 2;
          } else if (c === '[') { depth++; j++; }
          else if (c === ']') { depth--; j++; }
          else { j++; }
        }
        out.push({ start: i, end: j });
        i = j - 1;
      }
    }
    return out;
  }

  const RULES = {
    cx: [
      [scanCxComment, 'comment'],
      // Line comment: `#` followed by whitespace or end-of-line.
      // `#identifier` is the id sigil, handled later by the sigil rule.
      [/(^|[\s\(])#(?:[ \t][^\n]*|(?=\n|$))/gm, 'comment'],
      [/'''[\s\S]*?'''/g, 'string'],
      [/"[^"\n]*"/g, 'string'],
      [/'[^'\n]*'/g, 'string'],
      [/\[\?[a-zA-Z][\w-]*/g, 'directive'],
      [/\[[a-zA-Z][\w:-]*/g, 'element'],
      [/[#&*@][a-zA-Z][\w-]*/g, 'sigil'],
      [/(?<=[\s,])[+\-][a-zA-Z][\w-]*/g, 'sigil'],
      [/:[a-zA-Z][\w-]*(?=[\s=\]\[])/g, 'type'],
      [/[a-zA-Z][\w-]*(?==)/g, 'attr'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
      [/\b(true|false|null)\b/g, 'literal'],
    ],
    shell: [
      [/#[^\n]*/g, 'comment'],
      [/'[^'\n]*'/g, 'string'],
      [/"[^"\n]*"/g, 'string'],
      [/(^|\s)--?[a-zA-Z][\w-]*/gm, 'attr'],
      [/\b(cx|brew|pip|npm|cargo|go|gem|vpm|dotnet|curl|tar|chmod|sudo|bash|sh|export|set|cat|grep|sed|awk|find|mkdir|rm|mv|cp|ls|cd)\b/g, 'fn'],
      [/\$\w+/g, 'sigil'],
    ],
    python: [
      [/#[^\n]*/g, 'comment'],
      [/"""[\s\S]*?"""/g, 'string'],
      [/'''[\s\S]*?'''/g, 'string'],
      [/"[^"\n]*"/g, 'string'],
      [/'[^'\n]*'/g, 'string'],
      [/\b(import|from|def|class|return|if|elif|else|for|while|try|except|finally|with|as|in|not|and|or|None|True|False|lambda|async|await|yield|raise|pass|break|continue|global|nonlocal)\b/g, 'keyword'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
    ],
    go: [
      [/\/\/[^\n]*/g, 'comment'],
      [/\/\*[\s\S]*?\*\//g, 'comment'],
      [/`[^`]*`/g, 'string'],
      [/"[^"\n]*"/g, 'string'],
      [/\b(import|package|func|return|if|else|for|range|var|const|type|struct|interface|map|chan|go|defer|select|switch|case|default|break|continue|fallthrough|nil|true|false)\b/g, 'keyword'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
    ],
    rust: [
      [/\/\/[^\n]*/g, 'comment'],
      [/\/\*[\s\S]*?\*\//g, 'comment'],
      [/"[^"\n]*"/g, 'string'],
      [/\b(use|fn|let|mut|pub|impl|struct|enum|trait|mod|return|if|else|for|while|loop|match|in|as|where|self|Self|true|false|None|Some|Ok|Err|crate|super|extern|unsafe|async|await|move|ref|dyn|box)\b/g, 'keyword'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
    ],
    javascript: [
      [/\/\/[^\n]*/g, 'comment'],
      [/\/\*[\s\S]*?\*\//g, 'comment'],
      [/`(?:[^`\\]|\\[\s\S])*`/g, 'string'],
      [/'[^'\n]*'/g, 'string'],
      [/"[^"\n]*"/g, 'string'],
      [/\b(import|export|from|const|let|var|function|return|if|else|for|while|do|switch|case|default|break|continue|class|extends|new|this|super|null|undefined|true|false|try|catch|finally|throw|async|await|of|in|typeof|instanceof)\b/g, 'keyword'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
    ],
    typescript: 'javascript',
    ts: 'javascript',
    js: 'javascript',
    java: [
      [/\/\/[^\n]*/g, 'comment'],
      [/\/\*[\s\S]*?\*\//g, 'comment'],
      [/"[^"\n]*"/g, 'string'],
      [/\b(import|package|public|private|protected|static|final|abstract|class|interface|extends|implements|return|if|else|for|while|do|switch|case|default|break|continue|new|this|super|null|true|false|void|int|long|short|byte|float|double|boolean|char|String|try|catch|finally|throw|throws|var|record)\b/g, 'keyword'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
    ],
    kotlin: 'java',
    csharp: 'java',
    'c-sharp': 'java',
    cs: 'java',
    swift: [
      [/\/\/[^\n]*/g, 'comment'],
      [/"[^"\n]*"/g, 'string'],
      [/\b(import|func|let|var|class|struct|enum|protocol|extension|return|if|else|for|while|switch|case|default|break|continue|guard|in|as|is|nil|true|false|self|Self|try|throws|do|catch|async|await)\b/g, 'keyword'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
    ],
    ruby: [
      [/#[^\n]*/g, 'comment'],
      [/"[^"\n]*"/g, 'string'],
      [/'[^'\n]*'/g, 'string'],
      [/:[a-zA-Z_]\w*/g, 'sigil'],
      [/\b(def|end|class|module|require|return|if|elsif|else|unless|while|until|for|in|do|begin|rescue|ensure|yield|self|nil|true|false|and|or|not)\b/g, 'keyword'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
    ],
    sql: [
      [/--[^\n]*/g, 'comment'],
      [/'[^'\n]*'/g, 'string'],
      [/"[^"\n]*"/g, 'string'],
      [/\b(SELECT|FROM|WHERE|AND|OR|NOT|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|DROP|ALTER|JOIN|LEFT|RIGHT|INNER|OUTER|GROUP|ORDER|BY|HAVING|LIMIT|OFFSET|AS|ON|IN|IS|NULL|TRUE|FALSE)\b/gi, 'keyword'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
    ],
    ebnf: [
      [/\(\*[\s\S]*?\*\)/g, 'comment'],
      [/\/\*[\s\S]*?\*\//g, 'comment'],
      [/"[^"\n]*"/g, 'string'],
      [/'[^'\n]*'/g, 'string'],
      [/::=|::|\?|\*|\+|\||,|;/g, 'directive'],
      [/[A-Z][a-zA-Z]*(?=\s*::=)/g, 'element'],
    ],
    xml: [
      [/<!--[\s\S]*?-->/g, 'comment'],
      [/"[^"\n]*"/g, 'string'],
      [/'[^'\n]*'/g, 'string'],
      [/<\/?[a-zA-Z][\w:-]*/g, 'element'],
      [/\b[a-zA-Z][\w-]*(?==)/g, 'attr'],
    ],
    html: 'xml',
    c: [
      [/\/\/[^\n]*/g, 'comment'],
      [/\/\*[\s\S]*?\*\//g, 'comment'],
      [/"[^"\n]*"/g, 'string'],
      [/#\w+/g, 'directive'],
      [/\b(if|else|for|while|do|switch|case|default|break|continue|return|void|int|long|short|char|float|double|unsigned|signed|const|static|extern|struct|union|enum|typedef|sizeof|NULL|true|false)\b/g, 'keyword'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
    ],
    v: 'go',
    cxl: 'cx',
    cxs: 'cx',
    cxcol: 'cx',
    json: [
      [/"[^"\n]*"/g, 'string'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
      [/\b(true|false|null)\b/g, 'literal'],
    ],
    yaml: [
      [/#[^\n]*/g, 'comment'],
      [/"[^"\n]*"/g, 'string'],
      [/'[^'\n]*'/g, 'string'],
      [/^[a-zA-Z_][\w-]*(?=:)/gm, 'attr'],
      [/\b(true|false|null|yes|no)\b/g, 'literal'],
      [/\b\d+(?:\.\d+)?\b/g, 'number'],
    ],
    toml: 'yaml',
    md: [
      [/^#{1,6}\s.*$/gm, 'keyword'],
      [/`[^`\n]+`/g, 'string'],
      [/^\s*[-*+]\s/gm, 'sigil'],
      [/\[[^\]]+\]\([^)]+\)/g, 'element'],
    ],
    markdown: 'md',
  };

  // Resolve string aliases (e.g. typescript → javascript).
  function resolve(lang) {
    let r = RULES[lang];
    while (typeof r === 'string') r = RULES[r];
    return r || null;
  }

  function escapeHtml(s) {
    return s
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  function highlightCode(code, lang) {
    const rules = resolve(lang);
    if (!rules) return escapeHtml(code);
    const matches = [];
    const addMatch = (start, end, kind, text) => {
      for (const x of matches) {
        if (start < x.end && end > x.start) return; // earlier rule wins
      }
      matches.push({ start, end, kind, text });
    };
    for (const [pattern, kind] of rules) {
      // A rule's pattern may be a function (start/end scanner) for grammar a
      // regex can't express — e.g. bracket-balanced [; … ] block comments.
      if (typeof pattern === 'function') {
        for (const r of pattern(code)) {
          addMatch(r.start, r.end, kind, code.slice(r.start, r.end));
        }
        continue;
      }
      pattern.lastIndex = 0;
      let m;
      while ((m = pattern.exec(code)) !== null) {
        const start = m.index;
        const end = start + m[0].length;
        // Reject overlap with any earlier match (first-rule wins).
        let overlaps = false;
        for (const x of matches) {
          if (start < x.end && end > x.start) { overlaps = true; break; }
        }
        if (!overlaps) matches.push({ start, end, kind, text: m[0] });
        if (m[0].length === 0) pattern.lastIndex++;
      }
    }
    matches.sort((a, b) => a.start - b.start);
    let out = '';
    let pos = 0;
    for (const m of matches) {
      if (m.start < pos) continue;
      out += escapeHtml(code.slice(pos, m.start));
      out += '<span class="hl-' + m.kind + '">' + escapeHtml(m.text) + '</span>';
      pos = m.end;
    }
    out += escapeHtml(code.slice(pos));
    return out;
  }

  function highlightAll(root) {
    (root || document).querySelectorAll('pre code[class*="language-"]').forEach((block) => {
      const cls = block.className.match(/language-([\w-]+)/);
      if (!cls) return;
      const lang = cls[1];
      const code = block.textContent;
      block.innerHTML = highlightCode(code, lang);
    });
  }

  global.CXHighlight = { highlight: highlightCode, highlightAll };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => highlightAll());
  } else {
    highlightAll();
  }
})(window);
