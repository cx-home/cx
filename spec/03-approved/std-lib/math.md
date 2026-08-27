# `cx-stdlib/math` — numeric utilities

```cx
[module-meta name=math tier=A status=current
  [standard ref='IEEE 754' title='Floating point']]
```

**Status:** Current

Normative reference for the `cx-stdlib/math` sub-package.

---

## §1. Scope

`cx-stdlib/math` covers numeric utilities across CXDM's int / float scalar kinds: basic arithmetic, powers / logs / roots, trigonometry, statistics, bit operations, predicates, number theory, special constants, and explicit modular arithmetic.

Decimal arbitrary-precision support is gated on cap bit 11 ([`spec/core/abi.md`](../core/abi.md)); currently only basic ops are supported on decimals.

## §2. Type model

| CX type | Operations | Notes |
|---|---|---|
| `int` | Signed 64-bit | Overflow raises `CXER3000 E_MATH_OVERFLOW` (checked by default); explicit modular arithmetic via `wrapping-*` (§3.9) |
| `float` | IEEE 754 double | NaN, infinity, denormals representable |
| `decimal` | Arbitrary precision | Cap bit 11; basic ops only |

Mixed int + float arithmetic promotes to float.

### Type-preserving promotion (blanket rule)

- **Closed over ints → return int.** `abs`, `sign`, `min`, `max`, `clamp`, `gcd`, `lcm`, `factorial`, and all bit operations.
- **Inherently real → return float.** `sqrt`, `cbrt`, `exp`, `log` / `log2` / `log10` / `log-base`, `pow`, trig (§3.3), and all statistics.
- **Rounding: float → int.** `floor`, `ceiling`, `round`, `round-half-up`, `round-half-even`, `truncate`. Exception: `round-to(x, places)` returns float.
- **Mixed int + float → float.** Any mix promotes (e.g. `[+ 1 2.5] → 3.5`).

`abs`, `sign`, `min`, `max`, `clamp` carry `[returns any]` in §3 because they preserve the operand kind (int in → int out, float in → float out).

## §3. Public function surface

### §3.1. Basic

```
[?def abs              scope=public pure [returns any]   ($x::any) ...]
[?def sign             scope=public pure [returns int]   ($x::any) ...]
[?def floor            scope=public pure [returns int]   ($x::float) ...]
[?def ceiling          scope=public pure [returns int]   ($x::float) ...]
[?def round            scope=public pure [returns int]   ($x::float) ...]
[?def round-half-up    scope=public pure [returns int]   ($x::float) ...]
[?def round-half-even  scope=public pure [returns int]   ($x::float) ...]
[?def round-to         scope=public pure [returns float] ($x::float $places::int) ...]
[?def truncate         scope=public pure [returns int]   ($x::float) ...]
[?def max              scope=public pure [returns any]   ($xs::[sequence any]) ...]
[?def min              scope=public pure [returns any]   ($xs::[sequence any]) ...]
[?def clamp            scope=public pure [returns any]   ($x::any $lo::any $hi::any) ...]
```

- `round` — banker's rounding (half-to-even per IEEE 754) is the default: `round(0.5)=0`, `round(1.5)=2`, `round(2.5)=2`.
- `round-half-up` — commercial rounding (half-away-from-zero): `round-half-up(0.5)=1`, `round-half-up(-0.5)=-1`.
- `round-half-even` — explicit alias for default `round`.
- `truncate` — toward zero.

### §3.2. Powers, logs, roots

```
[?def pow      scope=public pure [returns float] ($base::float $exp::float) ...]
[?def sqrt     scope=public pure [returns float] ($x::float) ...]
[?def cbrt     scope=public pure [returns float] ($x::float) ...]
[?def exp      scope=public pure [returns float] ($x::float) ...]
[?def log      scope=public pure [returns float] ($x::float) ...]
[?def log2     scope=public pure [returns float] ($x::float) ...]
[?def log10    scope=public pure [returns float] ($x::float) ...]
[?def log-base scope=public pure [returns float] ($x::float $base::float) ...]
```

