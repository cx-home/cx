# `cx lsp` — Phase 5.5 fixtures

Source fixtures for the six diagnostic / hover / completion affordances
landed in Phase 5.5 (CXLS001, CXLS002, CXLS003, CXLS004, CXPath focus
hover, CXPath path-context completion). Each fixture is a stand-alone
`.cx` file the LSP server should produce a specific diagnostic /
hover / completion response on.

Run the manual driver against the built `cx` binary:

```sh
# Diagnostics (CXLS001–004):
python3 tooling/lsp/tests/probe.py ./vcx/target/cx diag tooling/lsp/tests/cxls001_unreachable_after_else.cx
python3 tooling/lsp/tests/probe.py ./vcx/target/cx diag tooling/lsp/tests/cxls002_missing_else.cx
python3 tooling/lsp/tests/probe.py ./vcx/target/cx diag tooling/lsp/tests/cxls003_when_consolidation.cx
python3 tooling/lsp/tests/probe.py ./vcx/target/cx diag tooling/lsp/tests/cxls004_modify_attr_mismatch.cx

# CXPath focus hover:
python3 tooling/lsp/tests/probe.py ./vcx/target/cx hover tooling/lsp/tests/cxpath_focus_hover.cx 0 16

# Path-context completion:
#   axis_or_name position (right after `//`)
python3 tooling/lsp/tests/probe.py ./vcx/target/cx completion tooling/lsp/tests/cxpath_completion_nodetest.cx 1 15
#   name_only position (right after `::`)
python3 tooling/lsp/tests/probe.py ./vcx/target/cx completion tooling/lsp/tests/cxpath_completion_axis.cx 1 22
#   attr_predicate position (right after `[`)
python3 tooling/lsp/tests/probe.py ./vcx/target/cx completion tooling/lsp/tests/cxpath_completion_predicate.cx 1 20
```

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
