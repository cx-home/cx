# I5 stream 5 — computation identity + deterministic result cache: implementation ledger

**Status:** OPEN (started 2026-08-11; order-of-march item 5, stream #677
per the stream-1 exit handoff).
Branch `impl/I5-stream5-computation` off `design/651-516-partition`
(cut at 9ac7d605 — the stream-1 exit-merge).
Governing spec: `computation_identity.md` — letters **L102–L108 inside the
S2 batch RULED (a) 2026-08-05 (letters 93–121)**; RULED-token anchor =
the S2 exit row in `partition_campaign_PLAN.md` (decision log 2026-08-05,
"WAVE S2 EXITED — letters 93–121 ruled (a)"), stream-5 fragment: "map-shaped
`[computation]` record, plain Tier-1 id, DUAL fn addresses …
`pure ⇒ deterministic` ruled as a new theorem — `[par]` reassembles source
order ALWAYS ([ordered] tombstoned), locale audit mandated … pure-only
VISIBLE cache (alias namespace, no new API, no [?memo]); tapes = inputs
not axes; addresses defined from I1 onward".
Issues: #677 (stream); #713 rides in part — items 1+2 CLOSED at the W8
boundary (CXER0274 fail-closed unknown grants; L114 `cap=resource`
spelling), items 3 (allow_all normalization, L104) + 5 (C4
caps-as-CX-value, L104) LAND HERE, item 4 (authority-store durability)
→ #678 (cross-pinned, not duplicated).