`log` is natural (base e). Domain errors return NaN per IEEE 754 (never raise).

### §3.3. Trigonometry

```
[?def sin        scope=public pure [returns float] ($x::float) ...]
[?def cos        scope=public pure [returns float] ($x::float) ...]
[?def tan        scope=public pure [returns float] ($x::float) ...]
[?def asin       scope=public pure [returns float] ($x::float) ...]
[?def acos       scope=public pure [returns float] ($x::float) ...]
[?def atan       scope=public pure [returns float] ($x::float) ...]
[?def atan2      scope=public pure [returns float] ($y::float $x::float) ...]
[?def sinh       scope=public pure [returns float] ($x::float) ...]
[?def cosh       scope=public pure [returns float] ($x::float) ...]
[?def tanh       scope=public pure [returns float] ($x::float) ...]
[?def asinh      scope=public pure [returns float] ($x::float) ...]
[?def acosh      scope=public pure [returns float] ($x::float) ...]
[?def atanh      scope=public pure [returns float] ($x::float) ...]
[?def deg-to-rad scope=public pure [returns float] ($deg::float) ...]
[?def rad-to-deg scope=public pure [returns float] ($rad::float) ...]
```

All trig functions take/return radians.

### §3.4. Statistical

```
[?def sum          scope=public pure [returns any]              ($xs::[sequence any]) ...]
[?def product      scope=public pure [returns any]              ($xs::[sequence any]) ...]
[?def mean         scope=public pure [returns float]            ($xs::[sequence any]) ...]
[?def median       scope=public pure [returns float]            ($xs::[sequence any]) ...]
[?def mode         scope=public pure [returns any]              ($xs::[sequence any]) ...]
[?def multimode    scope=public pure [returns [sequence any]]   ($xs::[sequence any]) ...]
[?def stddev       scope=public pure [returns float]            ($xs::[sequence any]) ...]
[?def variance     scope=public pure [returns float]            ($xs::[sequence any]) ...]
[?def stddev-pop   scope=public pure [returns float]            ($xs::[sequence any]) ...]
[?def variance-pop scope=public pure [returns float]            ($xs::[sequence any]) ...]
[?def percentile   scope=public pure [returns float]            ($xs::[sequence any] $p::float) ...]
[?def quantile     scope=public pure [returns float]            ($xs::[sequence any] $q::float) ...]
[?def correlation  scope=public pure [returns float]            ($xs::[sequence float] $ys::[sequence float]) ...]
[?def covariance   scope=public pure [returns float]            ($xs::[sequence float] $ys::[sequence float]) ...]
```

- `stddev` / `variance` — sample (N-1); `stddev-pop` / `variance-pop` — population (N).
- `covariance` — sample (N-1), consistent with `stddev` / `variance`.
- `mode` — most-frequent value; ties resolve to the smallest tied value (deterministic).
- `multimode` — all modes (values tied at max frequency), sequence sorted ascending.
- `percentile(xs, p)` — `p` in `[0, 100]`; `quantile(xs, q)` — `q` in `[0, 1]`.
- `correlation` — Pearson coefficient.

Empty sequences raise `CXER3001 E_MATH_EMPTY_SEQUENCE` for mean/median/mode/etc.

### §3.5. Bit operations

```
[?def bit-and         scope=public pure [returns int] ($a::int $b::int) ...]
[?def bit-or          scope=public pure [returns int] ($a::int $b::int) ...]
[?def bit-xor         scope=public pure [returns int] ($a::int $b::int) ...]
[?def bit-not         scope=public pure [returns int] ($x::int) ...]
[?def bit-shift-left  scope=public pure [returns int] ($x::int $n::int) ...]
[?def bit-shift-right scope=public pure [returns int] ($x::int $n::int) ...]
[?def popcount        scope=public pure [returns int] ($x::int) ...]
[?def leading-zeros   scope=public pure [returns int] ($x::int) ...]
[?def trailing-zeros  scope=public pure [returns int] ($x::int) ...]
```

