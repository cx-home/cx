# Rulings 2026-09-02 — the standard feature set (SF)

**Status: SF-1 and SF-6 RULED BY OWNER 2026-09-02 (the home, with a name
change; and the spec pointer). SF-2..SF-5 recorded under the standing
letter-acceptance rule, re-verified against the long-term-best bar. SF-7 (the
scope of `retention`) RULED BY OWNER 2026-09-03. ALL SEVEN RULED.**
Rulings recorded before work per the #832 process rule. Issue **#1189** (campaign
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
refuses. **SF-6 (below) rules that pointer, and it is now applied.**

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

## SF-6 — the spec pointer

**RULED: (a), by owner, 2026-09-02 ("1a").** Applied to
`spec/03-approved/xap/xap_feature_distribution_market.md` §9 (*what this spec
deliberately does not introduce*) as a tenth entry: this spec ships the
MECHANISM; the standard feature set is authored and published elsewhere under
its own publisher DID with no privileged status, and the register of concerns
that are platform and therefore must NOT be features lives with that set —
beside §9's list and for the same reason.

**The entry is made CHECKABLE, because §9's own preamble requires it.** §9
opens "Each a checkable absence", and an organizational statement that no
gate asserts would have quietly weakened that sentence for the other nine.
`scripts/check_xap_dist_absences.cx` (`make check-xap-dist-absences`) gains
three lanes, red-proven at authoring:

| lane | refuses | why |
|---|---|---|
| root feature library | a `features/` tree at the repo root | the set drifting back into cx-private is exactly what SF-1 ruled against |
| `market/` extra | a fourth `*.feature.cxd` under `market/` | a fourth member would make `market/` the de-facto standard set without anyone deciding it should be |
| `market/` gone | any of `catalog` / `commerce` / `entitlement` missing | conformance `xap-dist` 039–044 read them BY PATH; removing one deletes the §5 worked case (SF-4) |

The last lane is the SF-4 refusal given teeth: the register's reason for
leaving the three where they are is now a gate, not a paragraph.

## SF-7 — `retention`'s scope: it carries a sweep that actually erases

**RULED: (a), by owner, 2026-09-03 ("a").** `retention` is not
declaration-only. It carries `run-sweep` — an act verb, `consequence=irreversible`,
the set's first — which resolves the subjects a policy has made due and calls
the SHIPPED `erase-subject` command per subject, writing a journaled run record.

**Why (a) is long-term best.** #1189's own words are "policies as data, WITH
journaled runs". The mechanics are callable today, so declaration-only would
leave the hard half — resolving due-ness, ordering the sweep, reporting what a
hold refused — for every adopter to build, which is precisely the duplication
the register exists to stop. A policy nothing acts on is also a seam with no
live consumer, which the standing rule says we do not ship.

**Measured before the ruling, on `cx v0.17.0`:**

- `journal:erase-subject`, `journal:legal-holds` and `journal:shred-generation`
  ship and are callable; a journal ATTACHES to an ordinary store handle.
- A full erase cycle returns a `[shred-report …]` and leaves the attributed
  `[erased … at= authority= actor= shred-request=]` tombstone on the value
  channel.
- Hold-beats-shred works exactly as `erasure_compliance` §8 states: a signed
  `[legal-hold]` journaled to `cx:legal-hold` makes `erase-subject` refuse
  `CXER4621` naming the hold's seq, signer and scope, while an unheld subject
  in the same store shreds.
- Constraints for the implementation: `mem://` REFUSES a subject-bearing
  payload (`CXER1144` — the store must be opened with `encrypt-key-id`, whose
  KEK comes from `CX_STORE_KEK_<id>`), and a `nonce=` under 16 bytes is
  refused (`CXER4619`).
- The `$t` parameter of the §1.2 readout contract is a MONOTONIC float in
  seconds (`time.sys_mono_now()/1e9`), not a wall-clock instant — it cannot
  carry the retention clock. Wall time comes from `time:now`; the sweep takes
  an `at=` on the intent so a run is "as of" a stated instant.

**The hold noun is OBSERVED, and this is the load-bearing part of the letter.**
A hold row written into the feature's own store would NOT bind the shredder:
`erase-subject` pins the hold-stream head and re-checks it under the writing
commit lock, and consults nothing else. Such a row would read as "this data is
protected" while the shred proceeded. It is the most dangerous parallel table
the standard set could contain, and it is refused BY CONSTRUCTION — there is no
hold-writing verb, and the sweep does not re-check holds itself either: it
reports what the command refused.

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
- **`retention` as a declaration-only feature** (SF-7(b)). Trigger: the shipped
  `erase-subject` command ceasing to be callable from a feature module — not
  caution about irreversibility, which is what the dial and the compose gate
  are for.
- **A hold noun written by `retention`** (SF-7). Trigger: NONE. `erase-subject`
  consults the `cx:legal-hold` stream and nothing else; a hold this feature
  wrote would not bind, and would read as protection while the shred proceeded.
- **A submodule pin between cx-standard-features and cx-private** (SF-1).
  Trigger: the vendored schemas proving insufficient in practice, measured on
  a real drift incident.
