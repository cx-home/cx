# XSP generalization and the store profile (stream 4)

**Status:** APPROVED — graduated 2026-08-20 by owner ruling SPR-1 (G3; ledger/rulings_2026_08_20_spec_tree_reshape.md). Prior status: working draft (stream 4, issue #676). The §12 L5a + §13 fold rulings made real: the spec splits generic-frame/session vs profiles (zero wire change); the store profile becomes THE store wire; the CSRP data plane retires at a gRPC-style parity gate; ONE authority model. Carries the adopted D-XSP-c mandate (the server↔server channel + VC-revocation propagation — a live security hole), the G8/G13 corpus mandates, stream 6's bounds wire carriage, stream 3's change-feed requirement, stream 2's ∂ wire frames, stream 21's transcript-covered vocabulary negotiation, and crypto-agility's binary multihash forms. Normative once approved; implementation EARLY at I5 (streams 9/10/20 build on this).

**Worked example (M5):** the commerce store served over the profile — an
order put returns `sha2-256:4ea31c…` byte-identical to local; the refund
agent's propose-only, `[bounds]`-bearing delegation crosses the wire as a
VC in the M3 attach; the dashboard's `changes-since` pulls ∂ frames
(credit-governed, never coalesced) from the ref-advance feed; the offline
replica seeds from a signed head-set and pulls the same feed; two daemons
peer over mutual XSP-AUTH and a revoked credential propagates as journal
data — enforced locally at the next PEP check, never by remote reach-in.

## §1. Findings

1. xsp.md §1 was explicitly waiting for this stream ("a premature split
   would add a layer with no second consumer yet"); fabric §11 is the
   profile template (verbs as payload vocabulary over
   request/reply/event + credit + resume).
2. CSRP ships 21 wire ops, two lanes (text + a 5-frame binary codec),
   and a four-provider parallel auth stack (static/JWT/DID/OIDC bearer +
   hard-coded RBAC roles + tenant string-lists) — the exact
   two-authority-model drift the fold ruling kills. The irony to
   exploit: CSRP's DID provider is a one-shot bearer JWS lacking
   precisely the mutual channel-bound handshake XSP-AUTH ships.
3. The injected `ObjWireTransport` seam is the client migration point
   (an XSP transport is a third implementation); journal-over-CSRP
   (#644) has no spec section — this stream writes it for the profile.
4. **Feature negotiation is post-attach and OUTSIDE the signed
   transcript today** — a MITM can strip `store-feed`/`store-delta`
   tokens: a live downgrade surface, resolved here (L164).
5. Fabric ruled verb payloads text-canonical-only because data-bin is
   lossy on element/attr duality — while the store wire carries ast_bin
   doc bodies whose content addresses must be byte-exact. Both are
   right; the lanes must be ruled per role (L165).
6. Spec/impl divergences inventoried (#718): the shipped session advert
   carries a `rotate` token xsp.md doesn't list; the .proto lists 8
   RPCs vs 19 served; the parity suite misses Aliases/AliasesSet/
   Reload; list-shape and capabilities-compression divergences; retired
   URL query params still accepted; CXER-XSP-* symbolic codes have no
   registry rows; "the protocol is permanent" sentences to strike.

## §2. The split and the profile model (L163)

xsp.md splits into **"XSP frame + session layer"** (generic, normative —
frame v1 unchanged, §5.0–§5.3 with the `rotate` token added) and
**profiles**: the XAP profile (today's semantics, re-labeled) and the
STORE profile (this spec). The std-lib catalog pointers re-point. A
profile = a feature-token set + a payload verb vocabulary + its error
rows; growth is only ever a token (the §8 wire-freeze shape).

## §3. Transcript-covered negotiation (L164)

Profile and feature OFFERS move into the XSP-AUTH handshake: M1/M2 carry
offered token sets, M4 confirms the selection — **inside the signed
transcript** (the downgrade-protection property extended from
versions/suites to vocabulary, discharging stream 21's handoff).
**Version-handle consequence (audit C9): this changes what the HKDF
label covers, so landing it bumps `xsp-auth/2/…` → `/3/` (ruled in the
crypto-agility spec §6 item 3); #718's downgrade-strip security item is
verified in the same I5 cut.** The
post-attach `[…-session]` advert remains for operational limits
(windows, timeouts); any token that changes SEMANTICS is
transcript-bound. Unknown tokens stay ignored on the discovery surface;
un-negotiated frame types stay loud errors (the §5.0 rules, now
anchored).

## §4. Op vocabulary, lanes, and errors (L165–L167)

- **All 17 CSRP data/admin ops become payload verbs** (request→reply on
  a stream-id); `query`/`iter`/`list` become **credit-governed `event`
  streams** with `cancel` and `eos` (today unbounded); the binary
  frame codec (0x01–0x05) retires into frame types + payload
  vocabulary; the text/binary op asymmetry is erased (every op, both
  encodings).
- **Lanes ruled by role (L165):** doc BODIES ride **ast_bin** (lossless
  parse-AST — content addresses stay byte-exact); verb ENVELOPES ride
  **text canonical CX** (the fabric ruling generalized: data-bin never
  carries verb trees). Cross-encoding parity survives as a profile
  obligation. Addresses: tagged text forms in envelopes, **varint
  multihash in binary fields** with the normative bijection
  (crypto-agility lands here, not in dying CSRP).
- **Errors are NUMERIC, registered (L166):** the profile allocates
  **CXER5000–5049** (verified free above all current bands; the
  registry gains its rows in the same PR per #717 discipline); the
  generic layer's symbolic `CXER-XSP-*` codes get numeric allocations
  (closing divergence 11); the CSRP `17xx` band is marked
  Reserved/retired at retirement, never reused.
- **The parity gate (L167):** one daemon, three listeners (CSRP during
  transition, gRPC, the profile), same fixtures — op-for-op
  equivalence, ERROR IDENTITY, byte-identical content addresses,
  identical stream result sets; plus discriminator fixtures for what
  CSRP structurally cannot do (mid-iter cancel, credit exhaustion,
  resume-after-reconnect, ∂ deltas). The known parity debts close AS
  PART of the gate; the gRPC adapter re-bases onto the profile
  pipeline (it keeps synthesizing internal ops, not CSRP requests).

### §4.1. The op vocabulary (v1 — shipped at I5 W3)

Attach is XSP-AUTH on stream 0 (the fabric responder shape): the server
offers `profiles="store"` + its semantic feature set inside the signed
transcript (§3); the M3 `[attach [tenant "<store-name>"]]` routes to the
named mount (absent tenant = the sole mount; ambiguous or unknown =
`CXER5013`). Post-attach, every verb is ONE text-canonical envelope in a
`request` frame, answered on its stream-id; the §4.8 principal-demotion
rule applies unchanged (mismatch = the identity model's
`CXER-XSP-AUTH-PRINCIPAL-MISMATCH`, verbatim). A `binary=true` verb
frame is refused (`CXER5011`) — the fabric lane ruling, generalized.

**Lane concretions (L165 made byte-precise):**

- **Doc addresses in envelopes are tagged text** (`sha2-256:<hex>` —
  the Tier-1 store key form, already self-describing).
- **Doc bodies ride framed ast_bin** (the whole parse-AST document),
  imaged in the text envelope as a `::bytes` field in canonical
  lowercase-hex form (`[body::bytes 0x…]`). Content addresses stay
  byte-exact because the ast_bin round-trip reproduces the exact
  canonical text the address hashes.
- **Object-wire addresses are varint-multihash bytes fields**
  (`h::bytes=0x1220…` — `uvarint(code) ‖ uvarint(len) ‖ digest`, the
  crypto-agility bijection LIVE on this wire): self-describing,
  algorithm-agile, and refused fail-closed on an unregistered code or
  a length mismatch. Object payload bytes ride `[bytes::bytes 0x…]`.
- Envelope fields are flat single-scalar attrs/children wherever the
  shape allows (the W2 shape rule, applied profile-wide); batch ops
  carry one record element per item (`[o …]`/`[r …]`/`[k …]`/`[a …]`).

| Verb | Request envelope | Reply / stream |
|---|---|---|
| `capabilities` | `[capabilities]` | the profile capabilities advert (same truth as the §8 bootstrap surface); from W5 it RESTATES the §7a advert's `generation=` and `[guarantees …]` — two surfaces, one truth, so a client that missed the push can query |
| `get` | `[get hash="…"]` | `[doc hash= present=true [body::bytes 0x…]]`; absence is DATA: `present=false`, never an error frame; a lawfully erased doc answers the typed `[erased …]` tombstone VERBATIM (§7b) — never `present=false` |
| `put` | `[put [body::bytes 0x…]]` | `[put-result hash= stored=]` (`stored=false` = content-dedup hit) |
| `put-blob` | `[put-blob [bytes::bytes 0x…]]` | `[put-blob-result key= stored=]` — the F1' OPAQUE-document write (identity = hash of the RAW bytes, byte-exact round-trip; write-class). [ADDED 2026-08-08 under **RULED: F1'+F3+R1.1(b)**: the store surface's verbatim pair (store.md §4, F1') was missing from THE wire — measured: a remote put-blob wrote only the client's local mirror, so the §4.3 fn-document carriage had no transport. The profile must be the COMPLETE store wire (R1.1); the pair mirrors the embedded surface exactly.] |
| `get-blob` | `[get-blob key="…"]` | `[blob key= [bytes::bytes 0x…]]` — byte-exact, re-verified key == hash(raw) on load; an absent key answers the embedded surface's `CXER1121` VERBATIM (the F1' fixtures pin absent-blob as an error, unlike `get`'s absence-is-data — op-for-op parity keeps each surface's own contract); read-class |
| `delete` | `[delete hash="…"]` | `[delete-result hash= deleted=]` |
| `erase` | `[erase hash="…" authority=? request=?]` | `[erase-result hash= erased= deduped=?]` — the doc-level lawful shred (§7b): destroys the doc entry AND records the attributed `[erased …]` tombstone; `delete`-class capability; the actor is ALWAYS the session principal (never client-asserted); idempotent — re-erasing answers `deduped=true`, never a second destructive act |
| `modify` | `[modify hash="…" [action …]]` | `[modify-result old-hash= new-hash= stored=true]` |
| `list` | `[list window=W?]` | credit-governed `event` stream — one `[hash "…"]` per doc, then eos |
| `iter` | `[iter window=W?]` | `event` stream — `[doc hash= [body::bytes 0x…]]` per doc, then eos |
| `query` | `[query path="…" window=W?]` or `[query comp="…" window=W?]` (`path=`/`comp=` mutually exclusive; both absent or both present = `CXER5011`-class wire fault) | `event` stream. `path=`: one `[result doc= source= …]` tuple per **match** (the L97 flat provenance-bearing relation, `store.md` §6.2, carried verbatim from the executor), then eos. `comp=` (stream-2 ruling L99): the QUOTED planar comprehension's SOURCE TEXT — the server parses, applies the §7.8 membership gate (typed `CXER0120` rides the error frame verbatim) and BOTH server-side authorization layers, binds every FORMAL source-ref handle name to **the served store** (the same contract as local execution; a journal source refuses `CXER1709`), executes sandboxed, and streams the comprehension's own relation one top-level item per frame — each row inside an `[item [body::bytes 0x…]]` envelope riding FRAMED ast_bin (the doc-body lane: rows are TYPED nodes, byte-exact end-to-end — a text lane would collapse scalar rows to text; the client unwraps) — then eos |
| `objects-have` | `[objects-have [o h::bytes=…]…]` | `[have-result [o h::bytes=…]…]` — the MISSING addresses only (the dedup-on-wire primitive) |
| `log` | `[log]` | `[log-result [advance epoch= plane= kind= key= pos= root?= hash?=]…]` — the E3 advance log (stream 9: the peer-lineage read the wire reconcile/classify/status-peer consume; read-only; the porcelain `log` builtin is the one producer — no second shape) |
| `objects-get` | `[objects-get [o h::bytes=…]…]` | `[get-result [o h::bytes=… [bytes::bytes 0x…]]…]` — absent objects omitted; each object self-verifies; an address that was the root of a lawfully erased doc answers `[o h::bytes=… erased=true]` (§7b — the discriminator survives the object wire; `objects-have` keeps counting it MISSING, since it cannot be fetched) |
| `objects-put` | `[objects-put [o h::bytes=… [bytes::bytes 0x…]]…]` | `[put-result stored=N]` — the server VERIFIES each claimed address against the bytes and refuses a mismatch (`CXER5017`), never trust-the-label |
| `refs` | `[refs [k key="…"]…]` | `[refs-result [r key= present= root::bytes=?]…]` — explicit per-key presence |
| `refs-set` | `[refs-set [r key= root::bytes= expect::bytes=?]…]` | `[refs-set-result set=N]` — validate-then-apply, ALL-OR-NOTHING; conflict = `CXER1114` verbatim (`expect::bytes=0x` = must-not-exist; absent expect = unconditional) |
| `aliases` | `[aliases all=true? [k name=]…]` | `[aliases-result [a name= present= hash=?]…]` — explicit presence, never a silent empty |
| `aliases-set` | `[aliases-set [a name= hash= expect=?]…]` | `[aliases-set-result set=N]` — same CAS calculus on the alias pointer layer (`CXER1114`; target-presence faults verbatim `CXER1121`) |
| `status` | `[status]` | the porcelain `[status …]` element, verbatim |
| `gc` | `[gc]` | the porcelain `[gc-result …]` element, verbatim |
| `mounts` | `[mounts]` | daemon-level: the `[mounts …]` advert |
| `config-reload` | `[config-reload]` | daemon-level: the `[config-reload …]` report (§3.13 refusal codes verbatim) |
| `session` | `[session]` | `[store-session features= liveness-ms= pending-window= …]` — §5.0 surface 2: RESTATES the transcript-confirmed set, never extends it |

**Stream mechanics (`list`/`iter`/`query`):** the request MAY declare
`window=W` (W ≥ 1; a bad window is `CXER5011`); undeclared = unbounded
(the pre-§5 posture). Results ride `event` frames on the REQUEST's
stream-id, one item per frame, each decrementing one credit; at zero
the server stops pushing until a `credit` frame (type 8,
transcript-negotiated) replenishes. The stream terminates with a final
`event` frame carrying the eos flag and `[eos count=N]`
(`cancelled=true` after a client `cancel` frame); an empty result set
is a bare eos with `count=0`. A mid-stream fault terminates with an
`error` frame instead (no eos after an error). ∂ frames are NEVER
coalesced (§5) — one result, one frame.

**Error transparency:** op-layer faults cross the wire VERBATIM — the
store's own `CXER11xx` codes, the one ref-conflict code `CXER1114`,
the journal's `CXER46xx` (journal-over-profile) — never remapped onto
a transport band. The CSRP `17xx` remapping is precisely the
two-vocabulary drift this profile retires; the `CXER5000–5049` band
below covers only what the PROFILE itself can refuse.

**Authorization (W4, §6.1):** attach authenticates (XSP-AUTH;
anonymous initiators admitted only under a configured floor). With
`[grants …]` configured the session carries a VC-compilable authority
basis and EVERY verb is PEP-checked (deny-by-default; the `[deny …]`
value rides verbatim). Without grants the data plane keeps the open
dev posture and the daemon-level admin verbs (`mounts`,
`config-reload`) keep the `CXER5018` mutual gate — the one W3 interim
surface, now scoped to open mode only.

### §4.2. Error rows — the `CXER5000–5049` registry (L166, #717)

Landed with the W3 implementation (the governance §9.6 band row points
here). Sub-block `5000–5009` is the GENERIC frame/session layer's (the
numeric allocations for the retired symbolic `CXER-XSP-*` spellings —
the cutover is total, no dual-accept); `5010+` is the store profile's.

| Code | Symbolic | Meaning |
|---|---|---|
| `CXER5000` | `E_XSP_VERSION` | unknown frame version byte |
| `CXER5001` | `E_XSP_TRUNCATED` | buffer shorter than the frame declares |
| `CXER5002` | `E_XSP_TYPE` | unknown frame type byte; un-negotiated type at a pre-§5 peer |
| `CXER5003` | `E_XSP_LENGTH` | payload over the 2^32−1 ceiling / principal over 2^16−1 |
| `CXER5004` | `E_XSP_PAYLOAD` | payload codec failure (data-bin emit/parse) |
| `CXER5005` | `E_XSP_FLAGS` | reserved flag bits 2–7 set (MUST be 0 in v1) |
| `CXER5006–5009` | — | reserved (generic layer growth) |
| `CXER5010` | `E_XSP_STORE_ATTACH` | handshake state: verb before attach, prove without hello, unknown phase |
| `CXER5011` | `E_XSP_STORE_WIRE` | malformed verb envelope; wrong lane (binary verb frame); bad `window=` |
| `CXER5012` | `E_XSP_STORE_UNSUPPORTED` | unknown verb on an established channel |
| `CXER5013` | `E_XSP_STORE_MOUNT` | attach names no resolvable store mount |
| `CXER5014` | `E_XSP_STORE_CREDIT` | invalid credit frame (grant < 1; unknown or foreign stream) |
| `CXER5015` | `E_XSP_STORE_INTERNAL` | server-internal fault |
| `CXER5016` | `E_XSP_STORE_BODY` | body lane violation: bad `::bytes` image, ast_bin decode failure |
| `CXER5017` | `E_XSP_STORE_ADDRESS` | address violation: untagged/unregistered/malformed multihash; `objects-put` content↔address mismatch |
| `CXER5018` | `E_XSP_STORE_ADMIN` | daemon-level verb refused for a non-mutual principal — OPEN MODE ONLY (no `[grants]` configured); under grants the PEP owns admin and this row never fires (W4) |
| `CXER5019` | `E_XSP_STORE_FEED` | malformed/refused feed subscribe: unknown plane, unknown or undeclarable rung, malformed `[from …]` cursor, `bodies=true` without the confirmed `store-delta` token |
| `CXER5020` | `E_XSP_STORE_CURSOR` | resume cursor outside the retained lineage — an epoch token this lineage never issued, a position below a stream's retention floor, or a position above its head (the `:gapless`-class honest refusal — re-seed, never silent divergence; RULED: FL-1 #764) |
| `CXER5021` | `E_XSP_STORE_AUTHORITY` | presentation fault: `[vp]` on a floor session, malformed `[vp]`, a bound conjunct this surface cannot meter (`spend` at v1) |
| `CXER5022` | `E_XSP_STORE_PEER` | peer-surface refusal: the `revocations` plane subscribed without the transcript-confirmed `peer` token, under the open posture (the peer capability is deny-by-default — it has NO open-mode exception, §7.1), mixed with data planes, or on a daemon that designates no revocations journal |
| `CXER5023` | `E_XSP_STORE_PUSHDOWN_CLAIM` | computation-identity claim mismatch on a pushdown fn: the daemon's recomputed `computes-as:` value over the fetched entry def ≠ the request's `claim=` (§4.3 — tamper / version-skew guard, F3) |
| `CXER5024` | `E_XSP_STORE_PUSHDOWN_BUDGET` | daemon-side evaluation budget exceeded (§4.3, F4): carries `[conjunct :steps\|:memory]` and the configured limit — a loud typed refusal, NEVER a daemon takedown; the journal and store stay untouched |
| `CXER5025` | `E_XSP_STORE_PUSHDOWN_FN` | pushdown fn violation: the fetched document does not parse as a program of `[?def]`s, `entry=` names no def (or is absent with more than one def), or the selected def is not a callable of the verb's arity |
| `CXER5026–5049` | — | reserved |

### §4.3. The journal pushdown verb family (feature token `store-journal` — S6, RULED: F3+F4+F5+R1.1(b), register 2026-08-08)

For journals whose logs dwarf their queries, the journal §3 verbs run
DAEMON-SIDE as profile payload verbs — the [journal.md](../std-lib/journal.md)
§6.1 growth path, now normative. The family is gated by the
transcript-confirmed **`store-journal`** feature token (it changes verb
vocabulary, so it is transcript-bound per §3; a family verb without the
confirmed token refuses `CXER5012`). Every verb names its journal by
`tenant=` (the journal tenant within the attach-bound mount — the
tenant confinement of journal §4.1 carries over: the SESSION's mount is
the boundary, the verb's `tenant=` selects a partition inside it) and
takes the same defaulted `stream=` the local surface takes (§2.1.1;
default `:default`).

**The fn carriage (F3a).** A fold/replay/dry-run reducer crosses the
wire as the **def DOCUMENT, by document address, over the existing
object wire** — no special function carriage exists:

- The client stores the def source as an OPAQUE document (`put-blob` —
  raw-byte identity) and names it in the verb: `fn="sha2-256:…"` (the
  tagged blob address). The daemon fetches it through the SAME
  verifying read path every blob load uses (key == hash(raw bytes)).
- The request carries a MANDATORY computation-identity CLAIM:
  `claim="computes-as:<algo>:<hex>"`. The daemon parses the fetched
  document as a PROGRAM, resolves the entry def, recomputes
  `[$cx:computation-id]` over it, and REFUSES on mismatch
  (`CXER5023`). A missing/malformed claim is `CXER5011`.
- **A dependency closure is more documents — a module IS one
  document:** the blob may parse to several `[?def]`s; `entry="name"`
  selects the reducer (required when the program holds more than one
  def; unresolvable → `CXER5025`). The claim covers the ENTRY def as
  parsed; the helper defs are covered by the document's raw-byte
  identity, which the daemon verified on load.
- Purity is enforced SERVER-SIDE with the same check the local surface
  applies — an impure reducer refuses `CXER4611` verbatim (error
  transparency; identical error identity both sides).

**The evaluation budget (F4a).** EVERY daemon-side evaluation runs
under an operator-configured **step limit** and **memory ceiling**
(`[xsp [limits [pushdown steps=N memory-mb=M]]]`; both have named
defaults; only positive numerics are spellable — an unbounded budget
cannot be written). Exceeding either is the loud typed refusal
`CXER5024` with `[conjunct :steps|:memory]` and the configured limit —
never a daemon takedown, and never a partially-applied effect (the
family is read-only against the journal). Pushdown evaluations
serialize under the mount's op lock (the standing store discipline),
which is also what makes the memory meter attributable to ONE
evaluation. Per-principal DELEGABLE budgets (a `[bounds]` conjunct)
are a later layer riding the §6 authority model — deliberately not
built at v1 (F4a).

**Signing custody (F5b).** `snapshot` is NOT a wire verb — the signing
key never travels: the daemon serves the reconstruction state over
this family and the object wire, and the client (or the APPOINTED
SIGNER, below) computes and signs the checkpoint locally.
`snapshot-verify` is a public-key check and IS pushdown-safe. S6.4: a
signed snapshot MAY carry the **unsigned outer `signer="<did>"` hint**
(journal §4.8 — outside the frozen preimage, bound by the signature:
the verify key resolves FROM it, so a forged `signer` fails the crypto
check); `journal-snapshot-verify` resolves the hint as part of the
SAME pure check — the verb takes no new fields, consults **no
authority state**, and is unchanged on the wire. Appointment
enforcement (journal §3.7 `opts.require-appointed`) is the CALLER's
separate check against the `snapshot-sign` row (§6.1) — never this
verb's.
**Appointed signer:** an organization may delegate snapshot-signing to
a designated signer principal through the existing credential model —
the capability row `snapshot-sign` (§6.1), one row, no new machinery
(generalizes to threshold signers later). Appointment changes WHO may
sign, never WHERE the key lives. Daemon self-attestation is NOT
specced (F5b: if ever wanted, it is a distinct, explicitly-named
attestation type).

**The verbs** (envelopes per the §4.1 lane rules — flat single-scalar
fields, entry/doc bodies as framed ast_bin `::bytes`, journal error
codes `CXER46xx` verbatim):

| Verb | Request envelope | Reply / stream | Class |
|---|---|---|---|
| `journal-read` | `[journal-read tenant= seq= stream=?]` | `[entry-result present= [body::bytes 0x…]?]` — absence is DATA (`present=false`), mirroring `get`; `seq < 1` = `CXER4610` verbatim | read |
| `journal-slice` | `[journal-slice tenant= from= to= stream=? window=?]` | credit-governed `event` stream — one `[entry [body::bytes 0x…]]` per entry in seq order, then `[eos count=N]`; empty window = bare eos (the §2.5 absence channel); `from > to` = `CXER4610` verbatim | read |
| `journal-since` | `[journal-since tenant= from= stream=? window=?]` | `event` stream, same shape as `journal-slice` (the tail from `from` to head) | read |
| `journal-query` | `[journal-query tenant= path="…" window=?]` | `event` stream — matches across ALL streams, grouped by stream then seq (the §3.3 rule) | read |
| `journal-verify` | `[journal-verify tenant= stream=? from=? to=?]` | the `[verification …]` value VERBATIM — a `valid=false` is a FINDING (data), never an error frame (§2.5/§3.6) | read |
| `journal-verify-slice` | `[journal-verify-slice tenant= from= to= stream=?]` | same, anchored at `from−1` (§3.6) | read |
| `journal-snapshot-verify` | `[journal-snapshot-verify tenant= [snapshot::bytes 0x…] stream=?]` | the `[snapshot-verification …]` value verbatim (public-key + anchor check — pushdown-safe, F5b) | read |
| `journal-fold` | `[journal-fold tenant= stream=? fn= claim= entry=? [init::bytes 0x…]]` | `[fold-result [state::bytes 0x…] entries=N to-seq=M]` | compute |
| `journal-fold-slice` | `[journal-fold-slice tenant= from= to= stream=? fn= claim= entry=? [init::bytes 0x…]]` | `[fold-result …]` over `from..to` only | compute |
| `journal-replay` | `[journal-replay tenant= stream=? fn= claim= entry=? [init::bytes 0x…] from=? to=? at-seq=?]` | `[replay-result [state::bytes 0x…] entries=N to-seq=M]` — the §3.5 time-travel options as attrs | compute |
| `journal-dry-run` | `[journal-dry-run tenant= stream=? fn= claim= entry=? [init::bytes 0x…] [event::bytes 0x…] [attribution::bytes 0x…]]` | `[dry-run-result [state::bytes 0x…] [provisional-entry::bytes 0x…]]` — NOTHING persists (§3.5) | compute |

**Deliberately NOT wire verbs:** `append` and the pointer moves ride
the shipped object-wire carriage (journal §6.1 v1 — the daemon-side
alias CAS is already the serialization point); `head` is a pure cached
read on the client handle (and the head alias is one `aliases` read);
`streams` enumeration rides the existing `aliases` verb (stream keys
are derivable from the per-stream alias names); **`fold-value` is
client-eval ONLY** — it is pure over ALREADY-MATERIALIZED entries
(§3.4), so a wire form would ship the data TO the compute, inverting
the pushdown rationale (posed and accepted under the standing
acceptance ruling — see the ledger, S6 letter J1); `snapshot` per the
F5b custody rule above; `retain`/`compact`/`fold-from` are the
owner-side maintenance surface, out of the v1 family (they ride the
object wire as today).

**Authorization.** The read-class rows above require the `read`
capability (they expose exactly what `get`/`iter` over the same mount
expose); the compute-class rows require **`compute`** (§6.1) — a
DISTINCT grant, because they run client-supplied code on the daemon;
`read` alone never admits an evaluation, and `compute` does not imply
`write` (the family is read-only). Under the open posture (no
`[grants]`) the family follows the data plane's open rule, budget
still enforced — the budget is an operator resource bound, not an
authority decision.

**Parity obligation (R4.4a-revised).** Every family verb joins the G13
lanes with the LOCAL EMBEDDED ENGINE as the correctness oracle:
op-for-op equivalence of pushed-down vs client-eval over the same
journal (identical state bytes, identical computation-identity hash,
identical `CXER4610/4611` error identity), across both listeners (XSP
profile; gRPC edge via `pipeline="profile"` synthesis).

## §5. The change feed and ∂ frames (L168)

The feed is the profile's CARRIAGE of stream subscriptions
([`delivery.md`](../core/delivery.md) §3; RULED: U1.1a–U1.15a) — a transport,
not a delivery mechanism of its own. Its `[feed-sub …]` satisfies the
delivery.md §4 subscription contract; its head-set is THE multi-stream
cursor form (delivery.md §5), of which fabric's per-stream scalar seq
is the degenerate single-stream form — one doctrine, two contexts,
not two vocabularies.

The profile carries **ref-advance and doc-put notification
subscriptions** (stream 3's formal requirement, discharged): a feed
subscription declares its ladder rung (`:complete-ordered` —
ref-advance order per the fixed `store:log`/E3 lineage, the named
prerequisite); its **resume cursor is a HEAD-SET map** (the session
layer's resume text gains the map form beside fabric's scalar seq);
∂ deltas ride `event` frames as `[insert|retract|regroup]` data
elements — credit-governed, **never coalesced**, `eos`- or
`error`-terminated, per-frame redaction counts riding along.

### §5.1. The lineage substrate (E3 on this wire — shipped at I5 W4)

Every mount keeps the **per-ref advance lineage** (the semantic value
model's E3): each named ref — object-graph store keys (`refs-set`) and
aliases (`aliases-set`), the closed v1 ref scope — has a **dense,
gap-free position**; `pos=17` IS "the 17th advance of that ref"
(`branch-force` advances appear; re-pointing a ref at its current
target is an advance). The **doc plane is one more feed stream**:
doc-put/doc-delete events carry a dense per-mount doc-plane position.
The fixed `store:log` (#708 — per-ref advance order, closing the
insertion-order divergence) and the wire feed read **one log**; the
local porcelain and the remote subscription can never disagree.

A **HEAD-SET** is the map stream → position, one entry per stream, and
carries the **epoch token** (the wire attribute stays `boot=` — the
shape is unchanged) — the retention-boundary marker positions are
relative to:

`[head-set boot="<token>" [s plane="docs" pos=N]
[s plane="refs" name="head" pos=N] [s plane="aliases" name="latest" pos=N]]`

There is deliberately no cross-stream total order (the cursor is a
map, never a scalar — the live-modes L131 rule); within a stream,
position order IS delivery order.

**Durable lineage (RULED: FL-1, #764; extended to s3-rooted stores,
RULED: FL-2, #885; completed on the columnar substrate, RULED: FL-3,
#887).** On every durable substrate the data-plane lineage is DURABLE:
each act also lands, at write time and append-ordered, in a persistent
lineage medium beside the store's state. Restart-safe resume is NOT
substrate-dependent — there are exactly two lineage media and a
substrate joins the contract by mounting on one of them, never by
growing its own. Where the store has a local root (`file` document
model, pack, object-per-key, sqlite, and a columnar store over a local
file) that medium is the append-ordered sidecar log beside the state.
Where the store lives behind an object transport with no append
primitive it is a family of small objects under a key prefix: each act
is PUT as one segment object under a monotonic name, over a
per-generation base object holding the compacted story; compaction
writes the next generation's base before purging the old one, and boot
trusts the highest generation with a base (the generation guard). Two
stores mount that medium: an `s3`-rooted subtree store, whose lineage
keys sit beside its manifest at the bucket root; and a columnar store
hosted as a single object, whose lineage keys sit beside THAT object —
as its alias sidecar does — so several columnar stores in one bucket
keep separate lineages by construction. Names are minted by the one
daemon that owns the store — the substrate's existing single-writer
write model (the refs manifest is already an unconditional snapshot
PUT; a columnar store rewrites its whole object on every flush) — so
appends need no read-modify-write and no conditional PUT. Either way
the epoch token is minted once and persisted, and a verified boot
reload restores epoch, retention floors, and positions — so positions
are stable across daemon restarts and strictly monotonic per stream,
forever, and a valid prior-boot resume cursor RESUMES. The boot reload
verifies before it trusts (epoch intact, per-stream density above the
floors, the retained acts' fold agreeing with the loaded snapshot);
anything torn or inconsistent is discarded and the store seeds
compacted-from-snapshot under a FRESH epoch — the pre-FL-1 behavior,
which remains the story for a store with no persisted lineage (first
boot, upgraded store, a bucket or columnar object written before this
landing) and for substrates with nothing durable to keep (`mem://`
loses the store itself at exit; remote-proxy mounts keep no local
lineage).

**Retention is explicit and bounded**: when the sidecar accumulates
redundancy (records > 2 × live entities + 64 — the index log's own
compaction heuristic) it is rewritten as the state-compacted story (the
latest act per live entity, erase evidence included — attribution
survives compaction) at the acts' ORIGINAL positions, and each stream's
**retention floor** rises to its highest compacted-away position; above
its floor every stream stays dense (floor+1 … head, gap-free). A resume
cursor is refused loudly (`CXER5020`, the `:gapless`-class honest
refusal — the client re-seeds), never served silently divergent,
exactly when gapless resume is impossible: an epoch token this lineage
never issued, a position below a stream's retention floor, or a
position above its head (a position this lineage never issued). The
signed head-set advert is §7a's.

### §5.2. The `feed` verb (feature token `store-feed`)

| Verb | Request envelope | Reply / stream |
|---|---|---|
| `feed` | `[feed rung=":complete-ordered"? bodies=true? window=W? [planes "docs refs aliases"]? [from [s plane= name=? pos=]…]?]` | `[feed-sub rung=":complete-ordered" [head-set …]]`, then an `event` stream of §5.3 notifications on the REQUEST's stream-id |

- `feed` is transcript-gated: a peer that did not confirm `store-feed`
  gets `CXER5012` (un-negotiated use is loud, §3). `bodies=true`
  additionally requires the confirmed `store-delta` token (∂ payload
  carriage) — without it, `CXER5019`.
- **Rung:** the store feed declares `:complete-ordered` (the CDC top
  rung — the store is its own change source; one declaration
  mechanism, stream 7's). A subscription MAY state the rung it
  requires; an unknown or undeclarable rung atom is `CXER5019` at
  subscribe (refuse-to-lie at wiring time, never a silent downgrade).
- `[planes …]` filters the subscription (default: all three data
  planes). From W5 a FOURTH plane exists: `revocations` — the peer
  channel (§7). It subscribes ALONE (mixing it with data planes is
  `CXER5019`), requires the transcript-confirmed `peer` token AND the
  deny-by-default `peer` capability (§7.1; refusals are `CXER5022`),
  and its positions are the designated revocations journal's seqs —
  DURABLE, so a `[from [s plane="revocations" pos=N]]` cursor is
  epoch-EXEMPT (it was the durability precedent: since FL-1 the three
  data planes are durable too, but their cursors carry the epoch token
  per the rule below — the revocations journal's seqs need none).
- **Anchor/resume:** absent `[from]` = tail from the current head —
  the reply's `[head-set …]` IS the anchor. A present `[from …]`
  resumes: every retained entry **strictly above** the given positions
  replays in per-stream position order, then the subscription goes
  live; a stream absent from the map replays from its beginning.
  A `[from …]` carrying any `[s …]` entry MUST present the head-set's
  `boot="…"` token — positions are relative to the retention boundary
  it names. Since FL-1 (#764) the token is the durable EPOCH token on
  the local durable substrates, so a cursor from a previous daemon boot
  RESUMES; `CXER5020` (outside the retained lineage, §5.1) refuses
  exactly the cursors gapless resume cannot honor — wrong epoch, below
  a retention floor, above a head — never served silently divergent.
  An EMPTY `[from]` (no entries) is the full replay of the retained
  (state-compacted) story and needs no token (it asserts no
  positions).
- **Flow:** §4.1 stream mechanics verbatim (window/credit; control
  frames never consume credit). A feed has no natural end: it
  terminates by `cancel` (terminal `[eos cancelled=true]`), connection
  teardown, or a mid-feed fault (`error` frame, no eos after error).

### §5.3. Notification shapes (∂ on this wire)

- doc put → `[insert plane="docs" pos=N hash="…" [body::bytes 0x…]?]`
  (the body child only under `bodies=true`; the §4.1 get-lane rules)
- doc delete → `[retract plane="docs" pos=N hash="…"]`
- doc ERASE → `[erase plane="docs" pos=N hash="…" at= actor= authority=?
  request=]` — a lawful shred is a DISTINCT act (never a retract: the
  delete/erase discriminator must survive the wire, §7b); the
  attribution rides in the notification because the shred-request IS
  journal data on this feed (each replica executes its OWN local shred
  from it, with its own report — no remote reach-in)
- revocation (the `revocations` plane, §7) →
  `[revoke plane="revocations" pos=N vc-id="…"]` — `pos` is the
  revocations journal seq (durable, resumable across boots)
- ref advance → `[advance plane="refs" name="…" pos=N root::bytes=0x…]`
  — E3 positions on every notification (ahead/behind is computable,
  never inferred — the distributed-store L178 requirement)
- alias advance → `[advance plane="aliases" name="…" pos=N hash="…"]`;
  alias delete → `[retract plane="aliases" name="…" pos=N]` (an act,
  in the history — it consumes a position)
- **Never coalesced:** one event, one frame — a burst of N puts is N
  `insert` frames (the discriminator fixture); each event decrements
  one credit.
- **Per-frame redaction counts:** any feed frame that OMITS entries
  for erasure reasons carries `redacted=K` (the erasure/compliance
  visible-count rule: count + attribution, in the value, at the point
  of omission; K=0 is implicit — the attribute is absent). The first
  producer (shipped at W5): a `bodies=true` REPLAY of an `insert`
  whose doc has since been lawfully erased delivers the insert frame
  with the body omitted and `redacted=1` — the attribution is one
  `get` away (the tombstone). A merely-DELETED doc's replayed insert
  stays silent-bodyless (its retract follows in-stream — deletion is
  not redaction).
- A fault mid-feed terminates the subscription with an `error` frame
  carrying the fault verbatim (a query err is a fault, not a finding).

## §6. Authority: one model + bounds carriage (L169)

The four-provider stack, role bundles, and tenant string-lists RETIRE
whole. Attach is XSP-AUTH (mutual, channel-bound, transcript-signed);
authority is VC-compiled capability values; the store's `DidGrant`
table becomes ordinary delegations. **Bounds carriage (stream 6's
fourth dimension):** `[bounds [rate…][count…][spend…]]` rides the VC
chain as a fourth ⊆-checked attenuation axis beside
capabilities/slice/window, presented in the M3 `[attach]` or a later
`phase=present`; the meter names its stream (per-stream v1);
exhaustion crosses the wire as the `[deny …retry-after…]` value
(CXER4713); D-C1's independent-conjunct rule holds on the wire
(denial names the failing conjunct).

### §6.1. The listener model (shipped at I5 W4)

- **Grants config → root delegations.** The `[xsp]` section gains
  `[grants [grant did="…" caps="read write delete admin" over=?]…
  [grant floor=true caps="read"]?]`. At attach, each matching grant
  compiles to an ordinary `[delegation …]` (issuer = the daemon's
  inherent authority, subject = the session principal) in the
  SESSION's authority basis — a per-session `authz` store, the one
  decision function (`authz.md` §3.4) deciding every verb. This is
  the `DidGrant` table become ordinary delegations: same operator
  intent, ONE calculus (attenuation, revocation, explain for free).
- **Enforcement posture:** a config WITH `[grants …]` is
  deny-by-default — every verb is PEP-checked, and the PEP's
  `[deny …]` value crosses the wire VERBATIM in an `error` frame
  (`CXER4700`-band — error transparency, §4.1). A config with NO
  grants section keeps the W3 open posture (data verbs open; the
  daemon-level admin verbs keep the `CXER5018` mutual gate, re-scoped
  to open mode only — under grants, the PEP owns admin and `5018`
  never fires). The same posture rule the daemon's `[auth]` section
  has always had: absent = open dev mode, present = enforced.
- **The capability grammar (v1)** is the op-class table — the four
  classes CSRP enforced, kept class-for-class for the W7 parity gate,
  plus W5's fifth: `read` (get list iter query objects-have
  objects-get refs aliases capabilities session feed), `write` (put
  modify objects-put refs-set aliases-set), `delete` (delete erase —
  an erase is delete-grade authority; its extra weight is carried by
  attribution, not a class), `admin` (status gc mounts config-reload),
  and `peer` (the `revocations` feed plane, §7 — deliberately NARROWER
  than `read`: a peer daemon receives revocations without holding read
  on the data planes). S6 (RULED: F3+F4+F5) adds two rows: `compute`
  (the §4.3 compute-class pushdown verbs — a DISTINCT grant because
  they run client-supplied code on the daemon; never implied by `read`,
  never implying `write`) and `snapshot-sign` (the F5b appointed-signer
  row: the holder may produce signed journal checkpoints for the
  granted scope — it governs WHO may sign; the signing key never
  travels regardless). `[over /path]` slices apply to `query`/`get`
  scopes per the authz slice calculus.
- **VC presentation** (identity model §5, the only path from
  credential to enforceable capability): a presentation rides the M3
  `[attach …]` or a post-attach control message
  (`[xsp-auth phase=present …]` on stream 0) — in BOTH carriages as a
  **single-scalar text field**: `[vp "<canonical [vp [vc …]…] text>"]`.
  The nested-element form is UNSOUND twice over: M3 is
  transcript-signed and a nested child does not atomize (the §4.4a
  shape rule — fresh and decoded forms would sign different
  transcripts), and data-bin is lossy on element/attr duality (the
  L165 lane ruling), so a `[vc …]` crossing it re-canonicalizes
  differently and its SIGNATURE dies. Signed content rides the
  lossless lane; canonical text in a string field is that lane. The handshake is the
  proof of possession — the chain's terminal subject MUST be the
  session principal byte-for-byte (`CXER-XSP-AUTH-SUBJECT` verbatim);
  floor (anonymous) sessions cannot present (`CXER5021`). Each link
  verifies per `vc.md` §4/§6; the chain walks issuer→subject with
  STRICT attenuation — capabilities/slice/window/bounds, all four
  axes ⊆-checked (`CXER4703` verbatim on escalation); a root issuer
  this deployment does not recognize compiles to NOTHING (inert,
  logged, reported in the presentation reply — never conjured
  authority, N-TRUST-1); a cross-tenant delegation is a FAULT
  (`CXER4805` semantics), not inert. The presentation reply is
  `[presented compiled=N inert=K]` — visibility without leaking the
  deployment's grant table.
- **Bounds meters (per-stream v1):** the meter's serialization point
  on this wire is the session (one attach, one mount, ops serialized
  under the mount's op lock — the commit lock). Debit happens at the
  verb commit point under that lock; `rate` = token bucket, `count` =
  monotone (no replenishment; refunds never credit back). A bound
  conjunct this surface cannot meter (`spend` at v1 — no store verb
  debits an amount) REJECTS the presentation fail-closed (`CXER5021`)
  — a bound that cannot be enforced is never silently void.
  Sub-delegations SHARE the issuer's meter by default (a pool never
  multiplies authority). Exhaustion crosses the wire as the
  `[deny [reason :budget-exhausted] [retry-after DUR]]` value,
  `CXER4713` — `retry-after` present for `rate` (the bucket refills),
  absent for `count` (it never does); denial names the failing
  conjunct (D-C1: a bound never widens scope, a scope never relaxes a
  bound).
- **Issue-time window ⊆ pinned:** the shipped authz calculus checked
  capabilities and slice at delegation time but expiry only at
  decision time — a child could name a LONGER `until` than its
  parent. The identity model's chain rule (§5.2: capabilities/over/
  window ⊆, strict) has always required the issue-time check; landing
  bounds as the fourth axis pins the third in the same change.
- **Revocation enforcement (shipped at W5, §7):** the daemon keeps ONE
  revoked-set, folded from its own designated revocations journal and
  from every peer subscription. Two enforcement points, both LOCAL:
  a presentation whose `[vc]` id is revoked REFUSES at present time
  (`vc-verify`'s `revoked` status, verbatim); a delegation ALREADY
  compiled from a since-revoked VC is REMOVED from the session basis
  at the next PEP check (each compiled record remembers its source VC
  id) — the worked example's "enforced locally at the next PEP check,
  never by remote reach-in", made mechanical. Live sessions are never
  torn down by a revocation; their authority narrows at the next
  decision.

## §7. The server↔server channel + revocation (L170 — D-XSP-c)

A **`peer` feature profile**: two daemons run mutual XSP-AUTH (both
principals are DIDs; `[host-auth mode="mutual"]`), gated by a
deny-by-default `peer` capability. **Revocation propagation is a
SUBSCRIPTION to the peer's revocations journal stream** — the §5 change
feed reused verbatim (credit, resume, at-least-once; eventual and
offline-tolerant exactly as vc.md 3b describes: only how `revoked-set`
is populated changes; `verify` is untouched). Compromise-window
announcements ride the §7 provenance value (`[claim
compromised-window]`) on the same channel. **The honor rule:** a peer's
revocations are honored only for VCs whose issuer the local deployment
recognizes (the chain-root rule's analogue). **No remote reach-in:**
announcements are folded locally, never commands — a peer cannot
terminate another's sessions. The convergence bound is stated
(resolver TTL + max-session-age + feed lag) and reported.

### §7.1. The peer model (shipped at I5 W5)

- **The peer channel IS the feed's `revocations` plane** (§5.2/§5.3)
  — no new subscription machinery: credit, cancel, resume, and
  at-least-once delivery are the §5 mechanics verbatim. Positions are
  the designated revocations journal's seqs (durable — the plane is
  boot-exempt, §5.2), so a reconnecting peer resumes exactly and a
  full replay from `pos=0` is idempotent (folding a revocation twice
  is a no-op).
- **Designation:** `[xsp [revocations journal="<tenant>"]]` names the
  mount's revocations journal. A daemon with no designation refuses
  the plane (`CXER5022`) — never an empty stream pretending to be the
  answer. The serving side folds the SAME journal into its own
  revoked-set (a daemon honors its own revocations without dialing
  itself).
- **Gate:** the plane needs the transcript-confirmed `peer` token
  (offered only by daemons that designate a revocations journal — a
  token that cannot be served is never offered) AND the
  deny-by-default `peer` capability. Deny-by-default means exactly
  that: under the open posture (no `[grants]`) the plane refuses
  `CXER5022` — the ONE surface with no open-mode exception, because
  its consumer is an unattended daemon, not a developer.
- **Outbound peering:** `[xsp [peers [peer url="xsp(s)://host:port"
  did="<peer-did>" tenant="<mount>"]…]]` — the daemon dials each peer
  as a mutual XSP-AUTH initiator under its own `[identity]`, pins the
  responder DID (`did=`), offers `peer` in its transcript, subscribes
  the `revocations` plane, and FOLDS arriving `[revoke …]` events
  into its local revoked-set. Dial failures retry with backoff — an
  offline peer is lag, never an error state (vc.md 3b's
  offline-tolerant posture).
- **The honor rule, structural:** a peer's revocation names a VC id;
  a revocation can only ever NARROW authority (fold = add to
  revoked-set; enforcement = §6.1's two local points), and authority
  only ever ARISES from chains whose root this deployment recognizes
  (§6.1 compilation). So a forged or foreign revocation can deny
  nothing this deployment ever granted — fail-safe by construction,
  which is also why the fold does not chain-verify the peer's journal
  entries (the dangerous direction, conjuring authority, has no path
  through this channel).
- **No reach-in + convergence:** folding is the ONLY effect — no
  session teardown, no command execution. The subscription reply
  reports the bound: `[feed-sub … [revocations tenant= head=N]
  [convergence feed-lag-ms= enforcement="next-pep-check"]]` —
  worst-case staleness = the producer's feed pump lag plus the
  consumer's next PEP decision (there is no resolver-TTL term at v1:
  did:key resolution is offline; and no max-session-age term: §6.1
  removes revoked-sourced delegations mid-session at the next check).

## §7a. The object wire + the generation-bound advert (ADDED 2026-08-05, audit C6 — stream 9's four L178 requirements, now ACTUALLY discharged here rather than claimed)

- **Object-wire op family, first-class:** `objects-have` /
  `objects-get` / `objects-put` / `refs` are profile ops with their own
  rows in the §4 vocabulary — request→reply verbs; object payloads ride
  **ast_bin** per the §4 lane ruling (content addresses stay
  byte-exact end-to-end); `objects-have` takes a batch of tagged
  addresses and answers a presence bitmap; `objects-put` is
  content-addressed (the server verifies the address against the bytes
  and refuses a mismatch — never trust-the-label); **batch `ref-set` is
  validate-then-apply, all-or-nothing** (stream 9's fourth
  requirement): any single CAS failure in the batch applies nothing
  and returns the per-ref conflict values.
- **The profile handshake advert is GENERATION-BOUND and carries the
  signed head-set coordinate + the guarantee set** (stream 9's third
  requirement AND stream 7's F3 MUST, both previously dangling): the
  M4-confirmed attach is followed by the profile advert
  `[store-advert generation=<config-gen> [head-set …signed…]
  [guarantees …]]` — the guarantee set is the consistency-vocabulary
  token set this surface satisfies, checked ONCE at declaration time
  (the handle/session floor), refused at open when the requested rung
  exceeds it; the advert **binds the config generation**, and a
  `config-reload` that changes the guarantee set MUST re-advertise —
  a cached advert across reload is a cached lie (F3). Ref-advance
  notifications carry E3 positions (ahead/behind computable, never
  inferred).

### §7a.1. The advert (shipped at I5 W5)

- **Shape and carriage:** immediately after the M4 reply, the server
  pushes ONE text `event` frame on stream 0:
  `[store-advert generation=<gen> [head-set boot=… [s …]…]
  [guarantees "<canonical sorted tokens>"] signer="<daemon-did>"
  sig-algo=":ed25519" sig="<hex>"]`. The signature covers the
  canonical text of `[store-advert-canonical generation= [head-set …]
  [guarantees …]]` (the journal snapshot-canonical pattern — wrapper
  element, ed25519 over canonical bytes) with the daemon's
  `[identity]` key, so generation, coordinate, and guarantee set are
  bound together: a replayed pre-reload advert fails the generation a
  fresh `capabilities` reports, and a stripped guarantee token dies
  with the signature.
- **The guarantee set (v1)** is the consistency-vocabulary tokens this
  surface satisfies as an origin mount: `:at-least-once :gapless
  :linearizable-ref :monotonic-reads :prefix-consistent
  :read-your-writes` (canonical sorted; the set a replica serves is
  stream 9's, per the vocabulary's §8 replica profile). The feed's
  `rung=` declaration (§5.2) remains the declaration surface checked
  against it; `:at-seq-pinned`/`:at-head-set` join when this wire
  grows pinned reads. The set is checked at declaration time, refused
  at subscribe — never approximated.
- **F3 re-advertise:** every APPLIED `config-reload` (generation
  bump) pushes a fresh advert to EVERY established session — from the
  reload verb on this listener directly, and from the liveness
  sweeper's generation watch for reloads that land through the OTHER
  listeners (CSRP/gRPC own the same hot-config box). Re-advertising
  on every apply is deliberately broader than the MUST (guarantee-set
  change) — the advert binds the generation, so a stale generation is
  itself a lie worth correcting.
- `capabilities` restates `generation=` and `[guarantees …]` (§4.1)
  — the pull surface for clients that missed the push; one truth.

## §7b. Erasure on the wire (ADDED 2026-08-05, audit C6/M4 — the stream-20 requirements stream 4 was cited for but never carried)

- **The tombstone is a distinct wire response:** a `get`/`objects-get`
  whose payload was lawfully shredded returns the typed `[erased]`
  tombstone — NEVER `not-found` — so the three-way discriminator
  (never-existed / corrupt / erased) survives the wire unchanged.
- **Shred propagation rides the revocations-feed mechanism verbatim**
  (§7's subscription shape: credit, resume, at-least-once, eventual and
  offline-tolerant): destroying a key locally NEVER reaches replicas by
  side effect — a shred-request propagates as journal data on the feed,
  and each replica executes its own local shred with its own §9-shaped
  report. A replica that has not yet consumed the feed entry is
  behind, visibly (ahead/behind is computable from the head-set), not
  silently divergent.

### §7b.1. Erasure on this wire (shipped at I5 W5)

- **The producer is the `erase` verb** (§4.1; `delete`-class): the
  doc-level lawful shred at the OWNING daemon. It destroys the doc
  entry and records the attributed tombstone through ONE funnel
  (`store-erase-doc` beside the other single-seam mutation funnels),
  in the SAME act: `[erased hash= root=? at= authority=? actor=
  shred-request=]` (the stream-20 ruled tombstone shape,
  `erasure_compliance.md`; the act's own `request=` attr carries the
  same id in the §5.3 act vocabulary) — `actor` is the session
  principal (server-asserted, never client-supplied), `at` the server
  clock, `shred-request` the client's shred-request id (a generated
  token when absent). The
  tombstone SURVIVES compaction and restart on every object-graph
  substrate (an `E` manifest record whose payload rides as one more
  content-addressed object, staged and GC-rooted exactly as alias
  names are) and on the file:// index (an `E` record with inline
  payload) — attribution always survives (stream 20 §6). The full
  `erase-subject`/SEK machinery is stream 20's; this doc-level act is
  the wire's first producer and the discriminator's substrate, and
  stream 20 mounts the key hierarchy UNDER the same funnel.
- **Reads:** `get` answers the tombstone verbatim (never
  `present=false`); `objects-get` answers `[o … erased=true]` for a
  former root — and NEVER its bytes: the erased marker WINS over
  physical presence (the object may await reachability reclamation;
  serving it would leak lawfully erased content on the object wire) —
  and `objects-have` keeps reporting it MISSING for the same reason (a
  "have" that cannot be fetched is a lie). The three-way discriminator
  — never-existed / corrupt / erased — is server-asserted end to end.
- **Idempotent + convergent:** re-erasing answers `deduped=true`
  (never a second destructive act); erasing an ABSENT doc still
  records the tombstone (a replica applying a shred it received for a
  doc it never held converges to the same erased answer, not to
  not-found).
- **A later `put` of the same content SUPERSEDES the tombstone** (the
  T-record re-put precedent): content-addressed insert stays
  insert; the lineage records erase-then-insert, so the audit story
  is in the history, not in a blocklist — erasure destroys what was
  held, it does not censor future acts.
- **Propagation:** the erase act crosses the docs plane as the §5.3
  `[erase …]` notification carrying its attribution — the
  shred-request AS journal data on the feed. Each replica executes
  its own local shred from it (no reach-in; at-least-once + the
  idempotent rule above make redelivery safe). The replica AUTOMATION
  (a subscriber daemon applying erase acts to its own mount) is
  stream 9's replica worker, riding the joint requirement filed
  there; this wave ships the carriage, the act, and the convergence
  semantics it needs.

## §8. Bootstrap and retirement (L171)

HTTP keeps exactly: `health`, `ready` (unauthenticated, rate-limit-
exempt), `/metrics`, and server-level `capabilities` — whose advert
gains the server DID + handshake versions + suite-registry names and
DROPS `[auth [bearer …]]`. `capabilities` is also a post-attach profile
verb (two surfaces, one truth). The retirement set is enumerated (the
CSRP routers/codec/client arms, store_authz.v whole, the
`cx-store+http/https` schemes deprecated, `[$store:csrp-handle]`
retired, the "protocol is permanent" sentences struck across
cxstore-remote-protocol/grpc/service-tier/console, the 17xx band
reserved). Migration order inside I5: profile lands → consumers migrate
(remote client via ObjWireTransport, journal §-over-profile spec'd
here, porcelain, fabric mounts, console) → parity gate green → CSRP
data plane removed.

## §9. Corpus (L172 — G8 discharged at W3; G13 scoped to the W7 parity gate)

**`xsp.cxd` lands IN the corpus** — the design win stated: frames are
pure byte encode/decode over CX values, so the corpus itself pins frame
round-trips (all 8 types), header edges (principal-len 0, eos,
reserved-flag rejection, the 2^32−1 ceiling), the five error lanes,
decode-all remainders, negotiation accept/ignore/refuse triples, credit
arithmetic + replenishment, resume cursors incl. the group `from=`
refusal — only live-socket behavior stays in V (unlike CSRP's
V-only wire tests). G8 is discharged (`xsp.cxd` landed with W3).

**The store-protocol family (G13) is the W7 parity-gate deliverable —
NOT discharged at W5** (corrected 2026-08-07 under **RULED: R2.5**;
audit F-25 found the prior "G13 discharged" claim overstated). Its
fixture families — the op-for-op parity table; the error-identity
table; cross-encoding parity; the object wire incl. CAS conflict;
alias remoting w/ explicit absence; ∂ discriminators (N inserts ⇒ N
frames); feed ref-advance + doc-put notifications; bounds exhaustion;
head-set adverts — are built ONCE at W7 against the COMPLETE
post-pushdown verb surface (register R1.1(b)/R2.5). [CONFORMED
2026-08-08 under **RULED: R4.4(a-revised)**: CSRP died at S3 with no
three-listener gate — the correctness ORACLE is the LOCAL EMBEDDED
ENGINE (byte-identical addresses and values) plus the profile's own
fixture families, run identically across the TWO live listeners (the
XSP profile; the gRPC edge via `pipeline="profile"` synthesis). The
§4.3 pushdown verbs join these lanes per-verb as they land.] What
IS delivered and green at W5 is the revocation-propagation convergence
pair (`test_store_xsp_peer`), a live-socket behavior that never was a
G13 corpus fixture. All G13 fixtures ring-tagged on entry; M5 substrate
throughout.

## §10. Rulings ledger — RULED

Letters 163–172 **ruled (a) 2026-08-05 under the standing acceptance
ruling** (each verified against the long-term-best bar): the
spec split + fabric-shaped profile model (163); transcript-covered
negotiation closing the downgrade-strip hole (164); lanes by role —
ast_bin bodies, text envelopes, multihash binary fields (165); numeric
registered errors at CXER5000–5049 + the symbolic-code allocations +
17xx reservation (166); the three-listener parity gate w/ error
identity + the debts closed in-gate (167); the change feed w/ head-set
cursors + non-coalescing ∂ frames (168); one authority model + the
VC-chain bounds carriage (169); the peer profile + subscription-borne
revocation propagation w/ the honor rule and no-reach-in (170); the
bootstrap advert + the enumerated retirement (171); G8+G13 in-corpus
(172) — "in-corpus" is the DESIGN (frames are corpus-expressible); G8
discharged at W3, the G13 family delivered at the W7 parity gate per §9
above (corrected under RULED: R2.5, 2026-08-07). Recorded in the
campaign decision log. Spec-edit map: xsp.md
(split + rotate token), xap_identity_model (M1/M2/M4 token carriage),
store.md (§6.4 wire section replaces CSRP refs), journal.md
(journal-over-profile §), cxstore-remote-protocol/grpc/service-tier/
console (retirement amendments), governance §9.6 (bands), fabric.md
§11 (profile cross-ref), streams 9/10/20 handoffs.

**S6 (2026-08-08): the §4.3 pushdown family lands under the register's
post-R4.3 foundational rulings** — F3(a) fn-as-def-documents-by-address
+ recomputed claim (replaces letter P1 entirely); F4(a) the operator
budget (steps + memory, typed refusal); F5(b) client-signs +
appointed-signer + pushdown-safe snapshot-verify (replaces letter P2);
R4.4(a-revised) embedded-engine oracle, two listeners. Rows CXER5023–
5025, capability rows `compute`/`snapshot-sign`, feature token
`store-journal`. The fold-value client-eval-only decision is ledger
letter J1 (posed + accepted under the standing acceptance ruling,
flagged for review).

## Identity-epoch membership (audit C9)

**ADDITIVE — this stream owns no I1 manifest row and joins no epoch.**
The profile is wire protocol: frames, verbs, negotiation, feeds. No
canonical form, no Tier-1/Tier-2 address, and no journal preimage
changes here. Content addresses CROSS the wire and MUST arrive
byte-exact (the §4 ast_bin lane ruling + the L167 parity gate pin
byte-identical addresses across all three listeners — a conformance
obligation on existing identity, not a change to it). The
`xsp-auth/2/` → `/3/` HKDF label bump is a PROTOCOL version handle
(what the signed transcript covers changes), not a data-identity
event; `/2/` transcripts must not be reusable, and no stored byte
moves. CSRP retirement removes a transport; bytes at rest are
untouched. The one deliberate baseline move riding this cut is the
libcx re-cut to Rings 0–1 (I4 ruling R1) — an ABI event with its own
gate-baseline update, declared here loudly, and not an identity event.