64-bit integer operations. `bit-shift-right` is arithmetic (sign-extending).

**Shift-count policy.**

- **Count ≥ 64 saturates** — does not wrap modulo 64. `bit-shift-left(x, n≥64) → 0`; logical right shift → `0`; arithmetic `bit-shift-right(x, n≥64)` → `0` (non-negative `x`) or `-1` (negative `x`). Avoids the platform-dependent shift-count wrap hazard.
- **Negative shift count** raises `CXER3003 E_MATH_DOMAIN_ERROR`.

### §3.6. Predicates

```
[?def is-nan      scope=public pure [returns bool] ($x::any) ...]
[?def is-infinite scope=public pure [returns bool] ($x::any) ...]
[?def is-finite   scope=public pure [returns bool] ($x::any) ...]
[?def is-integer  scope=public pure [returns bool] ($x::any) ...]
[?def is-positive scope=public pure [returns bool] ($x::any) ...]
[?def is-negative scope=public pure [returns bool] ($x::any) ...]
[?def is-zero     scope=public pure [returns bool] ($x::any) ...]
```

### §3.7. Number theory

```
[?def gcd       scope=public pure [returns int]  ($a::int $b::int) ...]
[?def lcm       scope=public pure [returns int]  ($a::int $b::int) ...]
[?def is-prime  scope=public pure [returns bool] ($n::int) ...]
[?def factorial scope=public pure [returns int]  ($n::int) ...]
```

`factorial(n)` for `n > 20` raises `CXER3000 E_MATH_OVERFLOW`.

**`is-prime` algorithm.** Trial division for small `n`, then **deterministic Miller-Rabin** with fixed witness set `{2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37}`. This witness set is provably exact for all `n < 3.317 × 10^24`, covering the entire int64 range. Result is exact (no probabilistic false positives) and binding-portable (no randomness).

### §3.8. Constants

```
[?def pi       scope=public pure [returns float] () ...]
[?def e        scope=public pure [returns float] () ...]
[?def tau      scope=public pure [returns float] () ...]
[?def golden   scope=public pure [returns float] () ...]
[?def infinity scope=public pure [returns float] () ...]
[?def nan      scope=public pure [returns float] () ...]
[?def epsilon  scope=public pure [returns float] () ...]
```

`tau = 2π`; `golden = (1 + √5) / 2`; `epsilon` = float64 machine epsilon.

### §3.9. Explicit modular arithmetic

```
[?def wrapping-add scope=public pure [returns int] ($a::int $b::int) ...]
[?def wrapping-sub scope=public pure [returns int] ($a::int $b::int) ...]
[?def wrapping-mul scope=public pure [returns int] ($a::int $b::int) ...]
[?def wrapping-pow scope=public pure [returns int] ($base::int $exp::int) ...]
```

`wrapping-*` performs explicit two's-complement modular arithmetic over int64 (wrap modulo `2^64`) and never raises. The escape hatch from checked-by-default (§4.1) for code that wants wrap-around: hashing, checksums, PRNGs, deliberate modular math. `wrapping-add(i64-max, 1) → i64-min`.

## §4. Edge cases and policy

### §4.1. Overflow behavior

int64 arithmetic is **checked by default**. The operators `+`, `-`, `*`, and `pow` raise `CXER3000 E_MATH_OVERFLOW` when the result does not fit in signed 64-bit — uniformly across all call surfaces. No silent wrap on bare operators.

For deliberate modular arithmetic, use `wrapping-*` (§3.9). Float overflow yields ±infinity (IEEE 754). Decimal overflow raises `CXER3000`.

### §4.2. NaN propagation

Operations with NaN return NaN (IEEE 754). Comparisons with NaN return false. `is-nan` is canonical detection.

### §4.3. Integer / float mixing

Mixed-type ops promote to float. `[+ 1 2.5]` returns `3.5`. Statistical ops return float for int/float input; an exact-family operand refuses per §4.4.

### §4.4. Decimal support

