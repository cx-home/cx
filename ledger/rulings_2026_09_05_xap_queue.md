# Ruling record — the #1309 step-5 XAP queue: #1269, #1268, #1272, #1271, #1217 (2026-09-05)

Five issues that each asked for a lettered ruling. Ruled together because three of them
turn on the same fact — **the grammar is the single statement of what a feature is** — and
recording them apart would have hidden that they agree.

---

## #1269 — XSP binary payloads: RULED (a), the payload rides `ast-bin`

Issue: #1269 (bug, area:cx-stdlib, area:xap, prio:medium). Specs: `xap/xsp.md` §3,
`core/data_bin.md` §3.9, `core/ast_bin.md`, `core/cxdm.md` §2.4.

**Measured** on `release/0.18` @ d07f14933: `[$xsp:decode [$xsp:encode [frame … [payload
[do 'a/b' [key 'speed'] [n 1] [nested [x 'y']]]]]]]//payload` answers
`[payload [do _='a/b' key=speed n=1 [nested x=y]]]`. Every child whose content is a scalar
came back as an ATTRIBUTE and the text item became an `_` attribute. `xsp.md` §3 claims a CX
value round-trips losslessly; `data_bin.md` §3.9 encodes an element as the `0x50` keyed-map
projection, which by construction cannot tell `[key 'speed']` from `key='speed'`.

- **(a) RULED — an XSP binary payload carries `ast-bin`, the lossless CX tree tier.** The
  frame layout is unchanged; only the payload codec changes.
  **DELETES:** `data-bin` as the XSP payload codec. `data-bin` is untouched everywhere else
  — it stays the object/table tier, and its `0x50` element form stays byte-identical for
  the arrow / columnar / store-pack consumers that depend on it.
  Why: `[$xsp:decode [$xsp:encode v]] == v` is the invariant a *transport* must have. Without
  it every consumer has to know which values survive the trip, which is not a property a
  transport can ask of its users. And the value that does not survive is the RULED act form
  (#1260 CA-1: fields as CHILDREN, chosen precisely because an attribute cannot carry a
  list- or record-valued field) — so the binary lane silently rewrites acts into the shape
  that ruling retired, and nothing refuses.
- (b) keep `data-bin`, strike the "losslessly" claim, and state that an act MUST ride the
  text lane. Rejected: it deletes the invariant instead of the defect, and it leaves a
  transport whose fidelity depends on the shape of what you send.
- (c) `data-bin` gains a lossless element mode with a child/attribute marker. Rejected: it
  perturbs the `0x50` form that the object tier's other consumers pin byte-identically, to
  fix a problem that is not the object tier's.

**Cutover, not dual-accept.** `binary=true` is the default and is live on the fabric and
store-serve paths, but frames are in-flight only — nothing persists one — and both ends ship
in one binary. So the codec changes in one commit with no compatibility arm.

**Exit:** a conformance fixture pinning `[$xsp:decode [$xsp:encode v]] == v` for an element
with text-only children, for the #1260 act form with a record-valued field, and for a
`[payload]` carrying a map / sequence / bytes; the store-serve and fabric wire tests green
on the new codec; `xsp.md` §3's lossless claim now true, under `RULED: 1269-Q1`.

---

## #1268 — an act's undeclared fields: RULED (b), refuse EXTRAS, tolerate MISSING

Issue: #1268 (bug, area:xap, prio:medium). Spec: `xap/xap_grammar_composition.md` §6.1
(N-COMPOSE-7), `xap.md`, distribution §1.2. Not ruled by #1260.

**(a) is not available, and finding out why is the ruling.** (a) would refuse an act whose
children are not *exactly* the declared list. But N-COMPOSE-7 has a **fallback**: a verb with
a bare `[intent [do :v]]` exposes the fields of the noun it `[writes]`. `cx xap init`'s own
scaffold is that case — `[intent [do :register]]` over a noun carrying
`id` / `name` / `registered-at` — and `registered-at` is server-stamped, so requiring it on
the client's act is wrong. There is no way to mark a parameter optional or server-supplied
in the grammar today, so (a) would make an optional field **inexpressible**. A ruling that
demands exactness must first give the grammar a way to say "not always".

