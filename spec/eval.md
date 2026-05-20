# CXL — CX Language Specification
# Version: 1.0 (targets eventual XQuery 4.0 feature equivalence)
# Date: 2026-05-12
# Syntax revision: 2026-05-11 ( §D7) + 2026-05-12 (§D23–D25) — see §3.0

### Syntax-revision callout (2026-05-11, second pass 2026-05-12)

Per §D7,
CXL 1.0's directive syntax has been **rewritten to a uniform
positional-array form** before its first release. The previous
shape (`:then=…/:else=…` attribute form, `?cond` as a distinct
directive, wrapper-element branches like `[b1 …]`) is **not
valid**. Every directive uses one canonical shape:

```
[?Name [arg1, arg2, arg3, …]]
```

A **second-pass amendment** ( §D23–D25,
2026-05-12) adds a **labeled-form alias** as a parser-level
readability convenience:

```
[?Name :slot1 arg1 :slot2 arg2 :slot3 arg3]
```

Labeled form **desugars to positional at parse time** — the
AST is identical, the canonical form is identical, the wire
format is identical. See §3.0.1 for the labeled form's rules.
**Labeled form is the doc/tutorial default for human-readable
examples; positional form remains the canonical AST shape.**

Both shapes are enabled by the array-literal source-text form
(grammar `[56b]`, CXDM v1.1 Array Item, §D1). The
rewrite is **breaking** relative to 's pre-D7 CXL 1.0
draft, but CXL 1.0 has not yet shipped — there are no adopters
to break.

Prior `?cond` is folded into multi-branch `?if` via an array-of-
pair-arrays (per §3.3). `:then=` / `:else=` attribute-form slots
are dropped (the **labeled form** §3.0.1 reintroduces `:then` /
`:else` as bare slot labels, not `=`-attribute slots). The `*`
sentinel marks the default branch in multi-branch `?if` (per
§3.3 / §D8). Filters remain function-call shaped,
operating on array slots (per §3.0).

extends `?def` with an optional `:params` slot for parameterized
templates. See §3.7 for the post-0020 `?def` shape.

CXL is the CX Language — a CX-native data processing language for
rendering, querying, and transformation. A CXL program reads a CX
input document, performs computation, and produces output: text
(rendered to HTML, CSV, Markdown, etc.), CX (transformed to a new
document), or a CXDM value (returned to a host binding).

