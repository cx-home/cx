# Rulings 2026-09-06 — #789, the binding row's spelling, the `fold` kind, and the one-law nonce (WF-35 … WF-37)

**Status: RULED (a) on WF-35, (a) on WF-36, (a) on WF-37 under the standing
letter-acceptance rule.** Ids: `789-WF-35a` `789-WF-36a` `789-WF-37a`.
Branch `design/789-workflow`. Open to an owner veto.

**What raised them.** The `cx flow serve` packet stopped a THIRD time before
writing code. Each stop has been correct and each has found a real defect;
this one found that the row shape WF-29 made normative **does not parse**.

## The defect, reproduced

`cx` ends an element's attributes at the first content token, so a leading
bareword kind swallows the rest of the row as text. Measured on the shipped
binary, not read off the grammar:

```
[on webhook path="/x" start="s"]   → path='' start=''   ← attributes are NOT attributes
[on kind=webhook path="/x" …]      → kind='webhook' path='/x'
[on intent="orders/…" start="s"]   → intent='orders/…' start='s'
```

The bad row **round-trips through `cx:emit` unchanged**, so nothing is red:
it is a valid element with one text child, and every tool agrees. Three of
the five rows in §4.23's example are inert strings. §4.24 calls that shape
"ONE row shape wherever it lives … fixed ONCE so that the face which later
serves a kind adopts this row rather than inventing one" — so the defect
would have propagated to the XAP face verbatim.

