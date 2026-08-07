# I5 stream 4 — XSP store profile: implementation ledger

**Status:** phase ledger (I5, stream 4, issues #651/#516/#676/#718;
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
| **W5 — object wire, erasure, peer** | `objects-have/get/put/refs` ops (put verifies address, batch `ref-set` all-or-nothing); generation-bound `[store-advert]` w/ signed head-set + guarantee set, re-advertised on config-reload (F3); `[erased]` tombstone distinct from not-found; shred propagation on the feed; `peer` profile (mutual XSP-AUTH, deny-by-default `peer` cap, revocations-journal subscription, honor rule, no-reach-in, convergence bound reported) | G13 families green incl. revocation-convergence pair |
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
   already live-pinned (fabric_serve_test.v:1038); listener-side credit
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
