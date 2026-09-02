# Ruling — no compiler; the representation is the work (#1176)

**Date:** 2026-09-01
**Status:** RULED — option **(a)** as updated by the Stage-0 profile, which the
issue's own recommendation had already reached. Recorded so the decision lives
in the ledger rather than in an issue comment.

## What was proposed

Compile CX to native executables via the existing V/C toolchain: Stage 1
`cx build` packaging, Stage 2 CX-AST→V lowering of the static constructs,
Stage 3 typed unboxing. The proposal named Stage 2 "likely the highest-value
stage".

## What the measurement said

Stage 0 (profile before building) was run first. Self-time by category,
`/usr/bin/sample`, four workloads chosen to separate the evaluator's shapes:

| workload | alloc+GC | eval dispatch |
|---|---|---|
| `fib(33)` — calls + arithmetic | 41.8% | 28.9% |
| `[?match]` 6-arm, 1.2M | 72.0% | 9.8% |
| element construction, 1.5M | 78.7% | 9.2% |
| `[?for]` over a 200k-row document | 77.4% | 1.9% |

Evaluator dispatch — **precisely and only what AOT lowering removes** — is
2–29% of runtime. `fib` is the most dispatch-favourable workload that exists
(naive recursion over machine ints, no collections) and it is the only one
that clears 10%.

So Stage 2 as specified buys ~1.1–1.4x, for the cost of a second
implementation of the language and a second conformance lane over ~2,712
cases.

## The ruling

**No Stage 2, and no compiler this cycle.** The entire win lives in one place:
CX heap-allocates a node per intermediate value, into a 28-variant sum type.
Removing that is #1119, and #1119 delivers the same win to the INTERPRETER,
the store, and every embedding — with no compiler, no second semantics, and no
dual gate. Option (d)'s instinct (the value is in specialization, not
lowering) is right; the vehicle is the representation, not a compiler.

**Stage 1 (`cx build` packaging) stands on its own merits and is untouched by
this.** It was always a DEPLOYMENT feature, not a performance one — it buys
single-file deploy, not startup, since the floor is already ~10 ms. Its two
real questions are baked capability sets and static linking (#1102). Not
scheduled here; not blocked by this either.

**Reopen trigger for Stage 2, stated so it is not a matter of memory:** if
#1119 lands a compact or unboxed value representation, RE-RUN this profile.
Taking allocation out of the denominator is exactly what would make dispatch
the dominant term, and AOT lowering becomes worth re-costing at that point —
not before.

## Two structural facts the compiler must not re-derive

Recorded because the issue found them and a later implementer would otherwise
rebuild an analysis CX already performs:

1. **`eval` is a capability.** A program not granted it cannot run
   dynamically-constructed code, so it is statically closed BY CONSTRUCTION —
   checkable from the grant set at build time, not by whole-program analysis.
2. **Call heads are static names** (RULED: FE-5(a)) — `ProgramCall.name` is a
   string, `[$ops.key 1 2]` refuses. The callee at every call site is
   statically nameable.

The hybrid escape hatch is therefore not a mechanism to design; it is two
existing rulings to honour.

## Note on the measurement's integrity

The first W2 figure taken (50 s for a `[?for]` over 200k rows) was 96% #1178 —
a quadratic in the data parser, found while setting the profile up. The table
above uses a clean corpus throughout, and three of its four workloads parse no
document at all, so the conclusion does not rest on that number. #1178 is now
fixed (`c30dce9e4`): 200k rows went 47.8 s → 0.68 s, and CX reads its own
format at ~18 MB/s against the JSON reader's 21 MB/s.

That fix does not change this ruling. It removes a contaminant from every
future perf measurement over a CX corpus, which is a precondition for trusting
the #1119 work when it happens.
