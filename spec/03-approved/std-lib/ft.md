# `cx-stdlib/ft` — fulltext search with structured ranking

```cx
[module-meta name=ft tier=A status=current
  [standard ref='Unicode UAX #29' title='Word segmentation']
  [standard ref='Snowball Porter2' title='Stemming']
  [standard ref='TF-IDF' title='Scoring']
  [standard ref='Okapi BM25' title='Ranking']]
```

**Status:** Current

Normative reference for the `cx-stdlib/ft` sub-package.

---

## §1. Scope

`cx-stdlib/ft` provides in-program fulltext search with structured ranking and snippet generation. The module ships a **naive in-memory inverted index** built per call from a doc set or [`cx-stdlib/store`](store.md). Tokenization, stopword handling, English stemming, scoring (TF-IDF or BM25), phrase queries via positional postings, and snippet extraction run inside the process — no persistent index, no external engine.

The Index is an **opaque in-memory value rebuilt per program run**; there is no cross-run persistence and no serialization format. Persistence is the job of the future pack backend (§6); the API surface stays the same when persistence lands.

## §2. Conceptual model

An **Index** is an opaque element value built from a sequence of documents. Each document is tokenized into a stream of tokens. The Index records, per token: document IDs, positions (for phrase, slop, and proximity queries), and term frequencies.

**Positions are assigned at segmentation, before stopword removal** — a removed stopword still consumes its position. Phrase-slop and proximity distances therefore count elided stopwords: in `"state of the art"`, `state` and `art` are 3 positions apart regardless of the stopword configuration, so distance semantics are stable under stopword-list changes.

Searches take a **canonical structured query** — a CX element (§2.2) — and are ranked by **TF-IDF** (default) or **BM25** (opt-in), with a positional **proximity boost** (§5.3). End-user query strings (search boxes) are converted to the canonical form by the explicit parser `[$ft:parse-query]` (§2.2.1); the string format is a **data format**, not language surface, and search functions do not accept it directly. Programmatic query construction builds the canonical element — never string concatenation, which is the query-injection pattern the split exists to prevent.

### §2.1. Tokenization pipeline

```
segment  →  case-fold  →  stopword-removal  →  stem
```

