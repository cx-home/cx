# `cx-stdlib/re` — regular expressions

```cx
[module-meta name=re tier=A status=current
  [standard ref='RE2' title='Regex syntax']]
```

**Status:** Current

Normative reference for the `cx-stdlib/re` sub-package.

---

## §1. Scope

`cx-stdlib/re` provides regular expressions backed by the libcx-vendored **RE2** engine — same engine as schema validator pattern matching. RE2 guarantees linear-time matching against any input (no catastrophic backtracking), at the cost of disallowing some PCRE features (backreferences, lookbehind).

The module provides pattern compilation; match / find / find-all / find-iter (lazy); replace (literal + function-based); split; named and numbered capture groups; and pattern inspection.

## §2. Pattern syntax

RE2 syntax (a subset of PCRE):

| Feature | Supported |
|---|---|
| Literal characters | ✓ |
| Character classes (`[abc]`, `[^a-z]`, `\d`, `\w`, `\s`) | ✓ |
| Quantifiers (`*`, `+`, `?`, `{n}`, `{n,}`, `{n,m}`) | ✓ |
| Alternation (`a|b`) | ✓ |
| Grouping (`(...)`, `(?:...)`) | ✓ |
| Named groups (`(?P<name>...)`) | ✓ |
| Anchors (`^`, `$`, `\b`, `\B`, `\A`, `\z`) | ✓ |
| Lazy quantifiers (`*?`, `+?`, `??`) | ✓ |
| Unicode classes (`\p{L}`, `\p{Nd}`, `\P{...}`) | ✓ |
| Case-insensitive / multiline / dotall (`(?i)` / `(?m)` / `(?s)`) | ✓ |
| Backreferences (`\1`, `\k<name>`) | ✗ |
| Lookahead / lookbehind | ✗ |
| Atomic groups (`(?>...)`) | ✗ |
| Inline literal regions (`\Q...\E`) | ✗ |

For unsupported features the parser raises `CXER3200 E_RE_FEATURE_UNSUPPORTED` at compile time.

For a **whole-pattern** literal use the `literal` flag (§4.1) — it auto-escapes the entire pattern. **Partial-literal** patterns compose via `[$re:escape]` (§4.6).

## §3. Compiled pattern values

`compile` returns an opaque `[regex ...]` element value. Each call builds a fresh compiled-regex value — there is no internal compile cache. The idiomatic performance path is to **compile once and reuse** the value: bind it at module scope and pass it around.

```cx
[?const EMAIL_RE [$re:compile "^[\\w.+-]+@[\\w-]+\\.[\\w.-]+$"]]
```

A bounded internal LRU cache is permissible as a non-breaking internal optimization; callers MUST NOT rely on cache-hit timing.

## §4. Public function surface

### §4.1. Compilation

```
[?def compile            scope=public pure [returns element] ($pattern::string) ...]
[?def compile-with-flags scope=public pure [returns element] ($pattern::string $flags::map) ...]
```

`compile` uses default flags. `compile-with-flags` accepts a flags map; raises `CXER3201 E_RE_PATTERN_INVALID` on syntax error.

| Flag key | Default | Semantics |
|---|---|---|
| `case-insensitive` | `false` | Equivalent to `(?i)` |
| `multiline` | `false` | `^` / `$` match line boundaries |
| `dotall` | `false` | `.` matches newlines |
| `unicode` | `true` | Unicode-aware classes |
| `literal` | `false` | Whole pattern is a literal string |
| `max-match-bytes` | `0` | 0 = unbounded; positive limits match length for DoS protection |

### §4.2. Matching

```
[?def matches   scope=public pure [returns bool]              ($re::element $s::string) ...]
[?def find      scope=public pure [returns element]           ($re::element $s::string) ...]
[?def find-from scope=public pure [returns element]           ($re::element $s::string $from::int) ...]
[?def find-all  scope=public pure [returns [sequence element]] ($re::element $s::string) ...]
[?def find-iter scope=public pure [returns [iterator element]] ($re::element $s::string) ...]
```

- `matches` — true iff the entire string matches.
- `find` — first match; returns `[match start=$int end=$int text=$string groups=[sequence ...]]` or `[no-match]`. Group 0 is the full match.
- `find-from` — first match at or after byte position `from`.
- `find-all` — all non-overlapping matches as a materialized sequence.
- `find-iter` — lazy iterator; yields matches on demand.

**Zero-width advancement.** When `find-all` / `find-iter` produce a zero-width (empty) match, the search position advances by exactly **one codepoint** before searching again — codepoint-granular, consistent with [`spec/std-lib/strings.md`](strings.md). This guarantees forward progress and termination.

### §4.3. Groups

```
[?def group       scope=public pure [returns string]           ($m::element $i::int) ...]
[?def group-named scope=public pure [returns string]           ($m::element $name::string) ...]
[?def groups-all  scope=public pure [returns [sequence string]] ($m::element) ...]
[?def groups-map  scope=public pure [returns map]              ($m::element) ...]
```

- `group(m, i)` — value of numbered group `i` (0 = full match).
- `group-named` — value of named group.
- `groups-all` — all groups; `groups-map` — named-only as a map.

