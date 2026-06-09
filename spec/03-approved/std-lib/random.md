# `cx-stdlib/random` — PRNG + crypto-random

```cx
[module-meta name=random tier=B status=current
  [standard ref='xoshiro256++' title='PRNG']]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/random` sub-package.

---

## §1. Scope

`cx-stdlib/random` provides two distinct randomness facilities:

- **PRNG** — seeded, reproducible pseudo-random for simulation, sampling, shuffling, non-security contexts.
- **Crypto-random** — kernel-backed cryptographic randomness for tokens, keys, UUIDs, salts.

The two are clearly separated in the API surface — PRNG output cannot accidentally be used for crypto.

**Module boundary — generation vs. transform.** `cx-stdlib/random` owns the *generation* of random values — both the PRNG path and the CSPRNG (crypto-random) path. [`cx-stdlib/crypto`](crypto.md) owns keyed/security *transforms* (HMAC, KDF, signatures, AEAD) and draws any nonces, salts, or freshly-generated keys from `[$random:crypto-bytes]`. The bright-line rule: produce random bytes → `random`; transform data under a key → `crypto`.

## §2. Generator state

The module exposes both **explicit-state** and **process-global** generators:

- **Process-global PRNG** — implicit state shared across all callers in the process. Seeded from system entropy at module load; user may re-seed via `[$random:seed]`. **Impure.**
- **Explicit-state generator** — `[$random:from-seed $seed]` returns a `[generator …]` element carrying its own state. **Pure given the generator value.**

Explicit-state generators are the testable / reproducible path; process-global is the convenient default.

## §3. Public function surface

### §3.1. PRNG — process-global (impure)

```
[?def seed         scope=public impure [returns null]            ($s::int) ...]
[?def next-int     scope=public impure [returns int]             () ...]
[?def next-float   scope=public impure [returns float]           () ...]
[?def next-bool    scope=public impure [returns bool]            () ...]
[?def int-range    scope=public impure [returns int]             ($lo::int $hi::int) ...]
[?def float-range  scope=public impure [returns float]           ($lo::float $hi::float) ...]
[?def shuffle      scope=public impure [returns [sequence any]]  ($xs::[sequence any]) ...]
[?def choose       scope=public impure [returns any]             ($xs::[sequence any]) ...]
[?def sample       scope=public impure [returns [sequence any]]  ($xs::[sequence any] $n::int) ...]
```

- `next-int()` — uniform 63-bit non-negative integer.
- `next-float()` — uniform float in `[0.0, 1.0)`.
- `int-range(lo, hi)` — uniform integer in `[lo, hi]` inclusive; rejection sampling, no modulo bias (§4.1).
- `float-range(lo, hi)` — uniform float in `[lo, hi)`.
- `shuffle(xs)` — Fisher-Yates; returns a new sequence.
- `sample(xs, n)` — uniform-without-replacement sample of size `n`.

### §3.2. PRNG — explicit state (pure given generator)

```
[?def from-seed         scope=public pure [returns element] ($s::int) ...]
[?def next-int-with     scope=public pure [returns element] ($gen::element) ...]
[?def next-float-with   scope=public pure [returns element] ($gen::element) ...]
[?def next-bool-with    scope=public pure [returns element] ($gen::element) ...]
[?def int-range-with    scope=public pure [returns element] ($gen::element $lo::int $hi::int) ...]
[?def float-range-with  scope=public pure [returns element] ($gen::element $lo::float $hi::float) ...]
[?def shuffle-with      scope=public pure [returns element] ($gen::element $xs::[sequence any]) ...]
[?def choose-with       scope=public pure [returns element] ($gen::element $xs::[sequence any]) ...]
[?def sample-with       scope=public pure [returns element] ($gen::element $xs::[sequence any] $n::int) ...]
```

These return `[result $value $next-generator]` element pairs — the generator is threaded through calls explicitly.

**Parity invariant.** Every process-global PRNG op in §3.1 has exactly one explicit-state mirror here, named by suffixing `-with` and taking `$gen::element` as the leading parameter. The mirror computes the identical value the process-global form would compute from an equivalent state. This extends to §3.4–§3.6.

```cx
[?let [= $gen0 [$random:from-seed 42]]
      [= $r1   [$random:next-int-with $gen0]]
      [= $r2   [$random:next-int-with $r1/next-generator]]
  [pair $r1/value $r2/value]]
```

Deterministic: same seed → same sequence.

### §3.3. Crypto-random (impure, kernel-backed)

```
[?def crypto-bytes         scope=public impure [returns bytes]  ($n::int) ...]
[?def crypto-int           scope=public impure [returns int]    ($lo::int $hi::int) ...]
[?def crypto-hex           scope=public impure [returns string] ($n::int) ...]
[?def crypto-base64-url    scope=public impure [returns string] ($n::int) ...]
[?def crypto-token-urlsafe scope=public impure [returns string] ($n::int) ...]
```

