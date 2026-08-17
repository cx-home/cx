# I5 exit-review packet — the "item-6 owner-gated handoff packet"

**Status:** accumulating register (not normative). This file IS the
"item-6 packet" that the I5 stream ledgers cite for owner-gated exit
decisions — authored 2026-08-13 under audit ruling Q6a after the
adversarial audit found ≥6 streams pointing at a packet that existed
nowhere (partition_I5_audit.md AF-11). Content style: pointers to the
owning ledger/spec section, never restatement — the cited section is
the authority. **Append-only: any stream or batch that books an
owner-review item after this date adds its row here in the same
commit.**

## 1. G3 spec graduations awaiting the owner (user-only approval rule)

| spec | stream | pointer |
|---|---|---|
| semantic_value_model.md | s1 (#673) | partition_I5_stream1_values.md (G3 rows ~:273, :309) |
| live.md (the pack spec) | s3 (#675) | partition_I5_stream3_live.md — "G3 of live.md = OWNER exit review" |
| computation_identity.md | s5 (#677) | partition_I5_stream5_computation.md (~:48, :505) |
| commands_effects.md | s6 (#678) | partition_I5_stream6_effects.md (~:66) |
| consistency_vocabulary.md | s7 (#679) | partition_I5_stream7_consistency.md (~:67-68) |
| bitemporal.md | s8 (#680) | partition_I5_stream8_bitemporal.md (~:68) |
| schema_event_evolution.md | s21 (#693) | partition_I5_stream21_schema.md (~:84) |
| runtime_representation.md | s17 (#689) | partition_I5_stream17_runtime.md §W7 record (family authored; flip gated on #807 remainder) |

## 2. Booked owner-review notes and dispositions

| item | stream | pointer |
|---|---|---|
| par_reduce default-chunk-width residual | s5 | partition_I5_stream5_computation.md:507-510 |
| the item "BOOKED for the owner, not silently decided" | s6 | partition_I5_stream6_effects.md:662 |
| disposition (a): [?schema-register] spelling retired-before-birth | s16 | partition_I5_stream16_shape.md:179-186, 257-261 (discharged in validate.md:370 strikethrough — confirm at review) |
| disposition (b): register-schema/validate-against IMPURE (supersedes the §3.2 pure marker) | s16 | partition_I5_stream16_shape.md:261-263 |
| disposition: min/max row-group pruning + per-cell vectorized compare = dead seam until the predicate grammar grows a value form; live-consumer trigger = the analytics campaign #751/#798 (link recorded here — the two were mutually unlinked, audit AF-11) | s17 W4 | partition_I5_stream17_runtime.md:247-256 |
| columnar backend compile-flag gating (-d cxstore_columnar; default build never runs the W4 path) — surfaced by the audit; decide with stream-18/#800 context | audit | partition_I5_audit.md AF-7; #744 comment 2026-08-13 |
| gate-16 protocol: RULED (b) 2026-08-13 — the spec'd wrk form stands, runner upgraded (real listener + external wrk, c=64, 3-min); rider: skipping gates silently is FORBIDDEN (missing tool = loud red). Verdict: PASS 145,204 req/s / p99 2.52 ms. 28.11-14 RETIRED at the same re-home (record-anchored acceptance vs the spec-single-source model; behavioral surface covered by enforced gate 4 + corpus). Register: conformance/GATE_REGISTER.md | audit → #805 | GATE_REGISTER.md; _gate_evidence/gate_16.log |

## 3. Audit rulings record (2026-08-13, owner: "1a, 2a, 3a, 4a, 5a, 6a, 7a")

Q1a gate-truth batch = #805 (members #803 head / #804 / gates 7+8 / gate
4 / abi-§4 driver / bench baseline / #802); #781+#782 → #796.
Q2a relabels applied: #803→high, #793→medium, #794→medium; #791 note
recorded on the issue. Q3a AF-1 = #806, fix-now in s17 W7,
fixture-first. Q4a AF-2/AF-3 = #807, one family; out-of-range cells
REFUSE loudly (the ruled direction); AF-2a+AF-3 fixed in W7; the
advisory→enforced flip gated on the family. Q5a gate-registry re-home
(living register; repair-or-retire every row incl. 28.11-14). Q6a this
packet + the stream-14 receiving register (partition_corpus_audit.md) +
W7 scope additions (recorded in the s17 ledger). Q7a resume order: s17
W7 → exit → #805 → stream 18 → stream 14 LAST.

---

# Part II — the campaign exit review (appended 2026-08-14, stream roster complete)

**The I5 stream roster is COMPLETE.** All 22 streams exited on
design/651-516-partition with full `make test` union GREEN at every
exit merge. This part consolidates the campaign evidence for the
OWNER-GATED exit review (march stop-point iv). Pointer style holds:
each ledger cited is the authority.

## 4. The stream exit table

| stream | topic | issues closed | exit merge | ledger |
|---|---|---|---|---|
| s1 | semantic value model | #673 #708 | 9ac7d605 | partition_I5_stream1_values.md |
| s2 | planar query algebra | #674 #711 | 3be47a3c | partition_I5_stream2_planar.md |
| s3 | live modes | #675 (+U1/U2 @ 84c56283; #762 consumers @ 11ba938c) | dc94cbda | partition_I5_stream3_live.md |
| s4 | XSP store profile | #676 #718 | e9f7abfe | partition_I5_stream4_xsp.md |
| s5 | computation identity | #677 | b0b03bd5 | partition_I5_stream5_computation.md |
| s6 | commands/effects | #678 #713 | ecae77aa | partition_I5_stream6_effects.md |
| s7 | consistency vocabulary | #679 #714 | 69bced43 | partition_I5_stream7_consistency.md |
| s8 | bitemporal | #680 | 84306188 | partition_I5_stream8_bitemporal.md |
| s9 | distributed store | #681 #719 | 59f9bb08 | partition_I5_stream9_distributed.md |
| s10 | coordination | #682 | eccb8022 | partition_I5_stream10_coordination.md |
| s11–s13, s15, s19 | close-out verification lane | #683 #684 #685 #687 #691 (+#776) | b54832b4 | the merge record @ b54832b4 (fixture-verified closes; no separate ledger) |
| s14 | corpus absorption (LAST) | #686 | 3cc843ca | partition_I5_stream14_corpus.md |
| s16 | shape/type inference | #688 #706 | a3b5e97e | partition_I5_stream16_shape.md |
| s17 | runtime representation | #689 #710 #806 | cea35ee4 | partition_I5_stream17_runtime.md |
| s18 | agent-tool projection | #690 #715 | 488fc5ee | partition_I5_stream18_agent_tool.md |
| s20 | erasure | #692 #720 #779 | 454aa061 | partition_I5_stream20_erasure.md |
| s21 | schema/event evolution | #693 #716 | ffb7dadc | partition_I5_stream21_schema.md |
| s22 | clean-room implementability | #694 #707 | 3667027a | partition_I5_stream22_cleanroom.md |

Supporting batches inside the phase: item-4 defect batch @ ba9efe09
(#712 #721 #723 #703); #725 phantom-filter removal @ 51740e05; #783
test consolidation @ ff546063; the #805 gate-truth batch @ d375d342
(audit Q1a/Q5a); #811 guide-check masking + #813 fail-open .cxs
validator found-and-fixed en route; **#810 canonical singleton-in-slot
RULED (a) by the owner 2026-08-14 and FIXED post-roster**
(fix/810-slot-singleton — the parser was below spec; zero identity
movement; s14 ledger addendum carries the ruling record).

## 5. Gap register final state

Authority: partition_corpus_audit.md §4 (trued at s14 exit).
Summary: **closed** G1 G2 G4 G12 G15 (+G11 resolved → #701);
**split** G9 (tape format closed; completeness lands WITH the
recorder) and G5 (scalar-kind goldens landed; decimal/bigint goldens
landed with the epoch); **open-by-design** G16 (the continuous
production→witness map, vcx/tests/formal/production_witness_map.md —
fill-with-the-work discipline, ~300 honest unmapped); remaining rows
(G3 G6 G7 G8 G10 G13 G14 G17 G18) carry their landings in the register
text — G8/G13 landed with stream 4, G17/G18 with the I0 validators,
and G3's canonical-emit expansion was PARTIALLY blocked on #810, now
unblocked by the fix.

## 6. Open-issue routing at exit (for owner confirmation)

| lane | issues | state |
|---|---|---|
| the ruled post-campaign perf arc | #804 | gate 15 honest-red stands; leg-1 begun in #805 |
| render-parity remainder (prio:high) | #807 | advisory→enforced flip GATED on family green (Q4a) |
| V-runtime campaign (prio:high) | #775 (#737 #742 #743 #749 #754 #755 #759 #773) | its own ruled order |
| defect batches | #795 (#790 #791 #794) · #796 (#788 #792 #793 + #781 #782) | filed with named members |
| visible gate-4 debt | #808 | rows flip with the raise implementations |
| await owner routing | #809 (kind-test grammar remnant) · #812 (x/term spec-or-retire) | filed at s18 |
| release lane | #741 #752 (the v0.16.0 cut — version-literal-ok, the named next release; s4's W8 R1 riders ride it) | owner-gated cut |
| design backlog | #728–#735 · analytics #751 #786 #797–#800 · #784 #787 #789 #801 · #758 #765 | tracker-routed, post-campaign |

## 7. Review questions for the owner

1. **G3 graduations (§1 table — eight specs).** (a) One review
   sitting, graduate en bloc from the ledger pointers — every spec is
   fixture-backed and gate-green, and batching keeps the cross-spec
   vocabulary coherent; (b) per-spec sessions — slower, only worth it
   if any single spec draws findings. **Recommend (a).**
2. **What the march does next (after this review).** (a) The
   prio:high clearance first — #807 remainder + #775 V-runtime — then
   the v0.16.0 release cut (#741/#752), then #804; (b) cut v0.16.0 <!-- version-literal-ok -->
   first; (c) #804 first. **Recommend (a):** the standing policy is
   prio:high ASAP, and the cut ships cleaner after #807's identity
   surface settles.
3. **Campaign issue closure.** (a) Close #651+#516 at this review with
   the packet as the closing evidence, remainder tracked by the routed
   issues; (b) hold them open through the v0.16.0 cut <!-- version-literal-ok -->. **Recommend
   (a)** — the partition scope is delivered; open campaign issues that
   track nothing actionable go stale.
4. **Branch disposition.** (a) Merge design/651-516-partition →
   release/0.16.0 at the review (GitFlow rule: work lands on the
   current release branch, never main); (b) hold the design branch
   until the cut. **Recommend (a)** — 22 exit-merged streams on one
   long-lived branch is accumulated merge risk for zero benefit.

## 8. Exit-review rulings record (owner, 2026-08-14: "1a 2a 3a 4a")

- **exit-1a** — the eight §1/§7.1 G3 specs GRADUATE en bloc:
  semantic_value_model, computation_identity, commands_effects,
  consistency_vocabulary, bitemporal, schema_event_evolution,
  runtime_representation → spec/03-approved/core/ (s5's ledger pins
  "beside code-identity.md"); the live pack spec merges INTO
  spec/03-approved/std-lib/live.md (the journal.md form: full spec
  under the module-meta header — the thin pointer retires with the
  graduation). Status headers flip to Approved; live path references
  in approved specs/code comments update; partition_* ledgers keep
  their historical text unrewritten.
- **exit-2a** — the next arc: prio:high clearance first (#807
  render-parity remainder, #775 V-runtime campaign), then the v0.16.0 <!-- version-literal-ok -->
  cut (#741/#752 + the s4 W8 R1 riders), then #804.
- **exit-3a** — #651 + #516 CLOSE at this review; this packet is the
  closing evidence; the remainder is tracked by the §6 routed issues.
- **exit-4a** — design/651-516-partition merges → release/0.16.0 at
  the review (GitFlow: the current release branch, never main).

## 9. exit-4a execution record (the release-branch merge, 2026-08-14)

Merged @ the release/0.16.0 merge commit. Conflict domain: release's
#727 gtin cutover × the campaign's registry re-bless. Resolution =
campaign content + the gtin cutover applied on top; the registry
RE-SEALED FRESH from the merged engine (gtin@0.1.0 manifest
sha2-256:938ccff3… tree sha2-256:9f0e24be… — prefixed addresses, the
campaign form); every pin re-derived from the seal; the pkg: consume
example re-verified live; the serve_real test stays deleted (the #783
consolidation home is xap_umbrella_test.v). **Freeze-gate
adjudication:** 550f8a1a (#727) was authored ON release/0.16.0 where
the R4.1 gate did not run; its ruling is EXPRESS and recorded (the
commit message's "Owner-directed (destination (a) confirmed)" + issue
#727) — the sha rides the gate's adjudicated register with a loud
skip, citing this row. Rewriting pushed shared release history to
inject the token was rejected.

## 10. Next-arc rulings record (owner, 2026-08-14 session close: arc-1..8)

Recorded rulings-before-edits; the post-exit march executes against
this record.

- **arc-1 (cut authority + scope)** — the v0.16.0 cut <!-- version-literal-ok -->
  comes AFTER bug clearance and STOPS for the owner's one-word confirm
  before tag/merge-to-main/publish. The publish gate: the ~40-bug open
  ledger worked to MAJORITY-CLEAR — all prio:high and prio:medium bugs
  closed or expressly deferred via lettered questions AT the cut
  confirm (no silent deferrals); prio:low case-by-case. Named
  exception: #804 (perf recovery) stays post-cut per exit-2a.
- **arc-2 (#807 trailing-LF, QUALIFIED a)** — the LONG-TERM-BEST
  reading for CX decides, determined fixture-first; if the best
  reading preserves existing Tier-1 addresses → adopt; if it would
  MOVE addresses → STOP-POINT (the owner rules the migration; never
  auto-adopt movement, never pick the worse design to dodge it).
- **arc-3 (#807 f16)** — refuse-or-widen: a value that does not
  round-trip exactly widens to full precision or refuses loudly; never
  silently approximates (extends Q4a).
- **arc-4 (#809)** — implement kind-test reachability from binding
  paths — impl rises to the approved grammar (the #810 pattern).
- **arc-5 (#812)** — author the thin x/term catalog spec (the
  graduated pattern); term stays in the bundle.
- **arc-6 (packet §2)** — the six booked dispositions CONFIRMED en
  bloc as recorded.
- **arc-7** — the canonical-forms batch #795 (#790/#791/#794) and the
  defect batch #796 (#788/#792/#793 + #781/#782) ride BEFORE the cut.
- **arc-8 (#726)** — the reference app is built BEFORE the cut, after
  the bug arcs: a small CX-generic application exercising the campaign
  surface end-to-end (agent tools propose/approve, live views,
  bitemporal query, erasure, a licensed package); it doubles as the
  release's end-to-end acceptance and the adopter demo.

**The ruled march order:** #807 remainder (arc-2/arc-3; the
advisory→enforced flip gated on family green) → #775 V-runtime (ruled
order #737→#773→#754→#755→#742/#743) → #795 → #796 → the remaining
bug ledger by priority to majority-clear (incl. #814) → #726 reference
app → cut prep (#741/#752 + the s4 W8 R1 riders) → STOP for the
owner's confirm → publish → #804.

**§10 addendum — 804-return (owner, 2026-08-14, during the #795
stage):** #804 (the gate-15 perf recovery) RETURNS to the pre-cut
march — this supersedes exit-2a's post-cut placement and arc-1's named
exception. Slot: after the #795/#796 batches, before the general
ledger sweep (the march's heavy-item-first principle; the owner may
reorder). The arc-1 publish gate now counts #804 among the pre-cut
work rather than the deferral column.

**§10 addendum — 743-1a (owner, 2026-08-14, at the #775 exit):**
#743 (the vgc-in-Go-host STW ack-wait hang) is EXPRESSLY DEFERRED past
the v0.16.0 cut <!-- version-literal-ok --> with the documented interim
(the go-lane pacer pins + the issue's embedder guidance); the darwin
signal-free mach-suspension work is its own post-cut lane beside #804.
Basis: the signal-swap direction was FALSIFIED by a battery-verified
attempt (the Go runtime intercepts signals generally — no signal
choice clears the class; findings on the issue), the exposure is
narrow and documented, and an STW redesign against the session-4
weak-stop-point UAF history does not belong on the cut's critical
path. #743 keeps prio:high. This is the arc-1 express-deferral form
for the cut confirm.

**§10 addendum — 809-1a (owner, 2026-08-15, during the pre-cut ledger
sweep):** the `[131b]` `text()` kind test ADMITS CX's typed body scalars
— it selects TextNode **and** ScalarNode, the character-data node kinds,
not TextNode alone. The `ast.md` node-test table's "Text nodes only" row
is AUTHORIZED to be re-spelled to name both kinds; the change is
one-line and identity-inert (a node test filters a candidate set — it
does not participate in canonical bytes or any address).

Basis: in CX the Text/ScalarNode split is an artifact of AUTO-TYPING,
not of authorial intent — `[port eight]` is a TextNode and `[port 8080]`
a ScalarNode from the same authorial act. A `text()` that silently
skipped the typed ones would make a query's result set depend on whether
a body happened to auto-type, which is the opposite of the orthogonality
objective; `node()` reaching both is not a substitute, since it also
takes elements. #809 shipped the literal approved reading with the
divergence pinned BOTH ways (`program-cxpath-kindtest-010`) precisely so
this ruling would have a fixture to move.

Scope: `text()` only. `node()` / `element()` / `attribute()` are
unchanged, and the cxdm §2.2 taxonomy is unchanged — Text and ScalarNode
remain distinct Node KINDS; what this settles is which of them the
`text()` NODE TEST selects.

**§10 addendum — 738-2a (owner, 2026-08-15, same sweep):** the TOML
import surface becomes a STRICT reader — malformed input is REFUSED
(`cx-err:CXER0100 PARSE_ERROR`), never silently guessed into a
document. `conversions.md §6` is AUTHORIZED to gain the normative
strict-reader sentence, mirroring §4's JSON lane (which already cites
`json.md §3` by name).

Basis: a Ring-0 `data`-profile artifact whose pitch is safety on
untrusted input must reject garbage rather than guess at it, and every
sibling import lane (XML / JSON / YAML) already surfaces parse errors
through the same `!Document` seam — TOML was the one reader that did
not, by construction (`or { continue }` at every level, no error seam at
all). The leniency was never ruled correct; it was undocumented
behaviour that the G7 fixture batch pinned as-shipped pending exactly
this ruling.

Scope: the refusal is the import lane's, and it carries a
negative-fixture family. The DATE half of #738 (native date/datetime
mapping) closed separately at d2361a5d and needed no ruling — §6.1's
mapping table had already decided it and only the impl was behind.

**§10 addendum — 739-1a (owner, 2026-08-15, pre-cut ledger sweep):** the
`vc` predicate is RENAMED `valid?` → `valid`, cutover-first, in both
`spec/03-approved/std-lib/vc.md` and `stdlib/vc.cx`. The approved vc.md
surface row is AUTHORIZED to change.

Basis: `valid?` is unreachable — the locked lexicon does not admit `?` in
an identifier, so `[$vc:valid? …]` cannot be written and the public
surface exists only in prose. `valid?` is the ONLY `?`-suffixed def in
the bundled stdlib, so this is a one-symbol collision between a surface
naming choice and the lexicon. A one-symbol collision does not justify
moving the lexicon: admitting `?`-suffixed identifiers touches every
reader, the canonical spellings, and the fmt/emit round trip. The
semantics remain available through `verify`'s status channel meanwhile,
so nothing is lost by the rename.

Cutover-first per the no-dual-accept rule: the old spelling is not
accepted alongside the new one. Its conformance pin
(`vc-016-validq-surface-unreachable`, which currently asserts the parse
failure) flips with the fix.

**§10 addendum — 820-1a (owner, 2026-08-15, same sweep):** the `cx:`
namespace reservation is enforced at the PROGRAM construction seam, and
it reuses **E210** — the same code the data reader raises. No new code is
minted in the program band.

Basis: it is ONE reservation. Two codes for one rule teaches a user that
authoring `cx:foo` is two different mistakes depending on which reader
sees it first, when it is the same mistake with the same remedy. The
layering argument for a program-band code is real but abstract; the
user-facing cost of splitting the code is concrete. Enforcement belongs
at CONSTRUCTION rather than at emit: refusing on the way out would let
the bad node exist and be operated on first, and the diagnostic would
point at the emit site instead of the authoring site.

Scope note carried from the issue: the `xml:` prefix sibling and the
COMPUTED element-name form (a name that is not literal in the source
cannot be caught by a parse-time check alone) are checked in the same
landing.

**§10 addendum — 808-1a (owner, 2026-08-15, same sweep):** the two
unraisable codes are IMPLEMENTED, not retired — `CXER0280`
(E_RENDER_FAILED) gains a real raise site in the renderer, and
`CXER4113` gains the `[?eval]` `[?lib]` non-widening guard code.md §6.4.4
already declares normative.

Basis: both rows describe conditions that genuinely exist. §6.4.4's
sandbox rule ("[?eval] inherits the caller's [?lib] set; may narrow, not
widen") is a SECURITY boundary whose depth-cap twin CXER4114 is already
enforced — leaving the lib-widening half unenforced is a hole, not a
spec surplus. Retiring either row would be truing the spec to a
shortfall.

Qualification: if implementation shows a row's condition is genuinely
unreachable BY DESIGN rather than merely unimplemented, that finding is
surfaced as its own lettered question rather than answered with a
synthetic raise site — a guard that cannot fire is not an
implementation.

**§10 addendum — tables-1a (owner, 2026-08-16, pre-cut ledger sweep):**
for every CLOSED CLASSIFICATION TABLE in the system, **the spec is the
source and the implementation check is DERIVED from it by a gate.** The
implementation may never lead the spec: a row lands in the approved
document first, and the gate asserts equality in both directions so
neither side can drift.

This ruling is cross-cutting and settles three open items at once:

- **#827** — `security.md` §2.1 (the closed effect-point table) is
  AUTHORIZED to gain the rows it is missing. The audit: §2.1 carries 118
  rows of which exactly **one** charges `net`, while the implementation
  gates **55 distinct network primitives** — 11 http client
  (`http_client_gated_prims`), 6 http serve (`http_serve_gated_prims`),
  38 raw socket (`net_gated_prims`) — plus `io-edit-file`, which
  self-gates on read AND write as the one primitive spanning both. CX's
  entire network surface is enforced in the implementation and absent
  from the table that calls itself the normative closed set.
- **#756** — `code.md` is AUTHORIZED to gain a normative per-directive
  purity classification table. §6.5.1 carries the invariants only; the
  closed head list exists solely in `purity_checker.v`, whose comments
  claim a spec parity that was never there. The audit: 56 heads
  classified against 85 dispatched and 81 registered, with 47
  unclassified and 13 stale entries naming heads that exist in neither
  the registry nor the dispatch.
- the general rule for any table added later.

Basis: purity and capability are SECURITY properties, and #788's lesson
was that a hand-kept list drifts until something derives it. #818 then
demonstrated the mechanism working in the intended direction — the
spec-parity gate REFUSED to let the implementation mirror list an effect
point §2.1 had not declared, which is precisely the protection this
ruling generalizes.

Consequence for the mirror's shape: `capability_gated_prims()` lives in
Ring 1 and cannot import Ring 2, so the Ring-2 gated lists need their own
exposed half and the GATE (which lives in `vcx/tests`, and per §3 "tests
and tooling may import anything") unions the two before comparing against
§2.1. The import contract is not bent to make the gate convenient.

NOT settled by this ruling, and still open on #827: whether
`mime-multipart-boundary` (draws OS entropy) and `locale-default-locale`
(reads an environment variable) should BE gated. That is a question about
which surfaces are effect points, not about where the table lives, and it
is a runtime behaviour change on a security surface.

**§10 addendum — 785-1a (the derived open inherits the source's posture,
2026-08-16, during the pre-cut ledger sweep):** `journal.md` is AUTHORIZED
to state, normatively, that a `rotate`/`compact` TARGET is a DERIVED open
which inherits the source chain's **at-rest posture** (`encrypt-key-id`,
and framing `encoding`/`compression` within one scheme) and its
**`hash-algo`**, with an explicit key on the caller's `opts` overriding —
and that `journal-open` itself carries the at-rest keys.

Basis: the rule is an IMPLICATION of two settled contracts, not a new
policy. `store.md` §9 mandates fail-closed at rest — an at-rest posture
must never silently become a plaintext write — and §4.11 already makes
rotation a copy-then-**swap** in which the returned journal BECOMES the
live chain. A swap that downgrades the at-rest posture at every segment
boundary contradicts both. What the spec genuinely lacked, and what this
authorizes, is the **precedence order** (explicit `opts` ▸ the target
URL's own `?encoding=`/`?compression=` ▸ the source) and the **same-scheme
scoping** of framing inheritance: `file://` → `sqlite://` must not carry
`object-per-key` into a substrate that has no such framing, while
`encrypt-key-id` inherits ACROSS schemes precisely so a target that cannot
seal refuses LOUDLY (§9) instead of writing plaintext.

The `hash-algo` half rode the same call site and is the same defect class:
the target took the DEFAULT algo while `compact` copied entries **verbatim**
(§4.10, hashes unchanged), stamping `sha2-256` on a segment whose entries
were hashed under the source's algo — a segment that fails its own
`verify`. No identity surface moves: addresses stay the plaintext content
hashes (§9), and the copy-forward is byte-identical either way.

**§10 addendum — 777-1a + 830-1a (owner, 2026-08-16: "1a 2a"):**

**777-1a — one map lane; the envelope carries key TYPE.** The program map
grammar ADMITS the key kinds the data reading already accepts, and the
`__cx_map__` envelope records each key's CXDM kind rather than only its
name image. Keys keep their kinds through eval and render; the §8
admissible-key parity nit disappears with the split that caused it.

What the investigation found is worse than the reported nonuniqueness, and
is what the ruling is really buying:

- `parse_map_literal` accepts key tokens of kind `.string_lit` / `.ident` /
  `.number_lit` only. `true`/`false` (`bool_lit`) AND date/datetime
  literals fall OUT of the program map grammar into the DATA map reading —
  so the lane a map lands in is decided by its key's *token kind*.
- The envelope stores keys as entry element NAMES, so the key's kind is
  erased: `{'7': 'a', 7: 'b'}` — a string key and an int key, two distinct
  keys — renders `{7: 'a', 7: 'b'}`, which `cx canonical` then REFUSES with
  **W014 duplicate map key**. The program lane emits canonical text the
  canonicalizer rejects: a hard round-trip break, not a cosmetic second
  spelling.
- `{'true': v}` renders `{true: v}` (string key → bool key on re-parse) and
  `{'2026-08-16': v}` renders `{2026-08-16: v}` (string → date). The kind
  flips across the round trip.
- #776's ruling ("`{1:}` ≠ `{1::bigint:}` ≠ `{1.0:}`, three distinct keys")
  is not delivered in the canonical form: the ascription rides in the name
  text, and `{1::bigint: v}` renders `{'1::bigint': v}` — a STRING key.
  Carrying the kind structurally is what makes the three actually distinct.

Key identity in the envelope is therefore the pair (kind, image), and
duplicate detection compares the pair. Entries whose kind is unset keep
today's image heuristic byte-identically — every stdlib-constructed option
map has bare-name keys and is unaffected.

**830-1a — V's scalar temporal encoder rises to §3.6.1, in this sitting.**
`scalar_node_to_dataval` is kind-aware for decimal (0x28) and bigint (0x18)
only, so date/datetime scalars erase to the string tag 0x30 and V's own
data-bin round trip returns a quoted STRING. The impl rises to the spec
(the #810/#809/#815 pattern); data-bin goldens covering a temporal scalar
re-bless with the change. No Tier-1 identity surface: identity is the
canonical TEXT hash, and data-bin is transport.

**NOT settled by either ruling, and newly found — filed separately.** The
program renderer and `cx canonical` disagree on the VALUE spelling in map
position, for every key kind, not just the bool-keyed case that surfaced
it: `[m {yes: 'x'}]` renders `{yes: 'x'}` through `cx FILE` and `{yes: x}`
through `cx canonical` (the data lane's bare-when-safe rule, #790's
790-1a). That axis is orthogonal to the lane split, moves identity-bearing
canonical output broadly, and is left for its own ruling rather than
absorbed here.

**§10 addendum — 831-1a′ (one string image for collection items; owner,
2026-08-16):** `code.md` §11.1a **R6** is AUTHORIZED to redefine "bare-safe"
as the INTERSECTION of the two readings, and both the data emitter and the
program result renderer are authorized to share one implementation of it.

The issue was filed as a canonical NONUNIFORMITY — `cx FILE` rendering
`{yes: 'x'}` where `cx canonical` renders `{yes: x}`. The investigation found
something sharper underneath: "safe" had been computed for the DATA reading
alone, so the canonical form emitted images the PROGRAM reader **cannot
parse** —

```
{k: 'a b'}          ->  {k: a b}            expected ':' after map key
{k: 'a.b'}          ->  {k: a.b}            same
{k: 'https://a.com'} -> {k: https://a.com}  same
```

— including a shipped golden (`conv-020`, the TOML-import expected output).
That is `lexicon.ebnf` [L11]'s **one deliberate name-char mode fork** showing
through a canonical form: the data lexer folds `.`/`:` into a name, the
program lexer does not, and a single interior space is legal body text but
splits a collection item. Array position was never affected — its item
emitter already applied a stricter boundary predicate, which is exactly why
arrays were the one collection position where the lanes always agreed.

So the divergence was a SYMPTOM and the unreadable image was the defect.
Narrowing the safe set fixes the defect, and once it is narrowed the two
surfaces converge onto a spelling BOTH readers accept — which is why the
convergence is landing now after being reverted once.

**On that revert (#790/790-1a, 2026-08-15).** A bare-when-safe arm for
string scalars was tried in the program renderer and backed out, on the
reading that §11.1a means "program results quote their strings". R6 says the
opposite and always did — *"a string renders BARE iff it is bare-safe AND
does not auto-type"* — so the implementation was below its own normative
rule and the goldens pinned the pre-R6 behavior. What was genuinely missing
was not the direction but the safe SET; with R6 tightened, the earlier
objection no longer applies.

**Re-bless:** 111 expected-output lines across 19 conformance files (109 via
the `CX_BLESS=1` gate mode, which emits a record ONLY where it has proved the
diff quote-only, + 2 whose single-line `out-text` form the applier's pattern
skipped). Every diff verified quote-only before applying; no `in-code` block
moved. Data-lane goldens: `yaml-001`, `conv-020`.

**Not a Tier-1 identity move in the program lane** (the result image is not a
hash basis), and in the data lane it moves only images that were UNREADABLE
in the program reading — the class no correct document should have depended
on.

**§10 addendum — 828-1a (owner, 2026-08-16: "2a"):** both surfaces #827
split out BECOME effect points and are gated —
`mime-multipart-boundary` under `random`, `locale-default-locale` under
`env`. Neither is new policy; both are the implementation rising to rules
already written down.

- **locale-default-locale.** `env.md` §7 states it flatly: *"Environment-
  variable reads require `env`"*. The capability-free carve-out there is
  limited to the ambient process basics "intrinsic to the running process"
  (stdin/stdout/stderr, pid, argv, cpu-count, exit) — an env-var read is
  not one of those, and `hostname`/`username` are gated "in the same
  spirit". The counter-argument (LANG is not a secret) does not reach the
  rule: the spec chose BREADTH over secret-ness for this capability.
- **mime-multipart-boundary.** `security.md` §2.1 is a closed EFFECT-POINT
  table, not a secrets table, so the question is whether the surface
  reaches an OS resource that can fail — and this one's own failure mode is
  literally "entropy unavailable". Every sibling entropy draw charges
  `random`. The counter-argument is answered rather than dismissed: a
  boundary is NOT a secret, which is exactly why it must resist COLLISION
  with body content — and that is still entropy.

Friction is answered by the §4 ergonomics the model already ships
(actionable denial errors, `cx.pkg` manifest grants, `--allow-all`), not by
leaving an effect point ungated.

Mechanics: the two prims move OUT of `impure_without_capability_exceptions`
(where they sat as the "(h) KNOWN GAP #828" rows) and INTO
`capability_gated_prims`, with their rows added to §2.1 — the
`check-effect-alignment` gate asserts spec ↔ impl equality in both
directions, so the table and the mirror move together or not at all.
Witnesses: `locale-069` and `mime-046`, which carry no `grant=` and so run
under the EMPTY cap set (both disarm-verified red with the guards removed).

**§10 addendum — 829-1c (owner, 2026-08-16: "1c"):** a mid-run comment keeps
its POSITION and stays HASH-INERT — both, not one at the cost of the other.

The remainder of #829 looked blocked: `canonical.md` §2.9 requires "comment
placement preserved relative to nodes", and placing a comment INSIDE a text
run appeared to need the run split into two text nodes, which #469 closed in
those words because splitting moves the strict-canonical hash. The commit
that fixed the trailing shape (`ab978098`) recorded exactly that reasoning
and left the mid-run shape alone.

It does not need a split. The comment carries a **presentation-only**
`run_offset` — the same class as `pos` (#792) — recording where it sat
inside the run. Canonical form strips comments (lexicon [L2]/[L3]), so the
run remains ONE TextNode and the Tier-1 hash is untouched BY CONSTRUCTION;
the lossless emitter splits the rendered TEXT, never the node.

The interleave is DECLINED, keeping the historical leading placement, when a
fragment would not round-trip: one that needs quoting (`'a b'` + comment +
`' c'` re-reads as two strings, not one run) or one that would auto-type
(`x 5` split after `x ` re-reads `5` as an INT). The oracle for the second
is the parser's own `try_autotype`, NOT `cx_would_autotype` — that one
deliberately OVER-reports (its #473 note calls over-reporting "the safe
direction"), which is right for a quoting decision and wrong here, where it
silently costs the placement for images like a bare `e`.

**Remaining, not covered by this ruling:** the third shape in the report —
`[config [; c ] env=dev]` → `[config env=dev [; c ]]` — is a comment in the
ELEMENT-META zone, not a text run, so `run_offset` does not reach it. It is
#469's item 2 territory (the meta-zone retention lane) and needs its own
carrier.

**§10 addendum — pre-cut ledger rulings (owner, 2026-08-17: "1a 2a 3b 4a"
+ the #823 scope direction):**

- **808-1a** — `CXER0280 E_RENDER_FAILED` RETIRES to reserved. The
  renderer's real failure mode is `CXER0281 E_UNRENDERABLE_DIRECTIVE`,
  which exists and is exercised; inventing a second failure class to
  justify a registry row is backwards. (`CXER4113`, the issue's other half,
  already gained its raise site at e5fdbd14 — #808 closes with this.)
- **760-1a** — the four dead `[59a]` EvalName reservations (`?with`,
  `?use`, `?cond`, `?try`) RETIRE, the same treatment L98 gave the
  `[?for-tumbling]` / `[?for-sliding]` window heads. A name the grammar
  reserves and the evaluator cannot dispatch is a promise the language
  breaks.
- **804-1b — THE 200 MB/s THRESHOLD IS BINDING, AND THE CUT HOLDS FOR IT.**
  `code.md` §11.4.4 is normative; gate 15 measures ~2 MB/s. This
  supersedes every prior placement of #804 (exit-2a's post-cut slot, the
  §10 addendum's pre-cut-but-late slot): it is now the RELEASE CRITICAL
  PATH, not the last item before the cut. The threshold is not re-rulable
  against whatever the implementation happens to reach — the
  implementation rises to the spec, which is the same discipline #810 /
  #809 / #815 / #830 all followed. Diagnosis to work from (#804): the cost
  is per-ITEM evaluation machinery — `clone_frame_sharing_closures` per
  item, yield-leaf evaluation, `render_node_to` per emit — roughly 45 µs
  per ~95-byte record, and NOT the input path (the streamed-input fast
  path and the materializing path measure identically).
- **833-1a** — the new broad grant is spelled `--allow-common`: it names
  the common working set without implying "safe" or "dev-only", neither of
  which it guarantees.
- **#823 — SCOPE IS THE WHOLE ISSUE, not the byte-equivalence half.**
  Fixing the streamed `[?map]` renderer to emit the sequence wrapper is
  necessary but not sufficient. While `[?map]` returns `.buffered`
  (api.v ~285) it keeps exactly the memory profile #822 closed — 514 MiB
  peak RSS on a 10 MB pass-through — and NOTHING detects that, because
  gate 15 benches a `[?for]` shape only. The exclusion is honest at the
  predicate but its cost is unmeasured, which is how a regression class
  hides behind a documented trade-off. So the fix is: restore streaming
  for the shape, AND extend the gate to cover a `[?map]` shape so the
  exclusion can never silently return.
