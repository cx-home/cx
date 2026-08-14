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
| gate-16 protocol mismatch: in-process loop vs the spec'd wrk form — upgrade the runner or amend the spec, never silently; needs an express call at the Q5a re-home | audit | partition_I5_audit.md AF-4 |

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
