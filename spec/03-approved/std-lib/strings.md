# `cx-stdlib/strings` — string inspection, search, transform

```cx
[module-meta name=strings tier=A status=current
  [standard ref='Unicode UAX #29' title='Text segmentation']]
```

**Status:** Current

Normative reference for the `cx-stdlib/strings` sub-package.

---

## §1. Scope

`cx-stdlib/strings` provides the string-manipulation surface that doesn't fall into more specialized modules:

- **Inspection** — length, predicates, character class checks.
- **Case** — upper / lower / title / case-folding.
- **Search** — find / contains / starts-with / ends-with / count.
- **Transform** — trim / split / join / replace / pad / repeat.
- **Format** — runtime template-style `format` for human-readable string assembly. (Compile-time interpolation is the `[?str]` directive — §8.)
- **Encoding helpers** — escape / unescape for common targets (HTML, URL, shell, JSON).

CX strings are **UTF-8** by default. Most operations are Unicode-aware: case folding follows Unicode tables, character predicates use Unicode categories, character counts are scalar-value-aware. Byte-level operations live in [`cx-stdlib/bytes`](bytes.md); regex lives in [`cx-stdlib/re`](re.md).

## §2. Conceptual model

A CX string is a sequence of Unicode scalar values (USVs), encoded as UTF-8 bytes internally. **All indexing and length operations are character-aware (codepoint positions)** — they never split a multi-byte sequence.

There is deliberately no byte-aware indexing surface in this module. Callers needing byte-level positions convert to bytes via `bytes/from-string-utf8` and use [`cx-stdlib/bytes`](bytes.md). `length-bytes` is retained as a pure UTF-8 byte count since it is a common need and is not an indexing operation.

## §3. Public function surface

### §3.1. Inspection

```
[?def length        scope=public pure [returns int]    ($s::string) ...]
[?def length-bytes  scope=public pure [returns int]    ($s::string) ...]
[?def is-empty      scope=public pure [returns bool]   ($s::string) ...]
[?def at            scope=public pure [returns string] ($s::string $i::int) ...]
[?def slice         scope=public pure [returns string] ($s::string $start::int $end::int) ...]
[?def reverse       scope=public pure [returns string] ($s::string) ...]
```

- `length(s)` — codepoint count.
- `length-bytes(s)` — UTF-8 byte count.
- `at(s, i)` — single-character substring at codepoint position `i`; raises `CXER2900 E_STRINGS_INDEX_OUT_OF_RANGE` if out of bounds.
- `slice(s, start, end)` — Python-style half-open substring; bounds clamp.

### §3.2. Search

```
[?def contains    scope=public pure [returns bool]           ($s::string $needle::string) ...]
[?def find        scope=public pure [returns int]            ($s::string $needle::string) ...]
[?def find-from   scope=public pure [returns int]            ($s::string $needle::string $from::int) ...]
[?def rfind       scope=public pure [returns int]            ($s::string $needle::string) ...]
[?def starts-with scope=public pure [returns bool]           ($s::string $prefix::string) ...]
[?def ends-with   scope=public pure [returns bool]           ($s::string $suffix::string) ...]
[?def count       scope=public pure [returns int]            ($s::string $needle::string) ...]
[?def find-all    scope=public pure [returns [sequence int]] ($s::string $needle::string) ...]
```

`find` returns -1 if absent; `rfind` is right-to-left. `count` counts non-overlapping occurrences.

### §3.3. Case

```
[?def upper        scope=public pure [returns string] ($s::string) ...]
[?def lower        scope=public pure [returns string] ($s::string) ...]
[?def title        scope=public pure [returns string] ($s::string) ...]
[?def case-fold    scope=public pure [returns string] ($s::string) ...]
[?def swap-case    scope=public pure [returns string] ($s::string) ...]
[?def upper-locale scope=public pure [returns string] ($s::string $locale::string) ...]
[?def lower-locale scope=public pure [returns string] ($s::string $locale::string) ...]
```

