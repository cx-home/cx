# `cx-stdlib/fp` — functional composition over the value channels

```cx
[module-meta name=fp tier=A status=current]
```

**Status:** Current. **Advanced / opt-in.** A CX author is fully
productive without ever opening this module; it adds the abstraction *over the
container* — one `traverse`/`fold` that works for a sequence, a `result`, and a
user-defined tagged container alike. The words "monad" / "functor" / "typeclass"
do not appear in beginner material (the learnability ladder, Tier 3 — `process/spec-authoring-guide.md` §4).

`fp` is composition defined **over** the four outcome channels (`core/code.md`
§9.1.2), never beside them: extraction and recovery are `[?else]` / `[?fallback]`
/ `[?pipe]` (authored in core); `fp` adds *only* the `map` / `flat-map` / `pure` /
`traverse` / `sequence` / `fold` abstraction and its instance set.

---

## §1. The protocol (duck-typed, head-tag dispatch)

`fp` defines a small **closed** protocol of six combinators that dispatch on the
**head tag** of the container value via the core `[?match]` (`code.md` §8.2):

| Combinator | Role |
|---|---|
| `map` | functor map — apply a function inside the container |
| `flat-map` | monad bind — apply a container-returning function, one level of nesting removed |
| `pure` | lift a value into the container |
| `traverse` | map an effectful (container-returning) function across a structure, swapping the layers |
| `sequence` | `traverse` with the identity function — turn a structure of containers inside-out |
| `fold` | reduce a container to a summary value |

A type **"is a Functor"** iff the instance registry has a `map` arm for its head
tag — **duck-typed, checked at the value**. There is **no static kind system**
(`[returns ::F[_]]` is RESERVE) and **no explicit `[typeclass]`/`[instance]`
registry surface** (RESERVE-upgrade if duck typing proves too loose);
the instances are the closed built-in set below plus user-registered tagged
containers.

`fp` does **not** control evaluation order or scope and does **not** produce a
prohibited structural transform (`README.md` §3.1 carve-out): its combinators are
value→value functions dispatching through the core `[?match]`, and the
err-inspecting combinators inherit `[?match]`'s §9.2-exempt boundary (§4) rather
than defining a new evaluation rule.

### §1.1 Instance set (closed built-in)

- **`sequence` = the Maybe AND List monad (one instance).** In a sequence-based
  (XPath-derived) language, Maybe and List are **not** separate functors — they
  are the sequence monad at different cardinalities:
  - **`None` = the empty sequence `()`** — which IS the §9.1.2 absence channel /
    sequence-monad zero.
  - **`Some(x)` = the singleton `(x)`**; **`Some(null)` = `(null)` ≠ `()`** (the
    `Some(null)`-vs-`None` distinction is recovered by **cardinality**, with no
    boxed `Option` type and no `[some]`/`[none]` heads, `code.md` §9.1.2.3).
  - `pure x = (x)`; `map` / `flat-map` / `traverse` are the standard sequence
    monad. `[?else]` (`code.md` §8.13) is `getOrElse` over it (defaults on
    `()` = `None`).
- **`result` = `[ok]` / `[err]`** — `flat-map` is the railway short-circuit (the
  `[?pipe]` railway, `code.md` §8.9.3 / §9.2 auto-propagation): a `flat-map` over
  an `[err]` returns the `[err]` unchanged; over `[ok v]` it applies the function
  to `v`.
- **user-defined tagged containers** — duck-typed by head tag (register a `map`
  / `flat-map` arm for the tag).
- **NO `option` / `[some]` / `[none]` instance** — Maybe is the ≤ 1 sequence;
  there is no second "nothing" (`code.md` §9.1.2.3, resolves the `[some]`-erases-
  to-`x`-vs-dispatch contradiction).

### §1.2 Dispatch precedence (normative)

Given a value `x`, `[$fp:map x f]` selects its instance in this **fixed order**:

1. a **registered head-tag instance** for `x`'s head (a user-defined instance, or
   the built-in `result` over `[ok]` / `[err]`) → that instance;
2. else `x` is a **sequence** (`__cx_seq__`) → the `sequence` instance;
3. else `x` is a **bare scalar** → the singleton `Some(x)` under the `sequence`
   instance (a bare scalar is a singleton sequence, `code.md` V3 / XPath
   atomization);
4. else (`x` is a tagged element with **no** registered instance, e.g.
   `[user …]`) → **`cx-err:CXER4400`** (`E_NO_INSTANCE`).

**Key rule:** a tagged element is **NOT** implicitly a container — only scalars
and sequences are auto-Maybe. An element is a functor *only* if an instance is
registered for its tag. So `[user …]` dispatches to a "user" instance if one
exists, else it is an opaque value that raises `E_NO_INSTANCE` under
`map`/`flat-map` — never silently treated as a singleton or a body-container.

### §1.3 Signatures + arities (normative)

`F` denotes the dispatched container; `a`, `b` are item types. **Err-boundary**
combinators (marked ★) receive an `[err]`-holding container as an inspectable
value (they are defined over `[?match]`, inheriting its §9.2-exempt boundary, §4);
the others auto-propagate an `[err]` argument per §9.2.

| Combinator | Surface | Arity | Err-boundary? |
|---|---|---|---|
| `map` | `[$fp:map F fn]` | `fn: (a) → b` | no — propagates |
| `flat-map` | `[$fp:flat-map F fn]` | `fn: (a) → F b` | no — propagates (the railway *is* the propagation, for `result`) |
| `pure` | `[$fp:pure x]` (or `[$fp:pure x tag=…]`) | `x: a` | no |
| `traverse` ★ | `[$fp:traverse F fn]` | `fn: (a) → G b` → `G (F b)` | **yes** — may inspect an `[err]`-holding element |
| `sequence` ★ | `[$fp:sequence F]` | `F (G a)` → `G (F a)` | **yes** |
| `fold` ★ | `[$fp:fold F init fn]` | `init: b`, `fn: (b, a) → b` | **yes** — may fold over a container that holds `[err]` items |

