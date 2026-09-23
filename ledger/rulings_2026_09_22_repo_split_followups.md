# RS-13…RS-23 — the repo split's follow-up decisions (owner, 2026-09-22/23, in session on dev2)

**Status: RULED.** The owner answered each as a letter on the integrator's lettered options, in
session on 2026-09-22 (recorded on [#1591](https://github.com/cx-home/cx-private/issues/1591)
the same hour). They extend [`rulings_2026_09_21_repo_split_1589.md`](rulings_2026_09_21_repo_split_1589.md)
(RS-1…RS-12) and take the calls that page did not make.

RS-18, RS-19 and RS-20 were answered a day later, on 2026-09-23 and on the same issue, as letters
on the five extraction preps' lettered flags (F-D1 for RS-18; F-M1 for RS-19; F-F1 and F-F2 for
RS-20); each section below quotes the owner's letter before it says what the letter moves. RS-21 was
answered the same way, on 2026-09-23, against the store-auth branch's LETTER L1, and is recorded here
beside them.

RS-22 and RS-23 were answered in the same 2026-09-23 pass, as letters on the two LETTERs the
ring1b pipeline left (`_gate_evidence/pipeline_ring1b/RESULTS.md`): LETTER A for RS-22, LETTER B
for RS-23. They are the last two calls the `authz` split left open.

## RS-13 — `authz` splits along the RS-6 line (owner: D14a)

`authz` is not Ring 1 whole: measured on `5bcf2afa9`, `stdlib_authz.v` reaches the journal at 20
sites (the trust store binds and replays a journal handle) and names `SxConn` / `XapRuntime`. The
pure DECISION half — `check`, `authorize`, `decide`, `resolve-cap`, `verify-tier`, delegation parsing
and attenuation, the predicate library — becomes **`cx-stdlib/authz`** (Ring 1: spec
`spec/03-approved/stdlib/authz.md`, corpus `conformance/stdlib/authz.cxd`, code under `vcx/code/`).
The journaled TRUST STORE — `store` and every verb that appends (allocate / debit / delegate /
revoke / commit / grant-guardian / expire) — stays above the rings as **`cx-platform/authz-store`**
(spec `spec/03-approved/platform/authz-store.md`, corpus `conformance/platform/authz-store.cxd`,
code under `vcx/platform/`). `AuthzStore` is cut along that line and authz.md §3.1/§5 say so. A
consumer that decides and mutates imports both; the store server (RS-6) imports the decision half
only.

## RS-14 — did/vc's impure remainder gets modules named for what leaves (owner: D15b)

The pure verbs move to Ring 1 as RS-5 says (`cx-stdlib/did`: `key-create peer-create parse method
document key-of verify-control`; `cx-stdlib/vc`: `issue verify valid present`). The impure remainder
becomes two new modules above the rings, the `http-client` shape with the direction reversed:
**`cx-platform/did-web`** (`resolve` for `did:web` over HTTPS; spec `spec/03-approved/platform/did-web.md`,
corpus `conformance/platform/did-web.cxd`, code `vcx/platform/`) and **`cx-platform/vc-revocation`**
(`revoke`, `revoked-set` over a journal; spec `spec/03-approved/platform/vc-revocation.md`, corpus
`conformance/platform/vc-revocation.cxd`, code `vcx/platform/`). `[$did:resolve]` on a `did:web` from
Ring 1 refuses with a named code and sentence pointing at `did-web`; the refusal is a case in
`conformance/stdlib/did.cxd`.

## RS-15 — the xsp `auth-*` defs become `cx-platform/xsp-auth` (owner: D16a)

The 13 `auth-*` defs of `stdlib/xsp.cx`, whose natives are identity's `stdlib_xsp_auth.v`, move to a
new module **`cx-platform/xsp-auth`** (spec: the existing `spec/03-approved/xap/xsp-auth.md` becomes its
page, corpus the existing `conformance/xap/xsp-auth.cxd`, source `stdlib/xsp-auth.cx`, code
`vcx/platform/stdlib_xsp_auth.v`); `[$xsp:auth-*]` becomes `[$xsp-auth:*]` at every call site (about
75, in `xsp-auth.cxd`, `session.cx`, `store_xsp_*`). `cx-stdlib/xsp` is then the three frame defs and
moves whole to Ring 1 with its V half.

## RS-16 — the `cx` binary grades a corpus file (owner: D13a)

