# Agent-tool projection (stream 18)

**Status:** APPROVED — graduated 2026-08-20 by owner ruling SPR-1 (G3; ledger/rulings_2026_08_20_spec_tree_reshape.md). Prior status: working draft (stream 18, issue #690). Normative projection from command definitions to agent tool schemas; MCP as a generated Ring-2 edge adapter; propose-mode approval built in. Also rules the G15 spec-or-retire disposition. Normative once approved; implementation at I5.

**Worked example (M5):** `refund-order` projected end-to-end — the adapter
parses the module, selects defs with `[effects]` (THE discriminator),
emits `{name, description (from [fn-doc][summary]), inputSchema (params →
stream-16 export), outputSchema ([returns Order] → the E2 pin),
annotations}`; the agent's `tools/call` NEVER executes — the boundary
forces propose; the tool result carries the proposal + its Tier-1
address; a principal approves out-of-band with a signed Lane-2 claim
binding that address; commit re-checks, dedups, debits, journals the
authority chain. A tampered-args replay is a different address — the
approval does not apply.

## §1. Findings

1. The Runnable convention (`local fn ≡ MCP tool ≡ A2A skill ≡ pipeline
   step`) is spec'd and shipped — the projection's target contract
   exists. The MCP-server differentiator (capabilities enforce the tool
   sandbox at the effect point) is proven end-to-end.
2. **The #45 blocker is stale:** the closure-escape bug is CLOSED, the
   generic tool registry is buildable today, and four doc sites still
   claim otherwise (#715). The entire tool-ADVERTISEMENT half of MCP
   (`tools/list`; `tools-list-result` has zero callers) is unexercised.
3. **Both MCP modules pin protocol `2024-11-05`**, which predates every
   field the mandate needs (annotations, `outputSchema`,
   `structuredContent`, `_meta`, elicitation).
4. **A genuine cross-stream divergence:** stream 6 bound approvals to the
   command's Tier-2 address; stream 5 ruled Tier-2 is never a trust
   input; and stream 12's Tier-2 field ruling leaves `[effects]` OUT of
   the hash — so a Tier-2-bound approval could replay against a command
   whose declared effect set was widened. Resolved here (L139).
5. The A2A side is empty (`skills: ()` hardcoded) but structurally
   RICHER for this stream: `input-required` is a native durable
   pending-approval state, and its authority story is already DID/VC —
   the same delegation values the PEP consumes. MCP has no authority
   model at all.
6. The x/ tier is absent from the partition spec entirely — no ring,
   pack, or profile placement; the G15 fixture doc blocks cite a
   drained legacy record; the doc-freshness gate covers
   `stdlib/*.cx` only.

## §2. Approval binding — the correction (L139)

**The approval binds the Tier-1 address of the definition text** (the
trust key — it covers every clause byte-for-byte, including `[effects]`,
regardless of what Tier-2 normalizes away); the Tier-2 `code:` address
rides along for cache/equivalence only (stream 5's dual-address form).
`commands_effects.md` §5 is AMENDED accordingly — its "binds the Tier-2
`code:` address" sentence was the divergence; the Tier-1-only trust rule
stands unmodified. **`[effects]`/`[requires]`/`[preconditions]`/
`[idempotent]` do NOT join the Tier-2 hash** (the purity/scope
precedent: Tier-2 is semantic equivalence; trust is Tier-1's job) —
which is exactly why the approval must bind Tier-1.

## §3. Protocol target and transport (L138, L140)

- **Target: the 2025-06-18 MCP revision** (annotations, `outputSchema`,
  `structuredContent`, `_meta`); the 2024-11-05 pins update; no
  revision-conditional emission (one target).
- **Approval transport: out-of-band, normative** — the adjudicate
  precedent (the agent proposes as data; a deterministic engine
  disposes; the approver acts between runs). A2A's `input-required`
  task state + journaled lifecycle is the richer realization on that
  protocol. **MCP elicitation is an explicit NON-GOAL for approvals**:
  it would place the signing interaction on the agent's client,
  inverting the trust model (the agent holds only a propose-only
  sub-delegation).

## §4. The projection model (L141)

**One tool-descriptor model, derived from the command def; two lossy
adapters** (MCP, A2A), each ruling what it drops (A2A drops JSON Schema
for modes+tags; MCP drops the authority story). The projection itself is
**Ring 0/1 pure** (parse + CXPath + schema export); only the transports
are Ring 2 — "MCP as a Ring 2 edge adapter" means the adapter, never the
projection, so the same projection feeds MCP, A2A, offline export, and
the C3 docs pack (named shared consumer). Descriptors are **derived at
`tools/list` time from the loaded module tree** — no materialized
manifest, no drift (the guide-build precedent) — with an optional
`cx tools export` for offline registration, gated by golden files.
Generated adapters are never hand-edited (the bindings mirror rule).

## §5. Field mappings (L142)

| Tool field | Source | Rule |
|---|---|---|
| `name` | def name | verbatim |
| `description` | `[fn-doc][summary]` | REQUIRED for a projectable command — fail-loud at projection (L143) |
| `inputSchema` | params (name, type, defaulted, kind) via `cx schema export --to=json-schema` | `required` = non-defaulted positionals |
| `outputSchema` | `[returns T]` through the E2 pin | drift detectable by hash |
| `readOnlyHint` | `pure`, or `[effects]` ⊆ {read, env, clock} | sound: `pure`+non-empty-effects is a static contradiction |
| `idempotentHint` | the `[idempotent]` clause | EXACT; absent ⇒ false (the safe default) |
| `destructiveHint` | `= NOT readOnlyHint` | MCP's own default; no new clause |
| `openWorldHint` | `net ∈ [effects]` | ruled explicitly, not inferred |
| `_meta` | `{source: Tier-1, code: Tier-2, inputSchema-id/outputSchema-id: E2 pins, requires: cap: refs}` | the versioning + authority carriage |

**The one-way lossy-downward rule, normative:** MCP annotations are
HINTS — a courtesy for the client's UI; enforcement is at the CX effect
point (CXER0271) and at the boundary (propose mode + PEP), independent
of anything the client believes. `[requires]` projects into `_meta` for
sophisticated clients AND is enforced regardless.

## §6. Descriptions and the doc gate (L143)

`[fn-doc]` gains an additive `[param-doc name=… """…"""]` child (JSON
Schema wants per-property descriptions; `[sig]` is prose). A `[summary]`
is REQUIRED for projectability. The doc-freshness gate extends from
`stdlib/*.cx` to `x/*.cx` and every command-bearing module (#715) — a
description that becomes agent-facing tool contract cannot be ungated.

## §7. G15 disposition (L144): SPEC ALL FIVE, retire none

| Family | Ruling | Ground |
|---|---|---|
| `mcp` | Spec (rewrite at 2025-06-18) | the stream's own client half; sole consumer of frozen jsonschema's MCP justification |
| `mcp-server` | Spec (+ tools/list, the registry now #45 is closed, the propose return shape) | the campaign differentiator; this stream's implementation surface |
| `a2a` | Spec (thin: shapes + the skill seam; the empty `skills: ()` NOT ratified) | the second projection target; `input-required` = the approval slot |
| `a2a-xap` | Spec | sole did.md/vc.md corpus cover (G14); the DID/VC approval substrate |
| `llm` | Spec (minimal) | hard dependency of approved-spec adjudicate; the first Runnable |

Riders: `x/term` dispositioned in the same pass (tracker issue — same
governance hole, out of agent-tool scope); the dangling
`agentic_positioning.md` provenance refs in all five doc blocks repaired
(the #709 discipline); the four stale-#45 doc sites corrected;
**x-tier ring placement ruled** (run/mcp/a2a/llm = Ring 1 packs;
mcp-server/a2a-xap = Ring 2 — the §10 membership test applied);
explicit `gates.cxd` rows for the x-tier suites (the G17 interplay).
All in #715.

## §8. Corpus handoff (stream 14; M5 substrate)

Golden `tools/list` for `refund-order` (both protocol projections);
`tools/call` returns-a-proposal (never executes) positive + the
tampered-args different-address negative; approval-binds-Tier-1 pair
(same Tier-2, widened `[effects]`, old approval REFUSED); the
description-required fail-loud negative; `[param-doc]` presence
fixtures; registry-dispatch fixtures (the post-#45 pattern);
`tools-list-result`'s first callers.

## §9. Rulings ledger — RULED

Letters 138–145 **ruled (a) 2026-08-05 under the standing acceptance
ruling** (each verified against the long-term-best bar; L139 is a
CORRECTION to stream 6's finalized text, applied as an amendment —
the standing ruling's strengthen-on-failure clause exercised across
streams): 2025-06-18 target (138); Tier-1 approval binding + effects
out of Tier-2 + the commands_effects amendment (139); out-of-band
approvals, elicitation a non-goal (140); one model / two lossy
adapters / pure projection / derived-not-materialized (141); the field
mappings + the lossy-downward rule (142); [param-doc] + required
summaries + the extended doc gate (143); G15 spec-all-five + the
riders (144); the M5/corpus program (145). Recorded in the campaign
decision log. Spec-edit map: commands_effects.md §5 (amended), new
x/*.md specs ×5 (+term disposition), x/README + module doc repairs,
stdlib_colocated_docs.md ([param-doc], gate scope), cx_partition.md §4
(x-tier packs), gates.cxd rows, C3 cross-ref.

**L146 (ruled (a) 2026-08-14):** the projection's structured-input
surface = `[$cx:ast SOURCE]`, a pure `cx:` builtin returning the
ast.md declaration-AST JSON projection (`Program{libs, consts, defs}`;
DefNode carries structured params + the [152d–h] command clauses).
Ruled after the W1 probe program proved the def head + params are
data-layer text runs unreachable by CXPath (mixed text-fragment +
structured-node lanes; no shipped reflection). Spec-edit
authorization exercised: modules/cx.md §2.2 (the function + contract),
ast.md DefNode (additive [152d–h] + purity + positional-default — the
section's own gate-3 consistency mandate vs grammar [149]–[158]).
Encoding note: the C-ABI `program_ast_json` surface named in the
option text is the PLAYGROUND display shape, not the ast.md encoding —
the builtin emits the spec'd per-node encoding (def_node_to_json
family, tags collapsed to the spec'd `DefNode`/`LibNode`/`ConstNode`
per their own stated plan). String-only argument: a directive-as-data
focus is refused (canonical serialization quotes directive-head text
runs — not program-parseable); the module-source lane is the
projection lane, pairing with the data lane by def name. Fixtures:
code.cxd cxast-001..005.

## Identity-epoch membership (audit C9)

**ADDITIVE — this stream owns no I1 manifest row and joins no epoch.**
The projection is GENERATED surface: tool schemas, adapters, and
propose-mode plumbing derive from command definitions. Proposals carry
Tier-1 addresses and approvals bind them — this stream CONSUMES
identity at every step and defines or moves none. No canonical byte,
address spelling, or preimage changes here.