**Epoch posture:** I1 IS CLOSED; this stream is POST-EPOCH **and purely
additive by ruling** — L108: computation addresses are DEFINED from I1
onward; this stream adds no hash-affecting change to any existing
artifact (a new composition over shipped identities). Every pre-I1
computation address is undefined, not migrated; no re-bless is needed by
construction. The one engine-behavior cutover (W2's `[par]` source-order)
moves NO identity: unordered output was normatively unspecified, so no
program (and no address) can legitimately depend on it — the ruling
names the cutover free.

## Standing constraints

- Spec-first; NO spec edits without a recorded ruling (RULED: tokens on
  spec+impl commits; fragments must grep in `partition_*.md`). The §10
  spec-edit map of `computation_identity.md` IS ruled — each executed
  edit cites its letter.
- Every wave ends green on the full gate — launched UNPIPED, full log,
  `GATE-RC=$?` propagated, verdict read FROM the log.
- Fixtures ride WITH their machinery wave, never after; fixture-first
  for every defect-shaped change.
- Cutover-first, no dual-accept; never true a spec to a shortfall.
- Fable 5 only; push per landing; exit-merge IS an exit step.
- Triage gate flakes by standalone re-runs BEFORE suspecting the stream
  diff (#778 fabric liveness, #779 rotation-vs-fold are the known
  load-sensitive lanes).
- G3 graduation of `computation_identity.md` (and any new approved-tree
  file "beside code-identity.md") is OWNER-GATED — item-6 handoff
  packet, never attempted here. The working spec stays in `02-working/`
  this stream; normative cross-edits into approved specs execute per
  the ruled §10 map.

## Pre-open recon verdicts (2026-08-11, probed live this session)

1. **The `computation-id` name collision is REAL and correctly scoped —
   no rename needed.** `[$cx:computation-id]` EXISTS (stdlib_cx.v:59)
   but it is the F1′/A2 **Tier-2 fn-identity claim** — one `[?def]`
   source (string or def), returns the distinct claim token
   `computes-as:<algo>:<hex>` via `cx_code_tier2_hash`
   (code_identity.v:46); dispatch-only, never an address (A1). It is
   exactly the **fn-slot ingredient** of the L102 record (`fn.code`),
   not the record identity. The L102 computation-id = **plain Tier-1 of
   the `[computation]` record value** — no `computation:` prefix, no new
   registry row (the E1/L81 precedent) — so the existing builtin stands
   untouched and no second "computation-id" surface is introduced.
   Probed live: `[$cx:computation-id '[?def …]']` → `computes-as:…`
   (string-source idiom per corpus cx-108).
2. **L105 violation pinned live:** `[?for … [par]]` without `[ordered]`
   returns COMPLETION order — five consecutive runs of an 8-item
   comprehension gave five distinct orders (probe transcript this
   session). Implementation: par_eval.v:231-232 documents
   completion-order-when-unordered; :290-297 is the explicit unordered
   branch (ordered=true already reassembles by index — the source-order
   plumbing EXISTS; the cutover deletes the unordered branch, it builds
   nothing). Spec: code.md §7.1 grammar row `([ordered])?`, §7.2
   "`[ordered]` — preserves source order … MUST be paired with `[par]`",
   §7.3 parallel evaluation. diagram.v:720 renders `:par :ordered`
   distinctly (annotation surface joins the cutover).
3. **Locale audit substrate: clean by construction where probed, audit
   still owed.** `upper`/`lower` run through the in-repo
   `rune_to_upper`/`rune_to_lower` tables (stdlib_strings.v:310/:326),
   never host locale — but L105 mandates the audit over the WHOLE §6.5.x
   pure list with a fixture per audited builtin; the sweep and its
   table land in W2.
4. **Env quadrant: EMPTY, as §1.4 finds.** No `cx:version` under any
   name (dispatch list read); runtime version exists only as the build
   define (`-d cx_version=0.15.0`, derived from repo-root VERSION). The
   two closed tables the builtin-set id hashes EXIST: code.md §4.1
   directive-registry table + §6.5.x built-in purity classification;
   purity_checker.v:167 `builtin_purity_table()` is the runtime mirror
   (drift-gate precedents: directive-docs-check, stdlib-catalog-gate).
   Schema-dialect surface to verify at W4 entry.
5. **Caps state (L104/#713):** items 1+2 LANDED (unknown grant name →
   E_CAP_UNKNOWN/CXER0274 fail-closed, stdlib_caps.v:84-94; `cap=resource`
   is THE scope spelling with the retired `cap:` form refused,
   :148-180). Items 3+5 OPEN and land here: `allow_all` is still a
   distinct bool state with distinct behavior (:37, :106, :128-141 —
   the private-range bypass class) rather than NORMALIZING to
   explicit-full + a private-range-policy field; C4 caps-as-CX-value
   (security.md C4 "ruled yes", ~line 114) has zero implementation.
6. **Cache substrate exists; no new API is honest:** store aliases are
   a shipped funnel (stdlib_store.v alias_set/alias-delete funnels,
   alias_order, per-name streams) = the `computation/<addr>` alias
   namespace lands on shipped machinery; store dedup + immutable-ETag
   caching are the storage half (§1.6). Purity classification is
   checker-available (purity_checker.v) for the pure-only fail-loud
   refusal.
7. **EV prerequisites (L105 inheritance) are PINNED, not open:**
   EV-LET-SEQ (let* sequential), EV-CLOSURE-CAP (snapshot),
   EV-PULL (per-combinator pull counts), EV-BUDGET (≥1,000,000 floor)
   all carry pinned resolutions in clean_room_implementability.md
   (§ rows 96–101). They are named per-wave check items, not stream
   blockers.
8. **The M5 worked example is now constructible:** the headline pricing
   expression's `*`-head became hashable at I1 row 8 (operator heads,
   `operator_heads.cxd` v2.0), and `[?meta]` non-participation landed
   with #708 item 1 (idh-032) — the §0 negatives list is implementable
   as written, post-I1.

## Open decisions (to be ruled AT the owning wave's entry, standing acceptance)

