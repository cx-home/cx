# Ruling — keys get a single-registrant REPORT now; the vocabulary artifact is deferred (#1190)

**Date:** 2026-09-01
**Ruled by:** owner, letter **(a)**
**Status:** RULED, recorded BEFORE the work.

## The defect

Keys are "the shared rulers owned by no feature". W2 checks one property —
that every registration onto a name agrees in value TYPE — and nothing else.
There is no way to state that a key name exists, what a value in it means, or
which invariant a registrant accepts by registering.

So a mistyped key name is indistinguishable from a new ruler. Two features
whose key names differ by one character (`order-id` vs `order_id`) compose
with `ok=true` and produce two rulers with one registrant each. The join the
author intended does not exist, and nothing says so. The failure surfaces at
runtime as an empty readout — which is precisely the class the W1–W6 gate
exists to eliminate ("never gets in half-way").

## The ruling

**(a) Ship the report — item 4 of the filed scope — now. Items 1-3 (a
declarable, publishable key-vocabulary artifact; an opt-in compose-time check
against it; a `[key … from=pkg:…]` citation) become a separate design issue.**

`compose-report` already returns the key set. A key with exactly ONE
registration is either a typo or a private field wearing a global name, and
neither is a thing a composition should carry silently. Flagging it costs
almost nothing and catches the filed isolation exactly.

**Refused as this release's answer: (b) items 1-3 whole.** They are the
correct end state and are not rejected on merit. They are deferred because
they invent the interop artifact BEFORE there is a second party negotiating
over it: a new package kind, a new gate, and a published vocabulary format
would all be frozen on speculation about how publishers will want to declare
meaning. That is the expensive thing to walk back, and #1190's own framing —
"whoever publishes a key vocabulary owns interop" — is the reason to get the
format right with real publishers in view rather than first.

**Refused: (c) nothing this release.** The reported failure is silent, late,
and cheap to catch.

## Why (a) is long-term best

The report is not a lesser version of the vocabulary — it is the part that is
decidable WITHOUT one. A single-registrant key is anomalous on the evidence
the composer already holds, so the check needs no new artifact, no opt-in
policy, and no agreement between publishers. Items 1-3 need all three, and
they answer a different question (what a key MEANS) that no amount of
counting can reach.

Stating that plainly also keeps the deferral honest: the report catches the
TYPO class and says nothing about the `order-id`-means-two-things class,
which #1190 §2 names and which only a vocabulary can address.

## Execution constraints

1. The report is a **report**, not a gate: `ok` does not become false because
   a key has one registrant. A private-field-wearing-a-global-name is a
   legitimate, if unwise, choice, and there is no declared vocabulary to
   judge it against yet.
2. It must name the key AND its single registrant, so the reader can tell a
   typo from a deliberate private ruler without re-deriving the composition.
3. Fixtured both ways: two features meeting at one key report nothing; the
   one-character-apart pair reports both keys.
4. The deferred items get their own issue (#1199, filed 2026-09-02), cross-referenced here, so the
   scope is parked rather than lost.
