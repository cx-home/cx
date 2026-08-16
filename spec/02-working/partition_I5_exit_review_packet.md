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
