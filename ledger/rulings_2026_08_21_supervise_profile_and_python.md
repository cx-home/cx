# Rulings 2026-08-21 — supervise's id source + the profile gate, and the stale Python svg test (#895, #897)

## SPF-1 — a unique id is not a scheduler's to lend; a missing pack refuses at composition

**Status:** RULED (release-blocking: both reds keep `make test` at RC=2 at the
v0.16.0 cut tip `aafb6118`). Scope: `stdlib/supervise.cx`,
`conformance/stdlib/supervise.cxd`, `spec/03-approved/std-lib/supervise.md`,
`spec/03-approved/process/governance.md` §9.6,
`lang/python/test_code_eval.py`.

---

### The two reds

**#895 — `profile_gate[embed]`: 50 failures of 2513 graded, every one
`supervise.cxd`.** 25 cases × {eval, bin}, each surfacing as
`cx-err:CXER0001: [?channel] requires :name`. The `cli` composition is green;
the embed composition is built with the nine `-d cx_no_pack_*` exclusions,
`cx_no_pack_sched` among them.

**#897 — `test-python`:** `test_svg_target_returns_diagram` calls
`cxlib.eval_code('', …, 'svg')` and gets `CXER0271 E_CAP_DENIED: subprocess
capability required…`. The refusal is the *intended* consequence of `7888e884`
(RULED: DSC-1 — graphviz formats charge for the effect). The test did not move
with the behavior.

---

### The finding behind #895 — a scheduler timer used as a UUID source

`sup--alloc` (stdlib/supervise.cx:80) minted the per-supervisor unique id like
this:

```
[?def sup--alloc scope=private impure [returns string] ()
  [?let [= $null-ch [?channel name="cxsup-devnull" buffer=1]]
    [= $dur [$time:duration-h 240]]
    [= $t [$sched:after $dur $null-ch]]
    [= $_ [$sched:cancel $t]]
    [$concat "" $t@name]]]
```

It armed a **240-hour timer** against a devnull channel, cancelled it
immediately, and kept **the timer's synthesized name** as the id. That name is
`timer-${id}` from `sch_synthesize_name` — i.e. the id is really
`sched_reg().next_id`, the scheduler registry's own monotonic counter
(`vcx/code/stdlib_sched_notd_cx_no_pack_sched.v:396,408`).

This is a hack even where it works: it borrows an *optional local-effect pack's*
private allocator for a need that has nothing to do with scheduling, and pays
for each id with a timer arm + a registry insert + a cancel. Where the pack is
absent the borrowed name is empty, the derived channel names collapse, and the
first honest complaint arrives **25 fixtures deep** as `[?channel] requires
:name` — a message that names neither the cause nor the fix.

**RULED:** an identity allocator is core business. A module MUST NOT source its
identities from an optional pack.

---

### (a) The id source — RULED: the evaluator's own handle counter, via `[?subscribe]`

`cx-stdlib/uuid` was investigated first and **REJECTED on evidence**, not on
assumption. `vcx/code/stdlib_uuid.v` indeed carries no
`_notd_cx_no_pack_` suffix and so compiles in every profile — but its
generators are **capability-gated**:

```
const uuid_random_prims = ['uuid-v4', 'uuid-v4-bytes', 'uuid-v7', 'uuid-v7-bytes']
… if d := cap_guard('random', name) { return d }      // stdlib_uuid.v:409-414
```

Live-verified at BOTH the platform and the embed profile: `[$uuid:v4]` /
`[$uuid:v7]` return `E_CAP_DENIED` with no grant and succeed only under
`--allow-random`. So uuid does *function* under the embed defines — v4's
`crypto.rand` and v7's clock are V-level imports, not the CX `random`/`time`
packs — and the profile was never the disqualifier. **The capability is.**
Adopting
them would give `[$supervise:start]` a **`random` capability requirement**,
which contradicts supervise's own contract — "It adds NO new concurrency
primitive and NO capability (§5)" — and would break every conformance case,
which runs ungranted. The name-based `v5`/`v3` are pure and cap-free but need a
unique input, which is the circular problem.