- `crypto-bytes(n)` — `n` random bytes from the system CSPRNG (`getrandom(2)` Linux, `getentropy(2)` macOS, `BCryptGenRandom` Windows).
- `crypto-int(lo, hi)` — uniform integer in `[lo, hi]` using rejection sampling on `crypto-bytes`.
- `crypto-hex(n)` — `n`-byte random hex string (length `2n` chars, lowercase).
- `crypto-base64-url(n)` — `n`-byte random base64-url-encoded string (no padding).
- `crypto-token-urlsafe(n)` — convenience for session tokens; same as `crypto-base64-url` with default `n=32`.

Crypto-random does not support seeding. Determinism is incompatible with cryptographic security.

### §3.4. Distribution helpers

```
[?def gaussian         scope=public impure [returns float]   ($mean::float $stddev::float) ...]
[?def exponential      scope=public impure [returns float]   ($lambda::float) ...]
[?def poisson          scope=public impure [returns int]     ($lambda::float) ...]
[?def gaussian-with    scope=public pure   [returns element] ($gen::element $mean::float $stddev::float) ...]
[?def exponential-with scope=public pure   [returns element] ($gen::element $lambda::float) ...]
[?def poisson-with     scope=public pure   [returns element] ($gen::element $lambda::float) ...]
```

- `gaussian(mean, stddev)` — polar (Marsaglia) Box-Muller form. `stddev >= 0` required; `stddev == 0` returns `mean` exactly.
- `exponential(lambda)` — inverse-CDF (`-ln(1-u) / lambda`); `lambda > 0` required.
- `poisson(lambda)` — Knuth's multiplication method; `lambda > 0` required.
- Invalid parameters raise `CXER1905 E_RANDOM_DISTRIBUTION_PARAM`.

### §3.5. Weighted sampling

```
[?def choose-weighted      scope=public impure [returns any]            ($xs::[sequence any] $weights::[sequence float]) ...]
[?def sample-weighted      scope=public impure [returns [sequence any]] ($xs::[sequence any] $weights::[sequence float] $n::int) ...]
[?def choose-weighted-with scope=public pure   [returns element]        ($gen::element $xs::[sequence any] $weights::[sequence float]) ...]
[?def sample-weighted-with scope=public pure   [returns element]        ($gen::element $xs::[sequence any] $weights::[sequence float] $n::int) ...]
```

- `choose-weighted(xs, weights)` — one element of `xs` with probability proportional to its weight.
- `sample-weighted(xs, weights, n)` — `n` elements without replacement, proportional to remaining weights.
- `length(weights) != length(xs)` → `CXER1904 E_RANDOM_WEIGHTS_MISMATCH`.
- Negative weight or all-zero weights → `CXER1905 E_RANDOM_DISTRIBUTION_PARAM`. Zero weight is permitted (never selected).
- Empty `xs` → `CXER1902 E_RANDOM_EMPTY_SEQUENCE`; `n` > count of positive-weight elements → `CXER1903 E_RANDOM_SAMPLE_TOO_LARGE`.

### §3.6. Vectorized generation

```
[?def next-floats      scope=public impure [returns [sequence float]] ($n::int) ...]
[?def next-ints        scope=public impure [returns [sequence int]]   ($n::int) ...]
[?def next-floats-with scope=public pure   [returns element]          ($gen::element $n::int) ...]
[?def next-ints-with   scope=public pure   [returns element]          ($gen::element $n::int) ...]
```

- `next-floats(n)` — sequence of `n` uniform floats in `[0.0, 1.0)`.
- `next-ints(n)` — sequence of `n` uniform 63-bit non-negative integers.
- `n >= 0` required; `n == 0` returns the empty sequence; `n < 0` → `CXER1905`.
- `-with` mirrors return `[result $value $next-generator]` with the full `n`-value state advance.

## §4. Algorithm specifics

### §4.1. PRNG algorithm — xoshiro256++ (pinned)

xoshiro256++ (Vigna 2019), 256-bit state, period `2^256 - 1`. **Pinned as part of the v0.8.0 API/format-stability surface.** A given seed produces a byte-for-byte identical sequence:

- Across CX versions for the life of the v0.8 line.
- Across all Tier-1 bindings (V, Python, Go, Rust).

Any future change to the PRNG algorithm, its seed-mixing, or its output transform is a **breaking change** requiring a major version bump.

