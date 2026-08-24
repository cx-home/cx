# `cx-stdlib/array` — array operations

```cx
[module-meta name=array tier=A status=current
  [standard ref='XPath 3.1 F&O §17.3' title='Arrays']]
```

**Status:** Current — created under RULED: PYE-1
(`ledger/rulings_2026_08_22_python_eradication.md`, named spec
authorization). G3 owner review rides the bug-campaign close-out package.

Normative reference for the `cx-stdlib/array` sub-package.

---

## §1. Scope

`cx-stdlib/array` covers operations over CXDM Arrays ([`core/cxdm.md`](../core/cxdm.md)
§2.5): read (`size`, `get`, `head`, `tail`), construct (`append`, `put`,
`remove`, `insert-before`, `reverse`, `subarray`, `flatten`, `join`, `sort`),
and traverse (`filter`, `for-each`, `fold-left`, `fold-right`). The seventeen
function names follow XPath 3.1 F&O §17.3, adapted to CXDM value semantics.

Arrays are immutable values: every constructor returns a NEW array. Item
order is identity-bearing (canonical.md §2.1) and every function states its
order rule.

## §2. Index model

Positions are **1-based**, matching the language's readers (`[$nth $a 1]` is
the first item) and XPath. An out-of-range position on `get`, `put`,
`remove`, or `insert-before` REFUSES loudly (`CXER0100
E_ARRAY_INDEX_OUT_OF_RANGE` shape) — never an invented value, never a silent
no-op. `insert-before` admits `size + 1` (append position).

## §3. Public function surface

```
[?def size          scope=public pure [returns int]   ($a::array) …]
[?def get           scope=public pure [returns any]   ($a::array $i::int) …]
[?def append        scope=public pure [returns array] ($a::array $v::any) …]
[?def head          scope=public pure [returns any]   ($a::array) …]
[?def tail          scope=public pure [returns array] ($a::array) …]
[?def reverse       scope=public pure [returns array] ($a::array) …]
[?def subarray      scope=public pure [returns array] ($a::array $start::int $len::int) …]
[?def put           scope=public pure [returns array] ($a::array $i::int $v::any) …]
[?def remove        scope=public pure [returns array] ($a::array $i::int) …]
[?def insert-before scope=public pure [returns array] ($a::array $i::int $v::any) …]
[?def flatten       scope=public pure [returns any]   ($a::any) …]
[?def join          scope=public pure [returns array] ($arrays::any) …]
[?def filter        scope=public pure [returns array] ($a::array $fn::any) …]
[?def for-each      scope=public pure [returns array] ($a::array $fn::any) …]
[?def fold-left     scope=public pure [returns any]   ($a::array $init::any $fn::any) …]
[?def fold-right    scope=public pure [returns any]   ($a::array $init::any $fn::any) …]
[?def sort          scope=public pure [returns array] ($a::array) …]
```

- `size` — item count.
- `get` — the item at 1-based `$i`; out of range refuses (§2).
- `append` — a new array with `$v` as the last item.
- `head` — the first item; the empty array yields the empty sequence
  (absence, #584), matching the language reader `[$head]`.
- `tail` — everything after the first item; the empty array's tail is `[]`.
- `reverse` — items in reverse order.
- `subarray` — `$len` items starting at `$start`. `$start` must address the
  array (1 ≤ start ≤ size + 1) and `$len ≥ 0`; the window is clamped to the
  array's end. `subarray([], 1, 0)` is `[]`.
- `put` — a new array with position `$i` replaced by `$v`.
- `remove` — a new array without position `$i`.
- `insert-before` — a new array with `$v` inserted before position `$i`;
  `$i = size + 1` appends.
- `flatten` — the SEQUENCE of leaf items with every nested array (and boxed
  sequence) expanded, depth-first, per XPath `array:flatten` (whose result
  is a sequence, not an array).
- `join` — a sequence (or array) of arrays concatenated left-to-right into
  one array.
- `filter` — items for which `$fn` (one-parameter) answers `true`, order
  preserved; a non-bool answer refuses.
- `for-each` — a new array of `$fn` applied to each item, order preserved
  (result stays an ARRAY, unlike map:for-each's sequence — XPath draws the
  same distinction).
- `fold-left` — `$fn($fn($init, a1), a2)…`; `fold-right` —
  `$fn(a1, $fn(a2, … $init))`. `$fn` takes (accumulator, item) /
  (item, accumulator) respectively, XPath argument order.
- `sort` — ascending by the language's ONE sort arrangement: the `[$sort]`
  comparator (deterministic kind-class order, then value within a kind),
  boxed back into an array — `array:sort` and `[$sort]` can never disagree.
  cxdm §5.5 defines a TOTAL order only within one numeric/temporal kind;
  the cross-kind arrangement is a deterministic ordering convenience, not a
  §5.5 total-order claim. A key parameter is deliberately NOT taken (a
  future ruling may add one).

## §4. Errors

| Condition | Error |
|---|---|
| Non-array operand | `CXER0290` (typed-parameter refusal) |
| Index out of range (`get`/`put`/`remove`/`insert-before`) | `CXER0100` refusal naming the index and the size |
| Non-function `$fn` | the evaluator's not-callable refusal |
| `filter` predicate answering non-bool | `CXER0290` refusal |

Nothing here takes a capability grant: every function is pure.

## §5. Conformance

`conformance/stdlib/array.cxd` pins the surface: every function's happy row,
the 1-based boundary rows (1, size, size + 1, 0, size + 2), empty-array
rows, `flatten` depth rows, fold order rows (left vs right on a non-
commutative fn), and the sort arrangement row. `[?lib 'cx-stdlib/array']`
MUST resolve the module — the registered-but-sourceless state this spec
closes was #925.
