# CX Cheatsheet

A one-page reference for CX syntax. For the formal grammar, see
[`spec/grammar.ebnf`](../spec/grammar.ebnf). For the design rationale,
see [`docs/TUTORIAL.md`](TUTORIAL.md).

---

## Atoms

```cx
[name] # element, no body
[name body content] # element with text body
[name attr=value body] # element with attr and text
[name attr=value] # element with attr, no body
[- block comment ] # comment, full bracket form
# line comment # # to end-of-line 
'a string with spaces' # single-quoted string
'''multi-line ... string''' # triple-quoted, no escaping 
```

## Structure

```cx
[outer
 [inner one]
 [inner two]
] # nested, multi-line

[a [b [c deep]]] # nested, inline (compact)

[doc-a content]
[doc-b content] # multiple top-level elements; no wrapper required
```

## Types

```cx
[port :int 8080] # explicit type annotation (long form)
[port:i32 8080] # short alias for :int
[ratio :float 1.5] # float
[active :bool true] # boolean
[tag :string 02134] # string (forces; otherwise '02134' is auto-string)
[count 8080] # auto-typed: 8080 → int
[count 1.5] # auto-typed: 1.5 → float
[count true] # auto-typed: bool
[count null] # auto-typed: null
[count 0xCAFE] # hex → int
[count 1_000_000] # underscores allowed
[balance :decimal 1234.56] # arbitrary-precision decimal
[id :bigint 123…] # arbitrary-precision int
[shorts :u16[] 80 443 8080] # typed array
[mixed :[] 1 2.0 three] # inferred-type array
```

> **Note:** `[zip 02134]` is the string `"02134"`, not int 2134. Bare
> tokens starting with `0` followed by another digit are strings.
> See [`docs/migrations/v0.5-to-v0.6.md`](migrations/v0.5-to-v0.6.md) §1.

## Attributes

```cx
[user id=1 name=alice] # plain attrs, no quotes needed
[user name='Alice Q' email='a@example.com'] # quote when value has spaces / special chars
[user +admin -disabled] # boolean sigil shorthand
 # +x → x=true, -x → x=false
[btn class=primary :string size=lg] # type annotation interleaved with attrs
```

## Comments

```cx
[- this is a block comment ]
[server # inline line comment
 [host localhost] # also inline
 [- multi-token block comment with: any content [really] ]
]
```

## Mixed content & document markup

```cx
[p Plain text with [strong inline] markup and [em emphasis].]
[blockquote
 [p A paragraph.]
 [p Another.]
]
[code [# raw text never parsed - keep '''triple-quotes''' verbatim #]] # raw-text block
[doc :code [# multiline
verbatim content
preserved exactly #]]
```

## Anchors / merge / alias

```cx
[server &default port=8080 host=localhost] # define anchor
[server &prod *default host=prod.example.com] # merge: inherit default, override host
[server *default] # alias: re-use as-is
```

Anchors / aliases / merges are **intra-document only** — they're a
shorthand for repeating attribute sets within a single file
(YAML-style). For *cross-document* references — pointing at a
specific element from another file or another point in the same
file by stable identifier — use ID/IDREF (post-).
Treating anchors as cross-document references will silently
produce a literal alias, not the resolution you wanted.

## Processing instructions / directives

```cx
[?cx include=base.cx] # inline-expand another CX file
[?cx include=secrets.cx] # secrets in a separate file, merged at parse
[?xml-stylesheet href=style.xsl type=text/xsl] # generic processing instruction (preserved)
```

`[?cx include=path]` is the load-bearing directive: the parser
splices the named file's content in place, resolving relative paths
against the including file. Useful for splitting config across
files (`base.cx` + per-environment overrides), keeping secrets out
of the main config, or composing a deployment manifest from
service-owned fragments. Loops are detected and reported as parse
errors.

Other `[?<target> ...]` forms are preserved as processing-instruction
nodes; round-trip to XML emits them as XML PIs.

## Tabular data

