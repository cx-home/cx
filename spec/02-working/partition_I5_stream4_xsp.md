# I5 stream 4 — XSP store profile: implementation ledger

**Status: STREAM EXITED 2026-08-09** (entry 14 — the exit gate verified
clause-by-clause; #676 + #718 closed; the W8 R1 riders ride the first
release cut after I4 per ruling R1 and are recorded, not blocking).
Phase ledger (I5, stream 4, issues #651/#516/#676/#718;
branch `impl/I5-stream4-xsp-store` off `design/651-516-partition`).
Governing spec: `xsp_store_profile.md` (letters 163–172 ruled; its
identity-epoch membership paragraph landed with the wave-S4
reconciliation pass, commit b6b365fc). Pre-cut gate satisfied: the
audit-C9 membership paragraph exists and declares ADDITIVE (the one
deliberate baseline move — the R1 libcx re-cut — is an ABI event,
declared loudly).

**Exit gate (plan row I5, stream-4 clause):** spec conformance fixtures
green; gRPC-style parity suite passes over the XSP store profile; then
the CSRP data plane removed; the transcript-covered negotiation lands
as the `xsp-auth/2/` → `/3/` HKDF label bump (the label IS the version
handle; `/2/` transcripts must not be reusable); #718's downgrade-strip
security item verified in the same cut. Riders per I4 ruling R1: the
libcx rings-0–1 re-cut + ABI-baseline move; binding store access moves
to the wire; bindings v1 surface + auto-mirror lane (§12) ride the
first release cut after I4.

## Standing inputs

- **#718 divergence inventory** (fixture-before-fix; item 1 = the
  security item, verified here; items 2/3 close AS PART of the parity
  gate per L167; item 4 = L166 numeric allocations; item 5 = rotate
  token; item 6 = the "permanent" sentences struck; item 7 =
  journal-over-profile spec'd for the PROFILE).
- **Shipped shape:** XSP frame codec is CX-native (`stdlib/xsp.cx`,
  175 lines; V primitives in `platform/stdlib_xsp.v`); XSP-AUTH labels
  at `xsp-auth/2/…` (`platform/stdlib_xsp_auth.v:50–54`); CSRP =
  `platform/store_csrp*.v` (~2k lines) + `store_authz.v` (658) +
  routes in `store_service.v` (1932); gRPC edge =
  `store_grpc_{frame,proto}.v` + serve; remote client seam =
  `ObjWireTransport` in `platform/store_remote.v`.
- **Corpus:** `xsp.cxd` does not exist yet (G8 — frames land IN the
  corpus); the store-protocol family (G13) lands ring-tagged
  (`ring=2`, `eval-ring=2`) so the Ring-0 extraction corpus stays
  untouched.

## Waves (each ends green on full `make test`; fixtures ride with
their op family, never after)