Cap bit 11 gates decimal-typed values. This module is the FLOAT lane: a `$math:` verb whose computation runs in binary float refuses an exact-family (decimal / bigint) operand with `CXER3002 E_MATH_DECIMAL_NOT_SUPPORTED` — including operands reached inside a sequence argument (a statistical verb refuses a decimal item rather than skipping or converting it; RULED: CO-14/CO-18). Two named carve-outs answer exactly instead of refusing (measured at v0.17.0, the discipline shipped since I1 — version-literal-ok):

- `$math:div-decimal`, which exists to take decimals as the explicit precision+mode division context;
- the magnitude/integral verbs that share the core heads' exact implementation — `abs`, `floor`, `ceiling`, `min`, `max` — which answer on the exact lane exactly as their core spellings do (`[$math:abs 2.50]` is `2.50`; a bigint passes through).

Every other verb refuses — including `sign`, `round`, `truncate`, `clamp`, and `gcd`, whose exact-lane delegation is an open design item, not a shipped behavior. Exact arithmetic lives on the core heads (`+ - * / % $div $idiv` and the aggregates) per the exact-family rules; `[cast]` is the only decimal↔float bridge. Decimal overflow raises `CXER3000`.

### §4.5. Bit-shift count out of range

Shift count ≥ 64 saturates per §3.5: `bit-shift-left` and logical right shift → `0`; arithmetic right shift → `0` (non-negative) or `-1` (negative). Negative shift count raises `CXER3003`.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER3000` | `E_MATH_OVERFLOW` | Checked operators `+` / `-` / `*` / `pow` on int64 overflow; `factorial(n > 20)`; decimal overflow |
| `CXER3001` | `E_MATH_EMPTY_SEQUENCE` | Statistical functions on empty input |
| `CXER3002` | `E_MATH_DECIMAL_NOT_SUPPORTED` | A float-lane `$math:` verb given an exact-family (decimal / bigint) operand — the carve-outs (`$math:div-decimal`; the core-head delegates `abs`/`floor`/`ceiling`/`min`/`max`) answer exactly instead (§4.4) |
| `CXER3003` | `E_MATH_DOMAIN_ERROR` | Negative bit-shift count (§3.5 / §4.5) |

## §6. Conformance fixtures

Under `conformance/stdlib/math.cxd`:

- Basic vectors: abs / sign / round / floor / ceiling match expected.
- Round banker's: `round(0.5)=0`, `round(1.5)=2`, `round(2.5)=2`.
- Power vectors: `pow(2, 10)=1024`, `sqrt(2)≈1.41421356`.
- Log vectors: `log(e)≈1`, `log10(100)=2`, `log2(1024)=10`.
- Trig identities: `sin(0)=0`, `cos(0)=1`, `tan(π/4)≈1`, `atan2(1, 1)≈π/4`.
- Statistical: standard values for known sequences.
- Correlation between `[1..10]` and `[2..20]` = 1.0.
- Bit ops: `bit-and(0xFF, 0x0F)=0x0F`; popcount of `0xFF` = 8.
- Bit-shift saturation: `bit-shift-left(x, 64) = 0`; arithmetic right shift of negative `x` by ≥ 64 = `-1`.
- Negative shift count raises `CXER3003`.
- Predicates: nan / infinity / finite / integer detection.
- gcd/lcm: `gcd(12, 18)=6`; `lcm(4, 6)=12`.
- `is-prime` deterministic across bindings on Miller-Rabin witness set.
- Factorial: `factorial(0)=1`, `factorial(20)=2432902008176640000`, `factorial(21)` raises `CXER3000`.
- Checked overflow: `i64-max + 1` raises `CXER3000`; `wrapping-add(i64-max, 1) = i64-min`.
- Empty sequence raises `CXER3001` on mean / median / stddev.
- Constants: `pi≈3.14159265`, `e≈2.71828182`, `tau≈2*pi`, `golden≈1.61803398`.

## §7. Cross-references

- [`spec/core/abi.md`](../core/abi.md) — cap bit 11 (decimal type).
- [`spec/std-lib/random.md`](random.md) — stochastic sampling that feeds statistical functions.