```cx
[stocks :table[ticker:string price:f64 volume:u32]
 AAPL 192.45 38291092
 GOOG 142.30 18234567
 MSFT 415.18 23456789
]
```

The `:table[<cols>]` header declares one column per `name:type` pair
(types may be omitted for string columns); each row is a
whitespace-separated sequence of values, one per column. Quoted
values are always strings; bare values auto-type per the column's
declared type.

Column-major in the binary form (5–10× smaller than element-per-row
for large datasets); row-major in CX text for human reading.

## logfmt mode

A document made of bare top-level `key=value` attributes — one CX
"document" per log line:

```
ts=2026-05-07T10:30:00Z level=info svc=api req_id=abc123 latency_ms=45
ts=2026-05-07T10:30:01Z level=warn svc=api req_id=def456 latency_ms=210 slow=true
```

Each line parses as a synthetic Element with the attributes attached.

---

## Same data, four forms

```cx
# pretty
[config
 [server host=localhost port=8080]
]

# compact (cx --compact)
[config[server host=localhost port=8080]]

# JSON
{"config": {"server": {"host": "localhost", "port": 8080}}}

# YAML
config:
 server:
 host: localhost
 port: 8080
```

---

## Use-case examples

### Config file

```cx
[config :string env=production
 [server host=0.0.0.0 :u16 port=8080 +tls]
 [db url=postgres://… :int pool_size=20 :int timeout_s=30]
 [cors :string[] origins=https://app.example.com,https://admin.example.com]
 [features +signup -beta-ui +metrics]
]
```

### API response (data)

```cx
[response :int status=200
 [users
 [user id=1 name=alice +admin]
 [user id=2 name=bob email=b@example.com]
 [user id=3 name=carol +admin]
 ]
 [meta :int total=3 :int page=1]
]
```

### Documentation page (markup)

```cx
[article lang=en
 [head [title Why CX?]]
 [body
 [h1 Why CX?]
 [p CX unifies [strong markup] and [strong data] in one syntax.]
 [code [# [server :int port=8080] #]]
 [ul
 [li one syntax for both]
 [li lossless conversions]
 [li type fidelity]
 ]
 ]
]
```

### Mixed content (config + docs in one file)

```cx
[deployment
 [- production deployment notes ]
 [doc
 [p This deployment uses [em rolling] updates.]
 [p Rollback target: previous tag.]
 ]
 [server host=localhost :u16 port=8080]
]
```

---

## CLI

```sh
cx file.cx # round-trip CX → canonical CX
cx --json file.cx # CX → JSON (--xml / --yaml / --toml / --md / --ast)
cx --from xml file.xml # XML → CX (also json / yaml / toml / md)
cat file.cx | cx --json # stdin / stdout

cx fmt file.cx # lossless canonical (preserves comments)
cx canonical file.cx # strict canonical (data only; stable hash input)
cx hash file.cx # SHA-256 hex of strict canonical bytes
cx eq a.cx b.cx # exit 0 iff data-equivalent

cx --compact file.cx # one-line output
```

---

## CXPath (query)

```cx
//service # all descendants named "service"
config/server # exact path
* # any element (wildcard)
//service[@active=true] # attribute equality (typed)
//service[@port>=8080] # numeric comparison (>, <, >=, <=)
//service[@a=x and @b=y] # boolean and / or
//service[not(@disabled)] # negation
//service[1] //service[last()] # 1-based position
//p[contains(@class, note)] # contains()
//service[starts-with(@host, prod)] # starts-with()
//service[tags] # has child element named "tags"
```

Use through any binding's `select` / `select_all` method, or directly via
the `cx_select_all` / `cx_select_all_paths` C ABI. See
[`spec/cxpath.md`](../spec/cxpath.md) for the full grammar.

---

*See [`docs/TUTORIAL.md`](TUTORIAL.md) for guided walk-through.
[`spec/grammar.ebnf`](../spec/grammar.ebnf) is the normative grammar.*
