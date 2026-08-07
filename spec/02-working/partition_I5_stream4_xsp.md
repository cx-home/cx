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
