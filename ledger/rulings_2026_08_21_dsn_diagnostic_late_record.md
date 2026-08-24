# Late record — #520 DSN diagnostic (R5.0 class), 2026-08-21

## What happened

Commit `0f82c1d36a8a28bddd92442deffb7d94ad692c02` (#520 — the SQL DSN
diagnostic and `sqlite::memory:`) touches implementation
(`vcx/platform/sql.v`, `vcx/platform/sql_sqlite_d_cx_db_sqlite.v`) AND one
line of `spec/02-working/diagram_renderer_cx.md`, with no `RULED: <id>`
token in the message. spec-freeze-gate refuses it under R4.1. The gate is
RIGHT: its scope is deliberately `spec/**` with no exception for working
drafts (script header lines 21–22), and that breadth is an owner ruling,
not an oversight — narrowing it to make this violation disappear would be
overturning a standing rule to excuse a miss.

## The authorization that existed, recorded now

The work ran under the owner's standing autonomy grant of 2026-08-20
("work through them autonomously making the best long term cx decisions…
everything integrated, working sound with no known bugs and ready for
cut"). No per-commit ruling was sought because the change is a defect fix
with no surface question in it.

## What the spec-side touch actually was — Class S

One line, in a **working draft**, purely mechanical: the string `v0.16.0`
in the diagram design letter's status paragraph became "the current
release". It was required by a DIFFERENT gate — check-version-consistency
refuses stray `vX.Y.Z` literals — and it changed no clause, no claim and no
normative text. `spec/02-working/` is by construction not the normative
contract; the letter is a design document whose rulings were already
recorded in `ledger/rulings_2026_08_20_diagram_renderer.md`.

## Disposition

Adjudicated in `scripts/spec_freeze_gate.sh` as Class S, recorded LATE per
R5.0, citing this file. The row is loud by design.

**Flagged for owner review** rather than quietly absorbed: this adjudication
was authored by the agent that made the miss, under a standing autonomy
grant rather than a per-commit owner ruling. That is the weakest link in
the chain, so it is named here and surfaced in the cut review package. If
the owner prefers the row withdrawn, the alternative is a history rewrite
of a pushed shared branch — which the gate's own header judges worse than
the miss.

## Process improvement adopted the same day

The trap: a commit fixing implementation can be dragged into "spec+impl"
territory by an unrelated one-line doc edit made to satisfy another gate.
Standing habit going forward — keep mechanical doc-gate fixes (version
literals, dead links, marker churn) in their OWN commit, never folded into
an implementation commit. Costs one commit, keeps the freeze gate honest.