1. **segment** — Unicode word-boundary segmentation (UAX #29 §4.1). Punctuation drops; numbers and identifiers retain.
2. **case-fold** — fold to lowercase (skipped when `case-sensitive=true`).
3. **stopword-removal** — drop stopwords for the configured language (§4.2); disable with `:none`.
4. **stem** — Snowball Porter2 English stemmer (default for `language="en"`); other languages default to no stemming until a future revision.

| Language | Stopwords (bundled) | Stemmer |
|---|---|---|
| `en` (default) | English standard ~150 words | Snowball Porter2 (default-on) |
| `es`, `fr`, `de`, `pt`, `it`, `ru`, `nl` | bundled standard list | none |
| other tags | none | none |

**CJK / no-whitespace scripts** (Chinese, Japanese, Thai) tokenize poorly under the built-in UAX #29 segmenter — documented limitation. Callers supply a custom `tokenizer` (§3.1, §4.4) plugging in a domain segmenter.

### §2.2. Canonical query form (normative)

The query type is a CX element with root `[query …]` holding exactly one node:

```
QueryDoc ::= [query Node]
Node     ::= [term "keyword"]                       ; single keyword, run through the search pipeline
           | [phrase "…"]                           ; positional phrase, exact adjacency
           | [phrase slop=N "…"]                    ; phrase with slop — terms up to N positional moves apart; slop=0 ≡ exact
           | [near n=N Node+]                       ; unordered proximity — operands within N tokens (§2.2.2)
           | [near n=N ordered=true Node+]          ; ordered proximity — operands in query order within N tokens
           | [field name="f" Node]                  ; restrict Node to tokens inside child elements named f
           | [all Node+]                            ; conjunction (every child matches)
           | [any Node+]                            ; disjunction (at least one child matches)
           | [none Node+]                           ; negation (no child matches; filters a candidate set, never generates one)
```

The connectives are deliberately named `all` / `any` / `none` — **not** `and` / `or` / `not` — because a query is constructed in CX code as a data element, and `and`/`or`/`not` are reserved operator heads (code.md §6.5) that would parse as boolean forms in expression position, not as element construction.

```cx
[?let [= $q [query [all [term "database"]
                        [any [term "mysql"] [term "postgres"]]
                        [none [term "mongodb"]]]]]
  [$ft:search $idx $q 10]]
```

A malformed query element passed to a search function (unknown node name, `[query]` without exactly one child, `[near]` over non-positional operands, negative `slop`/`n`) raises `CXER1205 E_FT_QUERY_SHAPE` (§7).

#### §2.2.1. Query-string format (input to `[$ft:parse-query]` only)

The familiar search-box string is a **data format** consumed by the explicit parser `[$ft:parse-query]` (§3.2a), which returns a canonical `[query …]` element. It is documented sugar over nothing — it is *input parsing*, in the same category as JSON: search functions never accept it directly, and the grammar below binds only `parse-query`.

```
Query        ::= Term ((Connective)? Term)*
Term         ::= Keyword | Phrase | FieldRestrict | Group | Negation | Proximity
Keyword      ::= /[^\s"():!]+/
Phrase       ::= '"' /[^"]*/ '"' ('~' INT)?
Proximity    ::= Term ('NEAR/' INT | 'ONEAR/' INT) Term
FieldRestrict::= /[a-zA-Z][a-zA-Z0-9_-]*/ ':' Term
Group        ::= '(' Query ')'
Negation     ::= '-' Term | 'NOT' Term
Connective   ::= 'AND' | 'OR'   (default = AND)
```

Mapping to canonical form:

| String form | Canonical node |
|---|---|
| `database` | `[term "database"]` |
| `"customer support"` | `[phrase "customer support"]` |
| `"customer support"~2` | `[phrase slop=2 "customer support"]` |
| `acme NEAR/5 plumbing` | `[near n=5 [term "acme"] [term "plumbing"]]` |
| `acme ONEAR/5 plumbing` | `[near n=5 ordered=true [term "acme"] [term "plumbing"]]` |
| `subject:invoice` | `[field name="subject" [term "invoice"]]` |
| `a AND b` / `a b` | `[all …]` |
| `a OR b` | `[any …]` |
| `-a` / `NOT a` | `[none …]` (combined with siblings under the enclosing connective) |

The phrase-slop `~` follows the CX-wide doctrine that **`~` means "approximately"** (cx-private#108/#110/#111): here it grades *positional* tolerance (aboutness), whereas the core `[~ a b]` operator grades *value* nearness — the two never meet in one grammar because this format exists only inside `parse-query`'s input string.

#### §2.2.2. Proximity semantics

`[near n=N …]` matches a document iff it contains an occurrence of every operand such that the token-position span covering one occurrence of each is ≤ `N` positions wide (positions per §2 — stopwords consume positions). With `ordered=true` the occurrences must additionally appear in operand order. Operands MUST be positional nodes (`[term]` / `[phrase]`); a connective or `[field]` operand is `CXER1205`. `[phrase slop=N "…"]` is the phrase-local analogue: the phrase's tokens may sit up to `N` positional moves from their exact-adjacency slots; `slop=0` (or no `slop` attr) is today's exact phrase.

### §2.3. Scoring

| Mode | Algorithm |
|---|---|
| `tf-idf` (default) | Term frequency × inverse doc frequency |
| `bm25` (opt-in) | Okapi BM25; `k1=1.2`, `b=0.75` default |

Both modes apply a positional **proximity boost** on multi-term queries (§5.3). ft scores are **unbounded relevance ranks** — comparable within one Index, never calibrated to [0,1] and never mapped to `match`/`review`/`no-match` bands; whole-value nearness with banded decisions is `cx-stdlib/similar` (cx-private#108), a different module answering a different question (*aboutness* here, *nearness* there).

## §3. Public function surface

### §3.1. Building an Index

```
[?def index           scope=public pure [returns element] ($docs::[sequence any]) ...]
[?def index-with-opts scope=public pure [returns element] ($docs::[sequence any] $opts::map) ...]
```

`index` uses the default pipeline. `index-with-opts` accepts:

| Key | Default | Semantics |
|---|---|---|
| `language` | `"en"` | Tokenizer + stopword + stemmer language tag |
| `stopwords` | `:default` | `:none` to disable, `:default` for language standard, or a sequence of strings |
| `stemmer` | `:default` | `"en"` for Snowball Porter2, `"none"` to disable. `:default` resolves to `"en"` when `language="en"`, otherwise `"none"` |
| `tokenizer` | `:default` | Pure function `text → [sequence string]` replacing the built-in segmentation stage |
| `case-sensitive` | `false` | If true, no case folding |
| `min-token-length` | `2` | Minimum token length to index |
| `fields` | `:auto` | Element-name fields to index separately |

A custom `tokenizer` replaces only the segmentation stage — case-fold, stopword-removal, and stemming still run on its output unless separately disabled (`case-sensitive=true`, `stopwords=:none`, `stemmer="none"`).

### §3.2. Searching

```
[?def search           scope=public pure [returns [sequence element]] ($idx::element $query::element $limit::int) ...]
[?def search-with-opts scope=public pure [returns [sequence element]] ($idx::element $query::element $opts::map) ...]
```

`$query` is the canonical `[query …]` element (§2.2) — search functions do not accept query strings; an end-user string goes through `[$ft:parse-query]` first (§3.2a):

```cx
[$ft:search $idx [$ft:parse-query "database AND (mysql OR postgres)"] 10]
```

Each result has shape `[result doc-id="…" score=4.27 matches=3]`. `search-with-opts` accepts `limit` (default 10), `scoring` (`"tf-idf"` / `"bm25"`), `offset` (default 0), `min-score` (default 0.0), `proximity-boost` (float ≥ 0, default `0.25`; `0.0` disables — §5.3).

### §3.2a. Parsing end-user query strings

```
[?def parse-query scope=public pure [returns element] ($query::string) ...]
```

Parses the query-string data format (§2.2.1) and returns a canonical `[query …]` element; malformed input raises `CXER1200 E_FT_QUERY_PARSE`. This is the **only** place the string format exists. The boundary is deliberate: user-typed text enters exactly here, so a term containing `AND`, quotes, or `-` can never rewrite a programmatically built query.

`search-with-opts` also accepts the tokenization keys `language` (default: the Index's build `language`), `case-sensitive` (default: the Index's build `case-sensitive`), and `stemmer` (default: the Index's build `stemmer`). These let the query's terms be tokenized consistently with the Index. Query terms are tokenized with the effective `language` / `case-sensitive` / `stemmer` in force for the search; for matches to be meaningful the query pipeline must agree with the pipeline that built the Index.

If the search `language` or `case-sensitive` differs from the values the Index was built with (§3.1), the tokens produced for the query cannot match the Index's tokens, and `search-with-opts` raises `CXER1203 E_FT_INDEX_INCOMPATIBLE` (§7) rather than silently returning wrong results. A `stemmer` mismatch is permitted (stemming only narrows token families) and does not raise. `search` (the three-argument form) never raises `CXER1203`: it always tokenizes the query with the Index's own build options.

### §3.3. Store-integrated search

```
[?def search-store scope=public impure [returns [sequence element]] ($store::element $query::element $limit::int) ...]
```

Build an Index from a Store and search it. Convenience wrapper; equivalent to:

```cx
[?let [= $docs [?for [in $entry [$store:iter-docs $store]] [yield $entry/doc]]]
  [$ft:search [$ft:index $docs] $query $limit]]   # $query is a [query …] element
```

For large stores, build the Index explicitly with `[$ft:index]` and reuse.

### §3.4. Snippets

```
[?def snippet           scope=public pure [returns string] ($doc::any $query::element $context-chars::int) ...]
[?def snippet-with-opts scope=public pure [returns string] ($doc::any $query::element $opts::map) ...]
```

Wraps query-term matches in `<mark>...</mark>` HTML by default. `snippet-with-opts` keys: `context-chars` (default 80), `max-snippets` (default 3), `ellipsis` (default `"…"`), `mark-prefix` / `mark-suffix`.

### §3.5. Tokenizer access

```
[?def tokenize scope=public pure [returns [sequence string]] ($text::string $language::string) ...]
```

Run the default pipeline (segment → case-fold → stopwords → stem) and return the token sequence. Useful for debugging query/tokenizer alignment.

### §3.6. Result helpers

```
[?def doc-ids   scope=public pure [returns [sequence string]] ($results::[sequence element]) ...]
[?def score-of  scope=public pure [returns float]             ($result::element) ...]
```

### §3.7. Index introspection

```
[?def index-stats scope=public pure [returns map] ($idx::element) ...]
```

Returns a map `{doc-count: $n, term-count: $n, size-bytes: $n, languages: (...)}`
(per `[returns map]` above; `languages` is a sequence of language codes).

## §4. Tokenization details

### §4.1. UAX #29 default tokenizer

Splits at whitespace, punctuation, and script boundaries. Keeps contractions (`don't`), numbers with separators (`1,234.56`), and email/URL-like strings.

### §4.2. Stopwords

Bundled lists for `en`, `es`, `fr`, `de`, `pt`, `it`, `ru`, `nl`. Other languages default to no stopword removal unless `opts.stopwords` is supplied. English list:

```
a an and are as at be by for from has have he in is it its of on or
that the to was were will with you your this these those they them
their there here when where why how what which who whom whose
```

### §4.3. Field restriction

Indexed docs that are CX elements with children expose each child-element name as a **field**. Query `field-name:term` matches only tokens within elements named `field-name`:

```cx
[?let [= $idx [$ft:index [
    [doc [title "Database design"] [body "Schemas and indexes for analytics"]],
    [doc [title "Schema migrations"] [body "Database schema evolution"]]]]]
  [$ft:search $idx [query [field name="title" [term "database"]]] 10]]
```

Returns only the first doc.

### §4.4. Custom tokenizer

`index-with-opts` accepts a `tokenizer` option (a pure function `text → [sequence string]`) replacing the UAX #29 segmentation stage. Supported escape hatch for CJK / no-whitespace scripts, code search (identifier splitting), and domain terms.

```cx
[?let [= $idx [$ft:index-with-opts $docs {
    "tokenizer":     [?fn ($text) [$my-cjk:segment $text]]
    "stopwords":     :none
    "stemmer":       "none"}]]
  [$ft:query $idx "分散 検索"]]
```

The function MUST be pure (same text → same tokens). A tokenizer that raises, returns a non-sequence, or returns non-string elements yields `CXER1204 E_FT_TOKENIZER_INVALID`.

## §5. Scoring details

### §5.1. TF-IDF

```
score(query, doc) = Σ_term  tf(term, doc) × idf(term)
tf(term, doc)     = (count of term in doc) / (total tokens in doc)
idf(term)         = log(N / df(term))
```

### §5.2. BM25

```
score(query, doc) = Σ_term  idf(term) × (tf × (k1 + 1)) / (tf + k1 × (1 - b + b × dl/avg_dl))
  k1 = 1.2  (configurable via opts.bm25-k1)
  b  = 0.75 (configurable via opts.bm25-b)
```

Both produce non-negative scores. Higher = better. Comparable within an Index, not across Indexes.

### §5.3. Proximity boost

For a query whose match in a document involves ≥ 2 distinct positional atoms (terms; each phrase counts as one atom at its start position), the base score is scaled by co-occurrence closeness:

```
score'(q, d)   = score(q, d) × (1 + β × proximity(q, d))
proximity(q,d) = 1 / minspan(q, d)      when d contains ALL distinct matched atoms
               = 0                       otherwise
minspan(q, d)  = width in token positions of the smallest window in d
                 containing ≥ 1 occurrence of every distinct matched atom
```

`β` is the `proximity-boost` opt (§3.2; float ≥ 0, default `0.25`; `0.0` disables). Positions per §2 — stopwords consume positions. Properties (each pinned by a fixture, §8): the boost is **monotone** (smaller `minspan` → strictly higher `score'`, all else equal); it is a **ranking perturbation only** — it never creates a match (`proximity = 0` docs keep their base score, and a doc matching under `[near]`/slop constraints is matched by those constraints, not by the boost); single-atom queries are unaffected. The boost applies under both scoring modes.

## §6. Forward compatibility — pack-backed persistent index

A future revision will add a pack-backed persistent inverted index exposed as `[$ft:index-persistent]`. Same `search` query API; only the build call changes:

```cx
[?let [= $idx [$ft:index $docs]]            
  [$ft:search $idx [query [term "database"]] 10]]

[?let [= $idx [$ft:index-persistent "pack-ft:///path/to/index" $docs]]   # future revision
  [$ft:search $idx [query [term "database"]] 10]]   # same call shape
```

## §7. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER1200` | `E_FT_QUERY_PARSE` | `parse-query` on a malformed query string (§2.2.1 grammar violation) |
| `CXER1201` | `E_FT_UNKNOWN_LANGUAGE` | `tokenize` / `index-with-opts` with unsupported language tag |
| `CXER1202` | `E_FT_FIELD_NOT_INDEXED` | `[field name="f" …]` for a field not in `opts.fields` |
| `CXER1203` | `E_FT_INDEX_INCOMPATIBLE` | `search-with-opts` whose `language` or `case-sensitive` differs from the Index's build options (§3.2) |
| `CXER1204` | `E_FT_TOKENIZER_INVALID` | Custom `tokenizer` raises, returns a non-sequence, or returns non-string elements |
| `CXER1205` | `E_FT_QUERY_SHAPE` | `search` / `search-with-opts` / `search-store` / `snippet` on a malformed `[query …]` element — unknown node name, root without exactly one child, `[near]` over non-positional operands, negative `slop`/`n` (§2.2) |

## §8. Conformance fixtures

Under `conformance/stdlib/ft.cxd`:

- **Round-trip:** index 10 docs → search each unique term → that doc returned at rank 1.
- **TF-IDF vs BM25:** both modes return ranked non-empty results (order may differ).
- **Phrase queries:** `[phrase "exact phrase"]` matches contiguous tokens only.
- **Phrase slop:** `[phrase slop=N "…"]` matches terms up to N positional moves apart, misses at N+1; `slop=0` ≡ no `slop` attr ≡ exact phrase.
- **Proximity:** `[near n=N t1 t2]` hits within the N-token window, misses outside it; `ordered=true` rejects the reversed-order occurrence the unordered form accepts; `[near]` over a connective operand raises `CXER1205`.
- **Stopword positions:** with default stopwords, doc `"state of the art"` — `[phrase slop=2 "state art"]` matches (elided stopwords consume positions 2–3), `[phrase "state art"]` does not; distances unchanged under `stopwords=:none`.
- **Connectives:** `[all]` / `[any]` / `[none]` per Boolean algebra.
- **Field restriction:** `[field name="title" [term "foo"]]` matches only `[title]` children.
- **parse-query:** each §2.2.1 string form maps to its canonical node per the mapping table; `"a b"~2` → `[phrase slop=2 …]`; `NEAR/5` / `ONEAR/5` → `[near]` variants; malformed string raises `CXER1200`.
- **Injection boundary:** a user-supplied term containing `AND`, quotes, or a leading `-`, inserted programmatically as `[term $user-input]`, stays a single term — it can never rewrite the query; the same text through `parse-query` is parsed as operators (documenting the boundary).
- **Proximity boost:** two docs matching the same two-term query, identical term frequencies, different co-occurrence spans → the closer-span doc ranks strictly higher under both scoring modes; `proximity-boost=0.0` restores base-score order; single-term queries are unaffected; a doc missing one term keeps its base score (boost never creates a match).
- **Snippets:** contain query terms with `<mark>` wrappers; respect `context-chars`.
- **Stopwords:** common stopwords excluded from index; per-language stopwords drop for bundled languages; non-bundled language drops nothing unless overridden.
- **English stemming:** `"running"`, `"runs"`, `"ran"`, `"run"`, `"databases"` / `"database"` collapse to the same stem family; with `stemmer="none"` they stay distinct.
- **Custom tokenizer:** replaces segmentation only; with all downstream stages disabled, indexed tokens equal the function's raw output. Invalid tokenizer raises `CXER1204`.
- **CJK limitation:** documented under-segmentation under the default tokenizer; supplying a custom `tokenizer` produces the expected per-word tokens.
- **Case folding:** `"Database"` / `"database"` / `"DATABASE"` collide on the same indexed tokens.
- **Empty corpus / empty query:** `[$ft:index []]` returns an empty Index; `[$ft:parse-query ""]` returns an empty-match query, and searching with it returns an empty sequence (not an error).
- **search-store integration:** `[$ft:search-store]` matches docs from a populated store.

## §9. Cross-references

- [`spec/std-lib/store.md`](store.md) — Store integration via `[$ft:search-store]`.
- [`spec/03-approved/std-lib/similar.md`](similar.md) — whole-value *nearness* sibling (`~` operator, banded decisions); ft owns intra-document positional proximity (`[near]`), similar owns value similarity — the shared-word boundary is normative in both (cx-private#108/#111).
- [`spec/std-lib/re.md`](re.md) — regex engine that can plug into custom tokenizers.
- [`spec/std-lib/strings.md`](strings.md) — string operations useful when building a custom tokenizer.
- [`spec/core/abi.md`](../core/abi.md) cap bit 25 — RE2 engine, shared with future `ft` regex-tokenizer customization.
