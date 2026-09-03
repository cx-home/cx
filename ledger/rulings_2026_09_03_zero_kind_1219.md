# Rulings 2026-09-03 — #1219 the zero NodeKind and the unlocked registries

**Status: RULED (1a, 2a) by the owner, 2026-09-03, on the report of commit 766270cf2.**

## The finding the rulings rest on

The profile gate's two rc=139 crashes in the supervise panic-restart fixtures
(sup-003, then sup-001) were **not** the zero Node. Reproduced at 2 in 1,600 runs
through the profile binary with the gate's exact stack; in the -O0 binary the only
faultable instruction in the window `code__fire_close + 128` names is the dereference
of the slot pointer `map_get_check` returned for `env.state.closeables[id]`, and
`fire_close`'s body touches no `cx.Node`. `ProgramState.closeables` had a lock nobody
took; `monitor_pos` had none; the supervisor loop is a `[?worker]` mutating both from
its own thread. Both registries now go through locked helpers (state_locks.v). The
zero Node was fixed in the same commit because it is the third instance of one shape
in the #1119 campaign (`NodeKind.invalid`, `ScalarType.invalid_type`; #1211 closed).

## Q1 — the other unlocked `ProgramState` registries (RULED: 1a)

- (a) **TAKEN — file the class audit as one issue and fix the registries in a
  follow-up wave**: `idem_records`, `pin_admitted`, `slice_literals`,
  `iter_closures`, `schema_bindings`, `schema_contents` (and `module_table`'s
  mutability) are written from evaluator paths that run on worker threads, with no
  lock. Same defect shape as #1219; the next fixture family finds it the hard way.
- (b) Leave them until one reproduces — rejected: the reproduction cost here was
  two gate runs and a day of suspicion aimed at the representation.
- (c) Fold them into 766270cf2 — rejected: widens an unruled change past the two
  registries on the reproduced path.

## Q2 — recording the invalid zero in the representation spec (RULED: 2a)

- (a) **TAKEN — `cxdm_representation.md` §5 gains rule 6: the zero of the kind tag
  (and of the scalar-type byte) is INVALID and names no kind.** RP-1's design put
  `element` at 0 and the flip paid for it three times; the rule is what stops the
  next layout change from re-introducing it.
- (b) Leave it to the code comments and the issue — rejected: the spec is the only
  truth, and a soundness rule that lives only in a comment is not one.