- `upper` / `lower` — Unicode simple case (default tables).
- `title` — title-case per **Unicode UAX #29 word boundaries**; e.g. `"jean-paul sartre"` → `"Jean-Paul Sartre"`.
- `case-fold` — canonical form for case-insensitive comparison.
- `upper-locale` / `lower-locale` — delegate to [`cx-stdlib/locale`](locale.md) for Turkish dotted-i, Lithuanian, etc.

### §3.4. Trim

```
[?def trim             scope=public pure [returns string] ($s::string) ...]
[?def trim-start       scope=public pure [returns string] ($s::string) ...]
[?def trim-end         scope=public pure [returns string] ($s::string) ...]
[?def trim-chars       scope=public pure [returns string] ($s::string $chars::string) ...]
[?def trim-start-chars scope=public pure [returns string] ($s::string $chars::string) ...]
[?def trim-end-chars   scope=public pure [returns string] ($s::string $chars::string) ...]
```

- `trim` — strip Unicode whitespace from both ends.
- `trim-chars(s, "<>")` — strip any of the given characters.

### §3.5. Split and join

```
[?def split            scope=public pure [returns [sequence string]] ($s::string $sep::string) ...]
[?def split-limit      scope=public pure [returns [sequence string]] ($s::string $sep::string $max::int) ...]
[?def split-lines      scope=public pure [returns [sequence string]] ($s::string) ...]
[?def split-whitespace scope=public pure [returns [sequence string]] ($s::string) ...]
[?def join             scope=public pure [returns string]            ($parts::[sequence string] $sep::string) ...]
```

- `split` — split on each occurrence of `sep`. Empty `sep` splits on every character.
- `split-limit` — at most `max+1` segments.
- `split-lines` — split on `\n`, `\r\n`, or `\r`; trailing-empty dropped.
- `split-whitespace` — split on any Unicode whitespace; consecutive whitespace collapsed.

### §3.6. Replace

```
[?def replace       scope=public pure [returns string] ($s::string $from::string $to::string) ...]
[?def replace-first scope=public pure [returns string] ($s::string $from::string $to::string) ...]
[?def replace-n     scope=public pure [returns string] ($s::string $from::string $to::string $n::int) ...]
```

For regex-based replace, use `re/replace` from [`cx-stdlib/re`](re.md).

### §3.7. Pad and repeat

```
[?def pad-start scope=public pure [returns string] ($s::string $target::int $pad::string) ...]
[?def pad-end   scope=public pure [returns string] ($s::string $target::int $pad::string) ...]
[?def center    scope=public pure [returns string] ($s::string $target::int $pad::string) ...]
[?def repeat    scope=public pure [returns string] ($s::string $n::int) ...]
```

`pad-start(s, 10, "0")` → `"0000000abc"` for `s = "abc"`.

### §3.8. Character class predicates

```
[?def is-ascii        scope=public pure [returns bool] ($s::string) ...]
[?def is-digit        scope=public pure [returns bool] ($s::string) ...]
[?def is-alpha        scope=public pure [returns bool] ($s::string) ...]
[?def is-alphanumeric scope=public pure [returns bool] ($s::string) ...]
[?def is-whitespace   scope=public pure [returns bool] ($s::string) ...]
[?def is-upper        scope=public pure [returns bool] ($s::string) ...]
[?def is-lower        scope=public pure [returns bool] ($s::string) ...]
[?def is-blank        scope=public pure [returns bool] ($s::string) ...]
```

True iff every character matches the class. Empty string → true (vacuous). Unicode-aware (digits include Eastern Arabic numerals, etc.).

### §3.9. Format / interpolation

```
[?def format scope=public pure [returns string] ($template::string $args::[sequence any]) ...]
```

Template uses `{}` placeholders for positional args and `{name}` for named args. A single optional **type char** may follow a colon — `{name:type}`. No width, precision, alignment, fill, sign, or grouping specifiers are currently supported.