- **(b) RULED — the PEP-side admission refuses an act carrying a field the declared list
  does not name, and admits an act missing one.** The refusal is a value naming the verb,
  the offending field, and the declared list.
  **DELETES:** the silent admission of undeclared fields — including the toy door test
  module's reliance on `stuck` / `jam`, which stops in the same commit.
  How an empty field is told from an absent one (the rider the issue requires): the
  discriminator is PRESENCE, exactly as #1260 CA-1 has it. `[note]` with no body is the
  field **present and empty** — a performer-supplied hole; no `[note]` child at all is the
  field **absent**. Both pass admission under (b); the module sees the difference, because
  the act carries it.
  Why extras and not both: an extra field is unambiguously a fault — the grammar cannot
  account for it, and the journal would carry an act the grammar cannot explain, which is
  this issue's stated harm. A missing field may be a legitimate optional or server-stamped
  value that the grammar has no vocabulary to declare.
- (a) refuse missing AND extra — **the door is MARKED, not closed.** It becomes the right
  ruling the moment N-COMPOSE-7 can mark a parameter optional or server-supplied, and that
  marker is its own ruling with its own motivating case (filed separately, not smuggled in
  here).
- (c) leave it — the list is a projection aid. Rejected: N-COMPOSE-7 exists so two clients
  cannot disagree about a verb's arity; a list nothing enforces cannot adjudicate anything.

**Exit:** fixtures — an act with an undeclared field refuses at `POST /intent` and at
`[$xap:emit]` alike (the two paths answer the same value); an act missing a declared field
is admitted; a declared-but-empty field is admitted and distinguishable from absent; the
serve bridge's `POST /intent/<verb>` stops silently dropping extras and refuses them; the
toy door module declares every field it reads.

---

## #1272 — the compatibility floor: RULED (a), and it spends NO new error code

Issue: #1272 (bug, area:xap, prio:medium). Spec: `xap/xap_feature_distribution_market.md`
(distribution) §2 (`compatibility`), §1.2 (the feature contract), §6 steps 4–6.

`package.cxd` carries a `compatibility` block — "the XAP spec revision + toolchain floor the
package validates against" — that **nothing writes and nothing reads**. So when the §1.2
contract changed (#1210 HC-1: entry points take `$host`, not a bare store handle), a module
built against the old contract installs and boots cleanly and fails at its first store call
(`concat: argument 2 is absence`). Arity is unchanged and a parameter name is irrelevant, so
no static check can tell the two apart — the floor is the only honest signal, and it is inert.

- **(a) RULED.** `pkg-seal` writes the toolchain version and the §1.2 contract revision the
  package validated against into `compatibility`; `pkg-install` refuses a package whose
  declared contract revision is below the host's, with a value naming **both** revisions and
  the package.
  **DELETES:** nothing — the block exists and is inert; this makes it load-bearing.
  **The refusal reuses `CXER4884` (`E_XAP_PKG_GATE_REJECTED`), which spends no code.** Its
  contract already reads "the per-kind install gate rejects — carries the gate's own values",
  and a contract-floor check *is* a per-kind install gate. Minting a new `CXER488x` was the
  issue's suggestion; the pkg sub-band has only `CXER4885` and `CXER4889` free, and spending
  one of the last two on a refusal an existing code already describes would be the wrong
  trade twice over.
- (b) the lighter form — the host refuses at BOOT when a module's manifest lacks the floor or
  declares an older revision. Rejected as the primary, KEPT as a second line: a fleet
  installs long before it boots, and "install succeeded, boot refused" is the shape that
  wakes people up at night. The boot check stays as the belt to (a)'s braces, since a module
  can reach a runtime without passing through `pkg-install`.
- (c) spec-only, rely on CHANGELOG. Rejected: a CHANGELOG is not a refusal, and the failure
  it is asked to prevent surfaces as an unrelated absence error at the first store call.

**Exit:** fixtures — `pkg-seal` writes both fields; a package sealed at the current revision
installs; one sealed at an older revision refuses `CXER4884` naming both revisions; a manifest
with no `compatibility` block refuses the same way (absence is not a pass); the boot-side
check refuses a module whose manifest declares an older revision. Spec under `RULED: 1272-Q1`.

---

## #1271 — a served-tier journal handle: RULED (a)

Issue: #1271 (bug, area:xap, prio:medium). Spec: distribution §1.2 (the deployment context,
#1210 HC-1), `xap.md` §3.1.1, `std-lib/journal.md`.

`[host tenant= [store <handle>] [journal <handle> stream=]]` carries `[journal …]` exactly
when this process holds a journal handle. For an embedded binding (`file://`, `mem://`, a
`[$journal:open]` value) it does. For a **served** binding (`xsp://`) the chain lives in the
fabric daemon, only `fabric-publish` / `observe` reach it, and the child is ABSENT — loudly,
announced at boot. But HC-1's whole point was that a feature can own its fold portably
across deployments, and the served tier is the tier fleets and cross-company deployments run
on: there, it cannot.

- **(a) RULED — a journal handle over a served store.** `[$journal:open "xsp://…" TENANT]`
  resolves through the networked store backend, so `$host/journal` is **present at every
  tier** and a feature's fold is portable as HC-1 promised. The fabric handle stays what it
  is — the transport's.
  **DELETES:** the tier split in distribution §1.2 and the boot notice that announces the
  absence. One handle kind, one fold surface, at every tier.
  Why not the other two: they both make the tier visible in the feature's own code, which is
  the thing HC-1 removed.
- (b) a fold-capable fabric surface (`fabric-fold` / `fabric-since`) carried as a
  kind-polymorphic handle. Rejected: two fold surfaces for one concept, and every feature
  that folds would branch on which one it got — the tier split again, one layer down.
- (c) keep the absence; feature-owned folds are an embedded-tier facility. Rejected: it
  concedes the capability at exactly the tier where the flow engine's fleet readout (#1265
  W4) and the cross-company profile (W6) live.