A pure-CX package repo's gate is `cx` on PATH plus its own `.cxd`. The binary gains a verb that grades
module corpus files with the SAME grading core the fixtures shards use (moved out of `vcx/tests/`
into a linked module; the shards' census unchanged), prints the graders' `PASS`/`FAIL` lines and
summary, exits by the CLI's exit-code rule, honours `--manual-clock`, and refuses a document suite it
cannot grade by name. The verb is specified on the CLI page; it exists in the cli and platform
profiles.

## RS-17 — the `-gc e` per-case growth is fixed at the root (owner: D3b)

A long-lived evaluator's per-case cost must be flat: what a finished env leaves reachable under
`-gc e` is found and freed in the runtime/env teardown (measured on `f9706fe84`: the connector shard
3,893 s with per-case cost growing 0.8 → 12–25 s under `-gc e`, 46 s at a flat ~80 ms under a tracing
collector). No grader recycling, no per-kind corpus split, no collector swap for the graders.

## RS-18 — builtin registration splits per family, before the db extracts (owner: D20a)

The owner's letter, on #1591, verbatim: **"builtin registration splits per family before db
extracts — each product registers its own builtins."**

**The measurement it answers** is `extract-db/REPORT.md` flag **F-D1**, *"the drivers come, the
dispatch that reaches them does not"*: `vcx/platform/ring2_register.v` is the ONE site in the
tree that registers every platform family's `$verb`s — `ring2_builtin_register(sql_stdlib_builtin,
'sql')`, the `$if cx_db_redis ?` redis arm, and the seven `sql-*` / `redis-*` names of the §2.1
capability mirror — and `registry/repos.cxd` allocates that file to **`cx-platform-xap`** by the
`[path prefix='vcx/platform/']` catch-all. `cx-platform-db` therefore ships four driver bodies and
a state-code table that nothing can reach: `[$sql-open]` cannot resolve from db's own repository.
The report's option **(a)** is the one the owner took, and its own consequence line is why —
*"every other platform repository (net, store, fabric, identity, mail) hits the same wall next, so
the refactor is not db's alone — it is the general shape"*. Measured on the tree this page sits on:
the central file names **twenty** families whose files land in **eight** repositories, and every one
of the seven non-xap repositories has the F-D1 shape.

**The decision.** Registration splits PER FAMILY and lands in the family's own files, before any
further extraction:

1. **One register file per family**, named for the file that carries the family's dispatcher —
   `vcx/platform/<dispatcher basename>_register.v` — so `repos.cxd`'s first-match rule sends the
   registration to the same repository as the dispatcher it registers, with no new rule needed for
   a family that already has one. A family's impure-verb classification, its env-free and
   env-aware dispatch entries, its subscription ops, its iterator walkers, its per-program resets
   and its half of the security.md §2.1 capability mirror all live in that one file.
2. **`ring2_register.v` becomes the COMPOSER only** — it holds no family's names, calls each
   family's registrar, and seals the registry. It stays allocated to `cx-platform-xap`, which is
   where the composition of a binary from pinned repositories belongs (RS-3, RS-7).
3. **`registry/modules.cxd` names the register file** in the owning row's `code=`, so the register
   file is declared by the module whose surface it switches on and `placement-gate` grades it.
4. **Behaviour is unchanged and the composer proves it by construction.** The registry's four
   ordered lists (the env-free chain, the shared env chain, the main env chain, the per-program
   resets) keep the exact order they had: no single family ordering can preserve all of them at
   once — `store` precedes `smtp` in the env-free chain and follows it in the main env chain — so
   the composer runs TWO phases, and each family's main-env entry is a second, separately ordered
   registrar. The census is identical.
5. **The precedent is item 7's.** `vcx/code/ring1_register.v` already registers the Ring-1 packs
   from the code module's own `init()`, and iowatch's dispatch was split into an io-pack file so
   the engine compiles in every profile. This is that shape applied to the platform families.

**What this page does NOT decide.** V permits ONE `init()` per module, so the composer is a
written list of registrars rather than a table each family fills by itself. Making the absence of a
product remove its registrar without the composer naming it needs one of three mechanisms — a
const-initializer self-registration, a per-family `-d cx_no_pack_<family>` file gate, or a composer
generated from `registry/modules.cxd` behind a drift gate — and each buys a different cost. The
integrator's letter on the implementing branch states the three with their consequences; until one
is ruled, the composer names every family and a family's absence is a link error in `cx`, never a
silently unreachable verb.

## RS-19 — mail claims its smtp/imap pure halves, as `sasl` already is (owner: D19a)

The owner's letter, on the mail extraction prep's F-M1 option (a):

> mail claims its smtp/imap pure V halves (the 7,589 lines `modules.cxd`'s `half=` puts in
> `vcx/code`) by `registry/repos.cxd` prefix rules, as `sasl` already is, so `cx-platform-mail`
> travels whole

`registry/modules.cxd` names, on the `smtp` and `imap` rows, a `half=` column — the pure Ring-1
half AGENTS.md describes — holding `vcx/code/stdlib_smtp.v`, `vcx/code/stdlib_smtp_server.v`,
`vcx/code/stdlib_imap.v` and `vcx/code/stdlib_imap_server.v`. `registry/repos.cxd` claimed only the
two wire halves under `vcx/platform/`, so the four pure files fell to the general
`[path prefix='vcx/code/' repo=cx-core-code]` rule: 7,589 lines, 62% of the two modules' V code,
in a repository other than their module's. `stdlib/sasl.cx`'s Ring-1 code file was already claimed
explicitly by `[path prefix='vcx/code/stdlib_sasl' repo=cx-platform-mail]` — the same shape with
the other answer.

The allocation gains `[path prefix='vcx/code/stdlib_smtp' repo=cx-platform-mail]` and
`[path prefix='vcx/code/stdlib_imap' repo=cx-platform-mail]`, each with a `why=`, written above
the general `vcx/code/` rule so the first-match rule reaches them. `cx-platform-mail` then owns
both halves of both modules and travels whole. The halves import Ring 0 and `encoding.base64`
only — no socket, no store, no clock — so nothing the membership test claims leaves
`cx-core-code` with them.

The gate's blind spot is a defect of its own and is filed as its own issue (the `[split module]`
check read `spec`, `corpus`, `source` and `code` and not `half=`, so the torn module exited OK);
the fixture for it lands before these rows do.

## RS-20 — flow's CLI verbs stay in the front door, and the act seam gets a row (owner: D21a)

The owner's letter, on the flow extraction prep's F-F1 and F-F2:

> flow's CLI V lines (`vcx/cmd/flow*.v`, ~3,672 lines) stay in `cx` (the front door) as the local
> profile, and the `flow-perform` act seam in xap's `coordination.v` gets a row/`why=` that names
> it so a pin and a gate can see it

`registry/repos.cxd` sent `vcx/cmd/flow*.v` to `cx-platform-flow` by a rule whose own `why=` read
"the local profile verbs stay in the binary; owned by flow", while the `cx-platform-flow` row
reads `ships=package` — a package repository owning V that only `cx`'s tree can compile. The rule
now sends those files to `cx`, the distribution repository that builds the binary, and its `why=`
says the verbs are the local profile. `cx-platform-flow` is then what `ships=package` says it is.

`vcx/platform/coordination.v` holds `coord_flow_perform`, the one act seam of an otherwise pure-CX
module (RULED: 1265-PB-1), and travels to `cx-platform-xap` inside the catch-all
`[path prefix='vcx/platform/' repo=cx-platform-xap]` rule, where nothing names it: the `flow`
module row reads `code=none`, so `make placement-gate` does not see the seam either. The file gains
an `exact=` rule of its own, above the catch-all, whose `why=` names `flow-perform` and the
repository that depends on it, so the seam is legible to a pin and to a gate without a reader
opening the file.

## RS-21 — a decision's design item may ADD spec text where the edit map is silent (owner: D22b)

**The question.** `_gate_evidence/pipeline_storeauth/RESULTS.md` §7 LETTER L1 asked whether the
store profile page may carry a normative `[grants]` document-shape section. The design item was
already ruled — the store server authenticates through the Ring-1 trust primitives and the daemon's
own `[grants]` table — but the repo-split page's spec-edit map lists no sentence on
`spec/03-approved/xap/xsp_store_profile.md`, so every sentence of a new section sat beyond the map.
The letter offered (a) leave it, with the operator-facing grammar of the daemon's only authority
surface readable nowhere but the parser; (b) authorize one §6.2 under the design item; (c) move the
shape to `platform/store.md`, its long-term home once the store extracts. The integrator
recommended (b) now, (c) at the extraction.

**The owner's answer (D22b, 2026-09-23, on [#1591](https://github.com/cx-home/cx-private/issues/1591)), verbatim:**
"one normative §6.2 `[grants]` document-shape section on `xsp_store_profile.md`, under RS-6,
cross-linked from `platform/store.md` §6.4."

**The precedent.** A decision's design item MAY ADD spec text to a page the decision's edit map does
not name, when the added text says what that design item already ruled and says it in the page's own
voice. It may never MOVE or DELETE spec text there: a sentence the map does not name stays exactly
where it is, and a page the map does not name keeps every sentence it already has. The silence of an
edit map is therefore permission to write down a ruled design, never licence to rearrange a page
around it. `AGENTS.md` rule 1 is unchanged — the spec is the only truth, and a spec edit happens
inside a decision; what this decision settles is that the decision's own design items, not only its
enumerated edit rows, are inside it. A sentence beyond the design item stays what it has always
been: a flag in the agent's report, not an edit.

**This instance, bounded.** Exactly two pages move. A new §6.2 on
`spec/03-approved/xap/xsp_store_profile.md` states the `[grants]` document shape — its attributes,
the capability classes §6.1 names, what an unmatched principal receives, the refusal codes, and the
relation to the Ring-1 confirm primitive — with every claim carrying the id of a case that pins it.
One sentence in `spec/03-approved/platform/store.md` §6.4 cross-links it. Nothing else in either
page moves, and the letter's option (c) — the shape following the product into its own repository —
is not taken here and stays open for the extraction.

## RS-22 — `authz-store` and `vc-revocation` stay in `cx-platform-identity` (owner: D24a)

The owner's letter, on the ring1b pipeline's LETTER A:

> `cx-platform/authz-store` and `cx-platform/vc-revocation` live in `cx-platform-identity`
> (confirming the allocation; no row moves — record only)

LETTER A reported that neither module is derivable from the contents-per-repo bullets of issue
[#1589](https://github.com/cx-home/cx-private/issues/1589): `did-web` and `xsp-auth` are named
there by name, and these two are not. The ring1b branch allocated both to `cx-platform-identity`
on the reading that the product is the authority/trust model and identity is where that model's
other pieces already sit (session, the XSP-AUTH handshake, principal mint), and that RS-6 has the
store server CONSUME the trust primitives rather than own them — which argues against
`cx-platform-store`, the alternative the letter stated with its consequence (the trust ledger in
the repository whose server must not own it, and identity's authority surface split across two
repositories).

The letter CONFIRMS what is on the tree. `registry/repos.cxd` keeps the rows it already carries,
no `[path …]` row moves, and this section is the record that the reading was the owner's and not
the branch's. The `cx-platform-store` ↔ `cx-platform-identity` pin direction carries authz as well
as session, as the letter's first bullet states.

## RS-23 — the decision half gets a pure `open` over an in-memory trust store (owner: D25b)

The owner's letter, on the ring1b pipeline's LETTER B:

> `cx-stdlib/authz` gets a PURE `open` over an in-memory store, so every one of its decision cases
> grades in Ring 1 with no per-case `ring=` override

LETTER B measured the cost of RS-13 as it merged: `store` — the OPEN verb — went to
`cx-platform/authz-store` with everything that appends, so a program that only DECIDES still could
not obtain an authority store without importing the platform module. The decision corpus therefore
carried the per-case `ring=2` override on 35 of its 39 cases and the Ring-1 lane graded four
`gate-wellformed` cases: `cx-core-code` shipped a module whose corpus was almost entirely graded at
Ring 2. The letter's option (a) was to leave it, which is what merged; (b) was to return the
UNBOUND tier's open to the decision half.

The owner took (b), with the name the letter's own objection to it requires. `cx-stdlib/authz`
gains **`open`** — a PURE constructor over an **in-memory** trust store, the capability-free
substrate `mem://` is for `store` and `journal`. The JOURNALED constructor keeps its own name and
its own module: `[$authz-store:store]` is still `cx-platform/authz-store`'s, still binds and
replays the `authz` stream, and still is the only way to reach the durable tier. The two are not
one verb on two modules — the thing RS-14 rejected for `did` — because they are spelled
differently and answer for different tiers, and `authz.md` §3.1 says which is which.

The decision half's corpus is then authored against the unbound tier (the letter's option (c)):
every per-case `ring=` override in `conformance/stdlib/authz.cxd` is removed and every decision
case grades in Ring 1 at every profile, which is the proof the override was hiding. A case whose
SUBJECT is the durable tier — a journal replay, an append fault, a metered debit — is
`conformance/platform/authz-store.cxd`'s and stays there.

## Also ruled in the same session, operational (no id; recorded)

D1a the RS page landed as drafted; D2a the XSP codec's home as drafted; D4a #1592 re-rated
prio:medium; D5a #1594 closed, #1601 filed; D6a the runner derives `VJOBS` from the box (#1600);
D10a agents run in parallel without a count cap on dev2, opus by default; D11a merges batch per
union; D12a Fable only for the integrator session and for a runtime problem the owner names.
