# Ruling record — #1280: BOTH readings are load-bearing. Neither Q1 nor Q2 is ruled; the diagnostic is fixed instead (2026-09-05)

Issue: #1280 (bug, area:cx-lang, prio:medium). Spec: `core/code.md` §6.4.1 (element
construction), §6.3 / §6.5 (calls), §1.3 (the data / program reading), §9.2 (CXER0291);
`x/run.md` §4.1 (the closures-in-data registry pattern).
Engine: `vcx/code/eval.v` (`all_items_are_expr_position`, the D1 arm),
`vcx/code/dynamic_construction.v` (`eval_dc_body_items`), `vcx/cx/codec.v` (the
CXER0291 advice).

**This record is mostly a refutation of its own first two rulings.** I ruled both
letters, implemented both, and the tree refuted both — each with a specified,
documented counterexample. That is the useful content, so it is recorded in full
rather than summarized away.

## What is actually happening (the report's mechanism is wrong)

Nothing serializes sibling arguments. Measured on `6ebbe8743`:

| program (with `[?def cmd impure [effects] ($a='') [did a=$a]]` in scope) | answer |
|---|---|
| `[t3 1 cmd 7]` | `1` — `t3` is CALLED |
| `[t3 1 8 [do 'x' [a 1]]]` | `[t3 1 8 [do 'x' [a 1]]]` — a DATA element; `t3` is not called |
| `[t3 1 cmd [do 'x' [a 1]]]` | **CXER0291** |
| `[wrapper cmd]` (no element sibling, `wrapper` is not a def) | **CXER0291** |
| `[wrapper notadef [a 1]]` | `[wrapper 'notadef' [a 1]]` |

Two independent rules meet, and their product is the refusal:

1. `all_items_are_expr_position` treats a **plain bareword element child** as proof
   that the body is a DATA element body (#59 / #858 lineage), so a def-named head does
   not dispatch when one is present — row 2.
2. **D1 (#1231)**: a bare reference to a user callable is its VALUE. So `cmd` in that
   now-data body evaluates to the callable, is adopted as a child, and refuses at the
   serialization boundary (§9.2) — row 4 shows this half alone, with no def-named head.

## Q1 — "the head decides" — REFUTED by `stdlib/diagram.cx`

Ruled (a), implemented (a plain bareword element child stops vetoing when the head
names a user def), and:

```cx
[?def code-rules scope=public pure [returns element] ()
  [code-rules
    [trigger directive=worker rule="Actor lane; …"]
    [seq directive=send class=send rule="worker ->>+ channel : payload"]]]
```

**A def whose body constructs a data element with the def's OWN name** — the
self-named-constructor idiom, and `cx-x/diagram`'s public `code-rules` verb is written
exactly this way. Under (a) the inner `[code-rules …]` is a recursive call with
thirty-odd element arguments. Measured: `cx code-diagram` degenerated from
`i{"if $x"} / t["'big'"] / i -- "true" --> t / i -- "false" --> e` to a single generic
`b["[?if]"]`, and nine tests in `vcx/tests/code_units_umbrella_test.v` went red (the
CFG diamond, the match dispatcher, the modify block, the ERD attribute rows, the
recursion back-edge). **The construction gate is the only thing that lets one name be
both a def and a constructor**, and this tree uses that.

## Q2 — "a bare word in a data body is the data word" — REFUTED by `run.md` §4.1

Ruled (a), implemented (a bare implicit reference to a user def in element-body
position becomes the data word), and:

```cx
[?def greet-tool scope=public pure [returns string] ($name::string) [$concat "hi " $name]]
[?let [= $reg ([tool name=greet greet-tool], [tool name=shout shout-tool])]
  [reg [a [?splice [$dispatch $reg "greet" "dana"]]] …]]
```

`[tool name=greet greet-tool]` stores a **closure in data on purpose** — this is
`run.md` §4.1's post-#45 registry pattern, "closures stored in DATA elements, retrieved
by name predicate, invoked cross-scope", pinned by
`conformance/stdlib/run.cxd` `run-008-closures-in-data-registry-dispatch`. Under Q2 the
registry holds strings, and the fixture answers
`E_OPERAND_KIND: call head $r is bound to absence` twice instead of `hi dana` /
`HI dana`. My record claimed Q2 "DELETES nothing else"; **that claim was false.**

## The shape of the real question

A bare def name in an element body is EITHER the data word — so `[wrapper cmd]` is
stable against an unrelated `[?def cmd …]`, and §1.3's data/program seam holds — OR the
callable — so a registry can hold closures. **One rule cannot give both**, and each
reading is already specified and already relied on:

| reading | what it buys | what it costs |
|---|---|---|
| data word (Q2 a) | `[wrapper cmd]` means one thing whatever defs exist; the §1.3 seam | `run.md` §4.1's registry pattern, and the `[$run:invoke]` idiom around it |
| callable (status quo) | closures in data, cross-scope dispatch | a def declaration changes an unrelated document, and the failure is CXER0291 at the output |

## RULED, and landed: fix the DIAGNOSTIC — it changes no surface and is what the report actually cost

The reporter's loss was not the semantics; it was that the message sent them to the
wrong place. `CXER0291`'s advice said "APPLY it and return its RESULT", so they
concluded the construction path had serialized a sibling argument. The advice now names
both readings that produced the value (`vcx/cx/codec.v`, the ONE CXER0291 advice string,
so every boundary gets it):

> …If it came from a BARE def name in an element body, that is a closure-in-data
> reference (run.md §4.1): quote it (`'name'`) for the data word, and note that a
> bareword element child makes the enclosing form a data CONSTRUCTION, not a call —
> bind it first (`[?let [= $d [child …]] [head … $d]]`) if you meant to call.

**DELETES: nothing.** The code, the symbolic class, and every semantic stay exactly as
they were; this is the teaching half only, in the same spirit as #1142 rider 5 which
authored the first sentence. Both open letters below are unaffected by it — whichever
lands, the sentence stays true.

## Q1 — OPEN, owner's letter

- **(a) The head decides.** A def-named head is a call whatever kinds its arguments are.
  **DELETES:** the self-named-constructor idiom, and every data element whose head
  collides with a def name and whose body carries element children — here at minimum
  `cx-x/diagram`'s public `code-rules` verb, whose returned element name
  `code_diagram_completeness_gate_test.v` also diffs, so the fix is a rename of the def
  or the element, both shipped-surface changes.
- **(b) recommended — the body decides (status quo).** A plain bareword element child
  stays proof of a data element body; a caller wanting an element-literal argument binds
  it first. **DELETES:** nothing. §6.5's uniformity is real, but the gate is not
  arbitrary, and the improved diagnostic now says so at the point of confusion.
- (c) the head decides except when a child's head equals the outer head. Rejected: a
  rule about one coincidence that still breaks every other collision.
- (d) one namespace for def names and data element names, so the collision is a declared
  conflict at load. Loud and uniform, much the largest change, and it is #1311's
  question one level up.

## Q2 — OPEN, owner's letter

- **(a) the data word wins.** **DELETES:** `run.md` §4.1's registry pattern and the
  `run-008` fixture; every closure-in-data site respells as an explicit binding
  (`[?let [= $g greet-tool] [tool name=greet $g]]` — which still works, because a
  binding read is a value position).
- **(b) recommended — the callable wins (status quo) + the landed diagnostic.**
  **DELETES:** nothing. The action-at-a-distance remains real, but it now announces
  itself in a message that names both readings, and the surface that would be spent
  fixing it is one the language documents and uses.
- (c) make the two positions syntactically distinct — a marker that spells
  "closure-in-data" explicitly, freeing the bare word to be the data word.
  **DELETES:** nothing immediately, but it SPENDS a sigil or a keyword on a distinction
  the language has so far kept implicit, and it puts `run.md` §4.1's whole corpus on a
  cutover. Worth considering only together with #1311, whose binding half has the same
  shape.

Recommendation on both: **(b)** — because in each case the evidence that the current
reading is load-bearing came from the tree's own dog-fooded code, and the actual cost to
the reporter is now paid off by the diagnostic.

## Exit (what landed)

`conformance/code.cxd` `cmd-030` and `cmd-031` pin TODAY's answers across both
questions — the argument-kind asymmetry, the self-named constructor, the bare word in a
data body, the attribute/body disagreement, and the bracketed call — so whichever way
Q1 and Q2 land, the evidence is in the corpus and the change is visible as a fixture
diff. `run-008` and `stdlib/diagram.cx` untouched.