- **D1 (W5 entry) — the record constructor surface.** The spec names
  the record, the id, and the impure-fn refusal, but not the
  construction surface's spelling. Constraints discovered in recon: the
  env and caps components are ambient (entry set; runtime version), so
  the constructor is env-aware even though the resulting record is a
  plain value; L103 rules `cx:version` pure (a constant of the
  evaluation), suggesting the same posture for the whole env read.
  Rule the spelling with the code in view; the refusal codes ride the
  same ruling.
- **D2 (W4 entry) — the builtin-set-id document's home.** A canonical
  CX value listing the two closed spec tables, host-independent, with a
  drift gate binding it to code.md §4.1/§6.5.x. Candidate homes:
  conformance data vs stdlib data vs generated-at-build. The drift-gate
  precedents (directive-docs-check pattern) inform the pick.

## Wave plan (dependency order; each = one landing + gate)

| Wave | Work | Done-when |
|---|---|---|
| **W1 — open** | Branch + this ledger authored; recon verdicts probed live and booked; #713 pinning recorded | Ledger committed + pushed; no code movement |
| **W2 — L105 `pure ⇒ deterministic`** | `[par]` reassembles source order ALWAYS (par_eval.v unordered branch deleted; `[ordered]` becomes a documented no-op — tombstoned, never removed from the grammar); code.md §6.5.1 gains the theorem, §7.2/§7.3 cut over (spec-edit map rows); locale audit over the §6.5.x pure list w/ fixture per audited builtin + the audit table booked here; map-traversal pre-registration stated; float-sum source-order discriminator pairs | Five-run determinism probe green as a fixture; `[ordered]` fixture asserts no-op; audit table complete; full gate GATE-RC=0 |
| **W3 — L104 the caps value (C4)** | Caps-as-CX-value canonical form (grants map over the closed nine-name list, scopes canonicalized, ENTRY set the basis); `allow_all` NORMALIZES to explicit-full + private-range-policy field (#713 item 3); the C4 introspection surface lands (#713 item 5); security.md §2/C4 edits per the map | allow_all ≡ explicit-full canonicalization pair green; caps-value fixtures green; #713 items 3+5 evidence complete; gate GATE-RC=0 |
| **W4 — L103 the environment** | `cx:version` pure builtin (modules/cx.md row + stdlib_cx.v); builtin-set id = Tier-1 hash of the canonical two-tables CX value + drift gate (D2 ruled at entry); schema-dialect surface verified/exposed; env-record fixtures | cx:version fixture green; builtin-set-id drift gate green and wired into the full gate; gate GATE-RC=0 |
| **W5 — L102 + L106 record + cache** | The `[computation]` record constructor (D1 ruled at entry): map-shaped, dual fn addresses, fail-loud on impure fn / unforced Iterator inputs; computation-id = plain Tier-1; the cache = alias in `computation/<addr>` (no new store API, no `[?memo]`); never-cached list enforced; table inputs via canonical text (D22/L86); M5 end-to-end fixture (same⇒same, reformat⇒hit, patch-bump⇒miss, meta⇒hit) | M5 fixture green; §9 record-canonicalization pairs green; impure + unforced-iterator negatives green; gate GATE-RC=0 |
| **W6 — L107/L108 closure + corpus** | Tapes-as-inputs stated normatively (debug.md §6a cross-ref); store.md namespace note; post-I1 address-epoch statement; remaining §9 corpus families (tape-composed identity; any family not ridden by W2–W5) | G18 strict clean; every §9 family present or booked to its owning wave; gate GATE-RC=0 |
| **W7 — exit** | Full gate GATE-RC=0; exit-merge to design/651-516-partition (the merge IS an exit step); #677 closed with evidence; #713 items 3+5 evidence commented (issue stays open for item 4 → #678); handoff → #678 | Gate log + merge pushed; issue state updated |

Wave order rationale: the theorem (W2) is what makes every cached result
sound — it precedes anything that stores one; caps (W3) and env (W4) are
the two record components with no implementation, both pure prerequisites
of the constructor (W5); the cache rides W5 with the record since a
constructor with no consumer is a seam (no-live-consumer rule); W6 is
prose + corpus closure over the shipped machinery.

## Ledger entries

### Entry 1 — W1: stream open (2026-08-11)

Branch cut at 9ac7d605; ledger authored; recon verdicts 1–8 above all
probed live this session (par completion-order transcript, computation-id
claim probe, dispatch-list read, caps line-anchors, alias funnel read,
EV pin rows). #713 items 3+5 confirmed unlanded (probe of
stdlib_caps.v allow_all paths); items 1+2 confirmed landed (CXER0274
message text + `cap=resource` parse). No code movement this wave.