**RULED source:** the evaluator's process-global handle counter
`env.state.next_close_id` (`vcx/code/matcher.v:252`), reached through the
`__cx_close_id__` stamped on a `[?subscribe]` handle by `closeable_stamp_core`
(`vcx/code/eval.v:16844-16851`). `[?channel]`, `[?subscribe]` and `[?close]` are
**core directives** — Ring-0/1 evaluator surface, present in every profile, and
carrying no capability. Supervise already uses all three.

Why this is the genuine article and not the same hack relocated: the sched
version borrowed *a different subsystem's* private counter as a side effect of
arming work it did not want; this reads **the identity allocator that the
evaluator maintains precisely to distinguish handles**, which is what a
per-supervisor identity is. It is also strictly cheaper (no timer, no registry
insert, no cancel) and it cleans up after itself with `[?close]`.

Uniqueness is proved, not assumed — the conformance corpus gains a case
starting **two supervisors under identical config in one process** and asserting
distinct identities.

### (b) The composition refusal — RULED: CXER5095 `E_SUP_NO_SCHED`

Fixing (a) makes supervise *compose* without the scheduler, but it does not make
supervise *work* without it: backoff delays, the intensity window and
attempt-reset all ride sched timers, and `[$sched:test-clock-advance]` is what
makes the restart fixtures deterministic. A supervisor in a no-sched build is a
supervisor that silently never backs off, never expires its window and never
resets attempts. That is worse than a refusal.

**RULED:** `[$supervise:start]` refuses **at composition** in a build with no
scheduler, with a typed error that names the missing pack and what it is needed
for. New code in the module's own band:

- `CXER5095 E_SUP_NO_SCHED` — the local-effect pack `sched` is absent from this
  build; supervise needs it for backoff delays, the intensity window and
  per-child attempt-reset.

Registered in `spec/03-approved/process/governance.md` §9.6 alongside
5090–5094; 5096–5109 stay reserved.

**The probe must CONSUME its result — a lazy binding made the refusal dead
code.** The first spelling of `sup--has-sched` was
`[?fallback [?let [= $_m [$sched:clock-mode]] true] [recover-with false]]`.
A `[?let]` binding is LAZY: `$_m` is never read, so `[$sched:clock-mode]` was
never called, the fallback never fired, and the function answered a constant
`true` — leaving the CXER5095 arm unreachable in precisely the build it exists
for. Under embed, `[$sup:start]` went on composing a live supervisor. Caught by
the `dependent_module_probe` added for (c); without that probe the refusal
would have shipped as a seam with no live consumer, passing review because the
source reads correctly. The probe now forces the call by comparing the rendered
mode (`[not [= [$concat "" [$sched:clock-mode]] ""]]`).

**Position of the check — RULED: after argument validation, before the mint.**
Parsing and validating the policy and child specs is pure and
profile-independent: a malformed policy is a caller bug in every build, and
`CXER5090`/`CXER5091` remain the answer to it everywhere. *Composition* begins
where the supervisor's identity, channels and worker are minted; that is where a
missing substrate is the truthful complaint. This is also what the observed
failure counts already say — 5 of the 30 cases (sup-018…sup-022, the CXER5090
arg faults) pass in embed today because they never reach the mint, and they
keep passing unchanged.

### (c) The gate declaration — RULED: the general `packs=` mechanism, per case

The profile gate already has a **general, per-case** declaration:
`fixtures.FixtureCase.packs`, parsed from a `packs=` attribute
(`vcx/fixtures/fixture_loader.v:32,154`) and consumed by `needs_excluded_pack`
(`vcx/tests/runners/profile_gate/profile_gate.v:279-287`), which skips a case
whose declared pack this composition excludes. Precedent in tree:
`conformance/code.cxd:8109` (`packs=http-client`), `:16227` (`packs=env`).

The gate's other, coarser mechanism — the `pack_suite` map at
`profile_gate.v:93`, keyed pack → suite basename — is a **hardcoded
special-case by name**. It is NOT extended here.

**RULED:** the 25 cases that compose a live supervisor declare `packs=sched`.
The 5 pure argument-fault cases do not (they neither need nor touch the
scheduler, and grading them in embed is real coverage). The refusal from (b) is
itself covered by a new case in the same suite.

