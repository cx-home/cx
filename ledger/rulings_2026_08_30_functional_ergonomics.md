# Rulings 2026-08-30 — functional/structural ergonomics campaign (FE)

**Status: RULED — FE-1..FE-6 accepted (a) BY OWNER 2026-08-30 (letter
acceptance "1a"; FE-6 remains conditional on the #1138 probe, its design
letters return to the owner only if the probe finds a gap).** W1 execution is
unblocked. Filed together with the campaign issue set (label
`ergonomics campaign`; umbrella/scoreboard **#1144**; members #1135–#1143).
Rulings recorded before work per the #832 process rule.

**Origin.** An ergonomics evaluation (2026-08-30, Fable session) audited a
five-item improvement proposal against the approved spec, the formal grammar,
the full ledger, and live probes of the shipped `cx v0.17.0` binary
(@ 9dcd2297c). Finding: the grammar is ahead of the engine — the concise
language already exists on paper; the engine, one lookup surface, and the
teaching corpus have not caught up. Every ruling below either trues the engine
to its own spec, extends an existing form to its natural domain
(spec-authoring-guide.md §3 UNIFORM), or papers a refusal so it stops being
re-litigated. The set adds zero new sigils, zero new directives, zero new
builtin names.

**Non-interference.** This campaign touches no codec/format surface and is
sequenced around the running #1126 codec/Ring campaign. No cell of
`ledger/matrix_2026_08_30_format_surface.md` or
`ledger/matrix_2026_08_25_path_value_model.md` is changed by any FE item.

---

## FE-1 — operator-form holes are the first-class-operator mechanism

**Recommended: (a).**

- (a) Implement the holes grammar already admits: [125f] `OperatorForm` takes
  [125a] `ProgramArg ::= Hole | …`, so `[+ _ 1]` (unary partial) and
  `[+ _ _]` (binary operator value) are grammatical today; only the engine
  refuses (live: `no callable "f"` / `[?pipe] non-callable stage`). Fixing the
  divergence yields first-class operators with zero new surface:
  `{'+': [+ _ _], '-': [- _ _]}` is the op table, and the value is the
  operator's own shape (design constraint C7 — patterns, values, templates
  share one syntax).
- (b) Word-twin builtin family (`$add $sub $mul $lt $lte $gt $gte $neq`) —
  HELD IN RESERVE, not refused outright: it adds ~8 permanent names and a
  second spelling of every operator for the marginal gain of n-ary callables.
  Reopen only on corpus evidence that `[+ _ _]` reads badly at scale.
- (c) Lexable `$+` — REFUSED: `$` binds to a Name ([125], [L62]); admitting
  `+` as a Name leaks into every Name position or becomes a special case
  (UNIFORM defect by construction), and the operator-head lexer surface was an
  I1 identity-epoch cutover ("never a second one") — hash-exposed.
- (d) New sigil `&+` — REFUSED: `&` is `AnchorDef` [60] and `EntityRef` [66]
  (live: `&+` errors as unterminated entity reference); C1 caps sigils at ≤5.

Semantics pin to record at impl: operator partials obey §6.3a exactly (holes
fill left-to-right; a filled `[+ _ _]` applies the binary operator fold with
its normal numeric rules); a hole-bearing operator form in pipe-stage position
follows §8.9.1 (at most one hole).

## FE-2 — single-arm `[?match]` honors grammar [136]; it is the destructuring bind form

**Recommended: (a).**

- (a) Fix the divergence: grammar [136] alt-2 admits full `MatchPattern` in
  the single-arm second slot; the engine accepts element `ProgramPattern`
  only (live: `[?match (10, 20) ($b, $a) [yield …]]` →
  `CXER0100: [?match] second slot must be a pattern`). Fixed,
  `[?match $stack ($b, $a, *$rest) [yield …]]` is the one-line
  destructure-or-refuse binding — fail-loud (NO_MATCH per §8.2), no new
  syntax. One fixture per pattern kind in single-arm position, positive and
  negative (G3/UNIFORM obligation).
- (b) Pattern LHS in `[?let]`'s `[= …]` clause — REFUSED: `[=]` is overloaded
  (binding-clause head AND the reserved equality operator); `eval_let`
  disambiguates positionally, so `[= ($b, $a) $stack]` is already a
  well-formed equality test — a genuine ambiguity, not a free slot. Deeper:
  §14.3 partitions bind forms (total) from match forms (partial); a pattern
  LHS silently reclassifies `[?let]`. With (a) in place a let-pattern would be
  pure duplication.
- (c) `..$rest` rest spelling — REFUSED: rest is `*$rest` ([140f], §5.2 rules
  11–13, "one rest-marker per kind"); `..` is the parent step (RULED BP-1).

## FE-3 — `[?for]` pattern position extends to the full pattern grammar, refuse-on-miss

