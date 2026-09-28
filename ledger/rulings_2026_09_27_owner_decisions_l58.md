# Owner decisions 2026-09-27 (evening) — Letter 58: a feature's gate is the feature's (GATE-1), the boot report names each seeded basis (CAPADR-1)

**Status: RULED (owner, 2026-09-27 ~21:0xZ, in session, on the letter posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 19:0xZ with SEED-1's merge; 58.1 and
58.4 were taken by the integrator under the owner's 15:2xZ delegation and folded into HOSTB-1's round).**

## The owner's word, verbatim

"l58.2a l58.3a"

## GATE-1 — the `[requires cap:…]` gate stays on `apply`, one per feature (L58.2 = (a))

A feature declares its gate once, on `apply`, carried to the host like `[effects]` (SEED-1); every verb
of the feature requires it; a feature that needs public reads beside gated writes is split into two
features, the unit KIT-1 already deploys and grants. Nothing to build. Rejected: (b) a per-verb
`requires=` on `[verb]` — a new schema word and a second place the PEP reads a basis from; (c) both
with precedence.

## CAPADR-1 — the boot report prints each seeded basis (L58.3 = (a))

The `cap:` address an author writes in a binding row is the hash of the runner's seeded value
(`runner-caps`); the host's boot report prints each seeded basis, one line
`[seeded basis=cap:… for=…]`, and xap.md §8 says so in one sentence with its case (RS-38). The
seeded value's shape stays private. Rejected: (b) specifying the value's shape so authors compute
the hash — an internal shape made a public contract; (c) leaving it to the lane's computation.
