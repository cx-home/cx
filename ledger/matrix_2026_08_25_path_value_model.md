# The path/value model — total matrix (Cluster A), measured and reconciled

**Status: DERIVED, NOT RULED.** This file is the VC-19 deliverable's first
stage: the total operand-kind × operation matrix, every cell **measured** on
the tree binary at `8ffe26c69` (built 2026-08-25, `-gc e`, profile platform),
prior rulings reconciled in writing, and the genuinely open cells posed as
lettered questions. Nothing here is normative until the owner rules; the
rulings will be recorded in this file's AMENDMENT sections before any
implementation (R6.1). Probe sources: session scratchpad `probes/k1..k15,
t1..t10`; every number below came out of a real run, none is inferred.

Mandate: VC-19 ("all these issues get solved and sound in 0.17.0 period"),
resequenced by VC-20 (clusters follow #700 wave 2, on Fable 5). Scope:
Cluster A (#961 #964 #965 #966 + reconcile #582–#587, #847, the
`[$first $x/*]` idiom), with the Cluster B (#962 #967) and C (#955, err
truthiness) decisions appended since their rulings gate the same
implementation pass.

---

## §1. The measured matrix

Operand kinds down, operations across. Cells marked ✗ violate normative text
cited in §2; cells marked **?** are decisions with no governing text. "n-s"
= node-set. Aggregates (`$count`/`$first`) are over the bare operand;
path-op cells are the operand stepped.

| operand ↓ / op → | `/name` | `//name` | `@attr` | `/@attr` | `/*` | `[pred]` | `$count` | `$first` |
|---|---|---|---|---|---|---|---|---|
| **element** | field-collapse (§2.1) / n-s when multi-match | n-s ✓ | typed value ✓ | n-s of 1 ✓ | children ✓ | ✓ `$_` bound | child count | first child |
| **sequence of elements** | distributes ✓ (3) | ✓ (3) | `(1, 2)` ✓ | `(1, 2)` ✓ | **members, not children ✗** (2 where 1010 says 3) | **`$_` unbound ✗** (`$s[pred]` parses, then CXER0001) | members ✓ | first member ✓ |
| **seq w/ non-element member** | skips ✓ | skips ✓ | skips ✓ (row 4) | ✓ | skips ✓ | — | ✓ | ✓ |
| **grouping envelope** (`[violations $seq]`) | **0 — silent ✗** (#961) | through ✓ (2) | — | 0 via child | 1 (the seq node) | 0 via child | — | `$bag/*`→the seq |
| **array (scalars)** | 0 | 0 | — | — | 0 (non-elements skipped) | — | **3 — items (cxdm §2.1 says type error)** | 1 |
| **array (elements)** | **0 — does NOT distribute ✗** (asymmetric with seq) | distributes ✓ (2) | — | distributes ✓ (2) | members (2) | — | members | first member |
| **map** | entry read, collapses (`'h'`) | ✓ | **`()` absence ?** (scalar refuses) | — | entries as `[k v]` (3) | — | entries (3) | first entry |
| **scalar** | `()` absence ✓ | `()` ✓ | refuses CXER0001 ✓ | — | **refuses CXER0001 ✗** (PS-1: child steps on scalar yield absence) | — | 1 | itself |
| **err** | 0 ✓ (inspection) | 0 ✓ | own attrs ✓ (`@code`) | — | 0 | — | **propagates err** | **propagates err** |
| **absence** | `()` ✓ | `()` ✓ | `()` | — | `()` ✓ | — | 0 ✓ | `()` ✓ |
| **document** (`[$cx:parse]`) | **`()` / count 0 — silent ✗** | ✓ through | — | — | **CXER0001 ✗** (fast path unwraps single-root; n-s path refuses) | — | 1 | — |

Lane split, measured: the same expression evaluates differently by engine
path. On a single-root parse result, bare `$d/*` yields the root's children
(fast path unwraps the document) while `[$count $d/*]` refuses CXER0001
(node-set path sees the DocumentNode). Two walkers, two answers — the same
class #847 closed for envelopes.

Err contagion, measured: an err used as an operand of a constructor
(`[list :k $e]`) or an aggregate (`[$count $e]`, `[$first $e]`) propagates
the err; navigation (`$e@code`, `$e//x`) inspects. Matches code.md's loud
callout exactly. Not a defect; pinned as three cells.

## §1.1 Predicate-context cells (the #965/#966 block)

Program lane, `[doc [user name=ada [tag] [tag]] [user name=bo [tag]]]`:

| probe | measured | expected under XPath n-s model |
|---|---|---|
| `$d/user[= [$count $_/tag] 0]` | **1 (bo) ✗** | 0 |
| `$d/user[= [$count $_/tag] 1]` | **0 ✗** | 1 (bo) |
| `$d/user[= [$count $_/tag] 2]` | 1 (ada) ✓ | 1 |
| `$d/user[= [$count $_/*] 1]` | 1 (bo) ✓ | control: wildcard never collapses |
| `$d/user[$strings:contains …]` with `[?lib]` | filters correctly ✓ | — |
| `$d/user[$nosuch:fn …]` | **selects ALL ✗✗** | — |
| `cx select '//user[$strings:contains …]'` | **selects ALL ✗✗** (#965) | — |
| `cx select '//user[= [$count $_/tag] 0]'` | bo ✗ (same as program lane) | — |

So #965 is TWO mechanisms: (i) **an err arising in a predicate reads as
truthy — engine-wide**, program lane included (`$nosuch:fn` selects all with
no `cx select` involved); (ii) `cx select` has no `[?lib]`, so every
`$strings:*` call errs there and (i) turns the filter into select-all. And
#966 is the §6.2 field collapse operating in predicate position: `$_/tag`
for bo (one empty `[tag]`) collapses to the element, `$count` of a bare
element is its child count, 0. Both mechanisms measured, neither inferred.

## §1.2 Document cells (the #964 re-diagnosis)

#964's filed diagnosis — "/* refuses because one member is a comment" — is
**wrong**. Measured: `[$cx:parse "[a x=1]\n[b x=2]"]` (no comment anywhere)
refuses `$d/*` identically, and `$d/a` is silently `()` / count 0. The
comment never mattered; **multi-rootedness** does. `cx:parse` yields a
DocumentNode; the fast path unwraps it only when single-rooted (making the
issue's control accidentally pass); the node-set path refuses `/*` and
returns absence for `/name` on every document. The comment-first case is
just the multi-node case. The spec side is already written: cxdm §2.2 "a
Document Item used as a sequence member is treated as a sequence of its
top-level children, flattened" + code.md:1010 row 4 (non-element members
skip, not a fault).

## §1.3 Envelope cells (the #961 block) and #847-1a

All four construction shapes produce the same envelope today:
`[violations $vs]`, `[?element "violations" $vs]`, `[c [?for … [yield …]]]`,
and a parsed paren-seq body. Measured on every one: `/violation` 0 (silent),
`//violation` 2, `/*` 1, `/*/violation` 2, `[$first $bag/*]` = the whole
sequence. Round-trip parity holds (`/*`,`/name`,`//name` identical after
`cx:parse∘cx:canonical`, hash-equal) — #847's landed fix is intact at HEAD.
`[?splice]` control: 2/2/2 on every axis.

**The standing owner ruling this cluster must build on:** #847-1a
(2026-08-18, verbatim in the issue): *"a sequence as an element's sole child
is refused at construction"* — auto-splice explicitly rejected ("silently
rewrites what the author wrote"), axis-widening explicitly rejected ("makes
`/*` provenance-dependent forever"), `[?splice]` named the only idiom.
**That refusal was never implemented** (every shape above constructs today).
It resolves #961 as a loud construction error instead of a silent 0 — the
author writes `[violations [?splice $vs]]` and gets 2 on every axis.
Consequence for the preserved VC-13 worktree: the #961 grouping-transparency
commit (`expand_seq_items`) contradicts #847-1a and #587's pinned child-axis
scope, and does NOT ride. Consequence for the `[$first $x/*]` idiom sweep:
under refusal there is no transparency flip, so no idiom shifts meaning; the
sweep reduces to migrating construction sites that the new refusal catches
(rosetta #05's documented `//n` workaround becomes a `[?splice]` instead).

## §2. Prior rulings reconciled (in writing, per VC-19)

- **#584 (owner, 2026-07-23, ruling (b))** — field-read uniformity: `$x/field`
  reads content, uniformly over content kinds; `[$count $x/field]` = content
  arity for single-match fields; match-counting uses node-set forms. SETTLED,
  never re-litigate. Measured intact at HEAD (`[$count $b/life]` = 3).
  Nothing in this matrix touches it: §Q3's recommendation resolves #966 by
  classifying predicate-rooted paths as node-set forms — a boundary #584's
  own text already draws ("node-set queries … are unaffected").
- **#587 (2026-07-23)** — the child axis does not dissolve a sequence in
  element content; descendants pass through; pinned by fixture. STANDS.
- **#847 (2026-08-18)** — closed in two parts: the parity fix (in-memory ≡
  reparsed ≡ bytes-lane on every axis, landed, measured intact) and ruling
  1a (construction refusal, NOT yet implemented). Both stand; 1a becomes an
  implementation obligation of this cluster (Q1 settles its directive-result
  edge).
- **code.md:1010 (O4, normative)** — steps distribute over sequences of
  elements; non-element members skip, not a fault. Measured: HOLDS for bound
  sequences on `/name`, `//name`, `/@attr`, bare `@`, mixed members — the
  five distribution rows all pass. Violated by exactly three operand classes:
  `/*` (returns members, not distributed children), arrays (`/name` does not
  distribute while `/@attr` and `//name` do), documents (§1.2).
- **cxdm §2.1** — "Calling `count(arr)` on an Array is a type error; the user
  writes `count(items(arr))`." Measured: `[$count [1,2,3]]` = 3, and the
  items-view reading is what code.md's §6.2 composition (#584's 3-arity
  example) is built on. The two approved specs conflict; Q5 decides which
  sentence moves.
- **PS-1/CRS-1/BP-1 (2026-08-20)** — result steps ≡ bind-then-step, kind-
  driven and total: "a child step on a scalar yields empty (absence), @attr
  on a non-element refuses typed". Measured: holds for `/name`; `/*` on a
  scalar refuses instead of yielding absence (one cell out of line with the
  totality sentence).

## §3. The unified model (proposed, pending rulings)

One sentence per axis, each already the majority behavior:

1. **Focus classes:** element (children = its items), collection (sequence/
   array — members = its items; document — top-level nodes = its items),
   map (entries = its items), scalar/err/absence (atoms — no children).
2. **Steps distribute over collection focus** (1010 as written), skip
   non-element members, preserve order, collapse to absence when nothing
   contributes. Applies to `/name`, `//name`, `/@attr`, `@`, `/*`, and
   predicates uniformly — the three violating operand classes (seq-`/*`,
   array-`/name`, document-everything) are brought to the rule.
3. **Field collapse (#584) is a program-lane read idiom**: it applies to
   simple field accessors in value position and never to node-set forms;
   predicate-rooted paths (`$_/…`) are node-set forms (Q3).
4. **Aggregates are items-view**: `$count`/`$first` = size/head of the
   focus's items (element → children, collection → members, map → entries,
   scalar → itself, absence → 0); err propagates (Q5 pins this normatively
   and amends the cxdm sentence).
5. **Faults are loud, absence is quiet**: a missing name/attr on a
   compatible focus is absence; an operation a focus cannot carry (typed
   `@attr` on scalar) refuses CXER0001; an err *arising* inside predicate
   evaluation refuses the query (Q4); an err *value* navigated is data.
6. **A bare sequence never becomes element content** (#847-1a): refused at
   construction, `[?splice]` the only idiom; parsed paren-seq bodies remain
   the settled opaque-envelope cells (#587/#847) so data stays parseable.

Every cell of §1 lands in exactly one of these six sentences; the frozen
spec text will carry the full table with one conformance case per cell,
negative cases per refusal (the similar.md §3.2 / #853 pattern).

## §4. Open cells — the questions

Recorded here before work; answers to be appended as AMENDMENTs.

**Q1 — directive results in element content, under #847-1a's refusal.**
`[c [?for … [yield [x …]]]]` builds the refused shape today. (a) A
program directive in a multi-sibling slot contributes its result **spliced**
([?for]/[?if]-of-sequence in element body behave as [?splice] does — the
directive is program surface, so this is not the value auto-splice #847-1a
rejected; `[violations $vs]` and `[?element n $seq]` still refuse). (b) The
refusal is total: any sequence landing as sole content refuses; authors
write `[?splice [?for …]]` everywhere. (c) Transparency instead of refusal
(the VC-13 worktree's `expand_seq_items`) — overrides #847-1a and #587.
**I recommend (a)**: it keeps #847-1a's line (no VALUE silently rewritten —
a directive result is not a value the author wrote, it is the directive's
defined contribution), keeps the natural comprehension shape legal, and
leaves (b)'s migration cost unpaid. (b) is the safer-but-hostile pick —
every comprehension-in-body in existing code refuses at once. (c)
re-litigates two settled rulings and makes `/*` counts provenance-dependent.

**Q2 — the document operand (#964 re-diagnosed).** (a) DocumentNode is a
collection focus per §3.2: `/name`/`/*`/predicates see top-level items,
non-elements skip, both walkers agree; `cx:parse` keeps returning one
document value (`$count $d` stays 1 under items-view = top-level count —
note this changes today's accidental 1-for-multi-root only in being
correct). (b) `cx:parse` stops returning a DocumentNode at program surface
(bare element when single-rooted, sequence otherwise) — no document kind to
specify, but multi-root results change kind by input, and `$doc` (--data
lane) needs the same treatment. **I recommend (a)** — one kind, one rule,
matches cxdm §2.2's existing flatten sentence; (b) makes a function's return
kind input-dependent, which is the shape #964's fast-path unwrap already
proved confusing.

**Q3 — count-in-predicate (#966).** (a) Predicate-rooted paths (any path
rooted at `$_`) are **node-set forms** — no terminal field collapse, so
`[$count $_/tag]` is a match count (0/1/2 all correct in §1.1) while
program-lane field reads keep #584 exactly as ruled. (b) `$count` of a bare
element becomes 1 (cxdm atom-Item reading) — fixes bo but breaks #584's
normative 3-arity example; requires re-opening a settled ruling. **I
recommend (a)**; (b) is listed because a prior session note pointed at it —
it is wrong precisely because #584 pinned `[$count $b/life]` = 3.

**Q4 — err arising in a predicate (the #965 root).** (a) **Loud**: an err
produced while evaluating a predicate body refuses the whole query
(CXER-class, naming the predicate and the err) — filters can fail-open
(select-all, today) or fail-closed (empty), and BOTH lie to a validation
pipeline; only refusal is sound. (b) Fail-closed: the node is not selected,
quiet — consistent with `[?if $err]` running neither branch, but a
validator over `//row[$f …]` then reports "no bad rows" on a broken
predicate. **I recommend (a)**. Err *values* navigated as data stay the
inspection lane either way; this rules only errs *raised during* predicate
evaluation.

**Q5 — aggregates over containers (cxdm §2.1 vs measured vs #584).** (a)
Pin items-view `$count`/`$first` normatively (element → children, collection
→ members, map → entries, scalar → 1, absence → 0, err → propagate) and
strike cxdm §2.1's `count(arr)`-is-a-type-error sentence as reconciled —
cxdm keeps the container/atom distinction for sequence *operations*; the
program-surface aggregates are kind-total. (b) Implement cxdm as written
(count over Array refuses) — breaks measured load-bearing behavior and the
#584 model. **I recommend (a)**: two approved specs conflict; the side that
is owner-ruled (#584), measured, and load-bearing wins; the cxdm sentence is
the one that moves. This is reconciliation of a contradiction, not truing a
spec to a shortfall — the alternative (b) is stated and implementable.

**Q6 — spec-forced corrections, batch confirmation.** Each of these has
governing text already; listed so the cells are ruled by name, not slipped
in: (i) `/*` over a collection focus distributes (children-union, 1010) —
today it returns the members; (ii) `/name` distributes over **arrays** of
elements as it already does over sequences (1010 + orthogonality; today 0);
(iii) `/*` on a scalar yields absence (PS-1 totality; today refuses — the
loud→quiet direction is deliberate: `/name` on scalar is already quiet, and
a *typed* read stays loud via `@attr`); (iv) a predicate directly on a bound
sequence/element (`$s[pred]`) binds `$_` per member and distributes (1010
"predicates/axes follow the same node-set rule"; today parses then
CXER0001 unbound); (v) `@attr` on a **map** refuses CXER0001 like every
non-element (PS-1; today silent absence — `.key` is the map read, and quiet
absence on `@` hides exactly the confusion the refusal names); (vi) `cx
select` with no loaded modules refuses unknown callables loudly (composition
of Q4a; today selects all). Confirm as a batch or strike any line.

**Q7 — Cluster B, comment fidelity (#962/#967).** The lane matrix is: data
read/write preserves comments (measured ✓); program render dumps a V struct
(#962, measured live at HEAD); `cx fmt` deletes every comment (#967,
measured live at HEAD, spec explicit at cli.md:107/209 + canonical.md §1.2).
Both fixes are spec-forced; the one open call is mine to flag: the VC-13
worktree's #962 fix (CommentNode through the data emitter + the
line-comment newline guard against document truncation) was independently
verified including round-trip re-parse, and is **orthogonal to every
contested cell above** — I intend to port it in the implementation pass
regardless of Q1–Q6 outcomes, and to fix #967 by routing `cx fmt` through
the same lossless emitter the data lane already uses (one implementation,
per #967's scope note). Say only if you want either handled differently.

**Q8 — Cluster C, error surfacing (#955).** Spec direction is already
recorded (db_access.md: operand-kind faults are the CXER0100/E_ARG lane,
checked before other logic; `user-undefined` is name resolution only). The
fix: `or { return none }` kind-mismatch arms across `stdlib_*.v` return a
CXER0100 operand-kind err naming the argument position and expected kind and
the name AS WRITTEN — never the internal builtin name; `none` stays "not my
name". One question: (a) uniform `CXER0100` for operand-kind everywhere (the
candidate tightening db_access.md itself records), or (b) per-module codes
where they already exist (E_SQL etc.), CXER0100 elsewhere. **I recommend
(a)** — one lane, one code; existing per-module codes stay valid as *values*
inside the err (`kind=` attr) if wanted, but the code lane is uniform.

## §5. Sequencing after rulings

1. Spec amendment pass: code.md §6.2 (the six sentences + full table),
   cxdm §2.1/§2.2 (Q5), cli.md untouched (#967 is impl-only).
2. Conformance grid: one case per cell, negatives per refusal, in
   `conformance/code.cxd` (NOTE the standing trap: new in-cx rows move the
   cxparse differential baseline — update deliberately with a movement note).
3. One implementation pass: the three distribution defects (Q6 i/ii/iv),
   document focus (Q2), predicate node-set form (Q3), predicate err refusal
   (Q4 + select), #847-1a refusal (+ Q1's directive rule), aggregates pinned
   (Q5), #962 port, #967 fmt, #955 sweep.
4. Freeze: changing a cell thereafter requires a ruling naming the cell.
   The `[$first $x/*]` sweep and rosetta #05's `//n`→`[?splice]` migration
   ride step 3.