```cx
[$strings:format "Hello, {}! You have {} messages." ["Alice" 5]]
  → "Hello, Alice! You have 5 messages."

[$strings:format "Hex: {value:x}" {value 255}]
  → "Hex: ff"
```

Full format-spec grammar:

```
replacement_field ::= "{" [field_name] [":" type_char] "}"
field_name        ::= integer | identifier
type_char         ::= "d" | "f" | "s" | "x" | "X"
```

That is the entire surface — five type chars, no other modifiers. Width / precision / alignment / fill / sign / grouping can be added non-breaking in a future revision.

For deferred features, compose with dedicated functions: decimal places via `math/round-to` then `{:f}`; width/alignment/fill via `pad-start` / `pad-end` / `center`; locale-aware number grouping via `locale/format-number`.

### §3.10. Encoding helpers

```
[?def escape-html   scope=public pure [returns string] ($s::string) ...]
[?def unescape-html scope=public pure [returns string] ($s::string) ...]
[?def escape-shell  scope=public pure [returns string] ($s::string) ...]
[?def escape-json   scope=public pure [returns string] ($s::string) ...]
[?def escape-regex  scope=public pure [returns string] ($s::string) ...]
```

- `escape-html` — escapes the five XML/HTML metacharacters: `&` `<` `>` `"` `'` → `&amp;` `&lt;` `&gt;` `&quot;` `&#39;`.
- `unescape-html` — decodes numeric entities (`&#65;`, `&#x41;`) and the full HTML5 named entity set (~2 200 entities) per the WHATWG named-character-reference table.
- `escape-shell` — POSIX shell-safe quoting (single-quote based).
- `escape-json` — JSON string escapes.
- `escape-regex` — thin alias delegating to `re/escape` ([`cx-stdlib/re`](re.md) §4.6).

### §3.11. Locale-free numeric parsing

```
[?def to-number scope=public pure [returns [or number absence]] ($s::string) ...]
[?def to-int    scope=public pure [returns [or int absence]]    ($s::string) ...]
[?def to-float  scope=public pure [returns [or float absence]]  ($s::string) ...]
```

- The plain, locale-free string→number bridge. The accepted grammar is
  `ws? sign? mantissa exponent? ws?` where `mantissa` is `digits | digits "."
  digits? | "." digits` (at least one ASCII digit) and `exponent` is
  `("e"|"E") sign? digits` (at least one digit). Surrounding whitespace is
  trimmed.
- `to-number` returns an **int** for pure-integer syntax (`"-5"` → `-5`) and a
  **float** for fractional / exponent syntax (`"3.07"` → `3.07`, `"1e3"` →
  `1000.0`). `to-int` accepts integer syntax only (`"3.07"` / `"1e3"` →
  absence). `to-float` coerces any valid numeric string to a float (`"5"` →
  `5.0`).
- A non-numeric input — trailing junk (`"3.07abc"`), grouping separators
  (`"1,234"`), a lone sign / `.`, a missing-mantissa exponent (`"e3"`), or the
  empty string — yields the **absence channel `()`** (never a silent string
  passthrough), so callers branch with `[?else …]`. This is the safe
  replacement for the `[$cx:parse …]` workaround, which leaked non-numeric
  input through as a string and only failed at a later arithmetic op.
- For grouping, Unicode digits, or alternate decimal separators use
  [`cx-stdlib/locale`](locale.md) `parse-number-locale` (which raises on
  failure rather than signaling absence).

## §4. Edge cases

