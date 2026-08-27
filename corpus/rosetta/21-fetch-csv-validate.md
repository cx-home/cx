# 21 — Fetch CSV, parse, validate against schema

## What it does

The gate 47.7 probe for the v0.8.0 stdlib surface. Exercises the stdlib triad `http` + `csv` + `validate`:

1. Fetch a CSV file body via `cx-stdlib/http`'s one-shot `get`.
2. Parse the CSV into a sequence of typed record rows via `cx-stdlib/csv`.
3. Validate each row against a typed schema via `cx-stdlib/validate`.
4. Count and return only the valid rows.

(The original also routed the URL through `cx-stdlib/url` parse-then-rebuild. That step was decorative — it reconstructed the same literal string it was handed — and the rewrite drops it rather than keep a round-trip that demonstrates nothing. `url` is exercised by its own conformance suite.)

This is the canonical "agentic data-ingest pipeline" shape — fetch a vendor CSV (lead exports, contract logs, audit traces), filter for valid records, return a count or further-processed slice. Three new v0.8.0 stdlib modules collaborate.

## Idiomatic shape in other languages

- **Python** (`urllib` + `csv` + `pydantic`): `urllib.request.urlopen(url).read().decode() → csv.DictReader → [Lead(**row) for row in rows if Lead.model_validate(row).is_valid()]`
- **Go** (`net/http` + `encoding/csv` + `go-playground/validator`): `http.Get → csv.NewReader → for _, row := range rows { validate.Struct(&Lead{...}) }`
- **TypeScript** (`fetch` + `csv-parse` + `zod`): `await fetch(url) → csvParse(body) → rows.filter(r => LeadSchema.safeParse(r).success)`
- **BaseX (XQuery)**: `http:send-request → csv:parse → for $r in $rows where $r/validate-fn() return $r`

## Actual run

Program: see `21-fetch-csv-validate.cx`.

Run: `vcx/target/cx corpus/rosetta/21-fetch-csv-validate.cx`

Observed output:

```
[err code=cx-err:CXER0271 message='E_CAP_DENIED: net capability required for crm.example.com:443; none granted (grant via --allow-net)']
```

**Status:** BLOCKED — and the reason has CHANGED. Re-derived 2026-08-25 (RULED:
VC-28) after the program was rewritten for the v0.8.0 surface; before that
rewrite it did not parse at all (`CXER0100`: retired `:scope` colon-slot on
`[?def]`).

The previously recorded reason — "the three new stdlib modules ship
signature-only skeletons, bodies pending the Phase 3.x rollout" — is **no
longer true and has been removed**. `csv`, `validate`, `url`, and `http` are
all `gate=enforced` in `conformance/gates.cxd` (impl complete, all cases
green). Recording a shipped module as pending is exactly the class of fiction
this corpus was re-derived to remove.

What actually blocks it now is the **capability boundary, not a surface gap**:
the fetch needs `net`, the offline audit grants nothing, so `[$http:get]`
refuses with `CXER0271` before any byte moves. That is correct behavior, it is
deterministic and offline (no DNS timeout, no flake), and it is why the gate
records this program as `blocked` rather than green.

Everything downstream of the fetch is MEASURED WORKING. Feeding the same
pipeline a literal CSV body instead of a URL — same three `[?def]`s, same
schema — returns `1` from three input rows, rejecting one bad email and one
out-of-range score. So the program discriminates; it is not vacuous. It flips
to GREEN the moment it is run with `--allow-net` against a reachable endpoint:

```
cx --allow-net=crm.example.com corpus/rosetta/21-fetch-csv-validate.cx
```

## Workarounds used

One, and it is a genuine finding rather than a papered-over gap:

| Idiomatic | Used | Reason |
|---|---|---|
| `[$csv:parse $body]` then validate | `[$csv:parse-with-schema $body {score: :int}]` | `parse` yields all-string cells per `spec/std-lib/csv.md` §2, so a `type="int"` field fails with `score: expected int, got string`. Column coercion at parse time is the surface's answer, which is why `score` is named twice — once to coerce, once to bound-check. |

## Open gap log

The hypotheses this program was written to test are now ANSWERED by
measurement rather than pending. Kept with their verdicts, because the answers
are the point of the probe:

| Hypothesis | Verdict |
|---|---|
| the request form binds a response body as written | **VOID** — the shape tested (`[?http-client :method … :yield-body $b :in …]`) is not a shape CX has. `[?http-client]` is a client *handle* constructor; the one-shot verbs are `[$http:get]` / `[$http:post]` / … returning a `[response]`, and `[$http:body-text]` reads the body. |
| `csv` parse accepts bytes vs string input | **ANSWERED**: `parse` / `parse-with-schema` take `$s::string`. `[$http:body-text]` performs the charset decode, so the response → parse handoff is string-typed end to end. |
| `validate-shape` accepts the row shape `csv` produces | **CONFIRMED**: a CSV row is a CXDM **map**, and `validate-shape`'s `$value::any` honours it. No element synthesis needed. |
| the `is-ok` predicate composes with a comprehension filter | **CONFIRMED**: `[?for [in $row …] [where [$validate:is-ok …]] [yield $row]]` filters correctly. |
| `[?const LEAD_SCHEMA [schema …]]` parses and binds | **CONFIRMED**, and the schema literal is now spec-verbatim — `spec/std-lib/validate.md` §2.1 uses this exact block as its own example. |
| regex `pattern=` field validation works | **CONFIRMED**: `bad-email` is rejected with `PATTERN_MISMATCH` against `.+@.+\..+`. |

Remaining, and genuinely open: **the live end-to-end run**. Every stage is
proven in isolation and in composition offline, but the corpus has never
executed this program against a real HTTP endpoint. That needs a fixture
server, not a surface change.

## Why this matters

The triad `http` + `csv` + `validate` is the **minimum viable agentic data-ingest pipeline**. Almost every agentic workflow starts with "fetch some vendor data, filter it, branch on validation outcome." The 2026-08-25 re-derivation showed the surface covers that shape: every stage composes, the schema discriminates, and the only thing standing between this program and a green run is a capability grant and a reachable endpoint.

The one caveat worth keeping visible: the fetch leg has never been exercised end to end here. "Each stage works and they compose offline" is strong evidence, not the same claim as "the pipeline runs against a real server."

## Cross-references

- gate 47.7 — this program closes the gate.
- Rosetta-corpus surface-completeness process this program follows.
- `spec/03-approved/std-lib/http.md` — the one-shot verbs and `[response]` shape.
- `spec/03-approved/std-lib/csv.md` — row shape and `parse-with-schema` coercion.
- `spec/03-approved/std-lib/validate.md` — §2.1 carries this program's schema block verbatim.
