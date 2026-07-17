# `cx-x/adjudicate` — out-of-band agent adjudicator for the `similar` review band

```cx
[module-meta name=adjudicate tier=x status=experimental]
```

**Status:** Experimental (`x/` tier — exempt from the frozen-stability promise; cx-private #6 D3). Graduated to 03-approved by owner ruling (G3), 2026-07-13.
**Provenance:** the follow-up gated in [`similar.md`](../std-lib/similar.md) §5.3 (owner ruling Q4, 2026-07-13), tracked and delivered as cx-private #376.

## §1. Scope

`similar`'s v1 cascade terminates at the deterministic tiers; the `review` band always exits as **data** (similar.md §5.3), and resolutions re-enter on a later run as the known-verdicts resolver tier (§5.4). This module is the **agent adjudicator over that review residue** — implemented **out-of-band**, as the #376 sketch prescribes:

> an adjudicator is just a **producer of resolution records** with `decided-by="agent:<model>"` provenance; no cascade change needed, no new surface in `similar`.

Concretely: `cx-x/adjudicate` consumes review-band `[pair …]` elements (the shape `join` emits, similar.md §5.1) and produces `[resolution verdict=… decided-by=… [left V] [right V]]` records — exactly the value the `resolutions:` predicate option already consumes. The live consumer is the known-verdicts tier that shipped with #108; this module is the producer side of an existing seam, not a new seam.

**Out of scope — permanently, not deferred:** an *in-band* resolver tier (the cascade calling a model during scoring). similar.md §5.2/§5.4 pin deterministic re-runs; a model call inside the cascade would break that guarantee. The determinism story stays exactly §5.4's: the adjudicator runs *between* runs, its output is an **input table** to the next run, and identical input + identical resolutions ⇒ identical end state.

## §2. Conceptual model

```
run N   : [$join L R {on: $pred}]            → {applied, review-queue, new}
between : [$adjudicate:adjudicate base model review-pairs]  → resolution records   (this module)
run N+1 : $pred + resolutions: (records…)    → resolved pairs short-circuit, §5.4
```

- **Provenance.** `decided-by` is `"agent:<model>"` (e.g. `"agent:mistral"`) — the same free-form string field a human reviewer fills with their own identity. Consumers distinguish agent from human adjudication by the `agent:` prefix; nothing in `similar` changes.
- **Safe default.** A model reply that parses to none of the three verdicts yields verdict `:review` — under §5.4 the pair short-circuits to the conventional indeterminate (0.5/`:review`) and **stays held**, now with provenance recording that adjudication was attempted and was inconclusive. An adjudicator can refuse; it can never silently promote.
- **Caller filters.** `adjudicate` returns *all* records including `:review` verdicts; whether inconclusive records are merged into the next run's table or dropped (leaving the pair's true score visible) is caller policy — `decisive` is the one-verb filter for the common "merge only firm verdicts" case.
- **Model capability is a deployment property, not a module property.** The module is correct for any `/api/chat` endpoint; verdict *quality* depends on the model behind it. The empirical gate check for #376 (2026-07-13, this repo) found llama3.2-3B too conservative (routes everything to `:review` — safe but useless) while mistral-7B adjudicates the canonical cases (punctuation variants, typo+corroborating-field, abbreviation expansion, same-name-different-DOB) correctly with clean one-word format discipline. Guidance, not contract.

## §3. Public surface

Pure shaping/parsing is split from the effectful calls (the `cx-x/llm` pattern), so the contract is testable without a network.

```
[?def prompt-of     scope=public pure   [returns string]  ($pair::element)]
[?def verdict-of    scope=public pure   [returns atom]    ($reply::string)]
[?def resolution-of scope=public pure   [returns element] ($verdict::atom $decided-by::string $left::any $right::any)]
[?def decisive      scope=public pure   [returns any]     ($records::any)]

[?def adjudicate-pair scope=public impure [returns element] ($base::string $model::string $pair::element)]
[?def adjudicate      scope=public impure [returns any]     ($base::string $model::string $pairs::any)]
```