---

### #897 — the premise INVERTED on contact: the test passes because a capability check is missing

The issue reads "the refusal is correct, the test is stale". **At the cut tip
`aafb6118` that is no longer true, and the direction of the defect is the
opposite one.** Measured, before any edit:

- `cxlib.eval_code('', …, 'svg')` with no grant **does not raise** — it returns
  a 218-byte dot-less envelope carrying `<cx:source>`. The stale test therefore
  **passes**, and the whole `test_code_eval` file is green (19/19).
- `cx diagram … --format=svg` with no grant **does** refuse, `CXER0271`, naming
  `--allow-subprocess`. The CLI honours DSC-1c; the ABI does not.

DSC-1c is unambiguous on both points: `svg`/`png` "REQUIRE the `subprocess`
capability", "**The denial is NOT the envelope**", and the rule "lives in
`cx-stdlib/diagram`'s `render-svg`/`render-png`, so every caller — `cx
diagram`, `cx eval --target=svg`, **the ABI**, an embedding — sees it."

So the Python test was green for the wrong reason: it was passing over a
**capability bypass**. A caller denied `subprocess` was handed a plausible SVG
document instead of a refusal.

### SPF-2 — the third release-blocking red, unreported until now

Chasing it surfaced a red neither #895 nor #897 names:

```
vcx/tests/code_units_umbrella_test.v:128
  fn test_eval_code_svg_target_refuses_without_the_subprocess_grant
  Message: svg: expected a capability refusal, got 218 bytes
FAIL  code_units_umbrella_test.v   (1 failed, 1 total)
```

That test was authored WITH DSC-1c and encodes the correct contract. It is RED
at the cut tip. `make test` therefore has **three** reds, not two.

**Cause.** `render_diagram` — the `eval_code(target=…)` path used by the ABI,
the Python/Go/Rust bindings and every embedding — routes through
`cx-stdlib/diagram`'s `of-source`, **not** through `render-svg`/`render-png`.
DSC-1c added the `cap-denied` arm to `render-svg`/`render-png` only. Wave 3
(#889, DRW3-1) left `of-source`'s inline vector arms on the pre-DSC-1 shape:

```
[?let [= $r [?else [$process-run ("dot" "-Tsvg") …] [dot-unavailable]]]
  [?if [$dot-ok $r] [then …splice…] [else [$svg-envelope $src]]]]