> **Project-nature note (2026-05-17, per
> [ADR 0022 §D1 Amendment #3](decisions/0022-cx-is-one-language-v0_7_0-scope.md)).**
> At v0.6.0, CXL is operationally a templating mechanism (the
> "directives, interpolation, simple filters" set in this spec).
> **At v0.7.0, CXL changes nature: it becomes a full data processing
> language, peer of XQuery.** v0.7.0 delivers XQuery 4.0 expression
> parity per [`xquery_40_parity.md`](xquery_40_parity.md) plus the
> XQuery 4.0 standard `fn:` namespace + Array/Map/Math modules.
> **v0.8.0 ships the BaseX-class function-module ecosystem as a
> single tag** (`file:`, `http:`, `hash:`, `crypto:`, `json:`,
> `random:`, `convert:`, `validate:`, `archive:`/`zip:`/`bin:`,
> `inspect:`, `prof:`, etc.) per
> [`basex_function_modules.md`](basex_function_modules.md). v0.9.0+
> covers concurrency primitives (`jobs:`, `proc:`) behind a separate
> ADR. The long-term ambition is operational equivalence to large-
> scale data processing systems built on XQuery+BaseX — complete,
> highly parallel, industrial-grade. Per ADR 0022 §D1 (post-amendment
> #2): directive syntax (the `?` prefix) is preserved across the
> v0.6.0 → v0.7.0 transition; only the *capability ceiling* changes.
>
> When this spec is renamed to `eval.md` at v0.7.0 per ADR 0022 §D6,
> the opening prose will be rewritten to reflect the post-v0.7.0
> nature directly. This note is the bridge for v0.6.x readers.

CXL is itself a CX document (per
 D1),
so every CX tool — parser, schema validator, formatter, diff, hash
— works on `.cxl` files without modification. CXL is the second
member of the CX expression family, after CXPath
([`spec/cxpath.md`](cxpath.md)). It embeds CXPath verbatim for value
extraction and condition testing. CXL inherits its value semantics
from the CX Data Model ([`spec/cxdm.md`](cxdm.md)).

**Strategic target.** CXL is designed to reach **feature equivalence
with XQuery 4.0** (currently a W3C draft). CXL spec versions track
XQuery's version numbers at the points where features land (§10):
CXL 1.0 ships templating-oriented basics (this spec); CXL 3.1 catches
up to XQuery 3.1 capability (FLWOR, user functions, maps, arrays,
arrow operator); CXL 4.0 reaches the target. CXL is not an XQuery
implementation — syntax and semantics are CX-native — but the feature
sets are designed to be roughly cross-translatable for the benefit of
practitioners familiar with the XML world.

**One language, multiple use cases.** Templates (rendering CX to
text) and queries (transforming CX to CX) are not separate
languages; they are use cases of the same CXL. A CXL program's
output target (text, CX, value sequence) is declared via a top-of-
file `[?cx output-target=…]` directive or determined by invocation
mode (`cx eval` vs `cx render`).

This spec is **normative** for v0.6.0 CXL conformance. Per
 R8,
implementations MUST produce byte-identical output to the V
reference implementation for every fixture in
[`conformance/eval.txt`](../conformance/eval.txt).

---

## 1 — File model

A CXL program is stored in a file with the `.cxl` extension. The
file content MUST parse as a valid CX document under
[`spec/grammar.ebnf`](grammar.ebnf) (v3.5 or later).

A CXL program has two parts, interleaved freely:

- **Literal items** — CX data nodes (text, elements, scalars,
 comments) that emit verbatim to the output.
- **CXL evaluation forms** — `?`-prefixed directives that perform
 computation. Two kinds:
 - **Interpolation** (`[?=EXPR]`) — evaluate a CXPath expression
 and emit its value.
 - **EvalDirective** (`[?Name ...]`) — structured directive
 (`[?if]`, `[?for]`, `[?with]`, etc.) with attributes and body.

A CXL program is evaluated against an **input document** (the CX
document being processed). The input document is the implicit
top-level context for CXPath expressions inside the program.

```
cx eval input.cx --program=report.cxl # CXL program over input
cx eval input.cx --program=card.cxl --target=html # override output target
```

Output is written to stdout or the path given by `--output`.

---

## 2 — Evaluation model

### 2.1 Tree walk

The evaluator walks the program's parse-AST tree depth-first,
left-to-right. For each node:

| Node kind | Action |
|-------------------------------|-------------------------------------------------|
| Text (literal text) | Emit the text verbatim |
| Interpolation `[?=EXPR]` | Evaluate EXPR as CXPath, emit the value (§3.1) |
| EvalDirective `[?Name ...]` | Dispatch to the directive's evaluator (§3) |
| Element (data) | Emit as CX (round-trip) — see §2.2 |
| Comment | Drop (programs suppress source comments) |
| PI, CXDirective `[?cx …]` | Preserved per §2.3 (config directives stripped) |
| Scalar, BlockContent, others | Emit per CX rules |

### 2.2 Non-reserved elements emit verbatim

If a CXL program contains:

```
<article class="product">
 [h1 [?=@name]]
</article>
```

The `<article>` and `</article>` lines are literal text (the
bracket character `<` opens an HTML element, not a CX one). The
`[h1 ...]` is a data CX element; its emission depends on the
**output target** (§5). Default emission is the CX text of the
element, with `[?=...]` directives inside its body and attributes
evaluated.

For HTML / Markdown / other-format targets (declared via
`[?cx output-target=html]` and similar), embedded data CX elements
at the program's literal-text level are an authoring error — the
author should write `<h1>` instead. The v0.6.0 evaluator emits a
warning but does not block; v0.8.0 may tighten this to an error.

The expected pattern in v0.6.0: a CXL program targeting a non-CX
format contains *literal text in that format* plus *bracketed
CXL evaluation forms* (`[?for]`, `[?if]`, `[?=...]`). Embedded
data CX elements should only appear when the target is CX itself
(CX-to-CX transformation).

### 2.3 Preservation of `[?cx …]` directives

`[?cx …]` directives at the top of a CXL program configure the
evaluator (§5) and are stripped from output. Other PIs and
CXDirective nodes encountered in the program body are emitted
verbatim — they belong to the output, not the program.

### 2.4 Whitespace handling

An evaluation form that occupies its own source line (only
whitespace before the `[?` and only whitespace after the matching
`]`, terminated by a newline) consumes that line's trailing
newline. This is the **block form** convention also used by Liquid
and Hugo; it removes the overwhelmingly common case where Jinja
users reach for `{%- -%}`.

An evaluation form embedded inline within a text line
(`<p>[?=foo]</p>`) emits its value at exactly that position with
no whitespace added or removed.

Explicit whitespace control: prefix `-` immediately after the
opening `[?` trims preceding whitespace; suffix `-` immediately
before the closing `]` trims following whitespace.

```
[?-= foo] # trim leading whitespace then emit foo
[?= foo -] # emit foo then trim following whitespace
[?-= foo -] # trim both sides
[?-if cond …] # trim leading whitespace before [?if]
[?if cond … -] # trim trailing whitespace after [?if]'s closer
```

### 2.5 Error semantics

| Error class | Behavior |
|------------------------|---------------------------------------------------|
| Parse error in `.cxl` | Panic / unrecoverable (it's a CX parse error) |
| Unknown EvalName | Evaluation error with source location |
| Future-version EvalName at older evaluator | Evaluation error (per R4)|
| CXPath syntax error | Per `spec/cxpath.md` — panic |
| Unbound `for` variable | Evaluation error |
| Type mismatch in `[?if]` | Per CXDM §8 — error or false per rule |
| Filter-not-found | Evaluation error |

Evaluation errors include the source position (file:line:col),
the directive that failed, and the bound variables in scope.
v0.6.0 errors abort evaluation with a non-zero exit and a
diagnostic to stderr. Structured error handling (`[?try]`) lands
in v0.9.0+.

---

## 3 — CXL evaluation directives (v0.6.0)

Seven EvalNames plus the Interpolation form. Each below uses the
uniform shape introduced in §3.0.

### 3.0 Uniform directive shape

Per §D6 / §D7, **every directive** uses one structural
pattern:

```ebnf
EvalDirective ::= '[' '?' Name ArgArray ']'
ArgArray ::= Array | ε (* ε = no args *)
Array ::= '[' Item (',' Item)* ','? ']'
```

The directive name (`Name`) determines slot interpretation; the
parser treats every directive identically. The argument array is
a CXDM Array Item per [`spec/cxdm.md §2.4`](cxdm.md) /
[`spec/grammar.ebnf §[56b]`](grammar.ebnf); its items are the
positional slots.

**`?=` interpolation special-case.** Single-argument interpolation
keeps its concise form `[?=EXPR]` as syntactic sugar for
`[?= [EXPR]]`. This is a one-line parser convenience for the most
common idiom; all other directives use the explicit array form.

**No more named attribute slots.** Earlier attribute slots
(`:then=` / `:else=`) are not valid. Every slot is positional in
the argument array. The order of slots is fixed per directive
(documented in each §3.x section below).

**No more wrapper-element branches.** Earlier multi-branch
shapes (`[b1 test 'body']`, `[else …]`) are not valid. Multi-
branch directives use arrays-of-pair-arrays (§3.3) with the
sentinel `*` for the unconditional fallback.

**Filters are nested function calls** over array slots (§4 / §3.0
example below). Composition is bracket nesting:

```
[?=[?upper [[?trim [@name]]]]] # = upper(trim(@name))
```

CXL 3.1+ adds arrow-operator sugar `=>` for left-to-right filter
chains; CXL 1.0 uses bracket nesting only.

**Disambiguation from element syntax.** The directive form starts
with `[?` (an EvalDirective per grammar `[59]`); element syntax
starts with `[Name`. The two cannot be confused. The argument
array (`Array` per grammar `[56b]`) is distinguished from element
body by the comma-as-marker rule in the grammar header.

### 3.0.1 Labeled directive form (per §D23–D25)

Every directive with semantically-named slots admits a **labeled
alias** form that desugars to the §3.0 positional form at parse
time. The labeled form uses **`:`-prefix slot labels** to mark
each slot by name:

```ebnf
LabeledForm ::= '[' '?' Name LabeledArgList ']'
LabeledArgList ::= LabeledSlot (LabeledSlot)*
LabeledSlot ::= SlotLabel value-expr
SlotLabel ::= ':' [a-z][a-z0-9-]*
```

`:`-prefix is the **slot-label marker** — distinct from `?`
(directive prefix), `@` (attribute reference), and `$` (reserved
for CXL 3.1 variables). A directive uses **one of two forms**:

- **Positional form** (§3.0, canonical AST shape):
 `[?dir [a, b, c]]` — exactly one inner Array literal whose
 items are the slots.
- **Labeled form** (this section):
 `[?dir bare-head* :label1 a :label2 b]` — zero or more bare
 leading items (per the directive's documented head shape)
 followed by zero or more `:label expr` slots, with **no inner
 Array bracket**.

Mixing the two — `[?dir [a, b] :label c]` (inner array + labels)
or `[?dir a, b]` (bare commas without inner array) — is a parse
error (**W016**).

The bare-head shape varies per directive: `?if` takes one bare
head (the cond expression); `?for` takes one bare head (the loop
variable name); `?with` takes one (the context expression);
`?def` and `?use` each take one (the name). The per-directive
tables below enumerate the shape exactly.

**Bracket-leading bare-heads.** When a labeled-form bare-head
item starts with `[`, the parser applies §D1's
one-token lookahead: `,` before `]` inside the inner `[` →
positional ArgArray; `]` before `,` → bare-head Element (per
existing CX `[name body]` syntax). To force an array-typed
bare-head expression in labeled form, use the trailing-comma
form `[a,]`; or use positional form. In practice, bare-head
items are CXPath expressions or bare identifiers, never
array literals.

**Per-directive label tables:**

| Directive | Positional (§3.0) | Labeled (§3.0.1) |
|---|---|---|
| `?if` (single-branch) | `[?if [cond, then, else]]` | `[?if cond :then a :else b]` |
| `?if` (multi-branch) | `[?if [[c1,b1], [c2,b2], [*, d]]]` | unchanged — array-of-pairs has no semantic names |
| `?for` | `[?for [var, iter, body]]` | `[?for var :in iter :return body]` |
| `?with` | `[?with [ctx, body]]` | `[?with ctx :return body]` |
| `?def` | `[?def [name, params, body]]` (3 slots; legacy 2-slot `[?def [name, body]]` auto-expands to params=`[]`) | `[?def name :body body]` (+ `:params [args]`) |
| `?use` | `[?use [name, ctx]]` | `[?use name :ctx ctx]` |
| Filters | `[?upper [x]]` | unchanged — function-call form, no semantic slot names |
| `?cx` | `[?cx [{config}]]` | unchanged — map literal already named |

**No implicit body / tail form (per §D24).** Every slot has an
explicit label in labeled form. A directive omitting a required
body label is a parse error (W017). There is no "comma-separated
tail body" rule — `[?for v :in xs body]` (missing `:return`) is
invalid; `[?for v :in xs :return body]` is the only labeled form.

**Slot-label naming (per §D25).** Slot labels are single bare
identifiers for verb / connective slots (`:in`, `:ctx`, `:params`,
`:body`, `:return`, `:then`, `:else`, `:where`, `:let`). FLWOR
compound clauses retain SQL/XQuery kebab-case spelling
(`:order-by`, `:group-by`). Underscored or camelCase labels are
parse errors (W020).

**Why two forms?** Positional form is the canonical AST shape and
the canonical-form serializer's output. Labeled form is the human-
readable input alias that makes directive role explicit at the
call site. AST tools (linters, formatters, diff) operate on
positional AST; source-text writers and readers see labeled form
in documentation and tutorials. Both forms produce byte-identical
ASTs, ast_bin output, evaluation results.

### 3.1 `[?=expr]` — Value interpolation

Evaluates `expr` as a CXPath expression against the current
context and emits its CXDM value as text (per
[`spec/cxdm.md` §7.1](cxdm.md)).

```
[?=@name] # emit the context element's @name attribute
[?=//service[1]/@name] # emit the name of the first service
[?=count(//service)] # emit the count (v0.9.0; v0.6.0 has [?length …])
```

If `expr` produces a Sequence of more than one Item, all items
are emitted in order, separated by **no separator** (concatenation).
To join with a separator, use the `join` filter (§4).

If `expr` produces the empty Sequence, nothing is emitted.

Whitespace variants: `[?-=...]`, `[?=... -]`, `[?-=... -]` per §2.4.

Auto-escape behavior depends on `output-target` (§6).

**Body-position references (v0.7.0 — ADR 0003 D1 second bullet).**
Template content that contains `[ref @id]` body-position references
(per `spec/identity.md §1.4`) emits the reference **verbatim** —
the evaluator does not auto-resolve body_ref targets at eval time.
Rationale: templates frequently emit cross-document structures where
the reference is meaningful as-is (e.g., assembling a glossary entry
that says "see [ref @section-3]"); auto-resolution would inline the
target's content, changing the rendered shape.

Callers who DO want to resolve references inline as part of
templating should use `cx:select(value, "//*[@id=$ref-id]")` at the
appropriate slot to fetch the target value. A dedicated
`cx:resolve-references` convenience function is deferred to v0.7.x
if a use case surfaces.

### 3.2 `[?if [cond, then-body, else-body]]` — Conditional

Evaluates the first slot (`cond`) as a CXPath expression. Computes
EBV per [`spec/cxdm.md` §4.6](cxdm.md). If true, emits the second
slot (`then-body`); otherwise emits the third slot (`else-body`).

Positional form:
```
[?if [@stock > 0,
 In stock: [?=@stock],
 Out of stock]]
```

Labeled form (per §3.0.1, recommended for human-written templates):
```
[?if @stock > 0
 :then In stock: [?=@stock]
 :else Out of stock]
```

Slot order (positional):
1. `cond` — condition expression
2. `then-body` — body emitted when EBV(cond) is true
3. `else-body` (optional, default empty Sequence) — body emitted otherwise

The labeled form's `:else` slot is **optional** mirroring the
positional form's optional third slot — `[?if cond :then body]`
is valid; the false-branch is the empty Sequence. The `:then`
slot is **required** — `[?if cond :else body]` is a parse error.

If the third positional slot is omitted (`[?if [cond, then-body]]`),
the false-branch is the empty Sequence (nothing is emitted).

### 3.3 `[?if [[c1, b1], [c2, b2], …, [*, default]]]` — Multi-way `?if`

(Replaces the v1.0-draft `?cond` directive, which is dropped per
 §D7.)

When `?if` is invoked with a **single** array-of-pair-arrays
argument, it dispatches multi-way: each inner pair is `[test,
body]`; the first test whose EBV is true emits its body; remaining
pairs are not evaluated. The sentinel `*` (CXPath wildcard, per
 §D8) marks the unconditional fallback branch — its
body emits when no preceding test matched.

```
[?if [[@stock > 100, Plenty],
 [@stock > 10, Some],
 [@stock > 0, Low],
 [*, None]]]
```

The parser disambiguates §3.2 from §3.3 by inspecting the slot
count and shape of the single argument array:
- If the argument array contains 2 or 3 items and the first is a
 scalar/path expression (not itself an array of pairs) → §3.2
 form (cond / then / else).
- If the argument array contains N items, all of which are
 themselves 2-element arrays → §3.3 form (multi-way branches).

The `*` sentinel parses as a CXPath wildcard that always evaluates
to a truthy node-test result, so it acts as the always-match
default branch. The branches are evaluated top-to-bottom; the
match-first-wins rule is normative.

### 3.4 `[?for [var, iterable, body]]` — Iteration

Evaluates the iterable slot (second) as a CXPath expression. Binds
the loop variable name (first slot, a bare Name) to each Item in
the resulting Sequence in order, evaluating the body slot (third)
for each binding. The directive's value is the concatenation of
body evaluations.

Positional form:
```
[?for [v, //variant,
 [card
 :sku=[?=v/@sku]
 :stock=[?=v/@stock]]]]
```

Labeled form (per §3.0.1, recommended):
```
[?for v :in //variant :return
 [card
 :sku=[?=v/@sku]
 :stock=[?=v/@stock]]]
```

Slot order (positional):
1. `var` — loop variable name (bare identifier, not a string)
2. `iterable` — CXPath expression producing the Sequence to iterate
3. `body` — body to evaluate for each binding

Labeled-form slots:
- `:in` — iterable expression (mirrors XQuery `for $v in xs`)
- `:return` — body expression evaluated per iteration (mirrors
 XQuery FLWOR's `return` clause)

**Loop variable scope.** `var` is bound only inside the body.
Nested `[?for]` directives may shadow outer variables; the
innermost binding wins. Variables persist across sibling
directives within the body (visible to `[?if]`, `[?=...]`, etc.).

**Document order.** The bound Sequence iterates in CXDM Sequence
order, which is document order for CXPath result Sequences.

### 3.5 `[?with [context-expr, body]]` — Scope shift

Binds the value of `context-expr` (first slot) as the new context
for the body slot's CXPath expressions. Within the body, CXPath
expressions like `@name` and `child` are evaluated against
`context-expr` rather than the outer context.

Positional form:
```
[?with [//product[@id=42],
 [h1 [?=@name]]
 [p [?=description]]]]
```

Labeled form (per §3.0.1):
```
[?with //product[@id=42] :return
 [h1 [?=@name]]
 [p [?=description]]]
```

Slot order:
1. `context-expr` — expression establishing the new context
2. `body` — body evaluated under the new context

Labeled-form slot `:return` mirrors XQuery's FLWOR `return`
clause — the body's emission is what `?with` "returns" given
the rebound context. The same label is used by `?for` (§3.4)
for the same semantic role.

This is the only v0.6.0 construct for binding a value without
iteration. v0.9.0+ adds `[?let]` for named (non-context) bindings.

### 3.6 `[?include [path]]` — Partial inclusion

Renders the CXL program at `path` (first slot, a string literal
or CXPath expression returning a string) in the current context.
The included program inherits the caller's variable bindings
(loop variables, `with` context).

```
[?include ['partials/card.cxl']]
```

Slot order:
1. `path` — string path to the program to include

`path` resolution follows
: relative to
the current program file unless absolute. Cycle detection per
.

The included program is parsed, evaluated, and its output spliced
inline. The included program MAY contain `[?def]` blocks (§3.7)
that become available to the caller.

### 3.7 `[?def [name, params, body]]` — Define reusable block

Declares a named program fragment. The body slot is evaluated
when the block is invoked, not when `[?def]` is encountered.

Positional form (3 slots, §D7 amendment 2026-05-12):
```
[?def [card-row, [],
 <tr><td>[?=@sku]</td><td>[?=@stock]</td></tr>]]
```

Legacy 2-slot form `[?def [name, body]]` (the original D7 shape
pre-2026-05-12) parses as backward-compat sugar: the parser
auto-expands to 3-slot with `params = []` (empty array). Both
forms produce the same AST.

Labeled form (per §3.0.1, recommended for human-written templates):
```
[?def card-row :body
 <tr><td>[?=@sku]</td><td>[?=@stock]</td></tr>]
```

Slot order (3-slot positional form):
1. `name` — bare identifier naming the block
2. `params` — Array of bare identifiers (empty `[]` for
 parameterless templates)
3. `body` — body to evaluate on invocation

Labeled-form slot `:body` is used (not `:return`) because a
template definition's body is **not** an iteration return value —
it's the substitution template expanded at every invocation
site.

**Parameterized templates** (per
):
`?def` admits a non-empty params slot for parameter-bearing
templates. Parameters are bare identifiers lexically bound in
the body scope. Capability bit 30 signals support.

```
[?def stock-line :params [v] :body
 ([?if v/@stock > 0
 :then [?=v/@stock] in stock
 :else out of stock])]
```

Or in positional form:

```
[?def [stock-line, [v],
 ([?if [v/@stock > 0,
 [?=v/@stock] in stock,
 out of stock]])]]
```

Zero-parameter `?def` (params = `[]`) is identical in semantics
to the pre-amendment D7 2-slot shape. Bindings advertising bit 29
(collection literals + labeled-form parser) without bit 30
(parameter-binding evaluator) parse the 3-slot form fine but
error at evaluation when params is non-empty.

**Parameterized invocation** (when params is non-empty): use the
directive-call form `[?template-name a b]` (positional args).
The legacy `?use` form is for zero-parameter templates only;
`?use` of a parameterized template is an evaluation-time error.

Scope: definitions are visible from the point of definition
forward, within the same program and any programs included after
the definition. Definitions are not exported across `cx eval`
invocations. v0.9.0+ may add module-level exports. Parameter
bindings shadow outer names within the body and unbind on body
exit; closures are not introduced at v0.6.0 §D2.

### 3.8 `[?use [name, context-expr]]` — Invoke a named block

Renders the `[?def]` block named `name` (first slot) with
`context-expr` (second slot) as the current context.

Positional form:
```
[?for [v, //variant,
 [?use [card-row, v]]]]
```

Labeled form (per §3.0.1):
```
[?for v :in //variant :return
 [?use card-row :ctx v]]
```

Slot order:
1. `name` — bare identifier naming the block to invoke
2. `context-expr` (optional) — context expression for the block's body

Labeled-form slot `:ctx` marks the optional context expression.
If `:ctx` is omitted (`[?use card-row]`), the block runs in the
current context unchanged — mirroring the positional single-slot
form `[?use [name]]`.

**Parameterized invocation** (when the referenced `?def` has a
`:params` slot): `[?use name :args [a, b]]` is
**reserved syntax for CXL 3.1**. At v0.6.0 / CXL 1.0,
parameterized templates are invoked via the directive-call form
`[?name a b]` (positional), not via `?use`. `?use` of a
parameterized template is an evaluation-time error (per 
§R4 — `?use` supplies one context, not N parameters).

---

## 4 — Built-in filter functions

The frozen v0.6.0 filter set. Per
 D3,
this list is closed; host-binding pluggable extensions follow the
opt-in extension mechanism (deferred to v0.9.0+).

Filters are invoked via bracket-nested directive calls — there is
no infix `|` operator in v0.6.0. Filter calls themselves use the
`?`-prefixed form (they are CXL evaluation directives):

```
[?upper [?trim @name]] # upper(trim(@name))
[?where //variant [@stock > 0]] # filter sequence by predicate
[?first [?where //variant [@stock > 0]]] # first match
```

Filter names are reserved at v0.6.0 and ship as built-in
EvalNames extending the table in.

### 4.1 String filters

| Filter | Signature | Behavior |
|-------------------|-----------------------------------|-------------------------------------------|
| `[?upper x]` | `string → string` | Unicode uppercase |
| `[?lower x]` | `string → string` | Unicode lowercase |
| `[?trim x]` | `string → string` | Strip leading and trailing whitespace |
| `[?length x]` | `string → int` | UTF-8 code point count |
| `[?concat x …]` | `string × … → string` | Concatenate strings |
| `[?join sep xs]` | `string × Sequence → string` | Join sequence with separator |
| `[?replace old new x]` | `string × string × string → string` | Substring replacement (literal, all occurrences) |

### 4.2 Numeric filters

| Filter | Signature | Behavior |
|-------------------------|---------------------------------|-------------------------------------|
| `[?abs x]` | `numeric → numeric` | Absolute value |
| `[?round x n]` | `numeric × int → numeric` | Round to n decimal places |
| `[?format-decimal x n]` | `numeric × int → string` | Format with exactly n decimal places |
| `[?format-percent x]` | `numeric → string` | `0.125 → "12.5%"` |

### 4.3 Sequence filters

| Filter | Signature | Behavior |
|-------------------|---------------------------------|-------------------------------------|
| `[?length xs]` | `Sequence → int` | Count of items |
| `[?empty xs]` | `Sequence → bool` | True iff count == 0 |
| `[?first xs]` | `Sequence → Sequence` | One-item sequence, or empty |
| `[?last xs]` | `Sequence → Sequence` | One-item sequence, or empty |
| `[?rest xs]` | `Sequence → Sequence` | All but first |
| `[?take n xs]` | `int × Sequence → Sequence` | First n items |
| `[?drop n xs]` | `int × Sequence → Sequence` | All after first n |
| `[?reverse xs]` | `Sequence → Sequence` | Reverse order |
| `[?distinct xs]` | `Sequence → Sequence` | Order-preserving dedup |
| `[?where xs pred]`| `Sequence × CXPathPredicate → Sequence` | Filter by predicate |

### 4.4 Temporal filters

| Filter | Signature | Behavior |
|---------------------------|--------------------------------|-------------------------------------------|
| `[?format-date d fmt]` | `date × string → string` | Format per fmt; strftime-compatible subset |
| `[?format-datetime dt fmt]` | `datetime × string → string` | Format datetime |

The strftime-compatible subset at v0.6.0: `%Y %m %d %H %M %S %z`.
Other specifiers are an error.

### 4.5 Type filters

| Filter | Signature | Behavior |
|-------------------|---------------------------------|-------------------------------------|
| `[?type-of x]` | `Value → string` | Returns the CXDM type name |
| `[?default x d]` | `Value × Value → Value` | `x` if non-empty/non-null, else `d` |

`[?default]` is the canonical fallback construct — CXL v0.6.0 has
no ternary operator. `[?default @stock 0]` reads as "stock, or 0
if missing."

### 4.6 Encoding filters

| Filter | Signature | Behavior |
|-------------------|---------------------------------|-------------------------------------|
| `[?escape-html x]`| `string → string` | Replace `& < > " '` with entities |
| `[?escape-url x]` | `string → string` | Percent-encode for URL components |
| `[?safe-url x]`   | `string → string` | URL-scheme allowlist (v0.7.0). Returns empty when input has a `javascript:` / `data:` / `vbscript:` / `file:` scheme (case-insensitive, whitespace-obfuscation-resistant); pass-through otherwise. Templates under `output-target=html` should route `href` / `src` attribute values through this filter |
| `[?raw x]` | `string → string` | Marks output as "do not auto-escape" — see §6 |

The reserved EvalName set at v0.6.0 is the union of §3 directives
(`if`, `for`, `with`, `include`, `def`, `use` — `?cond` was
dropped §D7, folded into multi-branch `?if` per
§3.3) and §4 filter names. Per R4, this set is closed
for v0.6.0 (the CXL 1.0 ship target — pulled forward from
v0.6.0 per the readiness-rubric framing).

---

## 5 — Program configuration directives

Top-of-file `[?cx …]` directives configure the evaluator. These
are existing CXDirective AST nodes ([`spec/ast.md`](ast.md))
recognized at program-load time.

### 5.1 `[?cx output-target=…]`

Declares the program's output format. Affects:
- Default auto-escape policy (§6)
- Whether data CX elements in literal-text position emit
 warnings (§2.2)

Recognized values: `text` (default — no escaping), `html`,
`markdown`, `json`, `yaml`, `xml`, `cx`, `csv`, `tsv`.

```
[?cx output-target=html]
<article>[?=@name]</article>
```

The `output-target` directive parallels 's
`[?cx <fmt>-shape=…]` directive — both configure per-format
emission. They are independent and compose.

### 5.2 `[?cx output-strict]`

Enables strict mode. In strict mode:
- Any filter not in the v0.6.0 built-in set (§4) is an error.
- Any EvalName not in the v0.6.0 set is an error.
- Type mismatches in `[?if]` conditions error rather than coerce.

Strict mode is RECOMMENDED for CXL programs intended to be
portable across binding versions and tool ecosystems.

### 5.3 `[?cx cx-eval-version=4.0]`

Pins the program to a specific cx-eval (XQuery-equivalent) version.
Evaluators on newer cx versions MUST evaluate the program under the
pinned version's semantics. Future-version directives in a pinned
program are an error.

**Naming history.** At v0.6.0 this attribute was `cxl-version`. Per
[ADR 0022 §D6](decisions/0022-cx-is-one-language-v0_7_0-scope.md),
it renamed to `cx-eval-version` at v0.7.0 to reflect the retirement
of the "CXL" name (cx is one language; cx-eval is the evaluator).
The v0.7.0 evaluator accepts both forms during the migration window;
`cxl-version` is deprecated and removed at v0.8.0. The `cx
upgrade-config` migration tool (per ADR 0022 §D6) rewrites the
attribute name mechanically.

### 5.4 Other CXDirectives

`[?cx schema=…]` (schema validation of the program itself per
), `[?cx include=…]` (file include),
`[?cx version=…]` (CX format version per governance.md) all apply
to CXL programs the same as they apply to data documents.

---

## 6 — Output safety

The default auto-escape policy depends on `output-target` (§5.1):

| Target | Default escape policy |
|-------------------|--------------------------------------------|
| `text` (default) | No escaping |
| `html` | `[?=...]` auto-escapes per `escape-html` |
| `xml` | `[?=...]` auto-escapes per `escape-html` |
| `json`, `yaml`, `markdown`, `cx`, `csv`, `tsv` | No auto-escape (v0.6.0); explicit `[?escape-*]` filters available |

Programs targeting `html` or `xml` that want to emit pre-escaped
content use the `raw` filter:

```
[?=[?raw @html-blob]]
```

The `[?raw]` filter is an explicit author opt-in to bypass
auto-escape. Untrusted input MUST NOT be passed through `[?raw]`.
Programs rendered on untrusted input SHOULD run in
`[?cx output-strict]` mode (§5.2) and SHOULD NOT use `[?raw]`.

v0.9.0+ may add a context-sensitive escaping mode (HTML attribute
vs. URL component vs. JS string — what Go templates call
"auto-escape contexts"); v0.6.0 has a single output-context
escape model.

---

## 7 — CXPath embedding

Every expression position in a CXL evaluation form accepts a
CXPath expression as specified at [`spec/cxpath.md`](cxpath.md),
at the implementation's CXPath version.

Expression positions in v0.6.0 (per §D7):

- `[?=EXPR]` — interpolation
- `[?if [EXPR, …, …]]` — condition (first slot)
- `[?if [[EXPR, body], …]]` — multi-branch tests (first item of each pair)
- `[?for [v, EXPR, body]]` — sequence to iterate (second slot)
- `[?with [EXPR, body]]` — new context (first slot)
- `[?include [EXPR]]` — include path (first slot, string-valued)
- `[?use [name, EXPR]]` — block invocation context (second slot)
- Filter arguments (`[?upper [EXPR]]`, `[?join [SEP, EXPR]]`, etc.)
- `[?where [xs, PREDICATE]]` — filter predicate (CXPath bracket-
 predicate syntax in second slot)

CXPath inside a CXL evaluation form evaluates against:

- The **outer context** (the input document root, by default).
- Loop variables (`[?for v in …]` binds `v`; references like
 `v/@name` resolve to `v`'s subtree).
- `[?with]`-shifted context.

v0.6.0 CXPath does not have parent / sibling axes
([`spec/cxpath.md`](cxpath.md) §Deferred). Programs that need
upward navigation must restructure or wait for v0.8.0.

---

## 8 — Worked examples

### 8.1 HTML card render (template use case)

`product.cx`:
```
[product :id=42 :name='Pocket Notebook']
 :price=12.50
 :tags=[stationery paper]
 [variant :sku=PN-A :color=red :stock=120]
 [variant :sku=PN-B :color=blue :stock=0]
 description: A compact ruled notebook for daily use.
```

`card.cxl` (labeled form per §3.0.1, recommended for human-
written templates):
```
[?cx output-target=html]
<article class="product" data-id="[?=@id]">
 <h1>[?=@name]</h1>
 <p class="price">$[?=[?format-decimal [@price, 2]]]</p>
 [?if //tags :then
 <ul class="tags">
 [?for t :in //tags/* :return <li>[?=t]</li>]
 </ul>]
 <ul class="variants">
 [?for v :in //variant :return
 <li>[?=v/@sku] — [?=v/@color]
 ([?if v/@stock > 0
 :then [?=v/@stock] in stock
 :else out of stock])</li>]
 </ul>
 <p>[?=description]</p>
</article>
```

Equivalent positional form (per §3.0 — canonical AST shape):
```
[?for [v, //variant,
 <li>[?=v/@sku] — [?=v/@color]
 ([?if [v/@stock > 0,
 [?=v/@stock] in stock,
 out of stock]])</li>]]
```

Both produce identical ASTs, ast_bin output, and evaluation
results. The labeled form's `:then` / `:else` / `:in` /
`:return` slot labels make each directive's argument role
explicit at the call site.

Invocation:
```sh
cx eval product.cx --program=card.cxl > card.html
```

### 8.2 CX-to-CX transformation (query/transform use case)

`reshape.cxl`:
```
[?cx output-target=cx]
[catalog
 [?for v :in //variant[@stock > 0] :return
 [item
 :sku=[?=v/@sku]
 :available=true]]]
```

Selects only in-stock variants and emits them under a new
`[catalog]` root. The result is valid CX, schema-validatable,
hashable, queryable.

Invocation:
```sh
cx eval product.cx --program=reshape.cxl > in-stock.cx
```

### 8.3 Reusable block

`card-block.cxl`:
```
[?cx output-target=markdown]
[?def card-row :body
 | [?=@sku] | [?=@color] | [?=[?default [@stock, 0]]] |]

| SKU | Color | Stock |
|-----|-------|-------|
[?for v :in //variant :return [?use card-row :ctx v]]
```

Markdown table from a CX product catalog, using a reusable row
fragment.

---

## 8.4 — Streaming evaluation (v0.7.0)

The C ABI exposes two evaluator entry points:

- `cx_eval(input, program, opts)` — **buffered**. Materialises the
  entire program output into a single string before returning.
- `cx_eval_streaming(input, program, opts, cb, userdata)` —
  **streaming**. Invokes the caller-supplied write callback `cb` with
  output chunks as the evaluator produces them; returns once the
  program completes.

Both entry points produce **byte-identical** output for the same
input. Streaming mode does not relax any correctness guarantee; it
only changes the *granularity* at which bytes are surfaced to the
caller.

### 8.4.1 Per-item directives (true streaming benefit)

The following constructs emit per-iteration or per-element, flushing
to the streaming sink after each unit of output. Memory residency
under streaming mode is bounded by the largest single iteration plus
the evaluator's per-call flush threshold:

- `?for` (basic) and its labeled variants with `:let` / `:where` /
  `:count` / `:while`
- `?for-tumbling`, `?for-sliding` — per chunk / per window
- `?for-group-by` — emits per group (the group-collection phase is
  itself buffered; result emission streams)
- Top-level program nodes (literal text, `[?=EXPR]` interpolation,
  element constructors, bare directive calls)

### 8.4.2 Materialising directives (buffer required)

The following constructs MUST collect their entire input before
producing a result. Streaming mode still runs them correctly — output
remains byte-identical — but they do not contribute the streaming
throughput benefit because the materialised intermediate value is
held in memory:

- `?for :order-by` — full sequence collected and sorted before any
  emit
- Sequence filters `sort`, `distinct-values`, `reverse`,
  `fold-right`, `last` — must see the whole input
- `?fn` / `?focus` body call when invoked in value context (via
  `call_fn_to_value`) — body output is captured into a sub-builder
  and returned as a value rather than flushed to the streaming sink
- Any sequence-typed result whose downstream consumer is another
  directive — the value flows through cx-value internally and only
  emits when an outer atomising context (interpolation, element body)
  consumes it

### 8.4.3 Correctness invariant

For any program `P`, input `I`, and options `O`:

```
concat(stream(P, I, O))  ≡  buffered(P, I, O)
```

where `stream(...)` denotes the byte concatenation of all chunks
delivered to the streaming callback. Implementations MUST satisfy
this invariant — streaming mode is a delivery-mechanism change, not
a semantic mode.

Document-level memory residency under streaming mode is bounded by
the largest single materialising step (§8.4.2) plus the evaluator's
`flush_after_bytes` knob. Programs composed entirely of §8.4.1
directives stream in constant working-set memory regardless of input
size.

### 8.4.4 Per-binding wrappers

Per [`spec/v0_7_0_status.md §Y7`](v0_7_0_status.md), Tier-1 + Tier-2
bindings expose streaming through host-idiomatic shapes:

- **Python** — `cxlib.eval_cxl_streaming(input, program, on_chunk)`
- **Go** — `cxlib.EvalCXLStreaming(input, program, onChunk) error`
- **Rust** — `cxlib::eval_cxl_streaming(input, program, on_chunk)`
- **TypeScript** — `evalCxlStreaming(input, program, onChunk)`

Each binding's chunk callback receives bytes verbatim from the C ABI;
no per-binding rewriting / re-encoding is performed.

---

## 9 — Conformance fixture layout

The CXL conformance suite lives at
[`conformance/eval.txt`](../conformance/eval.txt). v0.6.0 fixtures
follow the existing flat `.txt` format:

```
=== test: NNN-name
level: core|extended
tags: tag1 tag2
--- in_cxl
<CXL program source>
--- in_cx
<input CX document>
--- out_text
<expected rendered output, byte-exact>
```

Error-path fixtures use `--- out_err` carrying an error-message
pattern.

Categories (v0.6.0):

1. **basic** — `[?=EXPR]` interpolation, literal text, simple CXPath
2. **control-flow** — `[?if]` (single-branch + multi-branch per §3.3), `[?for]`, `[?with]` semantics
3. **filters** — frozen built-in filter set per §4
4. **composition** — nested directives, embedded CXPath, `[?def]` /
 `[?use]` blocks
5. **partials** — `[?include]` resolution
6. **whitespace** — block-form newline rules, `[?-= ... -]` trim markers
7. **escaping** — target-aware auto-escape per §6
8. **errors** — unbound variable, bad CXPath, type mismatch,
 recursive include

Tier 1 bindings (V, Python, Go) MUST pass every fixture at v0.6.0
ship. Tier 2 (Rust, C#, Java) catches up per the binding-tiering
decision. Tier 3 is deferred until CXL demand materializes.

---

## 10 — Version policy

CXL spec versions track XQuery feature levels to make cross-reference
and capability-comparison clear. CXL is an independent language with
CX-native syntax and semantics; "XQuery N equivalence" means the
CXL version provides analogous expressive power, not literal grammar
parity.

| CXL version | CX release | XQuery parallel | Scope |
|---|---|---|---|
| **CXL 1.0** | v0.6.0 | XQuery 1.0 (subset) | This spec. 6 EvalDirectives (`if` covering single- and multi-branch per §3.3, `for`, `with`, `include`, `def`, `use`) + Interpolation + frozen filter set + 3 config attrs (`output-target`, `output-strict`, `cxl-version`). `?cond` was dropped at §D7, folded into multi-branch `?if`. Labeled directive form per §3.0.1 ( §D23–D25) ships in v0.6.0; parameterized `?def` ships in v0.6.0. Templating-oriented; no full FLWOR, no user functions, no aggregates. |
| **CXL 3.1** | v0.9.0+ | XQuery 3.1 (current standard) | Additive. Adds `let`, `fn`, `match`, `try` EvalNames; full FLWOR on `[?for]` with `:let` / `:where` / `:order-by` / `:group-by` / `:return` slot labels (kebab-case FLWOR compound spelling §D25); higher-order functions; aggregate filters (`sum`, `count`); maps and arrays as CXDM value kinds (already pulled forward to v0.6.0 §D1); arrow operator `=>` for left-to-right pipelining; lookup operator (per XQuery 3.1 `?key`, surface TBD to avoid conflict with the directive `?` prefix); context-sensitive escaping. |
| **CXL 4.0** | v1.x+ (target) | XQuery 4.0 (draft) | Additive. Pipeline operator `\|>`, partial function application, member maps, enhanced type system, additional collection operations. Target spec; ships when XQuery 4.0 stabilizes and the CX-native adaptation is settled. |

Independent CX-release-versioned extension that benefits CXL without
bumping the CXL spec version:

| CX release | CXL impact |
|---|---|
| v0.8.0 | CXPath parent/sibling axes become available; CXL programs gain upward navigation in expressions with no CXL spec change. |

A CXL 1.0 program MUST evaluate identically in every subsequent CXL
version. New EvalNames are recognized as such by future evaluators;
un-evaluated they are an evaluation error at older evaluators per
 R4 (not a parse error — the grammar accepts them as
EvalDirective AST nodes; the evaluator decides what to do with
unknown names).

The `[?cx cxl-version=1.0]` configuration directive pins a program
to a specific CXL spec version; evaluators with a newer CXL MUST
evaluate the program under the pinned version's semantics. Future-
version directives in a pinned program are an error.

---

## 11 — References

- [`spec/cxdm.md`](cxdm.md) — value model CXL operates over.
- [`spec/cxpath.md`](cxpath.md) — expression sublanguage embedded
 in CXL directives.
- [`spec/ast.md`](ast.md) — parse AST CXL walks.
- [`spec/grammar.ebnf`](grammar.ebnf) — the grammar `.cxl` files
 parse against (v3.5+, with Interpolation [58] and EvalDirective
 [59] productions).
- [`spec/canonical.md`](canonical.md) — canonical scalar formatting
 for `[?=...]` text emission.
- — schemas
 may validate `.cxl` programs.
- — output shapes
 are orthogonal to CXL programs; both may compose D6.
- — CXL evaluator
 may compose with streaming write for incremental output (v0.9.0+).
- — `[?include]`
 directive resolution rules.
