# Owner decision 2026-10-02 ~03:4xZ — Letter 172, "recommendations accepted: in the order (b), (a), (d), then (c) standing": quality at the source — advisory retires, a property step for both rings, a spec-invariant audit, an adversarial reader on every round

**Status: RULED (owner, 2026-10-02 ~03:4xZ, in session, on the integrator's measured causes — no invariant checked at
construction, advisory cases a sanctioned red, the author grading itself, spec invariants without cases — posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 03:3xZ). SHIP-1, SHIP-2, L162 = (a), FIX-1, CXF-8, RS-38,
AGENTS.md rules 2 and 3.**

## The owner's words, verbatim

"more bugs are being opened than closed. why is the code not better quality to begin with? for example, map allows
duplicated keys. that's a massive implementation failure that gives a false sense of progress and costs more work
later." — "recommendations accepted: in the order (b), (a), (d), then (c) standing"

## QUAL-1 — the four takings and their order

(b) **ADVIS-1 — advisory retires.** Every advisory case in every corpus carries the id of an OPEN issue, and the corpus
step refuses an advisory case with no issue, a closed issue, or an issue outside the current milestone; one sweep now
turns each advisory case into green or a filed bug with the case as its fixture. (a) **PROP-1 — a property step for
the two rings:** a CX program that generates random documents and programs (seeded, deterministic) and asserts the
invariants the specs name — unique map keys, canonical round-trip, decimal exactness, err propagation out of any
constructed element, deny-by-default at every effect point of security.md §2, the two readers' agreement on a data
document — as a step on every run; a failure it finds is fixed in the round if small or filed with its fixture under
(b)'s rule. (d) **SPECINV-1 — a spec-invariant audit:** every MUST / MUST NOT of the data and code specs without a
case id gets its case (RS-38's shape), red first where it reds, fixed if small, filed otherwise. (c) **REFUTE-1,
standing from the next launch:** before READY, every round launches a second opus agent that reads the round's diff
against its spec section and writes refutation cases (fail-open, a silent scope cut, an invariant unchecked) against
the round's binary; a red refutation is fixed or filed before READY and the refutation report is a section of
RESULTS.md; the integrator sends back a READY without it. Rejected: leaving quality to the backlog's closes (the
harvest rate, not the close count, is the quality signal).
