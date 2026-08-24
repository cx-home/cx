# `cx-stdlib/similar` — graded similarity & approximate matching

```cx
[module-meta name=similar tier=B status=current
  [standard ref='Jaro-Winkler' title='Short-string similarity']
  [standard ref='Levenshtein/Damerau-Levenshtein' title='Edit distance']
  [standard ref='Jaccard / cosine over tokens' title='Token-set similarity']
  [standard ref='Double Metaphone' title='Phonetic keys']
  [standard ref='Kuhn-Munkres (Hungarian)' title='Optimal 1:1 assignment']
  [standard ref='Fellegi-Sunter' title='Probabilistic record linkage']]
```

**Status:** Approved. The six §6 design questions were RULED by the owner 2026-07-13 (record in §6); the implementation (core `~` operator + module + UNIFORM-matrix verb integration) and the §8 conformance suite landed with this graduation. The §3 matrix was rebuilt against the real parser/evaluator per the audit-before-trust rule.

Normative reference for the `cx-stdlib/similar` sub-package.

> **Name.** `similar` (chosen 2026-06-24). Rejected: `sim` (abbreviation), `match` (collides with `[?match]`), `fuzzy` (the operation is *graded sufficiency*, not fuzz), `like` (evokes SQL `LIKE` — boolean wildcard pattern match, not a graded score). Sibling to [`ft`](ft.md): `ft` answers *aboutness* (rank a corpus by relevance to a query); `similar` answers *nearness* (is value A near-enough to value B to be treated as linked). They share the tokenization/stemming pipeline.

---

## §1. Scope

`similar` provides **graded comparison** as a generalization of exact equality. Where `=` returns a boolean, a `similar` comparison returns a **score in [0,1] plus evidence**, and a separately-supplied **decision policy** maps that score to one of three bands — `match` / `review` / `no-match`. The "enough" threshold is **caller- and purpose-supplied and never baked in**: `similar` reports nearness and evidence; it does not assert identity (§2.1).

The module ships:
- a set of **scorers** (string, phonetic, token, numeric, temporal — §4.2);
- **normalizers** — reusing [`ft`](ft.md)'s tokenization/stemming pipeline (segment → case-fold → stopword → stem); `similar` does not reimplement stemming/lemmatization;
- a **similarity-predicate constructor** (a first-class *data* value, §4.1) and the **known-verdicts resolver tier** (§5.4);
- **recursive composition** over CX value kinds (§2.3);
- the backing of the **core `~` operator** and of the graded verb forms (§3, §5) — including the **optimal 1:1 assignment** join selection (Hungarian, §5.1).

Out of scope: persistent inverted indexes (that is `ft`); the agent adjudicator tier (CUT from v1 by ruling Q4 — see §5.3).

## §2. Conceptual model

### §2.1. The graded predicate

Exact equality is the degenerate case: a comparison whose score ∈ {0,1} with threshold "must be 1." A **similarity predicate** is a data value `P` such that comparing `a` and `b` under `P` yields:

```
[similar score=<float 0..1> band=<:match|:review|:no-match> [evidence <detail>]]
```

`evidence` is a **child element** (CXDM attribute values are scalars; evidence is inspectable structure that must render and round-trip). It records the scorer used and — for composite values — per-field contributions and skipped fields, so every decision is auditable. A predicate **never** emits "same"; the `band` is the result of applying a **decision policy** (cuts, e.g. `{match: 0.92, review: 0.80}`) to the score. The **default predicate** (used by bare `[~ a b]`) carries default cuts `{match: 0.95, review: 0.85}`, so a band is always present; a predicate built with no `decide` policy returns `score`+`evidence` only — and is **falsy** in a boolean position. In a boolean position (cxpath filter, `[?match]` `when` arm, `[?if]`) a result reads **truthy iff `band=:match`**.

#### §2.1.1. Resolution — scalar rules

`[~ a b]` resolves to a `[similar …]` element by these rules (evidence elided; scores are the real default-scorer values, pinned by `conformance/stdlib/similar.cxd`):

