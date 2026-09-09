# Ruling — the playground's audited answer is pinned in a GENERATED file, not spliced into the hand-authored corpus (#1170)

**Ruling id:** 1170-a
**Date:** 2026-09-08
**Ruled by:** campaign worker C, long-term-best standard (owner rule 7 of #1354).
**Status:** RULED, recorded BEFORE the work.

## The defect being closed

`make verify-playground-examples` replays all 182 playground examples through
native `cx` and fails on a non-zero exit or an unterminated note comment. It
records no answer and compares none. So a semantics change retires an example's
MEANING while the gate stays green: after R-A1 (2026-08-25) retired the bare
`[name …]` builtin call, fourteen examples stopped computing what their note
claims and every one of them still exits 0 —

```
20-string-concat   [concat "hello" ", " "world"]   →  [concat 'hello', ', ', 'world']
                                                      note claims 'hello, world'
118-odd-even-partition  [?if [odd $n] …]           →  every item takes the `then` arm
```

Re-measured at HEAD on the shipped binary before this ruling: `[concat …]` still
echoes, `[$concat …]` still answers `'hello, world'`, and `[$nth (10,20,30,40) 2]`
answers `20` (1-based), not the `30` example 72's note claims.

## The question

#1170 §C1 proposes recording the audited output per example as an
`[out [# … #]]` payload "written by `playground-examples-regen` and diffed by
`--check`". WHERE that payload lives is the design choice, and it is a real
fork:

- **(a) spliced into `examples.cxd`**, beside the `[src]` and `[note]` it must
  agree with.
- **(b) a separate generated `examples.out.cxd`**, owned wholly by the
  generator, keyed by `key`, in corpus order.
- **(c) an `expected:` field in the generated `playground.examples.js`.**

## The ruling — (b)

**Deletes:** (a)'s premise that the generator may write into its own
hand-authored input, and (c)'s premise that the shipped page bundle is the
right place to keep a review artifact.

Reasons, in order of weight:

1. **A generator must not rewrite a hand-authored file.** `examples.cxd`
   carries a hand-written `[doc]` block whose own text explains a raw-text
   delimiter convention it cannot spell literally, plus per-entry formatting no
   AST re-render reproduces. The generator reads the corpus through
   `cx --ast --compact` (RawText is opaque to the in-process CXDM), so a
   rewrite from that AST would lose the doc block and every formatting choice;
   the alternative — line-splicing the raw file — puts a fragile text
   transform in the path of the only copy of 182 hand-authored examples. This
   repo already has one generator documented as owning a hand-authored corpus
   (`design/787/tools/gen_ux_fixtures.cx`) and it would delete seven fixtures
   if run as documented. Do not build a second.
2. **Authored and measured stay separate.** `[src]` and `[note]` are claims a
   human makes; the pin is what the binary did. Keeping them in one file makes
   that file half-generated, which is precisely how a reviewer stops trusting
   either half.
3. **The review moment is preserved exactly.** (a)'s whole benefit is that a
   changed answer becomes a diff the author must accept. A generated
   `examples.out.cxd` produces that same diff, in the same commit, adjacent in
   the diff view — and `--check` reds until the author regenerates and accepts
   it. Nothing about the benefit depends on the two payloads sharing a file.
4. **(c) is refused for cause:** `playground.examples.js` is what the reader's
   browser downloads. A pin is a review artifact for this repository, not
   payload for the page, and growing the shipped bundle by every example's
   expected output to buy a gate is a cost with no reader-side benefit.

## The shape

`scripts/gen_guide/playground/examples.out.cxd`, generated, header says so:

```
 [ex key=20-string-concat chars=31
  [out-text [#
[concat 'hello', ', ', 'world']
#]]
 ]
```

- `[out-text [# … #]]` is the house spelling for a pinned program answer —
  the same element the conformance corpus uses (`conformance/code.cxd`), so
  there is ONE shape in this repository for "what this program prints".
- `[err-text [# … #]]` is emitted only when the child wrote to stderr.
- `chars=` records the captured length, so the payload convention's normalized
  final newline can never hide a truncation.
- An example carrying the existing `[no-stable-value [# … #]]` marker (its
  native result is a race) is recorded as `no-stable-value=true` with no
  payload — the same three-state vocabulary `make test-playground-wasm-eval`
  already grades, not a fourth spelling.
- A captured output containing the raw-text terminator is a REFUSAL naming the
  key, matching the corpus's own stated limit, never a silently malformed pin.

## Scope note — what this ruling does NOT decide

#1170 §C2 (a corpus lint refusing a bare builtin head in `src`) is left
unruled here on purpose: the sound implementation consults the engine's own
`builtin_dispatchable` table (`vcx/code/eval.v:7077`) rather than a sixth
copy of the name list, and reaching a V-side classification table from a CX
generator ADDS SURFACE. That is the same wall #1351 hits for the err
classifier, and the two must be ruled together rather than each inventing a
spelling. Letters are drafted on #1170.

§C3 (a `[?let]`-cascade lint) and §C4 (a note↔output consistency check) need no
new surface and are the worker's to rule; they follow the pin, because both
read it.


## 1170-d / 1170-e / 1170-f — the mermaid gate joins the matrix (RULED, Fable 2026-09-09 05:07 ET)

**1170-d (Q1 a):** the three `203-quote-homoiconic` `output` rows are the
emitter-internal `cx:` image, which approved spec keeps unreadable (E210 stays
intact; semantic_value_model.md §2 L78 lowers quoted trees at the I1 epoch,
#708). They are a NAMED, COUNTED skip — `cx: image (1170-d)` in the gate's
summary, reason string cited on every skipped row — not a failure and not a
silent pass. Self-clearing: when L78 lands the image stops matching.

**1170-e (Q4 a):** `test-playground-mermaid` grades a bundle it BUILDS or PROVES
FRESH: `wasm-fresh-gate` (#992) first; `build-playground` (both wasm variants the gate names, ~2 min measured) when it reports stale; refuse
if it still does. Refused: a tracked multi-megabyte bundle (new surface for a
problem the freshness gate already solves); enrolling as-is; leaving it manual.

**1170-f:** enrollment order — #1349 landed every constant-minted id (`lh`, `lb`,
`b` at `fb3a3b686`; `u` at `50b2f3b2c`) → the named skip → the prerequisites →
`test-playground-mermaid` in `TEST_TARGETS`, one landing. GATE_REGISTER gains
row 9.1; `scripts/test_changed.sh` gains the lane's input row so the
development loop can skip it when none of its inputs moved.

Red-proved in a fresh worktree at `94835ad43` (`lane_F_1170_p1.log`): with the
bundle built from THIS tree and proven fresh, the gate failed on exactly the
three `203` output rows and nothing else — the #1349 rows were gone.
