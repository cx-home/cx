# `cx lsp` v0.8.0 diagnostic + completion surface (reserved)

This document **reserves the diagnostic codes and protocol slots** that
the v0.8.0 surface (code.md §5.5 / §8.2 / §8.10) introduces. The
implementation lives in `vcx/cmd/lsp_features.v` (a separate session;
see Phase 5.5 of `docs-src/canonical/v0_8_0_session_prompt.md`). This
file is the contract the implementation must honour — codes here are
load-bearing for diagnostic-aware editor configs and test fixtures.

## Reserved diagnostic codes

| Code      | Severity   | Trigger                                            | Spec ref | Status (v0.8.0) |
| --------- | ---------- | -------------------------------------------------- | ------- | --------------- |
| `CXLS001` | warning    | unreachable `[?match]` arm — a `[case …]` / `[when …]` after a catch-all `[else …]`, or a `[case …]` duplicating an earlier `[case …]` pattern source text | code.md §8.2 | implemented (Phase 5.5; full-AST via `code.parse`) |
| `CXLS002` | hint       | `[?match]` with no `[else …]` arm (silent `()` fallout) | code.md §8.2 | implemented (Phase 5.5; full-AST) |
| `CXLS003` | hint       | sibling `[when …]` arms with byte-identical predicate source text (consolidation suggestion; no semantic equivalence) | code.md §8.2 | implemented (Phase 5.5; full-AST) |
| `CXLS004` | error      | `[?modify]` `[set-attr …]` / `[delete-attr …]` targeting an attribute-step focus path | code.md §8.10 | implemented (Phase 5.5 finish; static-parse-error remap + defensive AST walk) |
| `CXLS005` | hint       | `[?map]` / `[?reduce]` with a `[par]` clause whose function body **calls an impure builtin** (code.md §7.3) with no `[?bulkhead]` wrap — impure workers spawn one-per-item (unbounded fan-out can race / exhaust resources). A **pure** `[par]` body is safe to evaluate in parallel and reorder (no effect races) and gets no hint. Suggested fix: wrap in `[?bulkhead max-concurrent=K]`. | code.md §7.3 | implemented (v0.8.0; SAP C5 §7.3 impure-gate — `code.node_calls_impure_builtin` over the function body) |
| `CXLS006` | error      | predicate-body purity violation — `[expr]` body calls an impure function or classified-impure builtin (paired with runtime `CXER0230`) | code.md §5.5.2 |
| `CXLS007` | error      | `$_` / `$_position` / `$_last` reference outside a PredicateExpr body (paired with runtime `CXER0231` for `$_position` / `$_last`; `$_` outside a predicate is a normal binding so this fires only when no in-scope user binding exists) | code.md §5.5.2 |
| `CXLS008` | error      | inferred-purity mismatch — `[?def]` annotated `pure` (explicit or default) whose call graph reaches an `impure` function or classified-impure builtin (paired with runtime `CXER0233`) | code.md §12.2 |

Codes are stable strings; editor configs (`tooling/lsp/{vscode,
neovim, helix}.example.*`) may key off them to surface custom UI.
`CXLS004` maps to the runtime error `CXER0100` (see
`spec/cx_native_error_codes.md`) — same surface, but caught at LSP
analysis time before evaluation.

## Reserved protocol slots

### `textDocument/hover` (code.md §5.5)

A hover on a CXPath path expression shows:

1. The path's resolved XPath production (`PathExpr` → `StepList` →
   per-step axis / node-test / predicate breakdown).
2. Live match-count against the document the hover is in
   (`select_all(path).len`).
3. Axis-name documentation (one-line synopsis from the XPath 3.1
   alignment table in `spec/cxpath_alignment.md`).

Sample LSP `Hover.contents`:

```
/section[2]/p[@lang="en"]

→ child::section[position()=2]/child::p[@lang="en"]
→ matches 3 nodes in this document
→ axis `child::` selects direct children (default axis)
```

### `textDocument/completion` (code.md §5.5) — Phase 5.5 finish, implemented

**Status:** Path-context completion is implemented for v0.8.0 in
`vcx/cmd/lsp_modify_diagnostics.v` (function `path_completion_items`
+ helper `detect_path_context`). Wired through the
`handle_completion` dispatch in `vcx/cmd/lsp.v`; items are
prepended ahead of the directive / module-function completions
so editors that respect `sortText` will list path candidates first.

Path-context completion: when the user is typing inside a `//`-prefix
path, the completion list contains:

1. **Axis names** (12 entries — `child::`, `descendant::`,
   `descendant-or-self::`, `parent::`, `ancestor::`,
   `ancestor-or-self::`, `following-sibling::`,
   `preceding-sibling::`, `following::`, `preceding::`, `self::`,
   `attribute::`).