- **`prompt-of`** — render one review pair as the adjudication prompt. `left`/`right` payloads render via `format:canonical` (byte-stable, round-trippable — the model sees real CX literals); the pair's `score=`/`band=` attributes and `[evidence …]` child are included when present. The prompt instructs a one-word reply: `match` / `no-match` / `review`. The exact prompt text is **not** version-stable (x/ tier; prompt engineering may evolve) — fixtures pin structural properties (both payloads present, the three verdict words present), never the full text.
- **`verdict-of`** — parse a model reply to a verdict atom. Normative rule: case-fold, then **precedence** (not position): `no-match` (accepting `no match` spacing) is checked before `match` (substring hazard), then `review`; no hit → `:review` (the safe default of §2).
- **`resolution-of`** — build one `[resolution verdict=V decided-by=D [left A] [right B]]` record (the similar.md §4.1 `resolutions` row shape). Pure constructor; carries whatever `decided-by` it is given, so human tooling can reuse it.
- **`decisive`** — filter a record sequence to firm verdicts (`:match`/`:no-match`), dropping `:review` records.
- **`adjudicate-pair`** — `prompt-of` → `llm:complete` → `verdict-of` → `resolution-of`, with `decided-by = "agent:" + model`. A pair missing a `left` or `right` child is a caller error and fails loudly (path/absence propagation), never a fabricated record.
- **`adjudicate`** — `adjudicate-pair` mapped over a sequence of pairs (via the `fp` functor); returns the record sequence in input order, ready to carry on a predicate as `resolutions:`.

## §4. Capability posture

The pure surface charges nothing. `adjudicate`/`adjudicate-pair` inherit `cx-x/llm`'s posture: run under a **scoped net grant** for the model endpoint only (`--allow-net=127.0.0.1:11434` for local Ollama), never `--allow-all`. The adjudicator writes nothing — producing the resolutions table is a return value; persisting/merging it is the caller's own (separately granted) effect.

## §5. Composition

An adjudicator is a Runnable like everything else in the `x/` tier:

```
[$run:batch [?fn ($p) [$adjudicate:adjudicate-pair $base $model $p]] $review-pairs]
```

is `adjudicate` modulo the convenience packaging — the module verb exists because the review-queue → resolutions step is the load-bearing #376 case and should be one call.

## §6. Errors

No module error band. Malformed input surfaces as the underlying error value (absent `left`/`right` → path absence propagation; transport/JSON failures propagate from `http`/`json` exactly as in `cx-x/llm`). `verdict-of` never errors — unparseable text is `:review` by §3's normative rule.

## §7. Conformance

`conformance/stdlib/adjudicate.cxd` (gate `enforced`) pins the pure surface:

- `verdict-of`: the three clean verdicts; case variants; `no-match`-before-`match` precedence; `no match` spacing; verdictless/garbage reply → `:review`; a reply embedding several verdict tokens resolves by precedence.
- `resolution-of`: record shape; verdict/decided-by attrs typed; left/right payload round-trip for string / map / element values.
- `prompt-of`: structural pins only (renders both payloads canonically, mentions all three verdict words, includes score when present, tolerates a score-less/band-less pair).
- `decisive`: filters `:review`, keeps order, empty-input identity.
- an end-to-end determinism fixture: records produced by `resolution-of` fed to a `[$similar:predicate {resolutions: …}]` short-circuit with `decided-by` provenance — the §5.4 consumer is live (mirrors similar-079..082 from the producer side).

The effectful path is pinned by a mock-server round-trip (`vcx/tests/adjudicate_real_test.v`, the `llm_real_test.v` pattern): a local `/api/chat` stub returns a scripted verdict; `adjudicate` yields the full record with `agent:<model>` provenance; feeding it back into a real `similar` join flips the pair out of the review band.

## §8. Cross-references

- [`similar.md`](../std-lib/similar.md) §4.1 (`resolutions` option), §5.1 (pair shape), §5.3 (routing; the Q4 cut this module lifts), §5.4 (resume seam + determinism).
- [`README.md`](README.md) — tier doctrine (`cx-x/llm` provider, Runnable composition).
- [`format.md`](../std-lib/format.md) — `canonical` rendering.
- cx-private #376 (the gating issue), #108 (the `similar` implementation that shipped the consumer tier).
