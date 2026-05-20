# CXL — the CX Language

CXL borrows the **data-code symbiosis** that makes XML + XQuery
uniquely powerful — and improves on it. Where XQuery is a separate
language with its own parser, type system, and runtime, **a CXL
template file (.cxl) is CX format. Code is data and that's very
powerful.**

The same parser, the same data model, the same content-hash, and
the same schema engine work on configs *and* on the programs that
transform them. There is no separate runtime to install, no second
grammar to learn, no impedance mismatch between "the data" and "the
code that shapes it."

CXL is CX's templating, querying, and transformation language.
A `.cxl` file is itself a CX document, parsed by the same parser,
validated by the same schema engine, hashed by the same canonical
algorithm. The only difference is that some elements (those whose
name starts with `?`) are *evaluated* rather than emitted verbatim.

This document is the single-source CXL reference: short tutorial,
cheatsheet, and worked examples. For the normative spec, see
[`spec/eval.md`](../spec/eval.md).

---

## Why CXL exists

Most data formats give you a query language (JSONPath, XPath, GraphQL)
*and* a separate templating language (Jinja, Handlebars, Liquid) *and*
a transformation language (XSLT, jq, jsonata). Each has its own parser,
its own data model, its own debugging story.

CX collapses these into one:

- **Data format** — most stacks: JSON / YAML / TOML. CX: CX.
- **Query** — most stacks: JSONPath / XPath / jq. CX: CXPath (built in).
- **Templating** — most stacks: Jinja / Handlebars / Liquid. CX: CXL.
- **Transformation** — most stacks: jq / XSLT / jsonata. CX: CXL.
- **Schema validation** — most stacks: JSON Schema / XSD. CX: `.cxs` (built in).

One parser. One data model. One canonical form. Hash a query, version a
template, schema-validate a transformation — same tools throughout.

---

## 60-second tour

A CXL program walks a *context document* (CX input) and produces output
(text, CX, HTML, or any registered target). Three core operations:

### Interpolation

```cxl
Hello [?= @name]!
```

`[?= …]` evaluates an expression and emits the result. `@name` reads the
context document's `name` attribute.

### Conditional

```cxl
[?if @active
  :then Welcome [?= @name]!
  :else Account is disabled.
]
```

### Iteration

```cxl
[?for u :in //user :return - [?= u/@name]
]
```

`//user` is a CXPath: "every `user` element in the document, anywhere."

---

## Running a template

CXL programs live in `.cxl` files and are evaluated with `cx eval`.
Five idiomatic invocation styles:

### A. Simple — file in, transformed text out

```sh
$ cat data.cx
[user name=Alice role=admin active=true]

$ cat greet.cxl
Hello [?= @name], you have [?= @role] access.

$ cx eval greet.cxl --data=data.cx
Hello Alice, you have admin access.
```

### B. Pipe — generate CX, transform via .cxl file

```sh
$ echo '[fleet [svc name=auth region=useast][svc name=api region=useast]]' \
    | cx eval useast.cxl --data=-
- **auth** (region: useast)- **api** (region: useast)
```

`--data=-` reads context from stdin.

### C. Cross-format pipeline — JSON in, CXL transform, anything out

```sh
$ curl -s api.example.com/fleet \
    | cx --from=json --to=cx \
    | cx eval report.cxl --data=- \
    | cx --from=md --to=html > report.html
```

The same `cx` binary handles format conversion, templating, and
stdin/stdout composition.

### D. Everything inline — one command, no files

```sh
$ cx eval \
    -e '[?for s :in //svc :return - **[?= s/@name]** (region: [?= s/@region])
]' \
    -d '[fleet [svc name=auth region=useast][svc name=api region=useast][svc name=cache region=uswest]]'
- **auth** (region: useast)- **api** (region: useast)- **cache** (region: uswest)
```

`-e` is the inline template; `-d` is the inline data. Combine with
`--data=-` if you want inline CXL but stdin data; combine with a
positional template file if you want file CXL but inline data via `-d`.

### E. Per-binding API

```python
# Python
import cxlib
print(cxlib.eval_cxl(open("data.cx").read(), open("greet.cxl").read()))
```

