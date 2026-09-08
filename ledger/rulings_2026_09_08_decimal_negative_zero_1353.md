# RULED: 1353-b, 1353-c, 1353-d — a decimal negative zero KEEPS its sign in
# the canonical image; `idh-022` is re-cast, and `canonical.md` §2.5 gains the
# decimal row it never had.

Date: 2026-09-08. Issue: cx-home/cx-private#1353. Campaign: v0.18.0 close-out
(#1354), HIGH tier (canonical surface + a `level=core` fixture re-cast).
Letters drafted by campaign worker A and posted on the issue as
`## PROPOSED RULING (worker A)`; **ruled by the owner + Fable at 2026-09-08
18:50 ET** in the issue comment headed `## RULED: 1353-b, 1353-c, 1353-d`.

This issue was landed once at `6c6e44edc` (+ `d4290547b`) and **reverted** at
`ea32f2303`, because the landing reversed a `level=core` fixture without a
ruling and the gate went red on exactly that case. The ruling is what unblocks
the re-land, and the fixture moves in the same change this time.

---

## Verbatim substance of the RULED comment

> **1353-b = 1(b):** the decimal row follows the float row. A decimal negative
> zero keeps its sign in the canonical image (`-0.0`, `-0.00`, `-0.000` —
> scale kept as today), is DISTINCT by content address, and EQUAL by value
> (`[= -0.0 0.0]` stays true). `canonical.md` §2.5 gains the decimal row
> beside the float row. `idh-022-negative-zero-decimal-normalizes` is RE-CAST
> under this ruling: `out-hash-eq` becomes **false**, its id and `[; …]` note
> are rewritten to say the sign of a decimal zero is address-significant and
> that this supersedes I1's 2b autotype reading; `idh-023` (scale significant)
> is unchanged and now consistent with it. Why: the decimal kind kept trailing
> zeros (presentation) while silently discarding a sign (information) — a byte
> the author wrote and `cx canonical` could not give back; (c) would let two
> canonical images share one address, breaking the invariant `idh-023`'s note
> relies on.
>
> **1353-c = 2(a):** re-apply `6c6e44edc` (the `normalize_decimal_token` fix)
> TOGETHER with the fixture re-cast, the spec row, and the header fix in ONE
> change carrying `RULED: 1353-b, 1353-c, 1353-d` — the only ordering under
> which the gate cannot go red on `idh-022` again.
>
> **1353-d = 3(a):** `identity_hash.cxd:32`'s header comment is corrected in
> the same change.
>
> Fixture-first (the re-cast is red at HEAD by construction);
> `spec-freeze-gate` + `docs-check` in the lane. HIGH tier. Ordering note
> stands: #1347's refusal set over number images must admit `-0.0` — whoever
> takes #1347 reads this first.

---

## What the ruling REFUSED

**Option 1(a) — keep I1's normalization** (`-0.0` → `+0.0`, scale kept,
`idh-022` unchanged, no code change; the issue closes on a spec row that says
the normalization is deliberate). Refused because it deletes **the
representability of a signed decimal zero at all**: a producer writing `-0.0`
to mean "a negative quantity that rounded to zero" — a measurement delta, a
rounded-down accounting movement, a re-emitted source document — cannot round-
trip it through `cx canonical`, and the byte is rewritten with no diagnostic.
It also leaves §2.5 unable to explain why **scale** (presentation) survives
canonicalization while a **sign** (information) does not; the letters recorded
that no such explanation could be constructed from anything written down.

The honest cost of refusing (a), recorded here so it is not rediscovered as a
surprise: two documents differing only by a decimal `-0.0`/`0.0` no longer
share a content address, so stored-document dedup forks on that byte.

**Option 1(c) — preserve the sign in the image but normalize it for the
address** (`idh-022` stays true and `cx canonical` stops being lossy).
Refused: it deletes the invariant `address = f(canonical bytes)`, which is the
sentence `idh-023`'s own note relies on to justify scale-significance. Two
distinct canonical images would share one address, in a file whose every other
case derives distinctness *from* the bytes.

**Option 2(b) — re-apply the code first, re-cast the fixture in a follow-up.**
Refused: `d4290547b` already proved what that does — the fix and the fixture
that contradicts it must move in one change or `conform-all` reds on
`idh-022`.

**Option 3(c) — leave the `identity_hash.cxd:32` header contradiction.**
Refused: a corpus header that contradicts its own case eleven lines down is
how the next reader reaches the wrong conclusion about a `level=core` pin,
which is close to what happened at `6c6e44edc`.

---

## The pinned values of `idh-022` — OLD and NEW

`conformance/identity_hash.cxd`, case at `:182`, `level=core`.

