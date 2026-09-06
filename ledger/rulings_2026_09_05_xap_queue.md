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

---

## #1269 — implementation record, 2026-09-05 (RULED: 1269 (a), landed)

`vcx/platform/stdlib_xsp.v`: `codec_emit_bytes_node('data-bin', …)` /
`codec_parse_bytes_node('data-bin', …)` → `'ast'` (the registered name of the ast-bin
codec, `vcx/cx/codec.v`). Two call sites; the frame layout, the flags bit and the text
lane are untouched.

### Measured — the cutover is strictly better on every payload shape tested

| payload | data-bin (before) | ast-bin (after) |
|---|---|---|
| `[do 'a/b' [key 'speed'] [n 1] [nested [x 'y']]]` | `[do _='a/b' key=speed n=1 [nested x=y]]` | round-trips exactly |
| `[do 'door/unlock' [note 'front'] [items [i 1] [i 2]]]` (the #1260 act form) | children collapsed to attributes | round-trips exactly |
| `{a: 1, b: 'two'}` | `[a 1][b two]` — flattened to child elements | `{a: 1, b: two}` |
| `42` | `[_ 42]` — wrapped | `42` |
| bytes-valued attributes | preserved | preserved |

Maps and scalars were NOT in the issue's scope and were also being mangled; both are
fixed by the same change.

### The consumer that depended on the lossiness — and the correction it forces

`vcx/tests/xap_umbrella_test.v`'s XSP-AUTH helper read `$m2/@eph` and `$m2/@nonce` on a
DECODED message. Those fields are written as CHILDREN (`[eph …]`, `[nonce …]`); they were
readable on the ATTRIBUTE axis only because data-bin's `0x50` projection had collapsed
them. Post-cutover the child axis is correct and `$m2/eph` yields the bytes directly
(measured). One line changed; the V implementation of `xsp:auth-*` never used the
attribute axis, so nothing else moved.

**This is the part the ruling under-stated.** It said "cutover, not dual-accept: frames
are in-flight only, nothing persists one, and both ends ship in one binary" — true, and
sufficient for the WIRE. It did not say that a consumer may have been written against the
collapsed shape. Nothing persisted a frame, but a reader had encoded the loss into its
navigation. The lesson generalizes: a codec cutover's blast radius includes every reader
whose paths were shaped by the old codec's defects, and those do not appear in a search
for persisted artifacts.

### Verified

`xap_umbrella_test` (the XSP-AUTH mutual-attach handshake end to end),
`platform_store_wire_umbrella_test`, `platform_netwire_umbrella_test`,
`fabric_umbrella_test`: all green. Fixture `xsp-024-binary-payload-round-trips-a-cx-element`
in `conformance/stdlib/xsp.cxd`. Spec: `xsp.md` §1, §2 (frame table + flags bit), §3 and
the §4 error row updated under `RULED: 1269`.

### The blast radius was FIVE consumers, not one — and the ruling under-stated it twice

The implementation record above named one: a test helper's `/@eph`. Running the stdlib
conformance corpus (which the V umbrella lanes do not cover) found four more, and they
sharpen the lesson rather than repeat it:

| consumer | depended on | corrected to |
|---|---|---|
| `xap_umbrella_test` XSP-AUTH helper | `$m2/@eph`, `$m2/@nonce` | child axis |
| `xsp-auth-017` | `[$first $decoded/payload]` naming the message | `[$first $decoded/payload/*]` |
| `xsp-auth-024` | the attr-form M2 (`$m2c/@eph`) | child axis |
| `xsp-auth-030` | `$m1-rt/@offer-features` | child axis |
| `xsp-016` | `[payload 2]` decoding as `[_ 2]`, so `/payload/*` found a child | `[$first $cfr/payload]` |

**Two of these fixtures existed to PIN the lossiness.** `xsp-auth-024`'s own doc said the
frame's "data-bin decode atomizes the single-scalar handshake fields … into attributes"
and pinned that `auth-prove` / `auth-finish` read the attr-form messages exactly as the
fresh child-form ones. `xsp-auth-030` said the offer fields are single-scalar "precisely
so they atomize across the data-bin frame round trip". Both notes are now false, and the
property each was protecting is strictly stronger after the cutover: a decoded message is
BYTE-IDENTICAL to the fresh one (`[= $m1 $rt]` → `true`, measured), so there is only one
form to read.

**What this says about reading a fixture failure.** A corpus can encode a defect as an
invariant, in prose, with a rationale that reads as a design argument. `xsp-auth-030`'s
"precisely so they atomize" is indistinguishable in tone from a real ruling. The only way
to tell them apart is to ask what the case is REALLY protecting — here, "the signed bytes
do not move between fresh and decoded forms" — and check whether the change preserves
THAT. It does, more strongly.

**And the process miss:** the V umbrella lanes were green while four conformance fixtures
were red. Running `code_eval_fixtures_test.v` (the stdlib corpus) is not optional for a
codec change; the umbrellas exercise the wire, the corpus exercises the CX-level reads.

---

## #1268 — RE-SCOPED 2026-09-05. The prerequisite landed; the admission check did not

Ruling (b) — refuse extras, tolerate missing — is unchanged and still right. What changed
is the estimate of what it takes, and the estimate was wrong twice over.

### What landed: the parameter list now REACHES the grammar (the prerequisite)

`XapGVerb` had no field for the `[intent [do :v [a] [b]]]` parameter list. The clause was
required and validated for PRESENCE — `xap_gc_child(ve, 'intent') or { error }` — and then
**discarded**. So N-COMPOSE-7's own claim, that the list "exposes exactly `(a, b)` to a
consumer, in that order", was true of NO consumer reading the composed grammar. Both
things that need it — the PEP's act admission (#1268) and the UX projection of a feature
verb (#1217) — had to infer arity from the written noun, which is the inference
N-COMPOSE-7 exists to replace.

Now: `v.params` is parsed from the clause, and the composed verb entry carries
`[params 'a b']` in EMISSION order (never sorted — unlike `[writes]`, the order IS the
declaration). A bare `[intent [do :v]]` emits NO `[params]` child, so a consumer can tell
the documented fallback ("ask the written noun") from "takes nothing", which the clause
itself cannot express. `xap_gc_verb_params` returns `?[]string` for exactly that reason.

Verified: `[verb name='door/unlock' … [writes 'door/door'] [params 'note']]`.

**This unblocks #1217**, which needs the same list.

### What did NOT land, and why — the act shape is more varied than the ruling assumed

The admission check was written, wired at the §4.9 point (before types / transitions /
cardinality / checks, since a field the grammar cannot account for makes those questions
meaningless), and reverted. Three findings, each from a measurement:

1. **The toy door relied on undeclared fields**, exactly as #1268 said — `stuck` / `jam`.
   Declaring them in its `[intent]` is correct and is kept.
2. **`id` was undeclared too.** The spec's own N-COMPOSE-7 example
   (`[do :place-order [id] [customer] [promised-at]]`) includes the identity field, so
   declaring it is right. Kept.
3. **The blocker: a SOURCE-PUMP-ingested act does not carry the declared parameters.**
   A fabric event `[unlock [id "…"]]` reaches the emit path as an intent whose single
   field is an element NAMED AFTER THE VERB — the pump passes the source event through
   rather than mapping it onto the parameter list. Under the check every pump-ingested
   act is refused, and `test_xap_host_arms_source_pumps_only_after_authority` fails with
   three pre-seeded entries never ingesting.

Item 3 is not a bug in the check. It is a real question the ruling did not ask: **is a
pump-ingested act subject to N-COMPOSE-7's list, and if so, whose job is the mapping?**
Either the source dial maps the event onto the declared parameters (the honest answer, and
it makes the pump's contract explicit), or ingested acts are exempt and the exemption is
stated. Deciding that is #1268's remaining work, and it is pump/dial design rather than an
admission check.

Also found on the way: the act form is not one shape. `[do 'ns/verb' [field …]]` carries
the verb designator as a SCALAR at index 0; `[verb [field …]]` names the verb on the
ELEMENT and puts a field at index 0. A check that skips index 0 unconditionally misreads
the second shape and refuses the verb name as a field. Any future implementation must key
on "every ELEMENT item is a field, every scalar is the designator", not on position.

---

## #1272 — RE-SCOPED 2026-09-05, not implemented. The floor has nothing to hold

Ruling (a) — `pkg-seal` writes the floor, `pkg-install` refuses below it, reusing `CXER4884`
rather than minting a code — stands. It cannot be built yet, and the reason is the same
class as #1268's.

**Verified:** `pkg-seal` writes only `hash=` onto the draft; nothing in
`vcx/platform/stdlib_xap_dist.v` reads or writes `compatibility`. The issue's premise holds
exactly.

**The blocker:** distribution §2 specifies the block as *"the XAP spec revision + toolchain
floor the package validates against"*, and **there is no XAP spec revision**. A search of
`spec/` and `vcx/` finds no revision identifier, no constant, nothing `pkg-seal` could
write and nothing `pkg-install` could compare. The ruling said "pkg-seal writes the
toolchain version and the §1.2 contract revision it validated against" — the first half
exists (the repo `VERSION`); the second does not.

**So #1272's real first question is one the ruling did not ask:** what IS the §1.2 contract
revision — an integer bumped by hand, the spec document's own revision, the release
version, a content hash of the contract's normative text? — and **who bumps it, on what
rule?** That identifier constrains every future contract change and is a shipped surface in
its own right; inventing it as a side effect of wiring a floor check would be the wrong way
to acquire it.

The toolchain-floor half could be built alone (the repo VERSION is real), but it does not
answer this issue: #1210's contract change is what the floor must catch, and a toolchain
version only catches it when a contract change happens to coincide with a release boundary.
A floor that is right by coincidence is worse than an inert one, because it reads as
enforcement.

---

## The pattern across step 5, stated once

Three of the five step-5 rulings assumed an artifact that does not exist, and each cost an
implementation attempt to discover:

| ruling | assumed | actually |
|---|---|---|
| #1250 | `planar_place_filters` is complete over `[?for]` | written for the planar SUBSET; under-approximates dependencies on the full grammar |
| #1268 | the admission point can read the declared parameter list | the `[intent]` clause was validated for presence and DISCARDED |
| #1272 | a §1.2 contract revision exists to write into the floor | no revision identifier exists anywhere |

**What separated these from #1269, which landed clean:** #1269's premise was verified
EMPIRICALLY before the ruling — the round-trip loss was reproduced, `binary=true`'s
consumers were grepped. The other three were reasoned from issue text and spec text, both
of which describe what SHOULD be there. A spec sentence is not evidence that the thing it
describes is implemented; N-COMPOSE-7 asserts the parameter list "exposes exactly (a, b) to
a consumer" and no consumer could see it.

**The rule for the remaining two (#1271, #1217):** verify the artifacts the ruling depends
on exist, by running something, before writing any code. Both premises HAVE been verified
that way — #1271's absence is stated in `stdlib_xap.v:172` and #1217's refusal was
reproduced — and #1217's prerequisite (the parameter list) has now landed.

---

## #1217 — CORRECTED 2026-09-05. Item 1 already existed; the real defect was item 2

My ruling said "implement items 1 and 2, item 3 is subsumed". **Item 1 was already
implemented** and had been since 2026-08-17. This is the fourth step-5 ruling to assume an
artifact's state without checking it — and the first where the artifact was already THERE.

**`[$ux:feature-form FEATURE VERB OPTS]` is public and does exactly what item 1 asks.**
Measured on `cx xap init`'s own scaffold:

```
[ux:form verb=register [ux:heading level=2 'Register']
  [ux:input name=id label=Id kind=text value='' help='the shared key']
  [ux:input name=name label=Name kind=text value='']
  [ux:input name=registered-at label='Registered at' kind=instant value='']
  [ux:submit label=Register]]
```

Fields from the written noun, `help=` from its `doc=`, title degrading by name — the
projection the issue asks to be built. `intent-params` (RULED: DP1 4b, owner 2026-08-17)
already reads the declared parameter list in preference to the noun's fields, precisely
because projecting the noun OVER-OFFERS.

### The real defect: that ruling held for one artifact and silently failed for the other

Composition keeps the parameter names but drops the `[intent [do :v [a] [b]]]` clause that
held them — and since #1268 carries them as `[params 'a b']` instead. `intent-params` read
only the feature-document spelling, so **every composed verb answered absence** and the
projection fell back to the noun. Measured, same verb, two artifacts:

| read from | inputs offered |
|---|---|
| the feature document | `id`, `name` |
| the composed grammar | `id`, `name`, **`registered-at`** |

`registered-at` is server-stamped; the verb declares `(id, name)`. DP1 4b's over-offering
defect, alive on the composed path the whole time — and invisible until #1268 put `[params]`
on composed verbs, because before that there was nothing for a corrected reader to find.

Fix: `intent-params` reads both spellings. Fixture
`ux-083-composed-grammar-projects-the-declared-parameters` pins PARITY rather than either
answer — a client reading the composition and a tool reading the contract must not disagree
about what a verb takes.

### What remains on #1217, re-scoped

- **Item 2 is now correct** for `feature-form`. What is NOT done is routing: `[$ux:form]`
  (source + verb) still answers `ux-no-such-command` for a feature source, and nothing
  tells the adopter that `feature-form` is the entry point for the other declaration
  system. That is the issue's item 3, which I ruled "subsumed" on the strength of item 1
  being unbuilt — it was not, so item 3 is the remaining work, and it is a routing/
  discoverability question, not a projection one.
- `feature-form` already answers `ux-no-such-verb`, distinct from `ux-no-such-command`, so
  half of item 3's ask exists too.