| Input | Resolves to | Rule |
|---|---|---|
| `[~ "acme" "acme"]` | `[similar score=1.0 band=:match]` | identical → 1.0 |
| `[~ "acme" "acne"]` | `[similar score=0.8666… band=:review]` | graded string scorer (Jaro-Winkler) |
| `[~ "acme" "globex"]` | `[similar score=0.47… band=:no-match]` | unrelated |
| `[~ 100 100]` | `[similar score=1.0 band=:match]` | numbers: exact |
| `[~ 100 105]` | `[similar score=0.0 band=:no-match]` | numbers compare **exactly by default** (no scale) |
| `[~ 100 105 10]` | `[similar score=0.5 band=:no-match]` | graded only with a caller tolerance/scale (0.5 is below the default review cut — supply cuts fit for purpose) |
| `[~ :active :closed]` | `[similar score=0.0 band=:no-match]` | atoms nominal — no graded middle |
| `[~ true false]` | `[similar score=0.0 band=:no-match]` | bools degenerate to `=` |
| `[~ "100" 100]` | `[similar score=0.0 band=:no-match [evidence [kind-mismatch 'string' 'number']]]` | disjoint kinds, no coercion |
| `[~ "acme" null]` | `()` (absence channel) | null is *unknown*, not *different* — flows inertly, not `0` |

Normative rules:

1. **Identical → 1.0.** Score is monotone; `1.0` is reserved for inputs equal under the active normalizers.
2. **string** — graded by the configured scorer (default Jaro-Winkler with the conventional 0.7 boost threshold, prefix ≤ 4, p=0.1).
3. **number / date / time / duration** — **exact (0/1) by default**; graded only when the predicate supplies a tolerance/scale (unbounded numerics have no canonical metric — ruling Q6, §6). Scale conventions: a numeric `tolerance` reads in the comparand's own units for numbers, **days** for date/datetime, **seconds** for durations; a *duration-valued* tolerance grades date/datetime at sub-day precision. Score = `max(0, 1 − |a−b|/tolerance)`.
4. **atom / bool / bytes** — nominal: `{0,1}` only (§3 footnote 1).
5. **disjoint kinds** — `0.0` plus a `[kind-mismatch <kind-a> <kind-b>]` evidence note; **no implicit coercion**. Sequence and array are distinct kinds; int/float are one *number* family; date/datetime share the *temporal* family.
6. **null / absence** — resolves to the **absence channel** (empty, `()`), never `0`, so "unknown" stays distinct from "different" (this is what makes record null-awareness, §2.3, work).
7. **map / element / sequence / array** — recursive per §2.3; `evidence` carries per-field/member contributions; absent fields are skipped, not penalized.

The 3rd operand of `[~ a b X]` accepts a `[similar-predicate …]` element (§4.1), or — shorthand — a bare **number/duration**, read as the default predicate plus that tolerance.

### §2.2. Pipeline

```
normalize  →  reduce-candidates (block / index)  →  score  →  decide
```

`normalize` reuses `ft`'s pipeline (per-field configurable; see §4.3 on the scorer/normalizer coupling). `reduce-candidates` is required for collection-scale operations (§5.2) to avoid all-pairs; it is a no-op for single-pair comparison (v1 computes dense pairwise matrices; blocking/indexing is an internal optimization seam, not surface).

### §2.3. Recursive comparison over value kinds

`similar` is defined **recursively**, bottoming out at scalar scorers. This is the value-kind axis of §3.

| Value kind | Comparison |
|---|---|
| **scalar** | a typed scorer: string → §4.2 string/phonetic/token; number → normalized numeric distance; date/time → temporal distance; bool/atom/bytes → equality |
| **map / row** | null-aware **weighted combine** over named fields; each field carries its own scorer + weight (§4.1 `weights`); score = Σwᵢsᵢ/Σwᵢ over fields present on BOTH sides; one-sided fields are recorded as `[skipped name=…]` evidence, never penalized; when NO field is comparable the result is the absence channel |
| **element** | combine over: the element **name** (exact component), **attributes as named fields** (cognate to children — the attribute-matching axis), child elements **aligned by name** (k-th occurrence to k-th occurrence) and recursed, scalar/text content aligned positionally; count-mismatched names recorded as skipped |
| **sequence / array** | **positional alignment** by default (CX sequences are ordered values): score = Σ pair-scores / **max**(len_a, len_b) — unpaired members count against the score (position is identity here, unlike null-aware fields); `ordered=false` on the predicate switches to **set similarity** (exact-membership Jaccard over deduplicated members) |
| **subtree** | the element case applied recursively to depth |
| **table** | row-wise; feeds the collection operators (§5) |

