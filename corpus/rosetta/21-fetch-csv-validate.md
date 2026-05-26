# 21 — Fetch CSV, parse, validate against schema

## What it does

The gate 47.7 probe per [ADR 0047](../../spec/decisions/0047-stdlib-surface-v0_8_0.md). Exercises the new stdlib triad `url` + `csv` + `validate` plus the existing `[?http-client]` integration directive:

1. Build a URL via `cx-stdlib/url` (parse + reconstruct).
2. Fetch a CSV file body via `[?http-client]` directive.
3. Parse the CSV into a sequence-of-element rows via `cx-stdlib/csv`.
4. Validate each row against a typed schema via `cx-stdlib/validate`.
5. Count and return only the valid rows.

This is the canonical "agentic data-ingest pipeline" shape — fetch a vendor CSV (lead exports, contract logs, audit traces), filter for valid records, return a count or further-processed slice. Three new ADR 0047 modules collaborate.

## Idiomatic shape in other languages

- **Python** (`urllib` + `csv` + `pydantic`): `urllib.request.urlopen(url).read().decode() → csv.DictReader → [Lead(**row) for row in rows if Lead.model_validate(row).is_valid()]`
- **Go** (`net/http` + `encoding/csv` + `go-playground/validator`): `http.Get → csv.NewReader → for _, row := range rows { validate.Struct(&Lead{...}) }`
- **TypeScript** (`fetch` + `csv-parse` + `zod`): `await fetch(url) → csvParse(body) → rows.filter(r => LeadSchema.safeParse(r).success)`
- **BaseX (XQuery)**: `http:send-request → csv:parse → for $r in $rows where $r/validate-fn() return $r`

## Actual run

Program: see `21-fetch-csv-validate.cx`.

Run: `devbox run -- ./vcx/target/cx eval corpus/rosetta/21-fetch-csv-validate.cx`

**Status:** BLOCKED (expected at v0.8.0 pre-implementation). The three new stdlib modules (`url` / `csv` / `validate`) ship signature-only skeletons per [ADR 0047 gate 47.2](../../spec/decisions/0047-stdlib-surface-v0_8_0.md); bodies for non-flagship modules land per the Phase 3.x companion-spec rollout. Once `cx-stdlib/url`, `cx-stdlib/csv`, and `cx-stdlib/validate` ratify their companion specs and ship V bodies, this program flips to GREEN.

The `[?http-client]` directive is the ADR 0027 integration capability; should work today against a reachable URL.

Expected output (post-implementation, against a valid CSV at the URL with N valid lead rows):

```
N
```

## Workarounds used

None yet — the program is written in the **target idiom** for the v0.8.0 amended stdlib surface. Workarounds appear only if real-implementation lands and an idiom turns out to be unexpressible; flagged then.

## Open gap log

Each item below is a hypothesis to confirm or disprove once the stdlib bodies land.

| Hypothesis | Gap area | Resolution path |
|---|---|---|
| `[?http-client :yield-body $body :in ...]` body-binding modifier works as written | ADR 0027 integration capability | Run against a mock HTTP server; confirm `:yield-body` binds the response body into the body-scope |
| `(csv/parse $body)` accepts a `bytes`-typed input (vs `string`-typed) | `cx-stdlib/csv` companion spec | Companion-spec decision: `parse` accepts string vs bytes vs either; default likely string post-charset-decode |
| `[validate/validate-shape $row :against LEAD_SCHEMA]` accepts a CXDM element as $row | `cx-stdlib/validate` companion spec | Companion-spec decision: input shape for `validate-shape` matches the CSV row shape that `csv/parse` produces |
| `(validate/is-ok ...)` predicate composes with `[?for ... :where ...]` | `cx-stdlib/validate` + `:where` modifier | Direct composability check; if it fails, an `:where` modifier evaluator gap |
| `[?const LEAD_SCHEMA [schema ...]]` schema-as-data parses and binds | ADR 0009 / ADR 0035 `[?const]` | Should work per ADR 0035 D12 (const + eager evaluation); schema-as-element shape is data, not directive |
| `[field :name "email" :pattern ".+@.+\..+"]` regex-pattern field validation | `cx-stdlib/validate` semantics | If validate uses RE2 (cap bit 25), pattern compiles and matches per `cx-stdlib/re` engine |

## Why this matters

The triad `url` + `csv` + `validate` is the **minimum viable agentic data-ingest pipeline**. Almost every agentic workflow starts with "fetch some vendor data, filter it, branch on validation outcome." If this program runs cleanly post-implementation, gate 47.7 closes and the v0.8.0 surface has demonstrated coverage of a real, common workflow shape.

If it BLOCKS post-implementation, the blocker is a stdlib gap that motivates an immediate amendment ADR per the [ADR 0045](../../spec/decisions/0045-surface-completeness-discovery-process.md) D6 triage workflow.

## Cross-references

- [ADR 0047 §D8 gate 47.7](../../spec/decisions/0047-stdlib-surface-v0_8_0.md) — this program closes the gate.
- [ADR 0045](../../spec/decisions/0045-surface-completeness-discovery-process.md) — Rosetta-corpus surface-completeness process this program follows.
- `spec/stdlib_url.md` (planned) — companion spec the program tests against.
- `spec/stdlib_csv.md` (planned) — same.
- `spec/stdlib_validate.md` (planned) — same.