### §4.4. Replace

```
[?def replace       scope=public pure [returns string] ($re::element $s::string $template::string) ...]
[?def replace-first scope=public pure [returns string] ($re::element $s::string $template::string) ...]
[?def replace-fn    scope=public pure [returns string] ($re::element $s::string $f::any) ...]
```

- `replace` — replace all matches.
- `replace-first` — replace only the first match.
- `replace-fn` — invoke callable `f` per match (taking the match element, returning the replacement string).

Template substitution:

| Token | References |
|---|---|
| `$0` | the entire match |
| `$1`, `$2`, … | numbered capture groups |
| `${name}` | named capture groups |
| `$$` | a literal `$` |

The Perl/JS `$&` alias is **not** supported — use `$0`.

### §4.5. Split

```
[?def split       scope=public pure [returns [sequence string]] ($re::element $s::string) ...]
[?def split-limit scope=public pure [returns [sequence string]] ($re::element $s::string $max::int) ...]
```

`split-limit` produces at most `max+1` segments.

### §4.6. Inspection

```
[?def group-count   scope=public pure [returns int]              ($re::element) ...]
[?def group-names   scope=public pure [returns [sequence string]] ($re::element) ...]
[?def pattern-text  scope=public pure [returns string]           ($re::element) ...]
[?def pattern-flags scope=public pure [returns map]              ($re::element) ...]
[?def escape        scope=public pure [returns string]           ($s::string) ...]
```

`escape` produces the canonical **RE2 `QuoteMeta`** form: each ASCII character that is neither a word character (`[A-Za-z0-9_]`) nor whitespace is prefixed with a single backslash, and all other characters (including alphanumerics, underscore, whitespace, and non-ASCII bytes) are emitted unchanged — so `escape("a.b")` is `"a\.b"`. Because `re` mandates RE2 throughout (§1–§2), this is the only consistent escaping for `[$re:compile]` to treat the result as a verbatim literal.

`[$re:escape]` is the canonical implementation; the `cx-stdlib/strings` module's `escape-regex` function (`[$strings:escape-regex]`) is a thin alias that delegates here.

## §5. Edge cases

- **Empty matches.** `^` or `a*` can match empty positions. `find-all` of `^` against multiline input returns one match per line boundary (with `multiline=true`).
- **Zero-width advancement.** See §4.2 — one-codepoint advance after each empty match guarantees termination.
- **Unicode-aware classes.** With `unicode=true`, `\d` is `\p{Nd}`, `\w` is `\p{L} + \p{Nd} + _`, `\s` is Unicode whitespace. With `unicode=false`, ASCII-only.
- **Linear-time guarantee.** RE2 guarantees O(n) matching regardless of pattern complexity.
- **Replace template escapes.** Literal `$` is `$$`; no backslash escapes in template strings.

## §6. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER3200` | `E_RE_FEATURE_UNSUPPORTED` | `compile` on PCRE feature RE2 doesn't support |
| `CXER3201` | `E_RE_PATTERN_INVALID` | `compile` on syntactically-invalid pattern |
| `CXER3202` | `E_RE_GROUP_NOT_FOUND` | `group(m, i)` out-of-range; `group-named` non-existent name |
| `CXER3203` | `E_RE_MATCH_BYTES_EXCEEDED` | Match exceeds `max-match-bytes` budget |

## §7. Conformance fixtures

Under `conformance/stdlib/re.cxd`:

- **Basic patterns:** literal / alternation / class / quantifier match expected.
- **Anchors:** `^foo$` against single-line and multi-line input.
- **Greedy vs lazy:** `.*` vs `.*?` produce different captures.
- **Groups:** numbered and named groups extract correctly.
- **Backreferences rejected:** `compile("(.)\\1")` raises `CXER3200`.
- **Lookahead rejected:** `compile("(?=foo)")` raises `CXER3200`.
- **Unicode classes:** `\d` matches `'9'` and `'٩'` under `unicode=true`.
- **Replace template:** `$0` / `$1` / `${name}` substitution.
- **Literal `$`:** `$$` emits literal `$`.
- **`$&` rejected:** not a full-match alias (use `$0`).
- **Replace function:** callable invoked per match; result substituted.
- **Find-iter laziness:** iterator doesn't materialize all matches at once.
- **Zero-width advance:** `find-all` of `a*` against `"baab"` yields `["", "aa", "", ""]` (terminates).
- **Literal flag:** `compile-with-flags` with `literal=true` matches metacharacters literally.
- **Linear time:** pathological backtracking pattern (e.g. `(a+)+b` against `aaaa...c`) completes in linear time.

## §8. Cross-references

- [`spec/core/abi.md`](../core/abi.md) — RE2 engine capability bit.
- [`spec/std-lib/strings.md`](strings.md) — `escape-regex` is a thin alias delegating to `[$re:escape]` (§4.6).
- [`spec/std-lib/ft.md`](ft.md) — fulltext tokenizer customization may compose with regex.
- RE2 spec: `https://github.com/google/re2/wiki/Syntax`.
