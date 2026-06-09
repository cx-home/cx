# `cx-stdlib/ft` — fulltext search with structured ranking

```cx
[module-meta name=ft tier=A status=current
  [standard ref='Unicode UAX #29' title='Word segmentation']
  [standard ref='Snowball Porter2' title='Stemming']
  [standard ref='TF-IDF' title='Scoring']
  [standard ref='Okapi BM25' title='Ranking']]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/ft` sub-package.

---

## §1. Scope

`cx-stdlib/ft` provides in-program fulltext search with structured ranking and snippet generation. v0.8.0 ships a **naive in-memory inverted index** built per call from a doc set or [`cx-stdlib/store`](store.md). Tokenization, stopword handling, English stemming, scoring (TF-IDF or BM25), phrase queries via positional postings, and snippet extraction run inside the process — no persistent index, no external engine.

The Index is an **opaque in-memory value rebuilt per program run**; there is no cross-run persistence and no serialization format. Persistence is the job of the future pack backend (§6); the API surface stays the same when persistence lands.

## §2. Conceptual model

An **Index** is an opaque element value built from a sequence of documents. Each document is tokenized into a stream of tokens. The Index records, per token: document IDs, positions (for phrase queries), and term frequencies.

Searches use a query language (keyword conjunctions, phrase queries, boolean operators, field restriction) and are ranked by **TF-IDF** (default) or **BM25** (opt-in).

### §2.1. Tokenization pipeline

```
segment  →  case-fold  →  stopword-removal  →  stem
```

1. **segment** — Unicode word-boundary segmentation (UAX #29 §4.1). Punctuation drops; numbers and identifiers retain.
2. **case-fold** — fold to lowercase (skipped when `case-sensitive=true`).
3. **stopword-removal** — drop stopwords for the configured language (§4.2); disable with `:none`.
4. **stem** — Snowball Porter2 English stemmer (default for `language="en"`); other languages default to no stemming until v0.8.x.

| Language | Stopwords (bundled) | Stemmer (v0.8.0) |
|---|---|---|
| `en` (default) | English standard ~150 words | Snowball Porter2 (default-on) |
| `es`, `fr`, `de`, `pt`, `it`, `ru`, `nl` | bundled standard list | none |
| other tags | none | none |

**CJK / no-whitespace scripts** (Chinese, Japanese, Thai) tokenize poorly under the built-in UAX #29 segmenter — documented limitation. Callers supply a custom `tokenizer` (§3.1, §4.4) plugging in a domain segmenter.

### §2.2. Query grammar

```
Query        ::= Term ((Connective)? Term)*
Term         ::= Keyword | Phrase | FieldRestrict | Group | Negation
Keyword      ::= /[^\s"():!]+/
Phrase       ::= '"' /[^"]*/ '"'
FieldRestrict::= /[a-zA-Z][a-zA-Z0-9_-]*/ ':' Term
Group        ::= '(' Query ')'
Negation     ::= '-' Term | 'NOT' Term
Connective   ::= 'AND' | 'OR'   (default = AND)
```

Examples: `database`; `"customer support"`; `subject:invoice`; `database AND (mysql OR postgres) -mongodb`.

### §2.3. Scoring

| Mode | Algorithm |
|---|---|
| `tf-idf` (default) | Term frequency × inverse doc frequency |
| `bm25` (opt-in) | Okapi BM25; `k1=1.2`, `b=0.75` default |

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
[?def search           scope=public pure [returns [sequence element]] ($idx::element $query::string $limit::int) ...]
[?def search-with-opts scope=public pure [returns [sequence element]] ($idx::element $query::string $opts::map) ...]
```

Each result has shape `[result doc-id="…" score=4.27 matches=3]`. `search-with-opts` accepts `limit` (default 10), `scoring` (`"tf-idf"` / `"bm25"`), `offset` (default 0), `min-score` (default 0.0).

`search-with-opts` also accepts the tokenization keys `language` (default: the Index's build `language`), `case-sensitive` (default: the Index's build `case-sensitive`), and `stemmer` (default: the Index's build `stemmer`). These let the query string be tokenized consistently with the Index. The query is tokenized with the effective `language` / `case-sensitive` / `stemmer` in force for the search; for matches to be meaningful the query pipeline must agree with the pipeline that built the Index.

If the search `language` or `case-sensitive` differs from the values the Index was built with (§3.1), the tokens produced for the query cannot match the Index's tokens, and `search-with-opts` raises `CXER1203 E_FT_INDEX_INCOMPATIBLE` (§7) rather than silently returning wrong results. A `stemmer` mismatch is permitted (stemming only narrows token families) and does not raise. `search` (the three-argument form) never raises `CXER1203`: it always tokenizes the query with the Index's own build options.

### §3.3. Store-integrated search

```
[?def search-store scope=public impure [returns [sequence element]] ($store::element $query::string $limit::int) ...]
```

Build an Index from a Store and search it. Convenience wrapper; equivalent to:

```cx
[?let [= $docs [?for [in $entry [$store:iter-docs $store]] [yield [$entry/doc]]]]
  [$ft:search [$ft:index $docs] $query $limit]]
```

For large stores, build the Index explicitly with `[$ft:index]` and reuse.

### §3.4. Snippets

```
[?def snippet           scope=public pure [returns string] ($doc::any $query::string $context-chars::int) ...]
[?def snippet-with-opts scope=public pure [returns string] ($doc::any $query::string $opts::map) ...]
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
    [doc [title "Database design"] [body "Schemas and indexes for analytics"]]
    [doc [title "Schema migrations"] [body "Database schema evolution"]]]]]
  [$ft:search $idx "title:database" 10]]
