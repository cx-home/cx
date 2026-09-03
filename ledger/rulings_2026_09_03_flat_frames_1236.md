# Rulings 2026-09-03 — #1236 flat frames: every derived frame copies the enclosing bindings map

**Status: PROPOSED 2026-09-03 — awaiting the owner's letters on Q1–Q4.**

## The finding

`MatchEnv.bindings` is one `map[string]cx.Node` holding a FLATTENED copy of everything visible. There
is no parent link, so every derived frame is a per-key copy of the enclosing frame
(`clone_frame_into`, matcher.v — the single authority both clone helpers route through, a
`for k, v in e.bindings { copy.bindings[k] = v }`). The sites, counted on release/0.18 @ fcab2e97e:

| site | helper | per |
|---|---|---|
| `[?for]` clause walk (`collect_frames`, the streamed and buffered pipelines) | `clone_frame_sharing_closures` | item, and again per `:let` clause |
| `[?let]` (both forms), `[?loop]`, `[?with-scope]`, `[?recur]` frames | `clone_frame_sharing_closures` | body entry |
| `[?match]` binding-capable arm (`match_arm_pattern`), path-case arms | `clone_sharing_closures` | arm ATTEMPT, hit or miss |
| `[?fn]` creation | `snapshot_bindings` | closure (#1235) |
| closure call with a defining scope | ALIAS (`bindings_shared`) + `cow_bindings` on first write | call — the one shape that already avoids the copy |
| `[?worker]` / `[?async]` spawn, error hooks | `bindings.clone()` / `env.clone()` | spawn (correct: a thread boundary must snapshot — #1230) |

29 files touch `env.bindings` directly: 149 indexed reads, 2 `value_ptr` fast reads (the `$name`
resolution path), 20 `in env.bindings` probes, 106 indexed writes behind 27 `cow_bindings()` guards,
15 whole-map iterations, 18 `bindings.delete`, 4 `bindings.len`, 9 `bindings.clone()`. Every prior
fix in this family is a special case of the flat copy: B17 (closures CoW), #317 (request-template
alias), #333 (defining-scope alias), #36 (pooled frame maps — removes the ALLOCATION, not the copy),
#871 (match arm shares closures), #1094 (bind-free arms skip the clone), #1139 (structural fast path
clones once on a hit: ~115 µs → ~1.6 µs on a five-lib frame, ~4.6 → ~2.3 µs on a 17-binding frame).
The cost scales with the PROGRAM (how many libs are loaded, how many top-level bindings exist), not
with the construct — a `[?for]` over 200k rows in a handler with five libs loaded copies a
several-hundred-entry map 200k times before doing any work.

## Q1 — the frame representation