**Scope note, stated rather than deferred:** (a) is a wave of its own — the journal verbs'
fold path over a networked store backend, and the store profile's pushdown for the
`since`/`at-seq` reads. It is sequenced after the #1269 codec cutover, because a served fold
reads payloads over the wire and would otherwise be built on the codec being replaced.

**Exit:** fixtures — the same feature's fold answers identically against `mem://`, `file://`
and `xsp://` bindings; `$host/journal` present under all three; the boot notice for the
served tier is gone because there is nothing to announce; an unauthorized served fold
refuses at the store's own authority layer, not at the handle.

---

## #1217 — the UX projection over feature verbs: RULED items 1 AND 2

Issue: #1217 (bug, area:xap, prio:medium, ux). Spec: `x/ux.md` §3.1 and [P0-17],
`xap_grammar_composition.md`.

`cx xap init demo` scaffolds a feature contract; `[$ux:form <feature source> 'register']`
answers `[err code=ux-refused [ux-refusal code=ux-no-such-command verb=register]]`. The
refusal is correct on its own terms — [P0-17] makes `[effects]`-clause presence the
discriminator and a feature verb is not a `[?def]` — but **nothing projects the other
declaration system**, and both halves are cx's own.

- **RULED: items 1 and 2, together.** `[$ux:form]` projects a **feature verb**, deriving from
  `[verb …]` plus the `[noun …]` it `[writes]`: fields → `ux:input`, `type=` → `kind=`,
  `doc=` → the label or help text; and it projects over a **composed grammar**, not one
  contract, because the useful unit is the composition — the verbs the grammar carries after
  the gate has run, which is where drift is most expensive.
  **DELETES:** nothing in the `[?def]` projection — [P0-17]'s discriminator is unchanged and
  the command path answers exactly as §3.1 documents. What it deletes is the hand-written
  per-feature view that `cx xap init --client` currently tells adopters to write, which is
  the drift [P0-17] exists to remove, reintroduced at composition scale.
  The material is already declared, and declared MORE completely than in the `[?def]` case:
  a verb names the noun it writes, and the noun declares its fields with types and `doc=`
  strings — the same material `type-schema-of` extracts from a param list, plus documentation
  a param list does not carry.
- **Item 3 (`ux-not-a-command` beside `ux-no-such-command`) is SUBSUMED, not deferred.** It
  was the issue's "cheap floor if the answer to 1 is no". The answer to 1 is yes, so there is
  no unaddressed declaration system left to name: after this, a refusal on a feature source
  means the grammar genuinely does not carry that verb, which is what
  `ux-no-such-command` already says. Adding a second code would name a distinction that no
  longer exists.
- N-COMPOSE-7 is what makes item 1 well-defined: the declared parameter list is the verb's
  arity, with the written noun's fields as the fallback (see #1268 above). The projection
  reads the same two sources, in the same order, so the form and the admission cannot
  disagree about what a verb takes.

**Exit:** fixtures — `[$ux:form]` over `cx xap init`'s own scaffolded `owner.feature.cxd`
answers a `[ux:form]` with one `ux:input` per declared field, `type=` mapped to `kind=`, and
`doc=` carried; over a composed grammar, every verb the composition carries; a verb the
grammar does not carry still refuses `ux-no-such-command`; the `[?def]` command projection
byte-identical to today. Spec `x/ux.md` §3.1 under `RULED: 1217-Q1`.