### Entry 2 — W2: L105 `pure ⇒ deterministic` (2026-08-11)

**Fixture-first transcript:** five new/flipped conformance cases authored
RED before any engine movement (s5_w2_lane_fixtures_pre2.log: map-003 got
completion order `(1, 9, 16, 4)`; map-030 an 8-permutation; for-031
`false`; for-032 the wrong float `0.7000007629394531`) → all green
post-cutover (s5_w2_lane_fixtures_post.log LANE-RC=0).

**Engine cutover (source order ALWAYS, RULED: L105):**
- `par_map` / `par_for_run` / `par_map_streamed` lose the `ordered`
  parameter; reassembly by input index is unconditional. The streamed
  variant emits the CONTIGUOUS COMPLETED PREFIX incrementally (buffer by
  index + frontier pointer) — streaming cadence survives, reordering
  never; error propagation unified to earliest-index-wins on every path
  (matches sequential first-failure).
- `[ordered]` = tombstoned no-op: still parsed where legal (paired with
  `[par]`); `[ordered]`-without-`[par]` stays CXER0100 (grammar closure;
  program-map-004 / program-reduce-003 unchanged); `for_has_ordered_clause`
  deleted; refusal messages updated to the clause spelling.
- Live probes post-build: top-level streamed `[?for … [par]]` and
  `[?map … [par]]` under 8-way work-skew — three runs each, byte-stable
  source order (previously five runs = five orders).

**Spec edits (all rows from the ruled §10 map or its direct ripples):**
code.md §6.5.1 — the theorem authored normatively (run-invariance +
host-independence; the old "not asserted here" disclaimer now points at
it) with the three closures ([par] source order, locale rule,
map-traversal pre-registration) and the EV-* prerequisite inheritance;
§7.2 `[ordered]` bullet + §7.3 output-order paragraph + the purity-
license note ("safe to reorder" narrowed: execution interleaves, output
never); §8.10.5 clause bullet + output-order table; grammar.ebnf [127m]
note; §10.1.2 visualization sentence (diagram draws source as written).
Ripple sweep: playground examples 49/50/51 re-authored + regenerated
(182/182 green), fixture-runner D11 comment, async umbrella
`test_for_par_unordered_multiset` → `test_for_par_source_order_always`
(exact-order assert). `[?test-concurrent]` / scheduler completion-order
surfaces are OUT of scope (impure concurrency scaffolds, not `[par]`).

**Locale audit (the L105 mandate, swept over the §6.5.x pure list):**

| Pure builtin(s) | Verdict | Evidence |
|---|---|---|
| `upper` / `lower` | CLEAN — V rune-table Unicode SIMPLE (1:1) default mapping; no libc locale anywhere (`grep setlocale/LC_` = zero hits outside the explicit i18n module) | fixtures program-builtin-case-locale-audit-001/002/003 (é/Greek map; ß NOT expanded at this tier; Turkish-trap `i`→`I`, `I`→`i` pinned) |
| — divergence facet | bare builtins = simple mapping; `strings:upper` = FULL mapping (ß→SS, strings-003). Both deterministic + host-independent; unifying them is a semantics change needing its own ruling — booked, not taken | probe transcript + strings-003 |
| `contains` / `starts-with` / `ends-with` | immune — byte equality | code reading |
| `substring` / `string-length` | immune — codepoint counting | probe: length('héllo') = 5 |
| `normalize-space` | immune — fixed XML whitespace class | code reading |
| `concat` / `text` / node accessors | immune — concatenation/projection | probe |
| numeric family (`sum`/`max`/`min`/`avg`/`abs`/`floor`/`ceiling`/`round`/`mod`/`div`/`idiv`) | immune — arithmetic + the canonical serializer (fixed `.` decimal, no locale grouping) | canonical-form corpus |
| sequence / higher-order / generator families | immune — structural | code reading |
| `cast` | immune — fixed-format strconv | code reading |
| CXPath / EBV / identity hash | immune — canonical bytes | identity corpus |

