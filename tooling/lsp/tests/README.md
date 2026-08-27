# `cx lsp` — Phase 5.5 fixtures

Source fixtures for the six diagnostic / hover / completion affordances
landed in Phase 5.5 (CXLS001, CXLS002, CXLS003, CXLS004, CXPath focus
hover, CXPath path-context completion). Each fixture is a stand-alone
`.cx` file the LSP server should produce a specific diagnostic /
hover / completion response on.

`probe.cx` is a **manual exploration driver** — it answers "what does the
server say about this file at this position". It is deliberately not a gate.
The gated pins live in `vcx/tests/lint_lsp_umbrella_test.v` (#996), which
runs in `make test-vcx-suite`; a script that reads as coverage while gating
nothing is the shape #1003 closed here.

Run the manual driver against the built `cx` binary:

```sh
# The probe driver is CX (flag-first: cx [flags] FILE [args] per cli.md §3):
PROBE="./vcx/target/cx --allow-read --allow-write --allow-subprocess tooling/lsp/tests/probe.cx ./vcx/target/cx"

# Diagnostics (CXLS001–004):
$PROBE diag tooling/lsp/tests/cxls001_unreachable_after_else.cx
$PROBE diag tooling/lsp/tests/cxls002_missing_else.cx
$PROBE diag tooling/lsp/tests/cxls003_when_consolidation.cx
$PROBE diag tooling/lsp/tests/cxls004_modify_attr_mismatch.cx

# CXPath focus hover:
$PROBE hover tooling/lsp/tests/cxpath_focus_hover.cx 0 16

# Path-context completion:
#   axis_or_name position (right after `//`)
$PROBE completion tooling/lsp/tests/cxpath_completion_nodetest.cx 1 15
#   name_only position (right after `::`)
$PROBE completion tooling/lsp/tests/cxpath_completion_axis.cx 1 22
#   attr_predicate position (right after `[`)
$PROBE completion tooling/lsp/tests/cxpath_completion_predicate.cx 1 20
```

Every invocation above is bounded: `probe.cx` gives each session a
20-second budget and drives the server through files rather than pipes, so
neither a wedged server nor a large response can hang it. That is not
belt-and-braces — `textDocument/completion` on these fixtures answers with
about 159 KB, well past a 64 KiB pipe buffer, and the pipe-based shape this
script used before #1003 deadlocked on exactly that (and on any server that
said more than 64 KiB on stderr, which nothing was draining).

Fixtures exercise the full-AST path (`code.parse` walked by
`vcx/cmd/lsp_match_diagnostics.v`) for CXLS001/002/003 + hover; the
CXLS004 + completion provider live in
`vcx/cmd/lsp_modify_diagnostics.v`. A future session moves these into
the canonical `conformance/lsp/` envelope (`LSP_REQUEST` /
`LSP_RESPONSE` JSON pair) once the conformance runner gains an LSP
mode — see `tooling/lsp/diagnostics.md` "Tests" section for
the reserved fixture names.

## Expected diagnostic emit

| Fixture                               | Expected code | Severity |
| ------------------------------------- | ------------- | -------- |
| `cxls001_unreachable_after_else.cx`   | `CXLS001`     | warning  |
| `cxls002_missing_else.cx`             | `CXLS002`     | hint     |
| `cxls003_when_consolidation.cx`       | `CXLS003`     | hint     |
| `cxls004_modify_attr_mismatch.cx`     | `CXLS004`     | error    |
| `cxpath_focus_hover.cx`               | (hover)       | —        |

## Expected completion emit

| Fixture                                  | Position (line, col) | Context        | Items                                  |
| ---------------------------------------- | -------------------- | -------------- | -------------------------------------- |
| `cxpath_completion_nodetest.cx`          | (1, 15)              | axis_or_name   | 12 axes + element names from document  |
| `cxpath_completion_axis.cx`              | (1, 22)              | name_only      | element names only (axis already set)  |
| `cxpath_completion_predicate.cx`         | (1, 20)              | attr_predicate | `@`-prefixed attribute names           |

Note: a diagnostic fixture may additionally emit a `cx-parse`
data-parser error on the same buffer if `cx.parse(source)` rejects
the shape; that error comes from `publish_diagnostics` (the data-parser
shape-check) and is independent of the CXLS00x layer, which runs via
`match_diagnostics(source)` / `modify_diagnostics(source)`. The
current bracket-clause fixtures parse cleanly, so each probe emits
exactly its one expected CXLS00x diagnostic.