```

Returns only the first doc.

### §4.4. Custom tokenizer

`index-with-opts` accepts a `tokenizer` option (a pure function `text → [sequence string]`) replacing the UAX #29 segmentation stage. Supported escape hatch for CJK / no-whitespace scripts, code search (identifier splitting), and domain terms.

```cx
[?let [= $idx [$ft:index-with-opts $docs {
    "tokenizer"      [?fn ($text) [$my-cjk:segment $text]]
    "stopwords"      :none
    "stemmer"        "none"}]]
  ...]
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

## §6. Forward compatibility — pack-backed persistent index

v0.8.x will add a pack-backed persistent inverted index exposed as `[$ft:index-persistent]`. Same `search` query API; only the build call changes:

```cx
[?let [= $idx [$ft:index $docs]]            ; v0.8.0
  [$ft:search $idx "query" 10]]

[?let [= $idx [$ft:index-persistent "pack-ft:///path/to/index" $docs]]   ; v0.8.x
  [$ft:search $idx "query" 10]]             ; same call shape
```

## §7. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER1200` | `E_FT_QUERY_PARSE` | `search` on malformed query string |
| `CXER1201` | `E_FT_UNKNOWN_LANGUAGE` | `tokenize` / `index-with-opts` with unsupported language tag |
| `CXER1202` | `E_FT_FIELD_NOT_INDEXED` | Query `field:term` for a field not in `opts.fields` |
| `CXER1203` | `E_FT_INDEX_INCOMPATIBLE` | `search-with-opts` whose `language` or `case-sensitive` differs from the Index's build options (§3.2) |
| `CXER1204` | `E_FT_TOKENIZER_INVALID` | Custom `tokenizer` raises, returns a non-sequence, or returns non-string elements |

## §8. Conformance fixtures

Under `conformance/stdlib/ft.cxd`:

- **Round-trip:** index 10 docs → search each unique term → that doc returned at rank 1.
- **TF-IDF vs BM25:** both modes return ranked non-empty results (order may differ).
- **Phrase queries:** `"exact phrase"` matches contiguous tokens only.
- **Boolean operators:** `AND` / `OR` / `NOT` per Boolean algebra.
- **Field restriction:** `title:foo` matches only `[title]` children.
- **Snippets:** contain query terms with `<mark>` wrappers; respect `context-chars`.
- **Stopwords:** common stopwords excluded from index; per-language stopwords drop for bundled languages; non-bundled language drops nothing unless overridden.
- **English stemming:** `"running"`, `"runs"`, `"ran"`, `"run"`, `"databases"` / `"database"` collapse to the same stem family; with `stemmer="none"` they stay distinct.
- **Custom tokenizer:** replaces segmentation only; with all downstream stages disabled, indexed tokens equal the function's raw output. Invalid tokenizer raises `CXER1204`.
- **CJK limitation:** documented under-segmentation under the default tokenizer; supplying a custom `tokenizer` produces the expected per-word tokens.
- **Case folding:** `"Database"` / `"database"` / `"DATABASE"` collide on the same indexed tokens.
- **Empty corpus / empty query:** `ft/index []` returns an empty Index; `ft/search $idx "" 10` returns an empty sequence (not an error).
- **search-store integration:** `[$ft:search-store]` matches docs from a populated store.

## §9. Cross-references

- [`spec/std-lib/store.md`](store.md) — Store integration via `[$ft:search-store]`.
- [`spec/std-lib/re.md`](re.md) — regex engine that can plug into custom tokenizers.
- [`spec/std-lib/strings.md`](strings.md) — string operations useful when building a custom tokenizer.
- [`spec/core/abi.md`](../core/abi.md) cap bit 25 — RE2 engine, shared with future `ft` regex-tokenizer customization.
