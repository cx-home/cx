# Ruling — the bare-builtin-head lint asks the ENGINE, and needs no new surface (#1170 §C2)

**Ruling id:** 1170-b
**Date:** 2026-09-08
**Ruled by:** campaign worker C, long-term-best standard (owner rule 7 of #1354).
**Status:** RULED, recorded BEFORE the work. Detection is measured; the
implementation is mechanical and follows.
**Follows:** `ledger/rulings_2026_09_08_playground_output_pin_1170.md` (1170-a).
It CORRECTS that ruling's scope note, which assumed §C2 needed a CX-visible
spelling for the engine's classification table and was therefore coupled to
#1351. It is not, and it is not coupled.

## The class to catch

Post R-A1 (2026-08-25) a bare `[name …]` head is DATA CONSTRUCTION; the
builtin is reached through the `$`-head call form. Fourteen playground
examples still used the retired spelling, echoed their own arguments, and
exited 0 under notes promising the computed answer. §C1's pin makes that
visible in review. §C2 is the mechanical detector, so the class cannot come
back one example at a time.

## The question

How does the lint learn which bare heads name builtins?

- **(a)** Expose the engine's `builtin_dispatchable` table
  (`vcx/code/eval.v:7077`) through a CX-visible spelling and consult it.
- **(b)** Keep a checked-in name list in the generator, with a parity gate
  holding it against the V table.
- **(c)** Ask the engine by RUNNING it — no list anywhere.

## The ruling — (c)

**Deletes:** (a)'s new surface and its false coupling to #1351; (b)'s second
registry and the gate that would exist only to keep the copy honest. It also
deletes the generator's existing `BUILTIN-NAMES` constant
(`gen_examples.cx:171`) as an authority — that list is a 30-name copy used for
TAG inference and it is already wrong (it carries `modulo` and `rem`, which
are not callable, and misses every name added since it was written). A lint
must not be built on it.

**The discriminator, measured on the shipped binary:**

```
$ printf '[$pizza]\n'  | cx …   →  [err code=cx-err:CXER0136 message='E_NO_CALLABLE: no callable "pizza"']
$ printf '[$concat]\n' | cx …   →  [err code=cx-err:CXER0100 message='concat: expected at least 1 argument(s), got 0 (code.md §6.5)']
```

**Corrected 2026-09-09 (RULED: 1058-T1.6-b).** As ruled on 09-08 this block
read `user-undefined` for the miss; `1058-T1.6-b` then gave the miss a real code
and REMOVED that string. The DECISION is unchanged — the miss code ⇔ the name is
not a builtin — only its spelling, and the correction is recorded here rather
than left for a reader to discover from a red gate.

The miss code (`cx-err:CXER0136`) ⇔ the name is not a builtin. Any other verdict
— including an ARITY error (`CXER0100`) — means it is. One grant-free child
process per distinct head, and the engine is the authority, so the answer cannot
drift from the engine the way a copied list does.

**Read the miss POSITIVELY, never as an absence.** The original predicate was
`not contains(output, 'user-undefined')`, and when T1.6-b removed that string the
lint went vacuously TRUE for every name — including names that cannot exist —
so all 148 heads read as builtins and `verify-playground-examples` printed 52
false BAREs (gate red at `c281b4130`). Measured both directions on the shipped
binary, with the real def and its real helpers:

```
new needle 'cx-err:CXER0136'  missing-name=false concat=true pair=false and=true  discriminates=true
old needle 'user-undefined'   missing-name=true  concat=true pair=true  and=true  discriminates=false
```

`pair` is one of the 52 that were falsely flagged; `and` is one of the five
LEGITIMATE bare operators this rule must keep detecting. The call site now
asserts that discrimination before reading any verdict from the probe, so the
next spelling change fails loudly instead of silently.

Run over every distinct bare head in the corpus (148 of them), 17 resolve:

```
abs  concat  contains  distinct  name  normalize-space  nth  odd  position
reverse  string-length  substring          ← the A1 class, all fourteen
and  or  not  cast  log                    ← legitimate, three different reasons
```

**Rule 1 alone over-reports, and each of the last five over-reports
differently**, which is why the second condition below is not optional:

| name | why a bare head is legitimate | measured |
|---|---|---|
| `and`, `or`, `not` | bare-spelled OPERATORS — dispatch happens | `[and]` → `CXER0100 [and] wrong arity`, never an echo |
| `cast` | dispatched bare WITH arguments, arity-gated | `[cast 3.7 :int]` → `CXER0290`; `[cast]` → echoes `[cast]` |
| `log` | a DATA element named after a math builtin (examples 120, 123) | `[log 10]` → `[log 10]`; `[$log 10]` → `2.302585092994046e0` |

A zero-argument probe (`[NAME]` echoes ⇒ bare dispatch is off) separates
`and`/`or`/`not` correctly and MISCLASSIFIES `cast`, because `cast`'s bare
dispatch is arity-gated. So the zero-arg probe is refused as the second
condition.

**The second condition is the pinned answer.** The R-A1 symptom is not "a
builtin name appears bare" — it is "the construct CAME TO REST as data". §C1
already records every answer, so:

> Flag an entry when a bare head `H` appears in its `[src]`, AND `[$H]`
> answers something other than the miss code (`cx-err:CXER0136`; `user-undefined`
> as ruled on 09-08), AND the entry's recorded
> answer contains a construct headed `H`.

Checked against the corpus: `20-string-concat` flags (answer holds
`[concat 'hello', …]`); `25-logical` is clean (`[and …]` computes to
`true`/`false`, no `[and ` in the answer); `35-cast-float-int` is clean (the
answer is the `CXER0290` refusal, no `[cast ` in it). Only a genuine data
element named after a builtin survives as a false positive — `log`, in two
entries.

**The exception is a per-entry marker, not a name list:**
`[bare-builtin-ok [# reason #]]` on the `[ex]`, joining `[wasm-unsupported]`
and `[no-stable-value]` as the corpus's third exception marker. Per-entry and
not per-name, because "this `[log …]` is data, not the math builtin" is a fact
about THIS example, and stating it out loud in a teaching corpus is a feature
rather than a cost. Graded in BOTH directions like the wasm marker: a marker
on an entry that does not trip the rule is a FAILURE too, so the lint cannot
be defeated by marking the corpus wholesale.

## Also ruled here

**§C3** (flag a `[?let]` cascade in `src`, with an allow-list for the
deliberate nesting examples) and **§C4** (a note quoting a literal answer that
the pin contradicts) need no new surface either and are the worker's to rule
when they are built. §C4 is deliberately ordered LAST of the four: extracting
"the answer this prose promises" from Markdown is heuristic, and a heuristic
gate that false-reds is how a gate teaches people to ignore it — the same
hazard `[no-stable-value]` exists to avoid. It is built only after §C2 has
removed the mechanically detectable half.
