# CX Programs — Normative Specification

**Status:** Current.

This document is the normative specification for CX code — the unified
pattern, query, and transform language. The CX surface is homoiconic
Lisp-1: every form is `[head …]`; directives carry clause-child
arguments (`[clause-head child …]`), scalar attributes (`name=value`),
and bareword modifiers.

---

## §1. Scope and goals

CX code is the single language for pattern matching, querying, and
transforming CX values, built from three primitives:

1. **Literal CX patterns** with `$bindings` for shape-matching and
 destructuring.
2. **Scala-style for-yield comprehensions** for joins, filters,
 projections, aggregations, and pipelines.
3. **A small set of named `[?…]` directives** for control flow,
 error handling, parallelism, services, concurrency, and
 visualization.

The language design follows V-lang's taste — small grammar, fast to
compile, easy to learn and read, pragmatic sugar where it pays. CX code
is dynamically typed at evaluation time; values are CX values per
`cxdm.md`.

### §1.1 Design constraints

| # | Constraint |
|---|---|
| C1 | Small grammar (≤ 10 directive names, ≤ 5 sigils) |
| C2 | One canonical AST shape per concept; aliases desugar at parse time |
| C3 | Every construct reads left-to-right as English |
| C4 | ≤ 3 operator precedence levels |
| C5 | Every keyword is a unique, greppable kebab-case token |
| C6 | A 5-line window makes sense in isolation |
| C7 | Patterns, values, and templates share one syntax (homoiconic) |
| C8 | Errors are CX values, not exceptions |
| C9 | Parallelism is one annotation |

### §1.2 Out of scope

The following are deliberately out of scope and require a future
spec amendment to enter scope in a later release:

- Protocols other than HTTP for services and clients (gRPC,
 WebSocket-only, Kafka, etc.). The directive surface is
 protocol-agnostic; new protocols add new transports without
 language changes.
- Cross-process or cross-node worker/channel transport. Single-process
 concurrency only.
- Pattern-matching optimizer passes. A tree-walking interpreter that
 meets the §11.6 performance gates is sufficient.
- IDE integrations beyond LSP CodeLens. VS Code / Neovim native
 extensions are downstream consumers of the LSP CodeLens and ship on
 their own timelines.

### §1.3 The data / program reading (start-symbol selection)

A CX resource has two readings: the **data** reading (`parse` → a Document of
inert `cx.Node` values) and the **program** reading (evaluate the same bytes as
a self-evaluating program). Which reading applies is chosen by the **caller**,
not embedded in the bytes — the grammar defines both start symbols (`[2]
Document` and `[120] Program`) and the host selects one. The reference CLI's
default action on a bare resource is the **program** reading: `cx <file|url|->`
is equivalent to `cx eval <file|url|->` (a pure-data resource evaluates to
itself). Output defaults to canonical CX; `--xml` / `--json` / `--to=…` render
the RESULT, and `--from=…` ingests a non-CX input. Because data is a
self-evaluating program, the two readings agree on every value except where an
explicit MODE rule says otherwise (SEQ-NEST, `cxdm.md` §1.2; and the name-char
fork, `lexicon.ebnf` §2). The single block comment `[; … ]` reads identically
under both, and `[-` is ALWAYS the subtraction operator head — there is no
comment-vs-subtraction fork. The pure-data constructs that carry no program meaning of their
own — raw text `[# … #]` ([L2]/[L3]), entity / character references `&name;` /
`&#nnn;`, and declarations `[! … ]` (DTD declarations and `[!DOCTYPE … ]`) —
read identically under both: the program reading admits each as a literal that
evaluates to the same `cx.Node` the data reading produces (it IS the data
reading), so a data file using them round-trips through `cx <file>` unchanged.

The reference program reader is tokenized (a lexer + parser over `[120]
Program`), whereas the data reader is scannerless. The program lexer therefore
cannot tokenize free-text element-body **prose** — em-dash, `;`, `,`, bullets
and other content punctuation the scannerless data reader accepts in body
position. To preserve the "a pure-data resource evaluates to itself" invariant
for such markup/prose documents, a host MUST, when the program reading of a
bare resource fails to parse AND no separate data input (`$doc`) was supplied,
fall back to the data reading: a resource that is valid DATA but not a valid
PROGRAM evaluates to itself. The reference CLI implements this fallback so that
`cx doc.cx` and `cx doc.cx --json|--to=…` on a prose/markup data document
produce output byte-identical to `cx --from=cx --to=…  doc.cx`. A resource that
parses as neither a program nor data surfaces the original program parse error.

The fallback exists for markup/prose with no program intent; it MUST NOT mask
a broken program. When the program-parse failure shows **program intent**, the
host MUST surface the original program diagnostic and fail (non-zero exit)
instead of falling back. Three failure classes show program intent:

1. rejection of an unknown or retired `[?name]` directive — the head is
   directive syntax, so the resource asked to be a program;
2. a syntax error after the parser committed to a recognized program
   construct (e.g. an infix comparison inside a recognized `[where …]`
   clause) — the surrounding form proves program intent; and
3. a resource whose **data reading** carries a registered program directive —
   an eval-directive node or processing-instruction node whose name is in the
   closed program-directive registry (`ProgramDirName` in the grammar). Such a
   resource is program-SHAPED: whatever made the program reading fail
   (including a lexer error raised before any directive was reached), silently
   echoing it back as data would report success (exit 0) for a program that
   never evaluated.

The program-shape test in class 3 is performed on the data reading, so it is
string-aware by construction: a directive mentioned inside quoted text parses
as text content, not as a directive node. Prose documents *about* directives
therefore keep the fallback, as do data documents whose only `[?…]` forms are
`[?cx …]` config directives or foreign processing instructions (e.g.
`[?xml-stylesheet …]` from an XML ingest).
(A future program reader that gives the lexer/parser an element-body free-text
mode would make the fallback unobservable — the program reading would simply
accept the prose directly. The fallback is the host-level guarantee in the
interim.)

**Implicit `$doc` selection (one-source homoiconic programs).** A host MAY
supply a separate data input alongside the program; when it does, that input
is bound as `$doc` (and `$input`) before evaluation, and the program's own
roots never rebind it — the caller-supplied input WINS over any in-document
data root. (The reference CLI spells this separate data input `--data=FILE|-`,
on both the bare run surface and its `cx eval` alias — the argv contract is
normative in [`misc/cli.md`](../misc/cli.md).) When NO separate data input is
supplied, the implicit
`$doc` binds to the value of the program's first **data root** — the first
top-level form, in source order, that is an element literal (the program
surface of the data reading's element production). Program-directive roots
(`[?lib …]`, `[?def …]`, and every other `[?name …]` form, known or future)
are skipped wherever they sit — before, between, or after the data roots: a
directive's status value (e.g. `[?lib]`'s `[result status=ok …]` import
status) is program-internal and MUST NOT become the implicit `$doc`. When
the resource carries no data root, `$doc` is unbound — reading `$doc`, or
using a construct that requires the implicit document (a `[?for]` pattern
generator's document-wide search, or a document-rooted CXPath expression —
the `//`- and `/`-anchored PathExpr forms), raises `cx-err:CXER0001` rather
than silently matching nothing. (This is the XPath XPDY0002 "context item
undefined" condition mapped onto the CX error surface; a **bound** `$doc`
whose query merely matches nothing still yields the empty node-set —
absence, not an error.)

---

## §2. Conventions and notation

### §2.1 Grammar notation

Grammar productions use the EBNF dialect from
`grammar.ebnf`. Terminals appear in `'single
quotes'`. Non-terminals are CamelCase. `*` means zero-or-more, `+`
means one-or-more, `?` means optional, `|` means alternation.
Grouping uses `(…)`.

### §2.2 Code examples

Code blocks tagged `cx` are CX source — either inert data or executable programs (CX is homoiconic; the same syntax covers both). Code blocks tagged `out_text` are expected textual output. Examples in this document are also fixtures in [`conformance/code.cxd`](../../../conformance/code.cxd) — the fixture identifier appears in a trailing comment when relevant.

### §2.3 Normative keywords

Per RFC 2119: **MUST**, **MUST NOT**, **SHALL**, **SHOULD**, **SHOULD
NOT**, **MAY**. Lowercase usages of these words are non-normative.

### §2.4 Error codes

Every runtime error raised by CX code carries a `:code` field with a
`cx-err:CXERnnnn` namespace identifier The
CX code-reserved range is `CXER0100–CXER0299`; the full assignment table
is in §9.4.

---

## §3. Lexical structure

The CX **lexical layer** — source encoding, whitespace, comments, the
identifier / QName token, string literals + the escape set, number / keyword /
date / datetime scalar tokens, the atom token, the glued `::T` type annotation,
structural sigils, the body-value (scalar / array) auto-typing rule, collection
literals, and the `[` element-vs-array disambiguation — is defined ONCE,
normatively, in [`lexicon.ebnf`](../formal/lexicon.ebnf). For every token shape and the
auto-typing rule, `lexicon.ebnf` is authoritative; §3.5–§3.7 below record only
the reserved-name registries and the evaluation-bearing points that are this
file's domain.

### §3.1–§3.4 Lexical essentials (normative form in `lexicon.ebnf`)

See `lexicon.ebnf` for the normative productions; in summary: source is UTF-8
(a leading BOM is consumed silently, a BOM elsewhere is `cx-err:CXER0100`
PARSE_ERROR — lexicon §0); whitespace is space / tab / CR / LF and is
non-semantic outside string literals and CX-data subtrees (lexicon §1,
`canonical.md` §2); line comments run `#`…EOL and block comments are `[; … ]`,
while `[# … #]` is raw text / CDATA, NOT a comment (lexicon §1 [L2]/[L3],
`grammar.ebnf` [30]/[31]); the identifier / QName token (lexicon §2 [L10]/[L11])
admits full Unicode name chars and `_`-leading names, with ASCII kebab-case
(`find-stale-orders`, not `findStaleOrders` / `find_stale_orders`) the preferred
*style* for multi-word identifiers.

### §3.5 Reserved tokens

The structural sigils and keywords (`[ ] { } #`, `$`, `@`, `**`, `*`, `/`, `.`,
`?`, `!`, `[? ?]`, `=`, `::`) are defined in `lexicon.ebnf` §8 [L60]-[L63].
The lone `:` has FOUR roles (`lexicon.ebnf` §2 / §11): the atom-literal prefix
`:NAME` (§3.6), the type-guard pattern head `:TypeName` (§5.4), the namespace
qualifier inside a QName (`prefix:local`), and the map-entry separator `{k: v}`.
Directive arguments are clause-child elements (`[clause-head child …]`), scalar
attributes (`name=value`), bareword modifiers (`name`), or positional
ProgramExpr values.

The reserved-NAME vocabulary below is this file's domain (the per-directive
registry in §4.1 is canonical); `lexicon.ebnf` defers to it.

Reserved directive names (the `?` form) — the closed set locked by
§4.1 is exactly the set of rows in the §4.1 registry table below.
That table is the sole normative enumeration; prose lists of
directive names anywhere in this file are illustrative, never
exhaustive. The registry spans the core structural and control-flow
directives, the dynamic-construction family (§6.4.2–§6.4.4), the
iterator combinator family, the resilience family, the concurrency
family, the error-hook / capability / secret family, the
inert-metadata annotation `?meta` (§4.2), and the compile-time
string-interpolation directive `?str`. (`?try` is not in the
registry — removed per §8.8; its former enumeration here was stale.)

Reserved clause-head names (the `[name …]` form inside a directive
body) per the per-directive registry in §4.1: `in`, `where`, `yield`,
`yield-array`, `yield-map`, `order-by`, `group-by`, `limit`, `take`,
`drop`, `takewhile`, `dropwhile`, `on-error`, `par`, `stream`,
`ordered`, `then`, `else`, `case`, `when`, `catch`, `returns`,
`throws`, `using`, `init`, `through`, `recover-with`, `set`, `delete`,
`rename`, `set-attr`, `delete-attr`, `append`, `prepend`,
`insert-before`, `insert-after`, `replace`, `only`, `bind`, `=`
(let-binding and loop-binding clause), `break`, `continue` (`[?loop]`
body tail position, §8.15).

Reserved attribute names (the `name=value` form inside a directive
body) per §4.1: `scope`, `version`, `in-memory`, `lazy`, `max`,
`delay`, `backoff`, `jitter`, `threshold`, `window`, `reset`,
`min-samples`, `per`, `max-concurrent`, `queue`, `direct`, …

Reserved barewords (the `name` form inside a directive body): `pure`,
`impure`, `lazy`, `in-memory`, `mock`, `asc`, `desc`.

User-defined identifiers MUST NOT collide with reserved directive
names, clause-head names, attribute names, or barewords. The
per-directive registry in §4.1 fixes the canonical vocabulary for
each directive.

### §3.6 Atom literals

The atom-literal TOKEN (`:NAME`, the forbidden names `:true` / `:false` /
`:null` raising `cx-err:CXER0100`, and the canonical `:NAME` render — never
`:"NAME"`, never bare `NAME`) is defined in `lexicon.ebnf` §6 [L40]. Atoms are
first-class scalars (`cxdm.md` §2.3) and compare type-strict by byte-identical
name — an atom never equals a string of the same characters (`cxdm.md` §5.1),
and atom hashes carry the atom-type discriminator tag so the atom and string
hash domains are disjoint.

**Parser disambiguation (evaluation-bearing).** The lexer emits `:` and the
identifier as separate tokens; the parser distinguishes an atom literal from
the type-guard pattern head contextually:

| Context | `:NAME` parses as |
|---|---|
| Pattern-head position — first inner token after `[` in pattern context | type-guard pattern head (§5.4) |
| Bare expression position | atom literal |
| Body position inside any element / directive / clause | atom literal |

`:NAME` outside the pattern-head context is always an atom literal. See
`lexicon.ebnf` §6, §4 EBNF [122b], and the parser realisation in
`vcx/code/parser.v`.

---

### §3.7 String literals and escapes (normative)

A program string literal is delimited by single quotes (`'…'`) or
double quotes (`"…"`). The two delimiters are interchangeable; choose
whichever avoids escaping the contained quote. Source is UTF-8 (§3.1),
so any printable Unicode character is written **literally** inside a
string — no escape is needed for non-ASCII text.

**The escape set is closed and uniform** across single-, double-, and program
string literals — it is defined ONCE in `lexicon.ebnf` §5 [L32]. The backslash
introduces exactly one of these sequences, and **no others**:

| Escape | Produces |
|---|---|
| `\\` | backslash `U+005C` |
| `\'` | apostrophe `U+0027` |
| `\"` | quotation mark `U+0022` |
| `\n` | line feed `U+000A` |
| `\r` | carriage return `U+000D` |
| `\t` | tab `U+0009` |
| `\uXXXX` | code point `U+XXXX` (4 hex digits) |
| `\UXXXXXXXX` | code point `U+XXXXXXXX` (8 hex digits) |

