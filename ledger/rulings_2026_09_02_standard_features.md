# Rulings 2026-09-02 — the standard feature set (SF)

**Status: SF-1 RULED BY OWNER 2026-09-02 (the home, with a name change).
SF-2..SF-5 recorded under the standing letter-acceptance rule, re-verified
against the long-term-best bar; SF-6 is OPEN and owner-gated.** Rulings
recorded before work per the #832 process rule. Issue **#1189** (campaign
member of the closed adoption campaign #1188, letter **AD-9**) stays in
cx-private and remains the contract; the feature content is built in a new
repository.

**Origin.** AD-9 was filed 2026-09-01 and left PROPOSED when the adoption
campaign closed: CX ships a MODULE library and the MECHANISM for distributing
feature packages, but no FEATURE library, and — the half of the deliverable
that is easy to overlook — no register of what must NOT be a feature. The
owner directed the home on 2026-09-02.

---

## SF-1 — the home: a new private repo, `cx-standard-features` (#1189)

**RULED: (b), by owner, 2026-09-02** — "cx needs a cx-standard-features repo,
private for now, so that a set of standard features can be built […] keep the
issue in cx-private for now but build out the features in the new repo."

This **overrides the AD-9 recommendation of (a)** (`features/` inside
cx-private). AD-9's case for (a) was reversibility, priced against a second CI
surface and a pin relationship. The owner's ruling takes the boundary now.

- Repo: **`cx-home/cx-standard-features`**, **private**. Created 2026-09-02.
- Name: `cx-standard-features`, not AD-9's `cx-features` — the set is *the
  standard set*, and the register in it is a statement about what is standard.
- The issue stays in cx-private. cx-private remains the contract and the
  ruling store; the new repo carries content and its own gates.
- (c) — the public mirror `cx-home/cx` — stays REFUSED on its face: the
  mirror is publish-allowlist OUTPUT, never a source of truth.

**Cost accepted, and mitigated.** #1077's discipline says price the structure.
The second CI surface is real. The pin-conflict cost AD-9 cited
(submodule pins racing across concurrent PRs) does **not** apply: the new repo
takes **no submodule** on cx-private. It vendors the four `xap_schemas/*.cxs`
files and carries `make schemas-sync` / a drift check that SKIPS when no
cx-private checkout is reachable, so a lone clone still gates green.

## SF-2 — the #866 boundary line

**RULED: (a)** — the AD-9 proposal, adopted verbatim and committed as
`REGISTER.md` in the new repo:

> CX ships features that are **pure platform semantics**, and never features
> that carry **domain vocabulary**, which stay third-party.

Admissible here means all three hold: it has nouns, verbs, rules and
governance of its own; it is pure CX semantics with no business-domain
content; and every deployment needs roughly the same one. An archetype
catalog — anything whose nouns name a *business* rather than a *deployment* —
remains third-party, so the standing #866 ruling (CX ships the mechanism;
third parties ship catalogs) is untouched.

**Long-term-best check.** The line is *checkable*, which is why it holds:
"does a noun of this feature name a business?" is answerable by reading the
feature spec, and the register's own left-hand column is the worked evidence
that the line falls where it is drawn.

## SF-3 — where the register lives

**RULED: (a-modified)** — the register is committed as **`REGISTER.md` in
cx-standard-features**, which is where the question "should this be a
feature?" is actually asked, and it lives in exactly ONE place.

AD-9 proposed committing it as normative text in
`xap_feature_distribution_market.md` beside §9's deliberate absences. That is
still the right *normative* home for a one-line pointer, but restating the
table in two places is a drift source of exactly the kind this set's own gate
refuses. **SF-6 (below) is the owner-gated letter for the spec pointer.**

## SF-4 — membership, and the three `market/` features

**RULED: (a-modified).** Priority order stands: **`admin`** first (every
deployment writes that surface today), then `identity`, `retention`, `ops`,
`notify`.

**AD-9's "`catalog`/`entitlement`/`commerce` re-home as the first members" is
REFUSED on measured evidence.** They are not merely "authored to make the
market a XAP" — they are the distribution spec's §5 worked case and they are
**load-bearing for the toolchain's own conformance suite**:

