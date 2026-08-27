# CX

https://cxhome.org — CX is a homoiconic data+code language: one bracket surface carries data documents, conformance fixtures, schemas, and programs.

Language file extensions: `.cx`, `.cxd` (fixture documents), `.cxs` (schemas)

<details>
<summary>Representative code sample</summary>

```
[; CX — one homoiconic surface for data and code ]
[article id=a-17 published=2026-08-27
  [title CX in fifty lines]
  [tags (:data, :code, :one-surface)]]

[?def total scope=public ($items)
  [$sum [?for [in $it $items] [yield $it/@price]]]]

[?let [= $cart [cart
                 [item sku="tea" price=4.50]
                 [item sku="mug" price=12.00]]]
  [?if [> [$total $cart/item] 10.00]
    [then [receipt total=[$total $cart/item] shipping=:free]]
    [else [receipt total=[$total $cart/item]]]]]
```
</details>

## Parser repo

https://github.com/cx-home/cx (monorepo; grammar at `tooling/tree-sitter-cx`, committed `src/parser.c` kept current by the repo's own release gate)

<details>
<summary>Parsed tree for code sample</summary>

```
(document [0, 0] - [14, 0]
  (comment_element [0, 0] - [0, 52]
    (comment_raw [0, 2] - [0, 51]))
  (element [1, 0] - [3, 38]
    name: (tag_name [1, 1] - [1, 8])
    (text [1, 8] - [1, 9])
    (attribute [1, 9] - [1, 16]
      name: (attr_name [1, 9] - [1, 11])
      value: (attr_value [1, 12] - [1, 16]
        (unquoted_value [1, 12] - [1, 16])))
    (text [1, 16] - [1, 17])
    (attribute [1, 17] - [1, 37]
      name: (attr_name [1, 17] - [1, 26])
      value: (attr_value [1, 27] - [1, 37]
        (unquoted_value [1, 27] - [1, 37])))
    (element [2, 0] - [2, 27]
      name: (tag_name [2, 3] - [2, 8])
      (text [2, 8] - [2, 9])
      (word [2, 9] - [2, 11])
      (text [2, 11] - [2, 12])
      (word [2, 12] - [2, 14])
      (text [2, 14] - [2, 15])
      (word [2, 15] - [2, 20])
      (text [2, 20] - [2, 21])
      (word [2, 21] - [2, 26]))
    (element [3, 0] - [3, 37]
      name: (tag_name [3, 3] - [3, 7])
      (text [3, 7] - [3, 9])
      (atom_literal [3, 9] - [3, 14])
      (text [3, 14] - [3, 16])
      (atom_literal [3, 16] - [3, 21])
      (text [3, 21] - [3, 23])
      (atom_literal [3, 23] - [3, 35])
      (text [3, 35] - [3, 36])))
  (def_directive [5, 0] - [6, 51]
    name: (directive_name [5, 6] - [5, 11])
    (def_modifier [5, 12] - [5, 24]
      (scope_attr [5, 12] - [5, 24]
        (attr_name [5, 12] - [5, 17])
        value: (attr_value [5, 18] - [5, 24])))
    body: (directive_body [5, 25] - [6, 50]
      (predicate_expr [6, 2] - [6, 50]
        (predicate_chunk [6, 3] - [6, 7])
        (predicate_expr [6, 7] - [6, 49]
          (predicate_chunk [6, 9] - [6, 14])
          (predicate_expr [6, 14] - [6, 29]
            (predicate_chunk [6, 15] - [6, 18])
            (predicate_chunk [6, 18] - [6, 21])
            (predicate_chunk [6, 21] - [6, 28]))
          (predicate_expr [6, 29] - [6, 48]
            (predicate_chunk [6, 31] - [6, 37])
            (predicate_chunk [6, 37] - [6, 40])
            (predicate_chunk [6, 40] - [6, 47]))))))
  (unknown_directive [8, 0] - [13, 48]
    (directive_head [8, 0] - [8, 5])
    (directive_body [8, 6] - [13, 47]
      (predicate_expr [8, 6] - [10, 47]
        (predicate_chunk [8, 7] - [8, 9])
        (predicate_chunk [8, 9] - [8, 14])
        (predicate_expr [8, 14] - [10, 46]
          (predicate_chunk [8, 16] - [9, 17])
          (predicate_expr [9, 17] - [9, 44]
            (predicate_chunk [9, 18] - [9, 43]))
          (predicate_expr [9, 44] - [10, 45]
            (predicate_chunk [10, 18] - [10, 44]))))
      (if_directive [11, 2] - [13, 47]
        cond: (directive_body [11, 7] - [11, 36]
          (predicate_expr [11, 7] - [11, 36]
            (predicate_chunk [11, 8] - [11, 10])
            (predicate_expr [11, 10] - [11, 29]
              (predicate_chunk [11, 11] - [11, 17])
              (predicate_chunk [11, 17] - [11, 23])
              (predicate_chunk [11, 23] - [11, 28]))
            (predicate_chunk [11, 29] - [11, 35])))
        (then_clause [12, 4] - [12, 61]
          (clause_head [12, 4] - [12, 10])
          (directive_body [12, 10] - [12, 60]
            (predicate_expr [12, 10] - [12, 60]
              (predicate_chunk [12, 11] - [12, 25])
              (predicate_expr [12, 25] - [12, 44]
                (predicate_chunk [12, 26] - [12, 32])
                (predicate_chunk [12, 32] - [12, 38])
                (predicate_chunk [12, 38] - [12, 43]))
              (predicate_chunk [12, 44] - [12, 59]))))
        (else_arm [13, 4] - [13, 46]
          (clause_head [13, 4] - [13, 10])
          body: (directive_body [13, 10] - [13, 45]
            (predicate_expr [13, 10] - [13, 45]
              (predicate_chunk [13, 11] - [13, 25])
              (predicate_expr [13, 25] - [13, 44]
                (predicate_chunk [13, 26] - [13, 32])
                (predicate_chunk [13, 32] - [13, 38])
                (predicate_chunk [13, 38] - [13, 43])))))))))
```
</details>

## Queries

Source of queries: https://github.com/cx-home/cx/tree/main/tooling/tree-sitter-cx/queries/cx (maintained alongside the grammar; copied here per the vendoring convention)

## Checks run locally

- `scripts/check-parsers.lua cx` — Check successful (1311 states, ABI 14; compiled from the pinned revision)
- `scripts/check-queries.lua cx` — Check successful
- `ts_query_ls lint runtime/queries/cx` + `format --check` — clean
- `make docs` — SUPPORTED_LANGUAGES.md regenerated (included)

(`make query` over the whole tree fails locally on an unrelated pre-existing `sql` language-object lookup in this environment; the cx-scoped lint/format/check above are clean.)