An unknown backslash-sequence (`\` + any other character) is **kept literally**
— both the backslash and the character are preserved, so regex patterns such as
`'\d+'`, `'\w'`, `'\s'` survive verbatim. Triple-quoted strings (`'''…'''` /
`"""…"""`) are **verbatim** — no escape processing at all: `\"` inside a triple
literal is the two bytes backslash + quote, not an escaped quote. Because there
is no escape mechanism, a triple literal cannot contain its own three-character
terminator; to embed a literal `"""` use the OTHER delimiter (`'''…"""…'''`).
The canonical-output JSON escaping in `canonical.md` §5 governs *serialization*,
not this *program-source* literal grammar; the CX-text serializer re-escapes a
backslash minimally so a verbatim value round-trips (`canonical.md` §2.4,
bijection invariant `conversions.md` §1).

This is the unified escape surface (lexicon §5 [L32]) — the same decoded set and
the same lenient pass-through across both the data parser (`vcx/cx/parser.v`)
and the program lexer (`vcx/code/lexer.v`).

---

## §4. Grammar

The complete EBNF lives in `grammar.ebnf` (CX code
productions added during implementation). The summary below
shows the language at-a-glance.

```ebnf
expr = literal | binding | path | call | opform | pattern | directive
binding = '$' Ident
path = binding ( '/' Ident | '@' Ident | '.' Ident )*
call = '[' '$' Ident arg* ']' [ '?' | '!' ]   (* head-dispatch; arg = expr | '_' (partial-app hole) *)
        (* built-ins are pre-bound $-names called the same way; there is NO
           paren-call form anywhere — Ident '(' … ')' is a parse error in every
           position, CXPath predicate bodies included *)
opform = '[' op expr* ']' (* closed reserved-operator set, bare head — §6.5 *)
op = '+'|'-'|'*'|'/'|'%'|'='|'!='|'<'|'<='|'>'|'>='|'~'|'and'|'or'|'not'|'cast'|'union'|'intersect'|'except'
pattern = '[' patternHead patternAttrs patternBody? ']'
patternHead = ('**' | '*' | TypeGuard | Ident) [ binding ]
TypeGuard = ':' Ident (* e.g. :User *)
patternAttrs = (patternAttr)*
patternAttr = '@' Ident (* existence *)
 | '@!' Ident (* absence *)
 | '@' Ident '=' expr (* equality *)
 | '@' Ident relop expr (* comparison *)
patternBody = [ 'direct=true' ] (pattern | binding | '**' | '*')*
directive = '[?' DirName child* ']'
child = clause | attribute | bareword | expr (* positional *)
clause = '[' ClauseHead expr* ']' (* named structured arg *)
attribute = AttrName '=' expr (* scalar modifier *)
bareword = AttrName (* no-arg flag *)
literal = StringLit | NumberLit | BoolLit | AtomLit | CxLiteral
AtomLit = ':' Ident ('.' Ident)* (* :NAME / dotted :a.b, §3.6; lexicon [L40] is the sole home *)
CxLiteral = '[' (* CX-data per grammar.ebnf §… *) ']'
relop = '=' | '!=' | '<' | '<=' | '>' | '>='
```

Every directive uses the single `[?DirName child*]`
shape. Per-directive specialisations in §§7–10 + §12 fix the canonical
clause vocabulary and attribute set for each directive.

**No infix operators (homoiconic invariant).** Every form is `[head …]`. The
infix pipe `|` is **retired** (it had no CX⇄XML image); the canonical and only
pipeline surface is the prefix `[?pipe seed STAGE …]` (§8.9), with bare stages and
no `[through]` wrapper.

### §4.1 Directive registry

The set of normative directives is fixed by the following
registry. The complete EBNF in
`grammar.ebnf` enumerates the same set under
the `DirName` production. Gate 2 (§11.4.1) and gate 3 enforce
set-equality between this registry, the EBNF, and the directives
specified in §§5–10.

Adding or removing a directive requires a governance amendment per
`../process/governance.md`.

| Directive | Specified in | Category |
|---|---|---|
| `[?match]` | §5.2, §8.2 | Core — pattern dispatch (single-arm + multi-arm) |
| `[?modify]` | §8.10 | Core — pure-functional update |
| `[?with-open]` | §8.10.7 | Core — scoped-resource RAII |
| `[?with-scope]` | §8.10.8 | Core — dynamic-scoped context |
| `[?str]` | §8.12 | Core — compile-time string interpolation |
| `[?element]` | §6.4.2 | Core — computed-name element construction |
| `[?attr]` | §6.4.2 | Core — computed-name attribute (attr position only) |
| `[?entry]` | §6.4.2 | Core — computed-key map entry (inside `{…}` only) |
| `[?name]` | §6.4.2 | Core — shared name sub-form (`set-attr`/`rename`) |
| `[?quote]` | §6.4.3 | Core — quasiquote (eager; two-color hygiene) |
| `[?unquote]` | §6.4.3 | Core — quasiquote hole (single value) |
| `[?splice]` | §6.4.3 | Core — quasiquote hole (sequence graft) |
| `[?eval]` | §6.4.4 | Core — tree-eval (reuses `cx:eval` sandbox) |
| `[?for]` | §7 | Core — for-comprehension (Sequence outer; D15) |
| `[?for-array]` | §7 | Core — for-comprehension (Array outer; D15) |
| `[?for-map]` | §7 | Core — for-comprehension (Map outer; D15) |
| `[?let]` | §8 | Core — local binding |
| `[?fn]` | §8 | Core — function literal |
| `[?def]` | §12.2 | Module — module-level function |
| `[?lib]` | §12.1 | Module — module import |
| `[?const]` | §12.3 | Module — module-level constant |
| `[?if]` | §8 | Core — conditional |
| `[?else]` | §8.13 | Core — value-or-default coalesce (`getOrElse`; on err + absence) |
| `[?do]` | §8.14 | Core — evaluate-for-effect sequencing (values discarded; first `[err]` propagates; yields `null`) |
| `[?loop]` | §8.15 | Core — condition-driven loop; `[break]`/`[continue]` clause-heads, all-explicit exits |
| `[?pipe]` | §6.4, §8.9 | Core — pipeline (prefix-only; bare stages; `[tap]`) |
| `[?map]` | §8 | Core — map (sequential or `[par]`) |
| `[?reduce]` | §8 | Core — reduce / fold (sequential or `[par]`) |
| `[?filter]` | §8 | Iterator stdlib — filter by predicate |
| `[?take]` | §8 | Iterator stdlib — prefix of `count` items |
| `[?drop]` | §8 | Iterator stdlib — suffix after `count` items |
| `[?zip]` | §8 | Iterator stdlib — per-position tuples |
| `[?enumerate]` | §8 | Iterator stdlib — emit `(i, item)` pairs |
| `[?chunks]` | §8 | Iterator stdlib — group by `count` |
| `[?concat]` | §8 | Iterator stdlib — flatten one level across sources |
| `[?chain]` | §8 | Iterator stdlib — alias of `[?concat]` |
| `[?cycle]` | §8 | Iterator stdlib — bounded repeat |
| `[?scan]` | §8 | Iterator stdlib — running-fold prefixes |
| `[?flatten]` | §8 | Iterator stdlib — flatten one level of nesting |
| `[?partition]` | §8 | Iterator stdlib — split by predicate |
| `[?group-by]` | §8 | Iterator stdlib — group by key |
| `[?to-sequence]` | §8 | Force-materialise — Iterator → Sequence |
| `[?to-array]` | §8 | Force-materialise — Iterator → Array |
| `[?to-map]` | §8 | Force-materialise — Iterator-of-pairs → Map |
| `[?view]` | §8 | View opt-in — zero-copy slice intent on one expr |
| `[?views]` | §8 | View opt-in — scoped view flip over a block |
| `[?retry]` | §10.2 | Resilience |
| `[?timeout]` | §10.2 | Resilience |
| `[?circuit-breaker]` | §10.2 | Resilience |
| `[?fallback]` | §10.2 | Resilience |
| `[?rate-limit]` | §10.2 | Resilience |
| `[?bulkhead]` | §10.2 | Resilience |
| `[?http-service]` | §10.3 | Services |
| `[?service-handle]` | §10.3 | Services |
| `[?http-client]` | §10.3 | Clients |
| `[?worker]` | §10.4 | Concurrency |
| `[?worker-handle]` | §10.4 | Concurrency |
| `[?channel]` | §10.4 | Concurrency |
| `[?send]` | §10.4 | Concurrency |
| `[?receive]` | §10.4 | Concurrency |
| `[?try-send]` | §10.4 | Concurrency |
| `[?try-receive]` | §10.4 | Concurrency |
| `[?close]` | §10.4 | Concurrency |
| `[?select]` | §10.4 | Concurrency |
| `[?stop]` | §10.3, §10.4 | Lifecycle |
| `[?wait-for]` | §10.3, §10.4 | Lifecycle |
| `[?async]` | §10.5 | Async |
| `[?await]` | §10.5 | Async |
| `[?await-all]` | §10.5 | Async |
| `[?await-any]` | §10.5 | Async |
| `[?await-race]` | §10.5 | Async |
| `[?cancel]` | §10.5 | Async |
| `[?check-cancel]` | §10.5 | Async |
| `[?sleep]` | §10.5 | Async |
| `[?with-error-hook]` | §9.6 | Core — error observe / enrich / report hook |
| `[?with-caps]` | `security.md` §3 | Core — capability narrowing (deny-only) |
| `[?secret]` | `cxdm.md` §12 | Core — mark a value secret (redacted at boundaries) |
| `[?reveal]` | `cxdm.md` §12 | Core — declassify a secret (gated by `secret-reveal`) |
| `[?meta]` | §4.2 | Core — inert metadata annotation on a value |

Any `[?<name>` whose `<name>` is not in this registry **MUST** raise
`cx-err:CXER0100` (PARSE_ERROR) at parse time. The complete set is
mirrored in `grammar.ebnf [127e]` ProgramDirName; gate 2 enforces
set-equality between this registry and the EBNF production.

### §4.2 Inert value annotations — `[?meta]` / `meta-of`

`[?meta {KEY: VALUE, …} FORM]` attaches an **inert metadata map** to the
value produced by `FORM`. The model is Clojure metadata: the annotation is
a side-band on the value, not part of its identity.

```
[?meta {visibility: :public, since: "0.8.0"} [api …]]
```

- **Inert.** `[?meta {…} FORM]` evaluates `FORM` and returns its value
  **unchanged** — zero runtime effect. Arithmetic, comparison, truthiness,
  pattern matching, and rendering all read **through** the annotation, so
  `[?meta {…} V]` behaves exactly as `V`. Only `meta-of` (below) and the
  XML serializer observe the map.
- **Annotation is a map.** The first argument MUST be a `{…}` map literal
  (any keys; values are arbitrary CX data — atoms make natural flag
  values). A non-map first argument is `cx-err:CXER0100`.
- **Attached to the value.** The map rides with the value through bindings,
  returns, and serialization, and is reflectable on **any** value (scalar,
  element, collection) — not just definitions.
- **Ignored by equality.** Two values that differ ONLY in their metadata
  are `=` (metadata is not identity-participating), keeping the
  hashing / bijection model unchanged.
- **Stacking merges, last(outer)-wins.** Multiple `[?meta]` wraps on one
  form merge into a single flat map; on a key collision the outer
  (later-applied) wrap wins. Wraps never nest.

**Reflection — `[meta-of EXPR]`.** A reserved built-in (bareword head, no
sigil) that evaluates `EXPR` and returns its attached metadata map, or the
empty map `{}` when `EXPR` carries no metadata. It is not a CXPath axis;
composes like any expression. A user binding / closure named `meta-of`
shadows the builtin (homoiconic).

**Serialization.** A `[?meta]`-annotated value serializes to XML losslessly
via a reserved `<cx:meta>` element (see [`conversions.md`](conversions.md));
formats with no native annotation (JSON / YAML / TOML / MD) drop it and
serialize the inner value.

---

## §5. Patterns

A pattern is a literal CX subtree extended with binding holes
(`$name`), wildcards (`*`, `**`), type guards (`:TypeName`), and the
`direct=true` modifier. Pattern matching evaluates a pattern against
a candidate CX value, succeeds or fails, and on success produces a
set of binding-to-value mappings.

### §5.1 Pattern grammar (reference)

Per §4 EBNF. A pattern matches the structural shape of a CX element
or value; it MUST NOT contain runtime expressions in name or
structure positions. Attribute-value comparisons (`@attr=expr`) and
`[where …]` clauses (in `[?for]`) MAY contain arbitrary expressions
including function calls.

### §5.2 Matching semantics

Pattern matching is structural. Given a pattern `P` and a candidate
value `V`, matching proceeds by case:

1. **Element name.** If `P`'s head is a literal name `N`, `V` MUST
 be an element with name `N`; otherwise match fails.
2. **Wildcard `*`.** Matches any single element regardless of name.
3. **Recursive wildcard `**`.** Matches any element at this position
 or deeper inside the candidate. To search the document for an
 arbitrary-depth match, use a CXPath `//pattern` path value (§5.5)
 or a `[?for]` pattern-generator over a `//` path (§7.5).
4. **Type guard `:TypeName`.** `V` MUST be an element whose schema
 type is `TypeName` (per `schema.md` §… type
 resolution); otherwise match fails.
5. **Binding `$x` (body position).** Always succeeds at this position;
 the binding's value depends on whether the surrounding pattern
 carries **attribute predicates**:

 - **With attribute predicates** — `[NAME @attr… $x]` — `$x` binds
 to the matched element. The attributes are the filter, the
 binding is "what I just selected", and the caller may want to
 navigate further on the result (read other attrs, walk children).

 - **Without attribute predicates** — `[NAME $x]` — `$x` auto-
 unwraps the body of the matched element:
 - empty body → the matched element itself (no value
 to unwrap; e.g. `[item $i]` against `[item]` binds
 `$i = [item]`)
 - single text body → that text as a string scalar
 (e.g. `[name $n]` against `[name Alice]` binds `$n = "Alice"`)
 - single scalar body → the scalar value (preserving type)
 (e.g. `[price $p]` against `[price 12]` binds `$p = 12 : int`)
 - structured body → the matched element itself
 (e.g. `[user $u]` against `[user [name Alice]]` binds
 `$u` to the whole `[user …]` element)

 This matches the natural reading: when a pattern names an
 attribute-filtered element, `$bind` is the element. When a pattern
 names a value-wrapping element with no attribute filter, `$bind`
 is the value.

 To force whole-element capture regardless of attrs/body shape, use
 a wildcard child binding: `[NAME * $x]` — the wildcard absorbs
 the body and `$x` binds the element. Or use the head-bind form
 `[NAME$x]` (no space; see §5.1) where supported by the parser.

 Worked examples:

 ```cx
 # text-body element → binding captures value
 [?for [name $n] [yield $n]]
 # matched against [name Alice] → $n = "Alice"; yields "Alice"

 # structured-body element → binding captures element
 [?for [user $u] [yield $u]]
 # matched against [user [name Alice]] → $u = [user [name Alice]];
 # yields the whole element

 # multi-binding into a clean record
 [?for [user [name $n] [email $e]] [yield [pair name=$n email=$e]]]
 # matched against [user [name Alice] [email a@x.com]]
 # → $n = "Alice", $e = "a@x.com"
 # → yields [pair name='Alice' email='a@x.com']
 ```
6. **Attribute tests.** Each `@attr*` clause in the pattern MUST be
 satisfied by the candidate's attributes:
 - `@attr` — attribute exists
 - `@!attr` — attribute does not exist
 - `@attr=expr` — attribute value equals `expr` (after expr
 evaluation in current scope)
 - `@attr relop expr` — attribute value satisfies the comparison
7. **Body children.** Body children in the pattern MUST appear in the
 candidate's body in the same relative order. Other children MAY
 appear between them. The `direct=true` modifier (§5.3) tightens
 this to "no intervening children."
8. **Scalar literal patterns.** In a `[case …]` arm of `[?match]`, a
 pattern that is a scalar literal (int, float, string, bool, null,
 date, datetime, **atom** per)
 matches iff the candidate value has the same kind AND same canonical
 representation. No coercion: `[case 200 …]` does not match `"200"`,
 and `[case :ok …]` does not match `"ok"`. Use
 `[case _ [where [eq [$to-int $v] 200]] …]` for coerced match. Atom patterns are surface `:NAME` per §3.6 below.
9. **Plain attributes (non-`@`).** A plain attribute clause `attr=VALUE`
 in a pattern (no leading `@`) is a **structural-equality test** on the
 candidate's attribute named `attr`: the candidate MUST carry an
 attribute `attr` whose value is structurally equal to `VALUE` (same
 kind and same canonical representation, no coercion — consistent with
 element equality and with the scalar-literal rule 8). This is the
 pattern-position dual of the `attr=VALUE` element-construction surface
 (§6.4.1): the same surface that *builds* `[user id=1]` also *matches* it.
 So `[user id=1]` matches a candidate `[user id=1]` and fails against
 `[user id=2]`. The leading-`@` forms (rule 6) remain the way to express
 existence (`@attr`), absence (`@!attr`), expression-valued comparison
 (`@attr=expr`), and relational predicates (`@attr relop expr`); a plain
 `attr=VALUE` is shorthand for the equality case against a structural
 literal `VALUE`.
10. **Attribute / map value-capture.** `@attr=$x` binds the matched attribute's
 value to `$x` (`[err @code=$c]` captures the err's code); `{key: $x}` binds a
 map value (`{role: $r}` captures the role). Combined with a type-test it is
 `@attr=$x::T` (capture-and-test, rule 14). This complements rule 6 (predicate,
 comparison only) and rule 9 (equality, literal only) — neither of which
 *captures*.
11. **Map literal & map rest.** `{k: v}` matches a candidate Map structurally
 (rule 9 equality on each pair). Map patterns are **open (subset)**: `{role: $r}`
 matches any Map carrying ≥ that key. A **rest** `{k: v, *$rest}` binds the
 unmatched pairs as a **Map** (name→value). Match is **by key (unordered)**;
 duplicate keys are n/a (`cxdm.md` forbids them).
12. **Sequence literal & spread.** `(a, b, c)` matches a Sequence **closed**
 (exactly that arity). A **rest** `(a, *$rest)` binds the remaining items as a
 **Sequence** (`*` only — **not** `**`, which is the element/Document descendant
 marker). Match is **positional**.
13. **Array literal & spread.** `[1, $x, 3]` matches an Array structurally
 (closed); `[1, *$rest]` binds the remaining items as an **Array**. Array literal
 patterns are disambiguated from the `[head …]` element-pattern surface by the
 comma-separated item form (an array pattern has `,`-separated items and no head
 name). Match is **positional**.
14. **Type-kind test `::T`.** `$name::T` is a **typed bind** (binds the value and
 tests its CXDM value-kind is `T`); `_::T` is the **anonymous** test (tests, binds
 nothing). `T` ranges over the full `KindName` set (§12.7) — scalar kinds
 (`int`/`float`/`bool`/`string`/`date`/`datetime`/`bytes`/`null`/`atom`),
 `element`/`document`/`text`/`scalar-node`/`comment`/`pi`/`directive`, `array`,
 `sequence`, `map`, `path`, `iterator`. **No atom collision:** atoms are
 single-colon (`:int` is the atom), type-kind tags are double-colon glued
 (`::int`). This is **distinct from** the single-colon `:TypeName` schema-type
 guard (rule 4), which tests an element's **schema type**; `::T` tests the
 **value kind**. Attribute-position type-test: `@name::T` tests the attr value's
 kind; `@name=$x::T` captures-and-tests.

#### §5.2.1 Applicability Matrix (the `UNIFORM` gate — normative)

Rows are the CXDM `Item` taxonomy (`cxdm.md` §2) plus the attribute sub-domain
(attributes are accessed via the `@name` axis, `cxdm.md` §2.4 — a sub-row of
Element, not a first-class Item). Every cell is ✅ (covered), ❌ (a defect if
unjustified), or — (n/a, genuinely meaningless). Every non-✅ cell carries a
written rationale.

| row | literal pat | `$bind` | `_` wildcard | spread / partial | type-test (`::T`) |
|---|---|---|---|---|---|
| **Scalar** — bool/int/float/string/date/datetime/bytes/null/atom | ✅ | ✅ | ✅ | — *(no members)* | ✅ `$n::int` / `_::float` |
| **Element** (Node) — tag + children | ✅ | ✅ | ✅ | ✅ `*`/`**` children | ✅ |
| ↳ Element **attributes** (`@a=v` / plain `a=v`) | ✅ | ✅ `@a=$c` (capture) | ✅ | ✅ `@*$rest` | ✅ `@a::T` |
| **Other Nodes** — Text/ScalarNode/Comment/PI/Directive | — *(no literal head; via `$c::comment` typed-bind)* | ✅ | ✅ | — *(leaf)* | ✅ `_::text` |
| **Document** (Node) — has children | ✅ | ✅ | ✅ | ✅ `*`/`**` | ✅ `_::document` |
| **Array** `[a,b,c]` | ✅ `[1,$x,3]` | ✅ | ✅ | ✅ `[1, *$r]` | ✅ `_::array` |
| **Map** `{k: v}` | ✅ | ✅ `{k: $x}` (capture) | ✅ | ✅ `{k:v, *$rest}` | ✅ `_::map` |
| **Sequence** `(a,b,c)` | ✅ | ✅ | ✅ | ✅ `(1, *$r)` (`*` only) | ✅ `_::sequence` |
| **Sequence-as-Item** (boxed) | ✅ *(matches the boxed item; does NOT unbox)* | ✅ | ✅ | — *(opaque box; unbox first)* | ✅ `::sequence` |
| **Path** | n/a *(non-match; realize first)* | ✅ | ✅ | n/a *(non-match)* | ✅ `::path` |
| **Iterator** | n/a *(non-match; realize first)* | ✅ | ✅ | n/a *(non-match)* | ✅ `::iterator` |

**Non-✅ cells (documented exceptions, not holes):**
- **`—` spread, 3 cells:** a **Scalar**, an **Other-Node leaf**, or a boxed
  **Sequence-as-Item** has no item-children to spread (a boxed sequence is opaque
  — unbox it first). Genuinely meaningless.
- **Path / Iterator literal & spread = NON-MATCH, not an error.** A structural
  (array/sequence) pattern against a Path or Iterator **does not match** — it
  **falls through to `[else]`**; it is **not** a raised `cx-err` (pattern
  *kind*-mismatch is the universal non-match rule). To destructure their contents,
  **realize first** (`items($iter)` → Array; evaluate a Path → Sequence). `$bind`,
  `_`, and `::T` stay ✅.
- **Other-Node structural-literal:** Text/ScalarNode/Comment/PI/Directive have no
  natural literal-head pattern surface; matched by a **typed bind** `$c::comment`
  (binds the node *and* tests its kind).

**Sequence-as-Item does NOT unbox on match.** `cxdm.md` §2.7 preserves a boxed
Sequence-as-Item's nesting; the pattern matches the **boxed item as a unit**
(`::sequence` type-tests it). To match its contents, unbox first.

#### §5.2.2 Pinned pattern semantics (normative defaults)

| Question | Default | Rationale |
|---|---|---|
| Sequence / Array open vs closed | **Closed** — `(1,2,3)`/`[1,2,3]` match exactly that arity | positional/ordered data; exact length least-surprising |
| Map / attributes open vs closed | **Open (subset)** — `{role:$r}` matches any map with ≥ that key | keyed & extensible |
| Rest `*$rest` — sequence | binds remaining as a **Sequence** | preserves the matched kind |
| Rest `*$rest` — array | binds remaining as an **Array** | preserves the matched kind |
| Rest `*$rest` — map / attributes | binds unmatched pairs as a **Map** | keyed leftovers are a keyed value |
| Rest surface | map `{k:v, *$rest}`; attrs `[NAME @a=v @*$rest]`; seq/array `(a, *$rest)` / `[a, *$rest]` | one rest-marker per kind; `**` is element/Document descendant only |
| Ordering | sequence/array **positional**; map/attributes **by key (unordered)** | mirrors each kind's equality (`cxdm.md` §5) |
| Duplicate keys | **n/a** — `cxdm.md` forbids duplicate Map keys / attr names | the data model guarantees uniqueness |
| `**` vs `*` | `*` = this level's tail; `**` = descendant (element/Document only) | reuses the admitted element-child `*`/`**` distinction |

If all clauses succeed, the match yields the union of all bindings.
If any clause fails, the match fails and no bindings are produced.

### §5.3 The `direct=true` modifier

`direct=true` appears as an attribute at the start of a pattern body.
It requires that the body children in the pattern appear as direct,
consecutive children in the candidate body, with no intervening
siblings.

```cx
[* direct=true [h2 $h] [p $p]] # h2 immediately followed by p
[* [h2 $h] [p $p]] # h2 then p somewhere, gaps OK
```

The `direct=true` attribute applies only to the immediate enclosing
pattern body. To require consecutive children at a deeper level, the
inner pattern carries its own `direct=true`.

### §5.4 Type guards

A type guard `:TypeName` at the head of a pattern restricts the match
to elements whose schema type is `TypeName`. Type resolution follows
`schema.md` §… inheritance rules. If no schema is
in scope, type guards MUST raise `cx-err:CXER0100` (PARSE_ERROR) at
program load time.

### §5.5 CXPath — path value kind

Selection and pattern-generator iteration both express through
CXPath path values and the `[?for]` directive:

| Form | Notes |
|---|---|
| `//user` | Path value — evaluates to matching nodes |
| `[?for [user $u] [yield $u]]` | Pattern-generator form (§7.5) |
| `//user[= $_@active true]` | Predicate in path |
| `[?for [user [email $e]] [yield $e]]` | Nested pattern |

A **Path** is a first-class value kind (sixth kind per `cxdm.md` §2.8).
`//user[= $_@active true]` parses to `cx.PathNode { steps: […] }`. Evaluation
produces a `Sequence` of matching nodes. Round-trips in canonical emit as
the terse `//` form. Grammar: `grammar.ebnf` [130]–[131], [135], [159].

#### §5.5.1 CXPath semantics and desugar table

| Path form | Equivalent `[?for]` | Notes |
|---|---|---|
| `//name` | `[?for [name $n] [yield $n]]` | Descendant element by name |
| `//name[= $_@a v]` | `[?for [name @a=v $n] [yield $n]]` | With attribute predicate |
| `//name/child` | `[?for [name [child $c]] [yield $c]]` | Child step |
| `[$count //name]` | `[$count [?for [name $n] [yield $n]]]` | Aggregation |
| `//name` in `[?if]` | truthy iff sequence non-empty | EBV per `cxdm.md` §6 |

CXPath aligns with XPath 3.1 on path syntax (axes, name tests,
predicates) and intentionally diverges on data-model fundamentals
(sequence-flat per `cxdm.md`, no namespace inheritance assumptions,
no XML-typed-value layer). Divergences are noted at the production
that introduces each construct.

#### §5.5.2 Predicate evaluation

A CXPath predicate `[expr]` is the **general-predicate form** The body
`expr` is any CX expression coerced via EBV (`cxdm.md` §6).
Three reserved bindings are in scope inside every predicate body:

| Binding | Value | Type |
|---|---|---|
| `$_` | the current candidate item | any item kind |
| `$_position` | 1-based index of the candidate within the candidate sequence | `int` |
| `$_last` | size of the candidate sequence | `int` |

**Evaluation order (normative).** For an N-item candidate sequence
the runtime materialises the sequence eagerly, then for each
candidate `c_i` (i = 1..N):

1. Bind `$_` to `c_i`.
2. Bind `$_position` to `i`.
3. Bind `$_last` to `N`.
4. Evaluate the predicate body to a CX value `r`.
5. Compute `EBV(r)`.
6. Keep `c_i` in the output iff `EBV(r) = true`.

**Homoiconic predicate bodies — the XPath-parity sublanguage is
retired.** A predicate body is CX code. The former parse-time sugar —
infix comparisons (`@a=v` and `!=`/`<`/`<=`/`>`/`>=`), paren function
calls (`count(*)`, `contains(...)`), infix `and`/`or`, `instance of` /
`cast as`, infix `union`/`intersect`/`except`, and `||` — is a parse
error (`cx-err:CXER0100`) inside predicate bodies exactly as at every
other expression position. No tombstone, no dual-accept (grammar.ebnf
[132]–[134] retirement note). Built-ins are invoked head-dispatch
(`[$count $_/*]`, `[$contains $_@name "x"]`); the set operators are
the reserved prefix heads `[union A B]` / `[intersect A B]` /
`[except A B]` (§6.5), valid in every expression position; `||` is
the `[$concat …]` builtin.

**Fused brackets.** When the body is a form, the predicate's own
brackets serve as the form's brackets — one bracket pair, never
`[[…]]` (grammar [159a]/[159b]). An operator form fuses as
`//user[= $_@id 991]`; a head-dispatch call fuses as
`//user[$flagged $_]`; a directive fuses as `//user[?match $_ …]`.
Nested subexpressions inside a fused body are ordinary
fully-bracketed forms:

```cx
//order[and [= $_@status :open] [> $_@total 100]]
```

**Notation atoms.** Four operator-free atoms are path notation with
defined semantics — NOT rewrite sugar; the renderer never converts
between an atom and its general-form equivalent in either direction:

| Atom | Keeps the candidate iff |
|---|---|
| `[N]` (positive integer literal) | `$_position` = N |
| `[@name]` | `[$exists $_@name]` |
| `[@!name]` | `[not [$exists $_@name]]` |
| `[name]` / `[axis::name]` | `[$exists $_/name]` / `[$exists $_/axis::name]` |

The canonical renderer emits every predicate exactly as written.

**Scope rule.** `$_` rebinds at every enclosing PredicateExpr per
standard lexical scoping; the innermost predicate's `$_` shadows
every outer. `$_position` / `$_last` likewise rebind. References
to `$_position` / `$_last` **outside** a predicate body raise
`cx-err:CXER0231` (E_RESERVED_BINDING_USE) at parse / module-load.

**Step-scoped named binding `(bind …)`.** A path step may carry an
optional `(bind $NAME)` parenthesised postfix annotation between its
NodeTest and any trailing predicates (grammar [160], ).
The step's focus is bound under `$NAME`, visible in every predicate
enclosed by the step and in every subsequent step of the same
PathExpr. `(bind $_)` is rejected with `CXER0232`
(E_RESERVED_BIND_NAME). Worked example:

```cx
//team (bind $t) / member[and [= $_@role "lead"] [>= [$count $t/member] 3]]
```

**Purity.** Every PredicateExpr body MUST be **pure**.
A body containing a call to a function annotated `impure` (.5.x below)
is rejected at parse / module-load with `cx-err:CXER0230`
(E_PREDICATE_NOT_PURE). The check is sound: every accepted
predicate is provably pure under the purity-inference rules.

### §5.6 Examples (informative, fixtures in conformance/code.txt)

```cx
# path value — all active users' emails
[?for [user @active=true [email $e]] [yield $e]]

# path value in aggregation
[$count //user[= $_@active true]]

# path value in [?if] truthiness gate
[?if //admin [then [admin-panel]] [else []]]

# name+email pairs using [?for] pattern-generator
[?for [user [name $n] [email $e]]
 [yield [pair name=$n email=$e]]]

# adjacency (next sibling) — direct=true modifier
[?for [* direct=true [h2 $_] [p $p]] [yield $p]]
```

---

## §6. Bindings, paths, function calls

### §6.1 Bindings

A binding is `$name` where `name` is an identifier per `lexicon.ebnf` §2.
Bindings are introduced by:

- Pattern matches (§5)
- For-comprehension generators (`[in $x SRC]` — §7)
- Let-bindings (`[?let [= $x EXPR] BODY]` — §8)
- Function parameters (§6.3)

Bindings are lexically scoped to the directive that introduces them.
A binding MUST NOT be referenced outside its enclosing directive.
Rebinding the same name inside an inner scope shadows the outer
binding (no error).

### §6.2 Path access

Bindings support full CXPath step syntax (grammar [135]):

| Syntax | Meaning |
|---|---|
| `$x/name` | Direct child element named `name` |
| `$x/*` | All direct children |
| `$x//name` | Descendant element named `name` |
| `$x/..` | Parent of the current focus |
| `$x/axis::name` | Explicit axis traversal (any axis from [131a]) |
| `$x/name[pred]` | Child filtered by predicate |
| `$x/name[pred]/more` | Chained path after predicate |
| `$x@attr` | Attribute named `attr` (typed value — `cxdm.md` §2.4) |
| `$x.key` | Map-key access (when `$x` is a decoded map) |

Paths chain left-to-right:

```cx
$user/profile/name # child of child
$user/* # all children
$user//email # any descendant named 'email'
$node/ancestor::section # ancestor axis
$h2/following-sibling::p # following-sibling axis
$order@total # attribute
$config.database.host # map-key access into nested map
```

**Terminal labeled-field unwrap.** A *simple field accessor* —
a binding path whose every step is a plain `/name` child step with no
predicate, resolving to a single focus — auto-unwraps its final step when
that step selects exactly one child holding a single item: the read yields
that inner value rather than the wrapping element. So for
`[result [value 42] …]`, `$r/value` reads `42` (not `[value 42]`). This is
the read counterpart of the simplest-adequate field model (a labeled field
is a plain child; reading it returns its content), and it is **uniform
over content kinds**: the inner value may itself be an element — for
`[box [life [evidence …]]]`, `$b/life` reads the `[evidence …]` element.
This is the platform's field-read idiom (`$response/body`,
`$r/next-generator`, `$task/status`, …) and is load-bearing throughout the
standard library. Node-set queries — any path with a predicate, a
descendant/wildcard/parent axis, or multiple matching children
(`$doc/user[= $_@active true]/name`) — are unaffected and return elements
per the table above.

**Composition with aggregation (normative — owner ruling 2026-07-23,
#584).** Because a simple field accessor yields the field's *content*,
aggregating over it aggregates the content: `[$count $x/field]` over a
field holding one element reports **that element's own arity** (3 for the
`[life [evidence [id…] [kind…] [val…]]]` example above), 0 for an empty
field, and N for an N-item field. This is the deliberate consequence of
the field model, not a defect — a field read answers "what is in the
field", never "how many children matched". Code that wants
**match-counting** must use a node-set form, which never unwraps: the
descendant axis (`[$count $b//life]` = 1), a wildcard read over the parent
(`[$count $b/*]` = 1), or a predicate step. Aggregation-sensitive folds
that accumulate element-valued records (the receive→fold pattern) should
count matches, not field contents.

**Terminal attribute unwrap.** The same simple-field-accessor rule extends
to a path whose prefix is a pure `/name` child chain (no predicates) and
whose final step is an attribute step `@attr`: when it resolves to a single
focus carrying a single matching attribute, the read yields the attribute's
**typed value scalar** per the `$x@attr` table entry (`cxdm.md` §2.4: the
`@name` axis produces the attribute's typed value — an atom-typed attribute
reads back as the atom, `kind=:active` → `:active`, never the string
`'active'`, since atoms and strings never coerce, `cxdm.md` §5.1) — so for
`[users [user name=Alice]]`, `$doc/user@name` reads `Alice` (not the
node `[name "Alice"]`). Node-set attribute queries — any predicate step, or
multiple matching foci (`$doc/item/@q`) — instead return the attribute axis
materialized as `[attr "value"]` element nodes, one per match.

**Step distribution over a sequence (normative, O4).** A navigation step
(`/name`, `/@attr`, `//name`, a predicate, an axis) applied to a **sequence of
elements distributes over its members** — it does not ask the sequence itself for
the step (the XPath node-set model CXPath borrows). So `$seq/@x` over
`([a x=1], [a x=2])` yields `(1, 2)`, not a `no attribute "x"` error. This is the
§9.1.2 / orthogonality rule in the path engine: a step that works on one element
works on a sequence of elements. Distribution semantics:

| Input to `$s/@x` | Result | Channel |
|---|---|---|
| empty sequence `()` | `()` | **absence in → absence out** (inert) |
| `([a x=1], [a x=2])` | `(1, 2)` | value; document/sequence **order preserved** |
| a member missing `@x` (`([a x=1], [a])`) | `(1)` — that member contributes nothing | optional read; **no `[err]`, no `null` stand-in** |
| a non-element member (`([a x=1], 'str')`) | `(1)` — non-elements have no attrs, skip | optional read; not a fault (node-set model) |
| all members lack `@x` | `()` | collapses to **absence**, consistent with row 1 |

The default `/@x` is an **optional** read (absence-yielding, never crashing — the
§9.1.2.1 null-totality posture). Result length MAY be **less than** input length;
that is the optional-read contract, not data loss. A *required* read (missing ⇒
`[err]`) would be a distinct, explicitly-marked operator (out of scope here, noted
so the absence/failure line stays clean). Scoped to read/navigation steps;
predicates/axes follow the same node-set rule.

**Navigating an err value does NOT propagate the err (normative — loud
callout).** Path navigation is the sanctioned err-*inspection* lane (the
errors-as-data-vs-control-flow boundary, "Errors are values, uniformly"):
`$e@code`, `$e/@message`, `$e/cause`, `$e/errors` read the err's own
structure, so a bound err behaves as the data element it is. The flip side
is deliberate and worth stating loudly: a query that does not match the
err's own shape — `$doc//row` when `$doc` holds a failed `[$cx:parse]`
result — yields the **empty node-set**, exactly as it would over any other
element with no matching descendants. A program that binds a fallible
producer to `$doc` and only ever runs content queries over it will read a
parse failure as "successfully empty". Guard the *binding*, not the query:
test the producer with `[?match]` / `[?else]` / `[?fallback]` at the bind
site (or propagate with postfix `?` on the producing call) before
navigating. This is not silent error swallowing — it is the documented
inspection boundary; the err is still the bound value and still reports
itself anywhere it is used as an operand.

Grammar: `grammar.ebnf` [135] BindingPath.

### §6.3 Function calls

The canonical CX call form is the head-dispatch element `[$fn args…]`: a `$`-bound name in head position applies the bound value
to the positional arguments.

```cx
[$to-card $u]
[$filter $users [?fn ($u) $u@active]]
[$sum 1 2 3]
```

Postfix `?` (§9.2) propagates errors; postfix `!` (§9.2) panics on
errors:

```cx
[$parse $input]? # propagate err
[$load-config]! # panic on err
```

The CX function-call surface is exclusively `[$fn args]` — the
homoiconic head-dispatch form, at every expression position
**including CXPath predicate bodies**. The paren-call form
`name(args)` does not exist anywhere in the language: the former
XPath-syntactic-parity carve-out (`count(*)`, `last()`, `position()`,
`contains(...)` inside predicates) is retired, and a paren-call is a
parse error (`cx-err:CXER0100`). The XPath positional functions are
subsumed by the reserved predicate bindings `$_position` / `$_last`
(§5.5.2) and the head-dispatch built-ins (`[$count $_/*]`,
`[$contains $s $sub]`).

### §6.3a Partial application — argument holes

A bare `_` hole in a head-dispatch call argument position defers that
argument: the call yields a **function value** awaiting the held
positions, which a later application fills left-to-right.

```cx
[= $add5 [$add 5 _]]   # partial: first arg fixed, second held
[$add5 10]             # → [$add 5 10] → 15
[= $p [$f _ _ 3]]      # two leading holes, third arg fixed
[$p 1 2]               # → [$f 1 2 3]
```

Rules (one each):
- A hole binds only to a declared **positional** parameter; a `_` in a
  **rest** (`*$xs`, grammar [153e]) position is a static error
  `cx-err:CXER0102` (E_PARTIAL_APP).
- Applying a partial supplies the held positions in order; supplying
  more arguments than held positions is `cx-err:CXER0102`.
- `_` is a hole **only** in head-dispatch argument position; the hole
  is the bare token `_`, distinct from the reserved context binding
  `$_` (which is never written as a bare `_`).

`_` holes use the homoiconic `[$fn …]` surface — the only
function-call surface (§6.3); there is no paren-call form anywhere
in the language.

### §6.4 Pipelines

A pipeline threads a value through a sequence of bare transform stages using the
prefix `[?pipe …]` directive (§8.9):

```cx
[?pipe $users filter-active to-cards sort-by-name]
```

Each bare stage receives the threaded value (appended as its final positional
argument, or filling a `_` hole; §8.9.1). There is **no infix `|`** (retired) and
**no `[through]` wrapper** (dropped): `[?pipe]` is the canonical and only
pipeline surface.

### §6.4.1 Element construction

A CX program may construct a CX element literal in any expression
position. The shape mirrors CX data, with one homoiconic extension for
a **computed** (dynamic) element name:

```
[NAME attr=VALUE … POSITIONAL_ITEM …]
[?element NAME-EXPR attr=VALUE … POSITIONAL_ITEM …] # computed name
```

- `NAME` is a literal identifier (the element name) — the static
 form.
- `[?element NAME-EXPR …]` is the **computed-name** form (§6.4.2): it
 evaluates `NAME-EXPR` at construction time and coerces the result to
 the element name (name-coercion rule, §6.4.2.1). Its body grammar is
 **identical** to the static `[NAME …]` element body (attributes
 interleaved with positional items). The retired paren micro-syntax
 `(:atom EXPR)` is **removed** — `[?element …]` is the sole computed-name
 surface; a leading `(:atom …)` in head position is now a parse error.
- `attr=VALUE` — element-construction attribute. `VALUE` is any
 expression (binding, literal, paren-grouped expression, builtin
 call). Attributes are scalar-only (D2; `lexicon.ebnf` §10): at
 evaluation time `VALUE` MUST reduce to a scalar — a non-string scalar
 is rendered via the canonical scalar printer, but a NON-SCALAR result
 (element / array / map / sequence) raises `cx-err:CXER0100`
 (PARSE_ERROR) rather than being stringified. Rich / nested data is
 expressed as a child element, not an attribute. The element on the
 resulting tree carries one `cx.Attribute` per `attr=VALUE` clause, in
 source order.
- `POSITIONAL_ITEM` — any expression; evaluated and appended to the
 element body in source order. Nested record-shape data is expressed
 as nested child elements (`[user [name 'Alice'] [email 'a@b.com']]`)
 .

The attribute-name token is a bare identifier, parsed via the
ident-then-`=` two-token lookahead. Attribute clauses may be
interleaved with positional items; the result tree groups attrs onto
the element head and items into the body regardless of source order.
(Implementations MAY normalise to attrs-then-body for canonical-form
emission per `canonical.md`.)

The construction surface is the expression-position dual of the
pattern attribute predicate (§5.2 rule 6): patterns filter and bind
on `@attr=expr`; literals construct with `attr=expr`. The leading
`@` is reserved for pattern position; using `@attr=VALUE` in an
expression literal is a parse error (`cx-err:CXER0100`).

Worked examples:

```cx
[?let [= $lang "cx"] [code lang=$lang "hello"]]
# evaluates to:
# [code lang=cx "hello"]

[?for [code @lang=$l @src=$s] [yield [pre [code lang=$l $s]]]]
# pattern binds @lang → $l, @src → $s; literal constructs the
# wrapping [pre [code lang=… $s]] block — the round-trip surface
# used by the doc-gen markdown emitter.
```

### §6.4.2 Symmetric computed names

One uniform mechanism produces a **computed name** in every name
position — element, attribute, map key — plus the `[?modify]` operators.
All `[head …]`; no parens.

```text
[?element NAME-EXPR  attr=VALUE …  ITEM …]   # computed element name
[?attr    NAME-EXPR  VALUE]                   # computed attribute (attr position only)
[?entry   KEY-EXPR   VALUE]                   # computed map entry (inside {…} only)
[?name    NAME-EXPR]                          # shared name sub-form (set-attr / rename)
```

- `[?element …]` body grammar is **identical** to the static `[NAME …]`
  element body (§6.4.1): attributes (`attr=VALUE`) interleaved with
  positional items. It is the dynamic-head element spelled as a directive.
- `[?attr …]` is valid **only** in attribute position; in body position →
  `cx-err:CXER0100`. `[?entry …]` is valid **only** inside a `{…}` map
  literal; elsewhere → `cx-err:CXER0100`. (Mirrors how `@attr=` is reserved
  to pattern position, §6.4.1.)
- `[set-attr [?name KEY-EXPR] VAL]` and `[rename [?name NAME-EXPR]]` — the
  `[?modify]` operators (§8.10) accept `[?name …]` wherever they accept a
  bare `Name`.

#### §6.4.2.1 Name coercion (one rule, all positions)

`NAME-EXPR` / `KEY-EXPR` evaluates and coerces to a name as follows:

- **string or atom** → the name (the atom `:` sigil stripped); must be a
  valid NCName (the same validity the `string → :atom` cast enforces, §6.5
  — rejects `true`/`false`/`null` and non-NCName shapes).
- **empty / `()`** → **absence channel**: the element / attribute / entry is
  **omitted** (`[?attr ()]` → no attribute; `[?element ()]` → `()`). This is
  cognate-correct (absence-in/absence-out). It **diverges** from the retired
  `(:atom)`, which *errored* on an empty name.
- **non-scalar** (element / map / sequence) → **failure**
  `[err code=cx-err:CXER0235]` (E_COMPUTED_NAME_NONSCALAR).
- **scalar that is not a valid NCName** (including a numeric / bool / bytes /
  datetime scalar used where an NCName is required) → **failure**
  `[err code=cx-err:CXER0236]` (E_COMPUTED_NAME_SHAPE). A map key (`[?entry]`)
  is the one position that admits non-NCName scalars (`[56g]` keys on scalars),
  so a non-NCName scalar key is **valid** there.
- For `[rename]` an empty name is **not** absence (an element must have a
  name) → `cx-err:CXER0236`.

Exactly one channel per outcome: valid → value, empty → absence,
non-scalar / bad-shape → failure.

#### §6.4.2.2 XML images (bijective)

```
[?element $n size=large "hi"]
  → <cx:element><cx:name>…$n…</cx:name>
       <cx:attr name="size"><cx:str>large</cx:str></cx:attr>
       <cx:str>hi</cx:str></cx:element>
[?attr  $k $v]  → <cx:attr><cx:name>…$k…</cx:name>…$v…</cx:attr>
[?entry $k $v]  → <cx:entry><cx:key>…$k…</cx:key>…$v…</cx:entry>
[?name  $k]     → <cx:name>…$k…</cx:name>
```

A **static** attribute keeps its current image (`name="size"` as an XML
attribute on `<cx:attr>`); a **computed** attribute uses the `<cx:name>`
child envelope. The presence/absence of the `<cx:name>` child is the
read-back discriminator → lossless round-trip.

### §6.4.3 Quasiquotation over trees

Lisp's `` ` `` / `,` / `,@` rendered homoiconically over CXDM trees.

```cx
[?quote   FORM]     # build FORM's CXDM tree UNEVALUATED, except holes nested within
[?unquote EXPR]     # hole: eval EXPR, graft its single VALUE as one node
[?splice  EXPR]     # hole: eval EXPR to a sequence, graft each item in order
```

- `[?quote FORM]` → FORM-as-data (the literal CXDM tree, unevaluated),
  except `[?unquote …]` / `[?splice …]` holes nested anywhere inside are
  evaluated and grafted.
- `[?unquote EXPR]` → `EXPR` evaluated, its single value replaces the node.
  `()` → the slot is removed (absence). A multi-item sequence in a
  single-node slot → `[err cx-err:CXER0237]` (E_UNQUOTE_SEQUENCE; "use
  `[?splice]`").
- `[?splice EXPR]` → `EXPR` evaluated to a sequence; each item grafted in
  order. `()` splices nothing; a scalar splices as a 1-element sequence.
  Valid only where multiple siblings are admitted (element body, sequence,
  map-entry list); in an attribute-value or name slot → `cx-err:CXER0100`.

Because the §6.4.2 constructors are ordinary tree nodes, building with
`[?quote]`+holes and building imperatively with
`[?element]`/`[?attr]`/`[?entry]` produce the **same tree**.

#### §6.4.3.1 Laziness

`[?quote]` is **eager** at its own evaluation point: holes are evaluated
once, left-to-right, at quote-eval time; a hole's `[err]` propagates
railway-style (§9.2) then. (Rationale: matches CX eager-by-default and
yields a deterministic canonicalization/hash of a quoted result.)

#### §6.4.3.2 Hygiene — the two-color rule

Two scopes exist: the **quote site** (where `[?quote]` lexically appears)
and the **eval site** (where `[?eval]` later runs the tree).

1. **Inside `[?unquote]`/`[?splice]`** (holes): resolved at the **quote
   site**, immediately, when `[?quote]` evaluates. They capture the
   constructor's lexical scope.
2. **A bare `$x` that is part of the quoted FORM** (not in a hole): **inert
   data** — it becomes a `<cx:var>x</cx:var>` node, resolving **only** later,
   if the tree is `[?eval]`'d, against `[?eval]`'s **context map** — never the
   quote site, never ambient eval-site bindings.

No accidental capture in either direction. Capture-avoidance is by the
existing eval sandbox isolation (§6.4.4), not gensym renaming.

#### §6.4.3.3 XML images

```
[?quote F] → <cx:quote>…F…</cx:quote>   [?unquote E] → <cx:unquote>…E…</cx:unquote>
[?splice E] → <cx:splice>…E…</cx:splice>   bare $x in a quote → <cx:var>x</cx:var>
```

### §6.4.4 Tree eval

```text
[?eval TREE]
[?eval TREE [context MAP]]
[?eval TREE [context MAP] [opts {"max-depth": 16}]]
cx:eval-tree($tree::any $context::map=$nil $opts::map=$nil) → any    # impure
```

- Evaluates a CXDM value **as code, with no parse step** → `CXER4100`
  (malformed source) is structurally unreachable: there is no source to
  malform.
- **Sandbox reused wholesale from `cx:eval`** (`modules/cx.md` §3,
  `security.md` §5):
  - **Context isolation** — only `$context` keys are visible; no ambient
    capture (this is what makes the §6.4.3.2 bare-`$x` rule sound).
  - **Capability** — gated by the existing `eval` capability
    (`security.md`); deny-by-default; a denial at an effect point →
    `cx-err:CXER0271`. A `pure` def reaching `[?eval]` / `cx:eval-tree` →
    `cx-err:CXER0233` (it is `impure`, like `cx:eval`).
  - **Module non-widening** — inherits the caller's `[?lib]` set; may narrow,
    not widen → `cx-err:CXER4113`.
  - **Depth cap** — default 8, `opts.max-depth` configurable, exceed →
    `cx-err:CXER4114`. Shares the `cx:eval` recursion counter (one budget
    across string- and tree-eval).
- **Authority of the evaluated tree** is bounded by wrapping it in
  `[?with-caps [deny …] …]` (`security.md`), **not** by the constructor.

#### §6.4.4.1 Tree-eval error model (one channel each)

| Outcome | Channel |
|---|---|
| Evaluated tree returns a value / `()` | value / absence |
| Non-evaluable node shape in position (e.g. a standalone `[?attr]`) | failure `[err cx-err:CXER0238]` (E_TREE_NOT_EVALUABLE) |
| Capability missing at an inner effect point | failure `CXER0271` (railway-propagates out) |
| Depth / lib violation | failure `CXER4114` / `CXER4113` |
| An `[err]` produced *by* the evaluated code | that `[err]`, railway-propagated (§9.2) — `[?eval]` is transparent to inner failures |

Build-then-eval is one expression: `[?eval [?quote …] [context {…}]]` — no
string, no serialization, no re-parse.

#### §6.4.5 Computed-name & tree-eval error codes

New core codes, allocated contiguous after the purity/eval band:

| Code | Name | Channel | Raised by |
|---|---|---|---|
| `CXER0235` | E_COMPUTED_NAME_NONSCALAR | failure | computed name/key expr is non-scalar |
| `CXER0236` | E_COMPUTED_NAME_SHAPE | failure | computed name is not a valid NCName (or empty `[rename]`) |
| `CXER0237` | E_UNQUOTE_SEQUENCE | failure | `[?unquote]` yielded a sequence in a single-node slot |
| `CXER0238` | E_TREE_NOT_EVALUABLE | failure | `[?eval]` — tree node not evaluable as code in its position |

> **Numbering note.** The originating design bundle proposed
> `CXER0234–0237`, but `CXER0234` (E_PURITY_UNCLASSIFIED_BUILTIN, §6.5) is
> already allocated; these four codes shift to the next free contiguous
> block `0235–0238` (band end `0239` stays reserved), preserving the
> intended adjacency to the purity/eval codes.

**Reused (no new code):** `CXER0100` (structural misuse — splice in name/attr
slot, `[?attr]` in body, `[?entry]` outside a map); `CXER0233` (a `pure` def
reaches `[?eval]`/`cx:eval-tree`); `CXER0271` (the `eval` capability is denied
inside the tree); `CXER4113`/`CXER4114` (lib-widen / depth cap — **shared**
with `cx:eval`, same counter). Absence outcomes raise nothing.

#### §6.4.6 Applicability matrix (computed names + quasiquote + tree-eval)

Every ✅ → ≥1 conformance fixture; every — (absence/fall-through) → a
fixture; every ❌ → an error-path fixture.

**Computed names/keys:**

| Position \ NAME-EXPR yields | string | atom | int/float/bool/datetime/bytes | `()` empty | element/map/seq |
|---|---|---|---|---|---|
| element `[?element E …]` | ✅ NCName | ✅ (`:` stripped) | ❌ CXER0236 (not NCName) | — absence: element → `()` | ❌ CXER0235 |
| attr `[?attr E V]` | ✅ | ✅ | ❌ CXER0236 | — absence: attr omitted | ❌ CXER0235 |
| map key `[?entry E V]` | ✅ | ✅ | ✅ (maps key on scalars, `[56g]`) | — absence: entry omitted | ❌ CXER0235 |
| set-attr `[set-attr [?name E] V]` | ✅ | ✅ | ❌ CXER0236 | — absence: no-op | ❌ CXER0235 |
| rename `[rename [?name E]]` | ✅ | ✅ | ❌ CXER0236 | ❌ CXER0236 (must have a name) | ❌ CXER0235 |

**Computed values/subtrees:**

| Position \ EXPR yields | scalar | element/map (1 node) | sequence | `()` | Path/Iterator |
|---|---|---|---|---|---|
| `[?unquote E]` in body | ✅ | ✅ | ❌ CXER0237 (use splice) | — slot removed | — realize-first |
| `[?unquote E]` in attr-value | ✅ | ❌ CXER0100 (attrs are scalar-only, §6.4.1) | ❌ CXER0237 | ❌ CXER0100 (no silent `attr=''`) | — realize-first |
| `[?splice E]` in body/sequence | ✅ (1-elem) | ✅ (1-elem) | ✅ each in order | — nothing grafted | — realize then splice |
| `[?splice E]` in attr-value/name | ❌ CXER0100 | ❌ CXER0100 | ❌ CXER0100 | ❌ CXER0100 | ❌ CXER0100 |

**`[?eval]` over TREE kinds:**

| TREE is | behavior |
|---|---|
| element/map/sequence of code forms | ✅ evaluated as code |
| scalar | ✅ self-valued (`[?eval 42]` → `42`) |
| `()` | — absence |
| Iterator/Path | — realize-first; if it cannot realize to a tree → `CXER0238` |
| tree with a non-evaluable-in-position node | ❌ CXER0238 |

### §6.5 Built-in functions

CX ships a closed set of pure-functional built-ins, **pre-bound in the
global `$` namespace**. They are invoked exactly like user/bound
functions — via head-dispatch `[$name args]` (§6.3) — in **any**
expression position:

```cx
[$upper $s]            # built-in call
[$count $xs]
[= $r [$range 1 10]]
[?pipe $xs [$distinct]]   # bare stage (§8.9)
```

**Reflection built-in `meta-of`.** `[meta-of EXPR]` returns the inert
metadata map attached to `EXPR` by `[?meta]` (§4.2), or the empty map `{}`
when none is present. Like `cast` it is a reserved **bareword** head (no `$`
sigil); a user binding / closure named `meta-of` shadows it.

```cx
[?let [= $p [?meta {unit: :years, source: "census"} 331]]
  [meta-of $p]]          # ⇒ {source: 'census', unit: :years}  — $p is still 331
```

There is **no paren-call surface for built-ins** anywhere (homoiconic
invariant — every form is `[head …]`), CXPath predicate bodies
included: `[case //user[> [$count $_@roles] 1]]`. The whitespace
bracket form `[name a b]` is **always** element construction (a data
element named `name`), even when `name` matches a built-in — so
`[first "a"]` constructs an element named `first`; the built-in is
`[$first "a"]`.

The signature notation `name(args)` used in the tables below documents
**arity and argument shape only — it is not the call syntax**; the call
is `[$name args]`. Each entry specifies arity, argument expectations,
and result shape.

**Operator heads vs named built-ins (the two call-bearing head forms).**
Exactly two element-head shapes carry call/operator semantics; every
other `[head …]` is data-element construction:

| Head form | Examples | Meaning |
|---|---|---|
| **Named built-in** — `[$name …]` | `[$upper $s]`, `[$count $xs]`, `[$concat "a" "b"]`, `[$substring $s 2 3]` | The `$`-sigil head-dispatch call (§6.3). A **word-named** built-in is reachable ONLY via `[$name …]`; the bare form `[name …]` is data-element construction (a data element named `name`), even when `name` matches a built-in. |
| **Symbolic / reserved operator head** — bare `[op …]` | `[+ $a $b]`, `[- $a $b]`, `[* $a $b]`, `[/ $a $b]`, `[= $x V]`, `[!= …]`, `[< …]`, `[<= …]`, `[> $x 100]`, `[>= $u@age 18]`, `[~ $a $b]`, `[and P Q]`, `[or P Q]`, `[not P]`, `[cast $v :int]`, `[union $a $b]`, `[intersect $a $b]`, `[except $a $b]` | A **closed set of reserved operator tokens** admitted **bare** as expression forms — they are NOT data elements and do NOT take a `$` sigil. The set is: arithmetic `+ - * / %`; comparison `= != < <= > >=` (grammar [126e] `ProgramRelOp`) plus the graded-similarity cognate `~` (std-lib/similar.md — 2-or-3-ary, element-valued); logical `and or not`; `cast` (the one type-tag operator, P6 below); and the set/sequence combinators `union intersect except` (formerly CXPath-predicate-only infix — now reserved prefix heads valid in every expression position; grammar [125f]/[125g]). |

The distinction is **lexical**: a symbolic or reserved-keyword operator
token is never a valid data-element name, so `[> $x 100]` is
unambiguously the comparison operator while a word head like `[gt …]`
would be element construction. This is why symbolic operators need no
`$` sigil (there is no ambiguity to resolve) but word-named built-ins do
(`[$count …]` vs the data element `[count …]`).

**The `$`-sigil decision rule (normative, canonical).** The sigil is
*declared*, not inferred: a bare word head can **never** be a
function/builtin call — it is always a directive, a reserved operator, a
reserved clause-head, or data-element construction. To decide the head form
of any `[head …]`, apply these in order:

1. **Head begins with `?`** → a **directive** (`[?for …]`, `[?let …]`); see
   the reserved directive-name list in §3.5 / registry §4.1.
2. **Head is in the closed reserved-operator set** → **bare**, no `$`:
   the symbolic operators `+ - * / = != < <= > >= ` and the seven
   reserved operator *words* **`and` `or` `not` `cast` `union`
   `intersect` `except`**. (This is the complete set — §6.5 above and
   grammar [125g]/[126e]. Nothing else is a bare operator.)
3. **Head is a reserved clause-head and the form sits directly inside a
   directive body** → **bare** (`[yield …]`, `[where …]`, `[set-attr …]`,
   `[mock]`, …); see the reserved clause-head list in §3.5.
4. **Otherwise** the sigil is set by intent, with no ambiguity:
   - **`$name`** references a binding; **`[$name …]`** is a head-dispatch
     **call** of a word-named built-in, user `[?def]`, or module member
     (a QName keeps the `$`: `[$strings:upper …]`, §12.1.1).
   - **bare `[name …]`** is **data-element construction** — a data element
     named `name` — *even when `name` matches a built-in*.

**Consequences that trip writers (all follow mechanically from the above):**
- `cast`, `and`, `or`, `not` are **bare** (reserved operators, step 2) —
  `[cast $v :int]`, not `[$cast …]`.
- `mod`, `div`, `idiv` take **`$`** — they are word-named built-ins, NOT in
  the reserved-operator set, so `[$mod $a $b]`; bare `[mod a b]` is a data
  element. (Contrast the symbolic `+ - * /`, which are bare.)
- Module members keep the **`$`**: `[$prefix:local …]`; the `/` operator is
  data-path navigation, never a module ref (§12.1.1).

**Symbolic / logical operator arity + operands (normative).** CX is
Lisp-1 homoiconic, so the reserved operator heads are **N-ary prefix** —
each folds over its FULL operand list:

| Op | Arity | Fold |
|---|---|---|
| `+` | ≥ 1 | sum of operands (`[+ 1 2 3 4 5]` = 15) |
| `*` | ≥ 1 | product (`[* 2 3 4]` = 24); unary = the operand |
| `-` | ≥ 1 | **unary** = negate (`[- 5]` = −5); **n-ary** = left-fold subtract (`[- 10 3 2]` = (10−3)−2 = 5) |
| `/` | ≥ 1 | **unary** = reciprocal as float (`[/ 4]` = 0.25); **n-ary** = left-fold divide (`[/ 100 5 2]` = 10); divide-by-zero raises `cx-err:CXER0101` (E_ARITH_DIVIDE_ZERO), as for `[$div]` |
| `%` | 2 | **binary** modulo, an exact alias of the `mod` builtin (#598): remainder with sign of dividend (XPath 3.1 §3.5, `[% -7 3]` = −1); int iff both operands int; divide-by-zero raises `cx-err:CXER0101` |
| `and` / `or` | ≥ 1 | EBV-fold, short-circuit left→right |
| `not` | 1 | EBV negation |
| `= != < <= > >=` | 2 | **binary**; chained comparison is NOT n-ary |
| `~` | 2–3 | **graded** cognate of `=` (std-lib/similar.md): `[~ a b]` scores with the default similarity predicate, `[~ a b $pred]` with a supplied one. Result is a `[similar score=… band=…]` **element** (not a boolean) — truthy in a boolean position iff `band=:match`; a null/absent operand resolves to the **absence channel** (unknown ≠ different) |
| `union` | ≥ 2 | left-fold sequence union — items of all operands, structural-duplicate-free (`eq`), first-occurrence order preserved |
| `intersect` | ≥ 2 | left-fold — items of the FIRST operand (first-occurrence order, deduplicated) present (`eq`) in EVERY other operand |
| `except` | ≥ 2 | left-fold — items of the FIRST operand (first-occurrence order, deduplicated) present (`eq`) in NO other operand |

**Arity is enforced.** Once a reserved operator head is recognized,
invoking it with the wrong number of operands raises `cx-err:CXER0100` —
it never falls through to data-element construction (a reserved operator
is never a data element). So `[+]` (zero operands), `[not P Q]` (binary
`not`), and `[= 1 1 2]` (ternary comparison) are each `CXER0100`.

**Int-preservation.** A `+ - * /` result is `int` iff every operand is
`int` AND the result is whole; otherwise `float` (e.g. `[/ 7 2]` = 3.5).

**Operand kind — scalar fold, NOT sequence aggregation.** Each operand of
`+ - * /` MUST be a single numeric scalar, OR a single node that
**atomizes** to one — an attribute or child/text node atomizes to its
**typed scalar value**, and is a valid operand iff that value is
numerically typed (`int`/`float`). CX is type-strict: a **string-typed**
scalar is NOT numeric and does NOT parse — `[+ "5" 3]` and a string-typed
attribute `[+ $doc/box@w 3]` (where `w="5"`) both raise `cx-err:CXER0100`;
convert explicitly with `[cast $s :int]` first. (An unquoted
`[box w=5]` / `[n 7]` auto-types to `int`, so `$doc/box@w` / `$doc/n`
atomize to `5` / `7`.) A non-numeric operand, or a **multi-item**
sequence / array / node-set operand, raises `cx-err:CXER0100`; it is
**never silently skipped** (strict). Summing a sequence or CXPath
node-set is the SEPARATE aggregate surface `$sum` / `$max` / `$min` /
`$avg` (numeric built-ins above), which flattens, atomizes node-sets,
skips non-numerics, AND applies XPath `fn:number` string-leniency —
`[$sum $doc//@value]`, never `[+ $doc//@value]`. The two surfaces are
distinct and do NOT overlap: `+ - * /` are scalar folds; `$sum` / `$max`
/ `$min` / `$avg` are sequence aggregates.

**Ordered comparison — numeric-strict.** The ordered comparisons
`< <= > >=` admit exactly what bare arithmetic admits: each operand MUST
be a single numeric (`int`/`float`) scalar, OR a single node that
**atomizes** to one (mixed int/float promotes: `[> 30 25.5]` evaluates).
EVERY other operand kind — a **string** (no silent lexicographic
ordering; convert explicitly with `[cast $s :int]` / `[cast $s :float]`),
a bool, an atom, a `date`/`datetime`/`duration`/`period` scalar (calendar
ordering is the time module's surface — `[$time:is-before]` /
`[$time:is-after]` — not bare `<`), an element/map/array, or a
multi-item sequence / node-set — raises `cx-err:CXER0100` naming the
operator and the offending operand kind. Per the reserved-operator rule
above it is **never a data element** and never silently skipped. The
single carve-out is **absence**: an ordered comparison with an absent
operand (`[> () 5]`) is `false` — never satisfied, never an error (the
same absence rule as `=`/`!=`). Equality `=`/`!=` is DIFFERENT by design
and unchanged: cross-kind structural equality **evaluates** — `[= '30'
30]` is `false`, `[!= '30' 30]` is `true` — no coercion, no error (§5.2).

Where a built-in operates on "a sequence", the argument may be a
top-level program sequence (a marker `__cxl_seq__` element), the
implicit document (an unnamed element wrapper), or a single
non-sequence value (treated as a 1-element sequence). Where a
built-in operates on "a string", the argument **MUST** be a string
scalar; non-string scalars are stringified by the canonical scalar
printer; non-scalar inputs raise `cx-err:CXER0100` (PARSE_ERROR)
unless the entry says otherwise.

**Sequence built-ins:**

| Built-in | Arity | Semantics |
|---|---|---|
| `count(seq)` / `length(seq)` | 1 | Integer count of items in `seq`; non-sequence scalar yields 1. |
| `empty(seq)` | 1 | Boolean — true iff `count(seq) == 0`. |
| `exists(seq)` | 1 | Boolean — true iff `count(seq) > 0`. Inverse of `empty(seq)`. The canonical existence test for predicates: the notation atoms `[@name]` / `[axis::name]` are defined by `[$exists $_@name]` / `[$exists $_/axis::name]` (§5.5.2). Scalar argument yields true (treated as 1-item sequence). |
| `first(seq)` | 1 | First item of `seq`; scalar input passes through unchanged. |
| `last(seq)` | 1 | Last item of `seq`; scalar input passes through unchanged. |
| `head(seq)` | 1 | Synonym for `first` (XQuery `fn:head` parity). |
| `tail(seq)` | 1 | All items of `seq` except the first, returned as a sequence; scalar input yields the empty sequence. |
| `reverse(seq)` | 1 | Items of `seq` in reverse order, returned as a sequence; scalar input passes through. |
| `distinct(seq)` | 1 | Items of `seq` with structural duplicates removed, preserving first-occurrence order. Two items are duplicates iff `eq(a, b)` is true. (XQuery `fn:distinct-values` parity; named `distinct` to align with the §6 surface — kebab-case unification.) |
| `nth(seq, n)` | 2 | The `n`-th item of `seq` (1-indexed, per XPath/XQuery convention). Out-of-range raises `cx-err:CXER0100`. |
| `position(seq, item)` | 2 | 1-based index of the first item in `seq` structurally equal (`eq`) to `item`; zero if no match. |
| `range(lo, hi, step?)` | 2–3 | Arithmetic progression `lo, lo+step, …` up to the inclusive bound `hi`. Default `step` is `1`. **Surface:** the prefix builtin `[$range lo hi step?]` ([125d] RangeCall) — usable in every expression position, including a `[?for [in $x [$range …]] …]` generator source. The retired infix `lo to hi by step` is a parse error. **Numeric domain**: **int** (default — int `lo`/`hi`/`step`); **float** (`step` **required**, no implicit `1.0`; computed count-based `n = floor((hi−lo)/step + ε)` then `lo + i·step` to avoid drift; endpoint included only within relative ε); **datetime** (`step` is a `duration` literal — `ns`/`us`/`ms`/`s`/`m`/`h`/`d`/`w`, all exact; a numeric step against a datetime is `cx-err:CXER0100`). Mixed int/float endpoints promote to float. **Calendar `date`/`period` ranges** (`step` is a `period` literal — `mo`/`y`) advance by calendar arithmetic against the anchor date (e.g. month-end clamping); a `period` step requires `date`/`datetime` endpoints. **Edge cases:** `step` of `0` → `cx-err:CXER0100`; a `step` whose sign points away from `hi` → the empty sequence `()` (not an error). **Result kind** (§12.7): a **finite** `[$range lo hi step?]` is an eager **Sequence**; the **open** form `[$range lo *]` (and `[$range lo * step]`) is a lazy **Iterator** (§6.7). |
| `iterate(f, seed)` | 2 | Functional progression — emits `seed, f(seed), f(f(seed)), …` **forever** (lazy **Iterator**). `f` is any unary callable (a bound `$ref`, a partial `[$f _]`, or a `[?def]`'d function); a non-callable `f` or arity mismatch → `cx-err:CXER0100` at the first pull. Statically infinite: forcing it whole without a bound (`[take]`/`[takewhile]`/a `[?for]` terminator) → `cx-err:CXER0100` (§6.7). `f` MAY be impure (capability-gated; fires once per pull, in consumption order — makes the generator impure, rejected under `--strict`). |
| `unfold(f, seed)` | 2 | General anamorphism (dual of fold) — `f` is applied to the current **state** and returns either **`()`** (stop) or a **2-element `Array` `[value, next-state]`** (emit `value`, recurse on `next-state`). Lazy **Iterator**, but **force-realizable** (runs to its `()` stop); a host **force budget** backstops a runaway → `cx-err:CXER0100` ("generator exceeded force budget"), never a hang. The pair is an `Array` (never a sequence — sequences flatten); multi-field state uses an `Array`/`Map`. Malformed result (non-`Array`, or not exactly 2 elements) → `cx-err:CXER0100` at that pull. Same callable/purity rules as `iterate`; an `[err]` from `f` is that element and propagates per §9.2 (the generator is not retried). |
| `identity(x)` | 1 | Returns `x` unchanged — primarily for pipe stages and `[?map]` shape testing. |

**String built-ins:**

| Built-in | Arity | Semantics |
|---|---|---|
| `upper(s)` | 1 | ASCII / Unicode upper-cased copy of `s`. |
| `lower(s)` | 1 | ASCII / Unicode lower-cased copy of `s`. |
| `contains(s, sub)` | 2 | Boolean — true iff `s` contains `sub` as a substring. Empty `sub` yields true. |
| `starts-with(s, prefix)` | 2 | Boolean — true iff `s` begins with `prefix`. Empty `prefix` yields true. |
| `ends-with(s, suffix)` | 2 | Boolean — true iff `s` ends with `suffix`. Empty `suffix` yields true. |
| `substring(s, start, len?)` | 2–3 | Substring of `s` starting at `start` (1-indexed; XPath convention) of length `len`. `len` omitted means "to end". Negative or out-of-range positions clamp; never raises. |
| `string-length(s)` | 1 | Integer — number of Unicode codepoints in `s` (V `string.len` byte count is **NOT** the contract; UTF-8-aware counting). |
| `normalize-space(s)` | 1 | Whitespace-normalised copy of `s` — leading + trailing whitespace stripped, runs of internal whitespace collapsed to a single ASCII space (XPath `fn:normalize-space` semantics). |
| `concat(s1, s2, …)` | ≥ 1 | String concatenation. Non-string scalar arguments are stringified via the canonical scalar printer; element arguments raise `cx-err:CXER0100`. |
| `text(elem)` | 1 | Body text of `elem` as a string; concatenates text-node children and stringifies scalar children. Empty body yields the empty string. Scalar argument is stringified. |

**Numeric built-ins:**

| Built-in | Arity | Semantics |
|---|---|---|
| `sum(seq)` | 1 | Sum of numeric scalars in `seq`; non-numeric items skipped. Empty / all-non-numeric yields integer 0. Any float promotes the result to float. |
| `max(seq)` | 1 | Maximum numeric scalar in `seq`; non-numeric items skipped. Empty yields integer 0. |
| `min(seq)` | 1 | Minimum numeric scalar in `seq`; non-numeric items skipped. Empty yields integer 0. |
| `avg(seq)` | 1 | Arithmetic mean of numeric scalars in `seq` as a float. Empty / all-non-numeric yields float 0.0. |
| `abs(x)` | 1 | Absolute value of numeric `x`. Integer input returns integer; float input returns float. |
| `floor(x)` | 1 | Largest integer ≤ `x`. Integer input passes through; float input returns integer. |
| `ceiling(x)` | 1 | Smallest integer ≥ `x`. Integer input passes through; float input returns integer. |
| `round(x)` | 1 | Half-away-from-zero rounding (XPath `fn:round` convention). Integer input passes through; float input returns integer. |
| `mod(a, b)` | 2 | Remainder of `a / b` (sign follows `a`, truncated division). `b = 0` raises `cx-err:CXER0101` (E_ARITH_DIVIDE_ZERO). |
| `div(a, b)` | 2 | Division: true division when either operand is float (float result); integer division (truncated toward zero) when both are integers. `b = 0` raises `cx-err:CXER0101`. |
| `idiv(a, b)` | 2 | Integer (truncating) division regardless of operand kinds; result is an integer. `b = 0` raises `cx-err:CXER0101`. |

Invoked head-dispatch as built-ins: `[$mod $a $b]` / `[$div $a $b]` /
`[$idiv $a $b]` (bare `[mod a b]` is element construction, per the §6.5
rule above). Division/modulo by zero is a runtime arithmetic trap
(`CXER0101`), distinct from the parse-time `CXER0100`.

**Floating point — finite-only (normative).** CX `f64` values are
**always finite**: a CX float is never `NaN`, `+Inf`, or `-Inf`. Any
arithmetic operation that would produce a non-finite result — division
by zero (`[$div x 0.0]`), `[$mod x 0.0]`, `[$idiv x 0]`, or an overflow
to infinity — **RAISES** rather than yielding a non-finite float
(division/modulo by zero raises `cx-err:CXER0101`, E_ARITH_DIVIDE_ZERO).
There is no code path in pure CX arithmetic that produces `NaN` or `±Inf`.

*Rationale.* Non-finite floats would break two CX invariants. (1)
**Content-addressed identity** — `NaN != NaN` violates reflexivity, which
would poison hashing, dedup, and structural equality (`eq`). (2)
**Bijective JSON/XML serialization** — neither JSON nor XML can represent
`NaN`/`±Inf`, so a non-finite value has no round-tripping wire form. A
non-finite float can therefore only **ENTER** CX across the FFI boundary
(a host binding passing a native `NaN`/`±Inf` into a CX value); such a
value is rejected at the first hash / serialize / validate / observe
point that inspects it (e.g. `cx-stdlib/prof` `CXER2103`,
`cx-stdlib/json` `CXER3104`). These boundary guards are not reachable
from pure CX arithmetic, which raises `CXER0101` first.

The sequence aggregates `sum` / `max` / `min` / `avg` accept **either** a
single sequence argument **or** multiple positional scalar arguments, which
coalesce into the operand sequence: `[$min 5 3 8]` is equivalent to
`[$min (5, 3, 8)]`. (The `Arity 1` column documents the canonical
single-sequence form.)

**Logical built-ins:**

| Built-in | Arity | Semantics |
|---|---|---|
| `not(x)` | 1 | Boolean negation of `x` under the EBV table in `cxdm.md` (booleans → negate; integers → `x == 0`; floats → `x == 0.0` (ints and floats share the numeric rule; NaN never arises — CX floats are finite-only); strings → empty; sequences → no items, a singleton reading as its one item; arrays/maps → empty; a present element or other node → always truthy, regardless of contents — presence, not emptiness). An Iterator operand has **no EBV** and raises the catchable `cx-err:CXER0100` — force the stream explicitly and test the realized value (cxdm.md EBV table). |
| `and(a, b, …)` | ≥ 1 | Boolean — true iff every argument is truthy. Short-circuit: argument evaluation order is left-to-right. |
| `or(a, b, …)` | ≥ 1 | Boolean — true iff at least one argument is truthy. Short-circuit: left-to-right. |
| `eq(a, b)` | 2 | Structural equality. Two scalars are equal iff same kind and same value. Two elements are equal iff same name, attribute count, child count, and structurally-equal children + attribute values. |

**Node-accessor built-ins:**

| Built-in | Arity | Semantics |
|---|---|---|
| `name(elem)` | 1 | The element's name as a string (including any namespace prefix). Non-element argument raises `cx-err:CXER0100`. |
| `local-name(elem)` | 1 | The element's local name with any namespace prefix stripped (`svg:circle` → `circle`; unprefixed names are returned unchanged). Non-element argument raises `cx-err:CXER0100`. |
| `string(value)` | 1 | The string value of the argument: a scalar's canonical text, or an element/attribute's text content. |

**Type-coercion built-in (`cast`):**

CX is type-strict — atomic scalars of different kinds never compare
equal even when their canonical text matches (`"42" != 42`,
`:ok != "ok"`); cf.
[`cxdm.md` §9](cxdm.md) — type coercion. The `cast` builtin is the **single
explicit coercion path**; a `to-int` / `to-float` / `to-string` family
was deliberately not adopted (locked 2026-05-23 — see ).

| Built-in | Arity | Semantics |
|---|---|---|
| `cast(value, :type-tag)` | 2 | Explicit kind-coercion. `value` is any value; `:type-tag` is an atom literal naming the target kind. Returns a scalar of the target kind, or an `[err …]` value with code `cx-err:CXER0290` on failure (parse error, unsupported source kind, null source). |

**Surface forms** (parse-equivalent):

| Form | Notes |
|---|---|
| `[cast value :type-tag]` | Canonical user-facing form (e.g. `[cast $p :int]`, `[cast "42" :int]`). `cast` is a **reserved operator head** — the one built-in with dedicated element-head syntax (it takes a `:type-tag` atom) — not a plain data element. |
| `cast(value, :type-tag)` | **Signature notation only** — documents arity/arguments (§6.5); NOT a call surface. There is no paren-call form anywhere in the language (§6.3). |

**Target kinds:** `:int`, `:float`, `:string`, `:bool`, `:atom`.

Compound type expressions (`[or T1 T2 …]`, `[sequence T]`) from D7 are
reserved for a follow-on iteration — the grammar admits only the
kind-name atoms.

**Coercion semantics** (normative):

| Source → Target | Behaviour |
|---|---|
| any → `:string` | Canonical string form: element body text (concat of children, same as `text`); scalars via the canonical printer; atoms render their name without the leading `:`. |
| string → `:int` | Parse decimal integer; empty / non-numeric raises `CXER0290`. |
| string → `:float` | Parse floating-point literal; empty / non-numeric raises `CXER0290`. |
| string → `:bool` | `"true"` / `"false"` exact match (case-sensitive); other strings raise `CXER0290`. |
| string → `:atom` | Validate NCName shape + reject reserved names (`true`/`false`/`null`). |
| int → `:float` | Lossless widening. |
| float → `:int` | Truncate toward zero. |
| int / float → `:string` | Decimal repr (round-trippable for float). |
| bool → `:string` | `"true"` / `"false"`. |
| bool → `:int` / `:float` | `1` / `0`. |
| atom → `:string` | The atom's name without the leading `:`. |
| atom → `:int` / `:float` / `:bool` | `CXER0290` — atoms are tag-shaped, not values; use `[?match]` to dispatch. |
| element → `:int` / `:float` / `:bool` / `:atom` | Coerce the body text (same as if the body had been cast directly). The critical path for `program-modify-005`. |
| element → `:string` | Canonical body text per the `:string` row above. |
| null → any | `CXER0290` — null is not coercible; users **MUST** check for null first (`[?if (eq $x null) [then …]]`). |

**Errors:** `cx-err:CXER0290` (E_CAST_FAILED) on any unsupported pair,
parse failure, or null source. The error is returned as a CX
err-value (`[err code=cx-err:CXER0290 message='…']`) rather than
raised, so callers may [`?try`](#§8.7) / [`?fallback`](#§10.2)
over it per the err-value-propagation convention (§9.2).

**Purity.** `cast` is **pure** — deterministic, no side effects (see
the purity table at §6.5.x).

**Conformance.** Each built-in in this table **MUST** have at least
one fixture in `conformance/code.txt` exercising its happy path
and (where applicable) its degenerate edge cases (empty input,
non-matching type, boundary indices). Gate 4 (§11.4.2) requires the
fixture-coverage triples to include each built-in name.

**Validation helper (fixture-only).** `validate-item(elem)` is an
internal fixture helper used by `program-err-003-on-error-recovery`
to drive `[?on-error]` recovery paths; it is not part of the public
built-in surface but is dispatchable to keep its conformance fixture
self-contained.

**Window built-ins.** Tumbling and sliding window operators are not
currently specified; they require a grammar extension to the `[?for]`
directive (XQuery 4.0 §4.13.4) and are filed for a future revision.

### §6.5.x Built-in purity classification

Every built-in is classified as **pure** or **impure**. The
classification is normative and closed: adding a new built-in
requires classifying its purity in the same spec amendment
that adds it. The static purity checker reads this table to decide whether a `pure` `[?def]` body or
a PredicateExpr body may call the built-in.

A reference to a built-in missing from this table raises
`cx-err:CXER0234` (E_PURITY_UNCLASSIFIED_BUILTIN) at parse /
module-load.

**Pure built-ins (closed list):**

| Group | Built-ins |
|---|---|
| Sequence | `count`, `length`, `empty`, `first`, `last`, `head`, `tail`, `reverse`, `distinct`, `nth`, `position`, `range`, `identity` |
| Higher-order | `filter`, `map`, `reduce` — applied as `[$filter seq pred]`, `[$map seq fn]`, `[$reduce seq fn init]`. The functional twins of the `[?filter]` / `[?map]` / `[?reduce]` directives (§8.10), reachable in any expression position via head-dispatch (§6.3). The function argument is a function value; the call is pure iff that function is pure. |
| Generator | `range` (arithmetic — also listed under Sequence), `iterate` (functional progression `[$iterate f seed]`), `unfold` (general anamorphism `[$unfold f seed]`). `range` is always pure; `iterate`/`unfold` are pure iff their `f` is pure (an impure capability-gated `f` makes the generator impure — §6.7). All are lazy where infinite (Iterator) and finite where bounded (Sequence — §12.7). |
| String | `upper`, `lower`, `contains`, `starts-with`, `ends-with`, `substring`, `string-length`, `normalize-space`, `concat`, `text` |
| Numeric | `sum`, `max`, `min`, `avg`, `abs`, `floor`, `ceiling`, `round`, `mod`, `div`, `idiv` |
| Logical | `not`, `and`, `or`, `eq` |
| Node-accessor | `name`, `local-name`, `string` |
| Type-test / cast | `cast` (reserved operator head — §6.5 P6), `exists` (the retired infix `instance of` / `cast as` operators are parse errors; kind tests use `::` type annotations and `[cast …]`) |
| EBV / identity | EBV operator (implicit in `[?if]`, `[when …]` arms, predicates); identity hash; atom-equality |
| Path / CXPath | CXPath evaluation over a frozen input document (the document is read-only from the predicate's perspective; the path itself is a value

**Impure built-ins (closed list):**

| Group | Built-ins |
|---|---|
| I/O | `print`, `read-file`, `write-file`, `read-line`, any `[?lib]`-supplied HTTP / socket / disk surface |
| Time-source | `now`, `today`, `instant-now`, `monotonic-now` |
| Random / UUID | `random`, `random-int`, `uuid`, `random-bytes` |
| Document mutation | `[?modify]` directive evaluation |
| Channel operations | `[?send]`, `[?receive]`, `[?try-send]`, `[?try-receive]`, `[?close]`, `[?select]` |
| Worker / async | `[?worker]`, `[?async]`, `[?await]`, `[?await-all]`, `[?await-any]`, `[?await-race]`, `[?cancel]`, `[?check-cancel]`, `[?sleep]` |
| Service / client | `[?http-service]`, `[?service-handle]`, `[?http-client]` |
| Resilience composition | `[?retry]`, `[?timeout]`, `[?circuit-breaker]`, `[?fallback]`, `[?rate-limit]`, `[?bulkhead]` (impure because they wrap impure operations and observe wall-clock / counter state) |

**Note on `position` (sequence built-in).** The built-in
`position(seq, item)` (§6.5 Sequence built-ins, "1-based index of
the first item structurally equal to `item`") is **pure** and
distinct from the predicate-context binding `$_position`. The two are namespace-disjoint: `position` is a function
name; `$_position` is a binding name.

### §6.5.1 Effect totality of `pure` + the capability-alignment invariant

Over the two admitted closed lists — the §6.5.x pure/impure classification and
`security.md` §2 capability categories — the following is **normative**:

> **Effect totality of `pure`.** A `[?def] … pure …` function accepted by the
> static purity checker (§6.5.x) **provably performs no capability-gated effect**:
> its transitive call graph contains no `impure` builtin (checker-enforced), and
> every capability-gated effect point is reached only through an `impure` builtin.
> Therefore a `pure` function evaluated under **any** capability set — including
> the empty set — raises **no** `CXER0271`. Purity ⇒ capability-freedom is a
> theorem over the two closed lists, not a runtime check.

**Scope (narrow and strong).** This is an **effect** guarantee ONLY — not
semantic totality. A `pure` function MAY still (a) raise an input-dependent
`[err]` (e.g. divide-by-zero `CXER0101`, overflow `CXER3000`), (b) not terminate,
and (c) exceed a budget. The claim is *not* "same result under any cap-set" beyond
"no capability effect, no `CXER0271`." Determinism modulo input-errors/termination
is a *separate* property, not asserted here.

**The capability-alignment invariant (ONE-WAY; conformance-gated).** The invariant
is **capability-gated ⇒ impure**: every capability-gated effect point is reached
only through an `impure` builtin. The converse does **not** hold —
`impure`-without-capability is allowed, but **only** via a **closed, enumerated
exception table** (state-bearing or wall-clock/counter-observing, but not
capability-gated):

| Impure-without-capability builtin/directive | Why it is impure yet cap-free |
|---|---|
| `[?modify]` (§8.10) | document mutation is a pure-functional update of an in-memory value; touches no capability |
| `[?retry]` / `[?timeout]` / `[?circuit-breaker]` / `[?fallback]` / `[?rate-limit]` / `[?bulkhead]` (§10.2) | resilience composition: impure because they observe wall-clock / counter state, but the *capability* (if any) is charged to the impure op they wrap, not to the combinator |
| **(a)** state-bearing PRNG: `random-next-*`, `random-int-range`, `random-float-range`, `random-gaussian`, `random-exponential`, `random-poisson`, `random-choose(-weighted)`, `random-sample(-weighted)`, `random-shuffle`, `random-seed` (`std-lib/random`) | draw from a **process-global generator** seeded once; deterministic given the seed and draws **no OS entropy**, so they need no `random` capability. The entropy surfaces (`random-crypto-*`) are the cap-gated counterpart |
| **(b)** mock clock: `time-mock-set`, `time-mock-advance` (`std-lib/time`) | mutate / read **test-clock** state, never the real wall clock; the wall-clock reads (`time-now`/`time-today`/…) are the cap-gated counterpart |
| **(c)** spec-classified bare-name builtins with impl pending: `print`, `read-file`, `write-file`, `read-line`, `now`, `today`, `instant-now`, `monotonic-now`, `random`, `random-int`, `uuid`, `random-bytes` | classified `impure` in §6.5.x (load-bearing for purity fixtures, e.g. a `pure` def calling `[$uuid]` must be rejected) but their evaluator handler is **not yet wired**; they **will be capability-gated at impl time** and move out of this table then |

(`path-absolute` / `path-canonical` are **not** in this table — they resolve
against the real cwd / filesystem and are **capability-gated under `read`**, so
they satisfy the gated ⇒ impure direction directly.)

The conformance check (`make check-effect-alignment`) enforces **both**: (1) every
capability-gated effect point is reached only through an `impure` builtin; (2)
every impure-without-capability builtin is in the closed exception table above. It
is **not** symmetric — a symmetric `impure ⇔ capability` rule would mislabel the
legitimate pure-functional / state-bearing exceptions.

This lemma is load-bearing for §10 concurrency: a capability-free computation has
no effect races and is safe to *evaluate in parallel* (§7.3). It is **not** a
free-cancellation claim — a pure CPU loop does not observe cooperative
cancellation (§10.5.4) and needs an explicit `[?check-cancel]` point.

### §6.6 Slice Expressions

A `$binding[SliceAxes]` postfix selects a sub-sequence of the
binding's value. The binding must be Sequence-typed (or atomizable
to Sequence via the standard host-boundary force-materialise rule —
Iterator and Array sources work transparently, and a `:table`-bearing
element atomizes to its **row sequence** per D22 below).

**Surface forms:**

| Form | Semantics |
|-----------------------------------|-----------|
| `$xs[N]` | Single index. 1-based. Returns the item at position `N`. |
| `$xs[N:M]` | Inclusive range. Returns items from index `N` through `M` (both endpoints included). |
| `$xs[:M]` | Open start. Equivalent to `$xs[1:M]`. |
| `$xs[N:]` | Open stop. Equivalent to `$xs[N:$_last]`. |
| `$xs[N:M:S]` (or `$xs[N:M by S]`) | Strided. Step `S` between selected items. Inclusive of `M` when the stride lands on it; otherwise stops at the last value ≤ `M` (positive stride) or ≥ `M` (negative stride). |
| `$xs[::S]` | Open ends + stride. Walks every `S`th item. |
| `$xs[::-1]` | Reverse (stride `-1` with open ends). |
| `$xs[*]` | Full axis — returns the source unchanged. |
| `$xs[-N]` | Negative index — `-1` is last, `-2` is second-to-last, etc. (D9) |
| `$xs[$_last]` | Last-index sigil — resolves to `len($xs)` at apply time (D6, D11). |
| `$xs[$_last-1]` | Arithmetic on `$_last` works as a normal expression in slice position. |

**Semantics (normative):**

- **D4** Indexing is 1-based. `$xs[1]` is the first element.
- **D5** Stop endpoint is **inclusive** (XPath / Julia convention).
 `(1, 2, 3, 4, 5)[2:4]` returns `(2, 3, 4)`.
- **D6** The `$_last` sigil is a reserved binding (alongside `$_`,
 `$_position`) that resolves to the receiver's length at the
 moment the slice is APPLIED, not when it is constructed. Slices
 stored via `[?def]` remain reusable across receivers of different
 sizes per D11.
- **D9** Negative indices count from the end. `-1` is the last
 index, `-2` the second-to-last, etc.
- **D20** Empty-direction / out-of-range slices return the empty
 sequence ``. Not an error.
 - `$xs[10:5]` (start > stop with positive step) → ``
 - `$xs[5:10]` on a 3-element source → `` (out of range; clamped to empty)
- **D21** Step-of-zero is an evaluation error:
 `cx-err:CXER0100: slice step cannot be zero`.
- **D12** Multi-axis slicing (`$matrix[1:3, 2:4]`) is shipped (W6-E).
 Comma-separated axes select along successive dimensions of a
 Sequence-of-Sequence (matrix) receiver: the first axis picks rows,
 each surviving row has the remaining axes applied, results re-wrap
 into a `__cxl_seq__` envelope. A `.single` first axis reduces rank
 by one (`$m[2, *]` → that row); a `.range`/`.full` first axis keeps
 the outer sequence. A flat-sequence receiver with arity ≥ 2 raises
 `cx-err:CXER0100`.
- **OQ2 (slice-on-map)** Slicing requires a positional sequence. A
 slice axis applied to a Map (`cx.MapNode` or the in-pipeline
 `__cxl_map__` envelope) is an evaluation error:
 `cx-err:CXER0100: slice on map requires positional sequence; got map`.
 Maps have no positional axis, so this is rejected rather than
 silently iterating entries in arbitrary order.

**Table sequence view (D22, #404).** A **`:table`-bearing element** (an
element carrying a `[table[…]]` block, grammar [29]) atomizes to its
**row sequence** wherever a surface takes the sequence view of a value:
slice receivers in this section, `[?for]` generator sources (§7.2), and
the §6.5 sequence built-ins (`$count`, `$first`, `$sum` over a column
slice, …). Each row materialises as an **ordered Map** — one entry per
declared column, in declaration order, keyed by column name — with cell
values as their typed scalars (an `age::int` cell is an `int`, so
`[where [> $r.age 26]]` needs no conversion) and collection-typed cells
as their Array / Map / Sequence items. This is the same row shape the
bindings' Table API (`misc/table-api.md` §2: "each row is an ordered
map") and `[$csv:parse]` (`std-lib/csv.md`) produce — one record story
platform-wide. The sequence view is a **read projection only**: element
identity, construction, serialization, canonical bytes, EBV (truthy by
presence), and equality are unchanged. **CXPath does NOT navigate into
table rows** — rows are not CXDM children (`$t//row` is `()` and
`[$count $t/*]` is `0`, by design): comprehensions and slices are the
query surface for tabular values; CXPath is the query surface for
element trees.

**Column-label slicing (D13).** The second axis of a multi-axis slice
may carry **string-valued** bounds — a *column label* rather than a
positional index — when the receiver's rows are column-addressable
(attributed-row elements such as `[row name="A" email="a@x"]`, whose
columns are their attributes in declaration order; **table rows**,
whose columns are the declared `[table[…]]` header in declaration
order (D22); or **Map rows** — `{k: v, …}` records such as
`[$csv:parse]` rows — whose columns are their entries in entry
order).

```cx
$t[*, "name"] # the "name" column from every row
$t[1:2, "name":"email"] # cols name..email (inclusive) for rows 1-2
```

- Single label → each row's matching column value. An attributed row
 resolves the label against its attributes (attribute-first); when a
 row carries no attributes the label falls back to a child element of
 that name. A **table row / Map row** (D22) resolves the label against
 its entries and yields the entry's **value** (the typed cell, not a
 wrapper element).
- Label-range `"lo":"hi"` resolves both labels to column positions in
 the row's ordered column list and slices **inclusively** between
 them (D5 convention); a reversed range yields `` (D20).
- A receiver whose rows are not column-addressable (flat scalar
 sequence) raises
 `cx-err:CXER0100: column-label slice requires a table or attributed-row source`.
 An unknown label in a *range* endpoint is a shape error (CXER0100);
 an unknown *single* label yields `` (a missing column).
- A **positional** (integer) second axis against a table/Map row is
 the OQ2 rejection (`slice on map requires positional sequence`) —
 columns are addressed by **label**; the full axis `*` yields the
 whole row map (`$t[2, *]` → row 2 as an ordered Map, equal to
 `$t[2]`).

**View opt-in (D8).** `[?view EXPR]` flips a slice's result from copy
(the default) to a zero-copy **view**; `[?views BLOCK]` is the scoped
form, marking every slice inside the block as view-flavored. Because
CX values are immutable, a view is **observationally
identical** to a copy — it yields the same value — so these
directives are a **semantic no-op that documents intent**:
`[= [?view $xs[2:4]] $xs[2:4]]` is `true`. The static "source not
mutated for the view's lifetime" check is trivially satisfied since CX
has no mutation. True zero-copy walking (a view that strides the source
in place rather than materialising) is a **future runtime
optimisation** and is intentionally not part of the current surface.

**Distinct from CXPath predicates.** `$bind[Expr]` may appear to
collide with the predicate form. The parser disambiguates
**positionally** at parse time based on the bracket body shape:

| Body shape | Parses as |
|-------------------------------|-----------|
| Single Expr, no `:` or `,` | CXPath predicate |
| Contains `:` at top level | Slice axis (range form) |
| Leading `*` | Slice axis (full axis) |
| Top-level `,` between Exprs | Multi-axis slice (D12 — shipped; string second-axis = column label per D13) |

The disambiguation is **shape-based and fully resolved at parse time** —
no lookahead beyond the bracket body. See §5.5 for the predicate side
of the same rule and `grammar.ebnf` [165] DisambiguationTable for the
normative grammar.

**Examples** (informative; fixtures in `conformance/code.txt`):

```cx
[?let [= $xs (10, 20, 30, 40, 50)]
 [?for [in $i (1, 2, 3, 4, 5)]
 [yield [pair pos=$i val=$xs[$i]]]]]

$xs[2:4] # (20, 30, 40)
$xs[:3] # (10, 20, 30)
$xs[3:] # (30, 40, 50)
$xs[::2] # (10, 30, 50)
$xs[::-1] # (50, 40, 30, 20, 10)
$xs[-1] # 50
$xs[$_last] # 50
$xs[$_last-1] # 40
```

Fixtures: `program-slice-001` through `program-slice-015`,
`program-slice-multiaxis-*` (D12), `program-slice-collabel-*` (D13),
and `program-view-*` / `program-views-*` (D8) in
`conformance/code.txt`; cookbook entries 156–160 demonstrate
slicing in idiomatic use.

### §6.7 Iterator evaluation

*(Amended by W3e . §6's title in this spec is
"Bindings, paths, function calls"; the iterator-evaluation rules
live here because iterator construction and consumption surface
through the same binding/call machinery as the rest of §6.)*

Iterators are produced by:

- The prefix range builtin `[$range lo hi step?]` — a **finite** range is an
 eager Sequence (not an Iterator); see §6.3 / §12.7.
- The open-end range builtin `[$range lo *]` (stride optional: `[$range lo * step]`)
 — a lazy, statically-known-infinite Iterator. Forcing one to full
 materialisation (no `[take …]` / `[takewhile …]` terminator, nor a `[?for]`
 terminator) **MUST** raise `cx-err:CXER0100` per D19, checked statically where
 the open form is syntactically visible. `cx lsp` emits `CXLS006` (hint)
 statically when a `[?for]` generator source is `[$range lo *]` with no
 `[take …]` / `[takewhile …]` clause, surfacing the runtime error before
 evaluation.
- The functional generator `[$iterate f seed]` — emits `seed, f(seed), …`
 forever; a lazy, statically-known-infinite Iterator with the same
 force-needs-a-bound rule as `[$range lo *]`.
- The general generator `[$unfold f seed]` — a lazy Iterator that **MAY
 terminate** (`f` returns `()`), so it is **force-realizable**: forcing it whole
 runs `f` to its `()` stop, yielding a finite Sequence. Because termination is
 statically undecidable, the host applies a **force budget** (a max-pull guard);
 on exhaustion it raises `cx-err:CXER0100` ("generator exceeded force budget"),
 never a hang. (`[$range lo *]` and `[$iterate]` are *known*-infinite by
 construction, so they require an explicit bound; only `[$unfold]` force-realizes.)
- Combinator directives `[?map]` / `[?filter]` / `[?reduce]` (terminal — materializes to scalar)
 / `[?zip]` / `[?enumerate]` / `[?take]` / `[?drop]` / `[?chain]` / `[?concat]` / `[?chunks]` / `[?cycle]`
 / `[?scan]` / `[?flatten]` / `[?partition]` / `[?group-by]` — see `stdlib.md` for the full
 catalog. `[?concat]` flattens a sequence-of-sequences one level; `[?chain]` is its
 end-to-end alias. An err-valued `[?filter]` / `[?partition]` predicate result
 short-circuits the whole combinator and is its result — §9.2 implicit operand
 propagation, uniform with the `[?for]` `[where …]` clause (§7.2).
- Explicit lift of a Sequence to an Iterator (a `to-iterator` directive
 is **planned, not yet in the §4.1 registry** — tracked post-W3)

Iterators are consumed by:

- `iterate` / `[?for [in $x ITER] …]` — walks the items in order
- `[?to-sequence ITER]` — force-materialize to a Sequence
- `[?to-array ITER]` — force-materialize to an Array
- `[?to-map ITER]` — force-materialize to a Map (entries are (key, value) pairs)
- Output rendering (any host-boundary write) — implicit force-materialize

Equality is identity-only; a `seq-equal` walk-comparison
helper is **planned, not yet in the §4.1 registry**.

When an Iterator is bound via `[?def $name ITER]`, the memo is
shared on re-walk per D7 (named iterators are re-walkable;
anonymous iterators may be single-use depending on source kind).

**Single-use sources.** Some source kinds are
intrinsically non-rewindable — an external stream (network response
body, file lines, channel reads) cannot be replayed once drained.
Iterators backed by such a source carry a single-use marker; walking
one a second time **MUST** raise `cx-err:CXER0105`
(ITERATOR_ALREADY_WALKED). All built-in source kinds shipped today
(`range`, `range(_, *)`, and the combinator family) are re-walkable;
the single-use marker is forward-looking for the streaming source
kinds that follow.

See [`cxdm.md` §2.9](cxdm.md) for the value-taxonomy entry
and [`ast.md` § IteratorNode](ast.md) for the AST shape.
---

## §7. For-comprehension

The `[?for]` directive expresses generation-with-filters-and-yields
in the Scala for-yield style. The body is a sequence
of clause-child elements: generators (`[in …]`), pattern generators
(bare `[pattern]`), let-bindings (`[= $y EXPR]`), filters
(`[where …]`), stream operators (`[order-by …]`, `[group-by …]`,
`[limit N]`, `[take N]`, `[drop N]`, `[takewhile P]`, `[dropwhile P]`,
`[par]`, `[stream]`, `[ordered]`), and exactly one terminating yield
clause (`[yield E]`, `[yield-array E]`, or `[yield-map K V]`).

### §7.1 Body grammar

```
[?for
 ([in $x SRC])+ # one or more generators (clause-child shapes below)
 ([= $y EXPR])* # zero or more let-bindings, any order
 ([where COND])* # zero or more filters
 ([order-by EXPR (asc|desc)?])?
 ([group-by EXPR])?
 ([limit N])?
 ([take N])* ([drop N])* ([takewhile P])* ([dropwhile P])*
 ([par])? ([stream])? ([ordered])? ([fail-fast])?
 [yield EXPR] # exactly one yield clause
]
```

The `[on-error $e HANDLER]` per-iteration clause is **retired** with the
`[?try]`/`[catch]` surface (§8.8): per-iteration handling folds into a yield-body
`[?match]` / `[?else]` (`[yield [?match [$f $x] [case [err $e] H] [else $v]]]`,
§9.3).

Generators, let-bindings, and filters MAY appear in any order before
the yield clause; later clauses see all earlier bindings in scope.

The generator clause `[in …]` has three shapes:

```
[in $x SRC] # explicit-bind generator
[in SRC] # anonymous generator (each item bound to $_)
[in [PATTERN] SRC] # pattern-bind generator
```

A bare bracketed pattern at top level (no `[in …]` wrapper) is the
pattern-generator shortcut for a document-wide search; see §7.5.

### §7.2 Semantics

Evaluation produces the Cartesian product of all generators, filtered
by every `[where …]`, then projected by the yield clause. Stream
operators transform the yielded sequence:

- `[order-by EXPR]` — sorts by `EXPR` evaluated per item. Optional
 `asc` (default) or `desc` direction follows the expression.
- `[group-by EXPR]` — groups consecutive items sharing `EXPR` value;
 introduces `$count` and `$group` bindings inside the yield clause.
- `[limit N]` — truncates to N items.
- `[take N]` / `[drop N]` — keep first N / skip first N.
- `[takewhile P]` / `[dropwhile P]` — predicate-driven prefix windows.
- `[par]` — evaluates generators in parallel (§7.3).
- `[stream]` — evaluates lazily; yields each item as soon as ready (§7.4).
- `[ordered]` — preserves source order under parallel evaluation;
 **MUST** be paired with `[par]`. Using `[ordered]` without `[par]`
 raises `cx-err:CXER0100` at parse time.

**Table sources (D22, #404).** A generator source whose value is a
`:table`-bearing element iterates the table's **row sequence** (§6.6
D22): `[in $r $t]` binds `$r` to one **ordered Map per row** — entries
keyed by the declared column names, in declaration order, cell values
as their typed scalars (collection cells as their Items). Guards and
yields access cells with map-key notation (`$r.age`), and because
cells carry their declared column types, `[where [> $r.age 26]]`
compares numerically with no conversion step. Row order is the
table's declaration order; an empty table (header, zero rows)
contributes zero iterations. `[?for]` over table rows composes with
every clause in this section (`[where]`, `[order-by]`, `[group-by]`,
`[limit]`, `[par]`, …) — this, plus D13/D22 slicing, **is** the
in-language query surface for tabular values (CXPath does not
navigate into rows; §6.6 D22).

```cx
[; $t holds [users [table[name::string age::int]] alice 30  bob 25] ;]
[?for [in $r $t] [where [> $r.age 26]] [yield $r.name]]
[; → ('alice') ;]
```

**Err-valued guards and predicates propagate (normative).** A `[where …]`
guard or `[takewhile P]` / `[dropwhile P]` predicate that evaluates to an
`[err]` value is never EBV-coerced (an err element would read truthy — a
present element always does): it short-circuits the whole comprehension, and that `[err]`
is the comprehension's result — per §9.2 implicit operand propagation,
uniformly with operators, calls, and the `[?if]` condition (§8.4). This
holds identically under `[par]` (§7.3; the earliest-item err wins, matching
sequential first-failure order) and `[stream]` (§7.4; items already emitted
stay emitted — the err terminates the remaining stream). A predicate that
should *tolerate* err-producing probes over heterogeneous items must handle
the err explicitly (e.g. `[?fallback … [recover-with false]]` or an
absence-returning lookup). Rationale: err→skip semantics silently filter
everything out under a broken predicate — the exact failure class §9.2
exists to prevent (#348).

**`$_position` in yield bodies.** Inside the yield
clause body, the reserved sigil `$_position` resolves to the
1-based index of the item being **emitted** — the OUTPUT position.
It counts only items that survive `[where]` filtering and
`[drop]`/`[take]` windowing (filtered or dropped candidates never
reach the yield step, so they do not advance the counter). The
binding is scoped to the yield frame only; it is not visible to
`[where]` or `[= …]` clauses, which run before the output index is
known.

```cx
[?for [in $x (10, 20, 30, 40)] [where [> $x 15]]
 [yield [n pos=$_position v=$x]]]
# → [n pos=1 v=20] / [n pos=2 v=30] / [n pos=3 v=40]
```

**Outer-container variants.** The default `[?for]`
yields a flat sequence. `[?for-array]` collects yielded items into
an Array (preserving structure — inner sequences do not flatten);
`[?for-map]` collects `[yield-map K V]` pairs into a Map. The
container choice is the directive head; the yield clause
(`[yield E]` / `[yield-array E]` / `[yield-map K V]`) decides
per-item shaping.

```cx
[?for-array [in $x [$range 1 3]] [in $y [$range 1 2]] [yield-array [$x, $y]]]
# → [[1, 1], [1, 2], [2, 1], [2, 2], [3, 1], [3, 2]] (Array of arrays)

[?for-map [in $x [$range 1 3]] [yield-map $x [* $x $x]]]
# → {1: 1, 2: 4, 3: 9}
```

### §7.3 Parallel evaluation (`[par]`)

`[par]` parallelizes the outermost generator across a **bounded worker pool**
of at most W workers (#94): `[par]` = default `W = min(4, ncpu)`, `[par N]` =
`W = N` (N ≥ 1), `[par max]` = `W = ncpu`. An `N < 1` / non-integer / non-`max`
token is a parse error (`cx-err:CXER0100`); an explicit `N > 64×ncpu` is the
fail-loud sanity cap (`cx-err:CXER0153`), never silently clamped. The inner
generators of a multi-source comprehension run sequentially within each worker —
only the outermost loop is parallel. Cardinality MUST be known finite. Output
order is unspecified unless `[ordered]` is also present (which reassembles source
order). `take` / `drop` / `limit` are applied to the assembled result.
Order-dependent shapes — `takewhile` / `dropwhile`, a `$_position` reference, or
a streaming/`Iterator` generator source — evaluate **sequentially** (the bound
is on the parallel path only; correctness is preserved). Errors raised during
parallel evaluation surface the earliest-input-index failure; the optional
`[fail-fast]` clause (grammar `[129r]`) reverts to short-circuit-on-first-`[err]`
behavior. Without `[par]`, `[fail-fast]` is a no-op (sequential evaluation
already short-circuits).

**Degree of concurrency — one spelling (#95).** "How many at once" has a single
canonical surface: **`[par N]` / `[par max]`** (default `min(4, ncpu)`, fail-loud
`CXER0153` cap). The other concurrency constructs are deliberately *not* given a
redundant width:
- **`[?worker]` / `[?async]`** are **single-task** primitives (one named task /
  one future), not pools — there is no "how many at once" on a single task. To
  run a bounded number of tasks concurrently, compose them under `[par N]` —
  e.g. `[?for [in $t $tasks] [yield [run $t]] [par N]]` or
  `[?map $tasks [using …] [par N]]`. The pool/degree lives in `[par N]`.
- **`[?channel buffer=N]`** is a **queue depth** (how many items may sit
  enqueued), a genuinely different quantity from worker count — left as `buffer=`.
- **HTTP listener workers** stay the **`CX_HTTP_N`** env var (#97), *not* source
  syntax: worker count there is deploy-time ops config (SO_REUSEPORT fds, accept
  fairness), intentionally excluded from the in-source degree spelling.

**Purity is the parallelization license (normative note).** A `pure`
computation (§6.5.1) is **safe to evaluate in parallel and to reorder** — by the
effect-totality lemma it has no capability effect and no shared mutable state, so
there are **no effect races**. The accurate keystone: *pure functions compose
(`cx-stdlib/fp`) and are provably effect-free (§6.5.1), hence free of effect-races
under parallel evaluation.* (`[par]` runs a **bounded** worker pool — `[par N]`
/ `[par max]`, default `min(4, ncpu)` — so an impure body's fan-out is capped by
the width, not unbounded; the retired `CXLS005` "wrap in `[?bulkhead]`" hint no
longer applies, #94.)
**Caveats (do not overclaim):** purity does **not** give *free cancellation* — a
pure CPU loop does not observe cooperative cancellation (§10.5.4) and needs an
explicit `[?check-cancel]` point; nor does it give retry/replay idempotence in
general (an input-dependent `[err]` or nontermination recurs).
Cancellation/cleanup safety comes from §8.10.7 RAII + §10.5.x cap-revocation, not
from purity alone.

### §7.4 Streaming evaluation (`[stream]`)

`[stream]` evaluates lazily: each yielded item is produced as soon as
the input pipeline can produce it. `[stream]` MUST NOT be combined
with `[order-by]` or `[group-by]`; doing so raises a parse-time
`cx-err:CXER0100`.

### §7.5 First generator may be a pattern

If the first generator is a bare pattern literal (not wrapped in
`[in …]`), it is implicitly a document-wide search for the pattern:

```cx
[?for [user $u] [yield $u/name]]
# ≡
[?for [in $u //user] [yield $u/name]]
```

This is the **pattern-generator** form. It desugars to the equivalent
CXPath expression at parse time. Subsequent generators MUST use an
`[in …]` clause.

To destructure each item of an explicit source with a pattern, wrap
both inside `[in [PATTERN] SRC]`:

```cx
[?for [in [user $u] /users/user] [yield $u]]
```

### §7.6 Examples (informative)

```cx
[?for [user $u]
 [in $e $u/emails]
 [where $e@active]
 [yield [pair name=$u/name email=$e]]]

[?for [user @dept=$d $u]
 [group-by $d]
 [yield [row dept=$d count=$count]]]

[?for [user $u]
 [order-by $u/name]
 [limit 10]
 [yield $u]]
```

### §7.7 Iteration idioms (informative)

cx has no imperative loop primitive, and this is deliberate (§3.1: every
form is `[head …]` evaluating to a value; `break`/`continue` are
out-of-band control transfers with no CX⇄XML image). The iteration model
is three orthogonal tools, each with one meaning:

| Need | Tool | Returns |
|------|------|---------|
| **Collect** — transform a source into a sequence/array/map | `[?for]` (§7) | the collected container |
| **Fold** — reduce a source to a single value, carrying state | `[?reduce]` (§8.10.6) | the accumulator |
| **Drive effects** — run a body per item / per step, keep nothing | tail recursion (below), or a streaming/discarding `[?for]` | the loop's final value / `()` |

There is no fourth construct because each effect-loop shape already has a
home. Choose by **what drives the loop**:

**Self-driven loops (a server accept/read loop, a supervisor, a poll/retry
loop, "do this forever") — use tail recursion.** A tail call to a
`[?def]` closure runs in **O(1) native stack** (the evaluator
trampolines tail positions; tail position threads through `[?if]`
branches and `[?let]` bodies). The body MAY perform capability-gated
effects; the accumulator is carried as a parameter:

```cx
# unbounded effect loop (the device-reader case): O(1) stack, no growth
[?def read-loop ($conn)
 [?let [= $chunk [read $conn 4096]]
  [?if [eof? $chunk]
   [then ()]
   [else [?do [publish $store $chunk] [read-loop $conn]]]]]]

# bounded count with a carried accumulator
[?def count-up ($n $acc)
 [?if [= $n 0] [then $acc] [else [count-up [- $n 1] [+ $acc 1]]]]]
```

This is the general loop. The recursive call MUST be in **tail position**
to run in constant stack — a call nested under an operator (e.g.
`[+ [loop …] 1]`) is not a tail call and recurses normally. Mutual
recursion across two closures is *not* trampolined into constant stack;
keep a forever-loop self-recursive.

**Source-driven loops (run a body for each item of a sequence or
generator, discard the results) — use a discarding `[?for]`.** At
statement / top-level position a `[?for]` with no `[order-by]`/`[group-by]`
**streams** (§7.4): each item is produced, the yield body runs (effects
included), and the result is sunk without buffering — an O(1) live set
even over an unbounded generator with a `[take …]`/`[takewhile …]` bound:

```cx
# effect-for-each, streaming, O(1) live set at top level
[?for [in $x $events] [yield [emit $x]]]

# over a generator, bounded
[?for [in $line [$iterate next-line $start]] [takewhile [!= $line null]]
 [yield [log $line]]]
```

The yield value is the per-item effect's result and is discarded here.
Note the asymmetry: in **expression** position (a `[?for]` nested inside
another form) the results are still collected into a container, so a
genuine effect-for-each belongs at statement position where the streaming
path applies.

**O(1) fold (the streaming-reduce case).** `[?reduce]` carries an
accumulator and its body MAY perform effects. Over a bounded integer
`[$range lo hi step?]` it folds with an **O(1) live set** (the range is
generated step-by-step, never materialised); over other sources it
materialises the source first. Use it when the loop genuinely produces a
result value:

```cx
[?reduce [$range 1 1000000] [using [?fn ($a $x) [+ $a $x]]] [init 0]]
```

**Why no `[?loop]`.** A dedicated imperative loop (with `break`/
`continue`/`while`/`forever`) would duplicate capability already present
— `break` ≈ `[takewhile]`, skip ≈ `[where]`, accumulator ≈ `[?reduce]`'s
`[init]`, forever ≈ `[$range lo *]` / self-recursion — while importing
out-of-band control flow that has no homoiconic data image. The three
tools above cover every shape; keeping them orthogonal (one tool, one
meaning) is worth more than a more-powerful single construct.

---

## §8. Directives reference

This section catalogs every directive with its parameters,
semantics, and error matrix. Core directives are complete here; §11
integration directives reference the design doc until normative
treatment lands as part of release-gate work.

### §8.1 Document search

Document search is split across two surfaces: `//pattern` (Path
value, §5.5) handles selection-only cases in one token, and `[?for]`
pattern-generator form (§7.5) provides binding capture, where/order-
by/limit clauses, and projection.

**Parse error:** `[?find` raises `cx-err:CXER0100` (the bare token
is reserved against accidental reintroduction).

### §8.2 `[?match]` — pattern dispatch

#### Single-arm form

```
[?match value pattern [yield expr]]
```

Tests `value` against `pattern` with strict root match. On success,
binds pattern holes and evaluates the `[yield …]` clause. On no-match,
raises `cx-err:CXER0100` (NO_MATCH). See §9.4.

#### Multi-arm form

```
[?match value?
 [case PATTERN ([where GUARD])? EXPR]
 [when PREDICATE EXPR]
 [else EXPR]
]
```

**Recognized by:** presence of at least one `[case …]` or `[when …]`
arm child.

**Evaluation:** top-down, first-match-wins; no fall-through. For each arm:
- `[case PAT … EXPR]` — matches `value` against `PAT` using pattern rules
 (§5.2). Optional `[where GUARD]` clause must also be truthy. No EBV
 on `PAT`; strict match. The arm result is the trailing positional
 `EXPR`.
- `[when PRED EXPR]` — evaluates `PRED` as boolean (EBV per
 `cxdm.md` §6). `value` need not be present for `[when …]` arms.
 The arm result is the trailing positional `EXPR`.
- `[else EXPR]` — fires if no prior arm matched. At most one; must
 be last.

**Value optional:** if `value` is absent, `[case …]` arms are a
parse error; only `[when …]` and `[else …]` arms are valid (SQL
Searched-CASE mode).

**Scrutinee is an inline expression and a §9.2-exempt boundary (normative).** The
`value` slot accepts any `ProgramExpr` (a bound `$ref`, a literal, OR an inline
call such as `[?match [/ 10 0] …]`); a bind-first form (`[?let [= $r EXPR]
[?match $r …]]`) remains valid. The scrutinee slot is **exempt from §9.2
auto-propagation**: when `EXPR` yields `[err …]`, that err is *captured as the
match value* (so a `[case [err …] …]` arm can dispatch on it), **not** propagated
out of the `[?match]`. This is the boundary that lets `[?match]` be the unified
inspection/recovery point (§9.3) — it is the same exemption `[?else]` (§8.13)
relies on. Inside arm bodies and guards, §9.2 propagation is normal.

**No-match behavior:**
- Multi-arm with `[else …]` → the else arm fires.
- Multi-arm without `[else …]` → empty sequence `` (not an error).
- Single-arm form → raises `cx-err:CXER0100` (unchanged).

**Pattern kinds in `[case …]`** (the **uniform** pattern grammar — full
Applicability Matrix in §5.2):
- Element pattern: `[case [user $u] …]`; attr match `[case [err code=X] …]`
  (plain equality, §5.2 rule 9) or `[case [err @code>0] …]` (predicate, rule 6);
  attr value-capture `[case [err @code=$c] …]` (rule 10)
- Scalar literal: `[case 200 …]`, `[case 'ok' …]`, `[case true …]`
  (type-strict, §5.2 rule 8)
- Map literal `[case {a: 1} …]` and map capture `[case {role: $r} …]` (rule 11)
- Sequence `[case (1, 2, 3) …]` (closed) and spread `[case (1, *$rest) …]` (rule 12)
- Array `[case [1, $x, 3] …]` and array spread `[case [1, *$rest] …]` (rule 13)
- Wildcard `_`: matches any value, binds nothing
- Bind-only `$x`: captures value, no shape test
- Type-kind test `[case $n::int …]` / `[case _::float …]` (rule 14)
- CXPath: `[case //prose …]` (type-test)

**Guard on `[case …]`:** the `[where GUARD]` clause uses the same
clause-head as `[?for]` — one guard keyword across all constructs.

```cx
# multi-shape dispatch
[?match $node
 [case [prose $p] [p $p]]
 [case [code $c] [pre $c]]]

# scalar dispatch
[?match $status
 [case 200 :ok]
 [case 404 :not-found]
 [else :err]]

# guarded case
[?match $user
 [case [user $u] [where [>= $u@age 18]] :adult]
 [case [user $u] :minor]]

# predicate-only (SQL Searched-CASE)
[?match
 [when [> $x 100] :big]
 [when [> $x 50] :medium]
 [else :small]]
```

**Errors:**
- `cx-err:CXER0100` — malformed pattern at parse.
- `cx-err:CXER0100` (NO_MATCH) — single-arm form on miss.
- `cx-err:CXER0103` — `[case //path …]` predicate with multi-valued operand.

### §8.3 `[?for]` — comprehension

Specified in §7.

### §8.4 `[?if]` — conditional

```
[?if cond [then thenExpr] [else elseExpr]?]
```

Evaluates `cond` to a boolean (per [`cxdm.md` §6](cxdm.md) EBV).
On truthy, yields `thenExpr`. On falsy, yields `elseExpr` if present,
otherwise yields the empty sequence.

An `[err]` condition is never EBV-coerced: it short-circuits the
conditional and is its result, per §9.2 implicit operand propagation
(an err element would otherwise read truthy — a present element always
does). To
*branch on* an err instead of propagating it, dispatch with `[?match]`
(whose scrutinee slot is the §9.2-exempt boundary, §8.2) or recover
with `[?else]` / `[?fallback]`.

**Errors:** `cx-err:CXER0100` for non-coercible `cond`;
`cx-err:CXER0001` for a body child (after `cond`) that is not a
`[then …]` / `[else …]` clause. The body is **fail-closed**: a bare
positional branch expression (`[?if C 'a' 'b']`) and a typo'd clause
name (`[?if C [thn 'a']]`) are each rejected loudly, naming the
offending child — never a silent `()` (which would be
indistinguishable from a legitimate falsy-with-no-else outcome).
This mirrors `[?let]`'s rejection of a malformed binding clause.

### §8.5 `[?let]` — local binding

```
[?let [= $x expr] body]
```

Evaluates `expr`, binds `$x`, evaluates `body` in the extended scope.
Multiple bindings can be chained or sequenced in one `[?let]`:

```cx
[?let [= $a 1] [= $b 2] [+ $a $b]]
```

### §8.6 `[?fn]` — anonymous function

```
[?fn ($x $y …) body]
```

Yields a function value capturing the surrounding lexical scope.
The parameter list is the leading `(…)` paren group; the body is the
trailing positional ProgramExpr. Invoked via `[$fn args]` — the only
general function-call surface (§6.3); there is no paren-call carrier
(`name(args)` is reserved for XPath built-ins in predicate bodies).

**Function values are not data-serializable.** A function value
captures lexical scope and has no faithful data round-trip, so reaching any
data-serialization boundary with one — the program result, a format
conversion (`--json`/`--xml`/…), or `[cast … data]` — raises
`cx-err:CXER0291` (E_FN_NOT_SERIALIZABLE). Function values remain
first-class *within* code (bound, passed, applied); only their projection to
data is rejected. (Serializing functions as a reference/closure
representation is deferred; the boundary error is the current posture.)

### §8.7 `[?def]` — module-level function

```
[?def name scope=public [returns T] (params) body]
```

**Superseded by §12.** `[?def]` is now a module-top-level directive declaring a
named, **module-scoped** function with **no closure capture**. The
full surface — parameter shapes (positional, named-with-default,
positional-with-default, rest `*$name`), visibility
(`scope=public|private`, private default), purity barewords
(`pure`/`impure`), type clauses (`[returns T]`, `[throws T]`),
`$`-prefixed param names, `$name` body references, order-independent
declaration, and the no-overloading rule — is normatively specified
in [§12.2](#122-def-module-level-functions). For inline /
closure-capturing functions, use `[?fn]` (§8.6).

### §8.8 *(retired — `[?try]` / `[catch]`)*

**Tombstone.** `[?try expr [catch $err handler]]` is **removed** (not deprecated).
It was a redundant second way to do `[?match]`'s job once every catchable failure
is an `[err]` value (§9.2 / §9.3). Handling unifies on `[?match]` (dispatch),
`[?else]` (§8.13) / `[?fallback]` (§10.2.4) (recover), `[?with-error-hook]` (§9.6,
observe), and `!` (panic). `[?try …]` / `[catch …]` are not in the directive
registry (§4.1); a `[?try …]` head raises `cx-err:CXER0100` (unknown directive).
The names are never reused. See §9.3 for the unified model.

### §8.9 `[?pipe]` — pipeline

```
[?pipe seed STAGE …]
```

Threads `seed` through each `STAGE` left-to-right: `seed → STAGE₁(seed) →
STAGE₂(…) → …`. The pipe is **prefix-only**; there is no infix `|` and no
`[through]` wrapper (both retired — see the tombstones below). The canonical and
only surface is `[?pipe …]`; every form is `[head …]`.

**Stages are bare transforms.** A bare stage is a transform applied to the
threaded value; `[?pipe 5 add1 add1]` → `7`. No ceremony keyword wraps it.

#### §8.9.1 Stage invocation (normative)

A stage is an expression the threaded value is supplied to, by this rule:

- **hole-form** — if the stage call contains a partial-application hole `_`
  (`[$f _ 3]`), the value fills it. A pipe threads **exactly one** value, so a
  stage may carry **at most one `_`**; **two or more holes in a pipe stage →
  `cx-err:CXER0100`** (a stage is not a multi-arg partial — the pipe has only one
  value to place). `[$f _ _ 3]` is a binary partial: valid as a *value*, not as a
  *pipe stage*.
- **no-hole form** — a bare name / `$ref` / hole-less `[$call]` receives the value
  **appended as the final positional argument** (`add1` ≡ `[$add1 _]`).
- **non-callable stage** — a literal, data element, map, sequence, or any
  non-function value in stage position is **`cx-err:CXER0100`** (a pipe stage must
  be callable); it does **not** silently pass the value through or replace it.
  Arity mismatch / unknown named arg after the value is supplied →
  `cx-err:CXER0100` (the callee's own arity error), which on an ordinary stage
  propagates (railway) and on a `[tap]` is discarded (§8.9.2).

#### §8.9.2 Named clauses — `[tap]`

Inside `[?pipe]` a small closed set of
reserved clause heads names a pipe-verb; everything else bare is a transform (the
same mechanism as `case`/`when`/`else` in `[?match]`). The vocabulary is
**`{ tap }`**:

- **`[tap f]`** — applies `f` to the current value (same invocation rule as a
  transform, §8.9.1) for its **side effect**; the value **passes through
  unchanged** and `f`'s return is discarded. **Error scope (the discriminator is
  the error code, not how it was raised):** a tap **propagates** an `[err]` iff
  its code ∈ **{`CXER0001` (`CX_PANIC` panic), `CXER0260` (cancellation)}**, and
  **discards** every other `[err]` value (data flow unaffected). In all cases the
  **error-hook still observes** the `[err]` at raise (§9.6) — nothing is silently
  lost, only the *data flow* is unaffected. So a capability denial `CXER0271`
  inside a tap is *discarded for flow but observed*. A function literally named
  `tap` is still reachable as `$tap`/`[$tap]`; only the bracketed `[tap …]` is the
  clause.

```cx
[?pipe $order
  validate
  [tap [$log:info "validated" {id: $_@id}]]   # $_ = the value; logs its id, order flows on
  charge-card
  ship]
```

#### §8.9.3 Railway short-circuit (normative)

If any stage yields `[err …]`, the
remaining stages are skipped — **taps included** — and the `[err]` is the result
(consistent with §9.2). This is `flat-map` on the **failure** channel. The
short-circuit is on **`[err]` ONLY, NOT on absence**: an empty result flows to the
next stage (which may legitimately compute over it — `[$count]` of empty `()` =
`0`). An author wanting *absence* to short-circuit uses `cx-stdlib/fp`'s
`flat-map` or `[?else]` mid-pipe. Keeping `[?pipe]` a single-channel (failure)
railway preserves the four-channel separation (§9.1.2). **Recovery lives OUTSIDE
the pipe** (`[?fallback]` / `[?match]` consume its result; `[?with-error-hook]`
observes raised errors) — the pipe itself only goes forward.

**Tombstones (closed-set documentation; the names are never reused as pipe
surface):**
- Infix `|` is **retired** — it was parse-time sugar for `[?pipe]` (a strict
  subset, through-chain only) with no CX⇄XML image; `5 | f | g` is now a parse
  error. Use `[?pipe 5 f g]`.
- The `[through F]` clause keyword is **dropped** — a bare stage is the transform;
  `[through F]` is replaced by bare `F`.

### §8.10 `[?modify]` — pure-functional update

```
[?modify doc focus action+]
```

Locates nodes in `doc` using CXPath `focus`, applies `action(s)` to each
matched node, and returns a new document. Original `doc` is unchanged
(structural sharing). Grammar: `grammar.ebnf` [141]–[148e].

**Focus:** any `PathExpr` ([130]). Selects a sequence; action applies to
every matched node. Zero matches → returns `doc` unchanged (not an error).

**Action vocabulary** — each action is a clause-child `[name operands…]`:

| Clause | Form | Effect |
|---|---|---|
| `[set VAL]` | replace value | attribute path: replaces attr; element path: replaces body |
| `[delete]` | — | removes matched node / attribute |
| `[using FN]` | lambda | `FN` receives matched node; return value (any kind, including kind-shift — see below) replaces node |
| `[rename NAME]` | bare name | renames element; keeps attrs + body |
| `[set-attr NAME VAL]` | name + expr | adds / overwrites attribute |
| `[delete-attr NAME]` | bare name | removes attribute |
| `[append VAL]` | expr | adds child at end of body |
| `[prepend VAL]` | expr | adds child at start of body |
| `[insert-before VAL]` | expr | new sibling before matched node |
| `[insert-after VAL]` | expr | new sibling after matched node |
| `[replace VAL]` | expr | replaces entire matched node |

Multiple actions on one `[?modify]` apply left-to-right to each
matched node.

`[using FN]` accepts a `[?fn]` lambda:
```cx
[?modify $doc //price [using [?fn ($p) [* $p 1.1]]]]
```

**`[using …]` return-kind — kind-shift allowed**:

The `[using FN]` lambda may return a value of any kind; the returned
value replaces the focus in the modified tree. The result tree's
shape at the modified locus follows the returned kind, regardless of
the focus kind.

```cx
# Element focus, element return — focus replaced by new element.
[?modify $doc //price [using [?fn ($p) [price-tag [$to-int $p]]]]]

# Element focus, string return — focus replaced by the string verbatim.
[?modify $doc //price [using [?fn ($p) [$concat "$" [$to-string $p]]]]]
# Input: [doc [price 100] [price 200]]
# Output: [doc "$100" "$200"]
```

The "render element to string in place" use case is legitimate and
intended. `[using …]` is the general transform action; restricting its
return-kind would throw away its most common use cases (project,
summarize, render). Caller surprise / downstream-selector confusion is
real but documented; a future LSP advisory MAY warn when a kind-shifting
`[using …]` result feeds a downstream CXPath that assumed the focus
kind.

`CXER0104` is **not** raised on legitimate kind-shift. It is retained
for `[using …]` evaluators that fail to produce a value
(non-terminating function, malformed return).

**Pipeline composition** (multi-step updates, §6.4):
```cx
[?pipe $doc
  [?modify //user/@status [set "active"]]
  [?modify //user[= $_@banned true] [delete]]]
```

**Errors:**
- `cx-err:CXER0100` — malformed focus path at parse.
- `cx-err:CXER0104` — `[using …]` evaluator failed to produce a value
 (non-terminating function, runtime trap inside the using body). NOT
 raised on legitimate kind-shift .
- `cx-err:CXER0100` — `[set-attr …]` / `[delete-attr …]` targeting an
 attribute-step path (static error).

### §8.10.5 `[?map]` — sequential / parallel map

```
[?map xs [using fn]] ; sequential
[?map xs [using fn] [par]] ; parallel, unordered (default)
[?map xs [using fn] [par] [ordered]] ; parallel, source-order preserved
```

Applies `fn` to each item in `xs`, returning a sequence of results.

**Children:**
- Positional 1: source sequence `xs` (a `ProgramExpr` evaluating to a sequence).
- `[using fn]` (required): closure value — a unary `[?fn ($x) …]` whose
 body produces the mapped result.
- `[par]` (optional bareword clause): enables parallel evaluation.
- `[ordered]` (optional bareword clause): preserves source order in
 the output. **MUST** be paired with `[par]`; raises
 `cx-err:CXER0100` at parse time when used alone.

**Output order:**

| Form | Order |
|---|---|
| `[?map xs [using fn]]` | source order (sequential — there's only one order) |
| `[?map xs [using fn] [par]]` | unspecified (completion-order; whichever worker emits first) |
| `[?map xs [using fn] [par] [ordered]]` | source order (parallel evaluation, ordered output via completion-tracking + reassembly) |

**`[using …]` closure contract:**
- Pure: no observable side effects on shared state (state-bearing resilience directives like `[?circuit-breaker]` per §10.2.7 are an exception — they explicitly share state across `[?map [par]]` invocations by design).
- Total: terminates on every input (a non-terminating `[using …]` body hangs the eval).

**Errors:**

| Code | When |
|---|---|
| `cx-err:CXER0106` | `[using …]` clause missing or not a closure value (E_USING_NOT_CLOSURE) |
| `cx-err:CXER0100` | `[ordered]` clause without `[par]` |
| `cx-err:CXER0100` | positional source missing |

**Visualization (§10.1.2):** sequential form renders as a single chained arrow `xs → fn → out`; `[par]` form renders as parallel branches with merge node; `[par] [ordered]` adds an order-preservation-buffer node before merge.

**Bounded concurrency (#94):** `[par]` owns its width — `[par]` runs a bounded pool of `min(4, ncpu)` workers by default, `[par N]` caps it at `N` (N ≥ 1), `[par max]` at `ncpu`. An `N < 1` / non-integer / non-`max` token is a parse error (`cx-err:CXER0100`); an explicit `N > 64×ncpu` is the fail-loud sanity cap (`cx-err:CXER0153`), never silently clamped. (`[?bulkhead]` is no longer the concurrency-bounding mechanism — it is demoted to an experimental resilience primitive; the old `CXLS005` "wrap in bulkhead" hint is retired.)

### §8.10.6 `[?reduce]` — sequential / parallel reduce

```
[?reduce xs [using fn] [init z]] ; sequential left-fold
[?reduce xs [using fn] [init z] [par]] ; parallel reduce (associative)
```

Folds `xs` into a single value by repeatedly applying the binary `fn` starting from `z`.

**Children:**
- Positional 1: source sequence `xs`.
- `[using fn]` (required): closure value — a binary `[?fn ($acc $x) …]` whose body produces the next accumulator.
- `[init z]` (required): initial accumulator value `z`.
- `[par]` (optional bareword clause): enables parallel evaluation.
 **MUST NOT** be paired with `[ordered]` (reduce output is a single
 value; ordering is unobservable when `fn` is associative).

**Evaluation order:**

| Form | Visit order |
|---|---|
| `[?reduce xs [using fn] [init z]]` | strict left-fold: `fn(fn(fn(z, x₁), x₂), x₃) …` |
| `[?reduce xs [using fn] [init z] [par]]` | any associative parenthesization — runtime is free to tree-split; result is uniquely determined by associativity contract |

**`[using …]` contract:**
- **Sequential** (no `[par]`): `fn` may be non-associative; left-fold semantics guaranteed.
- **Parallel** (`[par]`): `fn` **MUST** be associative — `fn(fn(a, b), c) == fn(a, fn(b, c))` for all `a, b, c`. `z` **MUST** be the identity for `fn` (e.g. `0` for `+`, `1` for `*`, `''` for string concat). Violations produce undefined results, not a runtime error.

**Errors:**

| Code | When |
|---|---|
| `cx-err:CXER0106` | `[using …]` or `[init …]` clause missing; using value not a closure (E_USING_NOT_CLOSURE) |
| `cx-err:CXER0100` | `[ordered]` clause present (`[ordered]` is meaningless on reduce — output is a single value) |
| `cx-err:CXER0100` | positional source missing |

**Visualization (§10.1.2):** sequential form renders as a chained `($acc, $x) → acc'` box sequence; `[par]` form renders as a tree-split reduction with pairwise combine nodes.

**Bounded concurrency (#94):** `[par]` owns its width — `[par]` chunks into `min(4, ncpu)` workers by default, `[par N]` into `N` (N ≥ 1), `[par max]` into `ncpu`. An `N < 1` / non-integer / non-`max` token is a parse error (`cx-err:CXER0100`); an explicit `N > 64×ncpu` is the fail-loud sanity cap (`cx-err:CXER0153`), never silently clamped. (`[?bulkhead]` is no longer the concurrency-bounding mechanism — it is demoted to an experimental resilience primitive; the old `CXLS005` "wrap in bulkhead" hint is retired.)

### §8.10.7 `[?with-open]` — scoped-resource RAII

```
[?with-open (expr) $binding body+] ; single binding
[?with-open (e1) $a (e2) $b body+] ; multi-binding (sequential)
```

Binds an opened resource to a name for the extent of `body` and
**guarantees** the resource is `close`d when the body's scope exits —
on normal return **and** on error-unwind. This is the CX surface for
the RAII / `with` / `defer close` / try-with-resources pattern. The
canonical consumers are `cx-stdlib/io` handles, locks, and tempfiles
(`stdlib_io.md` §3.4 / §3.6). Grammar:
`grammar.ebnf` `ProgramWithOpen`.

**Slots:**
- `(expr)` (required): a `ProgramExpr` evaluating to a **resource value** — any value carrying the closeable contract (see below). Evaluated **once**, eagerly, before the body.
- `$binding` (required): a `ProgramBinding` naming the resource for the lexical extent of the body; out of scope after the directive.
- `body+` (required): one or more `ProgramExpr`s evaluated in order; the **last** expression's value is the directive's result. An empty body raises `cx-err:CXER0100` at parse.

**Closeable contract:** a value is `[?with-open]`-able
**iff it carries a runtime-recognized close capability** — a nominal
close-contract marker on the handle element (an `on-close=`
attribute the runtime records when the handle is created).
`[?with-open]` invokes **that** registered contract on scope exit; it
does **not** call `io/close` (or any module's `close`) by name. The
contract is therefore **module-agnostic** — the directive has no
dependency on `cx-stdlib/io` or any other module. The current
implementers are `cx-stdlib/io` handles / locks / tempfiles
(`stdlib_io.md` §3.4 / §3.6),
`cx-stdlib/process` handles
(`stdlib_process.md` §2.2,, via
`process/close`), `cx-stdlib/store` handles
(`stdlib_store.md` §3.8, via `store/close`), and the core
**`[?async]` future and `[?worker]` handles** (§10.5.7.1) whose registered close
contract **cancels-and-joins** the task — so structured concurrency is RAII over
these handles. Each is closed by its *own* registered contract, all scoped
uniformly by this one directive. A value carrying no registered close contract is
not `[?with-open]`-able; binding one raises `cx-err:CXER0108`
(E_NOT_CLOSEABLE).

**Multi-binding** chains `(expr) $binding` pairs left-to-right; each
opener may reference an earlier binding. It is exactly nested
single-binding `[?with-open]`s, sugared flat — opens are left-to-right,
closes are **LIFO**. There is no parallel-open form.

```cx
[?with-open [$io:open "/var/log/app.log" "r"] $f
 [?for [in $line [$io:line-iter $f]]
 [where [$strings:contains $line "ERROR"]]
 [yield [$json:parse $line]]]]
```

**Guaranteed close:** when the body's scope exits — for
any reason — every binding that opened successfully has its `close`
invoked exactly once, **innermost-first (LIFO)**:

- **Normal completion** — `close` runs after the last body expression, before the result is returned.
- **Error unwind** — when the body raises (`?`-propagated `[err …]`, `!` panic, or any directive raising), every successfully-opened binding closes LIFO, then the in-flight error continues to propagate **unchanged**. `[?with-open]` neither catches nor rewraps it — pair with `[?match]`/`[?else]`/`[?fallback]` to recover.
- If `(expr)` itself raises (open fails), no binding exists for that position; any **earlier** successfully-opened bindings in a multi-binding form still close LIFO before the open-failure error propagates.

**Lifetime, not value:** `$binding` names the resource
value as returned by `(expr)` — an opaque handle. `[?with-open]` does
not copy, wrap, or mutate it; the body uses it exactly as a `[?let]`
binding. The only behavior over `[?let]` is the guaranteed-`close`-on-exit
edge. A body may `[?modify]` documents *read through* the handle freely
(§8.10); the handle itself is not a `[?modify]` target, and a produced
document outlives the scope as an ordinary value.

**Iterator interaction:** an `io` lazy iterator
(`line-iter` / `glob-iter`, ) closes its backing handle when
**exhausted**; `[?with-open]` is the **orthogonal** guarantee that the
handle closes on **scope exit** regardless of exhaustion. The common
iterate-to-EOF case thus has two close attempts — `close` is
**idempotent** (closing an already-closed handle is a no-op; it does
**not** raise `CXER3409`, which is for *operations* on a closed handle).
`[?with-open]` is precisely what covers the cases the iterator does not:
an early `[where …]` short-circuit, a `[take …]` prefix, or an error before
EOF leaves the iterator un-exhausted. Programs SHOULD wrap any handle
feeding a lazy iterator in `[?with-open]` rather than rely on exhaustion.

**`close`-failure surfacing:** if a binding's `close`
itself raises during scope exit, it is **never silently swallowed** — on
normal completion the `close` error becomes the directive's result error;
on error-unwind the in-flight body error takes priority and the `close`
error is attached as a `cause=` attribute (when none is set) or dropped to a
diagnostic (a `close` failure must never *mask* the original failure).
Remaining outer bindings still close LIFO.

**Errors:**
- `cx-err:CXER0100` — empty body, missing `(expr)` / `$binding`, or malformed binding at parse.
- `cx-err:CXER0108` — `(expr)` evaluates to a value carrying no registered close contract (not closeable; E_NOT_CLOSEABLE).
- Any error raised by `(expr)` (the open) or by `close` propagates per D4 / D7; `[?with-open]` introduces no new `CXER` code of its own.

### §8.10.8 `[?with-scope]` — dynamic-scoped context

```
[?with-scope {fields-map} body+]
```

Establishes a **dynamic-scoped context** — a fields map — for the
dynamic extent of `body`, and **guarantees** the prior context is
restored when the body's scope exits — on normal return **and** on
error-unwind. It is the CX surface for thread-local / dynamic-variable
contextual data (the MDC / `contextvars` / `tracing`-span pattern).
The canonical consumer is `cx-stdlib/log`, which reads the active
context and auto-attaches its fields to every log event emitted inside
the extent (`stdlib_log.md` §2.3 / §3.3).
Grammar: `grammar.ebnf` `ProgramWithScope`. It is the **sibling**
of `[?with-open]` (§8.10.7): both are block-scoping directives with a
guaranteed exit edge — `[?with-open]` restores by `close`-ing a
resource, `[?with-scope]` restores by popping a dynamic context.

**Children:**
- `{fields-map}` (required, positional 1): a `ProgramExpr` evaluating to a **map** of context fields. Evaluated **once**, eagerly, before the body. A non-map raises `cx-err:CXER0109` (E_SCOPE_NOT_MAP) at evaluation.
- `body+` (required, trailing positional): one or more `ProgramExpr`s evaluated in order; the **last** expression's value is the directive's result. An empty body raises `cx-err:CXER0100` at parse.

```cx
[?with-scope {request-id: "abc123" user-id: 42}
 [$log:info "processing started"] # carries request-id + user-id
 [?http-client target=$url method="get"]
 [$log:info "processing done"]] # same fields, no re-passing
```

**Dynamic extent, not lexical:** the active context is
visible to **every** evaluation during the body's dynamic extent —
including transitively inside functions *called* from the body, not
merely text lexically inside the block. A `log/info` deep in a called
helper sees the context without the fields being threaded through that
helper's signature. The context stack is **thread/coroutine-local**:
a scope established on one thread is not *shared* (live-aliased) with
another. A `[?worker]` / `[?async]` body **inherits a snapshot of the
spawning thread's active context taken at spawn time** (in-process
capture-at-spawn): the child starts with a *copy* of the parent's
active context and is **isolated** thereafter — a `[?with-scope]` push
or context mutation in the child does not affect the parent, and vice
versa. Pass `inherit-context=false` on `[?async]` / `[?worker]`
(§10.5.1 / §10.4.6) to start the spawned body with an **empty**
context. Capture-at-spawn is **in-process only** — it does not
propagate context across a *process* boundary (the Service-tier
distributed case, deferred .

**Nesting and merge:** `[?with-scope]` blocks nest. On
entry the directive's `{fields-map}` is **merged over** the active
context — `merge(outer, inner)` with the inner map winning for shared
keys. Merge is shallow (key-level). On scope exit the *outer* context
is restored exactly; the inner overrides do not leak out.

**Restore on every scope exit:** when the body's scope
exits — for any reason — the context pushed by this directive is popped
and the prior context restored, exactly once:

- **Normal completion** — restored after the last body expression, before the result is returned.
- **Error unwind** — when the body raises (`?`-propagated `[err …]`, `!` panic, or any directive raising), the context is restored as the stack unwinds past this directive's frame, then the in-flight error continues to propagate **unchanged**. `[?with-scope]` neither catches nor rewraps it — pair with `[?match]`/`[?else]`/`[?fallback]` to recover.

**Logging-agnostic:** `[?with-scope]` knows nothing about
logging; it establishes a dynamic context that whatever reads the active
context consumes. `cx-stdlib/log` is the current reader — at emit time
each `log/*` call merges the active context **under** its own `fields=` attribute
(call-site fields win for shared keys). The `log/current-scope` *function*
(a `[?def]`, not a directive) returns the active context for diagnostics.

**Errors:**
- `cx-err:CXER0100` — empty body or missing `{fields-map}` at parse.
- `cx-err:CXER0109` — `{fields-map}` does not evaluate to a map (E_SCOPE_NOT_MAP).
- `[?with-scope]` introduces no new `CXER` code of its own.

### §8.11 Integration directives (§10)

The integration-capability directives — `[?retry]`, `[?timeout]`,
`[?circuit-breaker]`, `[?fallback]`, `[?rate-limit]`, `[?bulkhead]`
(§10.2); `[?http-service]`, `[?http-client]` (§10.3); `[?worker]`,
`[?channel]`, `[?send]`, `[?receive]`, `[?try-send]`,
`[?try-receive]`, `[?close]`, `[?select]` (§10.4); `[?async]`,
`[?await]`, `[?await-all]`, `[?await-any]`, `[?await-race]`,
`[?cancel]`, `[?check-cancel]` (§10.5) — are normatively specified
in §10. This section's reference is for completeness only.

### §8.12 `[?str]` — compile-time string interpolation

```
[?str "Hello {$name}, you have {$user/unread-count} unread"]
```

`[?str]` is the **compile-time** string-interpolation directive: it
takes a single string literal and produces a `string` by substituting
each `{…}` **interpolation hole** with the rendered value of the
expression inside it. It is the scope-aware companion to
the runtime `cx-stdlib/strings` `format` function — `[?str]` resolves
`$`-bindings in the **enclosing lexical environment** at evaluation
time and is type-checked against them, whereas `format` substitutes a
template loaded at runtime (`spec/std-lib/strings.md` §8).

**Hole body — any expression (#66).** What is admitted inside `{…}` is
**any program expression**: a bare `$binding`, a path navigation
(`$x/child`), a filtered query (`$x//y[@pred]`), arithmetic
(`{[+ $a $b]}`), or a call (`{[$strings:upper $name]}`). The hole is
re-parsed through the program parser and evaluated in the enclosing
scope; the *result* must be a scalar (see Rendering). (The earlier
binding-paths-only restriction is lifted — `[?str "up={[$strings:upper $name]}"]`
now works directly, no intermediate `[?let]` needed. One limit: a hole
cannot contain a literal `}`, since the template scan stops at the first
`}` — wrap such cases in a bound value.)

**Rendering.** Each hole's value is rendered to text the same way a
scalar renders in canonical emit (`canonical.md`): a `string` is its
characters, other scalars their canonical lexical form. A hole whose
expression resolves to a non-scalar (element / sequence / map) raises
`cx-err:CXER0100` at evaluation. A `$`-binding not in scope is the
ordinary unbound-binding error.

**Literal braces.** `{{` and `}}` denote literal `{` and `}` in the
template text. An unbalanced `{`/`}`, an empty hole `{}`, or a hole
body that fails to parse as an expression is a malformed directive
shape and raises `cx-err:CXER0100` (PARSE_ERROR) at parse time.

`[?str]` introduces no new `CXER` code of its own; it requires no
capability (it is pure — it reads only in-scope values and emits
text).

### §8.13 `[?else]` — value-or-default coalesce

```
[?else EXPR DEFAULT]
```

Yields `EXPR`'s value when it is a usable result, otherwise `DEFAULT`. This is the
genuine `getOrElse` / `unwrap_or` — the single extraction point that unifies the
**absence** and **failure** channels (§9.1.2) while preserving the `[invalid]` and
null-vs-missing distinctions.

**`DEFAULT` is lazy** — evaluated **only** when `EXPR` is `[err]` or absence. So
`[?else [risky] [expensive]]` never computes `[expensive]` on the happy path, and
`[?else 42 [/ 1 0]]` → `42` (the default's divide-by-zero is never evaluated).

**Truth table (normative).** `[?else]` is **NOT** EBV-coalescing — only the empty
sequence and `[err]` trigger the default:

| `EXPR` yields | `[?else EXPR DEFAULT]` |
|---|---|
| `[err …]` (failure) | → `DEFAULT` |
| empty node-set / empty sequence (absence) | → `DEFAULT` |
| `null` (a present null **value**) | → `null` (passes through) |
| **EBV-false present values: `false`, `0`, `''`, `[]`, `{}`** | → **the value (passes through)** |
| `[invalid …]` (reported problems) | → the `[invalid]` value (passes through) |
| a non-empty sequence / any other value | → the value (passes through) |

Conceptually `[?else]` is principled sugar over `[?match]` (§8.2): `[?match EXPR
[case [err $e] DEFAULT] [case <empty> DEFAULT] [case $v $v]]`, where `<empty>` is
the empty node-set / empty sequence **specifically**. Like `[?match]`'s
inline-scrutinee slot (§8.2), `EXPR` is a **§9.2-exempt boundary**: an `[err]`
from `EXPR` is *captured* as the value to coalesce, not auto-propagated.

```cx
# the buried divide-loop collapses to logic-first form
[?for [in $p pairs] [yield [?else [/ $p/a $p/b] 0]]]
```

`[?else]` introduces no new `CXER` code; it requires no capability.

### §8.14 `[?do]` — evaluate for effect (owner ruling 2026-07-21, #550)

```
[?do E …]
```

The blessed **evaluate-for-effect sequencing form** (resolves the #530
fail-loud gap). One-or-more expressions evaluate **in order**; their values
are **discarded** — except the first `[err …]` result, which **propagates
immediately** per §9.2 instead of vanishing in an unobserved dummy `[?let]`
binding (the pre-`[?do]` idiom `[= $_x EFFECT]` silently swallowed a failed
effect's evidence). Success yields **`null`** — a present unit (§9.1.2.1 role
2b), never absence (absence would read as "nothing happened"; something
did).

```cx
[?do [$fabric:publish $f 'orders' $ev {}]
     [$fabric:ack $sub $seq]]        # a failed publish STOPS the sequence and
                                     # propagates; the ack never runs
```

`[?do]` is not a loop and carries no control flow beyond ordering; it
composes inside `[?loop]` bodies (§8.15) exactly as anywhere else. No new
`CXER` code; no capability (the body's effects carry their own gates).

### §8.15 `[?loop]` — condition-driven loop with explicit exits (owner ruling 2026-07-21, #550)

```
[?loop [= $x INIT]… BODY]
  [break V?]          ; exit — the loop's value is V (bare [break] → null)
  [continue V…?]      ; repeat — rebind the declared bindings positionally
```

THE condition-driven loop: **anonymous trampolined tail recursion** with
declared state. `[?for]` (§8.3) remains the data comprehension; `[?loop]`
covers unknown-trip-count, condition- and effect-driven iteration — the
territory that previously forced a named tail-recursive `[?def]` with
threaded params and marker returns. Semantics are exactly the tail call the
form desugars to: **no mutation** — `[continue V…]` rebinds the declared
loop bindings for the next pass (arity-checked: all of them positionally,
or a bare `[continue]` for unchanged state); the engine drives the passes
in O(1) native stack (the #60 trampoline's guarantee without its
boilerplate).

**All-explicit tail contract (normative).** Each pass's body value MUST be
a `[break …]` or `[continue …]` element — `break`/`continue` are reserved
clause-heads in `[?loop]` body tail position (§3.5). Any other tail value
raises `cx-err:CXER0100` ("loop body must end in [break …] or
[continue …]"). The implicit exit of Clojure's `loop/recur` (any non-recur
value silently becomes the result) is **deliberately rejected**: a branch
that forgets its exit word is a diagnostic, never a silent wrong answer. A
`[break]` with multiple values yields them as a sequence. An `[err …]` tail
value propagates as itself — the §9.2 failure channel outranks the tail
contract. `[?while COND BODY]` is **not admitted** (a second, weaker form —
stateless by construction under immutable bindings — for zero new power;
the stateless world-observing pump is the zero-binding `[?loop]`).

```cx
[?loop [= $i 1] [= $acc 0]
  [?if [> $i 5] [then [break $acc]]
    [else [continue [+ $i 1] [+ $acc $i]]]]]      # ⇒ 15

[?loop [= $tries 50]                              # bounded drain
  [?if [<= $tries 0] [then [break [?element "err" [?attr "reason" "drain-budget"]]]]
    [else [?let [= $r [step-in $sock]]
      [?if [= $r 'pong'] [then [break [?element 'pong']]]
        [else [continue [- $tries 1]]]]]]]]
```

No new `CXER` code (`CXER0100` covers the contract violations); no
capability.

---

## §9. Errors

### §9.0 Posture — one conveyor belt

**Data posture (normative).** Errors, absence, and reported problems ride the
**same conveyor belt** as the data; you only stop the belt at the edges. The
happy path *is* the program — handling is a postfix mark (`?`/`!`), a
self-threading pipeline (`[?pipe]`, §8.9), a value-or-default coalesce (`[?else]`,
§8.13), or a boundary dispatch (`[?match]`, §8.2), and **never** a wrapper that
out-indents the logic it guards. Code signals "nothing here" via the **absence
channel** (the empty node-set / empty sequence, §9.1.2), never via a `null`
scalar; `null` is a present data value.

**Effect posture (normative; cross-ref `security.md` §1).** A computation's
*effect* is the set of capabilities it can exercise, **denied by default and
checked at every effect point** (`CXER0271`). "This performs no external effect"
is a property the runtime *enforces* (§6.5.1 effect totality, `security.md`
§1/§4), not a convention a library hopes you honor. Type / `[returns T]`
conformance, by contrast, is **advisory** (`--strict` only, §12.2.5).

### §9.1 Errors are values

Every error is a CX value. An `err` is **plain data**:
scalar fields are **attributes**, structured fields are **child
elements** (the *simplest adequate* form):

```cx
[err code='cx-err:CXERnnnn'
 message='human-readable description'
 where='/path/to/site'?
 [cause [err …]]? # optional, for wrapped errors
 [errors [err …] …]? # optional, for multi-error collections
 <subsystem-specific scalar fields as attributes,
 structured fields as child elements>]
```

The `code` attribute is mandatory and MUST be in the `cx-err:CXERnnnn`
namespace. This namespace requirement governs errors **raised** by
directives / built-ins. An `[err …]` value **constructed as ordinary
program data** (e.g. a test input, or a foreign error preserved verbatim in
a `cause` chain) MAY carry an application-defined `code`; such values are
data, not raised errors. `message` is mandatory. `where` is recommended
for debuggability. `cause` (a child element) is present when the error
wraps an underlying err. Reads follow the axis: `$err@code` /
`$err@message` (attributes), `$err/cause` / `$err/errors` (children).

Subsystem-specific fields are defined per directive in §8 and the
design doc §11 — scalar fields as attributes, structured fields as
child elements.

#### §9.1.1 Success values

A directive or expression that yields a **value** returns that value
**directly — no envelope**. A directive whose result is a pure
status/acknowledgement (no payload), e.g. `[?send]`, returns bare
`[ok]`; when it carries a payload it returns `[ok VALUE]`. There is **no
`[result status=ok|err …]` wrapper** — that form is retired and is not a
CX value. Outcomes are thus `[ok …]` / a raw value on success and
`[err …]` (§9.1) on failure, distinguished by head (`ok` vs `err`), read
via `[?match]` or the `?`/`!` operators (§9.2).

**`[err]` is control-flow, not a general "problems" container.** Because an
`[err …]` value auto-propagates through call arguments (§9.2), it models an
*abort-and-propagate* failure — a denied capability, a parse fault, an I/O
error. A function whose job is to **report problems as data** — a validator
enumerating field violations, a linter, a diff, a type-checker, an assertion
collector — must NOT return `[err …]` for its normal output: that output is a
*deliverable the caller inspects*, and wrapping it in `[err …]` would make it
short-circuit every inspection call before that call could run. Such functions
return a distinct, inspectable outcome head (e.g. `cx-stdlib/validate`'s
`[invalid [violation …] …]`); they raise a real `[err code=cx-err:… ]` only for
genuine control-flow failures (e.g. a malformed schema). This keeps
"errors-as-data" and "errors-as-control-flow" categorically separate.

#### §9.1.2 The four outcome channels (normative; load-bearing)

CX has **four** disjoint outcome channels. Every later error/recovery/composition
rule (§8.9 pipe, §8.13 `[?else]`, §8.2 `[?match]`, §9.2 propagation, the
`cx-stdlib/fp` protocol) is defined in terms of them, so they are settled once,
here.

| Channel | Representation | Propagation | Meaning |
|---|---|---|---|
| **Value** | any normal node — including a present `null` scalar (a value, **not** absence) | flows | a usable result |
| **Absence** | the **empty node-set / empty sequence ONLY** (`cxdm.md` §1) | flows **inertly** | a pure, in-memory, optional read/query found nothing |
| **Failure** | `[err code= message= …]` (§9.1) | **auto-propagates** through call args & operators (§9.2) | an abort-and-propagate fault |
| **Reported problems** | a distinct inspectable head, e.g. `[invalid [violation…]]` (§9.1.1) | flows **as a value** (does NOT auto-propagate) | a problem-reporter's structured output (validator / linter / diff / type-checker) |

**Absence is the empty node-set / empty sequence, and nothing else.** The other
EBV-false values — `false`, `0`, `''`, the empty array `[]`, the empty map `{}` —
are **present values that flow**, not absence. CX adds **no new `nil` scalar**.

**The four-way split is disjoint.** Absence, failure, and reported-problems are
three distinct, non-overlapping outcomes (value being the fourth, trivial one).
This disjointness is what lets `[?else]` (§8.13) coalesce on *absence + failure*
while deliberately **passing `[invalid]` through** — a reported problem is an
*answer*, not a missing or failed value, so swallowing it would destroy the
distinction §9.1.1 exists to make.

##### §9.1.2.1 Anti-purgatory — three distinct "nothings"

Java's null hell came from three things together — *conflation*
(null meant uninitialized = missing = absent = error-sentinel), *silent flow*,
and *crashes* (NPE on deref). CX engineers against all three by keeping **three
"nothings" disjoint**:

1. **empty node-set / empty sequence = absence** ("nothing here"). Propagates
   **inertly** (ops on empty → empty — the XPath antidote: no pointer to deref,
   no NPE). It is *also* the **sequence-monad zero / `None`** (`cx-stdlib/fp`) —
   the same object serves the absence channel and the Maybe/List functor.
2. **`null` scalar = a present value**, **never absence**. Operations on `null`
   are **total**: every builtin / operator yields a defined value or a clean
   `[err]`, **never a crash**. `null` legitimately appears in two roles: **(2a)
   data-null** ("explicitly null" — JSON/SQL round-trip fidelity) and **(2b)
   unit-null** — a successful no-payload / unit return from a side-effect op (e.g.
   `cx-stdlib/log`). Both are *present values*; both are kept.
3. **`[err]` = a fault** (auto-propagates, §9.2).

Two standing rules make this stick:
- **(a) Posture** (§9.0) — code signals "nothing" via the **absence channel**,
  never via `null`; `null` is data-null or unit-null only.
- **(b) No-conflation guard (normative; conformance-checked).** **No builtin
  returns `null` to mean "absent."** The third bucket, **absent-null** (a builtin
  that historically returned `null` for an unset/missing-but-optional read), is a
  **violation** to migrate to the empty channel. `null` (data/unit) / empty
  (absence) / missing / `[err]` / `[invalid]` are non-overlapping.

(`Some(null)` vs `None` is `(null)` vs `()` — recovered for free by sequence
cardinality (`cx-stdlib/fp`), with no boxed `Option` type.)

##### §9.1.2.2 The "not found" taxonomy (normative)

Whether a "not found" rides
the **absence** channel or is a **failure `[err]`** is drawn by **criteria**, not
a per-case list: a "not found" is **absence** iff it is a *pure, in-memory,
optional structural access*; it is a **fault `[err]`** otherwise.

| "Not found" case | Channel | Criterion |
|---|---|---|
| CXPath miss, optional attr, out-of-range index, `map-get` missing key | **absence** (empty) | pure, in-memory, optional |
| **programmatic** required read (code demands a value — e.g. a required env var, a schema that must resolve) | **`[err]`** | requiredness makes the miss a fault at the call site |
| a **problem-reporter** (validator) finds a required **field** missing | **`[invalid …]`** | validators report violations as inspectable data (`validate.md`), NOT `[err]` — the reported-problems channel |
| missing file, network 404, store-get on absent external key, worker-handle-not-found | **`[err]`** | external / effectful resource (I/O-class fault) |
| unknown i18n key, unknown module / import | **`[err]`** | authoring / configuration error |

A present `null` is a **value** (the null-vs-missing distinction, `cxdm.md` §1),
never absence.

##### §9.1.2.3 Optionality IS the absence channel — no `[some]`/`[none]`

The "Maybe / Option" role is played by the **native
absence channel**: a present value is "some", the empty node-set / empty sequence
is "none". The extractor is **`[?else]`** (§8.13, `getOrElse`); absence
propagates inertly through pure ops as `map`/`flat-map` would. CX ships **no**
`[some]` / `[none]` heads and **no** `option` functor instance — the
sequence at cardinality ≤ 1 *is* Maybe (`cx-stdlib/fp`). A boxed optional
distinct from the empty channel is **not** admitted (it would be a second
"nothing" competing with absence, reintroducing exactly the ambiguity §9.1.2.1
removes).

### §9.2 Propagation: `?` and `!`

The postfix `?` operator unwraps a value or propagates an err:

- If the operand is `[err …]`, `?` **propagates the err value outward** through
 the enclosing propagation boundaries — the function body and `[?for]` — and
 yields it to the enclosing scope. `[?match]` is **not** a propagation *target*:
 it is an inspection/recovery boundary that acts when it *receives* an err value
 as its scrutinee (§8.2), so a propagated err is recovered wherever a `[?match]` /
 `[?else]` / `[?fallback]` consumes it, not by jumping to a lexically-nearest one.
- If the operand is any other value, `?` yields that value unchanged.

The postfix `!` operator panics on err. For known-infallible operations:

```cx
config := load-config! # panic if load fails
```

`!` raises a **catchable value-form** `cx-err:CXER0001` (`CX_PANIC`, §9.4): a panic
is an `[err …]` value that propagates per the rules above and is recoverable by
`[?match]` (or `[?else]`/`[?fallback]`) exactly like any other err. `CXER0001` is
**dedicated to `!`** — directives never raise it (§9.4). `!` differs from `?` only
in *what* err it raises (a fresh `CX_PANIC`, vs the propagated original), not in
catchability.

**Implicit operand propagation.** Beyond the explicit `?`, an `[err …]`
**argument propagates automatically** — an operation cannot proceed on a failed
operand. This holds **uniformly** for every operand-consuming form: a
head-dispatch call `[$fn … [err …] …]` AND an operator-element `[= a [err …]]`,
`[+ [err …] 1]`, `[< [err …] 0]`, `[and [err …] x]` alike. The first err-valued
operand short-circuits the form and is yielded as its result (left-to-right),
rather than being compared, atomized, or coerced. **Guard and predicate slots
are operand-consuming forms** and follow the same rule (#348): the `[?if]`
condition (§8.4), `[?match]` `[when …]` conditions and case-level `[where …]`
guards (§8.2), `[?filter]` / `[?partition]` predicate results (incl. the
head-dispatch `[$filter]` twin, §6.3), and the `[?for]` `[where …]` /
`[takewhile …]` / `[dropwhile …]` clauses (§7.2) — an err-valued guard is
never EBV-coerced or skip-coerced; it short-circuits the whole form and is
its result. To *inspect* an err instead of
propagating it — read its `@code`, compare it, branch on it — pass it to
`[?match]` (whose scrutinee slot is a §9.2-exempt boundary, §8.2), `[?else]`, or
`[?fallback]`, or bind it first (`[?let [= $e EXPR] …]`) and use path navigation,
which does not propagate (the same errors-as-data-vs-control-flow boundary as
§9.1.1).

**Errors are values, uniformly (normative).** **Every catchable failure is an
`[err]` value that propagates per the rules above; the evaluator raises NO
out-of-band thrown failure for any condition a handler is meant to catch.** With
this, `[?match]` (the value-propagation boundary) recovers exactly what a handler
needs to. Load-time failures (parse / `--strict` static errors of the *running*
program) precede evaluation and are surfaced to the host — the program never runs,
so they are not in-program catchable; a program that evaluates *another* source
(`[?cx include]` / `cx:eval`) catches *its* parse err as a value.

#### §9.3 Handling — the unified model

Handling unifies on four orthogonal roles (the `[?try]`/`[catch]`/`[on-error]`
surface is **retired**, §8.8):

| Role | Mechanism |
|---|---|
| **Dispatch / catch-and-handle** | `[?match]` (§8.2) over the `[err]` channel — discriminates by err shape/code (`[case [err @code='X'] …]`), a **superset** of a catch-all `[catch]` |
| **Recover (sugar)** | `[?else]` (§8.13, default on err + absence) · `[?fallback]` (§10.2.4, err-aware, `$err` bound) |
| **Observe / instrument** | `[?with-error-hook]` (§9.6) — a `raise`-stage `observe` fires the moment an err is built, independent of recovery |
| **Assert / panic** | `!` postfix → a value-form `CXER0001` (`CX_PANIC`), catchable by `[?match]` like any err |

```cx
# dispatch + recover (replaces try/catch): inline scrutinee, no extra indent
[?match [$parse $input]
  [case [err @code=$c] [fallback reason=$c]]
  [else $v]]

# err-aware recovery without [else] boilerplate
[?fallback [$parse $input] [recover-with [fallback reason=$err/@message]]]

# per-iteration handling folds into a yield-body [?match]/[?else]
[?for [in $u users]
 [yield [?match [$validate $u]
   [case [err $e] [skip user=$u reason=$e/@code]]
   [else $u]]]]
```

The catchability taxonomy (every failure class is a value-form-catchable `[err]`
or a load-time non-runtime failure — there is **no** uncatchable-at-runtime
category, including `!`):

| Failure class | When | Value-form-catchable? |
|---|---|---|
| parse / load / `--strict` static errors **of the running program** | before eval | **No** — surfaced to host; the program never runs |
| directive-shape / arity (`CXER01xx`) | eval | **Yes** |
| runtime type mismatch, unbound name | eval | **Yes** |
| capability denial (`CXER0271`) | eval (effect point) | **Yes** |
| arithmetic (`CXER0101` div-zero, `CXER3000` overflow) | eval | **Yes** |
| I/O / resource error | eval | **Yes** |
| cancellation (`CXER0260`) | eval | **Yes** (§10.5 precedence) |
| **`!` postfix panic (`CXER0001` / `CX_PANIC`)** | eval | **Yes — value-form, matchable** |

`finally`-style cleanup is `[?with-open]` (RAII, §8.10.7), retained and orthogonal.

### §9.4 CX code error code reservation

Per (amended 2026-05-21), CX code reserves the
`cx-err:CXER0100–CXER0299` range. Assignments by subsystem:

| Range | Subsystem |
|---|---|
| CXER0001 | Generic-core panic (reserved, outside CX-code range — see note below) |
| CXER0100 – CXER0105 | Pattern / match / iterator / application / arithmetic errors |
| CXER0106 – CXER0119 | Core directive shape errors (`[?map]`, `[?reduce]`, `[?with-open]`, `[?with-scope]`) |
| CXER0120 – CXER0139 | For-comprehension errors |
| CXER0140 – CXER0149 | Resilience: retry / timeout |
| CXER0150 – CXER0159 | Resilience: circuit-breaker / fallback / rate-limit / bulkhead |
| CXER0160 – CXER0179 | Services (HTTP server) |
| CXER0180 – CXER0199 | Clients (HTTP client) |
| CXER0200 – CXER0203 | Channels (narrowed — see note below) |
| CXER0204 – CXER0215 | Module system (§§12.1–12.5) |
| CXER0216 | Module system — member visibility (§12.6) |
| CXER0217 – CXER0219 | Reserved (formerly Channels range) |
| CXER0220 – CXER0229 | Workers (narrowed — see note below) |
| CXER0230 – CXER0239 | Purity / predicate (§§8.6, 12.2 — `:pure` annotation) |
| CXER0240 – CXER0249 | Futures (narrowed — see note below) |
| CXER0250 – CXER0259 | Retired — `[?cx include]` errors are parse-time data-parse `E` codes (`E901–E911`, cxdm.md §11); range reserved, not reassigned |
| CXER0260 – CXER0269 | Cancellation (narrowed — see note below) |
| CXER0270 – CXER0279 | Host capability / runtime environment |
| CXER0280 – CXER0289 | Visualization / renderer |
| CXER0290 – CXER0299 | Type coercion / cast (`cast` builtin, §6.5 P6) |
| L001 – L020 | Lint codes (emitted by `cx_lint`, `core/abi.md §2.18`) |

**CXER0001 (`CX_PANIC`) — the `!` panic, catchable value-form.** `CXER0001` is
the symbolic name `CX_PANIC` for the err raised by the postfix `!` operator
(§9.2), and is **dedicated to `!`**. It is a **catchable value-form** `[err]`: `!`
constructs `[err code='cx-err:CXER0001' …]`, which propagates per §9.2 and is
recoverable by `[?match]` / `[?else]` / `[?fallback]` like any other err (there is
no uncatchable-at-runtime category — §9.3 taxonomy). It sits **outside** the
CX-code reserved range (`CXER0100–CXER0299`) because it is a runtime / VM-level
concern, not a directive-level error. **No directive raises `CXER0001` directly**:
directive-level shape, arity, and type errors are allocated to dedicated wire
codes in the CX-code range (`CXER0100` for application/arity, `CXER0106`,
`CXER0108`, `CXER0109`; see §9.5) — any stray call-shape `CXER0001` raise in an
implementation is a conformance bug to re-code (arity → `CXER0100`).

**Range amendment — module system.** The original Channels
allocation (CXER0200–CXER0219) used only four codes (CXER0200..0203
— see §9.5 wire-code map). The module system (§§12.1–12.5)
claims CXER0204..CXER0215; the range table is split accordingly.
CXER0216 is the member-visibility error (§12.6); slots
CXER0217..CXER0219 stay reserved for any future Channels growth.
No existing wire code is renumbered.

**Range amendment (`cast` builtin) — type-coercion codes.** The
original Visualization allocation (CXER0280–CXER0299) used only two
codes (CXER0280..0281 — RENDER_FAILED / UNRENDERABLE_DIRECTIVE; see
§9.5 wire-code map). The `cast` builtin (§6.5 P6, locked
2026-05-23) claims a new "Type coercion / cast" range at
CXER0290..0299. Visualization narrows to CXER0280..0289 (with 8
reserved codes for future renderer growth at CXER0282..0289). No
existing wire code is renumbered.

**Range amendment — purity codes.** The
original Workers allocation (CXER0220–CXER0239) used only three codes
(CXER0220..0222 — see §9.5 wire-code map). The range is split: Workers
narrows to CXER0220..0229 (with 7 reserved codes for future Workers
growth at CXER0223..0229), and a new purity / predicate range claims
CXER0230..0239. No existing wire code is renumbered.

**Range amendment — host capability codes.** The
original Cancellation allocation (CXER0260–CXER0279) used only one
code (CXER0260 — CANCELLED). The range is split: Cancellation
narrows to CXER0260..CXER0269 (with 9 reserved codes for future
cancellation-related growth at CXER0261..CXER0269), and a new host-
capability / runtime-environment range claims CXER0270..CXER0279, of which
CXER0270 (WALL_SLEEP_UNSUPPORTED_IN_HOST), CXER0271 (E_CAP_DENIED,
`security.md`), and CXER0272 (E_STACK_EXHAUSTED — the evaluator's native-stack
headroom guard; see §9.5) are allocated. No existing wire code is renumbered.

**Range amendment — Futures + retired include range.** The
original Futures allocation (CXER0240–CXER0259) used only two codes
(CXER0240..0241 — AWAIT_ALL_FAILED / AWAIT_TIMEOUT; see §9.5
wire-code map). Futures narrows to CXER0240..0249 (8 reserved codes
for future growth at CXER0242..0249). The CXER0250..0259 sub-range
was briefly assigned to `[?cx include]`, but include is resolved at
parse/assembly time, so its errors are data-parse `E` codes
(`E901–E911`, cxdm.md §11); CXER0250..0259 is therefore **retired**
(reserved, not reassigned). No existing wire code is renumbered.

**Lint code namespace.** Lint codes (`L001..L020`) are
emitted by `cx_lint` (`core/abi.md §2.18`); they share the diagnostic
wire format with `S` schema codes and `W` write-warning codes but live
in a separate code namespace so consumers can filter lint output by
code prefix. `L005` delegates to `cx_validate` semantics (and surfaces
the underlying `S001..S020` code in the diagnostic's message body) but
uses its own `L`-prefixed code at the lint API. Built-in default rules
`L001..L007` are registered in §9.5; `L008..L020` are reserved for
future built-in rule growth. Custom rulesets supplied via the
`cx_lint` `ruleset` parameter MAY use codes outside this range.

### §9.5 Symbolic-name → wire-code map (normative)

Every error raised by a directive carries a wire-format code in
the `cx-err:CXERnnnn` namespace The
symbolic names in this spec's prose are documentation labels; the
wire-level code is always the CXER number. The mapping is append-only

symbolic names used in §§5–10 error tables and their wire codes.

| Symbolic name | Wire code | Subsystem | Where raised |
|---|---|---|---|
| CX_PANIC | `cx-err:CXER0001` | Generic-core | Unrecoverable runtime panic raised by postfix `!` (§9.2) — outside CX-code range |
| PARSE_ERROR | `cx-err:CXER0100` | Pattern | DURATION / pattern syntax parse failure |
| E_ARITH_DIVIDE_ZERO | `cx-err:CXER0101` | Numeric | Division or modulo by zero in `[$div]` / `[$mod]` / `[$idiv]` (§6.5) — a runtime arithmetic trap |
| E_PARTIAL_APP | `cx-err:CXER0102` | Application | Partial-application hole `_` in a rest (`*$xs`) position, or a partial applied with more arguments than held positions (§6.3a) |
| MULTI_VALUED_PREDICATE | `cx-err:CXER0103` | Pattern | `[case //path …]` predicate with multi-valued operand (§8.2) |
| USING_FAILED | `cx-err:CXER0104` | Pattern / modify | `[using …]` evaluator failed to produce a value — non-terminating function or runtime trap inside the using body (§8.10); NOT raised on legitimate kind-shift |
| ITERATOR_ALREADY_WALKED | `cx-err:CXER0105` | Iterator | Second walk of a single-use Iterator (external stream / non-rewindable source)
| E_USING_NOT_CLOSURE | `cx-err:CXER0106` | Core directive | `[?map]` / `[?reduce]` `[using …]` clause missing or value is not a closure (§8.10.5 / §8.10.6) |
| E_NOT_CLOSEABLE | `cx-err:CXER0108` | Core directive | `[?with-open]` `(expr)` evaluates to a value carrying no registered close contract (§8.10.7) |
| E_UNKNOWN_TYPE_TAG | `cx-err:CXER0107` | Type-tag | Unknown `TypeName` in `::TypeName[]` annotation (grammar.ebnf [26], §3.7) |
| E_SCOPE_NOT_MAP | `cx-err:CXER0109` | Core directive | `[?with-scope]` `{fields-map}` does not evaluate to a map (§8.10.8) |
| E_ENRICH_NOT_ERR | `cx-err:CXER0110` | Core directive | `[?with-error-hook]` `[enrich [using FN]]` FN returned a non-err value (§9.6) — enrich MUST return an err |
| RETRY_EXHAUSTED | `cx-err:CXER0140` | Resilience | `[?retry]` after `max=` attempts |
| TIMEOUT | `cx-err:CXER0141` | Resilience | `[?timeout]` elapsed |
| BREAKER_OPEN | `cx-err:CXER0150` | Resilience | `[?circuit-breaker]` tripped |
| RATE_LIMITED | `cx-err:CXER0151` | Resilience | `[?rate-limit]` exhausted |
| BULKHEAD_FULL | `cx-err:CXER0152` | Resilience | `[?bulkhead]` saturated |
| BAD_REQUEST | `cx-err:CXER0160` | Services | HTTP 400 — malformed request |
| UNAUTHORIZED | `cx-err:CXER0161` | Services | HTTP 401 — `[auth …]` returned err |
| NOT_FOUND | `cx-err:CXER0162` | Services | HTTP 404 — no resource matched |
| REQUEST_TIMEOUT | `cx-err:CXER0163` | Services | HTTP 408 — `read-timeout=` exceeded |
| PAYLOAD_TOO_LARGE | `cx-err:CXER0164` | Services | HTTP 413 — body > `max-body-bytes=` |
| INTERNAL_ERROR | `cx-err:CXER0165` | Services | HTTP 500 — unhandled err in handler body |
| SHUTTING_DOWN | `cx-err:CXER0166` | Services | HTTP 503 — in shutdown drain |
| CONNECTION_REFUSED | `cx-err:CXER0180` | Clients | TCP connect failure |
| TLS_HANDSHAKE_FAILED | `cx-err:CXER0181` | Clients | TLS negotiation failed |
| INVALID_RESPONSE | `cx-err:CXER0182` | Clients | Server response could not be parsed |
| CHANNEL_CLOSED | `cx-err:CXER0200` | Concurrency | Receive from closed-drained channel; send to closed channel |
| SEND_TIMEOUT | `cx-err:CXER0201` | Concurrency | `[?try-send]` buffer-full timeout |
| RECV_TIMEOUT | `cx-err:CXER0202` | Concurrency | `[?try-receive]` empty-channel timeout |
| CHANNEL_ALREADY_CLOSED | `cx-err:CXER0203` | Concurrency | Second `[?close]` on same channel |
| WORKER_PANIC | `cx-err:CXER0220` | Concurrency | Worker body raised unhandled err |
| WORKER_CANCELLED | `cx-err:CXER0221` | Concurrency | Worker terminated via `[?cancel]` |
| WORKER_NOT_FOUND | `cx-err:CXER0222` | Concurrency | `[?worker-handle]` lookup miss |
| AWAIT_ALL_FAILED | `cx-err:CXER0240` | Async | `[?await-all]` saw ≥ 1 non-done future |
| AWAIT_TIMEOUT | `cx-err:CXER0241` | Async | `[?await $f timeout=DURATION]` exceeded |
| CANCELLED | `cx-err:CXER0260` | Async | Operation observed cancellation |
| WALL_SLEEP_UNSUPPORTED_IN_HOST | `cx-err:CXER0270` | Host capability | Bare `[?sleep]` in wasm host without `_cx_wasm_set_wall_sleep(true)` opt-in |
| E_CAP_DENIED | `cx-err:CXER0271` | Host capability | Operation requires a capability absent from the active set (`security.md` §4); carries `capability=` + `resource=` |
| E_STACK_EXHAUSTED | `cx-err:CXER0272` | Host capability | Non-tail evaluation recursion neared the current thread's native-stack limit; the evaluator raises this catchable value-form err (recoverable per §9.1) with headroom to spare instead of ever crashing. Tail calls are trampolined and never trigger it; rewrite the hot recursion tail-recursively, iterate with `[?for]`/`[?reduce]`, or raise the host stack limit |
| RENDER_FAILED | `cx-err:CXER0280` | Visualization | Renderer could not produce output |
| UNRENDERABLE_DIRECTIVE | `cx-err:CXER0281` | Visualization | Directive shape outside §10.1.2 locked render rules |
| E_DEF_NOT_TOP_LEVEL | `cx-err:CXER0204` | Module system | `[?def]` written inside an expression / function body |
| E_DEF_REDECLARED | `cx-err:CXER0205` | Module system | Same-name `[?def]` declared more than once in a module |
| E_TYPE_ARG_MISMATCH | `cx-err:CXER0206` | Module system | `--strict` — call argument fails parameter type annotation |
| E_TYPE_RETURN_MISMATCH | `cx-err:CXER0207` | Module system | `--strict` — function return fails `[returns T]` annotation |
| E_LIB_INSECURE_TRANSPORT | `cx-err:CXER0208` | Module system | `[?lib]` resolver uses `http://`; HTTPS required |
| E_LIB_INTEGRITY_MISMATCH | `cx-err:CXER0209` | Module system | Fetched module bytes do not match the SRI hash recorded in `cx.lock` |
| E_LIB_IMPORT_CYCLE | `cx-err:CXER0210` | Module system | Cyclic module import graph detected at load time |
| E_LIB_UNPINNED | `cx-err:CXER0211` | Module system | Transitive dependency not present in `cx.lock` |
| E_LIB_MALFORMED_DIRECTIVE | `cx-err:CXER0212` | Module system | `[?lib]` / `[?def]` / `[?const]` directive shape rejected at parse |
| E_LIB_UNRESOLVABLE | `cx-err:CXER0213` | Module system | Resolver string does not match any of file / registered / HTTPS forms |
| E_CONST_CYCLE | `cx-err:CXER0214` | Module system | Cyclic `[?const]` dependency detected during pass 2 topological sort |
| E_CONST_BODY_FAILED | `cx-err:CXER0215` | Module system | Eager `[?const]` expression raised an error during load |
| E_VISIBILITY | `cx-err:CXER0216` | Module system | Access to a non-exported (private) member of another module (§12.6) |
| E_PREDICATE_NOT_PURE | `cx-err:CXER0230` | Purity / predicate | PredicateExpr body calls an impure function or builtin |
| E_RESERVED_BINDING_USE | `cx-err:CXER0231` | Purity / predicate | Reference to `$_position` or `$_last` outside a predicate body |
| E_RESERVED_BIND_NAME | `cx-err:CXER0232` | Purity / predicate | `(bind $_)` on a path step — underscore reserved for `$_` |
| E_PURITY_VIOLATION | `cx-err:CXER0233` | Purity / predicate | `[?def]` declared `pure` (explicit or default) calls an impure function or builtin |
| E_PURITY_UNCLASSIFIED_BUILTIN | `cx-err:CXER0234` | Purity / predicate | Reference to a builtin missing from the closed purity classification list |
| E_COMPUTED_NAME_NONSCALAR | `cx-err:CXER0235` | Dynamic construction | `[?element]`/`[?attr]`/`[?entry]`/`[?name]` computed name/key expr is non-scalar (§6.4.2.1) |
| E_COMPUTED_NAME_SHAPE | `cx-err:CXER0236` | Dynamic construction | Computed name is not a valid NCName, or an empty `[rename]` name (§6.4.2.1) |
| E_UNQUOTE_SEQUENCE | `cx-err:CXER0237` | Dynamic construction | `[?unquote]` yielded a multi-item sequence in a single-node slot — use `[?splice]` (§6.4.3) |
| E_TREE_NOT_EVALUABLE | `cx-err:CXER0238` | Dynamic construction | `[?eval]` — tree node not evaluable as code in its position (§6.4.4.1) |
| E_CAST_FAILED | `cx-err:CXER0290` | Type coercion / cast | `[cast value kind-atom]` could not coerce: parse failure, unsupported source kind (e.g. atom → int), unknown target kind, or null source (§6.5 P6) |
| E_FN_NOT_SERIALIZABLE | `cx-err:CXER0291` | Type coercion / cast | A function value reached a data-serialization boundary (program result, conversion, or `[cast … data]`); function values capture lexical scope and have no faithful data round-trip (§8.6) |
| *(include errors)* | `cx-err:E901–E911` | Include (§13) | `[?cx include]` is parse/assembly-time; its errors are data-parse `E` codes — see the registry in `cxdm.md §11` (the `CXER0250–0259` range is retired, §9.4) |
| UNRESOLVED_IDREF | `L001` | Lint (`cx_lint`) | `@id` IDREF that does not resolve to a `#id` anchor in the document (per `cxdm.md §4.2`) |
| UNUSED_ANCHOR | `L002` | Lint (`cx_lint`) | `#id` anchor declared but never aliased / referenced |
| UNRESOLVED_MERGE | `L003` | Lint (`cx_lint`) | Element with `merge` ref to a nonexistent anchor |
| UNUSED_ATTRIBUTE | `L004` | Lint (`cx_lint`) | Schema-declared attribute never read in the document (only when a schema is supplied via the `ruleset` parameter) |
| SCHEMA_VIOLATION | `L005` | Lint (`cx_lint`) | Schema violation; delegates to `cx_validate` semantics and surfaces the underlying `S001..S020` code in the message body |
| DEPRECATED_FORM | `L006` | Lint (`cx_lint`) | Deprecated directive form (e.g., retired surfaces) |
| EMPTY_PATTERNED_ATTR | `L007` | Lint (`cx_lint`) | Empty string supplied for an attribute carrying a `pattern=` constraint |

Per-directive error tables in §§10.1.5, 10.2.6, 10.3.5, 10.4.5,
10.5.5, and §§12.1.5 / 12.2.6 / 12.3.4 cite the same wire codes;
this table is the unifying source.
Gate 2 (§11.4.1) enforces 1:1 symbolic ↔ wire agreement across
sites.

#### §9.5.1 Canonical messages (normative)

Each code below carries this canonical `message` on its `[err …]` value
(§9.1, where `message` is mandatory). `‹placeholder›` segments are filled
from the err's structured attributes (e.g. `attempts=`, `elapsed=`,
`name=`, `module=`); the message text is otherwise fixed. Codes marked
**(site-specific)** are catch-alls whose message is defined per
occurrence — the raising site (and the conformance fixture) supplies it.
Lint (`L00x`) and include (`E90x`) codes are diagnostics / data-parse
codes, not `[err …]` values, and are excluded. Append-only.

**Determinism scope (normative).** For a code with a FIXED message in this
table, conformance fixtures and the implementation MUST emit that exact message
byte-for-byte. For a **(site-specific)** catch-all (`CXER0001` / `CXER0100` /
`CXER0104`), the message PROSE is implementation-defined — only the error CODE
and the error POSITION are byte-stable. The error POSITION is always reported as
`line:col` (1-based), never a byte offset. Byte-compatible CLI output therefore
covers the parsed document, the error CODE, the POSITION, and the process exit
code — but NOT the free-form prose of a site-specific catch-all.

| Wire code | Canonical message |
|---|---|
| `CXER0001` | (site-specific) |
| `CXER0100` | (site-specific) |
| `CXER0101` | division by zero |
| `CXER0102` | invalid partial application: hole in rest position or over-application |
| `CXER0103` | predicate operand is multi-valued |
| `CXER0104` | (site-specific) |
| `CXER0105` | single-use iterator already walked — second walk is not permitted |
| `CXER0106` | [using] clause missing or not a closure |
| `CXER0107` | unknown type ‹name› |
| `CXER0108` | value has no close contract |
| `CXER0109` | [?with-scope] argument is not a map |
| `CXER0110` | enrich hook returned a non-error value |
| `CXER0140` | retry budget exhausted after ‹attempts› attempts |
| `CXER0141` | operation timed out after ‹elapsed› |
| `CXER0150` | circuit breaker open |
| `CXER0151` | rate limit exceeded |
| `CXER0152` | bulkhead saturated |
| `CXER0160` | bad request |
| `CXER0161` | unauthorized |
| `CXER0162` | not found |
| `CXER0163` | request timeout |
| `CXER0164` | payload too large |
| `CXER0165` | internal server error |
| `CXER0166` | service shutting down |
| `CXER0180` | connection refused |
| `CXER0181` | TLS handshake failed |
| `CXER0182` | invalid response |
| `CXER0200` | channel closed |
| `CXER0201` | send timed out |
| `CXER0202` | receive timed out |
| `CXER0203` | channel already closed |
| `CXER0204` | [?def] not at module top level |
| `CXER0205` | [?def] ‹name› redeclared |
| `CXER0206` | argument does not match parameter type ‹type› |
| `CXER0207` | return value does not match declared type ‹type› |
| `CXER0208` | insecure http:// resolver; https required |
| `CXER0209` | module integrity mismatch against cx.lock |
| `CXER0210` | module import cycle |
| `CXER0211` | transitive dependency ‹name› not pinned in cx.lock |
| `CXER0212` | malformed module directive |
| `CXER0213` | module resolver ‹resolver› matches no module |
| `CXER0214` | [?const] dependency cycle |
| `CXER0215` | [?const] initializer failed |
| `CXER0216` | access to non-exported member ‹name› of module ‹module› |
| `CXER0220` | worker panicked |
| `CXER0221` | worker cancelled |
| `CXER0222` | worker ‹handle› not found |
| `CXER0230` | predicate body is not pure |
| `CXER0231` | ‹name› used outside a predicate body |
| `CXER0232` | underscore binding name is reserved |
| `CXER0233` | pure function ‹name› calls an impure operation |
| `CXER0234` | builtin ‹name› missing purity classification |
| `CXER0240` | [?await-all] saw a non-done future |
| `CXER0241` | await timed out after ‹timeout› |
| `CXER0260` | operation cancelled |
| `CXER0270` | wall-clock sleep unsupported in this host |
| `CXER0271` | ‹capability› capability denied for ‹resource› |
| `CXER0280` | render failed |
| `CXER0281` | directive cannot be rendered |
| `CXER0290` | cannot cast ‹value› to ‹kind› |
| `CXER0291` | function value cannot be serialized |

---

### §9.6 Error hooks — observe / enrich / report

Beyond *handling* errors (§9.3: `[?match]`, `[?else]`, `[?fallback]`), CX
provides hooks that **observe**, **enrich**, and **report** errors as they move
through their lifecycle, without tangling those concerns into recovery logic.
This is the admitted mechanism that keeps the elegant `[?pipe]`/`[?else]` path
fully observable: an `observe` hook attached at the **`raise`** stage fires the
moment an err is built, **independent of recovery** — so even an err that
`[?else]`/`[?match]` handles immediately is still seen (no "drop to a handler to
log" handcuff).
The directive is `[?with-error-hook]`; a `cx-errors.cx` `[error-pipeline …]`
document configures the same hooks program-wide.

An error's lifecycle is `raise → propagate* → (handle ⟂ report)`. Hooks attach
to it in four roles:

| Role | Signature | Effect |
|---|---|---|
| `observe` | `(err) → ignored` | pure side-effect; the err is unchanged and keeps propagating exactly as if the hook were absent |
| `enrich` | `(err) → err'` | returns a derived err (added context/attributes) that keeps propagating; **MUST return an err** — a non-err return raises `cx-err:CXER0110` (E_ENRICH_NOT_ERR); enrich never recovers (recovery is `[?match]`/`[?else]`/`[?fallback]`) |
| handle | — | the §9.3 recovery surface (`[?match]`/`[?else]`/`[?fallback]`; terminal recovery) |
| `report` | format + sink(s) | the unhandled-at-host terminal: render the err via a `formatting.md` profile and route it to one or more sinks |

**Lifecycle stages.**

| Stage | Fires when |
|---|---|
| `raise` | an `[err …]` is constructed within the body's dynamic extent |
| `propagate` | a `?`/`!` unwinds an err across a directive or function-scope boundary inside the body |
| `handle` | a `[?match]`/`[?else]`/`[?fallback]` inside the body recovers an err — observers run **before** the handler body |
| `report` | an err reaches a host boundary (top-level output / log / conversion) **unhandled** |

`observe` may attach at any stage; `enrich` attaches at `propagate`; `report` is
the unhandled-at-host terminal. Each active hook fires once per `(err, stage)`.
Nested hooks compose most-recently-entered-first (LIFO), like
`[?with-open]`/`[?with-scope]`.

**Inline surface** (grammar `[166]`):
```
[?with-error-hook
  ([observe [using FN]] | [enrich [using FN]] | [report …])+
  BODY]
```
- `[observe [using FN]]` — `FN: (err) → ignored`. `FN` MAY be impure (an effect
  sink, exempt from the §8.6 purity restrictions); its return is discarded.
  **Sugar (O3): `[observe FN]` ≡ `[observe [using FN]]`** (the `[using …]` wrapper
  is optional; both parse to the same AST).
- `[enrich [using FN]]` — `FN: (err) → err'`, run at `propagate`. **Sugar (O3):
  `[enrich FN]` ≡ `[enrich [using FN]]`.**
- `BODY` is any ProgramExpr; its value (or err) is the directive's result,
  unchanged by `observe`/`report` (and replaced only by an `enrich`'s derived
  err, which still propagates — never recovered).

**Report stage = format + sink(s).**
```
[report
  [format profile=PROFILE]        ; a formatting.md profile renders the err value
  [sink SINK+]]                   ; one or more sinks; the rendered err routes to each
```
Sink vocabulary: `[sink stderr]`, `[sink [log level=error]]`,
`[sink [http url='…' …]]`, `[sink [using FN]]` (custom). Sinks run in declaration
order. A network sink (`[sink [http …]]`) requires the `net` capability
(`security.md`); a denied or failed sink is a **hook fault**.

**Program-wide surface.** A `cx-errors.cx` `[error-pipeline …]` document
configures the hooks for a whole program (built-in + custom; selected/extended
like `cx-format.cx`):
```
[; cx-errors.cx ]
[error-pipeline
  [enrich [using [?fn ($err)
    [?modify $err . [set-attr service checkout-api] [set-attr env $DEPLOY-ENV]]]]]
  [report
    [format profile=canonical]
    [sink [log level=error]]
    [sink [using $ship-to-tracker]]]]
```

**Hook faults.** If a hook `FN` (or a sink) itself raises, the observed err's
propagation is **unaffected** — a hook MUST NOT hijack the error channel. The
hook fault is suppressed from the program error path and surfaced out-of-band
(impl-defined: a diagnostic / stderr); it is not a program-level err. The one
exception is the `enrich` contract: an `enrich` FN returning a *non-err* value
raises `CXER0110` on the program path, because enrich's purpose is to produce
the propagating err.

**Examples.**
```
[; observe: log every error raised in the body, then let it propagate ]
[?with-error-hook [observe [using [?fn ($err) [$log $err@code $err@message]]]]
  [?for [in $u //user] [yield [$validate $u]]]]

[; report: audit errors surfacing to the host ]
[?with-error-hook
  [report [format profile=canonical] [sink [using $audit]]]
  [$run-pipeline $input]]
```

Secret redaction (`cxdm.md` §12) applies before any `report` sink renders an
err, so a sink shipping to a remote tracker cannot leak a secret that was in
scope at the failure site.

**Observer ordering** is fixed: `handle`-stage observers run **before** the
handler body, so an observer always sees the raw caught err. The inline grammar
is `[166]`/`[166a-g]` (closed). The program-wide `[error-pipeline]` document
reuses the same clauses; its `cx-errors.cx` validation schema lands in
`schema.md` (forthcoming).

---

## §10. Integration capabilities

CX code provides five integration capability families as part of the
language. Each is normatively specified in this section.

### §10.1 Sequence-diagram visualization

#### §10.1.1 Commitment

Every well-formed CX program **MUST** be renderable to a
sequence/activity diagram per the rules in §10.1.2. Renderers
**SHALL** produce structurally equal diagrams across implementations
when given the same source. Diagrams **MUST** round-trip: every
diagram produced by a conforming renderer parses back to a CX tree
that is `cx-diff`-equal to the source.

The renderer is itself a CX program; an implementation **MAY**
optimize the renderer in native code, but the observable output
**MUST** match the reference renderer's output bit-for-bit on every
fixture in `conformance/code.txt` (gate #9).

#### §10.1.2 Locked rendering rules

Each directive **MUST** render per the following table. A directive
not listed below **SHALL** raise `cx-err:CXER0281` (UNRENDERABLE_DIRECTIVE).

> **Program-source surface is CX-only.** The renderer's input is a
> CX program AST parsed from CX surface syntax per §4. JSON, XML,
> YAML, TOML, and Markdown are output projections of program *results*
> (per `abi.md` `output_target`); they are not program-source inputs.
> The wasm playground gate (§11.6 gate 17) honors this constraint —
> the Source pane accepts CX only. Editor / CI tooling that wants to
> render diagrams from a non-CX source must first transform the input
> into a CX program by some other means.

| Directive | Render |
|---|---|
| `[?for]` (sequential) | Loop activation in caller's lane |
| `[?for [par]]` / `[?map [par]]` / `[?reduce [par]]` | Parallel branches |
| `[?if]` / `[?match]` | Alternative branches (predicate at branch point); a `[case [err …] …]` arm renders the recovery branch |
| `[?retry]` | Wrapped activation with retry-annotation badge |
| `[?timeout]` / `[?circuit-breaker]` / `[?fallback]` / `[?rate-limit]` / `[?bulkhead]` | Wrapped activation with policy-annotation badge |
| `[?http-service]` | Endpoint with `[resource]` children as message handlers |
| `[?worker]` | Independent swimlane |
| `[?channel]` | Channel lane between workers |
| `[?send]` / `[?receive]` / `[?try-send]` / `[?try-receive]` | Arrows between swimlanes |
| `[?select]` | Multi-arrow choice point |
| `[?async]` | Detached activation in a new swimlane |
| `[?await]` / `[?await-all]` / `[?await-any]` / `[?await-race]` | Synchronization barrier |
| `[?cancel]` | Cancellation arrow + barrier |

#### §10.1.3 Bidirectional editing

Renderers **SHOULD** support bidirectional editing — diagram edits
mapped back to source edits. Edits that map to valid AST
transformations **MUST** round-trip cleanly. Edits that do not (e.g.
reordering positional children of a directive) **MUST**
be rejected in the diagram UI with a pointer to the source location.

The canonical AST is always the source of truth; the diagram is a
projection.

#### §10.1.4 Reference renderer

The reference renderer ships three packaging formats sharing
one renderer core:

1. **CLI:** `cx diagram <file>` emits SVG, PNG, or Mermaid output.
 Flags **MUST** support: `--format {svg|png|mermaid}`, `--direction
 {lr|tb}`, `--detail {full|condensed}`.
2. **Web component:** `<cx-diagram src="...">` **MUST** render
 client-side without server round-trip.
3. **LSP CodeLens:** the CX language server **MUST**
 expose per-directive "render diagram" CodeLens entries that open
 the web component inline.

#### §10.1.5 Errors

| Code | Symbolic name | When |
|---|---|---|
| `cx-err:CXER0280` | RENDER_FAILED | Renderer could not produce output |
| `cx-err:CXER0281` | UNRENDERABLE_DIRECTIVE | Directive shape outside §10.1.2 |

---

### §10.2 Resilience directives

Resilience directives wrap an inner body and apply a policy to its
evaluation. They **MUST** compose by nesting; the outermost directive
runs first (its policy sees the policies of inner directives).

Errors from inner bodies remain CX `[err …]` values; resilience
policies catch and decide per-policy whether to retry, fail, fall
back, or pass through. On terminal failure, every resilience
directive **MUST** emit a structured `[err …]` per §10.2.7.

#### §10.2.1 `[?retry]`

```
[?retry
 max=INT ; required, > 0
 backoff=STRATEGY ; default exponential
 delay=DURATION ; default 100ms
 jitter=MODE ; default equal
 [on PREDICATE] ; default fn($e){true}; retry iff truthy
 BODY ; trailing positional, required
]
```

Evaluates `BODY`. If `BODY` returns `[err …]`, the implementation
**MUST** invoke the `[on …]` predicate with the err. If it returns
truthy and the attempt count is < `max`, sleep for the backoff-
computed delay (§10.2.5) and retry. Otherwise return the err to the
caller wrapped as `cx-err:CXER0140`.

#### §10.2.2 `[?timeout]`

```
[?timeout DURATION ; positional 1, required
 BODY ; trailing positional, required
 [on-timeout EXPR] ; optional
]
```

Evaluates `BODY` with a hard deadline. If `BODY` completes within
DURATION, its result is returned. If DURATION elapses, the
implementation **MUST** issue `[?cancel]` to `BODY` (cooperative per
§10.5.4) and return: the `[on-timeout EXPR]` clause's expression
evaluated if present; otherwise
`[err code=cx-err:CXER0141 elapsed=DURATION]`.

> **Implementation status (honest, #96):** the deadline is enforced against
> **logical time** — a `[?sleep DUR mock]` in `BODY` advances the clock and trips
> the timeout. A body that blocks on **real wall-clock** time (a bare
> `[?sleep DUR]`, a blocking syscall) is **not** interrupted today: it runs to
> completion and its value is returned even past DURATION, because real-time
> cooperative cancellation requires the production scheduler (§10.5.4), which is
> not yet wired on the default eval path. Do not rely on `[?timeout]` as a
> production deadline against real-time-blocking work until that lands.

#### §10.2.3 `[?circuit-breaker]`

```
[?circuit-breaker
 threshold=RATIO ; required, 0.0–1.0
 window=DURATION ; required, rolling-window length
 reset=DURATION ; required, half-open delay after trip
 min-samples=INT ; default 10
 name=STR ; optional, state-identity key (§10.2.7)
 BODY ; trailing positional, required
]
```

Three states: closed (passes through), open (rejects with
`cx-err:CXER0150`), half-open (allows one probe).

- **Closed → open** when failure ratio in the rolling `window`
 exceeds `threshold`, with at least `min-samples` recorded.
- **Open → half-open** after `reset` elapses.
- **Half-open → closed** if probe succeeds.
- **Half-open → open** if probe fails.

When open, the directive **MUST** return
`[err code=cx-err:CXER0150 until=INSTANT]` without invoking BODY.

#### §10.2.4 `[?fallback]`

```
[?fallback
 PRIMARY ; positional 1, required
 [recover-with SECONDARY] ; required
]
```

Evaluates PRIMARY. If PRIMARY returns `[err …]`, evaluates SECONDARY
and returns its value (which may itself be `[err]` — `[?fallback]`
does not wrap that case). Otherwise returns PRIMARY's value.

**`$err` is bound in `SECONDARY` (normative, O2).** Inside the `[recover-with
SECONDARY]` scope, `$err` is bound to PRIMARY's `[err …]` value, so recovery can
introspect the failure — `[?fallback [$store $rec] [recover-with [response
status=500 reason=$err/@message]]]`. This makes `[?fallback]` the err-**aware**
recovery combinator (the `recoverWith` of the recovery ladder: `[?else]` §8.13 for
don't-care value-or-default · `[?fallback [recover-with …]]` for err-aware recover
with `$err` bound and success passing through · `[?match]` §8.2 for multi-way
dispatch — minimal and non-overlapping). On the success path `$err` is not bound
(SECONDARY is not evaluated; the default is lazy).

#### §10.2.5 `[?rate-limit]`

```
[?rate-limit
 max=INT ; required, > 0
 per=DURATION ; required
 name=STR ; optional, state-identity key (§10.2.7)
 BODY ; trailing positional, required
]
```

Token-bucket rate limiting. Permits at most `max` invocations per
`per` window. If the limit is exceeded, returns
`[err code=cx-err:CXER0151 retry-after=DURATION]` where DURATION is
the time until a token frees.

#### §10.2.6 `[?bulkhead]`

```
[?bulkhead
 max-concurrent=INT ; required, > 0
 queue=INT ; default 0
 name=STR ; optional, state-identity key (§10.2.7)
 BODY ; trailing positional, required
]
```

Bounds concurrent invocations. If `max-concurrent` permits are in
use and the `queue` is full, returns `[err code=cx-err:CXER0152
max=INT]`. Queued requests wait FIFO for an available concurrency permit.

> **EXPERIMENTAL — implementation status (honest, #96).** Only the
> immediate-reject path is production-real (`CXER0152` when saturated). The two
> distinctive features are not: (1) the bounded `queue=`/backpressure (FIFO
> wait-for-slot) engages **only under the cooperative scheduler**
> (`[?test-concurrent]`); in ordinary eval and the real `spawn`/reactor paths a
> saturated bulkhead immediately rejects, it does not queue. (2) the slot
> acquire is a non-atomic read-modify-write, so the cap is **not reliably
> enforced under real thread contention** (a shared named bulkhead across
> parallel workers can exceed `max-concurrent` via lost updates). For production
> load-shedding prefer `[?rate-limit]` (§10.2.5) or a buffered `[?channel]`.

**Not the `[par]` bounding mechanism (#94).** `[par]` now owns its width as a
bounded worker pool — `[par N]` / `[par max]`, default `min(4, ncpu)` — so a
`[using …]` body no longer needs a `[?bulkhead]` wrap to cap fan-out, and the
old `CXLS005` "wrap in bulkhead" lint is retired. A same-source-text
`[?bulkhead]` shared across parallel workers still shares its in-flight + queue
state per §10.2.7 (subject to the contention caveat above). See §8.10.5
(`[?map]`) and §8.10.6 (`[?reduce]`).

#### §10.2.7 Common parameters

**DURATION syntax.** `Nus | Nms | Ns | Nm | Nh` (e.g. `100ms`,
`30s`). Negative or non-parseable durations **MUST** raise
`cx-err:CXER0100` (PARSE_ERROR).

**Backoff formulas** (delay before attempt N, N ≥ 1):

| STRATEGY | Formula |
|---|---|
| `constant` | `delay` |
| `linear` | `delay × N` |
| `exponential` | `delay × 2^(N-1)` |
| `fibonacci` | `delay × fib(N)` |

**Jitter modes** (D = pre-jitter delay):

| MODE | Formula |
|---|---|
| `none` | `D` |
| `full` | `uniform(0, D)` |
| `equal` | `D/2 + uniform(0, D/2)` |
| `decorrelated` | `uniform(delay, last_delay × 3)` |

**Error code matrix.**

| Code | Symbolic | Carrier attrs/clauses |
|---|---|---|
| `cx-err:CXER0140` | RETRY_EXHAUSTED | `attempts=INT [cause [err …]]` |
| `cx-err:CXER0141` | TIMEOUT | `elapsed=DURATION` |
| `cx-err:CXER0150` | BREAKER_OPEN | `until=INSTANT` |
| `cx-err:CXER0151` | RATE_LIMITED | `retry-after=DURATION` |
| `cx-err:CXER0152` | BULKHEAD_FULL | `max=INT` |

**State identity (stateful directives).** `[?circuit-breaker]`,
`[?rate-limit]`, and `[?bulkhead]` carry state across invocations.
State is keyed by the *lexical position* of the directive's
source-text occurrence: every evaluation of the same source-text
node — including iterated evaluation inside `[?for]` or
`[?map [par]]` — observes and updates the same state instance. Two
directives at distinct source-text positions are independent.

Each of these three directives accepts an optional common parameter:

```
name=STR ; default: lexical position
```

When `name=` is present, state identity is keyed by the string
instead of by lexical position. Two source-text positions with the
same `name` share state; this is the mechanism for cross-position
sharing (e.g. one rate-limit budget enforced by callers in different
modules). When `name` is absent, lexical-position keying applies as
above.

Implementations **MUST** make `name=` collision across the same
program evaluate as a *single* shared state instance regardless of
source position. Implementations **MAY** scope state to the current
evaluation context (one CX program invocation); state **MUST NOT**
persist across program invocations except via explicit external
storage outside the language semantics.

#### §10.2.8 Composition

Resilience directives **MUST** nest. Standard composition reads
top-down:

```cx
[?retry max=3
 [?timeout 10s
 [?circuit-breaker threshold=0.5
 [?http-client target="..." method="get"]]]]
```

Reading: retry up to 3 times a 10s-timeout-bounded call gated by a
50% circuit-breaker. If the breaker opens, retry sees
`[err code=cx-err:CXER0150]` and decides whether to keep retrying
(default `[on …]` predicate returns truthy → yes; user can scope by
overriding `[on …]`).

---

### §10.3 Services and clients

Service definitions are CX shapes. Resource definitions are
children. Request and response are CX values with locked schemas.
The full service definition **MUST** be queryable, transformable,
and visualizable per §10.1.

#### §10.3.1 `[?http-service]`

```
[?http-service on=PROTOCOL port=INT name=STRING
 [tls TLS-CONFIG] ; optional (structured token)
 read-timeout=DURATION ; default 30s
 write-timeout=DURATION ; default 30s
 max-body-bytes=INT ; default 10485760 (10 MiB)
 max-connections=INT ; default 1000
 grace-period=DURATION ; default 30s
 (resource-children)
]
```

PROTOCOL **MUST** be `http`. Other protocols are out of scope per
§1.2. The bare name `service` is reserved for a future broader
concept covering auth/identity/secrets/state across environments.

The directive starts a listener and returns a service handle. The
handle **MUST** be observable via `[?service-handle name=N]`. The
service runs until `[?stop $handle]` or process shutdown.

#### §10.3.2 `[resource]`

```
[resource
 [METHOD PATH] ; METHOD ∈ get|post|put|patch|delete|head|options
 produces=MIME ; default application/cx
 consumes=MIME ; default */*
 [auth EXPR] ; optional
 HANDLER ; trailing positional, required
]
```

PATH **MUST** support `:name` parameter binding (e.g.
`/users/:id` exposes `$request/path-params/id` to the handler).
Multiple `:name` parameters are permitted. The PATH grammar is
otherwise opaque to CX code — the implementation **MAY** support any
PATH dialect supported by the underlying HTTP server.

#### §10.3.3 Request and response

```cx
[request method=GET path='/users/42'
 [path-params ...]
 [query-params ...]
 [headers [header name=Accept value='application/cx']]
 [body $body]]

[response status=200
 [headers ...]
 [body $body]]
```

Both shapes are normative. The `body` child holds the parsed request
body when `consumes=` permits. Response `status` **MUST** be a
valid HTTP status code (100–599); other values raise
`cx-err:CXER0165` (INTERNAL_ERROR).

#### §10.3.4 `[?http-client]`

```
[?http-client target=URL
 [resilience [DIRECTIVE...]] ; resilience wrap applied to every call
 timeout=DURATION ; default 30s, per-request
 [tls TLS-CONFIG] ; optional
]
```

Returns a client value `$c`. Operations:

| Operation | Signature |
|---|---|
| GET | `$c \| get(PATH)` |
| POST | `$c \| post(PATH, BODY)` |
| PUT | `$c \| put(PATH, BODY)` |
| DELETE | `$c \| delete(PATH)` |
| Generic | `$c \| request(METHOD, PATH, OPTS)` |

Each operation **MUST** return `[response …]` on success or
`[err …]` on failure. Failures map to the §10.3.6 error codes.

#### §10.3.5 Service lifecycle

`[?http-service]` starts a listener at the named port. `[?stop $handle]`
initiates graceful shutdown — drains in-flight requests for up to
`grace-period`, then force-closes. `[?wait-for service=$handle]`
blocks until the service terminates. Service termination is also
triggered by process SIGTERM/SIGINT.

During shutdown drain, new requests **MUST** be rejected with HTTP
503 (`cx-err:CXER0166`).

#### §10.3.6 Error codes

Server-side (returned as `[response status=N [body [err code=cx-err:CXERnnnn ...]]]`):

| HTTP | Code | Symbolic | When |
|---|---|---|---|
| 400 | `cx-err:CXER0160` | BAD_REQUEST | Malformed body or path-param parse failure |
| 401 | `cx-err:CXER0161` | UNAUTHORIZED | `[auth …]` returned err |
| 404 | `cx-err:CXER0162` | NOT_FOUND | No resource matched path + method |
| 408 | `cx-err:CXER0163` | REQUEST_TIMEOUT | `read-timeout=` exceeded |
| 413 | `cx-err:CXER0164` | PAYLOAD_TOO_LARGE | Body > `max-body-bytes=` |
| 500 | `cx-err:CXER0165` | INTERNAL_ERROR | Unhandled err in handler body |
| 503 | `cx-err:CXER0166` | SHUTTING_DOWN | Service in shutdown drain |

Client-side:

| Code | Symbolic | When |
|---|---|---|
| `cx-err:CXER0180` | CONNECTION_REFUSED | TCP connect failure |
| `cx-err:CXER0181` | TLS_HANDSHAKE_FAILED | TLS negotiation failed |
| `cx-err:CXER0182` | INVALID_RESPONSE | Server response could not be parsed |

---

### §10.4 Concurrency

CX code ships single-process concurrency: workers as
goroutines/threads, channels as in-process queues. Cross-process /
cross-node transport is out of scope per §1.2.

#### §10.4.1 `[?channel]`

```
[?channel name=NAME buffer=INT]
```

Declares a channel with FIFO semantics. `buffer=` is the buffer
size (≥ 0). A 0-buffer channel is synchronous (rendezvous between
sender and receiver).

#### §10.4.2 `[?send]` and `[?try-send]`

```
[?send EXPR to=CH]
[?try-send EXPR to=CH timeout=DURATION]
```

`[?send]` blocks when the buffer is full; returns `[ok]` once
buffered. Returns `[err code=cx-err:CXER0200]` (CHANNEL_CLOSED)
if CH is closed at call time.

`[?try-send]` is identical except it returns
`[err code=cx-err:CXER0201]` (SEND_TIMEOUT) if the buffer
doesn't free within DURATION.

#### §10.4.3 `[?receive]` and `[?try-receive]`

```
[?receive from=CH]
[?try-receive from=CH timeout=DURATION]
```

`[?receive]` blocks on an empty channel; returns the next buffered
value. Returns `[err code=cx-err:CXER0200]` (CHANNEL_CLOSED) if
the channel is closed and drained.

`[?try-receive]` is identical except it returns
`[err code=cx-err:CXER0202]` (RECV_TIMEOUT) if no value arrives
within DURATION.

#### §10.4.4 `[?close]`

```
[?close CH]
```

Marks the channel closed. Subsequent `[?send]` calls **MUST** fail
with CHANNEL_CLOSED. Subsequent `[?receive]` calls drain buffered
values, then **MUST** receive CHANNEL_CLOSED. `[?close]` on an
already-closed channel **MUST** return
`[err code=cx-err:CXER0203]` (CHANNEL_ALREADY_CLOSED).

#### §10.4.5 Ordering guarantee

Channels **MUST** preserve FIFO ordering per producer-consumer pair.
With multiple producers, per-producer FIFO is preserved; there is
no global ordering across producers.

#### §10.4.6 `[?worker]`

```
[?worker name=NAME BODY]
[?worker name=NAME inherit-context=false BODY]
```

Starts a worker that runs concurrently with siblings in the same
enclosing scope. The trailing positional `BODY` runs to completion
(normal return, panic, or cancellation). Worker terminal state
**MUST** be observable.

The body is spawned with a **snapshot of the spawning thread's
active dynamic context** (the `[?with-scope]` context, §8.10.8)
taken at spawn time — a *copy*, isolated from the parent thereafter, so structured-log fields (request-id / trace) active
at spawn carry into the worker without hand-threading. Pass
`inherit-context=false` to start the body with an **empty** context.
Capture is in-process only (it does not cross a *process* boundary.

Worker observability:

- `[?worker-handle name=N]` returns a handle (or
 `[err code=cx-err:CXER0222]` — WORKER_NOT_FOUND if no such
 worker exists).
- `[?wait-for worker=$h]` blocks until the worker terminates;
 returns the worker's terminal value or `[err]`.
- `[?cancel worker=$h]` requests cancellation per §10.5.4.

#### §10.4.7 `[?select]`

```
[?select
 [case [from CH $msg HANDLER]]
 [case [from CH $msg HANDLER]]
 [case [timeout DURATION HANDLER]]
]
```

`[?select]` evaluates all `[case …]` clauses concurrently and
proceeds with the first to become ready. When multiple cases are
ready simultaneously, selection **MUST** be uniform-random among
ready cases. Timeout cases become ready when their timer elapses;
they **SHALL NOT** race with channel cases that are already ready
at entry.

#### §10.4.8 Error codes

| Code | Symbolic | When |
|---|---|---|
| `cx-err:CXER0200` | CHANNEL_CLOSED | Receive from drained closed channel; send to closed channel |
| `cx-err:CXER0201` | SEND_TIMEOUT | `[?try-send]` buffer-full timeout |
| `cx-err:CXER0202` | RECV_TIMEOUT | `[?try-receive]` empty timeout |
| `cx-err:CXER0203` | CHANNEL_ALREADY_CLOSED | Second `[?close]` on same channel |
| `cx-err:CXER0220` | WORKER_PANIC | Worker body raised unhandled err |
| `cx-err:CXER0221` | WORKER_CANCELLED | Worker terminated via `[?cancel]` |
| `cx-err:CXER0222` | WORKER_NOT_FOUND | `[?worker-handle]` lookup miss |

---

### §10.5 Async / await

Lightweight futures for fire-and-forget and parallel-await
patterns. Async **MUST** compose with resilience and concurrency
directives.

#### §10.5.1 `[?async]` and futures

```
[?async EXPR]
[?async EXPR inherit-context=false]
```

Evaluates EXPR in a new asynchronous context and returns immediately
with a future value:

```cx
[future id=ID state=STATE created=INSTANT
 value=VALUE # present when state = done
 [cause [err ...]] # present when state = failed
 cancel-reason=STRING] # present when state = cancelled
```

Future state machine:

```
pending → running → done (EXPR completed normally)
 → failed (EXPR raised [err])
 → cancelled (cancellation observed and honored)
```

Terminal states (`done`, `failed`, `cancelled`) **MUST** be
observable via `[?await]`. Once terminal, a future's state
**SHALL NOT** change.

**Dynamic-context capture-at-spawn.** EXPR is spawned
with a **snapshot of the spawning thread's active dynamic context**
(the `[?with-scope]` context, §8.10.8) taken at spawn time: the async
body starts with a *copy* of the active context and is **isolated**
from the parent thereafter — context mutations on either side do not
cross. So a `log/*` emitted inside an `[?async]` body carries the
request-id / trace fields active when it was spawned, without
hand-threading. Pass `inherit-context=false` to spawn EXPR with an
**empty** context instead. Capture is in-process only (it does not
cross a *process* boundary.

#### §10.5.2 `[?await]` and barriers

```
[?await $f]
[?await $f timeout=DURATION]
[?await-all FUTURES]
[?await-any FUTURES]
[?await-race FUTURES]
```

- `[?await $f]` blocks until `$f` is terminal. Returns `$f@value` on
 done, propagates `[err]` on failed, returns
 `[err code=cx-err:CXER0260]` on cancelled.
- `[?await $f timeout=DURATION]` adds a hard deadline; on expiry
 returns `[err code=cx-err:CXER0241]` (AWAIT_TIMEOUT).
- `[?await-all FUTURES]` blocks until all terminate. If all done,
 yields a sequence of values. If any failed or cancelled, yields
 `[err code=cx-err:CXER0240 [causes [err …] …]]`
 (AWAIT_ALL_FAILED) with every non-done cause in input order.
- `[?await-any FUTURES]` yields the first to terminate. Other
 futures continue running; their results are discarded.
- `[?await-race FUTURES]` yields the first to terminate. Other
 futures **MUST** be issued `[?cancel]`.

#### §10.5.3 `[?sleep]` — wall-clock and mock-clock delay

```
[?sleep DURATION]
[?sleep DURATION mock]
```

Pauses evaluation for DURATION. Two modes, distinguished by the
optional `mock` bareword. Per.

**Wall-clock (default).** `[?sleep DUR]` blocks the current OS
thread (or scheduler thread under `[?async]` / `[?worker]` /
`[?http-service]`) for at least DUR wall-clock time, then returns
`[ok]`. The evaluator polls the cancellation flag at intervals
of `min(DUR, 50ms)`; on observed cancellation, returns
`[err code=cx-err:CXER0260]` (CANCELLED) within one polling
boundary. The logical clock (`now_ns`) is **NOT** advanced.

**Mock-clock (`mock`).** `[?sleep DUR mock]` advances the
evaluator's logical clock (`now_ns`) by DUR and returns `[ok]`
instantly. Cancellation is checked at directive entry. No wall-
clock time elapses. This is the deterministic form used by tests,
fixture corpora, and any caller that needs reproducible timing
without real delays.

**Auto-mock context.** One context auto-promotes a bare
`[?sleep DUR]` to mock semantics:

1. **Inside `[?test-concurrent]` task bodies** — the cooperative
 scheduler is mock-clock-only by design; bare `[?sleep DUR]`
 yields via `task_yield(.sleep)`.

Explicit `[?sleep DUR mock]` works in every context (auto-mock or
not) — it always means logical-clock advance. Conformance fixtures,
unit tests, and any other harness needing deterministic time write
`mock` explicitly per D4.2.

**Interaction matrix:**

| Caller context | `[?sleep DUR]` | `[?sleep DUR mock]` |
|---|---|---|
| Top-level `cx eval` | wall-clock | mock |
| `[?async]` future body (no `[?test-concurrent]`) | wall-clock on V thread | mock |
| `[?worker]` body | wall-clock on worker thread | mock |
| `[?http-service]` request handler | wall-clock | mock |
| `[?test-concurrent]` task body | mock (auto, scheduler yield) | mock |
| Conformance fixture / unit test | wall-clock (write `mock` explicitly) | mock |
| Wasm playground (browser main thread) | `cx-err:CXER0270` | mock |
| Wasm Web-Worker host with opt-in | wall-clock (via `Atomics.wait`) | mock |

**Wasm constraint.** In a wasm host that has not opted into
blocking sleep (default for the browser-main-thread playground),
bare `[?sleep DUR]` raises `cx-err:CXER0270`
(WALL_SLEEP_UNSUPPORTED_IN_HOST). Hosts opt in by calling the
C ABI symbol `_cx_wasm_set_wall_sleep(true)`; this is appropriate
for Web-Worker hosts that can use `Atomics.wait` on a
`SharedArrayBuffer` without freezing the UI. The `mock` form is
always available regardless of host.

**Duration units.** `DURATION` is a duration literal — one or more
`integer-unit` terms drawn from the EXACT set `ns` / `us` / `ms` / `s`
/ `m` / `h` / `d` / `w` (lexicon `[L27]`); `m` is minutes (calendar
`mo`/`y` are the distinct `period` type, `[L28]`, not durations). The
unit set is shared with `[?timeout]`, `[?retry delay=…]`,
`[?rate-limit per=…]`, `[?circuit-breaker reset=…`/`window=…]`,
`[?bulkhead queue-for=…]`, and `[?test-clock advance=…]`.

**Errors:**

| Code | Symbolic | When |
|---|---|---|
| `cx-err:CXER0100` | PARSE_ERROR | DURATION argument missing, not a duration literal, or invalid unit |
| `cx-err:CXER0260` | CANCELLED | `[?cancel]` observed during wall-clock or mock sleep |
| `cx-err:CXER0270` | WALL_SLEEP_UNSUPPORTED_IN_HOST | Bare `[?sleep]` in wasm host without opt-in |

#### §10.5.4 Cooperative cancellation contract

`[?cancel $f]` requests cancellation. Cancellation is a signal,
not a kill. The runtime **MUST** guarantee that the following
operations honor cancellation at their next invocation:

- HTTP client calls (at the next network read/write boundary)
- `[?sleep DURATION]` — wall-clock form: within 50ms (one
 polling boundary); mock form: at directive entry (immediately).
 Both return `[err code=cx-err:CXER0260]` (CANCELLED).
- `[?send]` / `[?receive]` / `[?try-send]` / `[?try-receive]`
 (immediately, returning `[err code=cx-err:CXER0260]` —
 CANCELLED)
- `[?for]` (at every iteration boundary)
- `[?await]` (immediately, returning CANCELLED)

Pure CPU loops without yield points **SHALL NOT** observe
cancellation. Authors who want a cancellable hot loop **MUST**
insert `[?check-cancel]` at appropriate boundaries; this evaluates
to `[ok]` normally or `[err code=cx-err:CXER0260]` (CANCELLED)
if cancellation is pending.

If a future is cancelled but its body never reaches a cancellation
point, the future **MAY** remain `running` indefinitely.
`[?await $f timeout=DURATION]` imposes a hard deadline on the
caller's wait but **SHALL NOT** affect the future itself.

#### §10.5.5 Composition with resilience

`[?async]` composes with resilience directives. `[?async [?timeout 5s
slow-call]]` returns a future that resolves to
`[err code=cx-err:CXER0141]` after 5s.

#### §10.5.6 Error codes

| Code | Symbolic | When |
|---|---|---|
| `cx-err:CXER0240` | AWAIT_ALL_FAILED | `[?await-all]` saw ≥ 1 non-done future |
| `cx-err:CXER0241` | AWAIT_TIMEOUT | `[?await $f timeout=…]` deadline |
| `cx-err:CXER0260` | CANCELLED | Operation observed cancellation |
| `cx-err:CXER0270` | WALL_SLEEP_UNSUPPORTED_IN_HOST | Bare `[?sleep]` in wasm host without `_cx_wasm_set_wall_sleep(true)` opt-in (§10.5.3) |

#### §10.5.7 Structured concurrency — RAII over handles, cancellation revokes capabilities

##### §10.5.7.1 RAII over handles

An `[?async]` future handle and a
`[?worker]` handle **satisfy the `[?with-open]` closeable contract** (§8.10.7):
closing a handle **cancels and joins** it. Structured concurrency is then *just*
RAII over handles — a parent scope owns, cancels, and cleans up its children with
**zero new surface**, reusing the guaranteed-exit-edge already specified for
`[?with-open]` (LIFO close on normal completion AND error-unwind). A dedicated
child-adopting scope directive (`[?with-tasks]`) is **RESERVE** (a separate
decision with its own grammar / ownership / lifetime spec); this rollout uses
RAII-over-handles only. Single-process scope (§1.2) is unchanged.

##### §10.5.7.2 Cancellation revokes capabilities

A cancelled task must not
(a) leave resources open or (b) keep performing effects. (a) is covered —
`[?with-open]` cleanup runs LIFO on the cancellation unwind exactly as on
error-unwind (§8.10.7). (b) is the rule here: **once a task is cancelled, its
capability set is narrowed to empty for the REMAINDER OF THE TASK** — not only
during unwind. So *any* post-cancel effect — including in code that never reaches
an unwind/cleanup path — hits the revoked-cap backstop. The only carve-out is
`[?with-open]` `close`, which keeps the capabilities it needs to *release* its
resource (cleanup is never cancelled-out). This makes "a cancelled task cannot
start new I/O" a **capability-enforced** property (the §6.5.1 effect system is the
cancellation-safety substrate). `[?check-cancel]` (§10.5.4) remains the
cooperative complement for cancellation points inside long pure loops.

**Cancellation-vs-capability precedence (normative).** A cancelled task may hit
both a cancellation signal and (via cap-revocation) a denied cap. The reported
code is deterministic: **cancellation is checked BEFORE the capability** at every
cancellation point, so a cancelled task reports the meaningful `CXER0260`, not
`CXER0271`. Cap-revocation is the backstop for code that reaches a raw effect
without passing a cancellation point.

| Operation in a cancelled task | Result |
|---|---|
| `[?check-cancel]`, `[?await]` / join, `[?send]` / `[?receive]`, `[?sleep]` | `CXER0260` (cancellation point — observed first) |
| a raw capability-gated effect with no intervening cancellation point | `CXER0271` (revocation backstop) |
| `[?with-open]` `close` / post-cancel cleanup | **runs** under restored caps for the resource it releases (never cancelled-out) |

**Close-result precedence (normative).** Closing an async/worker handle (or a
`[?with-open]`-bound task) can surface up to four outcomes at once; the result is
chosen by this fixed priority so it is deterministic. The lower-priority outcomes
attach to the reported err as `cause=`.

| Priority | Outcome | Reported |
|---|---|---|
| 1 (highest) | a **child task failed** | the child's `[err]` (first by spawn order; the rest attach as `cause`) |
| 2 | the **body** raised | the body's `[err]` (the in-flight unwind error) |
| 3 | the scope was **cancelled** | `CXER0260` |
| 4 (lowest) | **close itself failed** (flush/release error) | the close `[err]` |

Rationale: a genuine child/body fault is more informative than the cancellation
that may have followed it; a close-time failure is least-specific. Cross-process /
distributed structured concurrency (cross-node cancellation, distributed
capability revocation) is **RESERVE** (§1.2 single-process boundary), but the
model is designed to extend to it (capability revocation is transport-agnostic in
principle).

---

## §11. Conformance

### §11.1 Conformance suite

The CX code conformance suite is [`conformance/code.cxd`](../../../conformance/code.cxd).
Every directive, every parameter, and every error code in this
specification MUST have at least one fixture exercising it. Every
example in this spec MUST be a fixture.

### §11.2 Implementation tiers

V is the reference implementation. Tier-1
bindings (V/Python/Go) MUST pass the full conformance suite at every
release. Rust and TypeScript remain in scope but pass asynchronously
per the cut.

### §11.3 Release gates

Release gates per
§11.6 / design doc §11.6. Sixteen gates across four categories:

**Spec gates (1–3):**
1. `code.md` complete — zero `TBD`, zero `implementation-defined`,
 zero `subject to change`.
2. `code.md` internally consistent — every cross-reference
 resolves; every error code unified across sites.
3. Companion specs aligned: `grammar.ebnf`, `ast.md`.

**Test gates (4–9):**
4. `conformance/code.txt` covers every directive × parameter × error
 code.
5. Resilience composition matrix green.
6. Service + client round-trip green.
7. 24-hour concurrency soak: zero deadlocks, zero leaks.
8. 10K-iteration async cancellation battery: zero non-deterministic
 failures.
9. Diagram round-trip: SVG / PNG / Mermaid all reverse-parse to
 structurally equal CX trees.

**Implementation gates (10–13):**
10. V reference implementation complete — no stubs, no `TODO` markers.
11. Tier-1 bindings (V/Python/Go) pass full conformance suite.
12. Reference renderer complete (CLI + web component + LSP CodeLens).
13. Documentation complete: this spec, CHANGELOG entry for the release.

**Performance gates (14–16):**
14. Pattern compilation: depth-8, 32-binding patterns compile in
 ≤ 1 ms on reference hardware.
15. Streaming throughput: ≥ 200 MB/s on JSON-shape workloads.
16. HTTP service: ≥ 10K req/s with p99 ≤ 10 ms.

Single failing gate blocks the tag. No exceptions.

### §11.4 Verification procedure

Each gate has an unambiguous verification protocol below. A gate is
"green" only when its protocol completes with no failures recorded;
"blocked" otherwise. Implementations **MUST NOT** mark a gate green by
inspection, by partial run, or by waiver.

Every protocol is executed in CI from the canonical dev branch
HEAD prior to tag. Re-runs after the tag are governed by §11.7.

#### §11.4.1 Spec gates (gates 1–3) — procedure

**Gate 1 — `code.md` is complete.**

*Inputs:* this file.
*Tool:* `scripts/check_code_spec_consistency.py` (gate 1 + gate 2,
exit 0 ⇔ green).
*Protocol:*

1. Search this file for any of the following tokens, case-insensitive,
 in normative sections: `TBD`, `TODO`, `FIXME`, `XXX`,
 `subject to change`, `implementation-defined`, `to be specified`,
 `future work`, `coming soon`, `placeholder`.
2. Occurrences inside Markdown code spans (single-backtick) or fenced
 code blocks (triple-backtick) are excluded — the tool tracks span
 state during the scan so the literal token list in this procedure
 does not self-trigger.
3. The gate passes if and only if the number of non-code-span matches
 in normative sections is zero.
4. CI artifact: a JSON report listing line + matched token for every
 hit; an empty `matches` array is the green condition.

A normative section is any `##` or `###` heading whose body does not
begin with the literal HTML comment `<!-- informative -->` (this
convention is normative — adding it to a section excludes that
section's body from the gate). The banner is reserved for
development-tracking aids and other non-normative content.

**Gate 2 — `code.md` is internally consistent.**

*Inputs:* this file.
*Tool:* `scripts/check_code_spec_consistency.py` (same tool as gate 1;
the script emits a `gate_2_consistency` block alongside
`gate_1_completeness` in its JSON report).
*Protocol:*

1. Parse every section anchor of the form `§N(.N)+` from this file's
 `##`/`###`/`####` headings. Parse every bare cross-reference of the
 same form in the body (excluding code spans, code fences, and
 tokens inside Markdown links of the form `[label](target)` —
 foreign-file references are link-wrapped and target their own
 document's anchor). The set of bare referenced anchors **MUST** be
 a subset of the set of defined anchors.
2. Parse every error code of the form `cx-err:CXER\d{4}` and every
 symbolic name appearing in an error table (§§10.1.5, 10.2.6,
 10.3.5, 10.4.5, 10.5.5, 9.X). Each numeric code **MUST** map to
 exactly one symbolic name and vice versa; the mapping **MUST**
 agree at every site.
3. Parse every directive token of the form `[?<name>` from §§5–10
 (including fenced code examples). Parse the directive registry in
 §4.1 from its Markdown table. The two sets **MUST** be equal.
4. CI artifact: a JSON report with three arrays (`unresolved_refs`,
 `error_code_conflicts`, `directive_set_diff`); all three empty is
 the green condition.

**Gate 3 — companion specs aligned.**

*Inputs:* `grammar.ebnf`, `ast.md`, and this file.
*Tool:* `scripts/check_code_spec_consistency.py` (same tool as gates 1
and 2; emits a `gate_3_companion_alignment` block in the JSON
report).
*Protocol:*

1. Parse `grammar.ebnf`. Extract the alternative names from
 production `[127e] ProgramDirName` (the directive closed-set).
 This set **MUST** equal the §4.1 registry in this file.
2. Parse `ast.md`. The program-AST section **MUST** define exactly
 the six program AST node types: `Program`, `ProgramBinding`,
 `ProgramCall`, `ProgramPattern`, `ProgramDirective`,
 `ProgramForComp`. Each **MUST** also appear in the Node type
 summary table. (There is no infix pipe — `[?pipe …]` is the canonical
 `ProgramDirective{name: "pipe"}`, not a distinct AST type, so it is
 not listed here.)
3. CI artifact: a JSON report with two subreports
 (`grammar_diff`, `ast_diff`); each subreport's
 `missing_from_companion` and `missing_from_spec` arrays empty is
 the green condition.

#### §11.4.2 Test gates (gates 4–9) — procedure

**Gate 4 — `conformance/code.txt` covers every directive × parameter ×
error code.**

*Inputs:* this file and `conformance/code.txt`.
*Tool:* `scripts/check_cxl_coverage.sh`.
*Protocol:*

1. Build the coverage requirement set: every `(directive, parameter,
 error_code)` triple derivable from §§5, 8, 10 of this file. A
 directive with no parameters contributes `(directive, ∅,
 error_code)` triples (one per error code in its error table) and
 `(directive, ∅, ∅)` (happy path). A parameter contributes triples
 for both its presence and (if optional) its absence.
2. Parse every fixture in `conformance/code.txt`. Each fixture's
 `in_code` is parsed by the V reference implementation; each
 directive use it contains contributes covered triples. Each
 fixture's `out_err` (if present) supplies the error-code
 coordinate.
3. The gate passes if and only if every required triple is covered by
 at least one fixture.
4. CI artifact: a JSON report listing uncovered triples; an empty
 `uncovered` array is the green condition.

**Gate 5 — resilience composition matrix green.**

*Inputs:* `conformance/code.txt` fixtures tagged `resilience-matrix`.
*Tool:* `make test-program-resilience-matrix` (V harness:
`vcx/tests/runners/cxl_resilience_matrix.v`).
*Protocol:*

1. Enumerate the legal-nesting pairs from the §10.2 composition table
 (`retry`, `timeout`, `circuit-breaker`, `fallback`, `rate-limit`,
 `bulkhead`, considered as both outer and inner). The full matrix
 is 6×6 = 36 cells; cells the §10.2 table marks `—` are excluded.
2. Each remaining cell **MUST** have at least one fixture tagged
 `resilience-matrix outer:<X> inner:<Y>`. The harness runs every
 such fixture against the V reference implementation; pass/fail is
 determined by `out_text` / `out_err` match.
3. The gate passes if and only if every cell has ≥ 1 fixture and
 every fixture passes.

**Gate 6 — service + client round-trip green.**

*Inputs:* `conformance/code.txt` fixtures tagged `service-client`.
*Tool:* `make test-program-service-client` (V harness:
`vcx/tests/runners/cxl_service_client.v`).
*Protocol:*

1. Enumerate the locked HTTP methods (§10.3.2) and the locked error
 response statuses (§10.3.3 error table). The required set is the
 cross-product `(method × status)` plus one TLS-on fixture per
 method and one streaming-body fixture per method that supports a
 request body.
2. Each fixture pairs a `[?http-service]` definition with a
 `[?http-client]` call in the same CX program; the harness spawns
 the service on
 localhost, runs the client, asserts the observed response matches
 `out_text` (for 2xx fixtures) or the response carries the expected
 `cx-err:CXER` code (for non-2xx fixtures).
3. The gate passes if and only if every required (method, status) and
 transport-variant fixture is present and passes.

**Gate 7 — 24-hour concurrency soak.**

*Inputs:* `vcx/tests/runners/cxl_concurrency_soak.v`.
*Tool:* `make test-program-soak-24h` (driver:
`scripts/run_concurrency_soak.sh`).
*Protocol:*

1. The harness instantiates a fixed topology of 16 worker pools, each
 with 8 workers connected by 4 channels per pool with depth 256
 (`scripts/run_concurrency_soak.sh` parameters; locked by
 the harness, not by this spec).
2. For 24 wall-clock hours the driver injects message bursts (Poisson
 arrival, mean 1 ms inter-arrival), worker churn (a worker is
 killed and respawned on a Poisson schedule with mean 30 s), and
 periodic `[?cancel]` storms (one storm per minute, cancelling
 ~10 % of in-flight futures).
3. The gate passes if and only if the entire 24 h window completes
 with: zero deadlocks (no harness heartbeat misses), zero lost
 messages (every sent message is either delivered or accounted
 for in a cancellation), and zero goroutine/file-descriptor leaks
 (RSS and `ulimit -n` stay within ± 5 % of t = 0 over the final
 hour).
4. CI artifact: the soak log, the heartbeat trace, and the
 start/end RSS+fd snapshots; the gate's pass/fail is computed by
 `scripts/check_soak_invariants.sh` from the artifact.

**Gate 8 — 10K-iteration async cancellation battery.**

*Inputs:* `vcx/tests/runners/cxl_async_cancellation_battery.v`.
*Tool:* `make test-program-async-battery`.
*Protocol:*

1. The battery enumerates the 12 race patterns: `{await-all,
 await-any, await-race}` × `{normal, error, cancel}` terminal-state
 combinations on a 3-future test bench (§10.5.2 await family).
2. Each pattern is executed 10 000 times back-to-back. The runner
 asserts the §10.5 normative outcome for each iteration's observed
 result.
3. The gate passes if and only if 10 000 / 10 000 iterations of every
 pattern observe the spec-mandated outcome with zero
 non-deterministic deviations.
4. CI artifact: a `(pattern, observed_outcome, count)` histogram per
 battery run; every bucket falling on the spec-mandated value is
 the green condition.

**Gate 9 — diagram round-trip.**

*Inputs:* every fixture in `conformance/code.txt`, the reference
renderer's three output formats (SVG, PNG, Mermaid).
*Tool:* `make test-program-diagram-roundtrip` (V harness:
`vcx/tests/runners/cxl_diagram_roundtrip.v`).
*Protocol:*

1. For each fixture, the renderer produces SVG, PNG, and Mermaid
 outputs from the source CX program.
2. Each output is fed back through the renderer's reverse parser to
 reconstruct a CX tree.
3. The reconstructed tree is compared against the source tree under
 `cx-diff` (canonical tree-diff, ignoring whitespace and source
 order where commutativity holds per §10.1.3 round-trip rules).
4. The gate passes if and only if every fixture round-trips
 cleanly in every format (≡ structurally equal under `cx-diff`).

#### §11.4.3 Implementation gates (gates 10–13) — procedure

**Gate 10 — V reference implementation complete.**

*Inputs:* the `vcx/code/` module (post-Phase 3).
*Tool:* `scripts/check_v_completeness.sh`.
*Protocol:*

1. The tool greps every `.v` file under `vcx/code/` and every `.v` file
 in `vcx/cx/` that participates in CX code evaluation for any of:
 `panic('TODO')`, `panic('not implemented')`,
 `panic('unimplemented')`, `// TODO`, `// FIXME`, `// XXX`,
 `eprintln('STUB')`.
2. The full `make test-program` target **MUST** pass (it runs gates 4–9
 in `--quick` mode, sufficient for completeness verification at
 this layer; the long-soak / long-battery variants are still gated
 by gates 7 and 8 independently).
3. Every directive in §4 grammar **MUST** appear in the V dispatcher
 table; the dispatcher tool emits the table and the script asserts
 set-equality with the grammar.
4. The gate passes if and only if the grep returns zero matches and
 both subsequent checks pass.

**Gate 11 — Tier-1 bindings pass full conformance.**

*Inputs:* `lang/python/`, `lang/go/`, and the `vcx/` V binding.
*Tool:* `make test-conformance-tier1`.
*Protocol:*

1. The V, Python, and Go bindings each run `conformance/code.txt`
 end-to-end via their respective fixture drivers
 (`lang/python/tests/run_cxl_fixtures.py`,
 `lang/go/tests/run_cxl_fixtures.go`,
 `vcx/tests/runners/cxl_fixtures_test.v`).
2. Each binding **MUST** observe the spec-mandated `out_text` or
 `out_err` for every fixture.
3. Differences attributable to language-runtime semantics (e.g. Go
 goroutine vs threading-model artefacts) are documented in
 `parity-matrix.md` and **MUST** be backed by a parity-matrix
 row before the gate accepts the divergence; an undocumented
 divergence is a gate failure.
4. The gate passes if and only if all three bindings show
 `passed == total_fixtures` and any documented divergences are
 parity-matrix-rowed.

**Gate 12 — reference renderer complete.**

*Inputs:* the three renderer packages: `cx diagram` CLI in
`vcx/cmd/diagram.v`, the `<cx-diagram>` web component in
`web/cx-diagram/`, the LSP CodeLens integration in
`tooling/lsp/codelens/`.
*Tool:* `make test-program-renderer-all`.
*Protocol:*

1. **CLI smoke:** `cx diagram` invoked on a fixed manifest of
 sentinel fixtures **MUST** emit SVG, PNG, and Mermaid output
 without diagnostic output to stderr; the bytes **MUST** match the
 golden files committed in `web/cx-diagram/golden/`.
2. **Web component smoke:** a Playwright runner
 (`web/cx-diagram/test/component.spec.ts`) mounts the component
 against every sentinel fixture and asserts the rendered SVG DOM
 is structurally equal to the CLI's SVG output (whitespace
 normalised).
3. **LSP CodeLens smoke:** the language-server integration test
 (`tooling/lsp/test/codelens_cxl.test.ts`) asserts the CodeLens is
 present on every directive in §10.1.2 and that invocation returns
 a `cx-diagram://` URI whose fetched payload bytes equal the CLI's
 SVG output for the same source.
4. Gate 9 (diagram round-trip) **MUST** also pass; gate 12 layers
 the packaging story on top of gate 9's correctness story.
5. The gate passes if and only if steps 1–4 all pass.

**Gate 13 — documentation complete.**

*Inputs:* `code.md`, `CHANGELOG.md`.
*Tool:* `scripts/check_docs_complete.sh`.
*Protocol:*

1. Gate 1 passes (this file complete).
2. `CHANGELOG.md` **MUST** carry the release entry
 announcing CX code.
3. No file in `spec/` whose header line is not a `*Historical*`
 banner may contain the literal substring `coming soon`.
4. The gate passes if and only if steps 1–3 all pass.

#### §11.4.4 Performance gates (gates 14–16) — procedure

**Gate 14 — pattern compilation.**

*Inputs:* `vcx/tests/runners/cxl_pattern_compile_bench.v`.
*Tool:* `scripts/run_bench_json.py --gate program-compile` followed by
`scripts/compare_bench.py --strict --threshold 0`.
*Protocol:*

1. The bench compiles 1 000 fresh patterns, each of depth 8 with 32
 bindings (generator: `scripts/gen_compile_bench_patterns.py`).
 The compile-only path is measured; cache hits and pre-compiled
 forms are excluded.
2. The 99th-percentile compile time **MUST** be ≤ 1 ms on the
 reference hardware (§11.5).
3. The harness emits a JSON record per pattern; the gate's PASS/FAIL
 is computed by `scripts/check_perf_gate.sh --gate program-compile`.

**Gate 15 — streaming throughput.**

*Inputs:* `vcx/tests/runners/cxl_streaming_bench.v` with a JSON-shape
fixture corpus (`bench/data/json_shape_*.cx`, 1 GB total).
*Tool:* `scripts/run_bench_json.py --gate program-streaming`.
*Protocol:*

1. The bench evaluates a fixed `[?for]` pattern over the corpus and
 measures sustained throughput in MB/s (bytes-processed ÷
 wall-clock-elapsed, mean over 5 trials with cold-cache disk
 reads).
2. The throughput **MUST** be ≥ 200 MB/s on the reference hardware
 (§11.5).
3. The harness emits the per-trial throughput; the gate fails if
 the mean falls below threshold or any single trial falls below
 80 % of the mean (the latter catches GC- or IO-induced jitter
 that would render the published number untrustworthy).

**Gate 16 — HTTP service throughput.**

*Inputs:* `vcx/tests/runners/cxl_http_service_bench.v` with a trivial
echo service.
*Tool:* `scripts/run_bench_json.py --gate program-http`.
*Protocol:*

1. The driver spawns the echo service under `[?http-service]` and runs a
 3-minute steady-state load test with concurrency = 64 (
 `wrk` driver pinned in
 `scripts/run_bench_json.py:cxl_http_payload`).
2. The harness measures requests-per-second and p99 latency. The
 gate requires **both** ≥ 10 000 req/s **and** p99 ≤ 10 ms on the
 reference hardware (§11.5).
3. The harness emits the wrk JSON output; the gate's PASS/FAIL is
 computed by `scripts/check_perf_gate.sh --gate program-http`.

### §11.5 Reference hardware

Reference hardware for gates 14–16 is the GitHub Actions hosted
runner image pinned in `.github/workflows/perf.yml` (currently
`ubuntu-22.04`, x86_64, 4 vCPU, 16 GB RAM, ephemeral SSD). A pinned
runner image is part of the release artefacts; image bumps between
releases require a maintainer `workflow_dispatch publish-baseline`
action and a baseline regeneration, per the governance procedure in
`governance.md` §6.

Implementations that meet the gates on alternative hardware **MAY**
publish a comparative bench, but the ship gate is computed against the
pinned image.

### §11.6 Gate evidence and sign-off

Each gate produces evidence: the spec, test, and implementation gates
(1–13) are evidenced by the `make test` target — the full version-agnostic
`TEST_TARGETS` set, which runs and reports each gate's pass/fail — together
with `make verify-doc-links`; the performance gates (14–16) are evidenced by
`.github/workflows/perf.yml` when CI runner capacity is available.

A release's evidence is the gate result for the tagged commit. The release
procedure (`scripts/release.sh`) runs `make test` + `make verify-doc-links`
and **MUST** refuse to bump, tag, or publish on a red gate, so a published
tag is gate-green by construction. A release manager **MAY** additionally
attach a gate-evidence bundle named `<tag>-gate-evidence.tar.gz` to the
GitHub release; when CI capacity is available `.github/workflows/release.yml`
produces it. A tag whose gate is red is not a conforming release.

### §11.7 Re-running gates between releases

Every release re-runs the full gate (`make test` + `make verify-doc-links`)
against the tagged commit; the spec, test, and implementation gates run on
every release, and the performance gates (14–16) run when CI capacity is
available. A release that finds a gate red publishes the red result in the
release notes and gates the offending fix into the next release; it does not
silently ship.

---

## §12. Module system

The module system is the normative surface for cross-file code re-use,
encapsulation, and reproducible builds. It is **normatively** specified
in this section; the
directives are listed in the §4.1 registry, the EBNF lives in
`grammar.ebnf` productions [149]–[159], the
AST shapes in `ast.md`, the lockfile format in
`lockfile.md`, and the bundled standard library
in `stdlib.md`.

A **module** is the contents of a single `.cx` source file or, for
packaged libraries, the union of `.cx` files reachable through the
package's `cx.pkg` manifest (§12.4). Modules are loaded once per
program, in a two-pass procedure (§12.5), and expose only the
declarations marked `scope=public` (§12.6).

### §12.1 `[?lib]` — module import

```
[?lib RESOLVER MODIFIER*]

RESOLVER ::= FilePath | RegisteredName | HttpsUrl
MODIFIER ::= 'as' '=' IDENT
 | '[only' '(' IDENT+ ')' ']'
 | 'only' '=' '(' IDENT+ ')'
 | 'in-memory'
 | 'version' '=' QuotedString
```

`[?lib]` is a module-top-level directive that imports another module
into the current module's binding table. It is only legal at module
top level (not inside expressions or function bodies). The resolver
string selects one of three shapes per:

| Form | Trigger | Resolution |
|---|---|---|
| **File path** | starts with `./`, `../`, or `/` | relative to importing module's directory (or project root for absolute) |
| **HTTPS URL** | starts with `https://` | fetched per §12.1.3; SRI-pinned in `cx.lock` |
| **Registered name** | anything else | looked up in `cx.lock`'s `[modules]` table |

Plaintext `http://` URLs are **refused at parse time** with
`cx-err:CXER0208`. There is no override.

#### §12.1.1 Bound name and `as=` modifier

Without an `as=` attribute, the imported module's bound name is the
last path-segment of the resolver string:

```
[?lib 'cx-stdlib/strings'] [; bound as 'strings' ]
[?lib './local-helpers.cx'] [; bound as 'local-helpers' ]
[?lib 'github.com/example/regex'] [; bound as 'regex' ]
```

`as=IDENT` rebinds the import under an explicit local name:

```
[?lib 'github.com/example/regex-helpers' as=regex]
```

The bound name is a **namespace prefix** — a module *is* a namespace. Members
are referenced as **QNames** `prefix:local` (`strings:upper`, `regex:compile`,
`local-helpers:sanitize`), the same `prefix:local` shape as an XML-namespaced
name; to call one, head-dispatch it: `[$strings:upper hi]`. The path operator
`/` is unaffected — `$x/child` is data navigation, never a module reference.

#### §12.1.2 `[only …]` clause — selective import

A bare `[?lib …]` makes every export reachable by its QName `prefix:local`
(`[$strings:upper hi]`). `[only …]` additionally **refers** the named exports
into the importing module's local `$` namespace so they can be called
**unqualified** — this is the idiomatic form. `[only …]` takes bare names; a
`[name as=alias]` item rebinds a referred name to resolve a cross-module clash.
`[only …]` is refer-sugar — it never hides exports; any export stays reachable
via its `prefix:local` QName.

```
[?lib 'cx-stdlib/strings' [only upper lower]]
[$upper hello]            [; referred: unqualified ]
[$strings:trim ' x ']     [; not referred: still reachable, qualified ]

[?lib './geometry'     [only floor]]
[?lib 'cx-stdlib/math' [only [floor as=mfloor]]]
[$floor 4.7]              [; geometry ]
[$mfloor 4.7]             [; math ]
```

#### §12.1.3 HTTPS fetch — recursive, cached, integrity-pinned

When a `[?lib]` resolves to an HTTPS URL (directly or via lockfile),
the loader:

1. Looks up the `(url, sri)` pair in the on-disk module cache.
2. On miss, performs an HTTPS GET (TLS verification always on),
 verifies the bytes match the `sri` field recorded in `cx.lock`,
 then stores the bytes under `(url, sri)`.
3. Parses the fetched module's `[?lib]` directives and recursively
 fetches transitive dependencies. Every transitive module MUST
 have a matching `cx.lock` entry; missing entries raise
 `cx-err:CXER0211 E_LIB_UNPINNED`.
4. Detects cycles in the import graph and raises
 `cx-err:CXER0210 E_LIB_IMPORT_CYCLE`.

Bytes that don't hash to the recorded SRI raise
`cx-err:CXER0209 E_LIB_INTEGRITY_MISMATCH`. The full lockfile
format is normatively specified in `lockfile.md`.

#### §12.1.4 Source carries no version

Source code names modules by **namespace path only**. The
lockfile is the single source of truth for the version → bytes
mapping. The grammar reserves `version='X'` as a peer attribute on
`[?lib]` for hotfix-override scenarios but it is **not idiomatic**
and no current use case requires it. See D8.

Bearer-token and HTTP Basic authentication attributes are reserved
in the grammar but their semantics are **not specified** in this revision.

#### §12.1.5 Errors

| Code | Wire | When raised |
|---|---|---|
| `E_LIB_INSECURE_TRANSPORT` | `cx-err:CXER0208` | `http://` resolver at parse time |
| `E_LIB_INTEGRITY_MISMATCH` | `cx-err:CXER0209` | Fetched bytes fail SRI verification |
| `E_LIB_IMPORT_CYCLE` | `cx-err:CXER0210` | Cyclic import graph |
| `E_LIB_UNPINNED` | `cx-err:CXER0211` | Transitive dependency absent from `cx.lock` |
| `E_LIB_UNRESOLVABLE` | `cx-err:CXER0213` | Resolver string does not match file / registered / HTTPS shape |

### §12.2 `[?def]` — module-level functions

```
[?def NAME MODIFIER* '(' PARAM* RESTPARAM? ')' BODY]

MODIFIER ::= 'scope' '=' ('public' | 'private')
 | 'pure' | 'impure'
 | '[returns' TYPE ']'
 | '[throws' TYPE ']'
PARAM ::= '$' IDENT [TYPEANNOT]
 | '$' IDENT '=' DEFAULT [TYPEANNOT]
RESTPARAM ::= '*' '$' IDENT [TYPEANNOT]
TYPEANNOT ::= '::' TYPE
```

`[?def]` declares a named, module-scoped function with **no
closure capture**. Sibling of inline `[?fn]` (§8.6), which keeps
closure semantics.

#### §12.2.1 Module-top-level only

A `[?def]` directive is **only legal at module top level**.
Writing it inside an expression position or inside another
function body raises `cx-err:CXER0204 E_DEF_NOT_TOP_LEVEL` at
parse time. For nested / closure-capturing functions, use
`[?fn]` (§8.6).

This makes "module-scope-only" a **syntactic** invariant —
there is no way to write a `[?def]` that could possibly capture
an outer scope.

#### §12.2.2 Closure semantics — no capture

A `[?def]` body sees:

- Every other `[?def]` and `[?const]` in the **same module**
 (regardless of source order — see §12.5).
- Every name imported via `[?lib]` (§12.1).
- **Nothing else.** The body does not see local variables of
 any enclosing expression, nor names from any other module
 that has not been imported via `[?lib]`.

**Defining-scope resolution (uniform lexical scoping).** This view is
**lexical and stable**: a callable resolves its free names in the scope
where it was **defined**, not where it is **applied**. The guarantee holds
when a `[?def]` (or a `[?fn]`, §8.6) is passed or returned as a *value* and
applied in **another module's** frame — e.g. a predicate/handler/mapper
given to a library combinator still resolves its own module's siblings and
imports, never the callee's. A module is thus a first-class lexical scope;
captured bindings are by reference (declarations are immutable post-load, so
no per-call copy). Mutual recursion and order independence follow (§12.5.5).
This holds for an **escaping** `[?fn]` too: a lambda returned from a module def
and applied in another frame resolves that module's **unqualified** siblings +
consts, and combinators that re-capture a returned closure (`pipe`/`compose`
nesting) preserve its environment — the escaping closure travels WITH its value
(cx-private #45).

#### §12.2.3 No overloading; bare-name references

A module may declare **at most one** `[?def]` per name.
Re-declaration within a module raises
`cx-err:CXER0205 E_DEF_REDECLARED` at module-load time.

Function references use the **bare name**:

```
[?def double (x) [* x 2]]
[?def triple (x) [* x 3]]

[map double [1 2 3]] [; pass `double` as a value ]
[?const TRIPLER triple] [; bind to a [?const] ]
```

Arity-tagged references (`name#N`, `name/N`) are **not** part of
the current grammar.

#### §12.2.4 Parameter shapes

Argument lists support three parameter shapes:

- **Positional** — `($a $b $c)`. Caller passes positional args in
 source order. Each param name carries the `$` binding sigil .
- **Named (keyword) with default** — `($greeting="hello")`. Caller
 passes `greeting="hi"`; default is used if caller omits.
- **Rest** — `(*$args)`. Collects any trailing positional args into
 a sequence. At most one rest-param per parameter list; always
 last. The `*` is the rest-spread marker .

Mixing example:

```
[?def http-get
 scope=public
 ($url::string $timeout=30 *$extra-headers)
 [...]]

[$http-get "https://example.com"]
[$http-get "https://example.com" timeout=60]
[$http-get "https://example.com" "Authorization: Bearer x"]
[$http-get "https://example.com" timeout=60 "X-Trace: abc"]
```

#### §12.2.5 Type annotations

Type annotations are CX data values per §12.7. Two forms:

- **`[returns T]`** clause on the directive, alongside the
 `scope=` attribute.
- **`name::T`** inline in the parameter list, immediately after
 the parameter name (glued `::` .

Both are optional. A `[?def]` without annotations is dynamically
typed at the call boundary.

```
[?def find-user
 scope=public
 [returns [or Person null]]
 ($id::string)
 [...]]

[?def list-users
 scope=public
 [returns [sequence Person]]

 [...]]
```

Under `--strict` mode (or `CX_STRICT_TYPES=1`), annotation
mismatches raise errors at the call boundary:

| Mode | Mismatched call arg | Mismatched return |
|---|---|---|
| `--strict` on | `cx-err:CXER0206` | `cx-err:CXER0207` |
| Default | annotations ignored at runtime; tooling still reads them | annotations ignored |

Conformance test runs and CI invocations are expected to set
`--strict`. Production / interactive runs default to off so
annotations never become a perf cost in the hot path.

`[throws T]` is reserved as a sibling clause to `[returns T]` but
its **semantics are not specified** in this revision.

#### §12.2.6 Errors

| Code | Wire | When raised |
|---|---|---|
| `E_DEF_NOT_TOP_LEVEL` | `cx-err:CXER0204` | `[?def]` inside expression / function body |
| `E_DEF_REDECLARED` | `cx-err:CXER0205` | Same-name `[?def]` declared twice in a module |
| `E_TYPE_ARG_MISMATCH` | `cx-err:CXER0206` | `--strict` — argument fails parameter type annotation |
| `E_TYPE_RETURN_MISMATCH` | `cx-err:CXER0207` | `--strict` — return fails `[returns T]` annotation |

### §12.3 `[?const]` — module-level constants

```
[?const NAME EXPR]
[?const scope=public NAME EXPR]
[?const lazy NAME EXPR]
[?const scope=public lazy NAME EXPR]
```

`[?const]` declares a named, **immutable** module-level value.
Like `[?def]`, `[?const]` is only legal at module top level.

#### §12.3.1 Eager by default

By default a `[?const]` value is computed at module load.
Cyclic or failing eager `[?const]`s fail the module load fast
(see §12.5).

#### §12.3.2 `lazy` modifier

`[?const lazy NAME EXPR]` defers evaluation to **first read**.
The value is **memoized** after the first access. First-call
latency is higher; load latency is lower. Use `lazy` for:

- Expensive load-time work that may not be needed (large table
 builds, file reads, network fetches).
- Recursive dependencies between modules where eager order can't
 be satisfied.

If an eager `[?const]` references a lazy `[?const]`, the eager
const forces the lazy one. Standard memoization semantics.

#### §12.3.3 Never mutable

`[?const]`s are **single-assignment**. There is **no** `mutable`
modifier, no reassignment syntax, no rebinding. Module-level
mutable state is out of scope; if a future use case
requires it, a separate directive will be proposed.

#### §12.3.4 Errors

| Code | Wire | When raised |
|---|---|---|
| `E_CONST_CYCLE` | `cx-err:CXER0214` | Cyclic `[?const]` dependency at load time |
| `E_CONST_BODY_FAILED` | `cx-err:CXER0215` | Eager `[?const]` expression raised an error |

### §12.4 Packages — directory and zip-archive shapes

A **package** is a collection of `.cx` files plus a `cx.pkg`
manifest declaring metadata and public sub-paths. Two on-disk
shapes are normative.

#### §12.4.1 Directory shape

A directory containing a `cx.pkg` manifest at its root, plus one
or more `.cx` files:

```
cx-stdlib/
 cx.pkg [; manifest at root ]
 strings.cx [; single-file leaf ]
 json/
 main.cx [; multi-file entry point ]
 encoder.cx [; private to json package ]
 decoder.cx [; private ]
 http/
 main.cx
```

Resolution

- `[?lib 'pkg/strings']` first tries `strings.cx` (single-file leaf).
- If not found, tries `strings/main.cx` (multi-file form).
- A `cx.pkg` manifest entry overrides convention.

#### §12.4.2 Zip-archive shape — design adopted, implementation deferred

A `.zip` archive is a first-class package container. The archive's
root holds `cx.pkg`; the manifest enumerates which sub-paths inside
the archive are public.

Per,
the zip-archive surface is **designed but its runtime
implementation lands in a follow-up release**. The grammar
productions, manifest shape, and lockfile encoding are locked now; the actual
zip-extract + memory-mount code ships when a real consumer
materialises (or when the bundled stdlib grows large enough to
benefit from archive packaging).

When the runtime ships, extraction defaults to **on disk**, with
opt-in **in-memory** mode via the per-import modifier
`[?lib 'foo' in-memory]` or the global flag
`cx FILE --in-memory ...`.

#### §12.4.3 Manifest — `cx.pkg`

```
[cx.pkg version=1
 name=STRING
 package-version=STRING?
 [sub-paths
 [public NAME FILE-PATH]*
 [private NAME FILE-PATH]*]
 description=STRING?]
```

The manifest enumerates which sub-paths inside the package are
public (reachable via `[?lib 'pkg-name/sub-path']`) versus private
(only reachable internally to the package). Sub-paths absent from
the manifest are **not reachable** from importers even if the
file exists in the package directory.

Worked example:

```
[cx.pkg version=1
 name="cx-stdlib"
 [sub-paths
 [public "strings" "strings.cx"]
 [public "json" "json/main.cx"]
 [public "json/encoder" "json/encoder.cx"]
 [public "http" "http/main.cx"]]]
```

#### §12.4.4 Multi-file packages — entry-file re-exports

When a package has multiple `.cx` files, the **entry file
controls the public surface** via explicit re-exports:

```
[; json/main.cx ]
[?lib './encoder.cx']
[?lib './decoder.cx']

[?def encode scope=public ($v) [encoder/encode $v]]
[?def decode scope=public ($s) [decoder/decode $s]]
```

Adding a non-re-exported file to the package directory does
**not** automatically expand the public surface.
This is the discipline that prevents accidental ABI leaks.

### §12.5 Two-pass module load

Loading a module is a two-pass (logically three-step) operation.
The semantics are load-bearing: they enable order-independent
declarations, well-defined `[?const]` evaluation, and mutual
recursion without forward declarations.

#### §12.5.1 Pass 1 — declaration registration

Parse the module. For each `[?def]`, `[?const]`, and `[?lib]`
directive, register the name into the module's binding table.
No bodies are evaluated; no `[?const]` expressions are
evaluated. Errors at this pass:

- Duplicate name within the module — `cx-err:CXER0205`.
- Malformed directive — `cx-err:CXER0212`.
- Insecure transport in `[?lib]` — `cx-err:CXER0208`.
- Unresolvable resolver — `cx-err:CXER0213`.

#### §12.5.2 Pass 2 — constant evaluation (topological)

Build the reference graph over `[?const]` declarations
(edge `A → B` if `A`'s expression references `B`). Topologically
sort. Evaluate `[?const]`s in dependency order. Lazy `[?const]`s
are registered as thunks; they evaluate on first read. Errors:

- Cyclic constant dependency — `cx-err:CXER0214`.
- `[?const]` body throws an error — `cx-err:CXER0215`.

#### §12.5.3 Pass 3 — module callable

After passes 1 and 2 succeed, the module is callable: its
public surface is exposed to importers, and its `[?def]`s can
be invoked.

#### §12.5.4 Function bodies are evaluated lazily

`[?def]` bodies are **not** evaluated at load time — they run
only when the function is called. This means a `[?def]` may
reference a `[?const lazy …]` whose evaluation has not yet
fired: that is well-formed; the lazy const fires on its first
read inside the body.

#### §12.5.5 Mutual recursion and order independence

```
[?def even? ($n)
 [?if [= $n 0] [then true]
 [else [$odd? [- $n 1]]]]]

[?def odd? ($n)
 [?if [= $n 0] [then false]
 [else [$even? [- $n 1]]]]]
```

Both functions see each other. The two-pass load gathers all
declarations before any function body executes. Likewise for
`[?const]`:

```
[?const B [* A 10]] [; references A; works fine ]
[?const A 5]
```

The topo-sort in §12.5.2 picks the evaluation order based on
references, not source order.

#### §12.5.6 Cross-module cycles

Cycles in the **module import graph** are detected at load
time and raised as `cx-err:CXER0210`. Cycles between
`[?const]`s across modules are a special case of
`cx-err:CXER0214`.

### §12.6 Visibility — `scope=public` (private default)

Visibility is declared via the `scope=` attribute on `[?def]`
and `[?const]`:

```
[?def helper ($x) ...] [; private; not exported ]

[?def serve
 scope=public
 ($request)
 ...] [; public; exported ]

[?const VERSION "1.0"] [; private ]

[?const scope=public PUBLIC-VERSION "1.0"] [; exported ]
```

**Module-private is the default.** Only definitions with
`scope=public` are visible to importers. The attribute-shaped
`scope=` modifier is the same mechanism used elsewhere in CX
for declarative qualifiers.

Referencing a member that exists in another module but is not
exported (private, or absent from the package manifest / entry-file
re-exports per §12.4) raises `cx-err:CXER0216` (E_VISIBILITY) — a
distinct diagnostic from `CXER0213` (E_LIB_UNRESOLVABLE), which is
reserved for resolver strings that match no module at all. The
visibility error names the member and the module that owns it.

### §12.7 Type-expression grammar (types-as-data)

Type expressions are CX data values. Every compound type is a
bracketed form; every atomic type is either a lowercase **kind**
name or a capitalized **element-name**.

```
Type ::= KindName | ElementName | BracketType
BracketType ::= '[' TypeHead Type+ ']'
TypeHead ::= 'or' | 'sequence' | 'iterator'
KindName ::= 'string' | 'int' | 'float' | 'bool' | 'null' | 'atom'
 | 'bytes' | 'date' | 'datetime'
 | 'element' | 'sequence' | 'map' | 'iterator'
 | 'array'
 | 'document' | 'text' | 'scalar-node' | 'comment' | 'pi' | 'directive'
 | 'function' | 'path'
 | 'any' | 'number'
 | RefinementName
RefinementName ::= 'decimal' | 'bigint'
 | 'i8' | 'i16' | 'i32' | 'i64' | 'u8' | 'u16' | 'u32' | 'u64'
 | 'f16' | 'f32' | 'f64' | 'duration' | 'period' | 'instant' | 'secret'
 /* storage-precision refinements per grammar.ebnf [26a]; each
    refines one of the nine scalar kinds (cxdm.md §2.3). */
ElementName ::= /* capitalized identifier; an element with that name */
```

#### §12.7.1 Kinds — lowercase, atomic

The lowercase identifiers in `KindName` each name one of CX's
value kinds:

- Scalars — the nine CXDM scalar kinds: `string`, `int`, `float`,
 `bool`, `null`, `atom`, `bytes`, `date`, `datetime`.
- Scalar refinements (`RefinementName`) — the storage-precision
 names of `grammar.ebnf [26a]`: `decimal`, `bigint`, `i8`..`i64`,
 `u8`..`u64`, `f16`/`f32`/`f64`, `duration`, `period`, `instant`, `secret`.
 Each refines one of the nine kinds (`cxdm.md` §2.3); in a type
 position it matches values of its underlying kind carrying the
 declared precision/representation.
- Containers: `element`, `sequence`, `map`, `iterator`, `array`.
- Other Nodes: `document`, `text`, `scalar-node`, `comment`, `pi`,
 `directive` (the non-Element Node kinds, `cxdm.md` §2.2). With
 `element` and `array` these complete the CXDM Item taxonomy so the
 `::T` value-kind test (§5.2 rule 14) names every kind.
- Other: `function`, `path`.
- `any` — the top type; matches a value of any kind. `number` —
 shorthand for `[or int float]` (matches either numeric kind).

Bare `element` matches any element regardless of name; bare
`sequence` matches any sequence regardless of item type; bare
`iterator` matches any lazy iterator (the §8 Iterator kind)
regardless of item type.

#### §12.7.2 Element-name types — capitalized

A capitalized identifier matches elements whose head name equals
that identifier:

- `Person` matches `[Person …]`.
- `Token` matches `[Token …]`.

The capitalization convention is the disambiguator: lowercase =
kind, capitalized = element name. This matches CX's existing
convention (atoms `:ok` lowercase; element heads capitalized
when naming a type).

#### §12.7.3 Union types — `[or T1 T2 …]`

```
[or Person null]
[or [sequence Token] Error]
[or string int]
```

Bracketed n-ary form. The head `or` is a type-position keyword;
its meaning in expression position is unrelated.

#### §12.7.4 Sequence / iterator parameterisation — `[sequence T]`, `[iterator T]`

```
[sequence string]
[sequence Person]
[sequence [or Person null]]
[iterator element]
```

`[sequence T]` is more specific than bare `sequence`; bare
`sequence` matches any sequence including empty. `[iterator T]`
parameterises the lazy Iterator kind (§8) by item type the same
way; bare `iterator` matches any iterator. The item type `T` is
the element type each `[?to-sequence]` / iteration step yields.

#### §12.7.5 No nullable shorthand

`[or T null]` is the canonical nullable form. There is **no**
`T?` postfix shorthand and **no** `[? T]` directive form.

#### §12.7.6 Dev-strict / prod-silent validation

Type expressions are inert data in default execution. Under
`--strict` (or `CX_STRICT_TYPES=1`) the evaluator enforces:

- Each call site checks every `name::T` parameter annotation;
 mismatched arg → `cx-err:CXER0206`.
- Each return checks the `[returns T]` annotation;
 mismatched return → `cx-err:CXER0207`.

Type expressions do not execute. A `[returns Person]` annotation
is data; the `Person` element type is referenced structurally,
not computed. Cycles involving type expressions do not exist
because types-as-data is not an evaluation graph.

### §12.8 Cross-references

- — `[?def]` semantics, parameter shapes, type-annotation grammar, dev-strict validation. Normative for §§12.2 and 12.7.
- — module loading, scoping, namespacing, lockfile, packages. Normative for §§12.1, 12.3, 12.4, 12.5, 12.6.
- `lockfile.md` — `cx.lock` format.
- `stdlib.md` — bundled `cx-stdlib` surface.
- `grammar.ebnf` productions [149]–[159] — EBNF for `[?lib]`, `[?def]`, `[?const]`, type expressions, lockfile, manifest.
- `ast.md` — `LibNode`, `DefNode`, `ConstNode`, `TypeExprNode` shapes.
- `abi.md` §3 cap bits 34 (`[?def]`) and 35 (`[?lib]`).

---

## §13. `[?cx include]` lexical inclusion

`[?cx include=PATH]` is the document-level lexical-inclusion
directive — the companion to the module system (§12) for composing
data documents from multiple files. It is a `CXDirective`
(`grammar.ebnf [34]`), distinct from the `[?<name>]` program
directives registered in §4.1.

The module system (§12) imports compiled module values into a binding
table; `[?cx include]` splices another file's element-level children
into the parent AST at parse time. Modules are reusable code;
includes are reusable document fragments.

### §13.1 Syntax

```
[?cx include=PATH]
```

The directive accepts exactly one attribute, `include`, whose value
is a path string. Additional attributes on the same directive are a
parse error.

```cx
[users
 [?cx include=lib/admins.cx]
 [user name=carol]
]
```

```cx
[?cx include=defaults.cx]              # legal
[?cx include='lib/util.cx']            # legal — single-quoted
[?cx include="config/prod.cx"]         # legal — double-quoted
[?cx include=foo.cx other=bar]         # parse error
```

The directive appears at any position where a CX node may appear.

### §13.2 When resolution runs

Include resolution is **opt-in**. By default, `[?cx include=…]`
directives are preserved as `CXDirective` nodes in the parsed AST
and the parser does not open the referenced files.

A caller enables resolution by supplying an *include root* — an
absolute directory path against which include paths are validated.
With a root supplied, every `[?cx include=…]` directive resolves
during the parse pipeline.

```sh
cx --include-root=/proj main.cx
cx --json --include-root=. main.cx > resolved.json
```

The `--include-root` flag accepts an absolute path or `.` (the
current working directory, expanded to absolute at flag-parse time).
Without the flag, the CLI parses the input without resolving
includes.

C ABI and per-binding parse entry points expose an optional
`include_root` parameter; see `abi.md` and `misc/bindings.md`.

### §13.3 Path resolution

#### §13.3.1 Relative paths only

Include paths are **relative**. Absolute paths raise
`cx-err:E901 INCLUDE_ABSOLUTE_PATH`.

```cx
[?cx include=/etc/passwd]              # E901
[?cx include=C:\Windows\system.ini]    # E901
[?cx include=\\server\share\foo.cx]    # E901 — UNC
```

A relative path is resolved against the **directory of the file
containing the directive**, not against the include root. For the
**entry document** (the buffer or file the caller passed to the
parser), the "directory containing the directive" is the include
root itself.

#### §13.3.2 No URL schemes

A path containing `://`, or starting with `file:`, `http:`,
`https:`, `ftp:`, `gopher:`, or `data:`, raises `cx-err:E903
INCLUDE_URL_REJECTED`. The parser does not perform network I/O.

#### §13.3.3 Traversal check

After lexically resolving `..` segments and joining against the
including file's directory, the resulting path MUST lie under the
include root. A path that escapes the root raises `cx-err:E902
INCLUDE_PATH_ESCAPES_ROOT`.

```
include_root: /proj
file:         /proj/lib/util.cx
directive:    [?cx include=../../etc/secrets.cx]
resolved:     /etc/secrets.cx   ← rejected (E902)
```

The check is lexical (collapse `..` segments before comparing).
Symlinks are followed when the file is opened; a symlink whose
target lies outside the include root is rejected by the same rule
applied to the resolved (post-symlink) path.

#### §13.3.4 Path-separator portability

Inside the directive, `/` is the path separator regardless of host
platform. The host's native separator is used only when opening the
resolved file. A `\` in the directive is interpreted literally; the
parser does not auto-translate.

### §13.4 What gets inlined

When `[?cx include=path]` resolves to a parsed CX document *D*, the
directive node is replaced in the parent AST by *D*'s element-level
children, in source order:

- **Inlined:** `Element`, `Comment`, `PI`, `RawText`, `Scalar`,
  `Text`, `BlockContent`, `AliasElement`, `EntityRef` at *D*'s top
  level.
- **Not inlined:** `XMLDecl`, `DoctypeDecl`, and any other
  `CXDirective` at *D*'s top level. These are valid in *D*'s own
  standalone parse but are discarded at splice time.
- **Discarded:** the `[?cx include=…]` directive node itself.

Position in the parent is preserved: every inlined node takes the
position of the consumed directive. Document order is preserved
across the splice boundary. A file with no element-level children
inlines as nothing.

```cx
# defaults.cx:
[server host=localhost]
[server host=backup]
[client timeout=30]

# main.cx:
[config
 [?cx include=defaults.cx]
 [client retries=3]
]

# after resolution:
[config
 [server host=localhost]
 [server host=backup]
 [client timeout=30]
 [client retries=3]
]
```

### §13.5 Resolution timing

Include resolution runs as a distinct pass between parsing and the
existing namespace / ID resolution passes:

1. **Parse** the entry document into an unresolved AST.
2. **Include-resolve** the AST (recursively, per §13.6 and §13.7).
3. **Namespace-resolve** per `cxdm.md` §3.
4. **ID-resolve** per `cxdm.md` §4.

An included file's namespace declarations and ID declarations are
applied *as if they had been authored inline at the directive site*.
A duplicate ID across the include boundary is a parse error per
`cxdm.md` §4.

### §13.6 Cycle detection

The parser maintains an *include stack* during resolution: an
ordered list of canonicalized absolute paths of files currently
being expanded. A directive whose resolved path is already on the
stack raises `cx-err:E904 INCLUDE_CYCLE`.

```cx
# loop.cx
[?cx include=loop.cx]                  # E904
```

A diamond include (`A` → `B` → `D` and `A` → `C` → `D`) is **legal**:
`D` is not on the stack at either site because it was popped between.

### §13.7 Depth limit

Include-stack depth is bounded by `max_include_depth`, defaulting to
**8**. Depth-9 raises `cx-err:E905 INCLUDE_DEPTH_EXCEEDED`. The
limit is configurable via the same per-call options that expose
`max_depth` (element nesting) and the allocation cap. The element-
nesting limit and the include-depth limit are independent.

### §13.8 Errors

`[?cx include]` is lexical inclusion resolved at **parse / document-
assembly time** (cxdm.md §4.4), so its errors are **data-parse codes
in the `E` namespace**, normatively registered in `cxdm.md §11` — not
CX-code `CXER` codes. (The `CXER0250–CXER0259` range is reserved/retired
for this reason; see §9.4.)

| Symbolic name | Wire code | When raised |
|---|---|---|
| `INCLUDE_ABSOLUTE_PATH` | `cx-err:E901` | Absolute or UNC path supplied |
| `INCLUDE_PATH_ESCAPES_ROOT` | `cx-err:E902` | Resolved path escapes the include root |
| `INCLUDE_URL_REJECTED` | `cx-err:E903` | URL-shaped include path |
| `INCLUDE_CYCLE` | `cx-err:E904` | Include stack already contains the resolved path |
| `INCLUDE_DEPTH_EXCEEDED` | `cx-err:E905` | `max_include_depth` exceeded |
| `INCLUDE_FILE_NOT_FOUND` | `cx-err:E906` | Resolved file does not exist |
| `INCLUDE_NOT_READABLE` | `cx-err:E907` | *(reserved — surfaced via the `E909` carrier in the current impl; see cxdm.md §11)* |
| `INCLUDE_NOT_REGULAR_FILE` | `cx-err:E908` | Resolved path is a directory or non-regular file |
| `INCLUDE_IO_ERROR` | `cx-err:E909` | Permission denied or I/O failure on read |
| `INCLUDE_NOT_UTF8` | `cx-err:E910` | Included file bytes are not valid UTF-8 |
| `INCLUDE_PARSE_FAILED` | `cx-err:E911` | Included file failed its own parse |

`INCLUDE_NOT_UTF8` and `INCLUDE_PARSE_FAILED` carry both the
included-file location (line / column inside the included file) and
the directive site that opened it, joined by an `included from …`
chain:

```
parse error: unexpected '}' at /proj/lib/util.cx line 12 col 8
 included from /proj/main.cx line 4 col 1: [?cx include=lib/util.cx]
```

### §13.9 Conversion across formats

| Format | Behavior |
|---|---|
| CX → CX, resolution disabled | Directives preserved as `[?cx include=…]` |
| CX → CX, resolution enabled | Directives consumed; included content inlined |
| CX → XML, resolution disabled | Directives emit as `<?cx include="…"?>` PI |
| CX → XML, resolution enabled | Directives consumed; included content emitted inline |
| XML → CX | `<?cx include="…"?>` PI parses as `CXDirective`; resolution applies if enabled |
| CX → JSON / YAML / TOML / MD | Directives preserved when disabled, consumed when enabled |

With resolution disabled, CX → any format → CX preserves directives
byte-for-byte; with resolution enabled, the round-trip is across the
resolved document, not the source.

### §13.10 Example — modular document with cross-file ID refs

```cx
# glossary.cx
[term #t-rest definition='Representational State Transfer']
[term #t-rpc definition='Remote Procedure Call']

# article.cx
[doc
 [?cx include=glossary.cx]
 [para
  APIs broadly fall into two families: [ref @t-rest]-style and
  [ref @t-rpc]-style.
 ]
]
```

After resolution the references `@t-rest` and `@t-rpc` resolve
against the merged document's ID table, exactly as if the glossary
terms had been authored inline (`cxdm.md` §4).

### §13.11 Resolved-vs-inline equivalence

The merged AST after include resolution is indistinguishable from
the AST of an equivalent inline-authored document:
`canonical(resolve(A)) == canonical(B)` whenever *B* is the inline-
equivalent of *A*'s resolved form. This is the property that lets
adopters refactor between single-file and multi-file CX without
changing downstream behavior.

### §13.12 Cross-references

- `grammar.ebnf [34]` — `CXDirective` production.
- `ast.md` — `CXDirective` node shape.
- `cxdm.md §3` — namespace scoping over the merged AST.
- `cxdm.md §4` — ID merge contract across the include boundary.
- `canonical.md` — canonical-form equivalence (§13.11).

---