**Unbiased range reduction.** `int-range(lo, hi)` and its `-with` mirror MUST produce uniform output over `[lo, hi]` with no modulo bias, via rejection sampling (or an equivalent unbiased reduction such as Lemire's multiply-and-reject). `float-range(lo, hi)` scales a uniform `[0.0, 1.0)` draw and introduces no bias beyond IEEE-754 rounding.

### §4.2. Crypto-random source

System CSPRNG. v0.8.0 implementation: Linux `getrandom(2)`; macOS `getentropy(2)`; Windows `BCryptGenRandom`; other Unix `/dev/urandom`. Raises `CXER1900 E_RANDOM_ENTROPY_UNAVAILABLE` if the system source is unavailable.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER1900` | `E_RANDOM_ENTROPY_UNAVAILABLE` | crypto-random call when system source returns error |
| `CXER1901` | `E_RANDOM_RANGE_INVALID` | `int-range(lo, hi)`, `int-range-with(gen, lo, hi)`, `float-range(lo, hi)`, `float-range-with(gen, lo, hi)`, or `crypto-int(lo, hi)` with `lo > hi`, or any other invalid range argument to those builtins |
| `CXER1902` | `E_RANDOM_EMPTY_SEQUENCE` | `choose` / `sample` on empty sequence |
| `CXER1903` | `E_RANDOM_SAMPLE_TOO_LARGE` | `sample` / `sample-weighted` with `n` too large |
| `CXER1904` | `E_RANDOM_WEIGHTS_MISMATCH` | weighted op with `length(weights) != length(xs)` |
| `CXER1905` | `E_RANDOM_DISTRIBUTION_PARAM` | invalid distribution parameter (negative stddev, non-positive lambda, negative weight, all-zero weights, negative `n`), or an invalid byte-count argument to `crypto-bytes` / `crypto-hex` / `crypto-base64-url` / `crypto-token-urlsafe` (e.g. negative `n`) |

## §6. Conformance fixtures

Under `conformance/stdlib/random.cxd`:

- **Seeded reproducibility:** `from-seed(42)` produces an identical sequence of `next-int-with` outputs every time.
- **Process-global re-seedability:** `seed(42)` then 10 `next-int` calls; re-`seed(42)`; sequences identical.
- **Range correctness:** `int-range(1, 6)` returns values only in `{1..6}` (1000 samples).
- **Shuffle preserves elements:** `shuffle([1..10])` is a permutation; sorted result equals input.
- **Empty sequence:** `choose([])` raises `CXER1902`.
- **Invalid range:** `int-range(10, 5)` raises `CXER1901`.
- **Crypto distinctness:** 1000 successive `crypto-bytes(16)` calls produce 1000 distinct values.
- **Crypto-hex format:** `crypto-hex(8)` returns a 16-char lowercase-hex string.
- **Crypto-base64-url:** `crypto-base64-url(32)` returns a URL-safe base64 string with no `=` padding.
- **Unbiased range uniformity:** `int-range(0, 2)` over 60 000 draws — each bucket within chi-square tolerance of uniform.
- **Cross-version golden sequence:** `from-seed(42)` followed by the first 16 `next-int-with` / `next-float-with` outputs matches a committed golden vector; every Tier-1 binding asserts the same vector.
- **Explicit-state parity:** for each process-global op, the `-with` mirror seeded from the same state produces the matching value.
- **Gaussian moments:** `gaussian(0.0, 1.0)` over 100 000 samples — sample mean within tolerance of `0.0`, stddev of `1.0`; `gaussian(m, 0.0)` returns `m`.
- **Distribution params raise:** `gaussian(0.0, -1.0)`, `exponential(0.0)`, `poisson(-2.0)` each raise `CXER1905`.
- **Weighted respects weights:** `choose-weighted(["a","b"], [1.0, 3.0])` selects `"b"` ≈ 3× as often as `"a"`; zero-weight element never selected.
- **Weighted error modes:** `choose-weighted(["a","b"], [1.0])` raises `CXER1904`; all-zero weights raise `CXER1905`; `sample-weighted(["a","b"], [1.0, 0.0], 2)` raises `CXER1903`.
- **Vectorized equals scalar:** `next-floats-with(gen, 5)` produces the same five values (and same next generator) as five threaded `next-float-with` calls.

## §7. Capabilities

Effectful functions in `cx-stdlib/random` run under deny-by-default capabilities ([`spec/core/security.md`](../core/security.md) §2): the effect point checks the active set and raises `cx-err:CXER0271` (E_CAP_DENIED, naming the missing capability and resource) when the grant is absent. Pure functions (in-memory transforms, parsing, formatting) require no capability.

Only the cryptographic generators source OS entropy and therefore require `random`. The seeded PRNG functions are deterministic over in-memory generator state and need no capability.

| Capability | Functions |
|---|---|
| `random` | `crypto-bytes`, `crypto-hex`, `crypto-int`, `crypto-base64-url`, `crypto-token-urlsafe` |
| (none) | `seed`, `next-bool`, `next-float`, `next-floats`, `next-int`, `next-ints`, `int-range`, `float-range`, `choose`, `choose-weighted`, `sample`, `sample-weighted`, `shuffle`, `gaussian`, `exponential`, `poisson` |

## §8. Cross-references

- [`spec/std-lib/uuid.md`](uuid.md) — depends on `[$random:crypto-bytes]` for v4 UUID generation.
- [`spec/std-lib/bytes.md`](bytes.md) — `crypto-base64-url` composes with bytes/base64-url encoding.
- [`spec/std-lib/crypto.md`](crypto.md) — keyed transforms consume `[$random:crypto-bytes]`.