Comparing a subtree is comparing a row whose fields may themselves be rows.

## §3. Orthogonality — applicability matrix (`UNIFORM` gate)

Per [`spec-authoring-guide.md`](../process/spec-authoring-guide.md) §3, a graded predicate must apply uniformly everywhere exact equality or an equality-like predicate appears. The **cognate-coverage rule** binds: these cells are admitted together, not "join now, the rest later." `—` marks genuinely-meaningless cells; every `❌`/`—` carries a one-line rationale.

### §3.1. Construct surface (where the predicate plugs in)

| Construct | Exact form | Graded form | Output |
|---|---|---|---|
| equality | `[= a b]` | `[~ a b]` / `[~ a b $pred]` | scored pair |
| cxpath predicate | `//vendor[= $_@name "x"]` | `//vendor[~ $_@name "x"]` | nodes filtered by `band=:match` |
| join | `[$join a b {on: "field"}]` | `[$join a b {on: $pred, …}]` | labeled linkage (§5.1) |
| group-by / distinct | `[$distinct xs]` | `[$distinct xs {by: $pred, policy: …}]` / `[$group-by xs {by: $pred, policy: …}]` → **clustering** | representatives / clusters + cohesion (§5.2) |
| membership | `[$contains set x]` | `[$contains set x $pred]` | best-match + score |
| sort / order-by | `[$sort xs]` / `[$sort xs {by: "field"}]` | `[$sort xs {by: [$similar:similarity-to x $pred]}]` | ranking (nearest first) |
| dispatch | `[?match]` `[case v …]` | `[when [~ $x pat] …]` arm (band-gated) | routed value |
| validate | `[$validate v vocab]` | `[$validate v vocab {by: $pred}]` | nearest allowed + score |

> **Naming note.** The membership verb is spelled `contains` — `?` is not a NameChar in a call head (`[$contains? …]` would lex the `?` as the error-catch postfix), the same constraint that renamed `gate-wellformed?` (authz) and `addr->string` (net). `contains` extends the existing string-containment builtin: a sequence first argument selects membership; a third argument selects the graded form. `sort`, `join`, and vocabulary `validate` are **new core collection verbs** introduced by this admission (they had no prior exact form); their exact forms are defined here and behave classically (equality join on a named field; scalar/field ascending sort; membership validation).

**Operator form (single definition).** `~` is a **core prefix operator**, the graded cognate of `[= a b]`: `[~ a b]` uses the default predicate; `[~ a b $pred]` supplies a tuned one (built by `[$similar:predicate …]`, §4.1). It is grammar production [125g] (the one 2-or-3-ary comparison head) and is defined **once**; every other row above is that operator in a position, not a new function. Two consequences:

- **No parallel namespace.** Existing verbs (`join`, `distinct`, `group-by`, `sort`, `contains`, `validate`) go graded by being *handed a `~`-predicate in their options map*, not via `$similar:join` etc. The `similar` module owns only the operator's backing, the `predicate` constructor, scorers, and normalizers — never the verbs.
- **cxpath is the same operator in predicate position, not a second one.** There is no infix `~` anywhere in the language: CXPath predicate bodies are homoiconic CX code (code.md §5.5.2 — the XPath-parity infix sublanguage was retired per [cx-private#110](https://github.com/cx-home/cx-private/issues/110)), so the graded test in a path is the same prefix operator, fused into the predicate brackets: `//vendor[~ $_@name "x"]`. This spec defines `~` exactly once, and the CX-wide doctrine holds: **`~` means "approximately" everywhere** — here it grades value nearness; ft's phrase-slop `~n` (a data format consumed only by `[$ft:parse-query]`, [ft.md](ft.md) §2.2.1) grades positional tolerance. The two never meet in one grammar.

### §3.2. Construct × comparand value-kind

Comparand kinds are CX's canonical value kinds (per [`spec-authoring-guide.md`](../process/spec-authoring-guide.md) §3 worked example): **scalar · map · element (+attrs+children) · sequence · array**. Two derived kinds collapse into these: **subtree** = element compared recursively (the *element* column), **table** = sequence of rows (the *sequence* column over maps) — so neither is a standalone comparand (see note below).

| Construct ↓ / kind → | scalar | map | element | sequence | array |
|---|:---:|:---:|:---:|:---:|:---:|
| `~` equality | ✅¹ | ✅ | ✅² | ✅ | ✅ |
| cxpath predicate | ✅ | ✅ | ✅ | ✅ | ✅ |
| join | ✅ | ✅ | ✅ | ✅ | ✅ |
| group-by / distinct | ✅³ | ✅³ | ✅³ | ✅³ | ✅³ |
| membership (`contains`) | ✅ | ✅ | ✅ | ✅ | ✅ |
| sort / order-by | ✅⁴ | ✅⁴ | ✅⁴ | ✅⁴ | ✅⁴ |
| `[?match]` / case | ✅⁵ | ✅⁵ | ✅⁵ | ✅⁵ | ✅⁵ |
| validate vs vocabulary | ✅ | ✅ | ✅ | ✅ | ✅ |

The grid is intentionally **all-✅**: `~` is *total* over value kinds (§2.3), and every construct is a position that applies `~`, so coverage is inherited rather than re-litigated per cell. The genuine limits are constraints on **form**, captured as footnotes, not gaps in coverage — which is the orthogonal outcome the `UNIFORM` gate targets (asymmetry would be the defect).

**Footnoted limits (each pinned by a negative fixture, §8):**

1. **scalar** — graded for `string` / `number` / `date` / `time` / `duration`. `atom` and `bool` (and `bytes`) **degenerate**: `~` is defined but reduces to `=` (score ∈ {0,1}); nominal symbols and booleans have no "near" notion. Pinned by a negative fixture, not a hole.
2. **element** — children aligned by name and recursed; **attributes are compared as cognate to children** (the attribute-matching axis the authoring-guide worked example flags). Subtrees are this case to depth. The element *name* is an exact component of the combine — differently-named elements never score 1.0.
3. **group-by / distinct** — graded equality is **not transitive**, so these are **clustering**, not grouping, and require a resolution policy (ruling Q1, §6). The policy is a construct argument applied uniformly across kinds — not a per-kind exception.
4. **sort / order-by** — applies only as *order-by nearness to a supplied reference* `[$similar:similarity-to x]`. "Sort by intrinsic mutual similarity" with no reference is **—** (meaningless: similarity is relational; a total order needs a fixed reference — anything else is clustering/embedding, not sort). A bare predicate as `by:` is a `CXER4901` options error.
5. **`[?match]`** — graded semantics apply via **`when` predicate arms** (`[when [~ $x pat] BODY]`), band-gated by the shared truthiness rule. `[case]` value/pattern arms, `$bind` / `_` / type-test arms are **—** (structural; exact semantics preserved — a graded `case` would make binding capture ambiguous).

**`—` (non-comparand):** `table` as a single comparand is **—** across every construct — a table is the *container* join / group-by / sort / distinct range over, never a thing `~` compares; comparing two tables is the *sequence* column applied to rows.

**Audit record (graduation).** This matrix was rebuilt against the real parser and evaluator at implementation time (2026-07-13): every ✅ carries ≥1 conformance fixture and every footnoted limit a negative fixture in `conformance/stdlib/similar.cxd` (§8). One silent-conformance gap was found and fixed during the audit: the standalone match/modify bridge's template predicate filter treated non-atomic predicate bodies as identity pass-through, which would have made `[?modify $doc //x[~ …] …]` select every candidate — such focus paths now route to the full program evaluator.

## §4. Public surface

### §4.1. Predicate constructor

```
[?def predicate scope=public pure [returns element] ($opts::map {})]
```

`[$similar:predicate {…}]` builds the canonical `[similar-predicate …]` element — a pure **data** value (never a closure), so every consumer scores env-free and the predicate serializes/round-trips like any element. Options:

| Key | Value | Meaning |
|---|---|---|
| `score` | atom — one of §4.2 | default scorer (default `:jaro-winkler`) |
| `decide` | `{match: F, review: F}` | decision cuts; **absent → score+evidence only, no band** (review ≤ match; violation `CXER4900`) |
| `normalize` | `{fold-case: B, trim: B, stem: B, stopwords: B}` | fold-case/trim default **true** (string scorers); stem/stopwords default false (token scorers only — §4.3) |
| `weights` | `{field: F}` or `{field: {weight: F, score: atom}}` | per-field weight and/or scorer override for map/element combines |
| `tolerance` | number or duration | numeric/temporal scale (§2.1.1 rule 3); must be > 0 |
| `ordered` | bool | sequence/array mode (§2.3; default true = positional alignment) |
| `resolutions` | sequence of `[resolution verdict=<atom> decided-by=<str> [left V] [right V]]` | the known-verdicts resolver tier (§5.4) |

A malformed option is a `cx-err:CXER4900` **at construction time**, not at first use. The canonical element shape (attrs `score`/`tolerance`/`tolerance-ns`/`ordered`, children `[decide]`/`[normalize]`/`[weights [field …]]`/`[resolutions …]`) is itself accepted anywhere a predicate is — a literal `[similar-predicate …]` element and a constructed one are the same value.

### §4.2. Scorers (pure)

`jaro-winkler`, `levenshtein`, `damerau` (true Damerau-Levenshtein, transposition-aware), `token-set`, `token-sort`, `jaccard`, `cosine`, `metaphone` (Double Metaphone keys: primary=primary → 1.0, alternate hit → 0.8, else 0.0), `numeric`, `temporal`. Each: `(a,b) → float 0..1`, deterministic. Direct access:

```
[?def score scope=public pure [returns float] ($scorer::atom $a::any $b::any)]
```

`[$similar:score :levenshtein "flaw" "lawn"]` → `0.5` — the raw score, no banding. Unknown scorer → `CXER4900`.

### §4.3. Normalizers (delegated to `ft`)

`similar` exposes `ft`'s segmentation/stopword/Porter2 stages as normalizer components. **Coupling (normative):** stemming/stopwords affect only token/term scorers (`token-set`, `token-sort`, `jaccard`, `cosine`) and are inert for character edit-distance and phonetic scorers; a `stem` pairing with a character/phonetic scorer is a `CXER4900` config error, not a silent no-op. `fold-case` and `trim` apply to character scorers.

### §4.4. Ranking key + accessors

```
[?def similarity-to scope=public pure [returns element] ($x::any $pred::any {})]
[?def score-of scope=public pure [returns float] ($r::element)]
[?def band-of  scope=public pure [returns any]   ($r::element)]
```

`similarity-to` builds the `[similarity-to [reference x] [predicate $pred]]` key spec consumed by `[$sort xs {by: …}]` (nearest first — similarity ranking defaults to descending). `score-of`/`band-of` read the report (`band-of` returns the band **atom**, or absence for a band-less report). The cascade of §5.3/§5.4 is predicate configuration (`resolutions` tier ahead of scorers), not a separate surface.

## §5. Decision, routing, and the collection operators

### §5.1. Joins as routing presets over a labeled result

`[$join left right {on: …, …}]` produces a **labeled** result:

```
[join-result type=:T
  [pair score=S band=:B [left ROW] [right ROW]] …
  [left-only ROW] … [right-only ROW] …]
```

The relational join *type* is a **filter over that one labeled result**, not a separate operation:

| `type` | Contents |
|---|---|
| `:inner` (default) | match-band pairs |
| `:left` | match-band pairs ∪ `[left-only]` rows with no match-band pair |
| `:right` | match-band pairs ∪ `[right-only]` |
| `:full` | **all** selected pairs (match **and review** band) ∪ rows in no selected pair |

`on:` is a **field name** (string — classic equality join over that attr/child/key; every equal pair links at score 1.0) or a **similarity predicate** (graded record linkage: whole rows compared per §2.3). Graded joins carry two knobs exact joins lack and MUST make explicit — **cardinality/selection** and **banding** (`decide:` in the join options overrides the predicate's cuts; a cut-less predicate gets the defaults). Pairs below the review cut are never linkable. Selection modes (ruling Q3, 2026-07-13):

| `selection` | Semantics |
|---|---|
| `:greedy-best` (default) | per-left-row best match above the cut, first-come (input order) on ties |
| `:top-k` | up to `k` matches per left row (`k:` option, ≥ 1) |
| `:all-above` | every pair above the cut |
| `:optimal` | globally optimal 1:1 assignment (Hungarian/Kuhn-Munkres) over the above-cut score matrix — total-score-maximizing; ties broken deterministically by input order; unassignable rows stay unmatched |

`:optimal` is in-module: 1:1 record linkage is the load-bearing case and callers must not each reimplement assignment.

### §5.2. group-by / distinct → clustering

Graded equality is **not transitive** (A~B, B~C ⇏ A~C), so it is not an equivalence relation. `distinct`/`group-by` under a predicate therefore become **clustering** and require a resolution policy. **Ruling (Q1, 2026-07-13): the policy is an argument to the OPERATOR, never a predicate field** — the policy governs how a construct aggregates pairwise verdicts, not how near two values are, so one predicate reuses across join (no clustering) and distinct (clustering):

```
[$distinct xs {by: $pred, policy: :complete-linkage}]   → representatives
[$group-by xs {by: $pred, policy: :complete-linkage}]   → ([cluster cohesion=C m…], …)
```

| `policy` | Cluster rule |
|---|---|
| `:transitive-closure` (default) | connected components over match-band pairs — largest clusters |
| `:complete-linkage` | agglomerative: repeatedly merge the two clusters whose *minimum* pairwise score is highest and ≥ the match cut (ties: lowest first-member index) — every member pair of a result cluster is match-band; conservative |
| `:singletons` | no clustering; only exact duplicates collapse |

Every policy is deterministic for a fixed input sequence; the cluster representative is the first member in input order, clusters order by first member, and `cohesion` is the mean pairwise score (1.0 for singletons). `distinct` returns the representatives; `group-by` returns the clusters.

### §5.3. Process routing: match / review / no-match

The three-way band is a **fork in the dataflow**. Because the result is data, routing is partition-then-dispatch over the labeled result (filter `:full` join output by `band`), and the routes separate by **capability**:

- `match` → auto-apply (write capability);
- `no-match` → its own route — often "insert as new" (upsert), not failure;
- `review` → **held**; the operation emits the review set as data, and resolutions re-enter per §5.4.

**Agent adjudicator — CUT from v1 (ruling Q4, 2026-07-13).** The earlier draft sketched a rare Tier-3 agent resolver over the review residue. The model capability it requires does not exist in the runtime, and a spec seam with no live consumer is a partial implementation by definition (process rule). v1 therefore terminates the cascade at the deterministic tiers (known-verdicts → exact → lexical → token/phonetic); the review band always exits as data. The agent tier is a follow-up gated on the model capability landing, tracked in its own issue.

### §5.4. Resume seam

The `review` stream cannot complete synchronously. A run emits `{applied, review-queue, new}` and terminates; resolutions re-enter on a later run **as an input table**, keeping the process pure/replayable. **Ruling (Q2, 2026-07-13): resolutions re-enter as a KNOWN-VERDICTS RESOLVER TIER** — the highest-priority tier of the cascade, carried on the predicate as `resolutions:`. A resolved pair short-circuits **before any scorer runs**: verdict `:match` → score 1.0, `:no-match` → 0.0, `:review` → 0.5 (the conventional indeterminate); the band is the verdict regardless of cuts, and evidence carries `[resolved decided-by=… <verdict>]` provenance. Pair identity is structural equality of the two values, orientation-insensitive. (The rejected alternative — predicate overrides as a side-table — would smear resume logic across every construct instead of one cascade tier.) Determinism: identical input + identical resolutions ⇒ identical end state (pinned by a §8 fixture).

## §6. Design rulings (owner, 2026-07-13 — formerly the open questions)

1. **Cluster-resolution policy** — on the OPERATOR, as a construct argument; never a predicate field. (§5.2)
2. **Resume seam** — resolutions re-enter as the known-verdicts resolver tier, the cascade's highest-priority tier. (§5.4)
3. **Cardinality/global assignment** — optimal 1:1 (Hungarian) is in-module as join `selection: :optimal`; `:greedy-best` is the default. (§5.1)
4. **Agent tier** — CUT from v1 (no model capability in the runtime; a seam with no live consumer is a partial impl). Follow-up issue gated on the capability. (§5.3)
5. **Learnability tiers** — confirmed: Tier-1 = bare `[~ a b]` + the default predicate; predicate construction, cascade, clustering are Tier-3 opt-in. (authoring-guide §4)
6. **Scalar metric defaults** — confirmed exact-by-default for number/date/time; graded ONLY with an explicit caller tolerance/scale (no implicit metric — the thresholds-never-baked-in principle applies to scales too). (§2.1.1 rule 3)

## §7. Errors

Errors are values (never V-errors), in the module's registered
`CXER4900–4901` island (governance §9.6; registered 2026-08-05 — these
two codes shipped inside what was then xap's proposed `4850–4949` band,
regularized when xap.md §8 yielded `4890–4949`):

| Code | Trigger |
|---|---|
| `cx-err:CXER4900` | malformed predicate: unknown scorer, `review > match` cuts, `tolerance ≤ 0` or non-numeric/duration, unknown normalizer key, stem × character/phonetic scorer pairing (§4.3), malformed `weights`/`resolutions`, non-map constructor argument, non-predicate third `~` operand |
| `cx-err:CXER4901` | malformed verb options: `join` missing `on:` / unknown `selection:`/`type:` / `top-k` with `k < 1`; unknown cluster `policy:`; `sort` `by:` that is not a field name, `[similarity-to …]` spec, or function; missing `by:` on a graded verb form |

Wrong `~` operand count is the operator-arity error `cx-err:CXER0100` (code.md §6.5), not a module code.

## §8. Conformance

`conformance/stdlib/similar.cxd` (gate `enforced`) pins:

- the §2.1.1 scalar rule table, per-scorer known pairs for all ten scorers, and the normalizer couplings (incl. the `CXER4900` negatives);
- recursive comparison: scalar / row / subtree / sequence / array, per-field weights and scorer overrides, null-aware skips;
- the §3.2 construct × value-kind matrix — ≥1 positive fixture per ✅ cell, a negative fixture per footnoted limit;
- join: inner/left/right/full as filters over one labeled result; all four selection modes (incl. the greedy-trap case `:optimal` wins);
- clustering: the three policies (incl. an intransitive chain where closure and complete-linkage differ), determinism, cohesion;
- routing: a fixed input partitions deterministically into match/review/no-match; the resolutions tier short-circuits with provenance; re-run determinism;
- decision policy: identical pair, two cut policies → different bands (purpose-relativity);
- truthiness: band-gating in `[?if]` / `when` arms / cxpath filters; band-less reports falsy.

## §9. Cross-references

- [`ft.md`](ft.md) — shared tokenization/stemming; corpus-relevance sibling.
- [`strings.md`](strings.md), [`re.md`](re.md) — string/regex primitives for normalizers.
- [`validate.md`](validate.md) — schema validation (the vocabulary `validate` verb here is the graded lookup cognate).
- [`spec-authoring-guide.md`](../process/spec-authoring-guide.md) §3 (orthogonality / `UNIFORM`), §4 (learnability tiers).
- [`code.md`](../core/code.md) §6.5 (the reserved operator set — `~` arity row), [`grammar.ebnf`](../formal/grammar.ebnf) [125g]/[159b].