```

— `[?else …]` flattens the denial into `[dot-unavailable]`, there is no
`[$cap-denied $r]` test, and every denial lands on the envelope branch.

**Severity, measured — no unauthorized execution.** The 218 bytes the failing
test received are byte-for-byte the dot-less envelope, confirmed by producing
it deliberately (`PATH=/nonexistent … --format=svg --allow-subprocess` → 218
bytes, `viewBox="0 0 1 1"`). Real graphviz output is nothing like it
(`width="78pt"`, a DOCTYPE, a `Generated by graphviz` comment). So `dot` never
ran ungranted: this is a denial **silently degrading to a fallback document**,
not a capability escape. Release-blocking and security-shaped, but the
distinction matters and is recorded here so it is not overstated.

**De-duplication was attempted FIRST, and REFUSED — measured, not assumed.**
The obvious fix is to delete the duplication rather than repair a copy, so the
inline arms were collapsed to `[$render-svg $img $src]` /
`[$render-png $img $src]` (four hops → two), built, and run. The wave-2
justification for the inlining — which this ruling had provisionally doubted,
on a reading of `classify_callee`'s recursion into `checker.defs` — turns out
to be **correct**, and `eval_semantics_umbrella` refuses the collapsed shape:

```
these stdlib defs DECLARE impure but reach no callee the engine classifies
impure … (#788): diagram:of-source
```

The #788/#818 parity check counts impure BUILTINS only; an impure `[?def]`
callee does not satisfy it (`classify_callee`'s def recursion serves the other
direction — keeping a *pure* def from reaching an impure one). Delegating would
leave `of-source` declaring `impure` while reaching nothing the engine treats as
impure, so a pure-required context would silently admit a def that shells out —
a worse defect than the one being fixed. **The four arms stay.**

**RULED (SPF-2a): duplication the language cannot remove must be GUARDED.**
Because the copies are load-bearing and cannot be collapsed, a source scan
pins them identical: `test_every_dot_hop_carries_the_dsc1c_refusal`
(`vcx/tests/code_diagram_roundtrip_test.v`) walks `stdlib/diagram.cx`, finds
every `process-run ("dot"` site, and fails unless each captures the err code
(`[recover-with [dot-failure code=$err@code]]` — a bare `[?else …]` is the
exact shape that flattened the denial) and answers `[$cap-denied]` with
`[$dot-denied-err]`. It also asserts the hop COUNT stays ≥ 4, so the scan
cannot pass vacuously by finding nothing after a refactor. This is the gate
that was missing: DSC-1c changed one copy of a rule that lived in four places,
and nothing was watching the other three.

**RULED (SPF-2):** a second call site for one effect must also be a second call
site for one capability rule. `of-source`'s `svg` and `png` arms take the
`[?fallback … [recover-with [dot-failure code=$err@code]]]` + `[$cap-denied]` →
`[$dot-denied-err]` shape verbatim from `render-svg`/`render-png`. Two further
private copies carrying the same stale shape — `of-source-svg` /
`of-source-png`, **called by nothing** — are DELETED, not repaired: an uncalled
copy of a superseded capability rule is a trap, not a spare. That takes the hop
count from six to four — all four now correct, and SPF-2a's scan holds them
there.

### The Python test — RULED: assert the surface DSC-1 ruled, and widen it

With SPF-2 landed the refusal is real on the ABI path, so the shape the issue
proposed becomes the right one. **RULED:** replace the single stale case
(whose comment still describes Phase 4.1) with three, so coverage *widens*:

1. **positive, capability-free** — `mermaid` returns a diagram carrying
   `cx:source`. This keeps a live "returns a diagram" assertion on the path
   that needs no grant.
2. **the typed refusal** — `svg` with no grant raises `CXER0271` naming the
   `subprocess` capability. This pins DSC-1 rather than tolerating it.
3. **the granted happy path** — `cxlib.eval_code_caps(…, caps='subprocess',
   …, 'svg')` returns the diagram. The binding already exports the
   capability-aware entry (`lang/python/cxlib/cx.py:388`), so the granted path
   is exercised for real; the case skips when graphviz `dot` is absent from the
   host, since that is a toolchain fact and not a contract.

---

### Dispositions

| # | Disposition |
|---|---|
| #895 (a) | `sup--alloc` re-sourced onto `[?subscribe]`'s `__cx_close_id__`; uuid REJECTED (capability-gated) with the evidence recorded above |
| #895 (b) | `CXER5095 E_SUP_NO_SCHED` refuses at composition; registered in governance §9.6; stated in supervise.md |
| #895 (c) | 25 live-supervisor cases declare `packs=sched`; gate untouched; no name special-casing |
| SPF-2 | `of-source`'s svg/png arms gain the DSC-1c `cap-denied` refusal (the ABI path was bypassing it); the two dead private copies deleted; `code_units_umbrella` — a THIRD, unreported cut red — goes green. De-duplication attempted first and REFUSED by the #788 parity check (measured); the four arms stay |
| SPF-2a | `test_every_dot_hop_carries_the_dsc1c_refusal` scans `stdlib/diagram.cx` and fails any `dot` hop missing the refusal, with a ≥4 hop-count floor so it cannot pass vacuously |
| #897 | one stale case → three (mermaid positive, svg refusal typed, svg granted with a `dot` skip) |

Closes #895, #897.

**For the owner.** SPF-2 was not in either issue's scope and is a capability
bypass on the embedding surface, so it is called out separately in the report
rather than buried here: between DSC-1c (#890) and the cut, `eval_code`'s
`svg`/`png` targets stopped charging for `subprocess` while `cx diagram` kept
charging. Any consumer that took the ABI path in that window was served
envelopes where DSC-1c says they should have been refused.