**Booked residual (named, no change):** `[?reduce … [par]]` chunk-fold
is deterministic per (n, width) on a host; the RESULT is host-independent
iff `:using` honors the §8.10.6 associative contract it already declares.
A non-associative closure under the default width (= f(ncpu)) is a
contract violation, not host variance of a conforming program. If the
owner ever wants stronger-than-contract determinism there, it is a
one-line width-derivation change — flagged for the item-6 packet, not
taken here.

Lanes green standalone: code_eval_fixtures (post log above), async_conc
umbrella (s5_w2_lane_async2.log LANE-RC=0 on the rebuilt binary — first
run red ONLY because the spawned CLI was stale, not a regression). Full
gate GATE-RC=0 (s5_w2_gate.log; fabric+http FAILs = usecache C-compile
artifacts, green on classified #572 retries). Landed 9bff3ad0.

### Entry 3 — W3: L104 the caps value (2026-08-11)

**Ruling taken at entry (standing acceptance, long-term-best verified) —
R1 (the C4 surface spelling): a zero-arg bare-name IMPURE builtin
`[$caps]`.** Verified against the bar: (i) a new stdlib module for one
function would need a new std-lib spec file — NOT in the ruled §10
spec-edit map (security.md §2/C4 + code.md ARE); (ii) purity: `[$caps]`
MUST be impure — a pure body reading the grant set would break the
§6.5.1 cap-set-invariance the W2 theorem rests on (booked as normative
rationale in both specs); (iii) capability-free by the §3 narrow-only
invariant (observation of own authority can never exceed it) — a new
row (f) in the CLOSED impure-without-capability exception table, both
spec-side and in effect_alignment.v (the drift-gated single source).
The ACTIVE set is what `[$caps]` shows (C4's own sentence); the ENTRY
set as the record's hash basis is W5's consumer and lands there with
its capture mechanism (no-seam rule).

**Fixture-first transcript:** program-caps-001 (full-grant C4 value) +
program-caps-002 (narrowing visible, policy field never on a narrowed
set) authored RED (s5_w3_lane_fixtures_pre.log: both shape-mismatch) →
green post-impl (s5_w3_lane_fixtures_post.log LANE-RC=0). Five new V
tests in stdlib_caps_test.v (normalization equality, full/empty/scoped/
narrowed C4 renders) — green (s5_w3_lane_caps.log).

**#713 item 3 (allow_all normalization):** the `allow_all` bool state is
GONE — `caps_set_all()` now installs the explicit nine-grant set + the
new `private_range_allowed` policy field (the ONE behavior the opt-out
adds: the §4.5 private-range-deny bypass). `cap_allowed` loses its
short-circuit; `cap_allow_all()` → `cap_private_range_allowed()` (the
net SSRF check reads the policy field — semantics byte-identical);
narrowing clears the policy field (an interior set never bypasses the
deny set — same behavior as before, now stated).

**#713 item 5 (C4 value):** `caps_to_cx_value()` — canonical map,
key-sorted at construction: granted-unscoped → `true`; scoped → sorted
canonicalized scope seq (hosts lower-cased, path roots trailing-slash
normalized, deduped); ungranted → ABSENT; `private-range-allowed: true`
only when set (so opt-out vs explicit-full are two canonical values
differing in exactly the behavior that differs). Wired as
`invoke_builtin('caps')`; classified impure (purity_checker table);
exception row (f) (effect_alignment.v — the alignment gate is the drift
canary).

**Spec edits (ruled map):** security.md §2/C4 rewritten as the
implemented normative form (spelling + canonical form + normalization +
entry-vs-active note); code.md §6.5.x impure table gains the
evaluation-environment-introspection row; §6.5.1 exception table gains
row (f).

Lanes green standalone: stdlib_caps_test, eval_semantics_umbrella (=
the check-effect-alignment lane), code_eval_fixtures. Full gate
GATE-RC=0 (s5_w3_gate.log; the two known usecache artifacts green on
classified #572 retries). Landed accb9797.

### Entry 4 — W4: L103 the environment (2026-08-11)

**Ruling taken at entry (standing acceptance, long-term-best verified) —
R2 (env constructibility, discharges D2): THREE zero-arg PURE cx-module
builtins — `cx:version` + `cx:builtins` + `cx:env`.** Verified against
the bar: L103 adds `cx:version` explicitly and states its PURPOSE
("so records are constructible in-language") — version alone cannot
construct the env record; `cx:builtins` exposes the two-tables value so
ANY party re-derives the builtin-set id in-language via
`[$cx:hash [$cx:builtins]]` (M5's "the requester re-hashes to verify" —
an unexposed basis would make the id an unauditable oracle, violating
the C4 dogfood posture); `cx:env` is the composed record itself (one
canonical construction, no per-user reassembly drift). All three are
constants of the runtime build (pure; host-dependence would be the L7a
bug). D2 resolved AGAINST a data-file home: the value constructs from
the in-code mirrors the drift gates already bind — `cx.directive_names`
(gate-3-bound to grammar [127e] + code.md §4.1) and
`builtin_purity_table()` (the effect-alignment drift canary) — no new
file, no fs dependency (embed-profile safe). INTERPRETATION BOOKED: the
hashed purity table is the §6.5.x classification's transitive closure
(bare names + module primitives) — a new builtin of any tier IS a new
builtin set, which is exactly what the id must detect; the additivity
contract covers evolution. No `[?lib]` forwarder defs — matches the
computation-id/type-binding precedent (always-available fallback only).

**Landed:** `cx_mod_version/env/builtins` (stdlib_cx.v; the version
mirror = `$d('cx_version', '0.0.0-dev')`, same define cmd/main.v +
cabi.v read — one source, three readers); `cx.schema_dialect_version`
pub const (data_bin_schema_driven.v) — the S020 check and the env
record now read the SAME const (derive-don't-multiply; S020 message
derives too). Env record `{builtins:, runtime:, schema-dialect:}`,
keys pre-sorted; builtins id derives through the SAME acquisition path
as `cx:hash` (re-hash-to-verify holds by construction).

**Fixture-first transcript:** cx-117 (version shape), cx-118 (env
canonical value: runtime==version, builtins is a plain Tier-1 address,
schema-dialect==the S020 semver), cx-119 (rehash-verifies) authored RED
(s5_w4_lane_fixtures_pre.log: three mismatches) → green post-impl
(s5_w4_lane_fixtures_post.log LANE-RC=0). V lane stdlib_cx_env_test.v:
id call-stability (no map-order leakage — every key list sorted at
construction), V-side rehash-verify, the '0.0.0-dev' test-build
default, dialect single-source, caps-in-basis (the W3 amendment rides
in the hashed table). s5_w4_lane_env.log LANE-RC=0.

**Spec edits (ruled map row: modules/cx.md):** §2.1 gains the three
rows + the environment-quadrant section (full-semver rationale,
two-tables basis, re-hash-to-verify, additivity contract, the honest
residue note). Full gate: s5_w4_gate.log.