```go
// Go
out, _ := cxlib.EvalCXL(dataCX, templateCXL, "text")
fmt.Print(out)
```

Same behaviour across all 10 bindings (`cx_eval_cxl` C ABI symbol).

---

## Directive reference

Every directive has two syntactic forms that produce **identical**
ASTs:

| Directive | Positional form | Labeled form (recommended for readability) |
| --------- | --------------- | ------------------------------------------ |
| `?=`      | `[?= expr]` | (only one form) |
| `?if`     | `[?if [cond, then, else]]` | `[?if cond :then a :else b]` |
| `?for`    | `[?for [var, iter, body]]` | `[?for var :in iter :return body]` |
| `?with`   | `[?with [ctx, body]]` | `[?with ctx :return body]` |
| `?def`    | `[?def [name, params, body]]` | `[?def name :params [a b] :body …]` |
| `?use`    | `[?use [name, ctx]]` | `[?use name :ctx ctx]` |
| `?include`| `[?include [path]]` | (single arg; one form) |
| `?cond`   | `[?if [[c1,b1], [c2,b2], [*,d]]]` | (array-of-pairs only) |

### `[?= expr]` — interpolation

Evaluate `expr` and emit the result as a string. Auto-escaped under HTML
target; raw under text/cx targets.

```cxl
[?= @name]                  # attribute
[?= //user/@email]          # CXPath: first user's email
[?= //user[@role='admin']/@name]   # CXPath with predicate
[?= [?upper [@name]]]       # nested filter call
```

### `[?if cond :then … :else …]`

```cxl
[?if @subscribed
  :then Welcome back!
  :else [?include [marketing-pitch.cxl]]
]
```

The condition uses *Effective Boolean Value* (EBV) — empty sequences,
empty strings, zero, false, and null are falsey; everything else is
truthy.

Multi-branch:

```cxl
[?if [
  [@role = 'admin',     Full access granted.],
  [@role = 'editor',    Read+write access.],
  [@role = 'viewer',    Read-only access.],
  [*,                   No access.]
]]
```

`*` is the default branch sentinel.

### `[?for var :in iter :return body]`

```cxl
[?for u :in //user :return [?= u/@name]
]
```

Each iteration introduces a fresh lexical scope with `u` bound to the
current item. The body can reference `u/@…` and `@…` (outer context).

### `[?with ctx :return body]`

Shifts the evaluation context. Useful for scoped attribute access:

```cxl
[?with //server :return
  Host: [?= @host]
  Port: [?= @port]
]
```

### `[?def name :params [a b] :body …]` + `[?use name :ctx …]`

Define a reusable block:

```cxl
[?def user-card :params [u]
  :body [
    Name: [?= u/@name]
    Role: [?= u/@role]
  ]
]

[?for u :in //user :return [?use user-card u]
]
```

### `[?include [path]]`

Inline another CXL file. Resolved relative to the calling template's
directory; cycle-detected.

```cxl
[?include [header.cxl]]
Main content here.
[?include [footer.cxl]]
```

---

## Filters

Filters are function-call shaped, operating on one or more positional
arguments. Compose with bracket nesting.

### String

| Filter | Signature | Example |
| ------ | --------- | ------- |
| `upper` | `string → string` | `[?upper [@name]]` |
| `lower` | `string → string` | `[?lower [@name]]` |
| `trim`  | `string → string` | `[?trim [@input]]` |
| `length`| `string → int` | `[?length [@title]]` |
| `replace` | `string × string × string → string` | `[?replace [@s, old, new]]` |
| `escape-html` | `string → string` | (implicit in `html` target) |
| `escape-url` | `string → string` | `[?escape-url [@redirect]]` |

### Sequence

| Filter | Signature |
| ------ | --------- |
| `first` | `seq[T] → T?` |
| `rest`  | `seq[T] → seq[T]` |
| `length`| `seq[T] → int` |
| `empty` | `seq[T] → bool` |
| `reverse` | `seq[T] → seq[T]` |
| `join`  | `seq[string] × string → string` |
| `concat`| `seq[string] → string` |

### Defaults / fallback

