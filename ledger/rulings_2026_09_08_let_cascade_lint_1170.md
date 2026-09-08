# Ruling — the `[?let]`-cascade lint lands with an EMPTY allow-list (#1170 §C3)

**Ruling id:** 1170-c
**Date:** 2026-09-08
**Ruled by:** Fable session, 09:25 ET, on #1170; premise CORRECTED by the same
session at 09:50 ET and by the owner's note on #1354 at 09:50 ET.
**Status:** RULED before the work. Recorded here by campaign worker C, which
implements it and rules nothing in it.
**Follows:** `ledger/rulings_2026_09_08_playground_output_pin_1170.md` (1170-a)
and `ledger/rulings_2026_09_08_bare_builtin_head_lint_1170.md` (1170-b). 1170-b
left §C3 to the worker "when it is built"; the letters below were drafted for
that and ruled by Fable rather than by the worker, because the answer turned on
a resource the worker could not spend unattended.

## The class to catch

`[?let]` takes ALL its bindings in ONE flat list, and each one can read the
ones before it (`spec/03-approved/lang/code.md` §8.5). Reaching for a second
`[?let]` to add a second binding is a Scheme habit, tracked as #361. The
playground corpus TAUGHT it: 16 of 202 entries cascaded, `172` six deep, and
`17-let-nested` was the worst case because its own note presented the cascade
as the idiom. §C1's Part A flattened thirteen of them by hand and repaired
`17`'s note; §C3 is the mechanical detector, so the class cannot come back one
example at a time.

## The question, as drafted on #1170

Three cascades were deliberately left standing — `162-sequence-select-channels`,
`171-seq-mid-producer-consumer`, `172-seq-large-workers-with-backpressure`.
They are the SEQUENCE-DIAGRAM examples, and `make test-playground-mermaid`
grades the emitter's shape classification, so landing a shape change to them
without running that gate is how a false green happens. The gate was measured
unrunnable: `dist/wasm/` present, `emcc` present, `node_modules/jsdom` ABSENT.

1. How does §C3 get past the three?
   - **(a)** Install jsdom once, flatten the three under a green
     `test-playground-mermaid`, land §C3 with an EMPTY allow-list.
   - **(b)** Land §C3 now with the three on an allow-list whose stated reason is
     the literal truth, and empty it later.
   - **(c)** Leave §C3 unbuilt until the diagram gate is runnable.
2. `make test-playground-wasm-eval` over the 20 new entries — **(a)** now,
   while the entries are fresh, or **(b)** deferred to the release lane.

## The ruling — 1 = (a), 2 = (a)

Fable ruled **1(b) now, 1(a) as the end state** at 09:25 ET on the measured
premise that jsdom was absent. That premise was **wrong, and was corrected by
the same session at 09:50 ET**: jsdom IS installed where the gate looks —
`scripts/playground-gate/node_modules/jsdom` exists and loads, and the gate
resolves from `scripts/playground-gate` (`test_playground_mermaid.mjs:157`).
The ABSENT reading came from checking the repo root. The correction says so
explicitly: "1170-c's 1(a) is unblocked now — flatten `162`/`171`/`172` under a
green `test-playground-mermaid`, land §C3 with an EMPTY allow-list, and run
`test-playground-wasm-eval` for the 20 new entries while at it (2(a)). No owner
install needed." The owner's #1354 note at 09:50 ET repeats it: "go straight to
1170-c's 1(a) … and 2(a)."

**So the operative ruling is 1(a) + 2(a), and 1(b) is dead** — it existed only
to route around a blocker that does not exist. Re-verified before implementing
(worker C, 11:47 ET): the directory is present, `require` returns a function,
and the stray root-level `package.json` / `package-lock.json` / `node_modules`
are gone.

**Deletes:** the allow-list mechanism §C3's sketch on #1170 asked for, in full
— the corpus marker, its both-directions grading, and the standing debt of
three entries whose stated reason would have been "not yet flattened". Nothing
in the corpus carries it and nothing may add it: an escape hatch on this rule
could only ever be used to keep a cascade.

## The rule, as implemented, and why it needs no name list

The §C3 sketch asked for a text rule with an exemption by NAME: flag a `[?let]`
whose body opens another `[?let]`, but not the inner `[?let]`s inside an
`[?async]` or `[?worker]` body. That exemption is not needed, and asking the
ENGINE instead of a regex is what removes it — the same move 1170-b made for
§C2.

> A `[?let]` directive that has another `[?let]` directive as a DIRECT child is
> a cascade.

The inner one is then in the outer one's BODY position, which is the only place
a second binding list can go. Everything else nests through something — a
`[?for]`, a `[?fn]`, a `[?worker]`'s `[body …]`, an element — and is a
genuinely different scope, which `17-let-nested`'s repaired note names as
legitimate CX.

Measured over the corpus at `f2d9501d0`, the rule flags exactly the three known
cascades and nothing else:

```
srcs with >=2 [?let]:  84-async-mock-sleep  85-await-all  87-await-race  90-cancel
                       162-…  171-…  172-…
flat     84, 85, 87, 90              (inner [?let] inside an [?async]/[?worker] body)
CASCADE  162 (2)  171 (3)  172 (4)
```

So the four non-cascades pass on structure, with no directive named anywhere —
and a rule with no name list cannot go stale when a fifth scoping directive is
added.

**Source of truth is `cx --ast --compact` over the entry's own `src`.** `--ast`
does not evaluate, so a `[?lib]` head or a missing grant cannot reach it.
Attributes are not walked and cannot need to be: a node-valued attribute is
refused outright (D2 — `value=[…]` is `E211`), so a `[?let]` can only ever be
an item.

**The prefilter is sound rather than convenient.** Only an `src` carrying two
or more `[?let` occurrences is parsed — 7 processes over the corpus, not 202 —
and a cascade needs two `[?let]` directives in one source. `[?let` is the only
spelling that produces one: `[? let` is `expected name`, and `[?LET` parses as
a processing instruction. Both measured.

## Also ruled here

Both lints REPORT and neither exits; one gate exits afterwards. 1170-b's own
warning is that a gate which is painful to act on teaches people to ignore it,
and "fix §C2, rerun, discover §C3" is that pain.

§C4 stays ordered LAST per 1170-b, unchanged by this ruling: extracting "the
answer this prose promises" from Markdown is heuristic, and a heuristic gate
that false-reds is how a gate teaches people to ignore it.
