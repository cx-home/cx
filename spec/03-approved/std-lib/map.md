# `cx-stdlib/map` — map operations

```cx
[module-meta name=map tier=A status=current
  [standard ref='XPath 3.1 F&O §17.1' title='Maps']]
```

**Status:** Current — created under RULED: PYE-1
(`ledger/rulings_2026_08_22_python_eradication.md`, named spec
authorization). G3 owner review rides the bug-campaign close-out package.

Normative reference for the `cx-stdlib/map` sub-package.

---

## §1. Scope

`cx-stdlib/map` covers operations over CXDM Maps ([`core/cxdm.md`](../core/cxdm.md)
§2.6): read (`get`, `keys`, `size`, `contains`), construct (`put`, `entry`,
`merge`, `remove`), and traverse (`for-each`). The nine function names follow
XPath 3.1 F&O §17.1, adapted to CXDM value semantics.

Maps are immutable values: every constructor returns a NEW map; no function
mutates its operand. Runtime entry order is insertion order (§2.6);
constructors state their order rule explicitly below.

## §2. Key model

Key identity is the CXDM rule — the pair **(kind, image)**, type-strict, no
numeric widening (§2.6/§5.1; RULED: 777-1a, MSS-3 item 5): an `int` key `1`
and a `string` key `'1'` are two keys. `get`, `contains`, `remove`, and `put`
all compare keys under that one rule. The admissible key kinds are cxdm
§2.6's (never `atom`, never `null`).

Computed member access `$m.$k` (grammar [135a] computed steps, RULED:
PYE-1a/PYE-1b) is the language-level read this module's `get` mirrors; the
two MUST agree on every (map, key) pair.

## §3. Public function surface

```
[?def get       scope=public pure [returns any]  ($m::map $k::any) …]
[?def put       scope=public pure [returns map]  ($m::map $k::any $v::any) …]
[?def keys      scope=public pure [returns any]  ($m::map) …]
[?def size      scope=public pure [returns int]  ($m::map) …]
[?def contains  scope=public pure [returns bool] ($m::map $k::any) …]
[?def entry     scope=public pure [returns map]  ($k::any $v::any) …]
[?def merge     scope=public pure [returns map]  ($maps::any) …]
[?def remove    scope=public pure [returns map]  ($m::map $k::any) …]
[?def for-each  scope=public pure [returns any]  ($m::map $fn::any) …]
```

- `get` — the value bound to `$k`, or the **empty sequence** when the key is
  absent (#584 presence semantics: absence, never an invented `null`). A
  declaration-only entry (`{k: ::T}`, MSS-4) has an ABSENT value: `get`
  returns the empty sequence for it while `contains` answers `true`.
- `put` — a new map: `$m` with `$k` bound to `$v` (replacing an existing
  binding of the same (kind, image) key in place — entry order preserved —
  or appended as the LAST entry when new).
- `keys` — the sequence of keys in runtime (insertion) order, each carrying
  its own kind.
- `size` — the entry count, declarations included (matching `count`).
- `contains` — whether `$k` (under key identity) is bound, declarations
  included.
- `entry` — the single-entry map `{$k: $v}`; refuses invalid key kinds
  exactly as the literal reader does (CXERMAP-BADKEY).
- `merge` — a sequence (or array) of maps folded left-to-right into one map:
  **later bindings win** on key collision (the `put` rule applied per entry;
  first occurrence fixes an entry's position). An empty operand yields `{}`.
- `remove` — a new map without `$k`; a miss is the identity (no error), per
  XPath `map:remove`.
- `for-each` — applies `$fn` (a two-parameter function value) to each
  (key, value) pair in runtime order and returns the SEQUENCE of results
  (flattened per cxdm §1.2, as `[?for]/[yield]` flattens).

## §4. Errors

| Condition | Error |
|---|---|
| Non-map first operand (`get`/`put`/…) | `CXER0290` (typed-parameter refusal, the [?def] ascription) |
| Invalid key kind on `put`/`entry` | `CXERMAP-DUPKEY` family / `CXERMAP-BADKEY`, matching the literal reader |
| Non-function `$fn` to `for-each` | the evaluator's not-callable refusal |

Nothing here takes a capability grant: every function is pure.

## §5. Conformance

`conformance/stdlib/map.cxd` pins the surface: read/construct rows, the
key-kind identity rows (`{1: x}` vs `{'1': x}` through `get`/`contains`/
`remove`), declaration-entry rows, `merge` collision order, and `for-each`
result shape. `[?lib 'cx-stdlib/map']` MUST resolve the module — the
registered-but-sourceless state this spec closes was #925.