- **Empty separators.** `split("abc", "")` → `["a", "b", "c"]`.
- **Overlapping matches.** `count("aaaa", "aa")` → 2 (non-overlapping). For overlapping, use `re` with capturing groups.
- **Locale-independence.** `upper` / `lower` use Unicode default tables, not locale. Use `upper-locale` / `lower-locale` for locale-aware behavior.
- **Performance.** Character-aware operations on multi-byte strings are O(N) at minimum. Implementations may cache an ASCII-fast-path flag per string. Byte-level hot loops should drop to [`cx-stdlib/bytes`](bytes.md).

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER2900` | `E_STRINGS_INDEX_OUT_OF_RANGE` | `at` with out-of-bounds codepoint position |
| `CXER2901` | `E_STRINGS_FORMAT_TEMPLATE_INVALID` | `format` with unparseable template |
| `CXER2902` | `E_STRINGS_FORMAT_ARG_MISSING` | `format` template referencing missing arg |
| `CXER2903` | `E_STRINGS_FORMAT_TYPE_MISMATCH` | `format` arg incompatible with format spec |
| `CXER2904` | `E_STRINGS_INVALID_UTF8` | Safety net for in-spec CX strings |

## §6. Conformance fixtures

Under `conformance/stdlib/strings.cxd`:

- **Length char vs byte:** `length("héllo")` = 5; `length-bytes("héllo")` = 6.
- **Multi-byte slice:** slice respects codepoint boundaries.
- **Search:** find / rfind / contains / count / find-all on multi-byte strings.
- **Case:** `upper("straße")` = `"STRASSE"`.
- **Title UAX-29:** `title("jean-paul sartre")` = `"Jean-Paul Sartre"`.
- **Trim:** Unicode whitespace (U+00A0, U+2028, etc.) trimmed.
- **Split-lines:** all three line-end conventions handled; trailing-empty dropped.
- **Pad:** correct width; multi-char pad truncated.
- **Format type-chars:** positional `{}` / named `{name}`; `{x:d}` / `{x:f}` / `{x:s}` / `{x:x}` / `{x:X}`. Width/precision/alignment (e.g. `{x:.2f}`) raises `CXER2901`.
- **Format error:** missing arg raises `CXER2902`.
- **HTML escape:** `escape-html` emits the five metacharacters; `unescape-html` decodes the full HTML5 named set (`&hellip;`, `&mdash;`, `&copy;`) plus numeric entities.
- **Predicates:** Unicode digit categories included in `is-digit`.
- **Empty string:** all predicates return true for `""`.

## §7. Cross-references

- [`spec/std-lib/re.md`](re.md) — regex-based search and replace; canonical `escape`.
- [`spec/std-lib/bytes.md`](bytes.md) — byte-level operations on UTF-8-encoded form.
- [`spec/std-lib/locale.md`](locale.md) — locale-aware case mapping and collation.
- [`spec/std-lib/format.md`](format.md) — CX-value-to-CX-text emission (distinct from the `strings` module's `[$strings:format]` template substitution).

## §8. Companion directive — `[?str]` string interpolation

Compile-time string interpolation ships as the `[?str]` **directive** (not a function in this module). It complements the runtime `[$strings:format]` function:

| Use case | Mechanism |
|---|---|
| Static text with bindings / data navigation | `[?str "..."]` directive — compile-time, type-checked |
| Runtime template (loaded from config / file / user input) | `[$strings:format $template $args]` — runtime substitution |

`[?str]` interpolates bindings and CXPath expressions inside `{...}`:

```
[?str "Hello {$name}, you have {$user/unread-count} unread"]
[?str "Active users: {$users//u[@active]/@email}"]
```

What's allowed inside `{...}` is a CXPath expression (a `$binding`, a path navigation `$x/child`, or a filtered query `$x//y[@pred]`). Full CX expressions (function calls inside `{...}`) are not currently in scope — bind first, then interpolate:

```
[?let [= $upper [$strings:upper $name]]
  [?str "Hello {$upper}"]]
```

The `[?str]` directive's normative spec is [`spec/core/code.md`](../core/code.md) §8.12 (registered in §4.1; grammar `[127r]`). It does not appear in this module's `[?def]` surface because it is scope-aware (resolves `$`-bindings in the enclosing environment) and is therefore directive territory.