2. **Element names** drawn from the live document (de-duplicated set
   of all `tag_name` values reachable from the document root).
3. **Attribute names** (after typing `@`): de-duplicated set of all
   attribute names in the document.
4. **Function names** (after typing an identifier in predicate
   position): `count()`, `position()`, `last()`, `name()`,
   `local-name()`, `sum()`, etc. — XPath 3.1 functions whose
   alignment is recorded in `spec/cxpath_alignment.md`.

Each completion item carries `data.path_axis: true` so the editor can
sort path completions distinct from generic identifier completions.

> **TODO (Phase 5 / code.md §5.5):** When the LSP implements path
> interior parsing for hover + completion, it must honour the
> path-step disambiguation rules. A `:` glued to a NodeTest is the
> namespace qualifier (`//svg:rect` — prefix:local); a free-standing
> `:NAME` after whitespace is an atom literal (code.md §3.6); a
> glued `::` is a type annotation (grammar.ebnf [26]); and a
> parenthesised `(bind $name)` after a NodeTest is the step-bind
> annotation (grammar.ebnf [160a]). None of these are
> directive-modifier slots — the v0.7 colon-slot modifier surface is
> retired.

### CXPath focus hover (Phase 5.5 — implemented)

A hover on any byte offset covered by a `ProgramPathExpr` node (per
code.md §5.5) returns a markdown response describing the path:

```
**CXPath expression** (code.md §5.5)

**Anchor:** `//` (descendant-or-self)

**Step count:** 2

**Steps:** `user/name`

**Focus type (static):** `any`
```

The CXPath hover takes precedence over the generic per-word docs
hover (`hover_docs_for` in `lsp_content.v`). When the cursor is
outside every `ProgramPathExpr` source range, the hover provider
falls through to the word-lookup path. Implementation:
`cxpath_hover_at` / `find_pathexpr_at` / `render_pathexpr_hover`
in `vcx/cmd/lsp_match_diagnostics.v`.

Static focus-type inference is deliberately stubbed to `"any"`. The
LSP affordance ships now so editors / tests can wire the response
shape; the type-inference fill-in lands in a follow-up LSP session
once CXPath schema-binding mode (post-v0.8.0) provides static type
information.

## Diagnostic emit sites (V implementation pointer)

The implementing V session should add diagnostic emitters in
`vcx/cmd/lsp_features.v` at the function that walks the parsed
program AST:

```
// vcx/cmd/lsp_features.v — pseudo-code

fn analyse_match_directive(m MatchDirective, mut diags []Diagnostic) {
    // CXLS001 — unreachable arm after [else …] or [case _ …]
    mut seen_catchall := false
    for i, arm in m.arms {
        if seen_catchall {
            diags << Diagnostic{
                code: 'CXLS001'
                severity: .warning
                range: arm.range
                message: 'unreachable [?match] arm — preceding arm is a catch-all ([else …] or [case _ …])'
            }
        }
        if arm.is_else || arm.is_case_wildcard {
            seen_catchall = true
        }
    }

    // CXLS002 — missing [else …] arm
    if !m.arms.any(it.is_else) {
        diags << Diagnostic{
            code: 'CXLS002'
            severity: .hint
            range: m.range
            message: '[?match] has no [else …] arm — non-matching values silently yield ()'
        }
    }

    // CXLS003 — sibling [when …] arms with similar predicates
    // (pattern-recognise only; do not auto-fix)
    detect_similar_when_predicates(m, mut diags)
}

fn analyse_modify_directive(m ModifyDirective, mut diags []Diagnostic) {
    // CXLS004 — [set-attr …] / [delete-attr …] on attribute-step path
    if m.focus.last_step_is_attribute() {
        for action in m.actions {
            if action.kind in [.set_attr, .delete_attr] {
                diags << Diagnostic{
                    code: 'CXLS004'
                    severity: .error
                    range: action.range
                    message: '[${action.kind} …] requires an element-focused path; the focus path ends with @${m.focus.last_attr_name}'
                }
            }
        }
    }
}
```

Completion provider sketch:

```
fn complete_in_path_context(doc Document, pos Position) []CompletionItem {
    mut items := []CompletionItem{}

    // Axes (always)
    for axis in cxpath_axes {
        items << CompletionItem{
            label: '${axis}::'
            kind: .keyword
            data: {'path_axis': 'true'}
            detail: cxpath_axis_doc(axis)
        }
    }

    // Element names from the live document
    for name in doc.distinct_element_names() {
        items << CompletionItem{
            label: name
            kind: .class
            detail: 'element from open document'
        }
    }

    return items
}
```

## Tests

Reserved fixture files (the implementing session should add these
under `conformance/lsp/`):

- `conformance/lsp/match_unreachable.cxd` — CXLS001
- `conformance/lsp/match_no_else.cxd` — CXLS002
- `conformance/lsp/match_when_consolidation.cxd` — CXLS003
- `conformance/lsp/modify_attr_path_error.cxd` — CXLS004
- `conformance/lsp/hover_cxpath.cxd` — hover provider snapshot
- `conformance/lsp/completion_path.cxd` — completion provider snapshot

Each fixture follows the `LSP_REQUEST` / `LSP_RESPONSE` JSON-pair
envelope (the `conformance/lsp/` directory and its envelope land with
the conformance runner's LSP mode — reserved, not yet created; the
interim manual driver is `tooling/lsp/tests/probe.py`, see
`tooling/lsp/tests/README.md`).

## Capabilities advertised

`cx lsp` `initialize` response must continue to advertise
`hoverProvider: true` and `completionProvider: { triggerCharacters:
[":", "/", "@", "$"] }`. v0.8.0 adds `/` to the trigger set so path
completions fire at the start of `//path` typing.

