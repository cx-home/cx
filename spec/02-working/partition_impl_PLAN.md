# Partition implementation plan — spec waves, implementation phases, gates

**Status:** Phase-3 deliverable of the #651/#516 campaign. Gate G-C = owner
approval of this document. Nothing below the "Implementation phases" heading
begins until every spec wave is complete AND G-C has passed (campaign ground
rules 4–5). Companion: `cx_partition.md` (G-B approved 2026-08-05).

## Part A — spec authoring waves (inside the gate)

All 22 stream specs (#673–#694) are authored on `design/651-516-partition`
in dependency order. A wave starts when its dependencies are approved.
Stream 14 (#686, corpus audit) starts immediately and runs continuously —
its ring-tagging output feeds every later gate, and its inherited-deferral
review must complete before G-C.

| Wave | Streams | Why this order |
|---|---|---|
| **S0 — identity-critical foundations** | 12 canonical warts (#684) · 11 decimal/bigint (#683) · 19 crypto-agility (#691) · 15 namespace permanence (#687) · 13 lexicon review (#685) | Everything downstream hashes; these change what bytes mean. Nothing else can be finalized while these are open. |
| **S1 — core model** | 1 semantic value model E1–E4 (#673) · 17 runtime representation (#689) · 16 shape inference (#688) · 22 implementability (#694) | E1–E4 consume S0's address/canonical rulings; 17 constrains the ABI the partition freezes; 16 feeds typed queries. |
| **S2 — language & computation** | 2 planar algebra (#674) · 5 computation identity (#677) · 6 commands/effects (#678) · 8 bitemporal (#680) | 2 needs E1 + 16; 5 composes Tier-2 + Tier-1 + E1; 6 needs the value-model lanes. |
| **S3 — runtime & live** | 3 live modes (#675) · 7 consistency vocabulary (#679) · 21 schema/event evolution (#693) · 18 agent-tool projection (#690) | 3 needs 2's dependency extraction; 21 composes with 5; 18 projects 6. |
| **S4 — platform & distributed** | 4 XSP store profile (#676) · 9 distributed store (#681) · 10 cross-stream coordination (#682) · 20 erasure/compliance (#692) | 4 needs S0 addresses + the value model; 9/10/20 build on 4. |

Wave exit = every spec in the wave owner-approved (G3-style). The M5
commerce/order-fulfillment domain is the worked example in every spec.

## Part B — implementation phases (after ALL waves + G-C)

Each phase ends green on the full conformance corpus and the import gates.
No production consumers exist, so rollback for every phase is a branch
revert — but the strangler rule still holds: the monolith keeps shipping
unchanged until I2 completes.

| Phase | Work | Exit gate |
|---|---|---|
| **I0 — seams before moves** | CI import gates (§3 of the partition spec) + corpus ring-tagging (from #686) land on the monolith. Zero code moves. | Gates green on unmodified tree; a synthetic violation fails the lane. |
| **I1 — identity epoch** | ALL hash-affecting changes land together in the monolith as ONE coordinated cutover: decimal/bigint kinds (11), canonical-wart fixes (12), self-describing addresses (19), any 13/15 canonical touches. One corpus re-bless, one identity epoch — never a second one. | Full corpus re-blessed and green; old→new hash mapping recorded; spec/corpus/impl agree. |
| **I2 — Ring-0 extraction** | `libcx-core` + `data`-profile `cx` built from `vcx/cx`. Cleanups ride along: fixture_loader → test support, cx.dylib debris, dead cxstore/cxsqlite, arrow_pub rename. | **Byte-for-byte**: extracted artifact matches the monolith on the full Ring-0-tagged corpus — outputs, canonical bytes, hashes, error codes identical. |
| **I3 — Ring 1/2 split** | The `vcx/code` frontier: store verbs, protocols, xap/fabric/session/authz/did/vc, DB drivers, process/io → Ring-2 modules; evaluator + pure/local stdlib stays Ring 1. Pack gates named per the profile table. | Full corpus green; import gates green; libcx ABI unchanged (symbol diff empty). |
| **I4 — profiles & installer** | Build matrix for data/embed/cli/platform; cxhome.org/install profile wiring; per-ring gate lanes activate (#700's structural relief). | Each profile builds + passes its ring-tagged corpus; installer one-command per profile. |
| **I5 — stream implementations** | #673–#694 implement in wave order against the partitioned tree, each on its own branch off the campaign branch, each gated by its approved spec + corpus additions. Early: 4 (store profile → CSRP data-plane retirement at parity gate), 2+3 (planar queries + live modes). Bindings v1 surface + auto-mirror lane (§12) ride the first cut after I4. | Per-stream: spec conformance fixtures green; for stream 4: gRPC-style parity suite passes over XSP store profile, then CSRP data plane removed. |
| **I6 — M5 proof** | Commerce/order-fulfillment showcase: native client + XAP UI + agent + REST/SQL adapters + offline replica against one model. | The demonstration itself — adapters project one model; campaign closes; #516 headline delivered. |

## Gates recap

- **G-A** (passed 2026-08-04/05): verdicts + streams filed + G-decisions.
- **G-B** (passed 2026-08-05): partition spec approved.
- **Wave exits:** per-spec owner approvals, S0→S4.
- **G-C:** owner approval of this plan → implementation may begin at I0.
- **Phase exits:** as tabled; every phase green on full corpus + import
  gates before the next begins.

## Standing constraints

Maintenance continues on `release/0.16.0` untouched; #700 (test relief)
proceeds there immediately, independent of these gates. The merge target for
the campaign branch is decided when the final gate passes — whichever
release line is current. Sanitization rules apply to every artifact of this
plan. No deferrals or scope cuts without express owner authorization.