**Recommended: (a).**

- (a) Extend [129b]/[129b1] from element-only `ProgramPattern` to full
  `MatchPattern`, enabling `[?for [in ($k, $v) $pairs] …]`. Miss semantics:
  **refuse loudly** (the fail-closed posture, same grounds as `[?let]`'s loud
  rejection of a malformed clause) — silent skip is silent data loss.
  Filtering-by-shape remains `[where]`'s / `[?match]`'s job. §14.3 already
  places `for`'s pattern slot in the match row, so no core-form
  reclassification occurs.
- (b) Skip-on-miss — REFUSED (silent data loss; and irreversible once code
  depends on it).

## FE-4 — §12.2.4 parameter shapes govern `[?fn]` and `[?def]` alike

**Recommended: (a).**

- (a) True `[?fn]` params up to the three spec'd shapes (positional,
  named-with-default, rest `*$name` + `::T` annotations). Live today `[?fn]`
  accepts plain `$name` only — no defaults, no rest — strictly poorer than
  §12.2.4 with no written rationale.
- (b) Pattern parameters — DEFERRED, not refused forever: grammatically
  ambiguous with positional defaults ([153b] — a bare value after a param is
  that param's default), and they make every call boundary a match site
  (~20–45µs vs ~2µs measured). The body-position idiom costs one line after
  FE-2. Reopen trigger: post-FE-2/FE-4 corpus evidence of recurring measured
  pain, plus a design resolving the [153b] ambiguity.

## FE-5 — expression call heads stay refused; bind-first is the papered posture

**Recommended: (a).**

- (a) Record the refusal normatively (today it lives in a grammar comment on
  [125]): a call head is a name, not a value; `[$ops.key 1 2]` refuses with
  guidance to bind first (`[?let [= $f $ops.key]] [$f …]`). Grounds:
  `ProgramCall.name` is a string in the AST (an expression head is a new AST
  node — L effort), PS-1 ruled heads carry no steps, and bind-first keeps the
  callable inspectable. Reopen trigger: op-table dispatch density in real XAPs
  making the extra bind a measured repeated tax.

## FE-6 — computed-key map lookup (CONDITIONAL — probe first)

W1 opens with a live probe: does a computed-key map read exist (lookup where
the key is a runtime value, absence on miss so `[?else]` supplies defaults)?
Verified surface covers static keys (`$m.key`). If the probe finds the surface
exists, FE-6 is vacated. If absent, it is a UNIFORM finding (sequences take
expression indices; maps would not) and BLOCKS the op-table idiom that FE-1
enables; the design ruling (absence-vs-error on miss — absence recommended,
composing with `[?else]` like every other miss) comes back to the owner as
lettered options before any impl.

---

## Refusals register (summary)

| Refused | Grounds |
|---|---|
| `&+` sigil | `&` occupied ([60]/[66]); C1 sigil cap |
| Lexable `$+` | Name-lexing blast radius; I1 identity-epoch exposure |
| Pattern LHS `[= …]` | Equality-operator collision; §14.3 bind/match partition; duplicated by FE-2(a) |
| `..$rest` | Rest is `*$rest`; `..` is parent (BP-1) |
| Pattern parameters | [153b] ambiguity; call-boundary match cost — DEFERRED with named trigger |
| Operator word-twins | Permanent dual spelling — HELD with named trigger |
| `[$parse]` scalar verb | Exists as `[$cx:parse]`; scalar-coercion use is the workaround strings.md §3.11 superseded; `cast` is the locked single coercion path (2026-05-23, VC-16); codec.md §6 forbids a second conversion entry |
| Skip-on-miss `[?for]` patterns | Silent data loss |
| Expression call heads | FE-5 — papered refusal with reopen trigger |

## Campaign plan

Waves (exit = full `make test`, per the standing exit-gate rule); umbrella
scoreboard #1144:

- **W1** (defect-class truing): #1135 shadowing bug (prio:high), #1136 =
  FE-2(a), #1137 = FE-1(a), #1138 probe (FE-6).
- **W2**: #1139 destructuring fast path (perf — structural single-arm match
  lowers to flat binds, byte-identical results), #1140 (uncoded non-callable
  err + FE-4(a) param parity), #1142 riders (`[using]`/CXER0106 parity,
  `::function` stdlib signatures, CXER0291 message).
- **W3** (ruled extensions): #1141 = FE-3(a); #1138 design+impl if the probe
  found a gap.
- **W4** (delivery): #1142 spec truing + #1143 discoverability (primer
  `argv`/`cast` example, env.md cross-refs) + corpus/rosetta/antipatterns/fp
  refresh to the post-campaign idiom.

Evidence base: live-probe transcripts and spec citations recorded in the
member issues; key divergences verified against `cx v0.17.0` @ 9dcd2297c.