| Wave | Work | Done-when |
|---|---|---|
| **W1 — spec surgery** | xsp.md splits into generic frame+session layer + a profiles section (XAP profile re-labeled; store profile = the working spec, promoted); `rotate` token added to §5.0 (#718 item 5); transcript-covered negotiation normative (xsp.md §5.0 amendment + xap_identity_model M1/M2/M4 token carriage); store.md §6.4 wire section replaces CSRP refs; journal.md journal-over-profile §; governance §9.6 gains CXER5000–5049 + numeric allocations for symbolic CXER-XSP-* + the 17xx reserved-at-retirement note; the "protocol is permanent" sentences struck (cxstore-remote-protocol.md, cxstore-grpc.md, service-tier, console); fabric.md §11 profile cross-ref | Spec tree self-consistent; verify-doc gates green |
| **W2 — xsp-auth/3** | M1/M2 carry offered profile+feature token sets; M4 confirms the selection inside the signed transcript; HKDF labels bump `/2/`→`/3/` (all five); downgrade-strip fixtures FIRST (a stripped offer under /3 fails the confirm; a /2 transcript is not replayable at /3); rotate token in the post-attach advert stays operational-only | #718 item 1 verified by fixture; handshake suite green |
| **W3 — profile core** | The 17 CSRP data/admin ops as payload verbs (request→reply on stream-id); `query`/`iter`/`list` as credit-governed `event` streams w/ `cancel`+`eos`; lanes by role (ast_bin bodies / text-canonical envelopes / varint multihash in binary fields w/ the bijection); CXER5000–5049 error rows in the registry (same PR, #717 discipline); `xsp.cxd` corpus family (G8: frame round-trips, header edges, five error lanes, decode-all remainders, negotiation triples, credit arithmetic, resume cursors incl. group `from=` refusal) | Profile listener serves the op set; xsp.cxd green |
| **W4 — feeds + authority** | Change feed (ref-advance + doc-put subscriptions, `:complete-ordered` rung, HEAD-SET resume cursors, ∂ frames never coalesced, per-frame redaction counts); ONE authority model (attach = XSP-AUTH, VC-compiled capability values, DidGrant → ordinary delegations); bounds carriage (`[bounds]` as the fourth ⊆-checked attenuation axis, per-stream meters, `[deny …retry-after…]` CXER4713) | Feed + authority fixture families green |
| **W5 — object wire, erasure, peer** | `objects-have/get/put/refs` ops (put verifies address, batch `ref-set` all-or-nothing); generation-bound `[store-advert]` w/ signed head-set + guarantee set, re-advertised on config-reload (F3); `[erased]` tombstone distinct from not-found; shred propagation on the feed; `peer` profile (mutual XSP-AUTH, deny-by-default `peer` cap, revocations-journal subscription, honor rule, no-reach-in, convergence bound reported) | Revocation-convergence pair green (`test_store_xsp_peer`). [CORRECTED 2026-08-07, RULED: R2.5 / audit F-25: the prior "G13 families green" OVERSTATED — the G13 fixture families (op-for-op parity, error-identity, cross-encoding parity) are the W7 parity-gate deliverable, built ONCE over the complete post-pushdown surface (R1.1(b)); they were NOT delivered at W5. W5 exit stands CONDITIONAL on W7 delivering them (§9 corrected under the same ruling).] |
| **W6 — consumers migrate** | Remote client: XSP transport as the third `ObjWireTransport` impl; journal-over-profile; porcelain; fabric mounts; console; gRPC adapter re-bases onto the profile pipeline (synthesizes internal ops, not CSRP requests) | All consumers on the profile; CSRP has zero in-tree consumers except the parity listener |
| **W7 — parity gate + retirement** | Three listeners (CSRP transitional / gRPC / profile), same fixtures: op-for-op equivalence, ERROR IDENTITY, byte-identical content addresses, identical stream result sets; discriminators (mid-iter cancel, credit exhaustion, resume-after-reconnect, ∂ deltas); #718 items 2/3 close in-gate; THEN: CSRP routers/codec/client arms removed, `store_authz.v` whole, `cx-store+http/https` schemes deprecated, `[$store:csrp-handle]` retired, 17xx band Reserved, bootstrap HTTP reduced to health/ready/metrics/capabilities (advert gains DID + versions + suites, drops `[auth [bearer …]]`) | Parity green THEN retirement lands; full corpus green |
| **W8 — R1 riders** | libcx re-cuts to Rings 0–1 (default `make lib` over `code/`); ABI baseline moves deliberately, ONCE (`libcx-abi-gate` re-baselined; iowatch callbacks + mbedtls out); binding StoreClients (python/rust/go/cxlib) move from `cx_code_eval_caps` store verbs to the wire (XSP store profile / gRPC / HTTP per §12.1); bindings v1 surface = Layer-1 Document API (cx_code_eval* excluded); auto-mirror publish lane (§12.3) | ABI gate green on the NEW baseline; binding parity green over the wire; profile tarballs reflect the re-cut |

Wave order is the §8 migration order (profile lands → consumers
migrate → parity → retirement) with the R1 riders last — the re-cut
cannot precede W6 (bindings need the wire before libcx loses the
Ring-2 verbs; that is R1's whole argument).

## Work log

1. **Phase open (2026-08-06).** Branch cut AFTER the wave-S4
   reconciliation pass landed on the campaign branch (audit C9 pre-cut
   gate — all eight silent specs, commit b6b365fc). Stream-10's
   manifest-row-15 fixture move verified already-landed at I1
   (`journal.cxd` journal-042 on CXER1114). Standing residuals noted,
   neither blocks this stream: entry-25 mode-in-identity (ruled (a),
   resolves before type-binding anchoring — a later stream); #707
   lazy-substrate (EV-ASYNC-SPAWN, stream 22's branch). Shipped-shape
   inventory recorded above.

2. **W1 — spec surgery LANDED (2026-08-06).** The edit map executed:
   xsp.md re-framed as the GENERIC frame + session layer with the new §6
   profile model (profile = token set + verb vocabulary + error rows;
   registry: XAP re-labeled, STORE pointed at the stream-4 spec); §5.0
   split into transcript-covered semantic offers (surface 1, with the
   `/3/` consequence stated) vs post-attach operational limits (surface
   2, `rotate` now listed — #718 item 5); §2's type table de-XAP'd;
   revocation-propagation deferral re-pointed at the profile's peer
   channel. xap_identity_model.md: M1/M2 gain `[offers]`, M4 gains
   `[confirmed]`, NEW §4.4a (selection = computed intersection,
   M4-verified, `CXER-XSP-AUTH-STATE` on mismatch), §4.4 coverage list +
   §8 downgrade item + properties table extended to vocabulary, §4.5
   labels rewritten at `/3/` with the full `/1/→/2/→/3/` lineage note
   (the §4.5 block still said `/1/` — it was never amended at I1's `/2/`
   cut; divergence closed). store.md: wire axis row re-ruled (xsp
   default, grpc, csrp transitional), NEW §6.4 (the profile as THE store
   wire + the retirement enumeration). journal.md: NEW §6.1
   journal-over-profile (the #644 gap — profile only, never spec'd for
   CSRP). fabric.md §11 marked as the profile template (cross-ref).
   Retirement amendments: cxstore-remote-protocol.md (RETIRING banner +
   "permanent" struck), cxstore-grpc.md (canonical → the profile;
   adapter re-bases), cxstore_service_tier_phase2.md (three sites incl.
   the §3 auth-stack retirement note), store_management_console.md
   (wire-transition note). governance §9.6: `CXER5000–5049` band
   pre-registered (live-modes precedent; per-code rows ride W3 with the
   implementation, #717 discipline; 5050–5069 = stream 9, 5070–5089 =
   live modes — no collisions). Gates: verify-doc-blocks 317/0,
   verify-doc-links all green, stdlib-catalog-gate green AFTER the
   both-halves repair (separate commit — pre-existing silent break from
   I3, gate now in TEST_TARGETS).

   **Rider found and fixed (not scope creep — a broken gate):**
   `stdlib-catalog-gate` read only `vcx/code/stdlib_dispatch.v`, but I3
   moved every platform module's dispatch behind the seam-G registry
   (`ring2_register.v`). The gate therefore reported redis/sql/xap_dist/
   xsp_auth as unimplemented and http_client/ring2 as orphans — and sat
   SILENT because the gate was never in `TEST_TARGETS`. Both halves are
   now read (the same union rule I4 applied to `check-completions-drift`),
   `http_client`/`http_serve` normalize to the `http` catalog module, the
   `ring2` seam probe is excluded, and the gate JOINS `TEST_TARGETS` — a
   gate outside the battery is a seam with no live consumer.

3. **W2 — xsp-auth/3 LANDED (2026-08-06).** The labels bump (all five)
   and §4.4a negotiation are live end to end.

   **THE SHAPE FINDING (a real trap, caught by the corpus):** the first
   implementation carried the token sets as a nested `[offers profiles=…
   features=…]` child. That broke `xsp-auth-017`/`024` — the frame
   round-trip cases. Reason: handshake fields are read attr-OR-child
   because data-bin ATOMIZES single-scalar children to attributes, so a
   fresh child-form message and a decoded attr-form message emit
   identical bytes. A NESTED element does not atomize — it stays a child
   and lands at a different byte position than the atomized siblings, so
   the fresh and decoded forms signed DIFFERENT transcripts and the
   responder signature failed. Fix: four flat single-scalar fields
   (`offer-profiles`, `offer-features`, `confirmed-profiles`,
   `confirmed-features`), which atomize like every other field. Verified
   directly: `encode(M1) == encode(decode(encode(M1)))` byte-for-byte.
   The spec (§4.4a) now states this as one of the two normative reasons
   for the shape (the other: canonical sorted/dedup'd sets, because the
   transcript signs bytes and two spellings of one set would be a signed-
   aliasing surface). **Generalizable rule: any field added to an
   XSP-AUTH message MUST be single-scalar.**

   **Selection is COMPUTED, not asserted:** M4 states the per-field
   intersection of the M1/M2 offers, and `auth-finish` recomputes it
   from its own M1 + the received M2 and refuses on mismatch. So the
   property holds against both threat directions — a MITM stripping a
   token breaks the transcript signature, and a server (or MITM)
   narrowing M4's stated set breaks the initiator's check. #718 item 1
   is verified, not merely spec'd.

   **Non-replayability, measured:** the same fixed vectors produce
   different tag_i / tag_r / chan-id under `/3/` than the recorded `/2/`
   values (`af9520ff…`/`29c84f43…`/`56fc3863…` → `0b09dbab…`/
   `23633005…`/`8f1b273b…`). `xsp-auth-031` pins the inequality against
   those recorded constants, so a regression that un-partitions the key
   schedule fails loudly.

   Consumers offer INSIDE the transcript (fabric remote client, fabric
   daemon, xap host); the post-attach `[fabric-session]` advert now
   restates the confirmed intersection (`FsConn.confirmed_features`) and
   cannot extend it — which is what surfaced the `fabric_serve_test`
   `publish-batch` assertion: its hand-built M1 offered nothing, so the
   advert correctly withheld the feature. The test now offers the set it
   asserts (both M1 builders, byte-identically — the transcript demands
   it). Fixtures: 25 (intersection), 26 (strip breaks sig — THE #718
   case), 27 (forged confirmed refused), 28 (offers required from /3 —
   pre-/3 tolerance would restore the hole), 29 (non-canonical refused),
   30 (frame round-trip survival — the regression guard for the shape
   finding), 31 (/2 non-replay). Cases 008/014's hand-forged messages
   gained well-formed offer fields so their own lanes (VERSION, CONFIRM)
   stay the thing under test.

   Green: `code_eval_fixtures` 2581 stdlib fixtures / 31 xsp-auth,
   `fabric_serve_test`, `xap_host_auth_test`, verify-doc-blocks 317/0,
   verify-doc-links, stdlib-catalog-gate. **Wave gate: full `make test`
   rc=0 (2026-08-07, zero FAILs — even the two standing classified-retry
   lanes were green first try); extraction gate byte-identical both
   lanes (4498070-byte ABI transcript; 1564 Ring-0 cases / 8978
   invocation pairs / 17 refusals).** All W2 work re-verified under
   Fable 5 after a mid-session model switch was caught and reverted
   (owner directive; the absolute model rule is now standing).

4. **W3 — profile core LANDED (2026-08-07).** The listener is
   `store_xsp_serve.v`: the third `cx store-serve` listener (opt-in
   `[xsp enabled addr [identity] [policy] [limits]]` config section,
   fabric-shaped identity validation, registered with the shutdown
   watcher at birth — the #211 lesson), XSP-AUTH responder on stream 0
   offering `profiles="store" features="credit"` INSIDE the transcript,
   attach routing by M3 `[tenant]` = mount name (sole-store shorthand
   kept), and every verb one text-canonical envelope over
   **`store_stdlib_builtin_inner`** — the op-core seam, exactly as the
   entry note predicted: no op pipeline was disentangled, only framed.
   All 19 verbs + `session` serve (get put delete modify list iter query
   objects-have/get/put refs refs-set aliases aliases-set capabilities
   status gc mounts config-reload). `list`/`iter`/`query` are
   credit-governed event streams on the REQUEST's stream-id (window=
   declares, credit frames replenish, `cancel` → terminal
   `[eos cancelled=true]`, empty set → bare `[eos count=0]`).

   **Lanes made byte-precise (§4.1):** doc bodies = framed ast_bin
   imaged as `[body::bytes 0x…]` (get/iter/put); doc addresses = tagged
   text; object-wire addresses = varint-multihash bytes attrs
   (`h::bytes=0x1220…`) — the crypto-agility bijection LIVE, fail-closed
   on unregistered codes; `objects-put` verifies every claimed address
   against the bytes (whole-batch refusal on one mismatch); `refs-set`
   and `aliases-set` are validate-then-apply all-or-nothing with
   `CXER1114` verbatim. **Error transparency:** op-layer faults ride
   VERBATIM (`CXER1121`, `CXER1110`, `CXER46xx`); absence is DATA
   (`present=false`); the profile's own rows are `CXER5010–5018`
   (§4.2). The L166 numeric cutover landed with it: the five symbolic
   `CXER-XSP-*` frame-codec codes are RETIRED into `CXER5000–5004`
   (+ new `CXER5005 E_XSP_FLAGS`), registry rows in §4.2, governance
   band row updated — #717 same-change discipline throughout.

   **Two shipped codec defects caught by the G8 corpus at authoring:**
   (1) a payload-less BINARY frame (encoded `[frame type=ping]`)
   mis-refused as a data-bin parse failure — a zero-length payload is
   now an empty `[payload]`, never a codec error (xsp-004 guards);
   (2) the declared-length ceiling: a 17-byte header declaring a
   4294967295-byte payload slipped past the truncation check through
   int(u32) overflow and CRASHED the decoder on a negative allocation —
   a remote-DoS-grade defect in every XSP listener; the length
   arithmetic is i64 now (xsp-012 guards). Reserved flag bits 2–7 were
   also silently IGNORED against §2's MUST — now rejected `CXER5005`
   (xsp-006; the negotiation-enforceability rationale recorded in
   xsp.md §2).

   **Corpus:** `conformance/stdlib/xsp.cxd` (G8) — 20 cases, suite
   `ring=2`: round-trips all 8 types, header edges (anonymous +
   payload-less consumed=17, eos, reserved flags, ceiling), six error
   lanes, decode-all remainders, the negotiation triple (accept =
   canonical intersection / ignore = unknown token never lands /
   refuse = forged EXTENSION refused by auth-finish — complements
   xsp-auth-027's narrowing), §5.2 credit arithmetic as executable
   spec, §5.3 cursor form. The group `from=` refusal was verified
   already live-pinned (fabric_serve_test.v:1038) — [CORRECTION
   2026-08-07, R3.14/audit F-30: that pin's home is CORRECT and stays
   there. The refusal is a live-listener behavior (a subscribe against
   the daemon's group registry, socket-bound); the xsp.cxd corpus
   family covers the codec/calculus-expressible G8 items only, so
   "moving" this pin into the corpus would fake an in-process case for
   a wire behavior. The original entry's phrasing implied corpus
   coverage; this note records the true split.]; listener-side credit
   ORDERING, cancel choreography, and everything socket-bound live in
   `store_xsp_serve_test.v` — one boot, ~40 assertions, including THE
   M5 property: a wire `put`'s address is byte-identical to the local
   embedded put of the same doc, and a `get` body re-renders to text
   that re-hashes to the address.

   **Interim posture (recorded, not silent):** attach authenticates
   (mutual default; `[policy mode=floor floor=…]` admits anonymous
   under `floor:<name>`), and the daemon-level `mounts`/`config-reload`
   require a DID-proven principal (`CXER5018`) until W4's VC-compiled
   PEP owns authorization. Fabric's pong (payload not echoed) noted as
   a §5.1 divergence in the fabric listener — a W6/W7 parity-adjacent
   cleanup, not touched here.

5. **W4 IN PROGRESS (2026-08-07).** Spec surgery landed first
   (be6356db): xsp_store_profile §5.1–§5.3 (the E3 lineage substrate —
   ONE log read by the fixed `store:log` #708 AND the wire feed; the
   HEAD-SET map form; `feed` gated by `store-feed`, body carriage by
   `store-delta`; `:complete-ordered` declared + reported; retention =
   process lifetime with the `:gapless`-class `CXER5020` refusal;
   notification shapes with E3 positions; never-coalesced; per-frame
   `redacted=K` carriage whose first producer is W5's shred) + §6.1
   (the listener authority model) + §4.2 rows 5019–5021 + the 5018
   re-scope; authz.md §2.2 `[bounds]` + §4.2 four-axis pin + §8
   CXER4713; xsp.md §5.3 map cursor; governance band row.

   **W4 rulings (verified long-term-best, recorded):** (1) enforcement
   posture mirrors the daemon's `[auth]` rule — `[grants]` present ⇒
   deny-by-default VC-compiled PEP, absent ⇒ the W3 open posture with
   `CXER5018` re-scoped to open mode only (ONE posture rule across
   listeners, and the W3 test lanes stay meaningful); (2) capability
   grammar v1 = the four CSRP op-classes kept class-for-class (the W7
   parity gate compares apples); (3) `spend` bounds are unsupported on
   this surface at v1 and REJECT the presentation fail-closed
   (`CXER5021`) — a bound that cannot be metered is never silently
   void; (4) unrecognized-root chains compile to NOTHING (inert,
   logged, `[presented compiled=N inert=K]`) while cross-tenant is a
   FAULT — the identity model's §5.3 split, kept exactly; (5) feed
   retention v1 = process lifetime + seed-at-open (a replay from the
   empty cursor serves the corpus snapshot as inserts, honoring the
   quartet's `changes-since(∅) ≡ [?for]`), with a boot token on the
   head-set making "below the retention boundary" DETECTABLE
   (`CXER5020`, never silent cross-boot divergence); durable lineage
   rides W5 with the signed advert.

   **Authz core LANDED (46c3b64e, fixtures authz-054…062 first):**
   `[bounds]` parses/materializes verbatim (unknown conjunct =
   unissuable CXER4711); attenuation now ⊆-checks FOUR axes at issue —
   the WINDOW check was decision-time only against the identity
   model's §5.2 chain rule (child until ≤ parent's; absent child until
   INHERITS), bounds compare per-conjunct against the nearest
   bounds-bearing ancestor (rate = capacity AND cross-multiplied
   refill; incomparable spend = fail-closed) — both CXER4703; the
   decision walks EVERY bounds-bearing link against `opts.meters`
   readings (pure-PEP snapshot posture; absent reading = fresh meter —
   meters RESTRICT, so no usage records = unspent budget, the inverse
   of gate evidence); exhaustion denies `[deny [code CXER4713]
   [reason :budget-exhausted] [conjunct :rate|:count]
   [retry-after N]?]` with retry-after only where the meter
   replenishes, and alternative chains with headroom still permit.
   Full stdlib fixture battery green (2581+9).

   **Remaining W4 (next):** the lineage substrate in MemStore (feed
   log + seed-at-open + boot token; funnels: store_put_canonical/raw,
   delete-doc, set/delete-alias, branch/branch-force, the two
   listener refs-set sites via ONE store_ref_advance helper; cxpack/
   graph rebuild writes are the SEED path, never live events) +
   `store:log` re-read from the lineage (#708 — NOTE: the canonical
   docs example 18-store.cxd pins the OLD live-refs-only count and
   re-records to advance-event counts, and store.md §*/console table
   sentences update in the same change) + listener feed verbs +
   listener authority wiring (per-session AuthzStore seeded from
   `[grants]`, VC presentation, per-verb PEP, meter debit at the op
   lock) + `store-feed`/`store-delta` in the transcript offers + V
   test lanes + G13 fixtures.

6. **W4 — feeds + authority LANDED (2026-08-07).** Five implementation
   commits on top of the entry-5 spec surgery: authz core (46c3b64e —
   `[bounds]` + the FOUR ⊆-checked issue-time axes incl. the window
   pin, `opts.meters` pure-PEP budget denies, CXER4713); the E3
   lineage substrate (72909cdf — #708 CLOSED: ONE per-ref advance log
   in MemStore behind the single-seam funnels + `store_ref_advance_local`,
   seed-at-`store_register` compaction, `feed_boot` boundary token;
   `store:log` = per-act rows with dense per-stream positions;
   the canonical docs example re-recorded); the listener authority
   model (8f6832dd — `[xsp [grants …]]` → per-session basis,
   deny-by-default PEP with `[deny]` verbatim on the wire, VC
   presentation M3/phase=present, per-session meters debited at the
   verb commit point, CXER5018 re-scoped to open mode); the change
   feed (this commit — server-level subscription registry over the
   lineage, `[feed]` with head-set boot-token cursors, CXER5019/5020,
   never-coalesced delivery, credit/cancel integration, cross-listener
   sweeper wake, `store-feed`/`store-delta` in the transcript offers).

   **TWO CARRIAGE FINDINGS (both spec'd §6.1/§5.1–§5.2 same-change):**
   (1) a VC presentation MUST ride as a single-scalar TEXT field
   (`[vp "<canonical [vp [vc …]…] text>"]`) — the nested-element form
   is unsound twice over: M3 is transcript-signed and nested children
   do not atomize (the W2 §4.4a trap), and data-bin is lossy on
   element/attr duality so a `[vc …]` crossing it re-canonicalizes and
   its SIGNATURE dies (L165's lossless-lane rule applies to signed
   content). (2) Wire-crossing delegations use the `id="…"` ATTR form
   — a leading bare id is mixed content and does not survive the text
   round-trip (measured: `[delegation d-vc-1 …]` re-parses as
   `[delegation 'd-vc-1 ' …]`, trailing space, bad-signature). Also
   pinned: the head-set/`[from]` cursor carries the mount's `boot`
   token, making "below the retention boundary" DETECTABLE (CXER5020)
   instead of silently divergent across daemon restarts.

   **Coverage:** test_store_xsp_authority (grants posture end-to-end:
   class grants, floor read, deny-by-default, phase=present late
   grant, `[bounds [count 2]]` → CXER4713 after exactly two permits,
   subject-mismatch, spend fail-closed, M3-carried vp) + the feed
   lanes in the W3 boot (un-negotiated 5012; rung/plane/cross-boot
   typed refusals; cross-connection live tail; the never-coalesced
   two-puts-two-frames discriminator; alias advance; window
   starvation + credit resume; retract delivery; cancel eos; HEAD-SET
   resume replay with bodies; live refs advance with dense per-name
   pos + multihash root). Fixtures: authz-054…062 (escalation lanes
   watched fail first), store-log-002/003, xsp-021 (map-cursor form).

   **WAVE GATE MET:** full `make test` rc=0 (2026-08-07); the single
   FAIL was the standing `-usecache` compile-artifact lane
   (fabric_nats_bridge, R=0.000ms), green on the #572 sanctioned
   cache-free retry. Interim CXER5018 retired into the PEP (open-mode
   only now); the CSRP DidGrant table's operator intent carries over
   as `[grants]` → ordinary delegations. NEXT = W5 (object
   advert/erasure/peer — §7a/§7b; the feed mechanism is reused
   verbatim for revocation + shred propagation, no new machinery).

7. **W5 — object advert, erasure, peer LANDED (2026-08-07).** Spec
   surgery first (dced728f: §7.1 peer model, §7a.1 advert, §7b.1
   erasure, §5.2/§5.3 revocations plane + [erase]/[revoke] shapes +
   the redacted=K first producer, §6.1 peer class + the two-point
   revocation enforcement, §4.1 erase row, §4.2 CXER5022), then one
   implementation commit (ab57a9b0) + the marker-wins spec sharpening.

   **Erasure (§7b.1):** `store_erase_doc_local` = the ONE doc-level
   lawful-shred funnel — destroys the entry AND records the attributed
   `[erased …]` tombstone in one act. The tombstone survives restart
   AND compaction on every substrate: `E` manifest records whose
   payload rides as one more content-addressed object (staged via the
   sink like alias names, explicitly GC-rooted at cxpack compaction),
   plus a file:// `E` index record with inline payload; ONE shared
   replay (`store_replay_apply_erased`/`_clear_erased`) with the
   supersede rule = replay order (a later `D` clears the tombstone —
   the T re-put precedent; the erased_manifested mark drops at clear
   so a RE-erase emits a fresh operative E). Idempotent (`deduped`),
   convergent (erase-of-absent records the tombstone). Wire: `erase`
   verb (delete-class, actor server-asserted); `get` answers the
   tombstone VERBATIM; **the erased marker WINS over physical
   presence** — `objects-get` answers `erased=true` and never the
   bytes even while the root object awaits reclamation (anything else
   leaks erased content), `objects-have` keeps it MISSING (a "have"
   that cannot be fetched is a lie). Feed: `[erase plane="docs" …]` is
   a DISTINCT act carrying its attribution (the shred-request AS
   journal data — replicas execute their OWN shred; automation rides
   stream 9), and a `bodies=true` replay of an erased insert carries
   `redacted=1` — the visible-count rule's first producer (deleted
   stays silent-bodyless; deletion is not redaction). `store:log`
   shows `kind=erase` for free (one log).

   **Advert (§7a.1):** `[store-advert generation= [head-set …]
   [guarantees …] signer= sig-algo=":ed25519" sig=]` — ONE stream-0
   event after M4, signed over `cx_text_canonical` of
   `[store-advert-canonical …]` (the verifier recipe is `$cx:canonical`
   — NOT `$cx:emit`, which is the pretty renderer; that distinction
   cost one red run and is now pinned by xsp-022 + the stripped-token
   negative xsp-023). Guarantee set v1 = the six origin-mount
   consistency tokens. F3 = the sweeper's generation watch (hot-config
   box `generation()`) re-advertises every established session on ANY
   applied reload, cross-listener included; `capabilities` restates
   generation + guarantees. ONE head-set builder serves advert and
   feed-sub.

   **Peer (§7.1):** the peer channel IS the feed's fourth plane —
   `revocations` (subscribes ALONE; peer token offered only when
   `[xsp [revocations journal=]]` designates one; deny-by-default
   `peer` capability with NO open-mode exception — CXER5022; durable
   journal-seq positions, boot-EXEMPT cursors; the reply reports
   `[convergence feed-lag-ms=250 enforcement="next-pep-check"]`).
   Journal head discovery PROBES the per-seq entry aliases (one read
   path for anything that writes entries — the head alias's
   `seq:hash` value is not a doc target and cannot cross the wire's
   validated aliases-set anyway). Outbound: `[xsp [peers [peer url=
   did= tenant=]]]` spawns one worker per peer — mutual XSP-AUTH
   initiator under the daemon identity (the fabric-remote dial shape
   over net_dial_*_real; operator config is the dial authority),
   responder DID pinned, backoff retry (an offline peer is lag). ONE
   revoked-set per server, folded from the local journal (sweeper
   tick) and every peer subscription; TWO local enforcement points:
   `vc-verify` gets `opts.revoked` at present time, and
   `sx_pep_decide` REMOVES compiled-from-revoked delegations (the
   per-session `vc_of` map) at the next check — sessions never torn
   down, authority narrows (no reach-in, measured: ping green after
   the deny). PEP-vs-token gate ordering ruled: under grants the PEP
   decides FIRST (a session without the peer cap gets the verbatim
   `[deny]`, never 5022); the transcript gate refuses 5022 for
   cap-holding sessions missing the token, for non-designating
   daemons, and for the open posture.

   **Coverage:** store_erase_test.v (substrate: reopen + compaction
   survival, supersede incl. re-erase-after-reput, absent-doc
   convergence, file:// E roundtrip); serve-test W5 lanes (advert
   signature verified through the REAL `$crypto:ed25519-verify`, F3
   generation=1 re-advert, the full erase choreography, the object-
   wire discriminator); test_store_xsp_peer = the G13
   revocation-convergence PAIR live over two daemons. Fixtures
   xsp-022/023. The one W5 scope note: the erase verb originates
   shreds at the owning daemon — `$store:erase` local porcelain and
   the erase-subject/SEK machinery are stream 20's (store.md §9 edit
   map), which mounts UNDER the same funnel; the replica worker that
   auto-applies erase acts is stream 9's (filed there as the joint
   requirement); migrate/clone do not carry the erased map yet
   (stream 20 revisits with the SEK cut).

   **WAVE GATE MET:** full `make test` rc=0 (2026-08-07); the two
   FAILs were both the standing `-usecache` compile-artifact lanes
   (fabric_nats_bridge R=0.000ms; for_comp_closures_mem), each green
   on the #572 sanctioned cache-free retry — the gate's own
   classified-retry verdict. [CORRECTION 2026-08-07, register R3.13 /
   audit F-29: "standing" was accurate only for fabric_nats_bridge
   (recorded I3/I4 ledgers); for_comp_closures_mem has NO prior record
   as a usecache lane — it passed the #572 sanctioned retry, but this
   was its first recorded appearance, not a standing one.] Extraction gate byte-identical (1564
   Ring-0 cases / 8978 invocation pairs / 17 profile refusals). NEXT
   = W6 (consumers migrate: the remote client's XSP transport as the
   third ObjWireTransport impl, journal-over-profile, porcelain,
   fabric mounts, console, the gRPC adapter re-base).

8. **W6 — consumers migrate LANDED (2026-08-07).** `cx-store://` IS the
   store wire now.

   **The client (store_xsp_client.v):** ONE persistent, tenant-bound
   session per open handle — dial → XSP-AUTH M1–M4 through the shipped
   `$xsp:auth-*` calculus (the peer worker's initiator shape),
   anonymous-floor by default, mutual via open-opts `xsp-did` +
   `xsp-seed-env` (the seed ALWAYS an env-var name; the URL carries NO
   userinfo — the bearer-in-URL pattern does not carry over, refused at
   parse). Idle sessions are ping-probed before reuse so a
   liveness-swept connection re-establishes instead of surfacing a
   spurious CXER1101; reconnect-once only when the request never left
   (a write-failure), never after a sent request (a delete/CAS retry
   would lie). Verbs ride text frames on fresh stream-ids;
   list/iter/query subscribe UNBOUNDED (no window=) and collect events
   to eos; errors cross VERBATIM ([err]/[deny] both — §4.1
   transparency); only genuine transport faults synthesize CXER1101.
   `XspObjWireTransport` = the THIRD ObjWireTransport impl: it adapts
   RemoteObjectBackend's CSRP-shaped bodies (bare-hex `h="…"`) to the
   profile's varint-multihash envelopes (`h::bytes=0x…`) and back, and
   synthesizes the CSRP-identical statuses from the verbatim codes
   (1114→409, 1121→404, 1131/[deny]→403, 1132/4713→429) so
   store_objwire_err and the alias/ref callers classify identically
   across all three transports. `get` answers the `[erased …]`
   tombstone verbatim; `has()` counts erased ≠ present. Scheme map
   (store.md §6.4 rider): bare `cx-store://` = the profile over TLS,
   `cx-store+xsp://` = the cleartext dev sibling (port explicit — no
   registered default); `cx-store+http/https` stay CSRP TRANSITIONAL
   until the W7 retirement; all nine store_remote.v routers split
   accordingly; `csrp_scheme()` (the service-tier gate) grows the xsp
   tokens and its name retires at W7. No HTTP discovery for the
   profile — the attach IS the negotiation.

   **Journal (#644 / #718 item 7):** the journal consumer rides the
   profile — entry docs as objects, head/entry pointers on the daemon's
   authoritative alias table, cross-process rehydrate + chain
   continuation live-tested (the stale-tail CAS lives daemon-side,
   CXER1114 identity). journal.md §6.1 TRUED to the shipped mechanism:
   v1 = the object-wire carriage over the profile; the daemon-side
   VERB PUSHDOWN (folds/streamed reads as payload verbs) is recorded
   as the profile's GROWTH PATH, explicitly NOT part of the stream-4
   exit gate, its two open design points named (fn-as-data canonical
   carriage is identity-adjacent; snapshot-signing key custody). The
   prior §6.1 text described pushdown as if shipped — a spec with no
   live consumer; trued under the standing acceptance ruling,
   FLAGGED FOR REVIEW.

   **gRPC re-base:** grpc_synth_req_m marks its requests
   `pipeline="profile"`; svc_dispatch_data_op routes those to the NEW
   store_profile_ops.v (svc_profile_data_op — the 16 data ops directly
   over store_stdlib_builtin_inner, same validation order, wire bodies,
   #628 op-lock discipline, and §4 status↔17xx remapping as
   store_csrp_route's cxd lane). The duplication is DELIBERATE: at W7
   the CSRP router files delete whole and this core remains; until then
   the parity suites pin both cores byte-identical (zero test edits).
   Auth/limiter/metrics/capabilities/mounts/config-reload stay the ONE
   shared svc pipeline. Note for W7: store_service.v:~1291's
   non-CSRP-path fallthrough into store_csrp_route needs attention when
   the router deletes; grpc_synth_capabilities drops the pipeline attr
   (harmless — resolved before data-op dispatch).

   **Fabric:** the pong no-echo divergence (recorded at W3) FIXED —
   pong echoes stream-id AND payload verbatim (§5.1 opaque echo, text
   or binary), fixture strengthened. Fabric mounts were already 100%
   XSP (the profile's template — nothing else to migrate).

   **Discovery:** the server-level HTTP capabilities advert gains
   `[xsp [addr …] [did …]]` when the profile listener is up (§8's
   bootstrap direction) — the hook a management client uses to find
   THE wire from the HTTP base it knows.

   **Console (xap-store-console, external):** remote-store discovers
   the advert and dials the profile (cx-store:// off https daemons,
   cx-store+xsp:// off http; TRANSITIONAL CSRP fallback for
   pre-profile daemons); add-credential gains the xsp-identity kind
   (did= + seed-env= — seed by env reference, nothing sealed or
   journaled); conform §13b (new) fully green: advert discovery,
   anonymous seed over the profile, mutual attach, list/get/query
   pushdown, no seed leakage. Toolchain-drift repairs to run at all:
   sha256:→sha2-256: stanza tags, registry re-published in the
   multihash pack format (console-connect@0.3.0, store-connect@0.3.0,
   store-browse@0.2.1 — released aliases are immutable), retired infix
   CXPath predicate cut over, browse-list's `($ld)` seq-literal wrap
   dropped (attrs are scalar-only). The 19 remaining conform reds are
   pre-existing 0.13-idiom drift on the static-daemon BEARER lanes
   (sealed-secret round trip, fail-closed asserts, readout shapes) —
   filed as xap-store-console#6, NOT caused by the migration.

   **Web client (xap-marine-htmx-web-client, external):** off pre-/3
   M1s — open() now offers `profiles "xap"` (features empty by design)
   inside the signed transcript and VERIFIES the M4-confirmed
   intersection carries xap before establishing. Proven end-to-end
   through the shipped calculus (hello→challenge→prove→attach-xsp→
   finish: confirmed profiles='xap'). The marine XAP host itself does
   not boot under the 0.15 dev binary (its own repo drift — the
   conform harness's "bus-error" retry loop) — that blocks the LIVE
   client↔host lane, not the client change; the cross-repo drift
   gate's 6 pre-existing reds are unchanged.

   **W6 gotchas (recorded):** `[$store:open]` takes ONE arg — opts ride
   `store-open-opts` with a `[map k=v]` element, and the opts allowlist
   is explicit (new keys must be added there or they silently drop);
   `$=` is not the equality builtin (`$eq`); `$first` over a
   single-match node-set descends into the ELEMENT's children — pass
   `$x/confirm` style paths to consumers (the corpus idiom), never
   `[$first $x/confirm/*]`; store-get-doc-text over the objwire answers
   the ABSENCE channel for a miss (never CXER1121 — pin error identity
   via modify-of-absent instead); a V match-expression arm can
   `return`, and getting a mut ref from an immutable-sourced pointer
   is the `unsafe { &Type(ptr) }` cast at the CALL SITE (the fn-return
   provenance still trips the checker).

   **WAVE GATE MET:** full `make test` rc=0 (2026-08-07); the single
   FAIL was the standing `-usecache` compile-artifact lane
   (fabric_nats_bridge, R=0.000ms), green on the #572 sanctioned
   cache-free retry — "every failed lane green on its classified
   retry" per the battery's own verdict. Extraction gate: 1564 Ring-0
   cases through BOTH libcx.dylib and libcx-core.dylib; ring_import_
   gate + libcx-abi-gate (713 symbols, I3 baseline) green — the W6
   client/profile-ops work touched no ring boundary and no ABI. NEXT =
   W7 (the three-listener parity gate + the CSRP retirement
   enumeration; #718 items 2/3 close in-gate).

## W3 entry note — the op-core seam (recorded before cutting code)

The CSRP router (`store_csrp.v`) does HTTP framing, auth, and error
mapping around calls to **`store_stdlib_builtin_inner(op, args)`** — the
ops themselves are already behind one internal surface. So W3 does NOT
have to disentangle an op pipeline: the profile listener decodes a verb
envelope, calls the SAME inner surface, and encodes the reply. What is
CSRP-specific is exactly what the profile replaces (bearer auth, HTTP
status mapping, the `17xx` band). This is also why L167's parity gate is
tractable: both listeners drive one op core, so op-for-op equivalence
and error identity are properties of the framing layers, not of two
independent implementations.

## Adjudication entries — audit re-adjudication (R1.2–R1.5, ruled 2026-08-07)

The adversarial audit (partition_audit_impl_I0_I5.md, F-2..F-5) found
four W2–W6 spec edits that were made mid-implementation without a prior
recorded ruling (the process breach that triggered the full stop). The
owner re-adjudicated each as if the question had been posed at the
proper time. **All four ruled (a): the shipped text stands AS RULED
TEXT, with the probe evidence recorded here** (partition_remediation_
register.md rows R1.2–R1.5; RULED (a) 2026-08-07).

- **R1.2 (F-2, 25d7c775) — M1/M2/M4 single-scalar offer/confirm shapes.**
  The transcript-signed handshake fields carry the offered/confirmed
  profile+feature sets as SINGLE space-separated scalars, not nested
  child elements. Probe evidence (W2, pinned xsp-auth-025..031): nested
  element children do NOT atomize through the data-bin lane — the same
  offer landed at DIFFERENT byte positions across encode/decode, so a
  transcript signed over the nested form was unstable (bad-signature on
  re-parse). The single-scalar shape keeps the signed transcript
  byte-stable. Alternatives (ii) nested-signed-over-exact-bytes
  abandons canonical-form signing; (iii) fixing data-bin element-child
  atomization touches the I1-frozen identity lane (a new epoch, ruled
  out). RULED (a): single-scalar stands.

- **R1.3 (F-3, f61cb141) — store.md §6.4 scheme + credential vocabulary.**
  Bare `cx-store://` = the profile over TLS; `cx-store+xsp://` = the
  cleartext dev sibling (port explicit); identity via open-opts
  `xsp-did` + `xsp-seed-env` (the seed is ALWAYS an env-var NAME, never
  a literal; URL userinfo refused at parse). RULED (a): the shipped
  scheme + open-opts credential surface stands; the W6 client behavior
  and its tests conform to it.

- **R1.4 (F-4, 8f6832dd) — vp single-scalar carriage.** Same evidence
  class as R1.2: a `[vc]`/`[vp]` crossing the data-bin lane
  re-canonicalizes and its signature dies (probed: `[delegation d-vc-1
  …]` re-parses with a trailing-space id → bad-signature). M3 is
  transcript-signed, so a nested-children vp hits the same W2 trap.
  RULED (a): the single-scalar `[vp "<canonical text>"]` carriage
  stands (and the R3.1 wrong-carriage refusal, CXER5021, guards the
  likely mistake).

- **R1.5 (F-5, 40743e8e) — erased-marker-WINS on the object wire.**
  `objects-get` answers `erased=true` (never the bytes) while the root
  awaits reclamation; `objects-have` keeps it MISSING (serving the
  bytes would leak lawfully-erased content). RULED (a): the sharpened
  §7b.1 rule stands (striking it re-opens the leak window).

These four are RECORD-ONLY adjudications (the text already shipped and
was ruled to stand); no spec text changes under R1.2–R1.5. The process
defect they represent is cured structurally by the R4.1 spec-freeze
gate + the rulings-before-edits protocol (R4.2).

## R1.1(b) — the verb-pushdown spec-first letters (POSED 2026-08-07, awaiting owner ruling)

R1.1 ruled **(b)**: the daemon-side verb pushdown is IMPLEMENTED in
stream 4 (not deferred). Two design points gate the cut and are OPEN
until these letters rule (rulings-before-edits: §6.1 is NOT restored to
its full pushdown contract, and NO pushdown code is written, until the
owner rules). Both letters carry probe evidence, per the R1.1 mandate to
answer the identity question WITH DATA.

### Letter P1 — the wire form of a fn-as-data (fold `$fn` carriage)

**The question.** When a fold/replay `$fn` crosses to be evaluated
daemon-side, in what form does it travel, and how is its identity
established, given that canonical forms are identity-bearing (a canonical
fn carriage is identity-adjacent)?

**Probe evidence (this session, vcx/code/code_identity.v +
cx_text_canonical, recorded runnable):**
- Tier-2 code identity is STABLE and alpha/name/comment/format-
  invariant: `[?def f ($acc $e) [+ $acc $e/@amount]]` and a renamed,
  reformatted, comment-bearing sibling hash IDENTICALLY
  (`sha2-256:8257364117…`), and a distinct computation
  (`[- $acc $e/@amount]`) gets a DISTINCT hash. So a fn HAS a stable,
  clean-room-reproducible canonical identity — the Tier-2 hash
  `code:sha2-256:<hex>` (code-identity.md).
- The DATA canonicalizer is the WRONG carriage: `cx:canonical` over a
  `[?def f ($acc $e) [+ $acc $e/@amount]]` returns
  `[?def f ($acc $e ') ' [+ $acc '$e/@amount'])]` — it quotes the body
  as data and mangles the parameter list; re-parsing it as a def FAILS
  (`CXDEF_PARSE: expected parameter … got [`). This is the R1.2/R1.4
  data-bin trap in its DATA-canonical variant: a program directive is
  not data, so the data lane corrupts it.

**Recommendation (P1-a):** the `$fn` crosses as its **program source
text** carried in a single-scalar canonical-PROGRAM-text envelope field
(the lossless-lane class R1.4 established for signed content — NEVER the
data-bin lane, which mangles it). The daemon re-parses it AS A PROGRAM,
computes its Tier-2 hash, purity-checks server-side (`CXER4611` exactly
as locally, §3), and evaluates. **Identity is the Tier-2 hash, computed
identically on both sides** — no NEW canonical form is introduced, so no
identity fork. The client SHOULD additionally send the fn's Tier-2 hash
alongside; the daemon recomputes and REFUSES on mismatch (a tamper /
version-skew guard). For dedup, the fn MAY be pre-stored as a `code:`
content object and referenced by its Tier-2 hash, but the primary
carriage is the self-contained program source (the daemon can
purity-check + evaluate with no prior store round-trip).
- Alternative P1-b: carry ONLY the Tier-2 hash; require the fn
  pre-stored as a `code:` object; daemon resolves it. Rejected as
  primary: forces a store round-trip before any fold and fails closed
  when the object is absent — but it is the natural dedup optimization
  ON TOP of P1-a.
- Alternative P1-c: carry ast_bin of the fn body. Rejected: re-introduces
  the element-child atomization instability (R1.2/R1.4) on the identity-
  bearing lane — the exact class this campaign is closing.

### Letter P2 — snapshot-signing key custody

**The question.** `snapshot`/`snapshot-verify` produce/verify a SIGNED
checkpoint (§4.8) with a client key. Under daemon-side pushdown, who
holds the signing key?

**Evidence / constraint.** A client signing key crossing to the daemon
is an absolute non-starter (it would let the daemon forge the client's
non-repudiation). The signed snapshot's whole value is that it is the
CLIENT's attestation over a chain state.

**Recommendation (P2-a):** the **signing verbs stay client-side-eval**
— `snapshot` (and any verb that signs) is NOT pushed down. The daemon
serves the `fold-from` reconstruction state over the object wire
(cheap — it is content-addressed); the client computes the checkpoint
and signs LOCALLY. Pushdown covers the NON-SIGNING long reads/folds
only: `read`/`slice`/`since`/`query`/`replay`/`fold`/`fold-slice`/
`fold-value`/`dry-run`/`verify`/`verify-slice` (`verify` checks chain
bytes — no key). This keeps the key-custody rule ABSOLUTE (no client
signing key on the wire, ever) AND still delivers the pushdown win
where it matters (folds over logs that dwarf their queries — the §6.1
growth-path rationale). The applicability matrix (§7) marks
`snapshot`/`snapshot-verify` remote as "client-eval over the served
state", distinct from the pushed-down reads.
- Alternative P2-b: the daemon signs snapshots with its OWN XSP-AUTH DID
  key. Shifts non-repudiation from the client to the daemon — a
  DIFFERENT security property, viable for daemon-authoritative
  deployments but NOT a drop-in for the client-attestation contract.
  Offered for the owner; not recommended as the default.

**On ruling:** with P1 + P2 ruled, §6.1's "Growth path (recorded, NOT
part of the exit gate)" paragraph is RESTORED to the full pushdown
contract under the rulings (the d7ca927b truing reversed), the §7
matrix annotated for the client-eval signing verbs, and the pushdown
is implemented with per-verb fixtures joining the W7 parity/error-
identity gate (op-for-op equivalence across client-eval vs pushed-down
for every non-signing verb; identical Tier-2 hash + `CXER4611` on both
sides). No §6.1 restoration or code lands before the rulings.

## CSRP retirement — demolition map (R4.4-a, ruled 2026-08-08; oracle = local engine, NOT a parity gate)

Blast-radius survey done BEFORE cutting (2026-08-08). The retirement is
NOT a `grep csrp | delete` — the `csrp_`-prefixed code splits into two
populations that must be handled OPPOSITELY:

**A. DELETE — the CSRP wire/router/auth (no non-CSRP, non-test consumer):**
- `store_csrp.v` (router + 17xx remap), `store_csrp_binary_route.v`,
  `store_csrp_client_bin.v`, `store_csrp_wire.v` — whole files.
- `store_authz.v` WHOLE — its only non-test consumer is store_service.v's
  HTTP bearer plane (`svc_authenticate`/`svc_authorize`/`new_key_cache`);
  the profile uses XSP-AUTH (store_xsp_authority.v), never this.
- The CSRP store router IN store_service.v: `store_csrp_route` dispatch
  (lines ~1291, ~1557), bearer auth calls, the `[auth [bearer …]]` advert
  arm. REDUCE store_service.v to: profile-op routing (svc_profile_data_op,
  KEEP) + bootstrap HTTP = health/ready/metrics/capabilities ONLY.
- Tests: store_csrp_test.v, store_csrp_conformance_test.v,
  store_csrp_wire_tagged_test.v, store_binary_wire_test.v (+ any
  bearer-plane assertions in store_service_test.v / store_wire_wave4_test.v
  — triage per-assert, don't blind-delete).
- Transitional `cx-store+http/https` schemes (store_remote.v csrp_scheme),
  `[$store:csrp-handle]` (stdlib_store.v:2022), 17xx band → Reserved
  (governance §9.6).

**B. RELOCATE + RENAME — misnamed generic helpers the PROFILE depends on
(deleting store_csrp.v would gut the profile):**
- `csrp_attr` / `csrp_scalar` / `csrp_msg_esc` (defined in store_csrp.v)
  are used by 10 profile/core files (store_profile_ops, store_xsp_serve
  /feed/peer/advert/client, store_porcelain, store_reload,
  store_remote_object, store_service). They are generic CX
  attr/scalar/message-escape utilities with a wrong prefix. MOVE to a
  neutral home (store_wire_util.v) and rename (wire_attr/wire_scalar/
  wire_msg_esc) BEFORE deleting store_csrp.v. Same for
  csrp_child_text/csrp_attr_of/csrp_child_scalar in store_csrp_client_bin.v
  IF any survivor uses them (else they die with the file).

**Sequencing — UNIFIED with the F2 computation-identity rip-out** (both
touch store_service.v + store_objgraph.v + store_authz.v; touch each
file ONCE). Final stage order set after the F2 spectrum-audit table
lands. Each stage ends green on the store batteries + full `make test`.
Provisional stages:
  S1. Relocate+rename the generic helpers (B) — pure move, green. DONE (ed2c7fa8).
  S2. F2 rip-out: computation-identity-as-address → F1' opaque-document
      surface (put-blob/get-blob), pure [$cx:computation-id] claim,
      legacy code-record loud refusal. DONE (c42e8b15/ab463c35/7b328e7a/
      a3e6588b).
  S3. Delete the CSRP wire/router/authz (A); reduce store_service.v to
      bootstrap-HTTP-only; retire schemes/csrp-handle/store-token;
      per-call XSP-AUTH gRPC edge (G1a); bindings cut over to the
      embedded XSP client (Python/Go/Rust). DONE (abaea9b9).
  S4. Corpus + spec deprecation sweep: cxstore-remote-protocol.md →
      RETIRED/historical, governance 17xx → Reserved, store-022 →
      cx-store+xsp, gates prose. DONE (6f10e7e7).
  S5. Epoch ratification (F6) — DONE (RULED (a), owner, 2026-08-08:
      the packet + the corrected identity corpus RATIFIED in the
      F6(b) one pass; I1 epoch corpus SEALED AS AMENDED; evidence =
      the packet's S5 addendum + full `make test` rc=0 @ 352619d5).
  S6. Pushdown (F3 generation-watch + F4 delegable budget + F5 snapshot
      signing) on the clean foundation — the next IMPLEMENTATION phase;
      owner-sequenced (rides the W7 parity/exit gate, now two-listener:
      XSP profile + gRPC edge).

## Letter F1' — documents split by identity rule; the store's verbatim surface (POSED 2026-08-08, evidence-first)

**Supersedes the F1 wording only where stated; poses the verbatim
surface. Evidence = the COMMITTED battery
`vcx/platform/store_verbatim_roundtrip_evidence_test.v` (green,
landed BEFORE this letter per the evidence-before-ruling rule).**

**What the evidence shows.**
1. Structured cx data round-trips CANONICALIZED through
   put-doc-text/get-doc-text — correct and required (the content
   address is the hash of canonical bytes).
2. A def simple enough to survive data-canonicalization round-trips —
   the unrepresentative case the reverted S2 premise was declared on.
3. The shipped dir-sync `greet` def (string-literal body) MANGLES
   through the document path: data canonicalization rewrites code's
   concrete syntax and the result no longer parses as the same
   program. 4. The lossless formatter is not a verbatim substitute.
5. (Standing, from the W5 wire fixtures) the OBJECT layer preserves
   bytes exactly — objects-put/get round-trip content-addressed blobs
   byte-for-byte; the retired put-def stored code through exactly that
   raw-leaf machinery, mis-keyed by computation identity.

**The amended principle (F1').** Documents are the only object kind —
unchanged. Documents split by IDENTITY RULE:
- **Structured documents** (cx data): identity = hash of CANONICAL
  bytes; normalization is meaningful and the canonicalized round-trip
  is the contract. Everything shipped today.
- **Opaque documents** (CX code, images, plain text — anything whose
  bytes ARE the content): identity = hash of the RAW bytes; the store
  round-trips them BYTE-EXACT; no canonicalization ever applies.
Code is an OPAQUE document. Computation identity remains a derived
relation over opaque documents that parse as programs — an index or
recompute-and-refuse claim, never an address (F1/A1 unchanged).

**The surface (the capability the put-def wart was masking).** The
store gains a general verbatim pair — `put-blob` / `get-blob`
(working names): put returns the raw-bytes document identity
(`sha2-256:` over the bytes as given); get returns the bytes exactly;
`exists`/aliases/objects/migrate/clone/feed treat blob documents
uniformly (they are ordinary content-addressed objects — the object
layer already carries them). Every storage path verifies
key == hash(raw bytes) on load — no skip-verify class returns. The
dir-sync recipe ingests `.cx` (and any opaque file) via put-blob,
`.cxd` structured data via put-doc-text; materialize is byte-exact
for both.

**Non-options, recorded:** storing code via put-doc-text (mangles);
a fmt-canonical storage form (evidence pin 4; and it would mint a NEW
identity-bearing canonical form — the R1.1 hazard); re-keying
structured data to raw bytes (destroys canonical dedup + the epoch).

**On ruling:** F2's re-run proceeds with executed checks; the rip-out
re-executes on the corrected premise (put-def/get-def retire in favor
of put-blob/get-blob + the pure [$cx:computation-id]); store.md +
cx.md + corpus land under the ruling; dir-sync round-trip green
byte-exact is the acceptance fixture.

## S6 letters

### Letter J1 — `fold-value` is client-eval only (POSED 2026-08-08; accepted under the standing acceptance ruling; RATIFIED (a) BY OWNER 2026-08-09 — entry 15)

**The question.** F5(b)'s eligible-verb enumeration (inherited from the
P2 letter) lists `fold-value` among the non-signing pushdown verbs.
Should it get a wire form?

**The fact that decides it:** `fold-value` is the PURE core (§3.4) — it
folds an **already-materialized** `[sequence element]` of entries with
NO backend access. Its input data lives client-side by definition. A
wire form would ship the entries TO the daemon to compute over them —
the exact inverse of the pushdown rationale (move the compute to the
data). `fold`/`fold-slice` — which read the daemon-side log — ARE the
pushdown forms of the same computation.

**Recommendation (J1-a, adopted):** `fold-value` stays client-eval
only; the §4.3 family covers `fold`/`fold-slice`/`replay`/`dry-run`
(compute-class) and the read/verify rows. No capability, error row, or
parity lane exists for a `journal-fold-value` wire verb. Verified
against the long-term-best bar: adding the verb would create a
data-upload evaluation channel with budget exposure and zero locality
win; any client holding materialized entries can fold them locally by
construction.
- Alternative J1-b: mirror every enumerated verb 1:1 onto the wire for
  vocabulary symmetry. Rejected: symmetry of NAMES is not op-for-op
  parity of BEHAVIOR; the G13 lanes pin fold ≡ fold regardless.

**RATIFIED (owner, 2026-08-09 — rulings 1a/2a at the post-exit review;
review flag CLEARED).** Adjudicated under the ORTHOGONALITY objective
(a concept, once introduced, applies broadly; exceptions possible but
rare and real): J1-a stands as a **concept-boundary consequence, NOT
an exception** — pure folds over values (concept 1) are already
maximally orthogonal, running wherever the values live, and a wire
form would BIND that concept to one transport, narrowing it; pushdown
evaluation (concept 2 — client-supplied pure code to daemon-resident
data under budget + capability) does not contain `fold-value`, whose
input is client-held by definition. The debt the review exposed —
concept 2 currently applies to ONE plane — is filed as **#751**
(generalize the §4.3 compute family to store-resident documents; the
S6 substrate reuses as-is; design-first, unscheduled).

## Work log (S6)

9. **S6.1 — pushdown spec surgery LANDED (2026-08-08, RULED:
   F3+F4+F5+R1.1(b)+R4.4(a-revised)).** xsp_store_profile.md NEW §4.3:
   the journal pushdown verb family (feature token `store-journal`,
   transcript-bound): 11 wire verbs — journal-read/-slice/-since/-query
   (read-class; slice/since/query as credit-governed event streams),
   journal-verify/-verify-slice/-snapshot-verify (read-class;
   verification values ride VERBATIM — a finding is data),
   journal-fold/-fold-slice/-replay/-dry-run (compute-class). Fn
   carriage per F3(a): fn= the OPAQUE def document's address (put-blob;
   raw-byte identity verified on load) + MANDATORY
   claim="computes-as:<algo>:<hex>" recomputed over the parsed entry
   def, refused on mismatch; module docs = dependency closure, entry=
   selects; helper defs covered by the document identity. Purity =
   server-side CXER4611 VERBATIM. Budget per F4(a): [xsp [limits
   [pushdown steps= memory-mb=]]], named defaults, unbounded
   unspellable, CXER5024 typed refusal w/ [conjunct :steps|:memory];
   evaluations serialize under the mount op lock (attributable memory
   metering). Custody per F5(b): snapshot NOT a wire verb (key never
   travels; daemon serves state); snapshot-verify pushes down;
   `snapshot-sign` capability row = the appointed signer (WHO signs,
   never WHERE the key lives). NEW capability rows compute +
   snapshot-sign (§6.1); error rows CXER5023 (claim mismatch), 5024
   (budget), 5025 (fn violation) in §4.2. §9 G13 text conformed to
   R4.4(a-revised) (embedded-engine oracle, TWO listeners). journal.md
   §6.1 growth-path paragraph → the NORMATIVE pushdown contract under
   the rulings (the d7ca927b-class deferral text retired the ruled
   way); §7 matrix gains the pushdown-equivalence + budget property
   rows and footnote 10 (remote snapshot = client-eval over served
   state). Letter J1 (fold-value client-eval-only) posed + accepted
   under the standing acceptance ruling, FLAGGED FOR REVIEW above.
   Deliberate non-verbs recorded in §4.3 (append/head/streams ride the
   shipped v1 carriage; retain/compact/fold-from = owner-side
   maintenance). Spec-only commit; implementation follows S6.2 (budget
   substrate) → S6.3 (verbs) → S6.4 (appointed-signer + porcelain) →
   S6.5 (G13 lanes + full gate).

10. **S6.2 — the F4 evaluation-budget substrate LANDED (2026-08-08,
   RULED: F4).** `code.arm_eval_budget(mut env, steps, mem_bytes)` arms
   an `&EvalBudget` on the evaluation env, shared by pointer through
   every same-thread env derivation (the current_worker propagation
   rule; spawned contexts deliberately start nil — a budgeted pushdown
   evaluation is PURE, so it cannot spawn). The check rides `eval_node`
   — the same single-funnel point as the #319 stack guard: steps =
   eval_node entries; memory = MONOTONE allocated bytes against the
   arm-time baseline (NEW V-fork builtin `gc_total_allocated()`,
   a8a7024f80 — one atomic load of vgc's total_alloc / Boehm
   GC_get_total_bytes; monotonicity makes the meter immune to
   collection dips), sampled every 64 steps. `CXER0273
   E_EVAL_BUDGET_EXCEEDED` allocated in the 0270–0279 host-capability
   band (code.md §9.4 rows, same-change per #717), deterministic
   message naming the conjunct + limit; the profile's wire row is
   CXER5024 (§4.3). TWO mechanism findings, both pinned by the test:
   (a) the refusal must ride the THROWN channel (EvalError), not an
   err VALUE — the streamed iterator/yield hot paths collect result
   nodes without err-introspection, and a value-form refusal was
   MEASURED being collected (an armed 100-iteration count answered
   100 with the latch tripped at step 6); (b) the trip LATCHES
   (tripped_conjunct) — without the latch a memory-only budget
   (64-step sampling) would admit up to 63 handler steps between
   refusals, so a handler could absorb-and-progress. Fixture-first:
   vcx/tests/eval_budget_test.v ran RED (all four refusal lanes:
   programs completed 1000000/50000) before the check landed, GREEN
   after — 7 lanes: step refusal, memory refusal, unbudgeted control,
   generous-budget control, step terminality through [?fallback],
   memory terminality (the latch lane), arming asserts. Regression:
   full code_eval_fixtures battery green (unbudgeted evaluation
   byte-identical), cxer-registry gate green, eval suites green.

11. **S6.3 — the journal pushdown verb family LANDED (2026-08-09,
    RULED: F3+F4+F5+F1'+R1.1(b)+R4.4(a-revised)).** The §4.3 family on
    the profile listener + the embedded client, oracle = the local
    engine.
    - **store_xsp_journal.v:** 11 verbs. read-class (journal-read reply;
      journal-slice/-since/-query as credit event streams;
      journal-verify/-verify-slice/-snapshot-verify — verification
      values VERBATIM). compute-class (journal-fold/-fold-slice/
      -replay/-dry-run). Fn carriage F3a: fn= the OPAQUE def document by
      address (store-get-blob, raw-byte identity verified on load) +
      MANDATORY claim=computes-as:<algo>:<hex> recomputed over the
      PARSED entry def (code.cx_program_entry_computation_id, NEW —
      defs-only program shape enforced there) and refused on mismatch
      CXER5023. Purity = server-side CXER4611 VERBATIM. Budget F4a: a
      fresh env armed with cfg.pushdown_steps/mem before eval; the
      engine's CXER0273 answers as the profile's CXER5024 [conjunct
      :steps|:memory]. Read-only journal attach per request.
    - **THE WIRE F1' PAIR (found missing):** a remote put-blob wrote
      only the client's LOCAL mirror — the fn-document carriage had no
      transport. Added put-blob/get-blob §4.1 rows (RULED F1'+F3+R1.1)
      + serve arms + xsp_client_put_blob/get_blob + store_remote_blob_
      put/get (gRPC edge refuses LOUDLY until its op set gains them —
      no silent local mirror) + the stdlib_store remote branch. get-blob
      absence crosses the embedded surface's CXER1121 VERBATIM.
    - **TWO carriage fixes:** an EMPTY [attach] (sole-store shorthand)
      ATOMIZES to attach=null through the data-bin frame (the W2 rule's
      degenerate case) — stdlib_xsp_auth validate_prove and
      stdlib_session attach-xsp now read attach child-OR-attr (the
      shorthand had NO live consumer until the pushdown client drove it).
      Corpus pin xsp-auth-032. Config: [xsp [limits [pushdown steps=
      memory-mb=]]] (positive-only, unbounded unspellable). Authority:
      NEW compute + snapshot-sign capability classes; get-blob=read,
      put-blob=write.
    - **THE V-RUNTIME BUG (#749, filed prio:high):** the store_xsp_
      journal_test streams originally held the []cx.Element from the
      collecting xcl_stream → SIGSEGV in cx__Element_free under -gc e.
      Root-caused DECISIVELY: -gc none + ASAN runs the WHOLE flow clean
      (zero findings, all asserts pass) and VGC_NEXT_GC_MB pinning does
      not help → a V compile-time autofree double-free of a held
      decoded-element slice's shared items backing, NOT a logic UAF and
      NOT the tracing collector. Interim (owner ruling (a)): a count-only
      client helper xcl_stream_count (returns int, never a held node
      slice) verifies stream cardinality; content decode stays covered
      by the read + parity fold lanes. Test split into three focused fns
      (parity/reads/refusals), each its own daemon boot.
    - **Coverage green under -gc e (3/3):** parity (blob byte-exact over
      wire; pushed-down fold/fold-slice/replay BYTE-IDENTICAL to the
      client-eval oracle; dry-run persists nothing), reads (read+absence,
      slice/query/since cardinality, verify/verify-slice, junk-snapshot
      refusal), refusals (CXER5023 claim, CXER5024 budget+conjunct,
      CXER4611 impure-declared-def verbatim, CXER5025 defs-only + bad
      entry). store_xsp_serve_test token-gate lane (CXER5012 un-negotiated
      store-journal) + capabilities advert pin updated. Gates:
      code_eval_fixtures (xsp-auth-032) green, verify-doc-blocks 317/0,
      cxer-registry OK, check-code-spec-consistency green. NEXT: S6.4
      (snapshot signed round-trip + appointed-signer + porcelain), S6.5
      (G13 families incl. gRPC-edge blob+journal parity).

   **S6.3 WAVE-GATE VERDICT (2026-08-09): validated lane-by-lane; a
   single clean-shot full `make test` was environmentally blocked, NOT a
   code defect.** test-vcx-code (every code/platform file this change
   touches) = 82/82 GREEN, incl. store_xsp_journal_test. test-vcx-suite =
   238 OK incl. the modified store_xsp_serve_test (210/241 OK); its only
   non-passes were all proven environmental and pass standalone:
   fabric_serve_test (socket-timing flake under load — OK 25s standalone),
   code_diagram_roundtrip_test (hung under marathon memory pressure — OK
   8s standalone), fabric_nats_bridge_test (the standing #572 -usecache
   compile flake). code_eval_fixtures (xsp-auth-032), verify-doc-blocks,
   cxer-registry, check-code-spec-consistency all green. ROOT CAUSE of the
   no-clean-shot: I had to `rm -rf ~/.vmodules/.cache` (my own debug
   thrashing had poisoned it → 156 stale-symbol link fails), which forced
   a COLD 241-file -j12 compile+run marathon that exhausted machine memory
   and flaked/hung socket + vgc-heavy tests. The cache is warm again now;
   the warm-cache full gate rides S6.4 as the clean-shot for the
   accumulated commits. (Also fixed: test-vcx-cmd gained the #572
   cache-free retry it lacked, 0f2e501c.)

## Letter S6.4 — the appointed-signer surface (F5(b)), POSED 2026-08-09; accepted under the standing acceptance ruling

**F5(b) is RULED** (client-signs default; the appointed-signer capability
is specced this pass through the existing credential model — one row, no
new machinery). This letter fixes the design points the implementation
needs, all forced or strongly indicated by existing frozen contracts.

**The hard constraint.** journal §4.8's signed preimage `snapshot-canonical`
is FROZEN (I1 epoch; the `fold-id` slot was reserved specifically so no
second signing epoch is ever minted). Therefore the appointed signer's
IDENTITY MUST NOT enter the signed bytes — adding a `signer` field to the
preimage would be a new signing epoch, forbidden.

**Design (recommended — S6.4-a):**
1. **Signer identity rides as an UNSIGNED outer hint, bound by the
   signature.** The signed `[snapshot …]` value gains an outer
   `signer="<did>"` attribute ALONGSIDE `sig-algo=`/`signature=` — NOT in
   the `snapshot-canonical` preimage. It is a HINT telling `snapshot-verify`
   which public key to check against; it is not itself signed, and it
   cannot be forged usefully: `snapshot-verify` verifies the signature over
   the recomputed frozen preimage using the key resolved from `signer`, so
   a mismatched `signer`/key fails step 2. Absent `signer` = the pre-S6.4
   behavior (verify against a caller-supplied key), fully back-compatible.
2. **`snapshot-verify` stays a pure public-key check (F5(b): "pushdown-safe").**
   It resolves the signer key (from the `signer` did:key, or a
   caller-supplied key as today), verifies the frozen-preimage signature,
   and checks `anchor-hash`. It does NOT by itself consult the authority
   model — appointment is a SEPARATE, explicit check (next point), so the
   pushdown `journal-snapshot-verify` (S6.3) needs no authority state and
   stays pushdown-safe unchanged.
3. **Appointment enforcement is an authority-model check, distinct from
   crypto verify.** "Is this signer the org's APPOINTED signer for this
   scope?" = does the `signer` DID hold `snapshot-sign over <scope>` in the
   org's grants/delegations. This rides the EXISTING VC-compiled capability
   path (profile §6.1) — `snapshot-sign` is already a capability row. A
   caller that requires appointment (not mere self-attestation) verifies
   BOTH: (2) the crypto signature AND (3) the `snapshot-sign` grant for the
   `signer` DID. Client-signs default = signer is self; no appointment
   needed (self-attestation). Appointed = signer is the designated principal
   holding the delegation; the signing KEY still never travels (it lives in
   the signer's own env / HSM — the daemon never sees it, F5(b)).
4. **Porcelain (client-side eval per F5(b) — `snapshot` is NOT a wire
   verb):** `$journal:snapshot` gains `opts.signer` (the DID recorded as the
   outer hint; default = the handle's own identity) — signing still uses
   `opts.signing-key` (the appointed signer's key, in the signer's env).
   Over a `cx-store+xsp://` handle, `snapshot` fetches reconstruction state
   via the S6.3 pushdown reads/object wire and signs LOCALLY;
   `snapshot-verify` rides the pushdown `journal-snapshot-verify`.
   `snapshot-verify` gains `opts.require-appointed` (+ the scope) → also
   runs check (3); omitted = pure crypto verify (back-compatible).

**Alternatives (rejected):** (i) put `signer` in the preimage — forbidden
(new signing epoch). (ii) make `snapshot-verify` always enforce appointment
— breaks the client-signs-default self-attestation case and the
"pushdown-safe pure check" ruling; appointment is opt-in policy. (iii) a
new "appointed-signer" credential type — F5(b) says one capability row, no
new machinery; `snapshot-sign` already exists.

**On acceptance (standing ruling — verified long-term-best):** journal
§3.7/§4.8 gain the `signer=` outer hint + `opts.signer`/`opts.require-
appointed` (additive, preimage untouched, back-compatible); profile §4.3
notes `journal-snapshot-verify` stays pure and appointment is the caller's
separate §6.1 check; new CXER rows only if a new refusal is needed
(appointment-failed reuses the authority refusal CXER4700-band / the
journal's snapshot-verify finding shape — NO new epoch, NO preimage change).
Per-verb fixtures: self-signed verify (default), appointed-signer verify
(signer holds snapshot-sign → valid), forged-signer (sig mismatch → invalid),
appointment-required-but-ungranted (→ refused). Impl is the next S6.4 step.

## Work log (S6, continued)

12. **S6.4 — the appointed-signer surface LANDED (2026-08-09, RULED:
    S6.4-a).** Commits 7385f131 (spec) → f8f813e9 (spec addendum) →
    e2b1c4ca (impl+fixtures).
    - **Spec (additive; the §4.8 preimage FROZEN, byte-unchanged, no
      second signing epoch):** journal §3.7 — `snapshot` gains
      `opts.signer` (the UNSIGNED outer `signer="<did>"` attribute
      alongside sig-algo=/signature=; default = the handle's own
      identity ONLY when it equals the signing key's derived did:key —
      a hint that could not verify is never manufactured; `sign=false`
      + `opts.signer` = the authoring-time misuse CXER4610);
      `snapshot-verify` gains `$opts::map {}` — the verify key resolves
      FROM `signer=` when present (did:key/did:peer:0 offline; never
      the unsigned verify-key= field; unresolvable →
      `:signer-unresolvable`, mismatched → `:signature-invalid`) and
      `opts.require-appointed` (+ `opts.authz` [authz-store] registry
      handle + `opts.scope`) runs the DISTINCT appointment check —
      signer holds `snapshot-sign` per the §6.1 capability calculus —
      failing as the FINDING `valid=false reason=:not-appointed` with
      the registry's `[deny …]` as its child (misuse without an open
      registry handle = CXER4610). §4.8 outer-hint paragraph; §6.1 +
      profile §4.3 pin the pushdown verb UNCHANGED on the wire (no new
      fields, no authority state — pushdown-safe per F5(b)); §10 rows.
    - **Impl (stdlib_journal.v + stdlib/journal.cx def):**
      jrn_build_snapshot gains the signer param; jrn_snapshot_check
      resolves signer-hint keys via did_key_bytes (shared by the local
      porcelain AND the daemon's pushdown verb — one check, both
      listeners); jrn_snapshot stamps opts.signer / the
      identity-equality default (session did via ms.remote.xsp.did ==
      did_key_from_seed(seed)); jrn_snapshot_verify takes $opts, and
      over a cx-store(+xsp):// handle routes the crypto check through
      the pushdown journal-snapshot-verify (ONE exchange, the anchor
      checked against the daemon's AUTHORITATIVE chain, findings +
      refusals verbatim); jrn_snapshot_appointment runs authz_decide
      over the caller-designated registry (actor=signer,
      capability=snapshot-sign, slice=scope, tenant=the registry's own
      — mirroring the PEP's request shape; no as-of, exactly
      authz-check's default posture).
    - **Fixtures:** journal-072..075 (self-signed hint stamped
      byte-exact incl. the 128-hex deterministic ed25519 signature;
      appointed-valid via a root [delegation … [capabilities
      [snapshot-sign]] [over '/ledger']]; forged signer — signed by
      seed-A claiming seed-B's did with verify-key=pubA PRESENT →
      `:signature-invalid` proves signer-resolution beats the carried
      key; ungranted → `:not-appointed` + [deny [code CXER4700]
      [reason :no-grant] …] child). V wire lane: NEW
      test_store_xsp_journal_snapshot_porcelain (mutual session via
      open-opts xsp-did/xsp-seed-env; default signer= = session
      identity; pushdown verify valid=true; forged signer over the
      wire → `:signature-invalid` — daemon-side resolution proven).
    - **Gates:** code_eval_fixtures_test green (journal suite 75 cases
      incl. the four new; every pre-S6.4 pinned artifact byte-identical
      — the back-compat claim is TESTED, not asserted);
      test-vcx-code **82/82** (incl. store_xsp_journal_test's four
      fns). The WARM full `make test` clean-shot rides S6.5 per the
      S6.3 verdict.

13. **S6.5 — the G13 parity families + gRPC-edge blob parity LANDED
    (2026-08-09, RULED: R4.4(a-revised)+L167+R2.5).** Commits 5693d870
    (spec) → adcac30d (impl + battery). The W7 parity-gate deliverable,
    built once over the complete post-pushdown surface, two live
    listeners, embedded-engine oracle.
    - **gRPC-edge blob pair:** PutBlob/GetBlob on the edge (the Put/Get
      message shapes reused with `encoding "raw"`; PutBlob's reply hash
      field = the blob KEY; absence maps 404/1721 on the wire and the
      client re-derives the blob surface's CXER1121 — cross-transport
      identity). svc_profile_data_op gains the put-blob/get-blob arms
      (raw octets verbatim; CXER1121→404/1721 exactly like `get`);
      store_remote_blob_put/get route the gRPC schemes to the new
      client fns — the S6.3 refuse-loud placeholder retired.
    - **G13 CATCH (the battery's first run):** GrpcObjWireTransport
      collapsed EVERY non-zero grpc status to 500 — an aliases-set to
      an absent target surfaced CXER1101 on the edge while the profile
      said CXER1121 (error-identity break on the whole gRPC object
      wire: 1121/1114/authz/rate all indistinguishable). Fixed: the
      transport maps the trailer's exact CXER (fallback: coarse
      grpc-status) onto the SAME statuses xcl_ow_status surfaces
      (404/409/403/429), so the store arms re-derive identical codes
      on both wires.
    - **store_g13_parity_test.v — five families** (oracle ≡ XSP ≡ gRPC,
      one daemon, both listeners, focused fns): (1) docs/blobs/delete —
      content-address identity, blob byte-exact round-trip of
      deliberately NON-canonical bytes, absence-code identity, delete
      parity; (2) aliases — set over gRPC read over XSP (the #718
      item-2 AliasesSet lane), explicit-absence parity, absent-target
      CXER1121 identity; (3) streams — list + query result-SET identity
      cross-wire (the #718 item-3 list-shape reconciliation, live);
      (4) journal — ONE chain through both wires (byte-identical
      entries), stale-tail CXER1114 identity, fold ≡ the local oracle's
      state, verify-finding identity, and the S6.4 signer surface both
      ways (default signer= on the gRPC handle via rb.did — the one
      identity slot both wires fill; pushdown verify ≡ wire-read local
      check, finding-identical; forged signer identical both wires);
      (5) admin — status shape, config-reload BYTE-parity (the item-2
      Reload lane), and the capabilities advert pinned honest.
    - **#718 dispositions:** item 2 CLOSED (cxstore-grpc.md §2 lists
      the complete 21-RPC surface; Aliases/AliasesSet/Reload driven by
      the battery). Item 3 CLOSED: list-shape = the live cross-wire
      result-set lane (the text-vs-binary CSRP route died at S3);
      compression advert now claims ONLY `none` (nothing implements a
      wire compression lane — the advert stated capability it did not
      have); retired-URL-params moot (store_csrp.v deleted at S3).
      Feed/∂/credit/advert families remain profile-listener lanes
      (the gRPC edge has no feed plane by design) and stay green in
      store_xsp_serve_test — the cross-listener families are exactly
      the ops both listeners carry.
    - **WAVE GATE — THE WARM FULL `make test` CLEAN-SHOT: rc=0**
      (2026-08-09, the shot the S6.3 verdict deferred, covering
      S6.3+S6.4+S6.5): test-vcx-code **83/83** (the battery is the
      +1 file); test-vcx-suite **240/241 + the standing #572
      -usecache fabric_nats_bridge flake green on its classified
      cache-free retry** (R:0.000ms link-stage signature, the
      documented class); cmd lane green; corpus lanes green (fmt
      12/12 tail). Machine pre-verified (76% memory free, warm
      ~/.vmodules/.cache, no orphaned binaries — the S6.3 lesson
      applied). **S6 (S6.1–S6.5) is COMPLETE; the stream-4 pushdown
      program (F3/F4/F5 under R1.1(b)/R4.4(a-revised)) is delivered.**

14. **STREAM-4 EXIT (2026-08-09, ruled (a) at the S6.5 close-out
    question) — the exit gate verified clause-by-clause; the stream is
    EXITED; #676 + #718 CLOSED.**
    - **Clause "spec conformance fixtures green":** the warm full
      `make test` clean-shot rc=0 (entry 13) runs the whole corpus —
      xsp.cxd (G8, W3), the store-blob rows, journal-001..075 (incl.
      the S6.4 signer rows), the profile fixture families, fmt tail
      12/12. VERIFIED.
    - **Clause "gRPC-style parity suite passes over the XSP store
      profile"** — read under the CONFORMED shape (RULED:
      R4.4(a-revised): CSRP died at S3, so no three-listener gate; the
      oracle is the LOCAL EMBEDDED ENGINE, the same families run
      across the TWO live listeners): store_g13_parity_test five
      families green (entry 13 — addresses, blob byte-exactness,
      CXER-code error identity incl. the collapse-to-500 catch, stream
      result sets, journal one-chain-two-wires + CAS + the S6.4 signer
      lanes, admin Reload byte-parity); store_xsp_journal_test
      pushed-down ≡ client-eval byte-identical (S6.3);
      store_xsp_serve_test profile families (W3–W5). VERIFIED.
    - **Clause "then the CSRP data plane removed":** the S3 demolition
      (abaea9b9) — store_csrp*.v + store_authz.v + csrp-handle +
      `cx store-token` DELETED; cx-store+http(s) refuse at open; HTTP
      = bootstrap-only; `[auth …]` config a hard error. VERIFIED.
    - **Clause "xsp-auth/2/ → /3/ HKDF label bump":** W2 (entry 3) —
      all five labels bumped, the label IS the version handle, a /2/
      transcript is not replayable at /3/ (fixture 26). VERIFIED.
    - **Clause "#718's downgrade-strip security item verified in the
      same cut":** W2 fixtures 25 (intersection) + 26 (strip breaks
      the signature) — the M1/M2 offers + M4 confirm ride the signed
      transcript. VERIFIED.
    - **#718 inventory, all seven items:** 1 = W2 (above); 2 = S6.5
      (the 21-RPC §2 listing + the Aliases/AliasesSet/Reload battery
      lanes); 3 = S6.5 (list result-set lane live cross-wire; the
      compression advert claims only `none`; retired-URL-params MOOT —
      store_csrp.v died at S3); 4 = W1/L166 (CXER5000–5049 + numeric
      allocations + 17xx Reserved); 5 = W1 (the `rotate` token in
      xsp.md §5.0); 6 = W1/S4 (the "permanent" sentences struck;
      cxstore-remote-protocol.md retired); 7 = W1 + S6.1 (journal.md
      §6.1 normative for the PROFILE incl. the ruled pushdown
      contract). **#718 CLOSED.**
    - **Riders (I4 ruling R1) — recorded, NOT exit blockers by the
      ruling's own text:** W8 = libcx rings-0–1 re-cut + ABI-baseline
      move + bindings v1 surface + auto-mirror lane ride the FIRST
      RELEASE CUT after I4. They start with the v0.16.0 cut decision,
      not with this stream.
    - **Open flags recorded at exit:** (i) letter J1 (fold-value
      client-eval-only) stands accepted under the standing acceptance
      ruling, FLAGGED FOR REVIEW — owner eyeball pending, effective
      meanwhile [RESOLVED at entry 15: ratified (a), flag cleared].
      (ii) The W6 §6.1 truing flag (entry 8) is SUPERSEDED —
      resolved the ruled way by the halt → audit (F-1..F-30) →
      remediation register → S6.1 restoration chain. (iii) #749 V
      -gc e autofree double-free (prio:high, V-runtime, count-only
      client helper interim); #742 release-side dylib-collector verify;
      #743 vgc SIGURG vs Go hosts (interim pinned on test-go lanes);
      #744 columnar backend uncompilable since I3 — all filed, none
      stream-gating. (iv) No wire-compression lane exists anywhere;
      the advert now says so honestly; a future lane is a fresh design
      item, not a debt of this stream.

15. **J1 RATIFIED + the orthogonality follow-up FILED (2026-08-09,
    post-exit; owner rulings 1a/2a).** The J1 review flag is CLEARED:
    ratified (a) as a **concept-boundary consequence, not an
    orthogonality exception** — the full adjudication is recorded at
    the letter itself (§"Letter J1", RATIFIED paragraph): pure folds
    over values are already maximally orthogonal (they run wherever
    the values live; a wire form would bind the concept to a
    transport), and the pushdown concept's domain — daemon-resident
    data — excludes `fold-value` by definition. The exposed debt —
    pushdown evaluation applied to only one plane — is **#751**:
    generalize the §4.3 compute family to store-resident documents
    (pure-fn map/reduce over matched docs beyond the CXPath
    filter/aggregate pushdown); the S6 substrate (F4 budget, `compute`
    row, F3a fn-carriage + computation-identity claims, CXER4611
    purity) reuses as-is; design-first, unscheduled. The exceptions
    register stays empty — no orthogonality exception was consumed by
    this stream.