- **(a) RECOMMENDED — parent-pointer frames.** A frame is its OWN bindings (params / let-binds /
  the for-item — a handful of keys) plus `parent &Frame`. Lookup walks the chain (depth is the
  static nesting depth, small); a derived frame costs O(#new bindings), not O(|visible|). What it
  DELETES: the per-key copy at every site in the table above; `clone_frame_into`'s copy loop;
  the need for #36's pooled maps on `[?for]`/closure frames (a frame with ≤ 8 locals is a small
  array, no map at all); `cow_bindings` for request templates (a request frame's parent IS the
  template — no alias flag). What it KEEPS: snapshot-at-spawn (a thread boundary flattens the
  chain ONCE — #1230's copy-at-spawn rule, unchanged), EV-CLOSURE-CAP (a `[?fn]` captures a
  snapshot; with #1235 that snapshot is the free-variable set, so it stays small), shadowing
  (the leaf wins), `-d cx_frame_poison` (locals arrays are frame-owned, the escape detector
  keeps its meaning). What it COSTS: a lookup miss walks the chain (depth d), so a hot read of a
  top-level binding from a deep frame is d probes instead of one — bounded by the program's
  static nesting, and the value_ptr fast path can cache the resolved frame per call site later.
- **(b) keep flat maps; keep adding special cases** (extend #1139's fast path to multi-arm
  `[?match]` = #1237, extend #36's pool to more sites, #1235's free-var snapshot). Rejected as
  the ruling: each removes one site's copy and leaves the root; `[?let]`, `[?loop]`,
  `[?with-scope]` and the `[?for]` `:let` clause have no fast path to be given, and every new
  construct inherits the copy. (#1235 and #1237 remain worth doing on their own — under (a) they
  become the capture rule and the arm fast path of the chain, not competitors to it.)
- **(c) a persistent map (HAMT / structural sharing)** for `bindings`: O(1) "copy", O(log₃₂ n)
  insert, lookups stay one probe. Rejected: it changes the representation of EVERY binding read
  in 29 files for a data structure V does not ship and CX would own; the chain reaches the same
  asymptotics with a struct and a pointer, and keeps the flat map for the ONE frame that is
  legitimately flat (the program's root).

## Q2 — where the chain is flattened (the boundaries that stay copies)

- **(a) RECOMMENDED — three flatten points and no others:** (1) a thread boundary (`[?worker]`,
  `[?async]`, error hooks) — flatten once into the spawned frame's own map (this is #1230's copy,
  it just gathers the chain instead of cloning one map); (2) closure capture — the #1235
  free-variable snapshot (a chain makes the free-variable walk natural: resolve each free name
  once, store the value); (3) `[?for]` buffered frames across a barrier (`collect_frames` —
  frames that outlive their iteration). Everything else derives by parent pointer.
- (b) flatten at every closure CALL as well (a call frame gets a flat copy of its defining
  scope) — rejected: reintroduces the copy on the hottest path; the defining scope is the
  parent (what the #333 alias already expresses, now without the alias flag).

## Q3 — deletes, iteration and shadowing under a chain

- **(a) RECOMMENDED — deletes are frame-local; iteration is leaf-to-root with shadow skipping.**
  `bindings.delete` (18 sites) may remove only a binding the CURRENT frame introduced; deleting
  a parent's binding is a semantics change nobody ruled and the audit must show every site
  deletes what it bound (the `$_`/`$_position` scaffolding and the `:rest` temporaries are the
  expected shape). The 15 `for k, v in env.bindings` sites iterate the chain leaf-first and skip
  keys already seen (the leaf wins — same result as today's flat map after the copy).
  `bindings.len` (4 sites) becomes the deduplicated count or, where it is only an emptiness test,
  a chain-empty probe. If the audit finds a site that deletes a parent's key, it comes back here
  as its own question — not a tombstone hack.
- (b) tombstones (a frame-local "deleted" marker shadowing the parent) — rejected unless Q3(a)'s
  audit forces it; adds a state every read has to check.

## Q4 — the exit bar

- **(a) RECOMMENDED:** byte-identical extraction transcript (13,165 pairs / the current
  verdict digest) under the chain; the corpus byte-identical with `CX_MATCH_NO_FASTPATH` both
  ways (the #1139 differential gate) — and the fast path can then be RETIRED if the chain makes
  the general matcher's arm attempt cheap enough (measure, don't assume); Stage-0 re-timed
  against `rulings_2026_09_01_no_compiler_1176.md` (the `[?for]` 200k-row and `[?match]` 6-arm
  shapes — alloc+GC was 77.4 % / 72.0 % of self-time there, and this copy is the allocation);
  gate 15's `[?map]` mean re-recorded against the BINDING 200 MB/s threshold (804-1b, not
  re-rulable); the `[?loop]` rebinding fixture (the EV-CLOSURE-CAP discriminator) unchanged;
  `-d cx_frame_poison` still catches an escaping frame. Landing shape: W1 the accessors (every
  direct `env.bindings[…]` read/write/iterate goes through `bind_get / bind_set / bind_has /
  bind_each` — a mechanical, byte-identical refactor of 29 files that is ITS OWN commit and gate
  run, so the representation change in W2 touches one file), W2 the chain, W3 the three flatten
  points + #1235, W4 the Q3 audit + #1237 (or its retirement).

## Measurements (release/0.18 @ cd025ce4a, -O0 dev binary, quiet machine, one run each)

The frame is made fat by BINDINGS, not libs: a `[?lib]` registers members into the closures table
and the Scope, and only consts into `bindings` — so "five libs loaded" fattens the CLOSURES clone
(#1237's `env.clone()` in collection sub-patterns), while a program with many visible `[?let]`
bindings fattens THIS copy. Both shapes were taken; the second is #1236's.

| shape | 0 extra bindings | 300 visible bindings (an outer `[?let]`) | ratio |
|---|---|---|---|
| `[?for]` over 200k ints, one `[?let]` per item | 1.78 s (~8.9 µs/item) | 57.7 s (~289 µs/item) | 32× |
| `[?for]` over 50k, a 4-arm `[?match]` per item (3 misses + 1 hit) | 2.31 s (~46 µs/item) | 74.7 s (~1.49 ms/item) | 32× |
| `[?for]` over 200k, 6-arm `[?match]`, no libs vs FIVE LIBS loaded | 8.9 s | 357 s | 40× (#1237: the closures clone per arm) |
| the same `[?for]`+`[?let]`, no libs vs five libs | 1.73 s | 1.80 s | 1.04× (libs do not fatten bindings) |

Boot is ~0.12 s in every cell. 300 bindings is not exotic: a handler that destructures a request
into a dozen locals under a program with a few dozen top-level lets, inside a `[?for]` with two
`:let` clauses, copies the whole set on every clause of every item. At 32× the flat copy is not a
constant factor on the evaluator — it is the evaluator's cost on any shape with a non-trivial frame,
and it is invisible in the thin fixtures the conformance corpus is made of.
