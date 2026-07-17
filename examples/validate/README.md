# Schema validation walkthrough — `.cxs` + `cx validate`

A minimal end-to-end tour of CX schema validation (spec:
`spec/03-approved/core/schema.md`): a small data document, the `.cxs`
schema that constrains it, one passing run, and one deliberately
failing variant with its exact diagnostics.

## Files

| File | Role |
| ---- | ---- |
| [`inventory.cx`](inventory.cx) | The data document — a warehouse inventory. |
| [`inventory.cxs`](inventory.cxs) | The schema: required/typed attributes, an enum with a default, child-element cardinality, `strict` mode. |
| [`inventory.bad.cx`](inventory.bad.cx) | A broken variant that trips three distinct diagnostic classes. |

## The schema, in brief

`inventory.cxs` declares (see the file for the full commented version):

- `[?cx schema-of inventory]` — the document element this schema targets.
- `[?cx schema-mode strict]` — vocabulary is closed to what the schema declares.
- `[inventory …]` — requires a `site::string` attribute and `1..*`
  `[item]` children.
- `[item …]` — requires `sku::string`, `name::string`, `qty::int`;
  `status` is optional with `[default stocked]` and
  `[enum stocked low discontinued]`.

## Passing run

```sh
$ cx validate examples/validate/inventory.cx --schema=examples/validate/inventory.cxs
$ echo $?
0
```

No diagnostics, exit `0`. Note the second item omits `status` — legal,
because the schema declares a default for it (`--apply-defaults` makes
the validator insert `status=stocked` there before validating).

## Failing run

`inventory.bad.cx` plants three violations: a non-integer `qty`, a
`status` outside the enum, and a missing required `sku`.

```sh
$ cx validate examples/validate/inventory.bad.cx --schema=examples/validate/inventory.cxs
examples/validate/inventory.bad.cx:0:0: error: S005: attribute 'qty' on <item>: type mismatch (declared :int, got :string = 'lots')
examples/validate/inventory.bad.cx:0:0: error: S007: attribute 'status' on <item>: value 'misplaced' not in :enum [stocked,low,discontinued]
examples/validate/inventory.bad.cx:0:0: error: S002: missing required attribute 'sku' on <item>
$ echo $?
1
```

One run, all three diagnostics reported (the validator does not stop at
the first error), exit `1`.

## Useful flags

- `--fail-on=info|warn|error|none` — severity threshold for the nonzero
  exit (default `error`).
- `--mode=open|strict|closed` — override the schema's own
  `schema-mode` directive for a run.
- `--apply-defaults` — insert schema-declared `[default …]` attribute
  values before validating.
