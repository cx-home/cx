# Ruling record — #1280: not a semantics question. Two bare spellings, both with a canonical `$` form that already works (2026-09-05)

Issue: #1280 (bug, area:cx-lang, prio:medium). Spec: `core/code.md` §6.3 (the canonical
call form), §6.3b (callable values), §6.5, §12.2.3 (bare-name references), §9.2 (CXER0291).
Engine: `vcx/cx/codec.v` (the ONE CXER0291 advice string).

## Correcting this record

**An earlier version of this file recorded two open owner letters. Both were false
dilemmas and are withdrawn.** They were built by reasoning from the issue's framing and
from engine spot-checks, without asking the one question that settles it: *does the
canonical `$` spelling already do what the reporter wanted?* It does. The withdrawn
letters, and the two "counterexamples" I built them on, are recorded below because the
mistake is more instructive than the ruling.

## What is actually happening

The report's program has TWO non-canonical spellings, and each one does something the
author did not intend:

```cx
[?def t3 ($n $f $d) …]
[?def cmd impure [effects] ($a='') …]
[t3 1 cmd [do 'x' [a 1]]]        ; → CXER0291
```

1. **`t3` in head position.** A bareword head CONSTRUCTS a data element (§6.5: "a
   word-named built-in is reachable ONLY via `[$name …]`; the bare form `[name …]` is
   data-element construction … even when `name` matches a built-in"; §12.2.3 repeats it
   for head position). `[$t3 …]` is the canonical call (§6.3: "The canonical CX call form
   is the head-dispatch element `[$fn args…]`").
2. **`cmd` in value position.** A bare def name is a REFERENCE to the callable
   (§6.3b's callable-value table: "the definition's name in value position, bare
   (`double`) or sigilled (`$double`)"), so the callable is adopted as a data child and
   has no data image when the document reaches the output (§9.2).

**Measured on the landed binary:**

| program | answer |
|---|---|
| `[t3 1 cmd [do 'x' [a 1]]]` — what the report wrote | CXER0291 |
| `[$t3 1 $cmd [do 'x' [a 1]]]` — the canonical form | **`[seen n=1 [do 'x' [a 1]]]`** ✅ |

The intended call already worked. There was nothing to rule.

## 1280-Q3 — RULED: the DIAGNOSTIC names the sigil

`CXER0291`'s advice said only "APPLY it and return its RESULT", which is why the report
concluded that construction had serialized a sibling argument. It now names both bare
spellings and their `$` forms, which is what §12.2.3 already prefers ("`$name` is the form
to prefer in new code, since it reads the same in every position"):

> …Two bare spellings adopt a callable by accident: a bare def NAME in value position is a
> reference to it (§6.3b) — write `'name'` for the data word — and a bareword HEAD
> constructs a data element rather than calling (§6.5), so `[f a b]` builds `[f …]` while
> `[$f a b]` calls `f`. Prefer the `$` form in both positions (§12.2.3).

**DELETES: nothing.** Same code, same class, same semantics — the teaching half only, in
the same spirit as #1142 rider 5, which authored the first sentence.

## The two withdrawn letters, and why each was wrong

Recorded because both errors are the same error, and it is worth being able to recognize
it next time.

### Withdrawn Q1 — "a def-named head is a call whatever its arguments' kinds"

I ruled (a), implemented it, and `stdlib/diagram.cx` broke: `code-rules` is a def whose
body constructs a data element of its own name, so the inner `[code-rules …]` became a
recursive call (nine tests red, `cx code-diagram` degenerate). I recorded that as proof
that the construction gate was load-bearing and escalated.

**It proves no such thing.** `[$code-rules]` works — measured. The self-named constructor
is fine under any reading; what broke was one *spelling* inside diagram.cx, and diagram.cx
is written in the spelling §12.2.3 deprecates. The gate is not protecting a capability; it
is implementing §6.5, which already says a bareword head constructs.

### Withdrawn Q2 — "a bare word in an element body is the data word"

I ruled (a), implemented it, `run-008-closures-in-data-registry-dispatch` broke, and I
recorded `run.md` §4.1's closures-in-data registry as a capability that reading would
delete.

**That was false, and one test would have shown it.** The same fixture program with
`$greet-tool` / `$shout-tool` instead of the bare names answers
`[reg [a 'hi dana'] [b 'HI dana'] [miss]]` — byte-identical to the fixture's own
`out-text`. The registry pattern depends on a callable being ADOPTABLE INTO DATA, which is
unaffected by how the callable is spelled. I mistook "the fixture uses this spelling" for
"the pattern requires this spelling".

### The test that collapses both

**Write it with `$`. If it works, the bare form was a spelling, not a capability.**

Both times it works. A fixture failing when a spelling is removed says the fixture uses
that spelling — nothing more — until the canonical spelling is tried.

## What genuinely remains, and it is NOT this issue

- **#1311** — a bare word in a data body also resolves against a **binding**
  (`[?let [= $x 5] [wrapper x]]` → `[wrapper 5]`). Unlike the def case, this is specified
  NOWHERE: §6.3b covers bare *def* references only, and a grep of `code.md` finds no bare
  binding reference. That is a spec gap, and its letters live on that issue.
- **A cleanup, not blocking:** §12.2.3 prefers `$name` and §6.3b still admits the bare
  form. Retiring the two bare spellings is a real corpus cutover, worth its own campaign,
  and nothing depends on it.

## Exit (what landed)

`conformance/code.cxd` `cmd-030` and `cmd-031` pin today's answers — the construction /
call contrast at the head, the bare def reference in a body, the attribute reading of the
same word, and the `$` forms that do what the reporter wanted. `run-008` and
`stdlib/diagram.cx` untouched.