**The pattern, stated once.** This is the third defect in my own spec text
found by a packet that refused to build on it (after `stream-prefix=`
contradicting PB-3, and WF-28a's missing document source). All three were
reachable by running one command against the shipped binary. The standing
rule already says a spec sentence is not evidence; the amendment this
session earns is that **an example is not evidence either — a normative
example must be parsed by the shipped parser before it is ruled normative.**

## WF-35 — how the binding row is spelled — RULED: (a)

- **(a) RULED — the kind is an ATTRIBUTE: `[on kind=<kind> …]`, an
  all-attribute row.**

  ```cx
  [on kind=schedule every=1d at="02:00" start="sha2-256:b4…" as=principal:did:key:z6Mk…]
  [on kind=webhook  path="/gh/push"     start="sha2-256:9e…" as=principal:did:key:z6Mk…]
  [on kind=file     glob=".cx/inbox/*.json" start="sha2-256:c1…" as=principal:did:key:z6Mk…]
  ```

  `validate` checks `kind=` against §4.24's closed set, THEN checks that
  kind's required attributes — so a typo answers "kind `file` requires
  `glob=`", not a shrug. **This also amends §4.9's own example**, which
  discriminated implicitly by which attribute happened to be present
  (`[on intent="orders/submitted" …]`). That parses, but implicit dispatch
  gives the worst error of all: a misspelled `glob=` yields a row with no
  recognizable kind, and every future kind must invent a discriminating
  attribute name forever.
  **What it DELETES:** the leading-bareword row shape, from §4.23, §4.24 and
  WF-28a; and implicit kind dispatch, from §4.9.
  **Strongest counter:** `kind=` is a word the vocabulary did not have.
  **Answer:** it is one attribute on a row that lives OUTSIDE the flow
  document, so the §2.3 word table and its round cap are untouched; and the
  alternative is a shape that reads as working and is not.
- **(b) trailing bareword — `[on every=1d … schedule]`.** REFUSED: it parses,
  but it preserves a shape whose only virtue was looking like the broken
  one, and a formatter that puts attributes below the head visually orphans
  it.
- **(c) the act idiom — `[on 'schedule' [every 1d] [start "…"]]`.** REFUSED:
  `start=` and `as=` are ATTRIBUTES in §4.9's already-ruled row; re-spelling
  them as children breaks that row too, for a consistency that only holds
  against `[do …]`, which is a different thing (an act, not a binding).

## WF-36 — the `fold` kind in the standalone runner — RULED: (a)

- **(a) RULED — `cx flow serve` serves FOUR kinds today, not five; a `fold`
  binding refuses `CXER4965` naming its landing, and §4.24's `fold` row for
  the runner face changes from *yes* to *named landing*.** Verified: a
  `[on kind=fold fold="NAME"]` row carries a name, but `live:observe` needs
  a quoted planar comprehension AND a `$bind` map of open source handles,
  and `live:materialize` re-attachment needs the same — there is no
  open-by-name. The `[runner]` document has `[journal]`, `[docs]`, `[env]`,
  `[ingress]`, `[courier]` and no store handle.
  **What it DELETES:** the claim, made in WF-29's table, that the runner
  serves five kinds today. It serves four.
  **Strongest counter:** shipping four of five is the partial implementation
  this campaign forbids. **Answer:** the refusal is the opposite of a
  partial — a kind that is REFUSED naming its landing is a complete,
  honest surface, which is the marking discipline WF-29 introduced and the
  module already applies to the eight round-2 words. What would be partial
  is a `fold` row that parses and silently never fires.
- **(b) add a `[fold …]` row to the `[runner]` document** carrying the store
  URL, the comprehension and the bind names. REFUSED: it puts a planar
  comprehension inside a runner document — computation inside choreography,
  which WF-31 refused for binding rows one section earlier.
- **(c) land open-by-name in `live` first.** REFUSED for this packet: it
  puts the `live` pack between a make replacement and its build, which
  WF-32 refused.

## WF-37 — which side moves so the one-law gate is reachable — RULED: (a)

- **(a) RULED — `flow_cli_nonce` becomes the content address over the
  `[args …]` record.** WF-31 makes the serve-side nonce a content address;
  `cx flow run` today uses `sha256(args_src)` over the CLI's own indented
  rendering — neither canonicalized nor tagged. Measured on one
  `[args [order "o-1"]]`: the CLI gives `e0ceba85…`, the content address
  gives `sha2-256:804082ef…`. They can never coincide, so the
  byte-identical-transitions gate is unreachable until one side moves.
  **This is a defect fix, not a surface change:** `1265-PB-2` ruled that the
  CLI derives a DETERMINISTIC nonce from the args, and says nothing about
  the derivation; `flow.v`'s own header already claims the value is the
  content address over the record. Nothing pins a CLI-derived run id — the
  umbrella test asserts only the `flow:sha2-256:` prefix, and every pinned
  id in `flow.cxd` supplies `opts.nonce` explicitly.
  **What it DELETES:** the untagged raw-text digest, and with it every
  existing `cx flow run` run id. That cost is acceptable and would not be if
  CX had external users; it does not.
- **(b) give the serve side an untagged raw-text nonce.** REFUSED: it is not
  a content address, so it contradicts WF-31's one rule immediately after
  that rule was made.
- **(c) have the gate pass an explicit nonce on both sides.** REFUSED: a
  gate that holds only when both sides are told the answer proves nothing.

## The packet's own flagged decisions — CONFIRMED, not re-ruled

`authority=` records the `as=` binder's identity (matches WF-31). `intent`
is served as a journal consumer over the runner's own journal — §4.9 offers
"a fabric subscription **or** a journal consumer", and the consumer needs no
`[fabric …]` row the document does not carry. `[docs …]` fetches by address
and hashes the fetched bytes on BOTH paths, so the mismatch refusal is
reachable either way. The ingress distinguishes its two inputs by path — a
reserved path for correlated acts, declared `path=` rows for deliveries, an
`[on …]` row claiming the reserved path refuses `CXER4965`, anything else
404. The schedule fixture uses a sub-second `every=` because there is no
clock hook into a serve process; the nonce assertion is unchanged.

**Fixture location, with one condition.** A `.cxd` case is one hermetic CX
program and cannot reach a V CLI, so `serve` cases land in
`vcx/tests/flow_umbrella_test.v`, whose header already states that division.
**The condition:** every assertion expressible as a `.cxd` case STAYS one —
the nonce rules of WF-31, the `[docs …]` hash mismatch, and the
malformed-`[runner]` refusal are module-level semantics and belong in
`flow.cxd`. Only what genuinely needs a process — the ingress, the courier,
the one-law comparison — goes to the umbrella test.

## Edit map — `spec/03-approved/std-lib/flow.md`

| Section | Edit |
|---|---|
| §4.9 | the example row takes `kind=intent`; implicit dispatch deleted |
| §4.23 | the `[runner]` example's three rows take `kind=` |
| §4.24 | the row shape is `[on kind=<kind> …]`; the `fold` row's runner column becomes *named landing*; the prose says four kinds served today |
| §8 | `CXER4965`'s row gains a `fold` binding and an `[on …]` row claiming the reserved ingress path |
| §11 | the five-kind fixture becomes four plus a `fold` refusal |
