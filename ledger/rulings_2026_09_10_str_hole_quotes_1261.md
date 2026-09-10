# RULED: 1261-a — a `[?str]` hole is scanned to its matching brace, quotes inside it skipped

**Fable, 2026-09-10 04:10Z, under the owner's delegation:** (a) balance the
hole. Refused (b) documenting the restriction and naming it in the refusal
(`?str hole contains a double-quoted literal; bind it first`): §8.12 already
says a hole admits **any** expression, and an expression that contains a
string literal — or a map literal, which carries `}` — is the ordinary case;
a documented "bind it first" is a workaround written into the contract.

## What was wrong

The lexer read the template as an ordinary string literal, so the first
unescaped `"` inside a hole closed it: `[?str "outer {[?if … [else [?str
"one {$n}"]]]}"]` died with `expected ']' (closing [?str]), got one at line
2:65` — a column, not the cause. `scan_str_template` then found the hole's
end at the first `}`, which §8.12 recorded as a limit ("a hole cannot contain
a literal `}` … wrap such cases in a bound value").

## What changed

- `str_hole_end` (program_lexer.v): one scanner — braces nest, a `'…'` /
  `"…"` inside the hole is skipped whole (backslash escapes honoured). The
  lexer uses it when the string literal follows `[?str` (`template_next`,
  set by the tokenize loop from the previous token), copying the hole
  VERBATIM (no escape decoding — the hole is re-parsed by the program parser,
  which decodes its own literals); `scan_str_template` uses the same scanner
  to split the template into slots. `{{` / `}}` literal braces are unchanged.
- code.md §8.12: the limit sentence is replaced by the rule (token carried).
- Fixtures (`code.cxd` `program-str-hole-001…003`): the issue's nested
  double-quoted `[?str]` in a hole (both arms), a map literal in a hole, a
  brace inside a single-quoted string in a hole — all RED before (CXER0100).
