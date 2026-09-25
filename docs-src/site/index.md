# CX — one language for your data and your code

**TL;DR — reach for CX whenever the data is the point.** One bracketed syntax is the document, the query, the program and the compiler's own tree, so the file you read is the file you transform, validate, hash, store and serve — with no second language in between. Python set the bar a working language has to clear: readable on day one, batteries included, good for a script and for a system. CX holds itself to that bar and goes past it where data work hurts: exact decimals by default, effects you grant instead of inherit, errors that are values, regular expressions that cannot blow up, and a content-addressed store in the box.

```console
curl -sSL https://cxhome.org/install | sh
cx primer
```

The installer resolves the latest release for your platform, checks its SHA-256 against the release's own checksum file and installs `cx` — or, where no prebuilt build exists, says so and points at the source build; `cx primer` then prints the manual for exactly the binary you installed. Every example on this page is a conformance fixture that was executed by `cx` {{VERSION}} when the page was generated, and the page is refused if one of them stops holding.

## Why reach for CX

### The document and the program are the same shape

A query is a pattern over the document: "every `user` that has a `name` and an `email`". There is no object model to build first and no parser to call — the program reads the data in the form you wrote it.

{{EXAMPLE:program-for-003-name-email-pair block}}

### Exact numbers are the default

In Python, `0.1 + 0.2` is `0.30000000000000004` until you import `decimal`. In CX a fraction literal is an exact base-10 decimal, and mixing it with a binary float is refused out loud rather than rounded in silence — so money stays money.

{{EXAMPLE:ap-decimal-float-mix-right block}}

### Every format lands in one value model

JSON parses into the same values the language computes with: a map is a map, whichever format it arrived in.

{{EXAMPLE:json-007-parse-object-map block}}

Typed tables are data, not a convention — the columns carry their types, which is what lets `cx` project a table to columnar formats without guessing:

{{EXAMPLE:tab-001-typed-columns block}}

### Effects are granted, never inherited

A Python script can read every file its process can. A CX program reads nothing until you grant it, and a denial is an ordinary value that names the flag which would allow it:

{{EXAMPLE:io-001-read-file-cap-denied block}}

### Regular expressions that cannot blow up

Python's `re` is a backtracking engine, so a hostile pattern and input can run for as long as they like. CX's `re` is RE2: linear time on any input, and the constructs that would need backtracking are refused when the pattern compiles.

{{EXAMPLE:re-002-compile-then-matches block}}

### State that outlives the program is two calls away

The store is content-addressed: `put-doc` answers a handle derived from the document's canonical bytes and `get-doc` answers the document. `mem://` needs no grant; a real URL talks to a served store with the same two calls.

{{EXAMPLE:store-rt-001-round-trip-get block}}

### Agent protocols are plain values

An MCP request is an ordinary CX value projected to its wire form — no bespoke serializer anywhere in the path.

{{EXAMPLE:mcp-001-call-tool-request-shape block}}

## What is in the box — counted when this page was generated

- **{{COUNT:modules}} shipped modules**, each declared once in `registry/modules.cxd` with its ring, its group and its home repository; the guide renders a reference page from each bundled module's own documentation.
- **{{COUNT:directives}} directives** — the whole normative set, projected from the specification into one table of the primer. If a directive is not in that table it does not exist.
- **{{COUNT:repositories}} repositories**, each pinned by sha from the front door, which builds the four `cx` builds from those pins and grades them together (the map below).
- **{{COUNT:examples}} examples on this page**, each replayed against `cx` {{VERSION}} and compared with its fixture byte for byte.

## Start here

- {{PAGE:guide.html The guide}} — the language, ring by ring, from a first document to a served application, with a reference page for every bundled module.
- {{PAGE:quickstart.html The quickstart}} — install, a first file, a first conversion, a first query and a first schema.
- {{PAGE:llm/primer.md The primer}} — the one file an assistant loads before writing CX (the same text `cx primer` prints); {{PAGE:llms.txt llms.txt}} indexes the rest of that layer, and {{PAGE:llms-full.txt llms-full.txt}} is all of it in one fetch.
- {{PAGE:llm/contributor.md The contributor's front door}} — the rules for changing CX, each citing the decision behind it, and the shortest reading order for each kind of change.
- {{PAGE:downloads.html Downloads}} — the four builds of one binary: `data`, `embed`, `cli` and `platform`. Take the smallest one that answers your question.

## The repositories

CX is built in two rings — Ring 0, the data format, which cannot execute anything, and Ring 1, the language — with the platform, the bindings and the ecosystem as groups above them. Imports point inward, never out, and the build enforces it. Each repository is thin — what it is, how to install it, what it pins — and this site, served from `cx`, carries the narrative for all of them.

{{REPO-MAP}}
