# CX v0.7.0 release announcement (draft)

**S5 v0.7.0 — communication artifact for tag day.**

Three audiences, three drafts:

1. [GitHub release notes](#github-release-notes)
2. [Blog post](#blog-post)
3. [Project page summary](#project-page-summary)

The GitHub release notes are the long form (full breaking-change
matrix + per-row deltas); the blog post is the narrative version
(why now, what's new, what's next); the project-page summary fits
above the fold on the cx.dev landing page.

---

## GitHub release notes

(For paste into the GH release body — see `RELEASE_NOTES_v0.7.0.md`
in the repo for the full master copy. The release workflow at
`.github/workflows/release.yml` consumes that file directly via
`body_path`.)

---

## Blog post

```markdown
# CX v0.7.0: from "the format" to "the data processing language"

CX v0.7.0 ships today. With it, CX moves from "a structured-data
format with a templating layer" to "a full data-processing
language" — the v0.6.0 CXL evaluator is now the v0.7.0 cx-eval
4.0 surface, with XQuery 4.0 / XPath 4.0 parity in directive form.

## What changed

**Engine.** The evaluator gained ?fn (first-class functions with
closures), ?let, ?match (pattern matching), ?try (multi-catch with
err-* bindings), the full FLWOR family (?for + :let / :where /
:count / :while / :order-by / :group-by, tumbling + sliding
windows), partial application, and the operator-token surface
(|>, =>, !, ||, to). Plus the XPath 4.0 lookup operator ?key,
maps-as-functions, arrays-as-functions, inline fn / arrow lambda
expression forms, and the full ~180-function fn: namespace.

**Self-host.** A new cx: module surface (DD row at ADR 0023) lets
cx programs parse, inspect, transform, diff, hash, and (gated)
evaluate other cx programs. Round-trip lossless between cx and
the AST. Includes cx:diff with three-policy semantic merge,
cx:patch for diff application, cx:schema-of for cxs schema
inference.

**Structured logging.** `log:` namespace with trace/debug/info/
warn/error + level filtering + logfmt/json formats + ambient
context via log:with-context. Same module surface as v0.8.0
BaseX modules will use.

**Arrow + Parquet.** Full Arrow C-Data Interface scalar surface
(decimal128, timestamp parametric tz, fixed-size-binary,
dict-utf8). IPC stream format read/write in Python / Go / Rust /
TS. Parquet round-trip via cxlib.parquet with schema
preservation. CX CLI: cx table dump / load --parquet shells out
to the canonical Python reference.

**i18n.** cx:lang attribute with inherited scope. Locale-aware
fn:format-number (en/de/fr at v0.7.0, full CLDR via ICU at
v0.7.x).

**Security.** Memory caps on sequence + map + closure-capture
(max_sequence_len, max_map_entries, max_capture_size). cx:eval
sandbox with M1-M5 gates. URL-scheme allowlist via safe-url
filter. ?include path-traversal sandbox.

## Why this matters

cx now sits where YAML and TOML currently sit (human-authored
config + cross-document references) with throughput closer to
JSON, richer structural primitives (ID/IDREF, anchors, mixed
content), and a full XPath 4.0 / XQuery 4.0 query layer built
in. No competing format combines those.

## What's next

v0.7.x:
- LSP server (gated on tree-sitter parser regen)
- BaseX-style modules: file:, http:, hash:, random:
- Native-port roadmap for binding parity
- ICU integration for full locale catalog

v0.8.0:
- Computed nested types (struct/list/fixed-size-list) in
  cx-table cell model
- Arrow C++ libarrow link option for libcx_arrow
- Full Q5 LSP rollout

## Try it

```sh
brew install cx-home/tap/cx        # macOS
apt install cx                     # Debian/Ubuntu (cx-home PPA)
cargo install cxlib                # Rust binding
pip install cxlib                  # Python binding
npm install @cx-home/cx            # TypeScript binding
go get github.com/cx-home/cx       # Go binding
```

Or grab a release tarball from
https://github.com/cx-home/cx/releases/tag/v0.7.0
```

---

## Project page summary

```markdown
**CX v0.7.0** — full XQuery 4.0 / XPath 4.0 parity. cx-eval
replaces the CXL templating layer; programs parse, inspect,
transform, hash, diff, and (gated) evaluate other cx programs.
Arrow + Parquet round-trip in 5 bindings. Structured logging
via log: module. Locale-aware fn:format-number. Memory caps +
URL-scheme allowlist + cx:eval sandbox lock down the security
surface. Read the [release notes][rn] or the
[v0.6 → v0.7 migration guide][mg].

[rn]: ./RELEASE_NOTES_v0.7.0.md
[mg]: ./docs/migrations/v0.6-to-v0.7.md
```