- `conformance/stdlib/xap-dist.cxd` cases 039–044 read
  `market/catalog.feature.cxd`, `market/entitlement.feature.cxd` and
  `market/commerce.feature.cxd` **by path from the repo root** (lines
  975–977, 995–997, 1020–1022).
- `conformance/gates.cxd` records those cases as the ENFORCED evidence that
  the market composes through the ONE W-gate, that `commerce/fulfil` is a
  derived verb, and that N-COMPOSE-2 denies the settlement gateway.
- `scripts/publish.sh` (the public-mirror allowlist) carries `market/` for the
  same reason.

Moving them deletes the toolchain's own proof. They **stay in cx-private
`market/`**; the new repo does not restate them, and its README says so and
says why. A deployment that wants them consumes them from the cx-private
registry — which is exactly what hash-pinned distribution is for, and is the
proof that the location was never the consumer's concern.

**Long-term-best check.** This is a correction to AD-9, not a narrowing of it:
AD-9's own argument was that the set should not be assembled out of things
authored for another purpose. The three market features were authored for
another purpose *and are still doing that job*.

## SF-5 — how a catalog identifies the set

**RULED: (b'), a strengthening.** AD-9 asked for "a `kind=` or manifest
convention marking a package as first-party standard". Both halves of that are
refused, and the answer is data that already exists:

**The set is exactly what the standard-features publisher DID signs.**

```
did:key:z6Mkqm4EhpubREEM2rZNMST3S8FQqWGbZ6222C9qyw72eAGW
```

- **Not `kind=`.** §1.1 is explicit that `kind` determines which *install
  gate* runs (feature / library / client). Overloading it would make the
  gate selector carry provenance, which is a different axis entirely.
- **Not a new manifest field.** A `[standard]` element or `tier=` attribute is
  **self-asserted by the publisher** — it would say strictly less than the
  signature the consumer already verifies, while adding schema surface.
- **A publisher DID cannot be forged**, is verified on every install as
  trust-chain stage 2, and is already in every manifest. A catalog ranks the
  set by filtering `//publisher/@did` — ordinary CXPath over data that is
  already there. Zero new surface.

This is why the new repo mints its **own** publisher identity rather than
reusing cx-private's `cx-home internal` key: a consumer can then pin an
attestation policy on the standard set without also trusting every internal
cx-private package.

## SF-6 — OPEN, owner-gated: the spec pointer

**PROPOSED — needs owner authorization (G3; spec edits are ruling-gated and
`spec/03-approved/` graduation is owner-only).**

Add to `spec/03-approved/xap/xap_feature_distribution_market.md` §9 (*what
this spec deliberately does not introduce*) a tenth entry pointing at the
register and the boundary line, so the spec states the absence and names where
the register is kept:

> 10. **No first-party feature library in this repository** — the standard
>     feature set is published from `cx-standard-features` under its own
>     publisher DID (SF-1/SF-5), and the register of concerns that are
>     platform and therefore must NOT be features is that repo's
>     `REGISTER.md` (SF-3). The three `market/` features are §5's worked
>     case, not members of that set (SF-4).

Recorded as PROPOSED, not applied. No `spec/` file is touched by this packet.

---

## Refusals register — do not re-propose without the named trigger

- **Re-homing `market/catalog` / `entitlement` / `commerce` into the standard
  set** (SF-4). Trigger: conformance cases 039–044 no longer reading them by
  path — i.e. the §5 worked case has another home first. Never as a tidy-up.
- **`kind=standard` (or any new `kind`)** (SF-5). Trigger: none. `kind`
  selects the install gate; a fourth value would need a fourth gate.
- **A self-asserted first-party marker in `package.cxs`** (SF-5). Trigger: a
  catalog requirement that a signature genuinely cannot serve — named, not
  anticipated.
- **A submodule pin between cx-standard-features and cx-private** (SF-1).
  Trigger: the vendored schemas proving insufficient in practice, measured on
  a real drift incident.