```cxl
[?= [?default [@nickname, @name]]]
```

`default` returns its first argument if non-empty, second otherwise.

### Composing

```cxl
[?upper [[?trim [@input]]]]
```

`upper(trim(@input))`. Bracket nesting is the only composition syntax —
no pipe operator at CXL 1.0 (the arrow operator `=>` lands at CXL 3.1).

---

## Output targets

CXL emits to one of three targets at v0.6.0:

| Target | Auto-escape | Use case |
| ------ | ----------- | -------- |
| `text` (default) | none | logs, plain reports |
| `cx` | CX-escape on interpolation | CX-to-CX transformation |
| `html` | HTML-escape on `[?=…]` | safe HTML rendering |

Set via `cx eval --target=html` or via a `[?cx output-target=html]`
directive at the top of the template.

```cxl
[?cx output-target=html]

<h1>Hello [?= @name]!</h1>
<p>You have <strong>[?= @role]</strong> privileges.</p>
```

User-supplied data goes through HTML-escape automatically — no XSS
through `[?=…]` interpolation under the `html` target.

---

## Whitespace handling

Block-form directives consume their line's trailing newline (the
"Liquid / Hugo convention"):

```cxl
[?if @x :then ok :else no]
```

A standalone directive line trims its surrounding newline so the output
isn't sprayed with empty lines.

Explicit whitespace control:

```cxl
[?-= foo]        # trim preceding whitespace then emit
[?= foo -]       # emit then trim following whitespace
[?-= foo -]      # trim both sides
```

---

## CXPath inside CXL

CXL expressions use CXPath for selection. The common patterns:

```cxl
[?= @name]              # attribute on context
[?= //user]             # first user element anywhere
[?= //user[@role='admin']/@name]    # first admin's name
[?for u :in //user[@active='true'] :return …]   # filter + iterate
```

CXPath at v0.6.0 covers `child::`, `descendant::`, predicates, `@`, and
union (`|`). `parent::`, `ancestor::`, `following-sibling::`, and
`preceding-sibling::` are post-v0.6.0.

Full reference: [`spec/cxpath.md`](../spec/cxpath.md).

---

## Worked examples

### Conditional greeting

```cx
# greet.cx
[user name=Alice role=admin active=true]
```

```cxl
# greet.cxl
[?if @active :then Welcome [?= @name]! Role: [?= @role]. :else Account [?= @name] is disabled.]
```

```sh
$ cx eval greet.cxl --data=greet.cx
Welcome Alice! Role: admin.
```

### Iterate over elements

```cx
# team.cx
[team
  [member name=Alice role=admin +active]
  [member name=Bob   role=user  +active]
  [member name=Carol role=user  -active]
]
```

```cxl
# team.cxl
[?for m :in //member :return - [?= m/@name] ([?= m/@role])
]
```

Both examples are runnable from [`examples/cx/`](../examples/cx/) in
the repo.

### JSON in → CXL transform → PSV out

A real shell pipeline: pull JSON from an API, convert to CX, reshape
with CXL, emit pipe-separated values for downstream consumers.

**Input** — a typical REST API response shape:

```json
{"employees":[
  {"name":"Alice","dept":"Eng","salary":120000},
  {"name":"Bob","dept":"Sales","salary":95000},
  {"name":"Carol","dept":"Eng","salary":140000}
]}
```

**One shell command** — three `cx` invocations composed via pipes:

```sh
$ curl -s api.example.com/employees \
    | cx --from=json --to=cx \
    | cx eval -e '[?for emp :in //employees :return [?= emp/name]|[?= emp/dept]|[?= emp/salary]
]' --data=-
Alice|Eng|120000Bob|Sales|95000Carol|Eng|140000
```

Or with a saved template:

```sh
$ cat employees.cxl
[?for emp :in //employees :return [?= emp/name]|[?= emp/dept]|[?= emp/salary]
]

$ curl -s api.example.com/employees | cx --from=json --to=cx | cx eval employees.cxl --data=-
Alice|Eng|120000Bob|Sales|95000Carol|Eng|140000
```

**Same thing from Python** — two ways, depending on whether you want
the per-binding API or the CLI:

```python
import cxlib, json, requests

raw = requests.get("https://api.example.com/employees").text
doc = cxlib.from_json(raw)                                    # JSON → CX
out = cxlib.eval_cxl(doc, open("employees.cxl").read())       # CXL transform
print(out)
```

Or with the same template inline:

```python
import cxlib, json, requests

template = (
    "[?for emp :in //employees :return "
    "[?= emp/name]|[?= emp/dept]|[?= emp/salary]\n"
    "]"
)
doc = cxlib.from_json(requests.get("https://api.example.com/employees").text)
print(cxlib.eval_cxl(doc, template))
```

**Three known v0.6.0 caveats** to be aware of with this pattern
(all tracked for v0.6.1 in [`ROADMAP.md`](../ROADMAP.md)):

1. **Row separation is concatenated.** CXL 1.0's whitespace handling
   inside `[?for]` body slots collapses iteration newlines, so the
   output above is one line. Workaround: post-process with `sed` or
   `awk`, or use the per-binding `Table` API which emits PSV/CSV
   with proper row separators. The whitespace-control markers
   (`[?-` / `-]`) are designed to fix this.

2. **`:table` blocks can't host CXL-substituted cells.** You can't
   write `[result :table[a b c] [?for emp :in … :return [?= emp/a]
   [?= emp/b] [?= emp/c] ]]` because the `:table` row validator
   parses cells before CXL evaluates. So the emit-pipes-directly
   pattern above is the v0.6.0 workable path.

3. **`e` as a `?for` variable name is broken.** `[?for e :in seq
   :return …]` binds the variable but CXPath lookups against it
   come back empty (lexer collision with scientific notation:
   `1e5`). Use any other name (`emp`, `u`, `x`, `item`).

---

## CXL 1.0 capabilities (v0.6.0 release)

| Capability | Status |
| ---------- | ------ |
| `[?= …]` interpolation | ✅ |
| `[?if]` single-branch + multi-branch | ✅ |
| `[?for]` iteration with lexical scope | ✅ |
| `[?with]` context shift | ✅ |
| `[?def]` / `[?use]` named blocks | ✅ |
| `[?def]` parameterized templates | ✅ |
| `[?include]` partial inclusion | requires include-resolution (v0.6.1) |
| String / sequence / temporal filters | ✅ (frozen set) |
| Output targets: text / cx / html | ✅ |
| Whitespace control (`[?-` / `-]`) | ✅ |
| Auto-escape under html target | ✅ |
| Labeled form (`:then` / `:else` / `:in` …) | ✅ |
| `cx eval` / `cx render` CLI | ✅ (`cx eval`) |

Per-binding native evaluators (~2k LOC × 9 bindings) are planned for
v0.7.0. Bindings access CXL today via the C ABI (`cx_eval_cxl`).

---

## CXL 3.1 and beyond

CXL 1.0 is the templating-and-rendering subset. CXL 3.1 (v0.9.0+) adds
the query-and-transformation capabilities that XQuery 3.1 has:

- **FLWOR**: `:let`, `:where`, `:order`, `:return` clauses on `[?for]`
- **User-defined functions**: `[?fn name :params … :body …]`
- **Maps and arrays as first-class values**
- **Arrow operator**: `@input => trim => upper`
- **Try / catch**: `[?try :try … :catch …]`
- **`?match`**: pattern matching on shapes

CXL 4.0 (v1.x target) tracks XQuery 4.0 once it stabilizes — pipeline
operator, partial function application, enhanced types.

The data-code symbiosis XML+XQuery have, in CX flavor: CXL queries
CXL; programs inspect programs; one toolchain.

---

## Where to go next

| You want to... | Read this |
| --- | --- |
| Try CXL right now | [`examples/cx/`](../examples/cx/) |
| One-page CX syntax reference | [`docs/CHEATSHEET.md`](CHEATSHEET.md) |
| Full normative spec | [`spec/eval.md`](../spec/eval.md) |
| CXPath reference | [`spec/cxpath.md`](../spec/cxpath.md) |
| Use CXL from your binding | per-binding README under [`lang/`](../lang/) |