## Atom literal recognition (code.md §3.6)

The v0.8.0 surface introduces atom literals (`:NAME`) as a new
first-class scalar kind (see [`spec/core/code.md` §3.6](../../spec/core/code.md)).
Atom recognition in `cx lsp` is now fully implemented across both
highlighting paths:

- **TextMate scope (`tooling/syntax/cx.tmLanguage.json`)** — atoms
  match `constant.other.atom.cx` via the `:[A-Za-z_][A-Za-z0-9_-]*`
  pattern. Editor highlighting picks this up automatically on reload.
- **Semantic tokens (`textDocument/semanticTokens/full`)** — atoms
  emit as `tt_atom` (token type 10, `enumMember` in the LSP legend)
  via a parser-driven overlay added in the code.md §3.6-Gap-4 fix
  (`vcx/cmd/lsp_content.v`). The lexer emits all `:ident` tokens as
  `tt_parameter` first; `atom_positions_from_parse` then calls
  `code.parse` and walks the resulting `ProgramLiteral{kind: .atom_lit}`
  AST nodes to produce an override map, which reclassifies atom
  positions to `tt_atom`. Slot labels remain `tt_parameter` because
  they appear only in `ProgramSlot` / `ProgramDirective.slots` — not
  as standalone `ProgramLiteral` nodes. On parse failure (e.g. while
  the user is mid-edit), the override map is empty and all `:ident`
  tokens fall back to `tt_parameter` — graceful degradation with no
  visible blink.

Reserved-name rejection (`:true` / `:false` / `:null` per code.md §3.6)
surfaces as a `CXER0100` parse error in `textDocument/publishDiagnostics`
through the existing parser-error pipeline — no new `CXLS00x` code
is needed.

## General predicate + purity surface (code.md §5.5.2 + code.md §12.2)

The v0.8.0 surface introduces `[expr]` general predicates with
reserved bindings (`$_`, `$_position`, `$_last`) and a per-step
`(bind $name)` step annotation (see [`spec/core/code.md` §5.5.2](../../spec/core/code.md)),
backed by a static purity-annotation system on `[?def]`
(`pure` / `impure` per [`spec/core/code.md` §12.2](../../spec/core/code.md)).
The LSP exposes three new diagnostic codes (`CXLS006` /
`CXLS007` / `CXLS008` above) and the following protocol surfaces.

### Semantic-token highlights

- **Reserved predicate bindings** — `$_`, `$_position`, `$_last`
  highlight as `tt_parameter` with a `data.predicate_reserved:
  true` modifier so editors can colour them distinct from user
  bindings if desired. Outside a predicate body the names
  highlight as ordinary bindings (no modifier).
- **`(bind $name)` step annotation** — the `bind` keyword highlights
  as a `tt_keyword` modifier (same scope as the `scope=` / `[returns]`
  def modifiers). The bound `$name` highlights as `tt_parameter`
  definition.
- **`pure` / `impure` bareword modifiers** — highlight as `tt_keyword`
  modifiers on `[?def]`. Editor configs MAY surface the
  annotation as inlay-hint above the function head.

### `textDocument/hover` (code.md §5.5.2 + code.md §12.2)

A hover on a `[?def]` head shows the function's annotated **and**
inferred purity (when they agree, one line; when they diverge,
two lines — the inferred-purity diagnostic CXLS008 also fires
on the function head).

A hover on a predicate `[expr]` shows the resolved purity status
of the body (pure / would-fail-CXLS006). A hover on `$_` inside
a predicate shows the resolved type of the candidate item (e.g.
"element [user]" when the predicate filters `//user`).

### Diagnostic emit sites (V implementation pointer)

The implementing V session should extend `vcx/cmd/lsp_features.v`
with three analysers:

```
// vcx/cmd/lsp_features.v — pseudo-code (code.md §5.5.2 / code.md §12.2)

fn analyse_predicate_body(p PredicateExpr, mut diags []Diagnostic) {
    // CXLS006 — purity violation in predicate body
    impure_calls := walk_call_graph_for_impure(p.body)
    for call in impure_calls {
        diags << Diagnostic{
            code: 'CXLS006'
            severity: .error
            range: call.range
            message: 'predicate body calls impure ${call.kind} `${call.name}` — predicates must be pure (code.md §5.5.2). Move the impure call to an outer :where, [?let], or [?for] body.'
        }
    }
}

fn analyse_reserved_binding_use(node Node, scope []ScopeFrame, mut diags []Diagnostic) {
    // CXLS007 — $_position / $_last outside predicate
    if node.kind == .binding && node.name in ['_position', '_last'] {
        if !scope.any(it.kind == .predicate_body) {
            diags << Diagnostic{
                code: 'CXLS007'
                severity: .error
                range: node.range
                message: '$${node.name} is reserved for predicate bodies only (code.md §5.5.2). Use [?for] or [?let] for ordinary position / size needs.'
            }
        }
    }
}

fn analyse_def_purity(d DefDirective, mut diags []Diagnostic) {
    // CXLS008 — inferred-purity mismatch
    inferred := infer_purity(d.body)
    declared := d.modifiers.pure_impure_or_default()
    if declared == .pure && inferred == .impure {
        diags << Diagnostic{
            code: 'CXLS008'
            severity: .error
            range: d.head_range
            message: '[?def] `${d.name}` is ${if d.has_explicit_pure { "pure" } else { "default-pure" }} but its body calls impure constructs (code.md §12.2). Annotate impure or replace the impure calls.'
            related: inferred.impure_call_sites
        }
    }
}
```

### Completion provider — `(bind $name)` annotation

When the cursor is in PathStep-trailing position (after a NodeTest
or the closing `]` of a predicate), include a `(bind $name)`
snippet completion (grammar.ebnf [160a]). Filter it out only when
the current step already carries a bind annotation (at most one
per step).

### Reserved-binding completion

Inside a predicate body, `$_` / `$_position` / `$_last` appear as
completion candidates (kind `Variable`, sortText prefix `0_` so
they sort above user bindings).

### Tests

Reserved fixture files (the implementing session should add these
under `conformance/lsp/`):

- `conformance/lsp/predicate_purity_violation.cxd` — CXLS006
- `conformance/lsp/reserved_binding_misuse.cxd` — CXLS007
- `conformance/lsp/def_purity_mismatch.cxd` — CXLS008
- `conformance/lsp/hover_predicate.cxd` — predicate-body hover snapshot
- `conformance/lsp/hover_def_purity.cxd` — `[?def]` purity hover snapshot
- `conformance/lsp/completion_bind_annotation.cxd` — `(bind $name)` completion in step-trailing position

## Out-of-scope for v0.8.0

- Auto-fix code-actions for CXLS003 (consolidation) — recognise only,
  don't rewrite. Code-action arrives in v0.8.x.
- Schema-aware completion (full type-checked element/attribute lists)
  — requires schema-binding mode; v0.9.x.
- Exhaustiveness check for `[?match]` against ADT schemas — gated on
  algebraic-data-type schema support per code.md §8.2.

## Future-reserved diagnostic codes (post-v0.8.0)

The following diagnostic codes are reserved for future LSP work but
are explicitly out-of-scope for the v0.8.0 surface. Listing them here
preserves the code-number contract so that runtime impls and
documentation can pre-reference them.

| Code      | Severity   | Trigger                                            | Spec ref |
| --------- | ---------- | -------------------------------------------------- | ------- |
| `CXLS005` | warning    | `[?modify] [using …]` produces a kind-shifted result whose down-pipe expression assumes the focus kind (e.g. element-focus + string-return feeds a downstream CXPath that walked the focus as an element) | code.md §8.10 |

`CXLS005` is the LSP-side advisory for the code.md §8.10 kind-shift
contract (locked 2026-05-23 — `[using …]` may legitimately return any
kind regardless of focus kind). The diagnostic should:

1. Detect `[using …]` actions whose body's static return-kind differs from
   the focus path's static kind (element vs scalar vs sequence).
2. Walk the enclosing `[?pipe]` stage chain to find downstream
   `[?modify]` / `[?for]` / CXPath expressions that operate on the
   `[using …]` result as if it were the focus kind.
3. Surface as `warning` (not error). The kind-shift itself is legal;
   the downstream confusion is the issue.

Implementation is post-v0.8.0; the diagnostic emit site will mirror
the `analyse_modify_directive` shape under
`vcx/cmd/lsp_features.v`.
