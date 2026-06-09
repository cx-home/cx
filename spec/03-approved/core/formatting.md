# CX Formatting Profiles

**Status:** Current for v0.8.0. This file admits the **profile model** — the
axes (§2), the built-in profiles (§3), and the `cx-format.cx` configuration
document (§4). The `cx fmt --profile` flag is specified in `cli.md` §3.1. The
remaining apply surfaces — the `[?cx format=NAME]` processing instruction
(`code.md`), the `cx-stdlib/format` emit functions, and the `format-profiles`
validation schema (`schema.md`) — are **forthcoming** in those owning files; the
references to them below are forward cross-references, not a claim that those
surfaces are already admitted.

Formatting renders a CX node tree to text under a **profile**. A profile is a
declarative set of presentation **axes**; built-in profiles are named
compositions, and projects define their own. Formatting parameterizes
`cx fmt` and the `cx-stdlib/format` emit functions.

## §1 Principle — formatting is presentation-only

A formatter is a pure function `(CX tree, profile) → text`. It **never changes
the data or the node tree** — same tree in, same tree out (round-trips). It
only decides whitespace, quoting, and layout. Changing structure or content is
a **transform** (`[?modify]`, a template), **not** a format. This boundary is
normative: a profile that would alter data is ill-formed.

Relationship to `canonical.md`: the **idiomatic** layer (syntax-usage:
quote hierarchy, glued `::T`, `[$fn …]` call form, atom/number rendering;
canonical.md §1.1a) and the **layout** layer (whitespace/indent/wrap) are the
two axis groups a profile sets. `canonical` (lossless) = idiomatic + a fixed
layout; `strict` = canonical − presentation + data normalization.

## §2 Axes

A profile sets these orthogonal axes (unset = the `canonical` default):

| Axis | Values | Default |
|---|---|---|
| `quote` | `idiomatic` (bare>single>double, canonical.md §2.3) · `single` · `double` | `idiomatic` |
| `indent` | `none` · `spaces=N` · `tabs` | `spaces=2` |
| `attributes` | `inline` · `below-each` (one per line) · `below-block` (all on one line under head) · `wrap=N` | `inline` |
| `children` | `inline` · `one-per-line` · `wrap=N` | `wrap=80` |
| `structure` | `preserve` (lossless) · `normalize` (strict: resolve merges/aliases, reorder) | `preserve` |
| `comments` | `preserve` · `strip` | `preserve` |
| `numbers` | `as-written` · `canonical` | `canonical` |
| `blank-lines` | `preserve` · `collapse` | `collapse` |
| `max-width` | INT · `none` | `80` |

Axes are presentation-only (none alters data). The set is fixed (not
extensible by code in v1); it is designed to express the practical layout
space declaratively.

## §3 Built-in profiles

Named compositions. All are version-stable EXCEPT `pretty`.

| Profile | Axis composition | Use |
|---|---|---|
| `strict` | `structure=normalize comments=strip quote=idiomatic` + deterministic layout | `cx hash` / equality; signing |
| `canonical` | the §2 defaults (lossless, deterministic) | `cx fmt` default; diffs; review |
| `idiomatic` | `quote=idiomatic` + ALL layout axes = preserve author layout | syntax normalizer that does not reflow (`cx fmt --profile=idiomatic`) |
| `pretty` | human layout (indent + wrap), **NOT version-stable** | reading / debugging only — never snapshot-test |
| `one-line` | `indent=none attributes=inline children=inline max-width=none` | dense single line |
| `vertical` | `indent=spaces=2 attributes=below-each children=one-per-line` | thin/tall review form |

## §4 Declarative configuration

Profiles are defined/overridden in CX (a `cx-format.cx` document):

```
[format-profiles
  [profile name=vertical
    quote=idiomatic indent=2
    [attributes below-each]
    [children one-per-line]]
  [profile name=compact extends=canonical
    [attributes inline] max-width=120]]
```

- Each `[profile name=…]` sets axes as scalar attributes (`indent=2`) or
  clause-children (`[attributes below-each]`); `extends=NAME` inherits a base
  profile's axes, overriding only those restated.
- Built-in profiles (§3) are pre-defined; a `cx-format.cx` may add or `extends=`
  them, never redefine a built-in's identity.
- Schema: a `format-profiles` document validates against the `format-profiles`
  schema (axis names + value enums per §2). That schema is **forthcoming** in
  `schema.md`; until it is admitted, §2 here is the normative source for the
  axis names and value enums.

## §5 Applying a profile

A profile is a first-class value; apply it by name or pass it inline. The
application surfaces below are owned by `cli.md`, `cx-stdlib/format`, and
`code.md` and are **forthcoming** (see Status); the forms shown define how a
profile is selected once they are admitted.

- CLI: `cx fmt --profile=NAME FILE`.
- Emit function: `[$format $value profile=vertical]` (by name) or
  `[$format $value [profile indent=2 [attributes below-each]]]` (inline dialect
  supplied at emit time).
- Project default: a `cx-format.cx` in the project root sets the default profile
  for `cx fmt`.
- In-document: `[?cx format=NAME]` selects a profile for that document.

Resolution order: explicit `--profile`/argument › in-document `[?cx format=]` ›
project `cx-format.cx` default › built-in `canonical`.

## §6 Power ladder

Progressive, each tier opt-in:

1. **by name** — `--profile=idiomatic` (zero config; the common case).
2. **extend** — `[profile name=x extends=canonical [attributes below-each]]`.
3. **full axis control** — set the whole §2 axis set (the declarative ceiling;
   covers essentially every real layout without code).
4. **RESERVED (not in v1)** — a per-node decision callback
   `(node, ctx) → axis-values` for cases the axes cannot express. It returns
   formatting *choices*, never raw text, so output stays valid CX. Reserved as
   a future extension point; not implemented in v1 (YAGNI until a real need).

## §7 Conformance

A conforming formatter: (a) is presentation-only (§1) — output re-parses to a
tree equal to the input tree (modulo `structure=normalize`); (b) implements the
§2 axes and the §3 built-ins; (c) `strict`/`canonical`/`idiomatic`/`one-line`/
`vertical` are byte-stable across versions (`pretty` is not); (d) honors the §5
resolution order. The reserved §6.4 callback is not required.
