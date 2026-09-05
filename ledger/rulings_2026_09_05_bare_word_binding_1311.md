# Ruling record — #1311 (a): a bare word in a data body does not read a binding (2026-09-05)

Issue: #1311 (bug, area:cx-lang, prio:medium). Spec: `core/code.md` §6.3b (callable
values), §6.5, §12.2.3 (bare-name references), §1.3 (the data / program reading);
`lexicon.ebnf` [L25a] / BC-1 (bare attribute values).
Engine: `vcx/code/dynamic_construction.v` — `eval_dc_body_items`.

## The defect

```cx
[?let [= $x 5] [wrapper x]]   → [wrapper 5]
```

A `[?let]` upstream silently rewrites the content of an unrelated data element. The DATA
reading of those same bytes is `[wrapper x]` either way, so §1.3's "data is a program that
evaluates to itself" seam held only when no binding of that name happened to be in scope.

**And one word meant three different things by position:**

| written | answered | specified? |
|---|---|---|
| `[wrapper x]` with `$x` bound | `[wrapper 5]` — the binding's value | **no** |
| `[wrapper cmd]` with `cmd` a def | the callable | yes — §6.3b |
| `[wrapper count]` (a builtin name) | `'count'` — the word | yes — §6.5 |
| `[wrapper a=x]` with `$x` bound | `'x'` — the string | yes — BC-1 / [L25a] |

Row 1 is the only one nothing documents. §6.3b's callable-value table specifies the bare
**def** reference; a search of `code.md` finds no bare **binding** reference anywhere —
only `[?quote]` lowering, let-binding syntax, and "a bare `$binding`", which is the
sigilled form.

## RULED (a): in a plain data-element construction body, a bare word is not a binding read

- **(a) RULED.** A bare, implicit, zero-argument word in element-body position whose name
  holds a BINDING contributes the data word. `$x` reads identically and is the form
  §12.2.3 already prefers ("`$name` … reads the same in every position").
  **DELETES:** an undocumented reading. Every affected site gains one character.
- (b) document it as a deliberate resolution order (binding → def → self-evaluate).
  Rejected: it makes one word mean three things by position *by design*, and it leaves the
  §1.3 seam conditional on the binding environment — the property that made this a defect
  report rather than a style question.
- (c) make it uniform the other way, so a bare ATTRIBUTE value also reads a binding.
  Rejected outright: it deletes BC-1 / [L25a] and the data-reading parity that ruling
  bought.

**The DEF reading is deliberately untouched.** It is specified (§6.3b), and `run.md` §4.1's
closures-in-data registry is built on it. Only the unspecified binding reading goes.

## Blast radius — MEASURED before the ruling, not estimated after

This is the discipline #1280 cost: the letter was not chosen until there was a number.
The change was implemented as a probe and every corpus in the tree was run against it.

| corpus | fixtures / units | affected |
|---|---|---|
| `conformance/code.cxd` | 1,530 | **1** |
| stdlib corpora, 72 module files | 3,714 | 0 |
| `guide-check` — every public def's `[fn-doc]` example | 68 modules | 0 |
| `verify-examples` | 26 | 0 |
| `verify-doc-blocks` | 750 blocks / 222 files | 0 |
| `conform-all` | 22 suites | 0 |

The single affected fixture is `cmd-030-what-a-bare-word-means-in-each-position`, whose
`binding-in-a-body` row was written the same day to document this behavior. **No
pre-existing fixture, stdlib module, doc example or tool relied on it.**

## Exit

`cmd-030`'s `binding-in-a-body` row re-recorded to `[wrapper 'x']` with the reason in its
`[meta]`; `code.md` §6.4.1 states the rule under `RULED: 1311`; the def reading and
`run-008` unchanged.