| | OLD (I1, pre-2026-09-08) | NEW (this ruling) |
|---|---|---|
| case id | `idh-022-negative-zero-decimal-normalizes` | `idh-022-negative-zero-decimal-significant` |
| `tags` | `identity-hash tier1 pair decimal i1` | `identity-hash tier1 pair decimal sign i1 1353` |
| `in-a` | `[reading delta=0.0]` | unchanged |
| `in-b` | `[reading delta=-0.0]` | unchanged |
| **`out-hash-eq`** | **`true`** | **`false`** |

The old pin's basis, measured on the pre-fix binary
(`/Users/ep/git-repos/cx/cx-private/vcx/target/cx`, release/0.18 @
`aa160b22c`) — both inputs share one address because `cx canonical` drops the
decimal sign:

```
$ cx hash in-a   sha2-256:b54f44fa9571ee3a5c244ccb8597d0462762aa148e4c052ca8a94c273330926a
$ cx hash in-b   sha2-256:b54f44fa9571ee3a5c244ccb8597d0462762aa148e4c052ca8a94c273330926a

$ cx canonical  [a d=-0.0 e=-0.00 f=-0.0e0 g=-1.5 h=0.0 i=-0.000]
                [a d=0.0  e=0.00  f=-0.0e0 g=-1.5 h=0.0 i=0.000]
```

`d`, `e` and `i` lose the sign; `f` — the same quantity spelled as a FLOAT —
keeps it. Under the ruling every sign above survives and the two `idh-022`
addresses diverge, which is what `out-hash-eq false` now pins.

The `idh-022` **id** moved because the id carried the position. Nothing
references the old suffix: the only other mentions of `idh-022` in the tree
(`docs-src/positioning/ring_value_map.md:59`, `campaign/v0.18/HANDOFF.md:74`,
`campaign/v0.18/worker-C.prompt.md:34`) use the bare `idh-022` prefix and stay
correct.

## Equality — the axis that does NOT move, measured both sides

Measured on the pre-fix binary, before any edit:

```
[= -0.0   0.0  ]  → true
[= -0.0e0 0.0e0]  → true
[< -0.0   0.1  ]  → true
[+ -0.0   1.5  ]  → 1.5
```

Decimals compare **mathematically** (`numeric_exact.v`), not by image, so this
ruling moves the image and the address only. Equal by value, distinct by
address — exactly the float row's existing bargain. Had decimal equality been
image-based this would have changed which values compare equal, a far larger
landing than a canonical form; that is why it was measured first rather than
patched.

---

## What landed under this record

| file | change |
|---|---|
| `vcx/cx/parser.v` | `normalize_decimal_token`: `if neg && !all_zero` → `if neg`. `decimal_token_is_canonical`: the `neg && all_zero` guard and its now-dead `neg`/`all_zero` locals removed, so `-0.0` rides the already-canonical fast path instead of the slow path that dropped its sign. The two stale doc-comment clauses above the predicate ("negative zero normalizes positive", "no `-` on a zero value") corrected — they were the comments that named the defect while the code walked into it. |
| `conformance/identity_hash.cxd` | `idh-022` re-cast per the table above (1353-b); the `:32` header comment corrected and expanded to say the sign is address-significant in BOTH kinds and that equality is a separate axis (1353-d). |
| `conformance/extended.cxd` | NEW `058-decimal-negative-zero-canonical-image` — `in-cx` = `out-canonical` = `[reading d=-0.0 e=-0.00 f=-0.000 g=-0.0e0 h=0.0 i=-1.5]`, pinning the image the address derives from at three scales beside the float and the positive zero, and doubling as the §11.4 idempotence pin for the shape. |
| `spec/03-approved/core/canonical.md` | §2.5 gains the `Negative zero (decimal)` row beside the float row (1353-b). This row did not exist in any form before: `:215` was explicitly float, `type-mapping.md:169` and `cxdm.md:521` are both float, and §2.5's decimal row said "bare, scale preserved" and nothing about sign. Whichever way this was ruled, a missing normative sentence had to be written. |
| `vcx/tests/canonical_umbrella_test.v` | `test_decimal_negative_zero_normalizes_scale_kept` → `test_decimal_negative_zero_keeps_sign_scale_kept` (now `-0.0`/`-0.00`/`-0.000` + the address forks); `test_negative_zero_distinct` re-cast; the L45 §6 header's "no negative zero" corrected. |
| `vcx/tests/cxparse_forks_umbrella_test.v` | `'[k -0.0]'` moves from `must_not_be_canonical` to `must_be_canonical` (with `-0.00`); the child-scan predicate declined it *because* the renderer moved it, which is the same defect on the fast-path side. `'[k -0]'` stays — the INT kind is untouched by this ruling. |

## Ordering note carried forward (from the ruling)

**#1347 must be worked after this record.** #1347 makes `cx fmt`'s fingerprint
hash the canonical image, at which point `cx fmt` stops declining `-0.0` and
starts rewriting it — with this defect present that would turn a fail-closed
decline into a silent value change in author files. The set of canonical
decimal images now gains `-0.0` (and `-0.00`, `-0.000`), so #1347's refusal
set over number images must admit them. The dependency is one direction only.
