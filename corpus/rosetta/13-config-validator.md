# 13 — Config validator

## What it does

Build a small `[config]` shape with `[port]`, `[host]`, and `[retry]`
children. Validate that the two required fields are present and yield
`:valid` if so, `:invalid` otherwise. This is a probe for the
intersection of three things: schema-as-shape, predicate composition,
and the `[?match]` truth-value-of-`:when` flow.

## Idiomatic shape in other languages

- **Python (pydantic)**: `class Config(BaseModel): port: int; host: str`
- **JSON-schema**: `{"required": ["port", "host"], "properties": {...}}`
- **TypeScript / Zod**: `z.object({port: z.number(), host: z.string()})`
- **CX schema (alternative path)**: `[?schema [config :requires (port, host)]]` (the `spec/schema.md` design surface) — not used here because we want the in-program shape, not the schema-validator path.

## Actual run

Program:

```cx
[?let [= $config [config
                   [port 8080]
                   [host "localhost"]
                   [retry max=3 backoff=100ms]]]
  [?match true
    [when [$and [> [$count $config//port] 0] [> [$count $config//host] 0]] :valid]
    [else :invalid]]]
```

Run: `vcx/target/cx corpus/rosetta/13-config-validator.cx`

Observed output:

```
:valid
```

**Status:** GREEN (re-derived 2026-08-25, RULED: VC-28). Rewritten for the
v0.8.0 surface: `[$count $config//port]` with `[$and]` inside
`[?match true [when …] [else …]]`, and `backoff=100ms` as an attribute rather
than the old atom-as-attribute-name form. Runs rc=0 → `:valid`, and verified
DISCRIMINATING: removing `[port 8080]` flips it to `:invalid`, so the arm is not
vacuously true. The previously-noted `exists()` gap is moot — `[> [$count …] 0]`
is the idiom and it is clean.

## Historical (v0.7.x surface, superseded)

Everything below this line describes the **pre-reshape** surface and is kept as
a discovery trail, not as findings. Its items are closed or void today: the
`exists()` gap is moot (`[> [$count …] 0]` is the idiom), the `:where`-modifier
item describes a shape CX does not have, and the child-vs-descendant "single
match" claim was superseded and then retired outright. `AUDIT.md` carries the
retirement list and the live gap register; this section is history.

### Status at the time

**Status:** GREEN (with one minor workaround). The program parses and
returns `:valid` correctly. Removing either `[port 8080]` or
`[host "localhost"]` from the source produces `:invalid` as expected.

### Workarounds used

| Idiomatic | Used | Reason |
|---|---|---|
| `[?match $config :where [and [exists $config/port] [exists $config/host]] :yield :valid :else :yield :invalid]` (task brief) | `[?match true :when [and [> count($config//port) 0] [> count($config//host) 0]] :yield :valid :else :yield :invalid]` | (a) No `exists()` builtin — substitute `count(...) > 0`. (b) `:where` modifier on outer `[?match]` not recognised in this position — substitute `:when` arm with `true` subject. (c) `$config/port` returns single child, but `$config//port` returns all matches; we use `//` for robustness. |

### Open gap log

Surface-completeness hypothesis confirmations:

1. **`exists()` builtin missing.** XPath 3.1 §3.6.2 has both `exists` and `empty`. CX has `empty` but not `exists`. Trivial fix (one-line addition); should land alongside `boolean()` / `not()` audit. **Amends `spec/code.md §6.5`.**

2. **`[?match $subject :where PREDICATE :yield X :else :yield Y]` modifier form.** Per `spec/code.md §8.4`, `:where` is a per-arm modifier, not an outer-match modifier. The task brief's example uses it as an outer modifier — that doesn't work. This is a spec-clarity issue, not a parser gap; worth a `spec/code.md` clarification.

3. **Schema-validator path (`spec/schema.md`) is the "real" answer here.** The fact that an in-program `[?match]` works at all is good, but production config-validation would lean on `[?schema]` / `validate` — confirming the schema surface is the right place for this class of program. **No new surface needed; aligns with existing roadmap.**

4. **Child-axis-vs-descendant-axis disparity (CONFIRMED, already in 0045 gap register).** Re-confirmed: `$config/port` returns 0 (or 1, depending on which way the single-match gap cuts); `$config//port` returns the correct count. Same gap as in program #06.

This is the corpus' first GREEN program — encouraging signal that the
surface isn't *uniformly* broken, just patchily so. Validation-by-
matching-on-counts is a workable idiom even without `exists()`.