`pure`'s target instance defaults to `sequence` (`[$fp:pure 5]` → `(5)`); a
`tag=` argument selects a registered instance (`[$fp:pure 5 tag=result]` →
`[ok 5]`).

### §1.4 Instance-registry shape (duck-typed)

An instance is a CX document — a `(class, tag) → fn` arm declared by registering a
function for a combinator on a head tag. The built-in instances (`sequence`,
`result`) are pre-registered; a user registers an arm for a tag `T` by providing
`map`/`flat-map` (and optionally `fold`/`traverse`) bound to `T`. Because an
instance is a CX document, the registry is **CXPath-queryable**
(`//instance[= $_@class 'Monad']`) — a tool or the model can check coherence
structurally and reason over the laws as data (the homoiconic moat, the same as
errors-as-queryable-documents). Resolution is by §1.2 precedence; a tag with a
`map` arm but no `flat-map` arm is a Functor but not a Monad (a `flat-map` on it
raises `E_NO_INSTANCE`).

---

## §2. Combinators map onto existing channels (no competition)

`fp` introduces only the genuinely-new *abstraction* rows; everything else is the
existing core surface (`code.md` §9.1.2 / §8):

| FP combinator | CX home | New? |
|---|---|---|
| `map` / `flat-map` (abstract, any tagged container) | **`fp.md` §1** | **NEW** |
| `flat-map` on the **failure** channel | `[?pipe]` railway (`code.md` §8.9.3) | existing |
| `getOrElse` / `unwrap_or` | `[?else]` (`code.md` §8.13) | the directive |
| `recover` / `recoverWith` | `[?fallback]` (`code.md` §10.2.4) | admitted |
| the **Maybe** functor | the `sequence` instance at cardinality ≤ 1 (`None`=`()`, `Some(x)`=`(x)`) — no `Option` type | **NEW** (as the sequence instance) |
| `pure` / `traverse` / `sequence` / `fold` | **`fp.md` §1** — `sequence` = Maybe + List | **NEW** |
| the `result` instance (`[ok]`/`[err]`) | `fp.md` over §9.1.2 failure (`flat-map` = `[?pipe]` railway) | **NEW** |
| static kind-checking of `F[_]` | — | RESERVE |

---

## §3. The functor / monad / traverse laws (conformance)

The laws are normative and **shipped as conformance fixtures** (asserted by
running each side and comparing under the production renderer):

- **Functor identity** — `map(x, id) ≡ x`.
- **Functor composition** — `map(x, f∘g) ≡ map(map(x, g), f)`.
- **Monad left identity** — `flat-map(pure(a), f) ≡ f(a)`.
- **Monad right identity** — `flat-map(m, pure) ≡ m`.
- **Monad associativity** — `flat-map(flat-map(m, f), g) ≡ flat-map(m, λx. flat-map(f(x), g))`.
- **Traverse naturality** — `traverse` commutes with the natural transformation
  between the two applicatives (checked over `sequence`/`result`).

Each law is asserted for **both** the `sequence` and `result` instances.

---

## §4. Interaction with §9.2 auto-propagation (err-holding containers)

Auto-propagation (`code.md` §9.2) short-circuits an `[err]` passed as a **direct
call argument** before ordinary dispatch — correct for happy-path `result` ops,
but it would prevent combinators that must **inspect** a failure from receiving
it. So the **err-boundary** combinators (`traverse`, `sequence`, `fold`, and the
`recover`-family which lives in core) are defined over `[?match]` and inherit its
§9.2-exempt scrutinee boundary: an `[err]`-holding container reaches them as an
inspectable value.

- A **non-boundary** combinator (`map`, `flat-map`) applied with a *direct*
  `[err]` argument auto-propagates that `[err]` per §9.2 (the railway).
- A **boundary** combinator (`traverse`/`sequence`/`fold`) over a container that
  *holds* `[err]` items receives the container as a value and may inspect the
  errs (e.g. `fold` can count them; `sequence` over `(… [err] …)` can collapse to
  the first `[err]` deliberately).

This is a real interaction with core (a *use* of the `[?match]` boundary), not a
new evaluation rule — consistent with the `README.md` §3.1 carve-out.

---

## §5. Errors

| Code | Symbol | Raised when |
|---|---|---|
| `CXER4400` | `E_NO_INSTANCE` | `map`/`flat-map`/`traverse`/`sequence`/`fold` dispatched on a tagged element with no registered instance for its head tag (§1.2 step 4) |

(`CXER4401–4409` reserved for future `fp` growth. The symbolic name is
documentation; conformance fixtures assert the numeric code, `governance.md`
§9.6.)

---

## §6. Cross-references

- [`spec/core/code.md`](../core/code.md) — §9.1.2 the four channels; §8.2
  `[?match]` (dispatch + the §9.2-exempt scrutinee); §8.9 `[?pipe]` railway;
  §8.13 `[?else]` (`getOrElse`); §10.2.4 `[?fallback]` (`recoverWith`).
- [`spec/core/cxdm.md`](../core/cxdm.md) — §1 sequence-flat (empty = `None`); §2
  the Item taxonomy; §2.7 Sequence-as-Item.
- [`spec/process/governance.md`](../process/governance.md) §9.6 — the `CXER4400`
  allocation.
- [`README.md`](README.md) §3.1 — the stdlib charter carve-out for `fp`.
