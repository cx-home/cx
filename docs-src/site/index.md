# CX — one language for your data and your code

{{TLDR}}

```console
curl -sSL https://cxhome.org/install | sh
cx primer
```

The installer resolves the latest release for your platform, checks its SHA-256 against the release's own checksum file and installs `cx` — or, where no prebuilt build exists, says so and points at the source build; `cx primer` then prints the manual for exactly the binary you installed. Every example on this page is a conformance fixture that was executed by `cx` {{VERSION}} when the page was generated, and the page is refused if one of them stops holding.

## Two rings, and the groups above them

We build CX in two rings — Ring 0, the data format, which cannot execute anything, and Ring 1, the language — with the platform, the bindings and the ecosystem as groups above them. Imports point inward, never out, and the build enforces it. The figure is drawn from the module and repository registries when this page is generated, so it cannot drift from the tree it describes; {{PAGE:rings.html the rings page}} reads it from the centre out, and {{PAGE:why.html the why page}} states our case in eight before/after panels.

{{FIGURE:rings}}

## Why reach for CX

### The document and the program are the same shape

A query is a pattern over the document: "every `user` that has a `name` and an `email`". There is no object model to build first and no parser to call — the program reads the data in the form you wrote it.

{{EXAMPLE:program-for-003-name-email-pair block}}

### Exact numbers are the default

A fraction literal is an exact base-10 decimal, and arithmetic keeps it one; mixing it with a binary float is refused out loud rather than rounded in silence — so money stays money.

{{EXAMPLE:ap-decimal-float-mix-right block}}

### Every format lands in one value model

JSON parses into the same values the language computes with: a map is a map, whichever format it arrived in.

{{EXAMPLE:json-007-parse-object-map block}}

Typed tables are data, not a convention — the columns carry their types, which is what lets `cx` project a table to columnar formats without guessing:

{{EXAMPLE:tab-001-typed-columns block}}

### Effects are granted, never inherited

A program reads nothing until you grant it, and a denial is an ordinary value that names the flag which would allow it:

{{EXAMPLE:io-001-read-file-cap-denied block}}

### Regular expressions that cannot blow up

Our `re` is RE2: linear time on any input, and the constructs that would need backtracking are refused when the pattern compiles, so no hostile string can turn a match into a denial of service.

{{EXAMPLE:re-002-compile-then-matches block}}

### State that outlives the program is two calls away

The store is content-addressed: `put-doc` answers a handle derived from the document's canonical bytes and `get-doc` answers the document. `mem://` needs no grant; a real URL talks to a served store with the same two calls.

{{EXAMPLE:store-rt-001-round-trip-get block}}

### Agent protocols are plain values

An MCP request is an ordinary CX value projected to its wire form — no bespoke serializer anywhere in the path.

{{EXAMPLE:mcp-001-call-tool-request-shape block}}

## What is in the box — counted when this page was generated

- **{{COUNT:modules}} shipped modules**, each declared once in `registry/modules.cxd` with its ring, its group and its home repository; the guide renders a reference page from each bundled module's own documentation, and the figure above draws every one of them.
- **{{COUNT:directives}} directives** — the whole normative set, projected from the specification into one table of the primer. If a directive is not in that table it does not exist.
- **{{COUNT:repositories}} repositories**, each pinned by sha from the front door, which builds the four `cx` builds from those pins and grades them together (the map below).
- **{{COUNT:examples}} examples on this page**, each replayed against `cx` {{VERSION}} and compared with its fixture byte for byte.

## Start here

- {{PAGE:why.html Why CX}} — our case in eight claims, each a before/after panel from a pair of conformance cases.
- {{PAGE:rings.html The rings}} — how much of CX you have to take on, and the gate that holds the import contract.
- {{PAGE:guide.html The guide}} — the language, ring by ring, from a first document to a served application, with a reference page for every bundled module.
- {{PAGE:quickstart.html The quickstart}} — install, a first file, a first conversion, a first query and a first schema.
- {{PAGE:llm/index.html The LLM front door}} — {{PAGE:llm/primer.md the primer}} an assistant loads before writing CX (the same text `cx primer` prints), the references, and {{PAGE:llms.txt llms.txt}} indexing that layer with {{PAGE:llms-full.txt llms-full.txt}} as one fetch.
- {{PAGE:llm/contributor.md The contributor's front door}} — the rules for changing CX, each citing the decision behind it, and the shortest reading order for each kind of change.
- {{PAGE:downloads.html Downloads}} — the four builds of one binary: `data`, `embed`, `cli` and `platform`. Take the smallest one that answers your question.

## The repositories

Each repository is thin — what it is, how to install it, what it pins — and this site, served from `cx`, carries the narrative for all of them. A row links to that repository's page of this site where one exists, and to the repository on GitHub otherwise; the pages arrive in the next waves of this documentation, eight at a time, and a row switches over the day its page is served.

{{REPO-MAP}}
